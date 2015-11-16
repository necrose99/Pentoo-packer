#! /bin/bash

cat > /mnt/gentoo/etc/portage/make.conf <<EOF
CFLAGS="-march=${GENTOO_MARCH} -O2 -pipe"
CXXFLAGS="\${CFLAGS}"
CHOST="x86_64-pc-linux-gnu"
USE="${GENTOO_USE}"
PORTDIR="/usr/portage"
DISTDIR="${PORTDIR}/distfiles"
PKGDIR="${PORTDIR}/packages"
EOF

