#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
echo "${GENTOO_TIMEZONE}" > /etc/timezone
emerge --config sys-libs/timezone-data
EOF

