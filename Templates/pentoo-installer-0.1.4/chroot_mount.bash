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
