#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR

. "$MODDIR/common.sh"

print_status() {
    echo "AdGuard Certificate"
    echo
    [ -f "$STATUS_FILE" ] && cat "$STATUS_FILE" || echo "status=unknown"
    [ -f "$HYBRID_STATUS_FILE" ] && {
        echo
        sed 's/^/hybrid_/' "$HYBRID_STATUS_FILE"
    }
    echo
    echo "system=$SYSTEM_CERT_DIR"
    [ -d "$APEX_CERT_DIR" ] && echo "apex=$APEX_CERT_DIR"
    for apex_dir in $(versioned_apex_dirs); do
        echo "apex_versioned=$apex_dir"
    done
}

print_cert_details() {
    echo "adguard_personal_ca=found"
    echo "adguard_personal_ca_path=$SELECTED_CERT"
    echo "adguard_personal_ca_hash=$SELECTED_HASH"
    echo "adguard_personal_ca_sha256=$SELECTED_SIG"
    echo "adguard_personal_ca_user=$SELECTED_USER"
    echo "adguard_personal_ca_mtime=$SELECTED_MTIME"
    echo "adguard_personal_ca_candidates=$CANDIDATE_COUNT"
    echo "adguard_personal_ca_selection=$SELECTION_REASON"
    [ -n "$SELECTED_SUBJECT" ] && echo "adguard_personal_ca_subject=$SELECTED_SUBJECT"
    [ -n "$SELECTED_ISSUER" ] && echo "adguard_personal_ca_issuer=$SELECTED_ISSUER"
}

first_pid_for_name() {
    for pid in $(pidof_name "$1"); do
        echo "$pid"
        return 0
    done
    return 1
}

print_runtime_visibility() {
    current=$(store_visibility_current)
    echo "system_store_current=$current"

    for name in zygote zygote64 zygote_next webview_zygote system_server; do
        pid=$(first_pid_for_name "$name")
        if [ -n "$pid" ]; then
            echo "${name}_pid=$pid"
            echo "${name}_namespace=$(store_visibility_pid "$pid")"
            echo "${name}_hybrid_mounts=$(pid_hybrid_state "$pid")"
            echo "${name}_system_etc_mount=$(pid_mount_state "$pid" /system/etc)"
            [ -d "/proc/$pid/root$APEX_CERT_DIR" ] && echo "${name}_conscrypt_mount=$(pid_mount_state "$pid" "$APEX_CERT_DIR")"
        else
            echo "${name}_pid=not_running"
            echo "${name}_namespace=not_running"
        fi
    done
}

first_package_pid() {
    seen=
    for pid in $(package_pids "$1"); do
        case " $seen " in
            *" $pid "*) continue ;;
        esac
        seen="$seen $pid"
        echo "$pid"
        return 0
    done
    return 1
}

doctor_recommendation() {
    app_state=$1
    current_state=$2
    target_sdk=$3

    if [ "$current_state" != "visible" ]; then
        echo "diagnosis=module_mount_missing"
        echo "recommended_fix=run_action_sh_repair_or_reboot"
        return
    fi

    if [ "$app_state" = "not_running" ]; then
        echo "diagnosis=app_not_running"
        echo "recommended_fix=start_target_app_then_rerun_doctor"
        return
    fi

    if [ "$app_state" != "visible" ]; then
        echo "diagnosis=profile_unmounted_or_namespace_miss"
        echo "recommended_fix=keep_this_module_mounted_for_apps_that_need_adguard_https_filtering"
        return
    fi

    if [ -n "$target_sdk" ] && [ "$target_sdk" -ge 37 ] 2>/dev/null; then
        echo "diagnosis=ca_visible_ct_or_pinning_or_custom_trust_possible"
        echo "recommended_fix=check_app_ct_pinning_or_custom_trust_policy"
        return
    fi

    echo "diagnosis=ca_visible"
    echo "recommended_fix=none"
}

run_doctor() {
    pkg=$1

    echo "device_sdk=$(get_sdk)"
    echo "module_id=$MODULE_ID"

    if ! prepare_trust_store >/dev/null 2>&1; then
        if find_adguard_cert >/dev/null 2>&1; then
            print_cert_details
            [ -f "$STATUS_FILE" ] && sed 's/^/prepare_/' "$STATUS_FILE"
            echo "diagnosis=trust_store_prepare_failed"
            echo "recommended_fix=run_action_sh_repair_or_reboot"
            return 1
        else
            echo "adguard_personal_ca=missing"
            echo "diagnosis=adguard_personal_ca_not_found"
            echo "recommended_fix=enable_adguard_https_filtering_and_install_its_certificate_to_user_store_then_reboot"
            return 1
        fi
    fi

    hybrid_mount_register >/dev/null 2>&1 || true
    print_cert_details
    print_runtime_visibility

    [ -f "$HYBRID_STATUS_FILE" ] && sed 's/^/hybrid_/' "$HYBRID_STATUS_FILE"

    if [ -z "$pkg" ]; then
        current=$(store_visibility_current)
        if [ "$current" = "visible" ]; then
            echo "diagnosis=base_namespaces_checked"
            echo "recommended_fix=run_doctor_with_package_for_app_profile_visibility"
            return 0
        fi
        echo "diagnosis=module_mount_missing"
        echo "recommended_fix=run_action_sh_repair_or_reboot"
        return 1
    fi

    target_sdk=$(package_target_sdk "$pkg")
    uid=$(package_uid "$pkg")
    pid=$(first_package_pid "$pkg")
    current=$(store_visibility_current)

    echo "package=$pkg"
    echo "target_sdk=${target_sdk:-unknown}"
    echo "uid=${uid:-unknown}"

    if [ -n "$target_sdk" ] && [ "$target_sdk" -ge 37 ] 2>/dev/null; then
        echo "ct_relevant=true"
        echo "ct_failure_possible=true"
    else
        echo "ct_relevant=false"
        echo "ct_failure_possible=false"
    fi

    if [ -n "$pid" ]; then
        app_state=$(store_visibility_pid "$pid")
        echo "pid=$pid"
        echo "app_namespace=$app_state"
        echo "app_hybrid_mounts=$(pid_hybrid_state "$pid")"
        echo "app_system_etc_mount=$(pid_mount_state "$pid" /system/etc)"
        [ -d "/proc/$pid/root$APEX_CERT_DIR" ] && echo "app_conscrypt_mount=$(pid_mount_state "$pid" "$APEX_CERT_DIR")"
    else
        app_state=not_running
        echo "pid=not_running"
        echo "app_namespace=not_running"
    fi

    doctor_recommendation "$app_state" "$current" "$target_sdk"
}

run_repair() {
    prepare_trust_store || exit 1
    hybrid_mount_register >/dev/null 2>&1 || true
    mount_targets_current_ns
    mount_targets_other_namespaces

    if verify_visibility; then
        status_write "ready" "repair-mounted"
        echo "repair=ok"
        exit 0
    fi

    status_write "degraded" "repair-not-visible"
    echo "repair=degraded"
    exit 1
}

case "${1:-status}" in
    status)
        print_status
        ;;
    doctor)
        shift
        run_doctor "$1"
        ;;
    repair)
        run_repair
        ;;
    *)
        echo "usage=action.sh status|doctor [package]|repair"
        exit 2
        ;;
esac
