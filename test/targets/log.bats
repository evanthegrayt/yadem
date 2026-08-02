#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "log path prints the resolved default log path" {
    run_yadem log path

    assert_success
    [[ "$output" == "$TEST_CACHE/yadem/install.log" ]]
}

@test "log show and delete use custom YADEM_LOG" {
    local custom_log="$BATS_TEST_TMPDIR/custom-log.$BATS_TEST_NUMBER/install.log"

    mkdir -p "$(dirname -- "$custom_log")"
    printf "first entry\nsecond entry\n" > "$custom_log"

    YADEM_LOG="$custom_log" run_yadem log list

    assert_success
    [[ "$output" == "$custom_log" ]]

    YADEM_LOG="$custom_log" run_yadem log show

    assert_success
    assert_output_contains "first entry"
    assert_output_contains "second entry"

    YADEM_LOG="$custom_log" run_yadem log delete

    assert_success
    assert_output_contains "Deleted log: $custom_log"
    [[ ! -e "$custom_log" ]]
}

@test "log show reports a missing custom YADEM_LOG" {
    YADEM_LOG="$TEST_HOME/missing/install.log" run_yadem log show

    assert_failure
    assert_output_contains "No log found at $TEST_HOME/missing/install.log"
}
