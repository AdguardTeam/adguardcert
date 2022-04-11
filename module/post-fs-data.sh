#!/system/bin/sh
MODDIR=${0%/*}

# Android hashes the subject to get the filename, field order is significant.
# AdGuard certificate is "/C=EN/O=AdGuard/CN=AdGuard Personal CA".
# The filename is then <hash>.<n> where <n> is an integer to disambiguate
# different certs with the same hash (e.g. when the same cert is installed repeteadly).
#
# Due to https://github.com/AdguardTeam/AdguardForAndroid/issues/2108
# 1. Take the last cert with our hash from the user store.
# 2. Copy it to the system store under the name "<hash>.0".
# 3. Remove the copied cert from `cacerts-removed`.
AG_CERT_HASH=0f4ed297
AG_CERT_FILE=$(ls /data/misc/user/*/cacerts-added/${AG_CERT_HASH}.* | sort | tail -n1)
cp -f ${AG_CERT_FILE} ${MODDIR}/system/etc/security/cacerts/${AG_CERT_HASH}.0
chown -R 0:0 ${MODDIR}/system/etc/security/cacerts
rm -f /data/misc/user/*/cacerts-removed/${AG_CERT_HASH}.0

[ "$(getenforce)" = "Enforcing" ] || exit 0

default_selinux_context=u:object_r:system_file:s0
selinux_context=$(ls -Zd /system/etc/security/cacerts | awk '{print $1}')

if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
    chcon -R $selinux_context $MODDIR/system/etc/security/cacerts
else
    chcon -R $default_selinux_context $MODDIR/system/etc/security/cacerts
fi
