#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR

. "$MODDIR/common.sh"

prepare_trust_store || exit 0
hybrid_mount_register >/dev/null 2>&1 || true

if ! verify_visibility; then
    mount_targets_current_ns
    mount_targets_other_namespaces
fi

if verify_visibility; then
    status_write "ready" "verified"
else
    status_write "degraded" "late-verify-failed"
fi

exit 0
