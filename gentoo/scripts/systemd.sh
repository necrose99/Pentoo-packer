#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
USE="-systemd" emerge --oneshot --quiet-build sys-apps/dbus
emerge -C udev
emerge --quiet-build sys-apps/systemd
ln -sf /proc/self/mounts /etc/mtab
EOF

