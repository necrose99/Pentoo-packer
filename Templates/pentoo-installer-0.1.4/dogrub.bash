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


EOF