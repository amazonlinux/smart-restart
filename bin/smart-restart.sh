#!/usr/bin/env bash

# This script will try to restart all systemd services based on the "age" of the libraries they link against. 
# Updates to libraries like glibc will cause the services linking against them to be marked as "outdated" and in 
# the need of a restart.
# Finding possible candidates is done using "needs-restarting -s". Services which should not be touched can be
# denylisted using the smart-restart-denylist.cfg
# In addition, smart-restart provides pre- and post-restart hooks executed before a restart happens. 
# In case the services could not be restarted or non-restartable components like the kernel received an update, this
# script will provide a reboot-hint file (REBOOT_HINT_MARKER). Finding this file on your system indicates a reboot 
# is adviced.

readonly REBOOT_HINT_PATH=${REBOOT_HINT_PATH:-/run/smart-restart}
readonly REBOOT_HINT_MARKER="${REBOOT_HINT_PATH}"/reboot-hint-marker
readonly CONF_PATH=${CONF_PATH:-/etc/smart-restart-conf.d}
readonly DENYLISTS=("${CONF_PATH}"/*-denylist)
# shellcheck disable=SC2207
readonly PRE_RESTART=($(ls "$CONF_PATH"/*pre-restart | sort -n))
# shellcheck disable=SC2207
readonly POST_RESTART=($(ls "$CONF_PATH"/*post-restart | sort -n))

SYSCTL_COMMAND="${SYSCTL_COMMAND:-systemctl}"
NEEDS_RESTARTING_COMMAND="${NEEDS_RESTARTING_COMMAND:-/usr/bin/needs-restarting}"

IS_TESTING=${IS_TESTING:-}
DEBUG=${DEBUG:-}

SERVICES=()
BLOCKED_SERVICES=()
PRE_RESTART_HEALTHY=0
POST_RESTART_HEALTHY=0

INF() { echo "$1"; }
DBG() { [[ "$DEBUG" != "" ]] && >&2 echo "$1"; }
CRIT() { >&2 echo "*** ERROR: $1"; }

assert_root() {
    if [[ "$(id -u)" != "0" ]]; then
        CRIT "Please run this script as root."
        exit 1
    fi
    return 0
}

assemble_service_list() {
    # shellcheck disable=SC2207
    local all_services=($($NEEDS_RESTARTING_COMMAND -s | xargs))
    
    # shellcheck disable=SC2048
    BLOCKED_SERVICES=("$(sed "s/#.*//g" ${DENYLISTS[*]})")

    DBG "Denylist: ${DENYLISTS[*]}"
    DBG "Blocked services: ${BLOCKED_SERVICES[*]}"
    DBG "All services: ${all_services[*]}"

    for SERVICE in "${all_services[@]}"; do
        grep -qF "${SERVICE}" <<<"${BLOCKED_SERVICES[*]}"
        if [[ $? -eq 0 ]]; then
            DBG "Ignoring ${SERVICE}"
        else
            SERVICES+=("${SERVICE}")
            DBG "Adding ${SERVICE}"
        fi
    done
}

execute_pre_hooks() {
    DBG "Executing pre-restart hooks: ${PRE_RESTART[*]}"
    for HOOK in "${PRE_RESTART[@]}"; do
        $HOOK
    done
}

