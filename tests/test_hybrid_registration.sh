#!/bin/sh
set -eu

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

MODDIR=$ROOT/module
STATE=$ROOT/state
CLI=$ROOT/hybrid-mount
CALLS=$ROOT/calls

mkdir -p "$MODDIR" "$STATE"

cat > "$CLI" <<'SCRIPT'
#!/bin/sh
echo "$*" >> "$CALLS"
case "$*" in
    "api version")
        exit 0
        ;;
    api\ config-patch*)
        exit 0
        ;;
    api\ modules-apply*)
        exit 0
        ;;
esac
exit 1
SCRIPT
chmod +x "$CLI"

export MODDIR
export CALLS
export ADGUARDCERT_STATE_DIR="$STATE"
export HYBRID_MOUNT_CLI="$CLI"

. ./module/common.sh

hybrid_mount_register

test -f "$MODDIR/magic"
grep -q 'api config-patch --apply-runtime' "$CALLS"
grep -q 'system/etc/security/cacerts' "$CALLS"
grep -q 'apex/com.android.conscrypt/cacerts' "$CALLS"
grep -q 'api modules-apply \["adguardcert"\]' "$CALLS"
grep -q '^status=registered$' "$STATE/hybrid.status"

echo "hybrid registration test passed"
