#!/system/bin/sh

MODDIR=${MODDIR:-${0%/*}}
MODULE_ID=${ADGUARDCERT_MODULE_ID:-adguardcert}

STATE_DIR=${ADGUARDCERT_STATE_DIR:-/data/adb/adguardcert}
CONFIG_FILE=$STATE_DIR/config.sh
STATUS_FILE=$STATE_DIR/status
CACHE_FILE=$STATE_DIR/cache
HYBRID_STATUS_FILE=$STATE_DIR/hybrid.status
RUN_CERT_DIR=$STATE_DIR/cacerts
STALE_RUN_CERT_PREFIX=$STATE_DIR/cacerts-

DATA_MISC_USER_DIR=${ADGUARDCERT_DATA_MISC_USER_DIR:-/data/misc/user}
SYSTEM_CERT_DIR=${ADGUARDCERT_SYSTEM_CERT_DIR:-/system/etc/security/cacerts}
APEX_ROOT_DIR=${ADGUARDCERT_APEX_ROOT_DIR:-/apex}
APEX_CERT_DIR=${ADGUARDCERT_APEX_CERT_DIR:-$APEX_ROOT_DIR/com.android.conscrypt/cacerts}
MODULE_SYSTEM_CERT_DIR=$MODDIR/system/etc/security/cacerts
MODULE_APEX_CERT_DIR=$MODDIR/apex/com.android.conscrypt/cacerts

PERSONAL_HASHES=${PERSONAL_HASHES:-"0f4ed297 14944648"}
INTERMEDIATE_HASHES=${INTERMEDIATE_HASHES:-"47ec1af8"}
MIN_CERT_COUNT=${MIN_CERT_COUNT:-10}
HYBRID_MOUNT_CLI=${HYBRID_MOUNT_CLI:-}
RUNTIME_CHILD_NAMESPACE_MOUNTS=${RUNTIME_CHILD_NAMESPACE_MOUNTS:-1}

[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

SELECTED_CERT=
SELECTED_HASH=
SELECTED_SIG=
SELECTED_USER=
SELECTED_MTIME=
SELECTED_SUBJECT=
SELECTED_ISSUER=
SELECTION_REASON=
CANDIDATE_COUNT=0
BASE_SIG=

bb_path() {
    for bin in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /data/adb/ap/bin/busybox; do
        [ -x "$bin" ] && {
            echo "$bin"
            return 0
        }
    done
    command -v busybox 2>/dev/null
}

bb() {
    bin=$(bb_path)
    if [ -n "$bin" ]; then
        "$bin" "$@"
        return $?
    fi
    "$@"
}

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_sdk() {
    getprop ro.build.version.sdk 2>/dev/null || echo unknown
}

status_write() {
    mkdir -p "$STATE_DIR" 2>/dev/null
    {
        echo "status=$1"
        echo "detail=$2"
        echo "cert=$SELECTED_CERT"
        echo "hash=$SELECTED_HASH"
        echo "sha256=$SELECTED_SIG"
        echo "user=$SELECTED_USER"
        echo "candidates=$CANDIDATE_COUNT"
        echo "sdk=$(get_sdk)"
        echo "time=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
    } > "$STATUS_FILE"
}

hybrid_status_write() {
    mkdir -p "$STATE_DIR" 2>/dev/null
    {
        echo "status=$1"
        echo "detail=$2"
        echo "time=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
    } > "$HYBRID_STATUS_FILE"
}

list_has() {
    for item in $1; do
        [ "$item" = "$2" ] && return 0
    done
    return 1
}

cert_hash_from_path() {
    cert_base=${1##*/}
    echo "${cert_base%%.*}"
}

cert_index_from_path() {
    cert_base=${1##*/}
    cert_index=${cert_base##*.}
    case "$cert_index" in
        ""|*[!0-9]*) echo 0 ;;
        *) echo "$cert_index" ;;
    esac
}

