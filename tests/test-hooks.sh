#!/usr/bin/env bash

# Here we are testing the correct execution order of pre- and post-restart hooks

# shellcheck disable=SC2034
TEST_NAME="RUN HOOKS"
. "$(pwd)"/setup_test

DESCRIPTION="Pre restart hook execution"
if [[ $(execute_pre_hooks | xargs) == "1 pre 2 pre" ]]; then
    PASSED "$DESCRIPTION"
else
    FAILED "$DESCRIPTION"
fi


DESCRIPTION="Post restart hook execution"
if [[ $(execute_post_hooks | xargs) == "1 post 2 post" ]]; then
    PASSED "$DESCRIPTION"
else
    FAILED "$DESCRIPTION"
fi
