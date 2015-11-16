#!/bin/bash

cp $SCRIPTS/scripts/kernel.config /mnt/gentoo/tmp/

chroot /mnt/pentoo /bin/bash <<'EOF'
emerge sys-kernel/pentoo-sources
emerge sys-kernel/genkernel
emerge sys-kernel/dracut
cd /usr/src/linux
mv /tmp/kernel.config .config
genkernel --install --symlink --oldconfig all
emerge -c sys-kernel/genkernel
EOF