cert_user_from_path() {
    cert_path=$1
    rel=${cert_path#"$DATA_MISC_USER_DIR"/}
    echo "${rel%%/*}"
}

cert_file_has() {
    grep -aq "$2" "$1" 2>/dev/null
}

cert_openssl_info() {
    cert=$1
    cmd_exists openssl || return 1
    openssl x509 -inform DER -in "$cert" -noout -subject -issuer 2>/dev/null && return 0
    openssl x509 -inform PEM -in "$cert" -noout -subject -issuer 2>/dev/null
}

cert_field() {
    cert_openssl_info "$1" | sed -n "s/^$2=//p" | head -n 1
}

cert_subject() {
    cert_field "$1" subject
}

cert_issuer() {
    cert_field "$1" issuer
}

cert_probe_text() {
    cert_openssl_info "$1" 2>/dev/null
    cert_file_has "$1" "AdGuard" && echo "AdGuard"
    cert_file_has "$1" "Personal" && echo "Personal"
    cert_file_has "$1" "Intermediate" && echo "Intermediate"
    cert_file_has "$1" "CA" && echo "CA"
}

cert_mentions_adguard() {
    cert_probe_text "$1" | grep -qi "AdGuard"
}

cert_mentions_intermediate() {
    subject=$(cert_subject "$1")
    echo "$subject" | grep -qi "Intermediate" && return 0
    cert_file_has "$1" "AdGuard Personal Intermediate" && return 0
    cert_file_has "$1" "Personal Intermediate" && cert_file_has "$1" "AdGuard" && return 0
    return 1
}

cert_is_intermediate() {
    cert_hash=$(cert_hash_from_path "$1")
    list_has "$INTERMEDIATE_HASHES" "$cert_hash" && cert_mentions_adguard "$1" && return 0
    cert_mentions_adguard "$1" && cert_mentions_intermediate "$1" && return 0
    return 1
}

cert_is_personal() {
    cert_hash=$(cert_hash_from_path "$1")
    cert_is_intermediate "$1" && return 1
    list_has "$PERSONAL_HASHES" "$cert_hash" && cert_mentions_adguard "$1" && return 0
    probe=$(cert_probe_text "$1")
    echo "$probe" | grep -qi "AdGuard" || return 1
    echo "$probe" | grep -qi "Personal" || return 1
    echo "$probe" | grep -qi "CA" || return 1
    return 0
}

sha256_file() {
    bb sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

count_files() {
    count=0
    for file in "$1"/*; do
        [ -f "$file" ] || continue
        count=$((count + 1))
    done
    echo "$count"
}

remove_stale_runtime_dirs() {
    for dir in "$STALE_RUN_CERT_PREFIX"*; do
        [ -d "$dir" ] || continue
        rm -rf "$dir" 2>/dev/null || true
    done
}

dir_signature() {
    [ -d "$1" ] || return 1
    {
        for file in "$1"/*; do
            [ -f "$file" ] || continue
            sig=$(sha256_file "$file")
            [ -n "$sig" ] && echo "$sig  ${file##*/}"
        done
    } | bb sort 2>/dev/null | bb sha256sum 2>/dev/null | awk '{print $1}'
}

stat_mtime() {
    mtime=$(bb stat -c '%Y' "$1" 2>/dev/null)
    case "$mtime" in
        ""|*[!0-9]*) echo 0 ;;
        *) echo "$mtime" ;;
    esac
}

