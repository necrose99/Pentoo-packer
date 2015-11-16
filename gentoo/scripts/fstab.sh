#! /bin/bash

cat > /mnt/gentoo/etc/fstab <<EOF
/dev/sda2   /boot        ext2    defaults,noatime     0 2
/dev/sda3   none         swap    sw                   0 0
/dev/sda4   /            ext4    noatime,discard      0 1
EOF

