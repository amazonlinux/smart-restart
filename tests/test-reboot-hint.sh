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
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    OS_VERSION="2023" SYS_RESTART_FAILED=0 NEED_RESTART_0=1 generate_reboot_hint_marker || retval=$?
 
    if [[ $retval -eq 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function restart_failed() {
    DESCRIPTION="Reboot hint on failed service restart"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    OS_VERSION="2023" NEED_RESTART_1=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval -eq 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function kernel_update() {
    DESCRIPTION="Reboot hint on kernel update"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    OS_VERSION="2023" REBOOTHINT_KERNEL=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval == 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function userspace_update() {
    DESCRIPTION="No reboot hint on userspace only"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    OS_VERSION="2023" REBOOTHINT_USER=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function userspace_and_kernel_update() {
    DESCRIPTION="Reboot hint on userspace and kernel updates"

    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list

    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    OS_VERSION="2023" REBOOTHINT_USER_KERNEL=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval == 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function reboot_hint_on_unhealthy_service() {
    DESCRIPTION="Reboot hint on unhealthy service"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health
    OS_VERSION="2023" NEED_RESTART_1=1 SYS_RESTART_FAILED=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval == 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function reboot_hint_on_unhealthy_service() {
    DESCRIPTION="Reboot hint on unhealthy service"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health
    OS_VERSION="2023" NEED_RESTART_1=1 SYS_RESTART_FAILED=1 generate_reboot_hint_marker || retval=$?

    if [[ $retval == 2 && -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}


function no_reboot_hint_on_stale_oneshot() {
    DESCRIPTION="No reboot hint when only a completed oneshot service remains stale"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    # After the restarts, needs-restarting still reports oneshot.service
    # ("active (exited)", never restarted by us). That must not be treated
    # as a failed restart requiring a reboot.
    OS_VERSION="2023" SYS_RESTART_FAILED=0 NEED_RESTART_1=1 SYS_ONESHOT_UNITS="dummy2.service" \
        generate_reboot_hint_marker || retval=$?

    if [[ $retval -eq 0 && ! -f "$(pwd)/reboot-hint-marker" ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    rm -rf "$(pwd)/reboot-hint-marker"
}


function no_reboot_hint_on_stale_reboot_class_service() {
    DESCRIPTION="No reboot hint when only a withheld reboot-class service remains stale"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list
    SYS_RESTART_FAILED=0 count_pre_restart_health

    # After the restarts, needs-restarting still reports dbus-broker.service
    # (withheld from restarting on purpose). AL2023's dnf4 hid it from the -s
    # output entirely, so it never raised the hint there; same result here.
    # The reboot recommendation for such packages is handled by the
    # --reboothint path, which deliberately ignores them.
    OS_VERSION="2023" SYS_RESTART_FAILED=0 NEED_RESTART_DBUS=1 \
        generate_reboot_hint_marker || retval=$?

    if [[ $retval -eq 0 && ! -f "$(pwd)/reboot-hint-marker" ]]; then
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
reboot_hint_on_unhealthy_service
no_reboot_hint_on_stale_oneshot
no_reboot_hint_on_stale_reboot_class_service
