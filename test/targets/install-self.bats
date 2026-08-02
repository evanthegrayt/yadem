#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "install-self dry-run prints planned symlink and PATH status" {
    run_yadem --test install-self

    assert_success
    assert_output_contains "Would create directory: $TEST_HOME/.local/bin"
    assert_output_contains "Would link $TEST_HOME/.local/bin/yadem -> $(yadem_bin)"
    assert_output_contains "PATH does not contain $TEST_HOME/.local/bin"
}

@test "install-self reports when destination directory is already in PATH" {
    PATH="$TEST_HOME/.local/bin:$PATH" run_yadem --test install-self

    assert_success
    assert_output_contains "Would link $TEST_HOME/.local/bin/yadem -> $(yadem_bin)"
    assert_output_contains "PATH contains $TEST_HOME/.local/bin"
}

@test "install-self creates the destination directory and symlink" {
    run_yadem install-self

    assert_success
    [[ -d "$TEST_HOME/.local/bin" ]]
    [[ -L "$TEST_HOME/.local/bin/yadem" ]]
    [[ "$(readlink "$TEST_HOME/.local/bin/yadem")" == "$(yadem_bin)" ]]
    assert_output_contains "Linked yadem: $TEST_HOME/.local/bin/yadem -> $(yadem_bin)"
}

@test "install-self reports an existing correct symlink as present" {
    mkdir -p "$TEST_HOME/.local/bin"
    ln -s "$(yadem_bin)" "$TEST_HOME/.local/bin/yadem"

    run_yadem install-self

    assert_success
    assert_output_contains "yadem symlink already present: $TEST_HOME/.local/bin/yadem -> $(yadem_bin)"
}

@test "install-self updates an existing symlink" {
    local other_target="$BATS_TEST_TMPDIR/other-yadem.$BATS_TEST_NUMBER"

    printf "old\n" > "$other_target"
    mkdir -p "$TEST_HOME/.local/bin"
    ln -s "$other_target" "$TEST_HOME/.local/bin/yadem"

    run_yadem install-self

    assert_success
    [[ "$(readlink "$TEST_HOME/.local/bin/yadem")" == "$(yadem_bin)" ]]
    assert_output_contains "Updated yadem symlink: $TEST_HOME/.local/bin/yadem -> $(yadem_bin)"
}

@test "install-self fails clearly when a non-yadem path exists" {
    mkdir -p "$TEST_HOME/.local/bin"
    printf "not yadem\n" > "$TEST_HOME/.local/bin/yadem"

    run_yadem install-self

    assert_failure
    assert_output_contains "Refusing to replace existing non-yadem path: $TEST_HOME/.local/bin/yadem"
    [[ "$(cat "$TEST_HOME/.local/bin/yadem")" == "not yadem" ]]
}

@test "YADEM_PATH_DIR overrides install-self destination" {
    local custom_dir="$TEST_HOME/custom-bin"

    export YADEM_PATH_DIR="$custom_dir"

    run_yadem install-self

    assert_success
    [[ -L "$custom_dir/yadem" ]]
    [[ "$(readlink "$custom_dir/yadem")" == "$(yadem_bin)" ]]
    assert_output_contains "Linked yadem: $custom_dir/yadem -> $(yadem_bin)"
}
