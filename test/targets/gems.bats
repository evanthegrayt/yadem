#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "gems dry-run prints gem actions and writes a log" {
    run_yadem --test gems

    assert_success
    assert_output_contains "Would install gem: standard"
    assert_output_contains "Would install gem: spoonerize"
    assert_output_contains "Would install gem: standup_md"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "gems would-install Would install gem: standard"
}
