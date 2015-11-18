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