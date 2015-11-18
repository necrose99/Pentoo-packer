#!/bin/bash

echo "Configuring virtualbox!"

chroot /mnt/pentoo /bin/bash <<'EOF'
rsync -av -H -A -X --delete-during "rsync://rsync.at.gentoo.org/gentoo-portage/licenses/" "/usr/portage/licenses/"
ls /usr/portage/licenses -1 | xargs -0 > /etc/entropy/packages/license.accept
emerge app-emulation/virtualbox-guest-additions
rc-update add virtualbox-guest-additions default
EOF
