#!/bin/sh
set -eu

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

MODDIR=$ROOT/module
STATE=$ROOT/state
USER_ROOT=$ROOT/data/misc/user
SYSTEM_CERTS=$ROOT/system/etc/security/cacerts
APEX_ROOT=$ROOT/apex
APEX_CERTS=$APEX_ROOT/com.android.conscrypt/cacerts

mkdir -p "$MODDIR" "$STATE" "$USER_ROOT/0/cacerts-added" "$SYSTEM_CERTS" "$APEX_CERTS"
mkdir -p "$STATE/cacerts-123-stale"

export MODDIR
export ADGUARDCERT_STATE_DIR="$STATE"
export ADGUARDCERT_DATA_MISC_USER_DIR="$USER_ROOT"
export ADGUARDCERT_SYSTEM_CERT_DIR="$SYSTEM_CERTS"
export ADGUARDCERT_APEX_ROOT_DIR="$APEX_ROOT"
export ADGUARDCERT_APEX_CERT_DIR="$APEX_CERTS"
export MIN_CERT_COUNT=1

for dir in "$SYSTEM_CERTS" "$APEX_CERTS"; do
    printf 'stock-root-a\n' > "$dir/11111111.0"
    printf 'stock-root-b\n' > "$dir/22222222.0"
    printf 'CN=AdGuard Personal Intermediate CA\n' > "$dir/47ec1af8.0"
done

printf 'CN=AdGuard Personal CA\n' > "$USER_ROOT/0/cacerts-added/0f4ed297.0"
printf 'CN=AdGuard Personal Intermediate CA\n' > "$USER_ROOT/0/cacerts-added/47ec1af8.0"
printf 'CN=Other Test CA\n' > "$USER_ROOT/0/cacerts-added/deadbeef.0"

. ./module/common.sh

prepare_trust_store

test -f "$MODDIR/system/etc/security/cacerts/0f4ed297.0"
test -f "$MODDIR/apex/com.android.conscrypt/cacerts/0f4ed297.0"
test -f "$STATE/cacerts/0f4ed297.0"

test ! -f "$MODDIR/system/etc/security/cacerts/47ec1af8.0"
test ! -f "$MODDIR/apex/com.android.conscrypt/cacerts/47ec1af8.0"
test ! -f "$STATE/cacerts/47ec1af8.0"
test ! -f "$MODDIR/system/etc/security/cacerts/deadbeef.0"
test ! -f "$MODDIR/apex/com.android.conscrypt/cacerts/deadbeef.0"

test -f "$MODDIR/system/etc/security/cacerts/11111111.0"
test -f "$MODDIR/apex/com.android.conscrypt/cacerts/22222222.0"
test ! -d "$STATE/cacerts-123-stale"

grep -q '^status=ready$' "$STATE/status"
grep -q '^candidates=1$' "$STATE/status"

echo "staging test passed"
