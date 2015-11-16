#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
emerge --quiet-build sys-kernel/gentoo-sources
emerge --quiet-build sys-kernel/genkernel-next
genkernel all
EOF

