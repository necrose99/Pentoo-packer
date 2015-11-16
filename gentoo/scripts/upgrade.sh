#! /bin/bash

chroot /mnt/gentoo /bin/bash <<EOF
emerge --quiet-build -uDN @world
EOF

