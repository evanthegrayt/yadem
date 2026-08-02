#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "brew dry-run prints global Brewfile action and writes a log" {
    run_yadem --test brew

    assert_success
    assert_output_contains "Would install Homebrew packages from the global Brewfile"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "brew would-install"
}

@test "brew help documents Homebrew global Brewfile lookup" {
    run_yadem brew --help

    assert_success
    assert_output_contains "brew bundle install --global"
    assert_output_contains ".Brewfile"
}
