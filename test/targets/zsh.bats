#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "zsh preserves existing custom directory by default" {
    mkdir -p "$TEST_HOME/.oh-my-zsh/custom"
    printf "existing custom\n" > "$TEST_HOME/.oh-my-zsh/custom/README"

    run_yadem zsh

    assert_success
    assert_output_contains "oh-my-zsh already exists: $TEST_HOME/.oh-my-zsh"
    assert_output_contains "oh-my-zsh-custom already exists: $TEST_HOME/.oh-my-zsh/custom"
    [[ "$(cat "$TEST_HOME/.oh-my-zsh/custom/README")" == "existing custom" ]]
}

@test "zsh clones missing custom directory" {
    setup_fake_git_clone
    mkdir -p "$TEST_HOME/.oh-my-zsh"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem zsh

    assert_success
    assert_output_contains "oh-my-zsh already exists: $TEST_HOME/.oh-my-zsh"
    assert_output_contains "Cloning https://github.com/evanthegrayt/oh-my-zsh-custom.git to $TEST_HOME/.oh-my-zsh/custom"
    [[ -d "$TEST_HOME/.oh-my-zsh/custom/.git" ]]
    [[ "$(cat "$TEST_HOME/.oh-my-zsh/custom/README")" == "cloned https://github.com/evanthegrayt/oh-my-zsh-custom.git" ]]
}

@test "zsh force dry-run reports custom replacement without modifying home" {
    mkdir -p "$TEST_HOME/.oh-my-zsh/custom"
    printf "existing custom\n" > "$TEST_HOME/.oh-my-zsh/custom/README"

    run_yadem --test zsh --force

    assert_success
    assert_output_contains "oh-my-zsh already exists: $TEST_HOME/.oh-my-zsh"
    assert_output_contains "Would back up $TEST_HOME/.oh-my-zsh/custom to $TEST_CACHE/yadem/zsh-custom.$(date +%F)"
    assert_output_contains "Would clone https://github.com/evanthegrayt/oh-my-zsh-custom.git to $TEST_HOME/.oh-my-zsh/custom"
    [[ "$(cat "$TEST_HOME/.oh-my-zsh/custom/README")" == "existing custom" ]]
    [[ ! -e "$TEST_CACHE/yadem/zsh-custom.$(date +%F)" ]]
}

@test "zsh force backs up existing custom directory before cloning" {
    setup_fake_git_clone
    mkdir -p "$TEST_HOME/.oh-my-zsh/custom"
    printf "existing custom\n" > "$TEST_HOME/.oh-my-zsh/custom/README"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem zsh --force

    assert_success
    assert_output_contains "Backed up $TEST_HOME/.oh-my-zsh/custom to $TEST_CACHE/yadem/zsh-custom.$(date +%F)"
    assert_output_contains "Cloning https://github.com/evanthegrayt/oh-my-zsh-custom.git to $TEST_HOME/.oh-my-zsh/custom"
    [[ -d "$TEST_CACHE/yadem/zsh-custom.$(date +%F)" ]]
    [[ "$(cat "$TEST_CACHE/yadem/zsh-custom.$(date +%F)/README")" == "existing custom" ]]
    [[ -d "$TEST_HOME/.oh-my-zsh/custom/.git" ]]
    [[ "$(cat "$TEST_HOME/.oh-my-zsh/custom/README")" == "cloned https://github.com/evanthegrayt/oh-my-zsh-custom.git" ]]
}
