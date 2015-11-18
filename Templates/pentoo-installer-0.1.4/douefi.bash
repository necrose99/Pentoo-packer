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
