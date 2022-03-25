#!/system/bin/sh
MODDIR=${0%/*}

# Android hashes the subject to get the filename, field order is significant
# AdGuard certificate is /C=EN/O=AdGuard/CN=AdGuard Personal CA
# The filename is then <hash>.<n> where <n> is an integer
AG_CERT_HASH=0f4ed297
cp -f /data/misc/user/*/cacerts-added/${AG_CERT_HASH}.* $MODDIR/system/etc/security/cacerts
chown -R 0:0 $MODDIR/system/etc/security/cacerts

[ "$(getenforce)" = "Enforcing" ] || exit 0

default_selinux_context=u:object_r:system_file:s0
selinux_context=$(ls -Zd /system/etc/security/cacerts | awk '{print $1}')

if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
    chcon -R $selinux_context $MODDIR/system/etc/security/cacerts
else
    chcon -R $default_selinux_context $MODDIR/system/etc/security/cacerts
fi
