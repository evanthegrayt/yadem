#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "brew dry-run prints Brewfile action and writes a log" {
    run_yadem --test brew

    assert_success
    assert_output_contains "Would install Homebrew packages from"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "brew would-install"
}
