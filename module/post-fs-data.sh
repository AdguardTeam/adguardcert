#!/system/bin/sh

exec > /data/local/tmp/adguardcert.log
exec 2>&1

set -x

MODDIR=${0%/*}

set_context() {
    [ "$(getenforce)" = "Enforcing" ] || return 0

    default_selinux_context=u:object_r:system_file:s0
    selinux_context=$(ls -Zd $1 | awk '{print $1}')

    if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
        chcon -R $selinux_context $2
    else
        chcon -R $default_selinux_context $2
    fi
}

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

if ! [ -e "${AG_CERT_FILE}" ]; then
    # Drop the certificates staged on the previous boot so a removed
    # certificate is not kept alive in the system and APEX stores.
    rm -rf ${MODDIR}/apex-cacerts
    rm -f ${MODDIR}/system/etc/security/cacerts/${AG_CERT_HASH}.*
    exit 0
fi

rm -f /data/misc/user/*/cacerts-removed/${AG_CERT_HASH}.*

cp -f ${AG_CERT_FILE} ${MODDIR}/system/etc/security/cacerts/${AG_CERT_HASH}.0
chown -R 0:0 ${MODDIR}/system/etc/security/cacerts
set_context /system/etc/security/cacerts ${MODDIR}/system/etc/security/cacerts

# Android 14 support
# Since Magisk ignore /apex for module file injections, use non-Magisk way
if [ -d /apex/com.android.conscrypt/cacerts ]; then
    # Clone directory into the module folder
    rm -rf ${MODDIR}/apex-cacerts
    mkdir -p ${MODDIR}/apex-cacerts
    cp -f /apex/com.android.conscrypt/cacerts/* ${MODDIR}/apex-cacerts/

    # Do the same as in Magisk module
    cp -f ${AG_CERT_FILE} ${MODDIR}/apex-cacerts/${AG_CERT_HASH}.0
    chown -R 0:0 ${MODDIR}/apex-cacerts
    set_context /apex/com.android.conscrypt/cacerts ${MODDIR}/apex-cacerts

    # Mount directory inside APEX if it is valid.
    CERTS_NUM="$(ls -1 ${MODDIR}/apex-cacerts | wc -l)"
    if [ "$CERTS_NUM" -gt 10 ]; then
        mount --bind ${MODDIR}/apex-cacerts /apex/com.android.conscrypt/cacerts
        for pid in 1 $(pgrep zygote) $(pgrep zygote64); do
            grep -Fq " /apex/com.android.conscrypt/cacerts " /proc/${pid}/mountinfo 2>/dev/null && continue
            nsenter --mount=/proc/${pid}/ns/mnt -- \
                /bin/mount --bind ${MODDIR}/apex-cacerts /apex/com.android.conscrypt/cacerts
        done
    else
        echo "Cancelling replacing CA storage due to safety"
        rm -rf ${MODDIR}/apex-cacerts
    fi
fi
