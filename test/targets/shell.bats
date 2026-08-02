#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "shell dry-run reports missing shell configuration" {
    write_yadem_config "YADEM_SHELL_LOGIN=''"

    run_yadem --test shell

    assert_success
    assert_output_contains "YADEM_SHELL_LOGIN is not configured"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "shell skipped"
}

@test "shell rejects unsupported configured shell" {
    write_yadem_config "YADEM_SHELL_LOGIN='fish'"

    run_yadem --test shell

    assert_failure
    assert_output_contains "Unsupported shell: fish"
}
