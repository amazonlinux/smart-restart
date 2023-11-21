#!/usr/bin/env bash

# Here, we are testing the generation of the reboot hint marker
#   When all services could be restarted -> no restart
#   When not all services could be restarted -> restart recommended
#   When a kernel update occured -> restart recommended

# cannot follow "$(pwd)/setup_test"
# shellcheck disable=SC1091

# Unused variables like TEST_NAME
# shellcheck disable=SC2034
TEST_NAME="REBOOT HINT"
. "$(pwd)"/setup_test

function restart_successful() {
    DESCRIPTION="No reboot hint on successful service restart"
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    NEED_RESTART_0=1 generate_reboot_hint_marker || retval=$?
 
    if [[ $retval -eq 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}

function restart_failed() {
    DESCRIPTION="Reboot hint on failed service restart"
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    NEED_RESTART_1=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval -eq 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}

function kernel_update() {
    DESCRIPTION="Reboot hint on kernel update"
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    REBOOTHINT_KERNEL=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval -eq 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}

function userspace_update() {
    DESCRIPTION="No reboot hint on userspace only"
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    REBOOTHINT_USER=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval -eq 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}

function userspace_and_kernel_update() {
    DESCRIPTION="Reboot hint on userspace and kernel updates"
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    REBOOTHINT_USER_KERNEL=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval == 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}

restart_successful
restart_failed
kernel_update
userspace_update
userspace_and_kernel_update

