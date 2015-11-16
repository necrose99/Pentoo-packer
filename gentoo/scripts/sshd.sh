#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
systemctl enable sshd.service
EOF

