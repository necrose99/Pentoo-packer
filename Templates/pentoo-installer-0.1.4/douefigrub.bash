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