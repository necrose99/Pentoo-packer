# chroot_umount()
# tears down chroot in target system
#
chroot_umount()
{
    umount $DESTDIR/proc
    umount $DESTDIR/sys
    umount $DESTDIR/dev
}