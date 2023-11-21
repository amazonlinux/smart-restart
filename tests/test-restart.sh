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

    SERVICES=()
    BLOCKED_SERVICES=()

    local -i retval=0

    NEED_RESTART_2=1 assemble_service_list 
    SYS_EXPECT_2=1 restart_services  || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function restart_failed() {
    DESCRIPTION="Service restart failed"
    local -i retval=0
    
    SERVICES=()
    BLOCKED_SERVICES=()

    NEED_RESTART_2=1 assemble_service_list
    SYS_EXPECT_1=1 restart_services || retval=$?

    if [[ $retval != 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

function all_services_denylisted() {
    DESCRIPTION="Service restart all denylisted"
    
    SERVICES=()
    BLOCKED_SERVICES=()

    local -i retval=0
    
    echo "dummy.service" > conf/default-denylist
    echo "dummy2.service" > conf/custom-denylist

    NEED_RESTART_2=1 assemble_service_list
    SYS_EXPECT_0=1 restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    
    echo "" > conf/default-denylist
    echo "" > conf/custom-denylist
}

function one_service_denylisted() {
    DESCRIPTION="Service restart one denylisted"

    SERVICES=()
    BLOCKED_SERVICES=()
    
    local -i retval=0
    
    echo "dummy.service" > conf/default-denylist

    NEED_RESTART_2=1 assemble_service_list
    SYS_EXPECT_1=1 restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi

    echo "" > conf/default-denylist
}

function denylist_systemd() {
    DESCRIPTION="Systemd denylisted"

    SERVICES=()
    BLOCKED_SERVICES=()
    
    local -i retval=0

    echo "systemd" > conf/default-denylist
    NEED_RESTART_0=1 assemble_service_list 

    # Setting sysctl to /bin/false will fail the test if restart_service tries to call systemctl
    SYSCTL_COMMAND=/bin/false SYS_EXPECT_0="1" restart_services || retval=$?

    if [[ $retval == 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
    echo "" > conf/default-denylist

}

function denylist_systemd_failed() {
    DESCRIPTION="Fail systemd denylist"
    SERVICES=()
    BLOCKED_SERVICES=()
    local -i retval=0

    NEED_RESTART_0=1 assemble_service_list 

    # Setting sysctl to /bin/false will fail the test if restart_service tries to call systemctl
    SYSCTL_COMMAND=/bin/false restart_services || retval="$?"

    if [[ $retval == 1 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

restart_successful
restart_failed
all_services_denylisted
one_service_denylisted
denylist_systemd
denylist_systemd_failed
