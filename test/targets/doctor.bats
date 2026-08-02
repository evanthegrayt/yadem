#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "doctor prints config, target, environment, and command diagnostics" {
    write_yadem_config \
        "YADEM_DOTFILES_REPO_DIR=\"$TEST_HOME/custom-dotfiles-repo\"" \
        "YADEM_DOTFILES_DIR=\"$TEST_HOME/custom-dotfiles-repo/source\"" \
        "YADEM_ALL_TARGETS=(doctor)"

    run_yadem doctor

    assert_success
    assert_output_contains "Yadem doctor"
    assert_output_contains "yadem repo path: $(repo_root)"
    assert_output_contains "default config: $(repo_root)/config/yademrc (file)"
    assert_output_contains "user config: $TEST_YADEM_CONFIG (file)"
    assert_output_contains "active config paths:"
    assert_output_contains "$(repo_root)/config/yademrc"
    assert_output_contains "$TEST_YADEM_CONFIG"
    assert_output_contains "resolved target dirs:"
    assert_output_contains "$(repo_root)/targets"
    assert_output_contains "shadowed targets: none"
    assert_output_contains "YADEM_DOTFILES_REPO_DIR: $TEST_HOME/custom-dotfiles-repo"
    assert_output_contains "YADEM_DOTFILES_DIR: $TEST_HOME/custom-dotfiles-repo/source"
    assert_output_contains "INSTALL_CACHE_DIR: $TEST_CACHE/yadem"
    assert_output_contains "INSTALL_LOG: $TEST_CACHE/yadem/install.log"
    assert_output_contains "install cache: ok"
    assert_output_contains "install log parent: ok"
    assert_output_contains "git:"
    assert_output_contains "bash:"
    assert_output_contains "zsh:"
    assert_output_contains "brew:"
    assert_output_contains "gem:"
    assert_output_contains "tic:"
    [[ ! -e "$TEST_CACHE/yadem/install.log" ]]
}

@test "doctor reports shadowed target names" {
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"

    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/brew.bash"

    run_yadem doctor

    assert_success
    assert_output_contains "$target_dir"
    assert_output_contains "shadowed targets:"
    assert_output_contains "    brew"
    assert_output_contains "active: $target_dir/brew.bash"
    assert_output_contains "shadowed: $(repo_root)/targets/brew.bash"
}

@test "doctor dry-run and help follow the target contract" {
    run_yadem --test doctor

    assert_success
    assert_output_contains "Dry-run: doctor is read-only; no changes will be made."
    assert_output_contains "Yadem doctor"

    run_yadem doctor --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] doctor"
    assert_output_contains "This target is read-only."
}
