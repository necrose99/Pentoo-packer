#!/bin/bash

set -e 

echo 3 | emerge  i rsync
rsync -aqz --exclude='mnt' --exclude='proc' --exclude='sys' --exclude='dev' --exclude='tmp' / /mnt/pentoo || die