find_adguard_cert() {
    SELECTED_CERT=
    SELECTED_HASH=
    SELECTED_SIG=
    SELECTED_USER=
    SELECTED_MTIME=
    SELECTED_SUBJECT=
    SELECTED_ISSUER=
    SELECTION_REASON=
    CANDIDATE_COUNT=0
    best_mtime=0
    best_index=0

    for cert in "$DATA_MISC_USER_DIR"/*/cacerts-added/*; do
        [ -f "$cert" ] || continue
        cert_is_personal "$cert" || continue

        CANDIDATE_COUNT=$((CANDIDATE_COUNT + 1))
        cert_mtime=$(stat_mtime "$cert")
        cert_index=$(cert_index_from_path "$cert")

        if [ -z "$SELECTED_CERT" ] || [ "$cert_mtime" -gt "$best_mtime" ] || {
            [ "$cert_mtime" -eq "$best_mtime" ] && [ "$cert_index" -gt "$best_index" ]
        }; then
            SELECTED_CERT=$cert
            SELECTED_HASH=$(cert_hash_from_path "$cert")
            SELECTED_USER=$(cert_user_from_path "$cert")
            SELECTED_MTIME=$cert_mtime
            best_mtime=$cert_mtime
            best_index=$cert_index
        fi
    done

    [ -n "$SELECTED_CERT" ] || return 1
    SELECTED_SIG=$(sha256_file "$SELECTED_CERT")
    [ -n "$SELECTED_SIG" ] || SELECTED_SIG=unknown
    SELECTED_SUBJECT=$(cert_subject "$SELECTED_CERT")
    SELECTED_ISSUER=$(cert_issuer "$SELECTED_CERT")
    SELECTION_REASON=newest-mtime-highest-index
    return 0
}

copy_cert_files() {
    src_dir=$1
    dst_dir=$2

    cp -f "$src_dir"/* "$dst_dir"/ 2>/dev/null && return 0

    for cert in "$src_dir"/*; do
        [ -f "$cert" ] || continue
        cp -f "$cert" "$dst_dir/" || return 1
    done
    return 0
}

reset_dir() {
    rm -rf "$1" 2>/dev/null
    mkdir -p "$1"
}

apply_cert_permissions() {
    ref_dir=$1
    dst_dir=$2

    dir_owner=$(ls -ldn "$ref_dir" 2>/dev/null | awk 'NR==1 {print $3 ":" $4}')
    file_owner=$(ls -ln "$ref_dir"/* 2>/dev/null | awk 'NR==1 {print $3 ":" $4}')
    selinux_context=$(ls -Zd "$ref_dir" 2>/dev/null | awk 'NR==1 {print $1}')

    [ -n "$dir_owner" ] || dir_owner=0:0
    [ -n "$file_owner" ] || file_owner=$dir_owner
    [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ] || selinux_context=u:object_r:system_security_cacerts_file:s0

    chown "$dir_owner" "$dst_dir" 2>/dev/null
    chmod 0755 "$dst_dir" 2>/dev/null

    chown "$file_owner" "$dst_dir"/* 2>/dev/null || true
    chmod 0644 "$dst_dir"/* 2>/dev/null || true

    if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
        chcon -R "$selinux_context" "$dst_dir" 2>/dev/null || true
    fi
}

prune_adguard_certs() {
    dst_dir=$1

    for hash in $PERSONAL_HASHES $INTERMEDIATE_HASHES "$SELECTED_HASH"; do
        [ -n "$hash" ] || continue
        rm -f "$dst_dir"/"$hash".* 2>/dev/null
    done
}

build_cert_dir() {
    src_dir=$1
    dst_dir=$2

    [ -d "$src_dir" ] || return 1
    [ "$(count_files "$src_dir")" -gt "$MIN_CERT_COUNT" ] || return 1

    reset_dir "$dst_dir" || return 1
    copy_cert_files "$src_dir" "$dst_dir" || return 1
    prune_adguard_certs "$dst_dir"
    cp -f "$SELECTED_CERT" "$dst_dir/$SELECTED_HASH.0" || return 1
    apply_cert_permissions "$src_dir" "$dst_dir"
    return 0
}

module_mirrors_ready() {
    [ -f "$MODULE_SYSTEM_CERT_DIR/$SELECTED_HASH.0" ] || return 1
    if [ -d "$APEX_CERT_DIR" ]; then
        [ -f "$MODULE_APEX_CERT_DIR/$SELECTED_HASH.0" ] || return 1
    fi
    return 0
}

mirrors_ready() {
    module_mirrors_ready || return 1
    [ -f "$RUN_CERT_DIR/$SELECTED_HASH.0" ] || return 1
    return 0
}

mountpoint_uses_module_dir() {
    mountpoint=$1
    module_fragment="/$MODULE_ID/"

    awk -v mountpoint="$mountpoint" -v module_fragment="$module_fragment" '
        $5 == mountpoint && index($4, module_fragment) { found = 1 }
        END { exit found ? 0 : 1 }
    ' /proc/self/mountinfo 2>/dev/null
}

store_uses_module_dirs() {
    mountpoint_uses_module_dir "$SYSTEM_CERT_DIR" && return 0
    [ -d "$APEX_CERT_DIR" ] && mountpoint_uses_module_dir "$APEX_CERT_DIR" && return 0
    return 1
}

prepare_trust_store() {
    mkdir -p "$STATE_DIR" 2>/dev/null

    if ! find_adguard_cert; then
        status_write "missing" "adguard-personal-ca-not-found"
        return 1
    fi

    if [ -d "$APEX_CERT_DIR" ] && [ "$(count_files "$APEX_CERT_DIR")" -gt "$MIN_CERT_COUNT" ]; then
        primary_source=$APEX_CERT_DIR
    else
        primary_source=$SYSTEM_CERT_DIR
    fi

    system_source=$SYSTEM_CERT_DIR
    [ -d "$system_source" ] && [ "$(count_files "$system_source")" -gt "$MIN_CERT_COUNT" ] || system_source=$primary_source

    system_sig=$(dir_signature "$system_source")
    apex_sig=
    if [ -d "$APEX_CERT_DIR" ]; then
        apex_sig=$(dir_signature "$APEX_CERT_DIR")
    fi
    BASE_SIG="$system_source:$system_sig|$APEX_CERT_DIR:$apex_sig"
    cache_sig="$SELECTED_HASH:$SELECTED_SIG:$BASE_SIG"

    if store_uses_module_dirs && module_mirrors_ready; then
        if [ ! -f "$RUN_CERT_DIR/$SELECTED_HASH.0" ]; then
            if [ -d "$MODULE_APEX_CERT_DIR" ]; then
                build_cert_dir "$MODULE_APEX_CERT_DIR" "$RUN_CERT_DIR" || {
                    status_write "failed" "runtime-store-stage-failed"
                    return 1
                }
            else
                build_cert_dir "$MODULE_SYSTEM_CERT_DIR" "$RUN_CERT_DIR" || {
                    status_write "failed" "runtime-store-stage-failed"
                    return 1
                }
            fi
        fi
        remove_stale_runtime_dirs
        echo "$cache_sig" > "$CACHE_FILE"
        status_write "ready" "cached-mounted"
        return 0
    fi

    if [ -f "$CACHE_FILE" ] && [ "$(cat "$CACHE_FILE" 2>/dev/null)" = "$cache_sig" ] && mirrors_ready; then
        remove_stale_runtime_dirs
        status_write "ready" "cached"
        return 0
    fi

    build_cert_dir "$system_source" "$MODULE_SYSTEM_CERT_DIR" || {
        status_write "failed" "system-store-stage-failed"
        return 1
    }

    if [ -d "$APEX_CERT_DIR" ]; then
        build_cert_dir "$APEX_CERT_DIR" "$MODULE_APEX_CERT_DIR" || {
            status_write "failed" "apex-store-stage-failed"
            return 1
        }
        build_cert_dir "$APEX_CERT_DIR" "$RUN_CERT_DIR" || {
            status_write "failed" "runtime-store-stage-failed"
            return 1
        }
    else
        build_cert_dir "$system_source" "$RUN_CERT_DIR" || {
            status_write "failed" "runtime-store-stage-failed"
            return 1
        }
    fi

    rm -f "$DATA_MISC_USER_DIR"/*/cacerts-removed/"$SELECTED_HASH".* 2>/dev/null
    remove_stale_runtime_dirs
    echo "$cache_sig" > "$CACHE_FILE"
    status_write "ready" "staged"
    return 0
}

