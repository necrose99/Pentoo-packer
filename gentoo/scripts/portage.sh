#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
emerge-webrsync
eselect profile set ${GENTOO_PROFILE}
EOF

