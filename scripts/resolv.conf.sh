#!/bin/bash

cp -L /etc/resolv.conf /mnt/gentoo/etc/
cat >>/mnt/gentoo/etc/resolv.conf <<EOF
nameserver 8.8.8.8 
nameserver 8.8.4.4 
nameserver 2001:4860:4860::8888 
nameserver 2001:4860:4860::8844
EOF