restart_services() {
    local -i retval=0

    # shellcheck disable=SC2086
    if [[ ${#SERVICES[@]} != 0 ]]; then
        DBG "Attempting to restart services: ${SERVICES[*]}"
        # shellcheck disable=SC2048,SC2086
        $SYSCTL_COMMAND restart ${SERVICES[*]} || retval=$?
    else
        DBG "No services to restart"    
    fi


    if [[ ! "${BLOCKED_SERVICES[*]}" =~ "systemd" ]]; then
        DBG "Attempting to restart systemd itself"
        $SYSCTL_COMMAND daemon-reexec || retval=$?
    else
        DBG "Systemd denylisted. NOT attempting to restart"
    fi
    return $retval
}

# Though, {pre,post} health checks could live in restart_services(), I've moved them outside to be able to test the functionality.
count_pre_restart_health() {
    DBG "No of services to check (pre-restart): ${#SERVICES[@]}"
    if [[ ${#SERVICES[@]} != 0 ]]; then
        # shellcheck disable=SC2048,SC2086
        PRE_RESTART_HEALTHY=$($SYSCTL_COMMAND status ${SERVICES[*]} | grep "Active" | grep -cE "active \(running\)")
    fi
}

count_post_restart_health() {
    DBG "No of services to check (post-restart): ${#SERVICES[@]}"

    if [[ ${#SERVICES[@]} != 0 ]]; then
        # shellcheck disable=SC2048,SC2086
        POST_RESTART_HEALTHY=$($SYSCTL_COMMAND status ${SERVICES[*]} | grep "Active" | grep -cE "active \(running\)")
    fi
    DBG "Pre restart cnt: $PRE_RESTART_HEALTHY"
    DBG "Post restart cnt: $POST_RESTART_HEALTHY"

    if [[ "$PRE_RESTART_HEALTHY" != "$POST_RESTART_HEALTHY" ]]; then
        S=()
        for SERVICE in "${SERVICES[@]}"; do
            $SYSCTL_COMMAND is-active ${SERVICE}
            local -i retval=$?

            if [[ $retval -gt 0 ]]; then
                S+=("${SERVICE}")
            fi
        done

        CRIT "Not all services could be successfully started. Failed services: ${S[*]}"

        return 1
    fi
}

execute_post_hooks() {
    DBG "Executing post-restart hooks: ${POST_RESTART[*]}"
    for HOOK in "${POST_RESTART[@]}"; do
        $HOOK
    done
}

# Although the reboot-hint option in `needs-restarting` is interesting as a standalone utility, we cannot use it directly.
# The reboot hint uses the installation date and boot date to determine if a reboot is required. Since we restarted services already, we need to assess the
# state of the system based on other metrics.
# This means, we need to consolidate a few information sources here to be sure.
# 1) Check if processess actually got restarted (and ignore the "denylisted" services)
# 2) Remove userspace components from the reboot-hint output
# shellcheck disable=SC2155
LOCAL_OS_VERSION=$(cut -d ":" -f6 /etc/system-release-cpe)
OS_VERSION=${OS_VERSION:-$LOCAL_OS_VERSION}

generate_reboot_hint_marker() {
    local -i reboot_hint=0
    local -i retval=0
    # shellcheck disable=SC2155
    local post_restart_services=$($NEEDS_RESTARTING_COMMAND -s | xargs)
    local failed_services=()
    for SERVICE in $post_restart_services; do
         if ! grep -qF "$SERVICE" <<<"${BLOCKED_SERVICES[*]}"; then
            DBG "$SERVICE not denylisted. Service restart required"
            failed_services+=("${SERVICE}")
            reboot_hint=1
        fi
    done

    count_post_restart_health || retval=$?

    local reboothint_separator=""

    # Consistency is key, that's why the output of needs-restarting --reboothint has different styles for yum & dnf (output for glibc):
    # (yum)   glibc -> 2.26-63.amzn2 
    # (dnf)   * glibc
    if [[ "$OS_VERSION" -eq "2" ]]; then 
        reboothint_separator="->"
    elif [[ "$OS_VERSION" -eq "2023" ]]; then 
        reboothint_separator="*"
    else
        CRIT "ERROR: Could not determine OS. I won't create a reboot hint marker"
        return 1
    fi

    # Those are the packages `needs-restarting` is scanning for. We're going to ignore the one's we know we can't restart
    # ['kernel', 'kernel-rt', 'glibc', 'linux-firmware', 'systemd', 'udev', 'openssl-libs', 'gnutls', 'dbus']
    # shellcheck disable=SC2155
    local updated_components=$($NEEDS_RESTARTING_COMMAND --reboothint | grep -v "glibc\|systemd\|openssl-libs\|gnutls\|dbus\|udev"  | grep -- "${reboothint_separator}")
    # At this point $updated_components should only report in case kernel* or linux-* was updated.

    if [[ -n ${updated_components} ]]; then
        reboot_hint=1
        DBG "Encountered updates we cannot restart without a reboot: $updated_components"
    fi

    if [[ "$PRE_RESTART_HEALTHY" != "$POST_RESTART_HEALTHY" ]]; then
        reboot_hint=1
        # shellcheck disable=SC2048
        for SERVICE in ${SERVICES[*]}; do
            $SYSCTL_COMMAND status "$SERVICE"

            if  [[ $? != 0 ]]; then

                CRIT "Service \"${SERVICE}\" failed to start again."
            fi
        done
    fi


    if [[ $reboot_hint == 1 ]]; then
        mkdir -p "$REBOOT_HINT_PATH"
        echo "${SERVICES[*]}" > "$REBOOT_HINT_MARKER"
        echo "${updated_components}" >> "$REBOOT_HINT_MARKER"
        INF "Recommending a restart"
        return 2
    else
        DBG "NOT Recommending a restart"
        return 0
    fi
}

if [[ -z "$IS_TESTING" ]]; then
    assert_root
    assemble_service_list
    count_pre_restart_health
    execute_pre_hooks
    restart_services
    execute_post_hooks
    generate_reboot_hint_marker || exit $?
fi
