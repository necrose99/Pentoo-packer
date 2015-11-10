#!/bin/bash

echo "Configuring virtualbox!"

chroot /mnt/pentoo /bin/bash <<'EOF'
rsync -av -H -A -X --delete-during "rsync://rsync.at.gentoo.org/gentoo-portage/licenses/" "/usr/portage/licenses/"

emerge "=virtual/linux-sources-1" --autounmask-write
etc-update --automode -5
emerge "=virtual/linux-sources-1"

emerge ">=app-emulation/open-vm-tools-9.4*" --autounmask-write
etc-update --automode -5
emerge ">=app-emulation/open-vm-tools-kmod-9.4*"

rc-update add open-vm-tools default
rc-update add open-vm-tools-kmod default
EOF
