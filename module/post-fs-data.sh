#!/system/bin/sh
MODDIR=${0%/*}

# Android hashes the subject to get the filename, field order is significant.
# (`openssl x509 -in ... -noout -hash`)
# AdGuard's certificate is "/C=EN/O=AdGuard/CN=AdGuard Personal CA".
# The filename is then <hash>.<n> where <n> is an integer to disambiguate
# different certs with the same hash (e.g. when the same cert is installed repeatedly).
# 
# Due to https://github.com/AdguardTeam/AdguardForAndroid/issues/2108
# 1. Retrieve the most recent certificate with our hash from the user store.
#    It is assumed that the last installed AdGuard's cert is the correct one.
# 2. Copy the AdGuard certificate to the system store under the name "<hash>.0". 
#    Note that some apps may ignore other certs.
# 3. Remove all certs with our hash from the `cacerts-removed` directory.
#    They get there if a certificate is "disabled" in the security settings.
#    Apps will reject certs that are in the `cacerts-removed`.
AG_CERT_HASH=0f4ed297
AG_CERT_FILE=$(ls /data/misc/user/*/cacerts-added/${AG_CERT_HASH}.* | (IFS=.; while read -r left right; do echo $right $left.$right; done) | sort -nr | (read -r left right; echo $right))

if [ -e "${AG_CERT_FILE}" ]; then
    cp -f ${AG_CERT_FILE} ${MODDIR}/system/etc/security/cacerts/${AG_CERT_HASH}.0
    rm -f /data/misc/user/*/cacerts-removed/${AG_CERT_HASH}.*
fi

chown -R 0:0 ${MODDIR}/system/etc/security/cacerts

[ "$(getenforce)" = "Enforcing" ] || exit 0

default_selinux_context=u:object_r:system_file:s0
selinux_context=$(ls -Zd /system/etc/security/cacerts | awk '{print $1}')

if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
    chcon -R $selinux_context $MODDIR/system/etc/security/cacerts
else
    chcon -R $default_selinux_context $MODDIR/system/etc/security/cacerts
fi