ensure_hybrid_magic_marker() {
    [ -d "$MODDIR" ] || return 1
    [ -e "$MODDIR/magic" ] || [ -e "$MODDIR/overlay" ] || : > "$MODDIR/magic" 2>/dev/null || return 1
    return 0
}

hybrid_mount_module_present() {
    [ -d /data/adb/modules/hybrid_mount ] && return 0
    [ -d /data/adb/modules/meta-hybrid_mount ] && return 0
    [ -d /data/adb/modules_update/hybrid_mount ] && return 0
    [ -d /data/adb/modules_update/meta-hybrid_mount ] && return 0
    [ -d /data/adb/metamodule ] && return 0
    return 1
}

hybrid_mount_cli() {
    [ -n "$HYBRID_MOUNT_CLI" ] && [ -x "$HYBRID_MOUNT_CLI" ] && {
        "$HYBRID_MOUNT_CLI" api version >/dev/null 2>&1 && {
            echo "$HYBRID_MOUNT_CLI"
            return 0
        }
    }

    for cli in \
        /data/adb/metamodule/hybrid-mount \
        /data/adb/modules/hybrid_mount/hybrid-mount \
        /data/adb/modules/meta-hybrid_mount/hybrid-mount \
        /data/adb/modules_update/hybrid_mount/hybrid-mount \
        /data/adb/modules_update/meta-hybrid_mount/hybrid-mount
    do
        [ -x "$cli" ] || [ -f "$cli" ] || continue
        "$cli" api version >/dev/null 2>&1 || continue
        echo "$cli"
        return 0
    done

    if command -v hybrid-mount >/dev/null 2>&1 && hybrid-mount api version >/dev/null 2>&1; then
        command -v hybrid-mount
        return 0
    fi

    return 1
}

