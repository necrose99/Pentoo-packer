#!/bin/bash

chroot /mnt/pentoo /bin/bash <<'EOF'
equo i "sys-boot/grub"
echo "set timeout=0" >> /etc/grub.d/40_custom
grub2-install /dev/sda
grub2-mkconfig -o /boot/grub/grub.cfg
EOF
