#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "dotfiles-uninstall help describes single-file and restore modes" {
    run_yadem dotfiles-uninstall --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] dotfiles-uninstall"
    assert_output_contains "-R, --restore"
    assert_output_contains "zshrc or .zshrc"
}

@test "dotfiles-uninstall dry-run reports managed symlinks without removing them" {
    setup_test_dotfiles_repo
    ln -s "$TEST_DOTFILES_DIR/zshrc" "$TEST_HOME/.zshrc"
    ln -s "$TEST_DOTFILES_DIR/bashrc" "$TEST_HOME/.bashrc"
    ln -s /tmp/not-yadem "$TEST_HOME/.vimrc"

    run_yadem --test dotfiles-uninstall

    assert_success
    assert_output_contains "Would remove symlink: $TEST_HOME/.zshrc -> $TEST_DOTFILES_DIR/zshrc"
    assert_output_contains "Would remove symlink: $TEST_HOME/.bashrc -> $TEST_DOTFILES_DIR/bashrc"
    assert_output_not_contains "$TEST_HOME/.vimrc"
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ -L "$TEST_HOME/.bashrc" ]]
    [[ -L "$TEST_HOME/.vimrc" ]]
}

@test "dotfiles-uninstall removes only symlinks into dotfiles dir" {
    setup_test_dotfiles_repo
    ln -s "$TEST_DOTFILES_DIR/zshrc" "$TEST_HOME/.zshrc"
    ln -s /tmp/not-yadem "$TEST_HOME/.bashrc"

    run_yadem dotfiles-uninstall

    assert_success
    assert_output_contains "Removed symlink: $TEST_HOME/.zshrc -> $TEST_DOTFILES_DIR/zshrc"
    assert_output_not_contains "$TEST_HOME/.bashrc"
    [[ ! -e "$TEST_HOME/.zshrc" ]]
    [[ -L "$TEST_HOME/.bashrc" ]]
}

@test "dotfiles-uninstall single-file mode accepts names with or without leading dot" {
    setup_test_dotfiles_repo
    ln -s "$TEST_DOTFILES_DIR/zshrc" "$TEST_HOME/.zshrc"
    ln -s "$TEST_DOTFILES_DIR/bashrc" "$TEST_HOME/.bashrc"

    run_yadem dotfiles-uninstall zshrc

    assert_success
    assert_output_contains "Removed symlink: $TEST_HOME/.zshrc -> $TEST_DOTFILES_DIR/zshrc"
    [[ ! -e "$TEST_HOME/.zshrc" ]]
    [[ -L "$TEST_HOME/.bashrc" ]]

    run_yadem dotfiles-uninstall .bashrc

    assert_success
    assert_output_contains "Removed symlink: $TEST_HOME/.bashrc -> $TEST_DOTFILES_DIR/bashrc"
    [[ ! -e "$TEST_HOME/.bashrc" ]]
}

@test "dotfiles-uninstall restore mode restores newest matching backup" {
    setup_test_dotfiles_repo
    mkdir -p "$TEST_CACHE/yadem"
    printf "old backup\n" > "$TEST_CACHE/yadem/zshrc.2026-07-31"
    printf "new backup\n" > "$TEST_CACHE/yadem/zshrc.2026-08-01"
    ln -s "$TEST_DOTFILES_DIR/zshrc" "$TEST_HOME/.zshrc"

    run_yadem dotfiles-uninstall -R zshrc

    assert_success
    assert_output_contains "Restored $TEST_HOME/.zshrc from $TEST_CACHE/yadem/zshrc.2026-08-01"
    [[ -f "$TEST_HOME/.zshrc" ]]
    [[ "$(cat "$TEST_HOME/.zshrc")" == "new backup" ]]
    [[ -f "$TEST_CACHE/yadem/zshrc.2026-07-31" ]]
    [[ ! -e "$TEST_CACHE/yadem/zshrc.2026-08-01" ]]
}

@test "dotfiles-uninstall reports no-symlink single-file case" {
    setup_test_dotfiles_repo
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"

    run_yadem dotfiles-uninstall zshrc

    assert_success
    assert_output_contains "$TEST_HOME/.zshrc is not a symlink. Skipping."
    [[ -f "$TEST_HOME/.zshrc" ]]
}

@test "dotfiles-uninstall restore mode reports no backup" {
    setup_test_dotfiles_repo
    ln -s "$TEST_DOTFILES_DIR/zshrc" "$TEST_HOME/.zshrc"

    run_yadem dotfiles-uninstall --restore zshrc

    assert_success
    assert_output_contains "Removed symlink: $TEST_HOME/.zshrc -> $TEST_DOTFILES_DIR/zshrc"
    assert_output_contains "No backup found for zshrc in $TEST_CACHE/yadem"
    [[ ! -e "$TEST_HOME/.zshrc" ]]
}