hybrid_mount_available() {
    hybrid_mount_cli >/dev/null 2>&1 && return 0
    hybrid_mount_module_present
}

hybrid_mount_patch() {
    printf '%s\n' '{"rules":{"adguardcert":{"default_mode":"magic","paths":{"system/etc/security/cacerts":"magic","apex/com.android.conscrypt/cacerts":"magic"}}}}'
}

hybrid_mount_register() {
    ensure_hybrid_magic_marker >/dev/null 2>&1 || true

    cli=$(hybrid_mount_cli 2>/dev/null)
    if [ -z "$cli" ]; then
        if hybrid_mount_module_present; then
            hybrid_status_write "registered" "magic-marker"
            return 0
        fi
        hybrid_status_write "unavailable" "hybrid-mount-not-found"
        return 1
    fi

    patch=$(hybrid_mount_patch)
    if "$cli" api config-patch --apply-runtime "$patch" >/dev/null 2>&1 || \
        "$cli" api config-patch --patch "$patch" --apply-runtime >/dev/null 2>&1; then
        "$cli" api modules-apply '["adguardcert"]' >/dev/null 2>&1 || \
            "$cli" api modules-apply --modules '["adguardcert"]' >/dev/null 2>&1 || true
        hybrid_status_write "registered" "api-config-patch"
        return 0
    fi

    if "$cli" api config-patch "$patch" >/dev/null 2>&1 || \
        "$cli" api config-patch --patch "$patch" >/dev/null 2>&1; then
        "$cli" api modules-apply '["adguardcert"]' >/dev/null 2>&1 || \
            "$cli" api modules-apply --modules '["adguardcert"]' >/dev/null 2>&1 || true
        hybrid_status_write "registered" "api-config-patch-deferred"
        return 0
    fi

    hybrid_status_write "failed" "api-config-patch-failed"
    return 1
}

