#!/bin/bash

cd /
mkdir /mnt/pentoo/proc
mkdir /mnt/pentoo/boot
mkdir /mnt/pentoo/dev
mkdir /mnt/pentoo/sys
mkdir /mnt/pentoo/tmp
ln -s/mnt/gentoo /mnt/pentoo
mount /dev/sda1 /mnt/pentoo/boot
mount -t proc proc /mnt/pentoo/proc
mount --rbind /dev /mnt/pentoo/dev
mount --rbind /sys /mnt/pentoo/sys
