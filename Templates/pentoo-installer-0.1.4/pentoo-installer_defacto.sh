#!/bin/bash
# This script is released under the GNU General Public License 3.0
# Check the COPYING file included with this distribution

## start by exiting if the user doesn't have enough RAM for the install to work

ANSWER="/tmp/.setup"
TITLE="Pentoo Installation"
# use the first VT not dedicated to a running console
LOG="/dev/tty8"
DESTDIR="/mnt/gentoo"
EDITOR=
PARTITIONEDITOR=

# clock
HARDWARECLOCK=
TIMEZONE=

# partitions
PART_ROOT=

# default filesystem specs (the + is bootable flag)
# <mountpoint>:<partsize>:<fstype>[:+]
DEFAULTFS="/boot:64:ext2:+ swap:4096:swap /:*:ext4"

# install stages
S_CLOCK=0       # clock and timezone
S_PART=0        # partitioning
S_MKFS=0        # formatting
S_MKFSAUTO=0    # auto fs part/formatting TODO: kill this
S_CONFIG=0      # configuration editing
S_GRUB=0        # TODO: kill this - if using grub
S_BOOT=""       # bootloader installed (set to loader name instead of 1)


# main menu selection tracker
CURRENT_SELECTION=""

# DIALOG()
# an el-cheapo dialog wrapper
#
# parameters: see dialog(1)
# returns: whatever dialog did
DIALOG() {
    dialog --backtitle "$TITLE" --aspect 15 "$@"
    return $?
}

# chroot_mount()
# prepares target system as a chroot
#
chroot_mount()
{
    [ -e "${DESTDIR}/sys" ] || mkdir "${DESTDIR}/sys"
    [ -e "${DESTDIR}/proc" ] || mkdir "${DESTDIR}/proc"
    [ -e "${DESTDIR}/dev" ] || mkdir "${DESTDIR}/dev"
    mount -t sysfs sysfs "${DESTDIR}/sys"
    mount -t proc proc "${DESTDIR}/proc"
    mount -o bind /dev "${DESTDIR}/dev"
}

# chroot_umount()
# tears down chroot in target system
#
chroot_umount()
{
    umount $DESTDIR/proc
    umount $DESTDIR/sys
    umount $DESTDIR/dev
}

finddisks() {
    workdir="$PWD"
    cd /sys/block
    # ide devices
    for dev in $(ls | egrep '^hd'); do
        if [ "$(cat $dev/device/media)" = "disk" ]; then
            echo "/dev/$dev"
            [ "$1" ] && echo $1
        fi
    done
    #scsi/sata devices
    for dev in $(ls | egrep '^sd'); do
        # TODO: what is the significance of 5?
        if ! [ "$(cat $dev/device/type)" = "5" ]; then
            echo "/dev/$dev"
            [ "$1" ] && echo $1
        fi
    done
    #virtual devices
    for dev in $(ls | egrep '^vd'); do
        # TODO: how to check if this is really a disk?
        if [ "$(grep -c 'DEVTYPE=disk' $dev/uevent)" = "1" ]; then
            echo "/dev/$dev"
            [ "$1" ] && echo $1
        fi
    done
    # cciss controllers
    if [ -d /dev/cciss ] ; then
        cd /dev/cciss
        for dev in $(ls | egrep -v 'p'); do
            echo "/dev/cciss/$dev"
            [ "$1" ] && echo $1
        done
    fi
    # Smart 2 controllers
    if [ -d /dev/ida ] ; then
        cd /dev/ida
        for dev in $(ls | egrep -v 'p'); do
            echo "/dev/ida/$dev"
            [ "$1" ] && echo $1
        done
    fi
    cd "$workdir"
}

# getuuid()
# converts /dev/[hs]d?[0-9] devices to UUIDs
#
# parameters: device file
# outputs:    UUID on success
#             nothing on failure
# returns:    nothing
getuuid()
{
    if [ "${1%%/[hs]d?[0-9]}" != "${1}" ]; then
        echo "$(blkid -s UUID -o value ${1})"
    fi
}

# getkernelversion()
# outputs the kernel version
#
# parameters: none
# outputs:    kernel version on success
#             nothing on failure
# returns:    0 on success
#             1 on failure
getkernelversion()
{
    local kernver=$(ls $DESTDIR/boot/kernel-genkernel-* |sed -e "s|kernel-genkernel||g" -e "s|$DESTDIR/boot/||") \
        || return 1
    echo "${kernver}"
}

findpartitions() {
    workdir="$PWD"
    for devpath in $(finddisks); do
        disk=$(echo $devpath | sed 's|.*/||')
        cd /sys/block/$disk
        for part in $disk*; do
            # check if not already assembled to a raid device
            if ! [ "$(cat /proc/mdstat 2>/dev/null | grep $part)" -o "$(fstype 2>/dev/null </dev/$part | grep "lvm2")" -o "$(sfdisk -c /dev/$disk $(echo $part | sed -e "s#$disk##g") 2>/dev/null | grep "5")" ]; then
                if [ -d $part ]; then
                    echo "/dev/$part"
                    [ "$1" ] && echo $1
                fi
            fi
        done
    done
    # include any mapped devices
    for devpath in $(ls /dev/mapper 2>/dev/null | grep -v control); do
        echo "/dev/mapper/$devpath"
        [ "$1" ] && echo $1
    done
    # include any raid md devices
    for devpath in $(ls -d /dev/md* | grep '[0-9]' 2>/dev/null); do
        if cat /proc/mdstat | grep -qw $(echo $devpath | sed -e 's|/dev/||g'); then
        echo "$devpath"
        [ "$1" ] && echo $1
        fi
    done
    # inlcude cciss controllers
    if [ -d /dev/cciss ] ; then
        cd /dev/cciss
        for dev in $(ls | egrep 'p'); do
            echo "/dev/cciss/$dev"
            [ "$1" ] && echo $1
        done
    fi
    # inlcude Smart 2 controllers
    if [ -d /dev/ida ] ; then
        cd /dev/ida
        for dev in $(ls | egrep 'p'); do
            echo "/dev/ida/$dev"
            [ "$1" ] && echo $1
        done
    fi
    cd "$workdir"
}

get_grub_map() {
    [ -e /tmp/dev.map ] && rm /tmp/dev.map
    DIALOG --infobox "Generating GRUB device map...\nThis could take a while.\n\n Please be patient." 0 0
    $DESTDIR/sbin/grub --no-floppy --device-map /tmp/dev.map >/tmp/grub.log 2>&1 <<EOF
quit
EOF
}

mapdev() {
    partition_flag=0
    device_found=0
    devs=$(cat /tmp/dev.map | grep -v fd | sed 's/ *\t/ /' | sed ':a;$!N;$!ba;s/\n/ /g')
    linuxdevice=$(echo $1 | cut -b1-8)
    if [ "$(echo $1 | egrep '[0-9]$')" ]; then
        # /dev/hdXY
        pnum=$(echo $1 | cut -b9-)
        pnum=$(($pnum-1))
        partition_flag=1
    fi
    for  dev in $devs
    do
        if [ "(" = $(echo $dev | cut -b1) ]; then
        grubdevice="$dev"
        else
        if [ "$dev" = "$linuxdevice" ]; then
            device_found=1
            break
        fi
       fi
    done
    if [ "$device_found" = "1" ]; then
        if [ "$partition_flag" = "0" ]; then
            echo "$grubdevice"
        else
            grubdevice_stringlen=${#grubdevice}
            grubdevice_stringlen=$(($grubdevice_stringlen - 1))
            grubdevice=$(echo $grubdevice | cut -b1-$grubdevice_stringlen)
            echo "$grubdevice,$pnum)"
        fi
    else
        echo "DEVICE NOT FOUND"
    fi
}

printk()
{
    case $1 in
        "on")  echo 4 >/proc/sys/kernel/printk ;;
        "off") echo 0 >/proc/sys/kernel/printk ;;
    esac
}

