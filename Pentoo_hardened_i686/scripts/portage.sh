#!/bin/bash

chroot /mnt/pentoo /bin/bash <<'EOF'
mkdir /usr/portage
emerge-webrsync
emerge git layman
layman -L
layman -a pentoo
layman -S
EOF
