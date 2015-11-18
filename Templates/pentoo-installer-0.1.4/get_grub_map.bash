get_grub_map() {
    [ -e /tmp/dev.map ] && rm /tmp/dev.map
    DIALOG --infobox "Generating GRUB device map...\nThis could take a while.\n\n Please be patient." 0 0
    $DESTDIR/sbin/grub --no-floppy --device-map /tmp/dev.map >/tmp/grub.log 2>&1 <<EOF
quit
EOF
}