# geteditor()
# prompts the user to choose an editor
# sets EDITOR global variable
#
geteditor() {
    DIALOG --menu "Select a Text Editor to Use" 10 35 3 \
        "1" "nano (easier)" \
        "2" "vi" 2>$ANSWER
    case $(cat $ANSWER) in
        "1") EDITOR="nano" ;;
        "2") EDITOR="vi" ;;
        *)   EDITOR="nano" ;;
    esac
}

# setpartitionlabel()
# select and write partition layout
# parameters: device
# sets PARTITIONEDITOR global variable
#
setpartitionlabel() {
    while true; do
        local pt=
        DIALOG --menu "Select a Partition Table to Use" 10 35 3 \
            "1" "msdos (default)" \
            "2" "gpt (unsupported)" 2>$ANSWER
        [ "${ANSWER}" = "" ] && pt='msdos'
        case "$(cat $ANSWER)" in
            "1")
                PARTITIONEDITOR="cfdisk"
                pt='msdos' ;;
            "2")
                PARTITIONEDITOR="cgdisk"
                pt='gpt' ;;
            *) return 1 ;;
        esac
        # Check current partition layout
        local cpt=$(parted $1 print | sed -nr 's/^Partition Table:\s(.*)/\1/p')
        if [ "${pt}" != "${cpt}" ]; then
            DIALOG --defaultno --yesno "$1 will be COMPLETELY ERASED!  Are you absolutely sure?" 0 0 \
                || continue
            parted $1 mklabel "${pt}" || continue
        fi
        break
    done
}

# _mkfs()
# Create and mount filesystems in our destination system directory.
#
# args:
#  domk: Whether to make the filesystem or use what is already there
#  device: Device filesystem is on
#  fstype: type of filesystem located at the device (or what to create)
#  dest: Mounting location for the destination system
#  mountpoint: Mount point inside the destination system, e.g. '/boot'

# returns: 1 on failure
_mkfs() {
    local _domk=$1
    local _device=$2
    local _fstype=$3
    local _dest=$4
    local _mountpoint=$5
    echo "$@" >> $LOG
    # we have two main cases: "swap" and everything else.
    if [ "${_fstype}" = "swap" ]; then
        swapoff ${_device} >/dev/null 2>&1
        if [ "${_domk}" = "yes" ]; then
            mkswap ${_device} >>$LOG 2>&1
            if [ $? != 0 ]; then
                DIALOG --msgbox "Error creating swap: mkswap ${_device}" 0 0
                return 1
            fi
        fi
        swapon ${_device} >>$LOG 2>&1
        if [ $? != 0 ]; then
            DIALOG --msgbox "Error activating swap: swapon ${_device}" 0 0
            return 1
        fi
    else
        # make sure the fstype is one we can handle
        local knownfs=0
        for fs in xfs jfs reiserfs ext2 ext3 ext4 vfat; do
            [ "${_fstype}" = "${fs}" ] && knownfs=1 && break
        done
        if [ $knownfs -eq 0 ]; then
            DIALOG --msgbox "unknown fstype ${_fstype} for ${_device}" 0 0
            return 1
        fi
        # if we were tasked to create the filesystem, do so
        if [ "${_domk}" = "yes" ]; then
            local ret
            case ${_fstype} in
                xfs)      mkfs.xfs -f ${_device} >>$LOG 2>&1; ret=$? ;;
                jfs)      yes | mkfs.jfs ${_device} >>$LOG 2>&1; ret=$? ;;
                reiserfs) yes | mkreiserfs ${_device} >>$LOG 2>&1; ret=$? ;;
                ext2)     mke2fs "${_device}" >>$LOG 2>&1; ret=$? ;;
                ext3)     mke2fs -j ${_device} >>$LOG 2>&1; ret=$? ;;
                ext4)     mke2fs -t ext4 ${_device} >$LOG 2>&1; ret=$? ;;
                vfat)     mkfs.vfat ${_device} >>$LOG 2>&1; ret=$? ;;
                # don't handle anything else here, we will error later
            esac
            if [ $ret != 0 ]; then
                DIALOG --msgbox "Error creating filesystem ${_fstype} on ${_device}" 0 0
                return 1
            fi
            sleep 2
        fi
        # create our mount directory
        mkdir -p ${_dest}${_mountpoint}
        # mount the bad boy
        mount -t ${_fstype} ${_device} ${_dest}${_mountpoint} >>$LOG 2>&1
        if [ $? != 0 ]; then
            DIALOG --msgbox "Error mounting ${_dest}${_mountpoint}" 0 0
            return 1
        fi
    fi

    # add to temp fstab
    echo -n "${_device} ${_mountpoint} ${_fstype} defaults 0 " >>/tmp/.fstab

    if [ "${_fstype}" = "swap" ]; then
        echo "0" >>/tmp/.fstab
    else
        echo "1" >>/tmp/.fstab
    fi
}

# Disable swap and all mounted partitions for the destination system. Unmount
# the destination root partition last!
_umountall()
{
    DIALOG --infobox "Disabling swapspace, unmounting already mounted disk devices..." 0 0
    swapoff -a >/dev/null 2>&1
    umount $(mount | grep -v "${DESTDIR} " | grep "${DESTDIR}" | sed 's|\ .*||g') >/dev/null 2>&1
    umount $(mount | grep "${DESTDIR} " | sed 's|\ .*||g') >/dev/null 2>&1
}

