#!/bin/bash

chroot /mnt/pentoo /bin/bash <<'EOF'
ln -snf /usr/share/zoneinfo/UTC /etc/localtime
echo UTC > /etc/timezone
EOF
