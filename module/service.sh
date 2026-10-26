#!/system/bin/sh

exec >> /data/local/tmp/adguardcert.log
exec 2>&1

MODDIR=${0%/*}

AG_CERT_HASH=0f4ed297
APEX_CERT_DIR=/apex/com.android.conscrypt/cacerts
MIRROR_DIR=${MODDIR}/apex-cacerts

has_mount() {
    grep -Fq " ${APEX_CERT_DIR} " "/proc/$1/mountinfo" 2>/dev/null
}

inject_mount() {
    nsenter --mount=/proc/$1/ns/mnt -- \
        /bin/mount --bind "${MIRROR_DIR}" "${APEX_CERT_DIR}" \
        || echo "Failed to inject certificate store into PID $1"
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

# The monitor only makes sense if post-fs-data.sh staged a valid certificate
# store. If it did not (e.g. AdGuard's certificate is not installed, or the
# safety check failed), there is nothing to inject.
[ -d "${APEX_CERT_DIR}" ] || exit 0
[ -f "${MIRROR_DIR}/${AG_CERT_HASH}.0" ] || exit 0
[ "$(ls -1 "${MIRROR_DIR}" | wc -l)" -gt 10 ] || exit 0

# Check for pid 1
has_mount 1 || inject_mount 1

# late_start service runs in parallel with the boot, so zygote may not be started yet
while [ -z "$(pgrep zygote)" ] && [ -z "$(pgrep zygote64)" ]; do
    sleep 1
done

for pid in $(pgrep zygote) $(pgrep zygote64); do
    has_mount $pid && continue

    inject_mount $pid
    # Children that unshared their mount namespace before the injection miss the mount
    for child in $(child_pids $pid); do
        has_mount $child || inject_mount $child
    done
done
