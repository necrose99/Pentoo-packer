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