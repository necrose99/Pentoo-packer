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