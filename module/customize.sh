#!/system/bin/sh

MODDIR=${MODPATH:-${0%/*}}
export MODDIR

[ -f "$MODDIR/common.sh" ] || exit 0
. "$MODDIR/common.sh"

ensure_hybrid_magic_marker >/dev/null 2>&1 || true
hybrid_mount_register >/dev/null 2>&1 || true

exit 0
