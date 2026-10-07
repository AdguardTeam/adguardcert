#!/system/bin/sh

exec >> /data/local/tmp/adguardcert.log
exec 2>&1

MODDIR=${0%/*}

AG_CERT_HASH=0f4ed297
APEX_CERT_DIR=/apex/com.android.conscrypt/cacerts
MIRROR_DIR=${MODDIR}/apex-cacerts
CHECK_INTERVAL=5

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" "$@"
}

# Checks whether the certificate store is already mounted in the mount
# namespace of the process $1.
has_mount() {
    grep -Fq " ${APEX_CERT_DIR} " "/proc/$1/mountinfo" 2>/dev/null
}

# Binds the staged certificate store into the mount namespace of the process $1.
inject_mount() {
    nsenter --mount=/proc/$1/ns/mnt -- \
        /bin/mount --bind "${MIRROR_DIR}" "${APEX_CERT_DIR}"
}

# Lists PIDs whose parent is $1.
child_pids() {
    children="$(ps -o pid,ppid 2>/dev/null | awk -v parent="$1" '$1 ~ /^[0-9]+$/ && $2 == parent { print $1 }')"
    if [ -z "$children" ]; then
        # Fallback for the old ps (columns: USER PID PPID ...).
        children="$(ps 2>/dev/null | awk -v parent="$1" '$2 ~ /^[0-9]+$/ && $3 == parent { print $2 }')"
    fi
    echo "$children"
}

# Injects the certificate store into the mount namespace of $1 unless it is
# already there.
repair_pid() {
    has_mount "$1" && return 0

    log "Injecting certificate store into PID $1"
    inject_mount "$1" || log "Failed to inject certificate store into PID $1"
}

# Re-injects the certificate store into zygote processes that do not have it.
# This covers zygotes started after post-fs-data.sh has run (e.g. after a
# restart), since apps forked from a repaired zygote inherit the mount.
monitor_zygote() {
    while true; do
        for pid in 1 $(pidof zygote zygote64); do
            has_mount "$pid" && continue

            repair_pid "$pid"

            # PID 1 is excluded: every other process is its child.
            [ "$pid" = "1" ] && continue

            # Children that unshared their mount namespace before the
            # injection need to be repaired individually.
            for child in $(child_pids "$pid"); do
                repair_pid "$child"
            done
        done

        sleep $CHECK_INTERVAL
    done
}

# The monitor only makes sense if post-fs-data.sh staged a valid certificate
# store. If it did not (e.g. AdGuard's certificate is not installed, or the
# safety check failed), there is nothing to inject.
[ -d "${APEX_CERT_DIR}" ] || exit 0
[ -f "${MIRROR_DIR}/${AG_CERT_HASH}.0" ] || exit 0
[ "$(ls -1 "${MIRROR_DIR}" | wc -l)" -gt 10 ] || exit 0

log "Monitoring zygote mount namespaces"
monitor_zygote &
