#! /bin/bash

cd /mnt/gentoo

curl -O $GENTOO_MIRROR/releases/amd64/autobuilds/$GENTOO_BUILD/stage3-amd64-$GENTOO_BUILD.tar.bz2

tar xpf stage3-amd64-$GENTOO_BUILD.tar.bz2
rm stage3-amd64-$GENTOO_BUILD.tar.bz2

