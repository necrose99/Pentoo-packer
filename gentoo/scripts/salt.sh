#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
emerge --autounmask-write --quiet-build app-admin/salt
etc-update --automode -3
emerge --quiet-build app-admin/salt
EOF

cat > /mnt/gentoo/etc/salt/minion <<EOF
providers:
  service: systemd
EOF

