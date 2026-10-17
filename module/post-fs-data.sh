#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR

. "$MODDIR/common.sh"

prepare_trust_store || exit 0
hybrid_mount_register >/dev/null 2>&1 || true

exit 0
