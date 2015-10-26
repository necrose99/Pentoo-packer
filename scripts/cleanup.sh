#!/bin/bash

chroot /mnt/pentoo /bin/bash <<'EOF'
equo rm sys-kernel/pentoo-sources pentoo-live pentoo-artwork-isolinux
equo cleanup

cp /etc/systemd/system/autologin@.service \
    /usr/lib/systemd/system/getty@.service

rm -rf /etc/systemd/system/autologin@.service

sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i -e 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

EOF

rm -rf /mnt/pentoo/usr/portage
rm -rf /mnt/pentoo/tmp/*
rm -rf /mnt/pentoo/var/log/*
rm -rf /mnt/pentoo/var/tmp/*

equo i zerofree

mount -o remount,ro /mnt/pentoo
zerofree /dev/sda4

swapoff /dev/sda3
dd if=/dev/zero of=/dev/sda3
mkswap /dev/sda3
