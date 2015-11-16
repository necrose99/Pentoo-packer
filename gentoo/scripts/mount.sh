#! /bin/bash

swapon /dev/sda3

mount /dev/sda4 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount /dev/sda2 /mnt/gentoo/boot

