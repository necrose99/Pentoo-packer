#! /bin/bash

cat > /mnt/gentoo/etc/systemd/network/dhcp.network<<EOF
[Match]
Name=en*

[Network]
DHCP=yes
EOF

chroot /mnt/gentoo /bin/bash <<EOF
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
EOF

