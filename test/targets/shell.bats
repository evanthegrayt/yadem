#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "shell dry-run reports missing shell configuration" {
    write_yadem_config "YADEM_LOGIN_SHELL=''"

    run_yadem --test shell

    assert_success
    assert_output_contains "YADEM_LOGIN_SHELL is not configured"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "shell skipped"
}
