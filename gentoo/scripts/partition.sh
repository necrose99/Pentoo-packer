#! /bin/bash

sgdisk \
  -n 1:0:+2M   -t 1:ef02 -c 1:"grub" \
  -n 2:0:+128M -t 2:8300 -c 2:"boot" \
  -n 3:0:+2G   -t 3:8200 -c 2:"swap" \
  -n 4:0:0     -t 4:8300 -c 2:"root" \
  -p /dev/sda

mkfs.ext2 /dev/sda2
mkfs.ext4 /dev/sda4

mkswap /dev/sda3