# _getdisccapacity()
#
# parameters: device file
# outputs:    disc capacity in bytes
_getdisccapacity()
{
    fdisk -l $1 2>/dev/null | sed -n '2p' | cut -d' ' -f5
}

# Get a list of available disks for use in the "Available disks" dialogs. This
# will print the disks as follows, getting size info from _getdisccapacity():
#   /dev/sda: 625000 MiB (610 GiB)
#   /dev/sdb: 476940 MiB (465 GiB)
_getavaildisks()
{
    for DISC in $(finddisks); do
        DISC_SIZE=$(_getdisccapacity $DISC)
        echo "$DISC: $((DISC_SIZE / 2**20)) MiB ($((DISC_SIZE / 2**30)) GiB)\n"
    done
}

autoprepare()
{
    DISCS=$(finddisks)
    if [ $(echo $DISCS | wc -w) -gt 1 ]; then
        DIALOG --msgbox "Available Disks:\n\n$(_getavaildisks)\n" 0 0
        DIALOG --menu "Select the hard drive to use" 14 55 7 $(finddisks _) 2>$ANSWER || return 1
        DISC=$(cat $ANSWER)
    else
        DISC=$DISCS
    fi
    SET_DEFAULTFS=""
    BOOT_PART_SET=""
    SWAP_PART_SET=""
    ROOT_PART_SET=""
    CHOSEN_FS=""
    # disk size in MiB
    DISC_SIZE=$(($(_getdisccapacity $DISC) / 2**20))
    while [ "$SET_DEFAULTFS" = "" ]; do
        FSOPTS="ext2 ext2 ext3 ext3 ext4 ext4"
        [ "$(which mkreiserfs 2>/dev/null)" ] && FSOPTS="$FSOPTS reiserfs Reiser3"
        [ "$(which mkfs.xfs 2>/dev/null)" ]   && FSOPTS="$FSOPTS xfs XFS"
        [ "$(which mkfs.jfs 2>/dev/null)" ]   && FSOPTS="$FSOPTS jfs JFS"
        while [ "$BOOT_PART_SET" = "" ]; do
            DIALOG --inputbox "Enter the size (MiB) of your /boot partition.  Minimum value is 16.\n\nDisk space left: $DISC_SIZE MiB" 10 65 "64" 2>$ANSWER || return 1
            BOOT_PART_SIZE="$(cat $ANSWER)"
            if [ "$BOOT_PART_SIZE" = "" ]; then
                DIALOG --msgbox "ERROR: You have entered an invalid size, please enter again." 0 0
            else
                if [ "$BOOT_PART_SIZE" -ge "$DISC_SIZE" -o "$BOOT_PART_SIZE" -lt "16" -o "$SBOOT_PART_SIZE" = "$DISC_SIZE" ]; then
                    DIALOG --msgbox "ERROR: You have entered a too large size, please enter again." 0 0
                else
                    BOOT_PART_SET=1
                fi
            fi
        done
        DISC_SIZE=$(($DISC_SIZE-$BOOT_PART_SIZE))
        while [ "$SWAP_PART_SET" = "" ]; do
            SUGGESTED_SWAP_SIZE=$(awk '/MemTotal/ {printf( "%.0f\n", int ( $2 / 1024 ) + 1)}' /proc/meminfo)
            DIALOG --inputbox "Enter the size (MiB) of your swap partition.  Minimum value is > 0.\n\nDisk space left: $DISC_SIZE MiB" 10 65 "${SUGGESTED_SWAP_SIZE}" 2>$ANSWER || return 1
            SWAP_PART_SIZE=$(cat $ANSWER)
            if [ "$SWAP_PART_SIZE" = "" -o  "$SWAP_PART_SIZE" -le "0" ]; then
                DIALOG --msgbox "ERROR: You have entered an invalid size, please enter again." 0 0
            else
                if [ "$SWAP_PART_SIZE" -ge "$DISC_SIZE" ]; then
                    DIALOG --msgbox "ERROR: You have entered a too large size, please enter again." 0 0
                else
                    SWAP_PART_SET=1
                fi
            fi
        done
        DISC_SIZE=$(($DISC_SIZE-$SWAP_PART_SIZE))
        while [ "$ROOT_PART_SET" = "" ]; do
            if [ "${DISC_SIZE}" -lt "8200" ]; then
                DIALOG --msgbox "Pentoo requires at least 8.2GB for / and you don't have that much left, aborting install." 0 0
                exit 1
            elif [ "${DISC_SIZE}" -lt "24000" ]; then
                DIALOG --msgbox "Pentoo *suggests* using at least 24GB for your / partition but you don't have that much left. You have been warned." 0 0
            fi
            DIALOG --msgbox "${DISC_SIZE} MiB will be used for your / partition." 0 0 && ROOT_PART_SET=1
        done
        while [ "$CHOSEN_FS" = "" ]; do
            DIALOG --menu "Select a filesystem for /" 13 45 6 $FSOPTS 2>$ANSWER || return 1
            FSTYPE=$(cat $ANSWER)
            DIALOG --yesno "$FSTYPE will be used for /. Is this OK?" 0 0 && CHOSEN_FS=1
        done
        SET_DEFAULTFS=1
    done

    DIALOG --defaultno --yesno "$DISC will be COMPLETELY ERASED!  Are you absolutely sure?" 0 0 \
    || return 1

    DEVICE=$DISC
    FSSPECS=$(echo $DEFAULTFS | sed -e "s|/:\*:ext4|/:$ROOT_PART_SIZE:$FSTYPE|g" -e "s|swap:4096|swap:$SWAP_PART_SIZE|g" -e "s|/boot:64|/boot:$BOOT_PART_SIZE|g")
    sfdisk_input=""

    # we assume a /dev/hdX format (or /dev/sdX)
    PART_ROOT="${DEVICE}3"

    if [ "$S_MKFS" = "1" ]; then
        DIALOG --msgbox "You have already prepared your filesystems manually" 0 0
        return 0
    fi

    # validate DEVICE
    if [ ! -b "$DEVICE" ]; then
      DIALOG --msgbox "Device '$DEVICE' is not valid" 0 0
      return 1
    fi

    # validate DEST
    if [ ! -d "$DESTDIR" ]; then
        DIALOG --msgbox "Destination directory '$DESTDIR' is not valid" 0 0
        return 1
    fi

    # / required
    if [ $(echo $FSSPECS | grep '/:' | wc -l) -ne 1 ]; then
        DIALOG --msgbox "Need exactly one root partition" 0 0
        return 1
    fi

    rm -f /tmp/.fstab

    _umountall

    # setup input var for sfdisk
    for fsspec in $FSSPECS; do
        fssize=$(echo $fsspec | tr -d ' ' | cut -f2 -d:)
        if [ "$fssize" = "*" ]; then
                fssize_spec=';'
        else
                fssize_spec=",$fssize"
        fi
        fstype=$(echo $fsspec | tr -d ' ' | cut -f3 -d:)
        if [ "$fstype" = "swap" ]; then
                fstype_spec=",S"
        else
                fstype_spec=","
        fi
        bootflag=$(echo $fsspec | tr -d ' ' | cut -f4 -d:)
        if [ "$bootflag" = "+" ]; then
            bootflag_spec=",*"
        else
            bootflag_spec=""
        fi
        sfdisk_input="${sfdisk_input}${fssize_spec}${fstype_spec}${bootflag_spec}\n"
    done
    sfdisk_input=$(printf "$sfdisk_input")

    # invoke sfdisk
    printk off
    DIALOG --infobox "Partitioning $DEVICE" 0 0
    sfdisk $DEVICE -uM >$LOG 2>&1 <<EOF
$sfdisk_input
EOF
    if [ $? -gt 0 ]; then
        DIALOG --msgbox "Error partitioning $DEVICE (see $LOG for details)" 0 0
        printk on
        return 1
    fi
    printk on

    # need to mount root first, then do it again for the others
    part=1
    for fsspec in $FSSPECS; do
        mountpoint=$(echo $fsspec | tr -d ' ' | cut -f1 -d:)
        fstype=$(echo $fsspec | tr -d ' ' | cut -f3 -d:)
        if echo $mountpoint | tr -d ' ' | grep '^/$' 2>&1 > /dev/null; then
            _mkfs yes ${DEVICE}${part} "$fstype" "$DESTDIR" "$mountpoint" || return 1
        fi
        part=$(($part + 1))
    done

    # make other filesystems
    part=1
    for fsspec in $FSSPECS; do
        mountpoint=$(echo $fsspec | tr -d ' ' | cut -f1 -d:)
        fstype=$(echo $fsspec | tr -d ' ' | cut -f3 -d:)
        if [ $(echo $mountpoint | tr -d ' ' | grep '^/$' | wc -l) -eq 0 ]; then
            _mkfs yes ${DEVICE}${part} "$fstype" "$DESTDIR" "$mountpoint" || return 1
        fi
        part=$(($part + 1))
    done

    DIALOG --msgbox "Auto-prepare was successful" 0 0
    S_MKFSAUTO=1
}

