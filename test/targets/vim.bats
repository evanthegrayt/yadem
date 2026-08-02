#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "vim help describes force mode" {
    run_yadem vim --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] vim"
    assert_output_contains "-f, --force"
    assert_output_contains "Back up or replace an existing ~/.vim"
}

@test "vim install leaves existing directory alone without force" {
    mkdir -p "$TEST_HOME/.vim"
    printf "existing vim\n" > "$TEST_HOME/.vim/README"

    run_yadem vim

    assert_success
    assert_output_contains "Vim files already exist: $TEST_HOME/.vim"
    [[ -d "$TEST_HOME/.vim" ]]
    [[ "$(cat "$TEST_HOME/.vim/README")" == "existing vim" ]]
}

@test "vim force dry-run reports backup and clone without modifying home" {
    mkdir -p "$TEST_HOME/.vim"
    printf "existing vim\n" > "$TEST_HOME/.vim/README"

    run_yadem --test vim --force

    assert_success
    assert_output_contains "Would back up $TEST_HOME/.vim to $TEST_CACHE/yadem/vim.$(date +%F)"
    assert_output_contains "Would clone https://github.com/evanthegrayt/vimfiles.git to $TEST_HOME/.vim"
    [[ -d "$TEST_HOME/.vim" ]]
    [[ "$(cat "$TEST_HOME/.vim/README")" == "existing vim" ]]
}

@test "vim force install backs up existing directory before cloning" {
    setup_fake_git_clone
    mkdir -p "$TEST_HOME/.vim"
    printf "existing vim\n" > "$TEST_HOME/.vim/README"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem vim --force

    assert_success
    assert_output_contains "Backed up $TEST_HOME/.vim to $TEST_CACHE/yadem/vim.$(date +%F)"
    assert_output_contains "Cloning https://github.com/evanthegrayt/vimfiles.git to $TEST_HOME/.vim"
    [[ -d "$TEST_CACHE/yadem/vim.$(date +%F)" ]]
    [[ "$(cat "$TEST_CACHE/yadem/vim.$(date +%F)/README")" == "existing vim" ]]
    [[ -d "$TEST_HOME/.vim/.git" ]]
    [[ "$(cat "$TEST_HOME/.vim/README")" == "cloned https://github.com/evanthegrayt/vimfiles.git" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "vim backed-up"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "vim cloning"
}

@test "vim force install backs up existing regular file before cloning" {
    setup_fake_git_clone
    printf "existing vim file\n" > "$TEST_HOME/.vim"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem vim --force

    assert_success
    assert_output_contains "Backed up $TEST_HOME/.vim to $TEST_CACHE/yadem/vim.$(date +%F)"
    [[ -f "$TEST_CACHE/yadem/vim.$(date +%F)" ]]
    [[ "$(cat "$TEST_CACHE/yadem/vim.$(date +%F)")" == "existing vim file" ]]
    [[ -d "$TEST_HOME/.vim/.git" ]]
    [[ "$(cat "$TEST_HOME/.vim/README")" == "cloned https://github.com/evanthegrayt/vimfiles.git" ]]
}

@test "vim force install replaces existing symlink before cloning" {
    setup_fake_git_clone
    ln -s /tmp/old-vim-target "$TEST_HOME/.vim"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem vim --force

    assert_success
    assert_output_contains "Replaced symlink: $TEST_HOME/.vim"
    assert_output_contains "Cloning https://github.com/evanthegrayt/vimfiles.git to $TEST_HOME/.vim"
    [[ -d "$TEST_HOME/.vim/.git" ]]
    [[ "$(cat "$TEST_HOME/.vim/README")" == "cloned https://github.com/evanthegrayt/vimfiles.git" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "vim replaced-link"
}
