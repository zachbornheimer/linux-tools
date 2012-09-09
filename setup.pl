#!/usr/bin/perl

# Arguments
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
# perl setup.pl ext4:root:/dev/sda1 swap:/dev/sda2 ext4:/dev/sda3 timezone:America/New_York nohwclocktoutc

print "You have given the following arguments: ";
foreach (@ARGV) {
    print "\t$_\n";
}
print "This will now make your system (including formatting your system!) Proceed? ";
chomp(my $answer = <STDIN>);
exit if ($answer =~ /^y/i);

print "Proceeding...\n";

MAKE_FILESYSTEMS: {
    print "Making the filesystems...\n";
    foreach (@ARGV) {
        if (/^ext4:/) {
            $_ =~ s/^.*://;
            system('mkfs.ext4 ' . $_);
        } elsif (/^swap:/) {
            $_ =~ s/^.*://;
            system('mkswap ' . $_ . '; swapon ' . $_);
        }
    }
    print "Filesystems made.";
}

MOUNT_FILESYSTEMS: {
    print "Mounting the filesystems...\n";
    foreach (@ARGV) {
        if (/^ext4:root:/) {
            s/^.*://;
            system('mount ' . $_ . ' /mnt');
        }
        if (/^ext4:/) {
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

CHROOT: {
    print "Chrooting...\n";
    system('arch-chroot /mnt');
}

SET_LOCALE: {
    print "Setting the Locale...\n"
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
    my $setHWClockToUTC = 1;
    foreach (@ARGV) {
        if (/^timezone:/) {
            s/^timezone://;
            if (-e /usr/share/zoneinfo/ . $_) {
                system('ln -s /usr/share/zoneinfo/' . $_ . ' /etc/localtime; echo ' . $_ . ' >/etc/timezone;');
            }
        }
        if (/^nohwclocktoutc/) {
            $setHWClockToUTC = 0;
        }
    }
    if ($setHWClockToUTC) {
        system('hwclock --systohc --localtime');
    }
}
