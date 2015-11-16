#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
export DONT_MOUNT_BOOT=1
emerge --quiet-build sys-boot/grub
echo "GRUB_CMDLINE_LINUX=\"real_init=/usr/lib/systemd/systemd\"" >> /etc/default/grub
grub2-install /dev/sda
grub2-mkconfig -o /boot/grub/grub.cfg
EOF

