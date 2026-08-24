#!/usr/bin/env bash

# Variable assignments like SERVICE=() reset the state of smart-restart.sh
# but they are picked up by shellcheck as unused.
# shellcheck disable=SC2034

# cannot follow "$(pwd)/setup_test"
# shellcheck disable=SC1091
TEST_NAME="SERVICE RESTART"
. "$(pwd)"/setup_test


function restart_successful() {
    DESCRIPTION="Service restart successful"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2="1" assemble_service_list 
    count_pre_restart_health 
    SYS_EXPECT_2="1" SYS_RESTART_FAILED="0" restart_services  || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    PRE_RESTART_HEALTHY="0"
    POST_RESTART_HEALTHY="0"
}

function restart_failed() {
    DESCRIPTION="Service restart failed"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2="1" assemble_service_list
    count_pre_restart_health
    SYS_EXPECT_1="1" restart_services || retval=$?

    if [[ $retval != 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function all_services_denylisted() {
    DESCRIPTION="Service restart all denylisted"
    reset_test_environment
    local -i retval=0
    
    echo "dummy.service" > conf/default-denylist
    echo "dummy2.service" > conf/custom-denylist

    NEED_RESTART_2="1" assemble_service_list
    count_pre_restart_health
    SYS_EXPECT_0="1" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function one_service_denylisted() {
    DESCRIPTION="Service restart one denylisted"
    reset_test_environment
    
    local -i retval=0
    
    echo "dummy.service" > conf/default-denylist

    NEED_RESTART_2="1" assemble_service_list
    count_pre_restart_health
    SYS_EXPECT_1="1" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function health_check_pass() {
    DESCRIPTION="Health check passed"
    reset_test_environment
    local -i retval=0
    
    NEED_RESTART_1="1" assemble_service_list
    SYS_RESTART_FAILED="1" count_pre_restart_health
    NEED_RESTART_1="1" SYS_EXPECT_1="1" restart_services || retval="$?"
    SYS_RESTART_FAILED="1" count_post_restart_health || retval="$?"

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function health_check_fail() {
    DESCRIPTION="Health check failed"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_2="1" assemble_service_list 
    SYS_RESTART_FAILED="0" count_pre_restart_health
    SYS_EXPECT_1="1" restart_services || retval="$?"
    SYS_RESTART_FAILED="1" count_post_restart_health || retval="$?"

    if [[ $retval != 0 ]]; then
        PASSED "$DESCRIPTION (error: $retval)"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function denylist_systemd() {
    DESCRIPTION="Systemd denylisted"
    reset_test_environment
    local -i retval=0

    echo "systemd" > conf/default-denylist
    NEED_RESTART_0="1" assemble_service_list 

    # Setting sysctl to /bin/false will fail the test if restart_service tries to call systemctl
    SYSCTL_COMMAND=/bin/false SYS_EXPECT_0="1" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function denylist_systemd_failed() {
    DESCRIPTION="Fail systemd denylist"
    reset_test_environment
    local -i retval=0

    NEED_RESTART_0="1" assemble_service_list 

    # Setting sysctl to /bin/false will fail the test if restart_service tries to call systemctl
    SYSCTL_COMMAND=/bin/false restart_services || retval="$?"

    if [[ $retval == 1 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}



function completed_oneshot_not_restarted() {
    DESCRIPTION="Completed oneshot service is filtered from restart list"
    reset_test_environment
    local -i retval=0

    # needs-restarting reports dummy.service, dummy2.service and
    # oneshot.service; the latter is "active (exited)" (SubState "exited")
    # and must not be restarted.
    NEED_RESTART_2_ONESHOT="1" SYS_ONESHOT_UNITS="oneshot.service" assemble_service_list
    count_pre_restart_health
    # SYS_EXPECT_2 makes the systemctl mock only accept a restart of exactly
    # dummy.service dummy2.service, proving oneshot.service was dropped.
    SYS_EXPECT_2="1" SYS_RESTART_FAILED="0" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    PRE_RESTART_HEALTHY="0"
    POST_RESTART_HEALTHY="0"
}



function reboot_class_service_not_restarted() {
    DESCRIPTION="Reboot-class service is withheld from restart list"
    reset_test_environment
    local -i retval=0

    # needs-restarting reports dummy.service, dummy2.service and
    # dbus-broker.service; the rpm mock owns the latter's unit file via
    # dbus-broker, which provides a reboot-class name, so it must be
    # withheld (dnf4 behavior).
    NEED_RESTART_2_DBUS="1" assemble_service_list 2>/dev/null
    count_pre_restart_health
    # SYS_EXPECT_2 makes the systemctl mock only accept a restart of exactly
    # dummy.service dummy2.service, proving dbus-broker.service was dropped.
    SYS_EXPECT_2="1" SYS_RESTART_FAILED="0" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    PRE_RESTART_HEALTHY="0"
    POST_RESTART_HEALTHY="0"
}

function reboot_class_service_warns() {
    DESCRIPTION="Withheld reboot-class service prints dnf4-style warning to stderr"
    reset_test_environment
    local warning

    warning=$(NEED_RESTART_2_DBUS="1" assemble_service_list 2>&1 >/dev/null)

    if grep -q "should not be restarted but require a reboot" <<<"$warning" \
        && grep -q "dbus-broker.service" <<<"$warning"; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (stderr: $warning)"
    fi
}

function legacy_stack_keeps_dnf4_behavior() {
    DESCRIPTION="Guards disabled (dnf4/yum stack): list is restarted verbatim"
    reset_test_environment
    local -i retval=0

    # On AL2/AL2023 the guards are off (dnf4 already applies them itself);
    # everything needs-restarting printed must be restarted unchanged, even
    # units our mocks would classify as oneshot.
    ENFORCE_RESTART_SAFETY_GUARDS=0 NEED_RESTART_2_ONESHOT="1" SYS_ONESHOT_UNITS="oneshot.service" \
        assemble_service_list
    count_pre_restart_health
    SYS_EXPECT_3="1" SYS_RESTART_FAILED="0" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    PRE_RESTART_HEALTHY="0"
    POST_RESTART_HEALTHY="0"
}



restart_successful
restart_failed
all_services_denylisted
one_service_denylisted
denylist_systemd
denylist_systemd_failed
health_check_pass
health_check_fail
completed_oneshot_not_restarted
reboot_class_service_not_restarted
reboot_class_service_warns
legacy_stack_keeps_dnf4_behavior