apex_mount_source() {
    if hybrid_mount_available && [ -d "$MODULE_APEX_CERT_DIR" ]; then
        echo "$MODULE_APEX_CERT_DIR"
    else
        echo "$RUN_CERT_DIR"
    fi
}

bind_mount_dir() {
    src=$1
    dst=$2

    [ -d "$src" ] || return 1
    [ -d "$dst" ] || return 0
    bb mount -o bind "$src" "$dst" 2>/dev/null || {
        bb umount -l "$dst" 2>/dev/null || true
        bb mount -o bind "$src" "$dst" 2>/dev/null || return 1
    }
    bb mount -o remount,bind,ro "$dst" 2>/dev/null || true
    return 0
}

have_nsenter() {
    bb nsenter --help >/dev/null 2>&1
}

bind_mount_dir_in_ns() {
    pid=$1
    src=$2
    dst=$3

    [ -d "$src" ] || return 1
    [ -d "$dst" ] || return 0
    [ -r "/proc/$pid/ns/mnt" ] || return 0
    have_nsenter || return 0
    bb nsenter --mount="/proc/$pid/ns/mnt" -- mount -o bind "$src" "$dst" 2>/dev/null || {
        bb nsenter --mount="/proc/$pid/ns/mnt" -- umount -l "$dst" 2>/dev/null || true
        bb nsenter --mount="/proc/$pid/ns/mnt" -- mount -o bind "$src" "$dst" 2>/dev/null || return 1
    }
    bb nsenter --mount="/proc/$pid/ns/mnt" -- mount -o remount,bind,ro "$dst" 2>/dev/null || true
    return 0
}

versioned_apex_dirs() {
    for dir in "$APEX_ROOT_DIR"/com.android.conscrypt@*/cacerts; do
        [ -d "$dir" ] || continue
        echo "$dir"
    done
}

pidof_name() {
    pidof "$1" 2>/dev/null
}

child_pids_for_parent() {
    parent=$1
    ps -A 2>/dev/null | awk -v parent="$parent" '
        NR > 1 {
            pid = $2
            ppid = $3
            if ($1 ~ /^[0-9]+$/) {
                pid = $1
                ppid = $2
            }
            if (ppid == parent) print pid
        }
    '
}

zygote_child_pids() {
    [ "$RUNTIME_CHILD_NAMESPACE_MOUNTS" = "1" ] || return 0

    for name in zygote zygote64 zygote_next webview_zygote; do
        for pid in $(pidof_name "$name"); do
            child_pids_for_parent "$pid"
        done
    done
}

target_pids() {
    echo 1
    pidof_name zygote
    pidof_name zygote64
    pidof_name zygote_next
    pidof_name webview_zygote
    pidof_name system_server
    zygote_child_pids
}

mount_targets_current_ns() {
    apex_src=$(apex_mount_source)

    if [ -d "$SYSTEM_CERT_DIR" ] && [ -d "$MODULE_SYSTEM_CERT_DIR" ]; then
        bind_mount_dir "$MODULE_SYSTEM_CERT_DIR" "$SYSTEM_CERT_DIR" || true
    fi

    if [ -d "$APEX_CERT_DIR" ]; then
        bind_mount_dir "$apex_src" "$APEX_CERT_DIR" || true
        for apex_dir in $(versioned_apex_dirs); do
            bind_mount_dir "$apex_src" "$apex_dir" || true
        done
    fi
}