partition() {
    if [ "$S_MKFSAUTO" = "1" ]; then
        DIALOG --msgbox "You have already prepared your filesystems with Auto-prepare" 0 0
        return 0
    fi

    _umountall

    # Select disk to partition
    DISCS=$(finddisks _)
    DISCS="$DISCS OTHER - DONE +"
    DIALOG --msgbox "Available Disks:\n\n$(_getavaildisks)\n" 0 0
    DISC=""
    while true; do
        # Prompt the user with a list of known disks
        DIALOG --menu "Select the disk you want to partition (select DONE when finished)" 14 55 7 $DISCS 2>$ANSWER || return 1
        DISC=$(cat $ANSWER)
        if [ "$DISC" = "OTHER" ]; then
            DIALOG --inputbox "Enter the full path to the device you wish to partition" 8 65 "/dev/sda" 2>$ANSWER || return 1
            DISC=$(cat $ANSWER)
        fi
        # Leave our loop if the user is done partitioning
        [ "$DISC" = "DONE" ] && break
        # Set partition layout and partition editor PARTITIONEDITOR
        setpartitionlabel $DISC || continue
        # Partition disc
        DIALOG --msgbox "Now you'll be put into the ${PARTITIONEDITOR} program where you can partition your hard drive. You should make a swap partition and as many data partitions as you will need.  NOTE: ${PARTITIONEDITOR} may tell you to reboot after creating partitions.  If you need to reboot, just re-enter this install program, skip this step and go on to step 2." 18 70
        $PARTITIONEDITOR $DISC
    done
    S_PART=1
}

