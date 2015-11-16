#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
echo "root:${GENTOO_ROOT_PASSWD}" | chpasswd
EOF

