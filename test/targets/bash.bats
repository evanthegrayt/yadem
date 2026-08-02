#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "bash preserves existing custom directory by default" {
    mkdir -p "$TEST_HOME/.bash_it/custom"
    printf "existing custom\n" > "$TEST_HOME/.bash_it/custom/README"

    run_yadem bash

    assert_success
    assert_output_contains "bash-it already exists: $TEST_HOME/.bash_it"
    assert_output_contains "bash-it-custom already exists: $TEST_HOME/.bash_it/custom"
    [[ "$(cat "$TEST_HOME/.bash_it/custom/README")" == "existing custom" ]]
}

@test "bash clones missing custom directory" {
    setup_fake_git_clone
    mkdir -p "$TEST_HOME/.bash_it"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem bash

    assert_success
    assert_output_contains "bash-it already exists: $TEST_HOME/.bash_it"
    assert_output_contains "Cloning https://github.com/evanthegrayt/bash-it-custom.git to $TEST_HOME/.bash_it/custom"
    [[ -d "$TEST_HOME/.bash_it/custom/.git" ]]
    [[ "$(cat "$TEST_HOME/.bash_it/custom/README")" == "cloned https://github.com/evanthegrayt/bash-it-custom.git" ]]
}

@test "bash force dry-run reports custom replacement without modifying home" {
    mkdir -p "$TEST_HOME/.bash_it/custom"
    printf "existing custom\n" > "$TEST_HOME/.bash_it/custom/README"

    run_yadem --test bash --force

    assert_success
    assert_output_contains "bash-it already exists: $TEST_HOME/.bash_it"
    assert_output_contains "Would back up $TEST_HOME/.bash_it/custom to $TEST_CACHE/yadem/bash-custom.$(date +%F)"
    assert_output_contains "Would clone https://github.com/evanthegrayt/bash-it-custom.git to $TEST_HOME/.bash_it/custom"
    [[ "$(cat "$TEST_HOME/.bash_it/custom/README")" == "existing custom" ]]
    [[ ! -e "$TEST_CACHE/yadem/bash-custom.$(date +%F)" ]]
}

@test "bash force backs up existing custom directory before cloning" {
    setup_fake_git_clone
    mkdir -p "$TEST_HOME/.bash_it/custom"
    printf "existing custom\n" > "$TEST_HOME/.bash_it/custom/README"

    PATH="$TEST_FAKE_BIN:$PATH" run_yadem bash --force

    assert_success
    assert_output_contains "Backed up $TEST_HOME/.bash_it/custom to $TEST_CACHE/yadem/bash-custom.$(date +%F)"
    assert_output_contains "Cloning https://github.com/evanthegrayt/bash-it-custom.git to $TEST_HOME/.bash_it/custom"
    [[ -d "$TEST_CACHE/yadem/bash-custom.$(date +%F)" ]]
    [[ "$(cat "$TEST_CACHE/yadem/bash-custom.$(date +%F)/README")" == "existing custom" ]]
    [[ -d "$TEST_HOME/.bash_it/custom/.git" ]]
    [[ "$(cat "$TEST_HOME/.bash_it/custom/README")" == "cloned https://github.com/evanthegrayt/bash-it-custom.git" ]]
}