mountpoints() {
    if [ "$S_MKFSAUTO" = "1" ]; then
        DIALOG --msgbox "You have already prepared your filesystems with Auto-prepare" 0 0
        return 0
    fi
    while [ "$PARTFINISH" != "DONE" ]; do
        : >/tmp/.fstab
        : >/tmp/.parts

        # Determine which filesystems are available
        FSOPTS="ext2 ext2 ext3 ext3 ext4 ext4"
        [ "$(which mkreiserfs 2>/dev/null)" ] && FSOPTS="$FSOPTS reiserfs Reiser3"
        [ "$(which mkfs.xfs 2>/dev/null)" ]   && FSOPTS="$FSOPTS xfs XFS"
        [ "$(which mkfs.jfs 2>/dev/null)" ]   && FSOPTS="$FSOPTS jfs JFS"
        [ "$(which mkfs.vfat 2>/dev/null)" ]  && FSOPTS="$FSOPTS vfat VFAT"

        # Select mountpoints
        DIALOG --msgbox "Available Disks:\n\n$(_getavaildisks)\n" 0 0
        PARTS=$(findpartitions _)
        DIALOG --menu "Select the partition to use as swap" 21 50 13 NONE - $PARTS 2>$ANSWER || return 1
        PART=$(cat $ANSWER)
        PARTS="$(echo $PARTS | sed -e "s#${PART}\ _##g")"
        if [ "$PART" != "NONE" ]; then
            DOMKFS="no"
            DIALOG --yesno "Would you like to create a filesystem on $PART?\n\n(This will overwrite existing data!)" 0 0 && DOMKFS="yes"
            echo "$PART:swap:swap:$DOMKFS" >>/tmp/.parts
        fi

        DIALOG --menu "Select the partition to mount as /" 21 50 13 $PARTS 2>$ANSWER || return 1
        PART=$(cat $ANSWER)
        PARTS="$(echo $PARTS | sed -e "s#${PART}\ _##g")"
        PART_ROOT=$PART
        # Select root filesystem type
        DIALOG --menu "Select a filesystem for $PART" 13 45 6 $FSOPTS 2>$ANSWER || return 1
        FSTYPE=$(cat $ANSWER)
        DOMKFS="no"
        DIALOG --yesno "Would you like to create a filesystem on $PART?\n\n(This will overwrite existing data!)" 0 0 && DOMKFS="yes"
        echo "$PART:$FSTYPE:/:$DOMKFS" >>/tmp/.parts

        #
        # Additional partitions
        #
        DIALOG --menu "Select any additional partitions to mount under your new root (select DONE when finished)" 21 50 13 $PARTS DONE _ 2>$ANSWER || return 1
        PART=$(cat $ANSWER)
        while [ "$PART" != "DONE" ]; do
            PARTS="$(echo $PARTS | sed -e "s#${PART}\ _##g")"
            # Select a filesystem type
            DIALOG --menu "Select a filesystem for $PART" 13 45 6 $FSOPTS 2>$ANSWER || return 1
            FSTYPE=$(cat $ANSWER)
            MP=""
            while [ "${MP}" = "" ]; do
                DIALOG --inputbox "Enter the mountpoint for $PART" 8 65 "/boot" 2>$ANSWER || return 1
                MP=$(cat $ANSWER)
                if grep ":$MP:" /tmp/.parts; then
                    DIALOG --msgbox "ERROR: You have defined 2 identical mountpoints! Please select another mountpoint." 8 65
                    MP=""
                fi
            done
            DOMKFS="no"
            DIALOG --yesno "Would you like to create a filesystem on $PART?\n\n(This will overwrite existing data!)" 0 0 && DOMKFS="yes"
            echo "$PART:$FSTYPE:$MP:$DOMKFS" >>/tmp/.parts
            DIALOG --menu "Select any additional partitions to mount under your new root" 21 50 13 $PARTS DONE _ 2>$ANSWER || return 1
            PART=$(cat $ANSWER)
        done
        DIALOG --yesno "Would you like to create and mount the filesytems like this?\n\nSyntax\n------\nDEVICE:TYPE:MOUNTPOINT:FORMAT\n\n$(for i in $(cat /tmp/.parts); do echo "$i\n";done)" 18 0 && PARTFINISH="DONE"
    done

    _umountall

    for line in $(cat /tmp/.parts); do
        PART=$(echo $line | cut -d: -f 1)
        FSTYPE=$(echo $line | cut -d: -f 2)
        MP=$(echo $line | cut -d: -f 3)
        DOMKFS=$(echo $line | cut -d: -f 4)
        umount ${DESTDIR}${MP}
        if [ "$DOMKFS" = "yes" ]; then
            if [ "$FSTYPE" = "swap" ]; then
                DIALOG --infobox "Creating and activating swapspace on $PART" 0 0
            else
                DIALOG --infobox "Creating $FSTYPE on $PART, mounting to ${DESTDIR}${MP}" 0 0
            fi
            _mkfs yes $PART $FSTYPE $DESTDIR $MP || return 1
        else
            if [ "$FSTYPE" = "swap" ]; then
                DIALOG --infobox "Activating swapspace on $PART" 0 0
            else
                DIALOG --infobox "Mounting $PART to ${DESTDIR}${MP}" 0 0
            fi
            _mkfs no $PART $FSTYPE $DESTDIR $MP || return 1
        fi
        sleep 1
    done

    DIALOG --msgbox "Partitions were successfully mounted." 0 0
    S_MKFS=1
}

