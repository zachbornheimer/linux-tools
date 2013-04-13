#!/usr/bin/perl

#####################
# Copyright (C) 2013 Zachary Bornheimer
# Purpose: Install and Setup Arch Linux with limited interaction
#
# Procedure:
#     Boot the Live Disc
#     Acquire an Internet Connection
#     wget https://raw.github.com/zachbornheimer/linux-tools/master/arch/setup.pl
#     perl setup.pl [arguments] -- There a few questions to answer at the end
#     reboot
#
# Arguments:
#
# Include the disc that is being operated on (this could be an array)
#    disc:/dev/sda
# Include partitions like this:
#    ext4:root:/dev/sda1
#    swap:/dev/sda2
#    ext4:home:/dev/sda3
#
# Include Timezone like this:
#    timezone:America/New_York
#
# Optional Arguments:
# 
# Don't want the hardware clock set to utc?
#    nohwclocktoutc
#
# Example:
# perl setup.pl disc:/dev/sda ext4:root:/dev/sda1 swap:/dev/sda2 ext4:home:/dev/sda3 timezone:America/New_York nohwclocktoutc
#
# Current Problems:
#    Running grub-install, returns "Path `/boot/grub' is not readable by GRUB on boot.  Installation is impossible. Aborting.
#
# Tested with:
#     Snapshot for April 01, 2013 -- Updated to work with systemd and the updated arch setup system
#####################

my $disc;

print "You have given the following arguments:\n";
foreach (@ARGV) {
    print "\t$_\n";
}
print "This will now make your system (including formatting your system!) Proceed? ";
chomp(my $answer = <STDIN>);
exit if ($answer !~ /^y/i);

print "Proceeding...\n";

print "Setting the default shell to bash...\n";
$ENV{SHELL}='/bin/bash';

MAKE_FILESYSTEMS: {
    local @ARGV = @ARGV;
    print "Making the filesystems...\n";
    foreach (@ARGV) {
        if (/^ext4:/) {
            $_ =~ s/^.*://;
            $rootLocation = $_;
            system('mkfs.ext4 ' . $_);
        } elsif (/^swap:/) {
            $_ =~ s/^.*://;
            system('mkswap ' . $_ . '; swapon ' . $_);
        } elsif (/^disc:/) {
            $_ =! s/^.*://;
            $disc = $_;
        }
    }
    print "Filesystems made.\n";
}

MOUNT_FILESYSTEMS: {
    print "Mounting the filesystems...\n";
    local @ARGV = @ARGV;
    foreach (@ARGV) {
        if (/^ext4:root:/) {
            s/^.*://;
            system('mount ' . $_ . ' /mnt');
        } elsif (/^ext4:/) {
            s/^ext4://;
            my $sub = $_;
            s/^.*://;
            $sub =~ s/(.*):.*/$1/;
            $sub =~ s/(\\|\/)//;
            system('mkdir /mnt/' . $sub . '; mount ' . $_ . ' /mnt/' . $sub);
        }
    }
}

INSTALL_BASE_SYSTEM: {
    print "Installing the base system...\n";
    system('pacstrap /mnt base base-devel');
}

FSTAB: {
    print "Generating and modfiying fstab...\n";
    system('genfstab -p /mnt > /mnt/etc/fstab');
    local @ARGV = ('/mnt/etc/fstab');
    $^I = '';
    while (<>)  {
        s/,data=ordered,/,/;
        s/,data=ordered//;
        print;
    }
}

if (fork()) {
	wait;
} else {
    CHROOT: {
        print "Chrooting...\n";
        chroot("/mnt/arch");
    }

    SET_LOCALE: {
        print "Setting the Locale...\n";
        local @ARGV = ('/etc/locale.gen');
        $^I = '';
        while (<>) {
            s/^#en_US.UTF-8/en_US.UTF-8/;
            print;
        }
        system('locale-gen;echo LANG=en_US.UTF-8 > /etc/locale.conf;export LANG=en_US.UTF-8');
    }

    SET_TIMEZONE: {
        print "Setting the timezone...\n";
        local @ARGV = @ARGV;
        foreach (@ARGV) {
            if (/^timezone:/) {
                s/^timezone://;
                if (-e "/usr/share/zoneinfo/" . $_) {
                    system('rm /etc/localtime; ln -s /usr/share/zoneinfo/' . $_ . ' /etc/localtime; echo ' . $_ . ' >/etc/timezone;');
                }
            }
        }
    }
    
    INIT: {
        system('mkinitcpio -p linux');	
    }
    
    SETUP_GRUB: {
    	system('pacman -S --noconfirm grub-bios grub-efi-x86_64');
    	print "Do you want to have grub boot into Arch automatically? [Y] ";
    	chomp(my $answer = <STDIN>);
    	if ($answer !~ /^n/i) {
    	local @ARGV = ('/etc/default/grub');
        	foreach (@ARGV) {
            	while (<>) {
    	            if (/^GRUB_TIMEOUT/) {
    	                s/^GRUB_TIMEOUT.*/GRUB_TIMEOUT=\Q$grubTimeOut\E/;	
    	                print;
    	            }
	        }
     	    }
    	}
        system('grub-install --recheck ' . $disc . '; grub-mkconfig -o /boot/grub/grub.cfg');
    }
    
    ADD_STARTUP_DAEMONS: {
        local @ARGV = ('dhcpcd');
        foreach (@ARGV) {
            system('systemctl enable ' . $_ . ';');	
        }
    }
    
    ROOT_PASSWORD: {
    	print "Do you want to set a root password? [Y] ";
    	chomp(my $answer = <STDIN>);
    	if ($answer !~ /^n/i) {
    		system('passwd');
    	}
    }
    
    exit;
}
print "Finished in the chroot.\n";

SET_HWCLOCK: {
    my $setHWClockToUTC = 1;
    print "Checking if we need to setup the hardware clock...";
    foreach (@ARGV) {
        if (/^nohwclocktoutc/) {
            $setHWClockToUTC = 0;
        }
    }
    if ($setHWClockToUTC) {
        print "yes.\nSetting the hardware clock to UTC...\n";
        system('hwclock --systohc --localtime');
    }
}

print "\nPlease restart the computer when you are ready to complete the installation.\n";
