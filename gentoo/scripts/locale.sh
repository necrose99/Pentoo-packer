#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
echo "${GENTOO_LOCALE} ${GENTOO_LOCALE/*./}" > /etc/locale.gen
locale-gen
eselect locale set ${GENTOO_LOCALE}
EOF