mount_targets_other_namespaces() {
    apex_src=$(apex_mount_source)

    seen=
    for pid in $(target_pids); do
        case " $seen " in
            *" $pid "*) continue ;;
        esac
        seen="$seen $pid"

        if [ -d "$SYSTEM_CERT_DIR" ] && [ -d "$MODULE_SYSTEM_CERT_DIR" ]; then
            bind_mount_dir_in_ns "$pid" "$MODULE_SYSTEM_CERT_DIR" "$SYSTEM_CERT_DIR" || true
        fi

        if [ -d "$APEX_CERT_DIR" ]; then
            bind_mount_dir_in_ns "$pid" "$apex_src" "$APEX_CERT_DIR" || true
            for apex_dir in $(versioned_apex_dirs); do
                bind_mount_dir_in_ns "$pid" "$apex_src" "$apex_dir" || true
            done
        fi
    done
}

cert_visible_in_dir() {
    [ -n "$SELECTED_HASH" ] || return 1
    [ -f "$1/$SELECTED_HASH.0" ]
}

cert_visible_in_pid_dir() {
    pid=$1
    path=$2

    [ -n "$SELECTED_HASH" ] || return 1
    [ -d "/proc/$pid/root$path" ] || return 2
    [ -f "/proc/$pid/root$path/$SELECTED_HASH.0" ]
}

store_visibility_current() {
    if [ -d "$APEX_CERT_DIR" ]; then
        cert_visible_in_dir "$APEX_CERT_DIR" || {
            echo not_visible
            return 1
        }
        for apex_dir in $(versioned_apex_dirs); do
            cert_visible_in_dir "$apex_dir" || {
                echo not_visible
                return 1
            }
        done
        echo visible
        return 0
    fi

    cert_visible_in_dir "$SYSTEM_CERT_DIR" && echo visible && return 0
    echo not_visible
    return 1
}

store_visibility_pid() {
    pid=$1

    [ -d "/proc/$pid/root" ] || {
        echo unavailable
        return 2
    }

    if [ -d "/proc/$pid/root$APEX_CERT_DIR" ]; then
        cert_visible_in_pid_dir "$pid" "$APEX_CERT_DIR" && {
            echo visible
            return 0
        }
        echo not_visible
        return 1
    fi

    if [ -d "/proc/$pid/root$SYSTEM_CERT_DIR" ]; then
        cert_visible_in_pid_dir "$pid" "$SYSTEM_CERT_DIR" && {
            echo visible
            return 0
        }
        echo not_visible
        return 1
    fi

    echo unavailable
    return 2
}

verify_visibility() {
    [ "$(store_visibility_current)" = "visible" ]
}

package_pids() {
    pkg=$1
    pidof "$pkg" 2>/dev/null
    ps -A 2>/dev/null | awk -v p="$pkg" '
        NR > 1 {
            pid = $2
            if ($1 ~ /^[0-9]+$/) pid = $1
            name = $NF
            if (name == p || index(name, p ":") == 1) print pid
        }
    '
}

package_target_sdk() {
    dumpsys package "$1" 2>/dev/null | sed -n 's/.*targetSdk=\([0-9][0-9]*\).*/\1/p' | head -n 1
}

package_uid() {
    dumpsys package "$1" 2>/dev/null | sed -n 's/.*userId=\([0-9][0-9]*\).*/\1/p' | head -n 1
}

mountinfo_has_path() {
    pid=$1
    path=$2
    [ -r "/proc/$pid/mountinfo" ] || return 2
    grep -q " $path " "/proc/$pid/mountinfo" 2>/dev/null
}

mountinfo_has_hybrid_source() {
    pid=$1
    [ -r "/proc/$pid/mountinfo" ] || return 2
    grep -q '/mnt/hm_' "/proc/$pid/mountinfo" 2>/dev/null
}

pid_mount_state() {
    pid=$1
    path=$2
    if mountinfo_has_path "$pid" "$path"; then
        echo mounted
        return 0
    fi
    echo absent
    return 1
}

pid_hybrid_state() {
    pid=$1
    if mountinfo_has_hybrid_source "$pid"; then
        echo visible
        return 0
    fi
    echo hidden
    return 1
}
