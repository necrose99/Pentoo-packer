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