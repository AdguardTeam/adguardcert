#!/system/bin/sh
MODDIR=${0%/*}

cp -f /data/misc/user/*/cacerts-added/* $MODDIR/system/etc/security/cacerts
chown -R 0:0 $MODDIR/system/etc/security/cacerts

[ "$(getenforce)" = "Enforcing" ] || exit 0

default_selinux_context=u:object_r:system_file:s0
selinux_context=$(ls -Zd /system/etc/security/cacerts | awk '{print $1}')

if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
    chcon -R $selinux_context $MODDIR/system/etc/security/cacerts
else
    chcon -R $default_selinux_context $MODDIR/system/etc/security/cacerts
fi