# do_rsync()
# does the rsync
#
# params: none
# returns: 1 on error
do_rsync() {
    DIALOG --infobox "Copy in progress. This may take a while - you can watch the output in the progress window. (ctrl+alt+f8)" 6 45

    rsync -av /mnt/livecd/* ${DESTDIR} 2>&1 >$LOG
    rsync -av /etc/* ${DESTDIR}/etc/ 2>&1 >>$LOG
    rsync -av /root/* ${DESTDIR}/root/ 2>&1 >>$LOG
    rsync -av /usr/portage ${DESTDIR}/usr/ >>$LOG
    rsync -av /var/lib/layman/pentoo ${DESTDIR}/var/lib/layman/ >>$LOG
    if [ $? -ne 0 ]; then
        DIALOG --msgbox "Rsync failed (maybe you're out of disk space?). See the log output for more information"
        return 1
    fi
    sed -i 's#aufs bindist livecd##' ${DESTDIR}/etc/portage/make.conf
    mknod -m666 ${DESTDIR}/dev/zero c 1 5
    mknod -m666 ${DESTDIR}/dev/null c 1 3
    mknod -m600 ${DESTDIR}/dev/console c 5 1
    mkdir -m755 ${DESTDIR}/media/{cd,dvd,fl}

    S_SELECT=1
}

# auto_fstab()
# preprocess fstab file
# comments out old fields and inserts new ones
# according to partitioning/formatting stage
#
auto_fstab()
{
    if [ "$S_MKFS" = "1" -o "$S_MKFSAUTO" = "1" ]; then
        if [ -f /tmp/.fstab ]; then
            # comment out stray /dev entries
            sed -i 's/^\/dev/#\/dev/g' $DESTDIR/etc/fstab
            # append entries from new configuration
            sort /tmp/.fstab >>$DESTDIR/etc/fstab
	    sed -i -e '/aufs/d' $DESTDIR/etc/fstab
        fi
    fi
}

# douefigrub()
# writes kernel to UEFI as new boot option
# parameters:
#     kernelpath: path to kernel, relative to partition root
#     initrdpath: path to initrd
#     bootparams: other boot params for kernel
# returns: 1 on failure
douefigrub() {
    # check if grub2 is installed
    grub2-mkimage -? 2>/dev/null 1>&2
    if [ $? -ne 0 ]; then
        DIALOG --msgbox "Error: Couldn't find grub2-mkimage.  Is GRUB-2 installed?" 0 0
        return 1
    fi
    local kernelpath="${1}"
    local initrdpath="${2}"
    local bootparams="${3}"
    # uefipart: uefi partition, ex. /dev/sda1
    DIALOG --menu "Select the partition to use as UEFI boot partition" 21 50 13 NONE - $PARTS 2>$ANSWER || return 1
    local uefipart=$(cat $ANSWER)
    PARTS="$(echo $PARTS | sed -e "s#${uefipart}\ _##g")"
    [ "$uefipart" = "NONE" ] && return 1
    # grubpart: grub partition, ex. (hd0,2)
    DIALOG --inputbox "Verify your GRUB device path" 8 65 "(hd0,2)" 2>$ANSWER || return 1
    local grubpart=$(cat $ANSWER)
    # uefimount: uefi partition mount point, ex. /boot
    local uefimount="$(mount | grep "^${uefipart} " | cut -d' ' -f 3)"
    # mount if not mounted
    if [ "${uefimount}" = "" ]; then
        mkdir -p /tmp/efibootpart || return 1
        mount "${uefipart}" /tmp/efibootpart || return 1
        uefimount=/tmp/efibootpart
    fi
    # safety check for /EFI/BOOT/BOOTX64.EFI (case insensitive for fat)
    local findefi="$(find "${uefimount}" -iwholename "${uefimount}/efi/boot/bootx64.efi")"
    if [ "${findefi}" != "" ]; then
        DIALOG --msgbox "Error: ${findefi} exists, refusing to overwrite!" 0 0
        return 1
    fi
    # safety check for /boot/grub2 (case insensitive for fat)
    local findgrub2="$(find "${uefimount}" -iwholename "${uefimount}/boot/grub2")"
    if [ "${findgrub2}" != "" ]; then
        DIALOG --msgbox "Error: ${findgrub2} exists, refusing to overwrite!" 0 0
        return 1
    fi
    # create grub image
    mkdir -p "${uefimount}/EFI/BOOT" || return 1
    grub2-mkimage -p /boot/grub2 -o "${uefimount}/EFI/BOOT/BOOTX64.EFI" -O x86_64-efi part_msdos part_gpt fat normal \
        || return 1
    # copy grub modules
    mkdir -p "${uefimount}/boot/grub2" || return 1
    cp -ar /usr/lib/grub/x86_64-efi "${uefimount}/boot/grub2/" \
        || return 1
    # create a crude grug.cfg
    mkdir -p "${uefimount}/boot/grub2" || return 1
    cat >> "${uefimount}/boot/grub2/grub.cfg" <<EOF
timeout=5
menuentry 'Pentoo' {
    insmod efi_gop
    insmod efi_uga
    insmod part_msdos
    insmod part_gpt
    root=${grubpart}
    linux ${kernelpath} ${bootparams}
    initrd ${initrdpath}
}
EOF
    DIALOG --msgbox "UEFI boot image successfully installed. You can now review the GRUB-2 config file." 0 0
    [ "$EDITOR" ] || geteditor
    $EDITOR "${uefimount}/boot/grub2/grub.cfg"
    DIALOG --msgbox "Success: UEFI booting by GRUB-2 installed!" 0 0
}

# douefi()
# writes kernel to UEFI as new boot option
# parameters:
#     kernelpath: path to kernel, relative to partition root
#     initrdpath: path to initrd
#     bootparams: other boot params for kernel
# returns: 1 on failure
#
douefi() {
    modprobe efivars
    # check if booted through UEFI
    efibootmgr -v 2>/dev/null 1>&2
    if [ $? -ne 0 ]; then
        DIALOG --msgbox "Error: Couldn't read from UEFI. Did you boot through UEFI?" 0 0
        return 1
    fi
    # kernel path with \\ instead of /
    local kernelpath=${1//\//\\\\}
    # initrd path with \ instead of /
    local initrdpath=${2//\//\\}
    local bootparams="${3}"
    # kernelpart: kernel partition, ex. /dev/sda2
    DIALOG --menu "Select the partition with the kernel (/boot)" 21 50 13 NONE - $PARTS 2>$ANSWER || return 1
    local kernelpart=$(cat $ANSWER)
    PARTS="$(echo $PARTS | sed -e "s#${kernelpart}\ _##g")"
    [ "$kernelpart" = "NONE" ] && return 1
    # kernelpart as disk and trailing part-number
    local kernelpartnu=$(expr match "${kernelpart}" '.*\([1-9][0-9]*\)')
    local kernelpartdisk=${kernelpart:0: -${#kernelpartnu}}
    # write to UEFI
    echo "${bootparams} initrd=${initrdpath}" | \
        iconv -f ascii -t ucs2 | \
        efibootmgr --create --gpt \
            --disk "${kernelpartdisk}" --part "${kernelpartnu}" \
            --label "Pentoo" \
            --loader "${kernelpath}" \
            --append-binary-args -
    if [ $? -ne 0 ]; then
        DIALOG --msgbox "Error: Couldn't write to UEFI!" 0 0
        return 1
    fi
    DIALOG --msgbox "Success: Direct UEFI booting installed!" 0 0
}

# dobootloader()
# installs boot loader
# parameters:
#     bootmode:
#         - uefigrub: installs GRUB2 UEFI-image plus menu
#         - uefi: boot kernel direclty by UEFI
# returns: 1 on failure
#
dobootloader() {
    local bootmode="${1}"
    local _kernver=$(getkernelversion)
    local kernelpath="/boot/kernel-genkernel${_kernver}"
    local initrdpath="/boot/initramfs-genkernel${_kernver}"
    local bootparams="root=/dev/ram0 real_root=${PART_ROOT}"
    # select UEFI boot partition
    PARTS=$(findpartitions _)
    # compose boot parameters
    # parse kernel cmdline (only video mode for now)
    for _var in $(cat /proc/cmdline); do
        case $_var in
            video=*)
                eval $(echo $_var) ;;
        esac
    done
    bootparams+=" video=${video} console=tty1 ro"
    case "${bootmode}" in
        uefigrub)
            douefigrub "${kernelpath}" "${initrdpath}" "${bootparams}" \
                || return 1
            ;;
        uefi)
            douefi "${kernelpath}" "${initrdpath}" "${bootparams}" \
            || return 1
            ;;
    esac
}

# dogrub()
# installs grub
# params: none
# returns: 1 on failure
dogrub() {
    get_grub_map
    local grubmenu="$DESTDIR/boot/grub/grub.conf"
    rm ${DESTDIR}/boot/grub/menu.lst
    ln -s ./grub.conf ${DESTDIR}/boot/grub/menu.lst
    if [ ! -f $grubmenu ]; then
        DIALOG --msgbox "Error: Couldn't find $grubmenu.  Is GRUB installed?" 0 0
        return 1
    fi
    # try to auto-configure GRUB...
    if [ "$PART_ROOT" != "" -a "$S_GRUB" != "1" ]; then
        grubdev=$(mapdev $PART_ROOT)
        local _rootpart="${PART_ROOT}"
        # look for a separately-mounted /boot partition
        bootdev=$(mount | grep $DESTDIR/boot | cut -d' ' -f 1)
        if [ "$grubdev" != "" -o "$bootdev" != "" ]; then
            subdir=
            if [ "$bootdev" != "" ]; then
                grubdev=$(mapdev $bootdev)
            else
                subdir="/boot"
            fi
            # keep the file from being completely bogus
            if [ "$grubdev" = "DEVICE NOT FOUND" ]; then
                DIALOG --msgbox "Your root boot device could not be autodetected by setup.  Ensure you adjust the 'root (hd0,0)' line in your GRUB config accordingly." 0 0
                grubdev="(hd0,0)"
            fi
            # remove default entries
            sed -i 's/^#splashimage/splashimage/' $grubmenu
            sed -i '/^#/d' $grubmenu
	    # parse kernel cmdline (only video mode for now)
	    for _var in $(cat /proc/cmdline)
	    do
			case $_var in
				video=*)
				eval $(echo $_var)
				;;
			esac
		done
	    # get kernel version
	    local _kernver=$(getkernelversion)
            cat >>$grubmenu <<EOF

# (0) Pentoo
title  Pentoo
root   $grubdev
kernel $subdir/kernel-genkernel${_kernver} root=/dev/ram0 real_root=${_rootpart} ${_cmdline} video=${video} console=tty1 ro
initrd $subdir/initramfs-genkernel${_kernver}

# (2) Windows
#title Windows
#rootnoverify (hd0,0)
#makeactive
#chainloader +1
EOF
        fi
    fi

    DIALOG --msgbox "Before installing GRUB, you must review the configuration file.  You will now be put into the editor.  After you save your changes and exit the editor, you can install GRUB." 0 0
    [ "$EDITOR" ] || geteditor
    $EDITOR $grubmenu

    DEVS=$(finddisks _)
    DEVS="$DEVS $(findpartitions _)"
    if [ "$DEVS" = "" ]; then
        DIALOG --msgbox "No hard drives were found" 0 0
        return 1
    fi
    DIALOG --menu "Select the boot device where the GRUB bootloader will be installed (usually the MBR and not a partition)." 14 55 7 $DEVS 2>$ANSWER || return 1
    ROOTDEV=$(cat $ANSWER)
    DIALOG --infobox "Installing the GRUB bootloader..." 0 0
    if [ -d "${DESTDIR}"/usr/lib/grub/i386-pc ]; then
        cp -a "${DESTDIR}"/usr/lib/grub/i386-pc/* "${DESTDIR}"/boot/grub/
    fi
    sync
    # freeze xfs filesystems to enable grub installation on xfs filesystems
    if [ -x /usr/sbin/xfs_freeze ]; then
        mount | grep $DESTDIR/boot | grep -q xfs && /usr/sbin/xfs_freeze -f $DESTDIR/boot > /dev/null 2>&1
        mount | grep $DESTDIR | grep -q xfs && /usr/sbin/xfs_freeze -f $DESTDIR/ > /dev/null 2>&1
    fi
    # look for a separately-mounted /boot partition
    bootpart=$(mount | grep $DESTDIR/boot | cut -d' ' -f 1)
    if [ "$bootpart" = "" ]; then
        if [ "$PART_ROOT" = "" ]; then
            DIALOG --inputbox "Enter the full path to your root device" 8 65 "/dev/sda3" 2>$ANSWER || return 1
            bootpart=$(cat $ANSWER)
        else
            bootpart=$PART_ROOT
        fi
    fi
    DIALOG --defaultno --yesno "Do you have your system installed on software raid?\nAnswer 'YES' to install grub to another hard disk." 0 0
    if [ $? -eq 0 ]; then
        DIALOG --menu "Please select the boot partition device, this cannot be autodetected!\nPlease redo grub installation for all partitions you need it!" 14 55 7 $DEVS 2>$ANSWER || return 1
        bootpart=$(cat $ANSWER)
    fi
    bootpart=$(mapdev $bootpart)
    bootdev=$(mapdev $ROOTDEV)
    if [ "$bootpart" = "" ]; then
        DIALOG --msgbox "Error: Missing/Invalid root device: $bootpart" 0 0
        return 1
    fi
    if [ "$bootpart" = "DEVICE NOT FOUND" -o "$bootdev" = "DEVICE NOT FOUND" ]; then
        DIALOG --msgbox "GRUB root and setup devices could not be auto-located.  You will need to manually run the GRUB shell to install a bootloader." 0 0
        return 1
    fi
    /sbin/grub-install --no-floppy --recheck --grub-shell=$DESTDIR/sbin/grub --root-directory=$DESTDIR $ROOTDEV >/tmp/grub.log 2>&1
    cat /tmp/grub.log >$LOG
    # unfreeze xfs filesystems
    if [ -x /usr/sbin/xfs_freeze ]; then
        mount | grep $DESTDIR/boot | grep -q xfs && /usr/sbin/xfs_freeze -u $DESTDIR/boot > /dev/null 2>&1
        mount | grep $DESTDIR/boot | grep -q xfs && /usr/sbin/xfs_freeze -u $DESTDIR/ > /dev/null 2>&1
    fi

    if grep "Error [0-9]*: " /tmp/grub.log >/dev/null; then
        DIALOG --msgbox "Error installing GRUB. (see $LOG for output)" 0 0
        return 1
    fi
    DIALOG --msgbox "GRUB was successfully installed." 0 0
    S_GRUB=1
}

# set_clock()
# prompts user to set hardware clock and timezone
#
# params: none
# returns: 1 on failure
set_clock()
{
    # utc or local?
    DIALOG --menu "Is your hardware clock in UTC or local time?" 10 50 2 \
        "UTC" " " \
        "local" " " \
        2>$ANSWER || return 1
    HARDWARECLOCK=$(cat $ANSWER)

    # timezone?
    tzselect > $ANSWER || return 1
    TIMEZONE=$(cat $ANSWER)

    # set system clock from hwclock - stolen from rc.sysinit
    local HWCLOCK_PARAMS=""
    if [ "$HARDWARECLOCK" = "UTC" ]; then
        HWCLOCK_PARAMS="$HWCLOCK_PARAMS --utc"
    else
        HWCLOCK_PARAMS="$HWCLOCK_PARAMS --localtime"
    fi
    if [ "$TIMEZONE" != "" -a -e "/usr/share/zoneinfo/$TIMEZONE" ]; then
        /bin/rm -f /etc/localtime
        /bin/cp "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    fi
    /sbin/hwclock --hctosys $HWCLOCK_PARAMS --noadjfile

    # display and ask to set date/time
    dialog --calendar "Set the date.\nUse <TAB> to navigate and arrow keys to change values." 0 0 0 0 0 2> $ANSWER || return 1
    local _date="$(cat $ANSWER)"
    dialog --timebox "Set the time.\nUse <TAB> to navigate and up/down to change values." 0 0 2> $ANSWER || return 1
    local _time="$(cat $ANSWER)"
    echo "date: $_date time: $_time" >$LOG

    # save the time
    # DD/MM/YYYY hh:mm:ss -> YYYY-MM-DD hh:mm:ss
    local _datetime="$(echo "$_date" "$_time" | sed 's#\(..\)/\(..\)/\(....\) \(..\):\(..\):\(..\)#\3-\2-\1 \4:\5:\6#g')"
    echo "setting date to: $_datetime" >$LOG
    date -s "$_datetime" 2>&1 >$LOG
    /sbin/hwclock --systohc $HWCLOCK_PARAMS --noadjfile

    S_CLOCK=1
}

prepare_harddrive()
{
    S_MKFSAUTO=0
    S_MKFS=0
    DONE=0
    local CURRENT_SELECTION=""
    while [ "$DONE" = "0" ]; do
        if [ -n "$CURRENT_SELECTION" ]; then
            DEFAULT="--default-item $CURRENT_SELECTION"
        else
            DEFAULT=""
        fi
        DIALOG $DEFAULT --menu "Prepare Hard Drive" 12 60 5 \
            "1" "Auto-Prepare (erases the ENTIRE hard drive)" \
            "2" "Manually Partition Hard Drives" \
            "4" "Return to Main Menu" 2>$ANSWER
        CURRENT_SELECTION="$(cat $ANSWER)"
        case $(cat $ANSWER) in
            "1")
                autoprepare && DONE=1;;
            "2")
                partition && PARTFINISH="" 
		mountpoints && DONE=1;;
            *)
                DONE=1 ;;
        esac
    done
}

configure_system()
{
    # must mount chroot so pre/post installs don't fail out
    chroot_mount
    chroot $DESTDIR /bin/bash <<EOF
rc-update del autoconfig default
rc-update add keymaps default
mv /etc/inittab.old /etc/inittab
mv /etc/init.d/halt.sh.orig /etc/init.d/halt.sh
EOF
    # don't need chroot anymore
    chroot_umount

    # ensure the disk is synced
    sync

    # automagic time!
    # any automatic configuration should go here
    DIALOG --infobox "Writing base configuration..." 6 40
    auto_fstab

    [ "$EDITOR" ] || geteditor

    local CURRENT_SELECTION=""
    while true; do
        if [ -n "$CURRENT_SELECTION" ]; then
            DEFAULT="--default-item $CURRENT_SELECTION"
        else
            DEFAULT=""
        fi
        DIALOG $DEFAULT --menu "Configuration" 17 70 10 \
            "/etc/conf.d/keymaps"        "Keymap" \
            "/etc/fstab"                "Filesystem Mountpoints" \
            "/etc/resolv.conf"          "DNS Servers" \
            "/etc/hosts"                "Network Hosts" \
            "/etc/locale.gen"           "Glibc Locales" \
            "Root-Password"             "Set the root password" \
	    "add-user"			"Add a new user" \
            "Return"        "Return to Main Menu" 2>$ANSWER || CURRENT_SELECTION="Return"
        CURRENT_SELECTION="$(cat $ANSWER)"

        if [ "$CURRENT_SELECTION" = "Return" -o -z "$CURRENT_SELECTION" ]; then       # exit
            break
        elif [ "$CURRENT_SELECTION" = "Root-Password" ]; then            # non-file
            while true; do
                chroot ${DESTDIR} passwd root && break
            done
		elif [ "$CURRENT_SELECTION" = "add-user" ]; then
			DIALOG $DEFAULT --inputbox "Enter a username" 17 70 2>$ANSWER
				_username=$(cat $ANSWER)
				chroot ${DESTDIR} useradd -m -G users,wheel,audio,cdrom,video,cdrw,plugdev $_username
				rsync -r --exclude=.svn --exclude=.subversion "${DESTDIR}"/root/.[!.]* "${DESTDIR}"/home/"${_username}"/
				chroot ${DESTDIR} chown -R ${_username}:${_username} /home/$_username
			while true; do
				chroot ${DESTDIR} passwd $_username && break
			done
        else                                                #regular file
            $EDITOR ${DESTDIR}${CURRENT_SELECTION}
        fi
    done

    ## POSTPROCESSING ##

    # /etc/locale.gen
    #
    chroot ${DESTDIR} locale-gen

    # /etc/localtime
    cp /etc/localtime ${DESDIR}/etc/localtime

    ## END POSTPROCESSING ##

    S_CONFIG=1
}

install_bootloader()
{
    DIALOG --colors --menu "Which bootloader would you like to use?  Grub is the Pentoo default.\n\n" \
        12 75 4 \
        "GRUB" "Use the GRUB bootloader (default)" \
        "UEFI-GRUB" "Use GRUB2 and UEFI (unsupported)" \
        "UEFI" "Boot kernel directly by UEFI (unsupported)" \
        "None" "\Zb\Z1Warning\Z0\ZB: you must install your own bootloader!" 2>$ANSWER
    case $(cat $ANSWER) in
        "GRUB") dogrub ;;
        "UEFI-GRUB") dobootloader 'uefigrub' ;;
        "UEFI") dobootloader 'uefi' ;;
    esac
}

mainmenu()
{
    if [ -n "$CURRENT_SELECTION" ]; then
        DEFAULT="--default-item $CURRENT_SELECTION"
    else
        DEFAULT=""
    fi
    DIALOG $DEFAULT --title " MAIN MENU " \
        --menu "Use the UP and DOWN arrows to navigate menus.  Use TAB to switch between buttons and ENTER to select." 16 55 8 \
        "0" "Set Clock" \
        "1" "Prepare Hard Drive" \
	"2" "Copy the Distribution" \
        "3" "Configure System" \
        "4" "Install Bootloader" \
        "5" "Exit Install" 2>$ANSWER
    CURRENT_SELECTION="$(cat $ANSWER)"
    case $(cat $ANSWER) in
        "0")
            set_clock ;;
        "1")
            prepare_harddrive ;;
	"2")
	    do_rsync ;;
        "3")
            configure_system ;;
        "4")
            install_bootloader ;;
        "5")
            echo ""
            echo "If the install finished successfully, you can now type 'reboot'"
            echo "to restart the system."
            echo ""
            exit 0 ;;
        *)
            DIALOG --yesno "Abort Installation?" 6 40 && exit 0
            ;;
    esac
}

#####################
## begin execution ##

RAMSIZE=$(awk '/MemTotal/ {printf( "%.0f\n", int ( $2 / 1024 ) + 1)}' /proc/meminfo)
if [ "$RAMSIZE" -le "1500" ]; then
	DIALOG --msgbox "The Pentoo Installer requires a minimum of 1.5GB of RAM to run. Failing safe." 0 0
	exit 1
fi

DIALOG --msgbox "Welcome to the Pentoo Installation program. The install \
process is fairly straightforward, and you should run through the options in \
the order they are presented. If you are unfamiliar with partitioning/making \
filesystems, you may want to consult some documentation before continuing. \
You can view all output from commands by viewing your VC8 console (ALT-F8). \
ALT-F1 will bring you back here." 14 65

while true; do
    mainmenu
done

exit 0

# vim: set ts=4 sw=4 et:
