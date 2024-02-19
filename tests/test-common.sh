#!/usr/bin/env bash

# This is the place to test common functionality not suitable for any other tests AND
# not suiteable for an own test-file.

# cannot follow "$(pwd)/setup_test"
# shellcheck disable=SC1091

# Unused variables like TEST_NAME
# shellcheck disable=SC2034
TEST_NAME="Common"
. "$(pwd)"/setup_test

function test_assert_root() {
    DESCRIPTION="Root assert fails for user"
    reset_test_environment
    # Need a subshell here since assert_root exits instead of returning
    (assert_root) || retval=$?

    if [[ $retval != 0 ]]; then
        PASSED "$DESCRIPTION"
    else 
        FAILED "$DESCRIPTION (error: $retval)"
    fi
}

test_assert_root
