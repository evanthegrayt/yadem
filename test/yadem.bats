#!/usr/bin/env bats

load test_helper

setup() {
    setup_install_home
}

write_yadem_config() {
    TEST_YADEM_CONFIG="$BATS_TEST_TMPDIR/yademrc.$BATS_TEST_NUMBER"
    export TEST_YADEM_CONFIG
    export YADEM_CONFIG="$TEST_YADEM_CONFIG"

    printf "%s\n" "$@" > "$TEST_YADEM_CONFIG"
}

@test "list prints available install targets" {
    run_yadem --list

    assert_success
    assert_output_contains "all"
    assert_output_contains "bash"
    assert_output_contains "brew"
    assert_output_contains "dotfiles"
    assert_output_contains "dotfiles-uninstall"
    assert_output_contains "gems"
    assert_output_contains "homebrew"
    assert_output_contains "italics"
    assert_output_contains "macos"
    assert_output_contains "repos"
    assert_output_contains "shell"
    assert_output_contains "vim"
    assert_output_contains "zsh"
}

@test "global help includes options and targets" {
    run_yadem --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] TARGET [TARGET...]"
    assert_output_contains "-t, --test"
    assert_output_contains "-a, --all"
    assert_output_contains "-l, --list"
    assert_output_contains "dotfiles"
}

@test "target help is delegated to the target script" {
    run_yadem dotfiles --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] dotfiles"
    assert_output_contains "Existing symlinks are replaced"
}

@test "built-in targets implement print_help without defining help" {
    local target

    for target in "$(repo_root)"/bin/yadem.d/*; do
        [[ -f "$target" ]] || continue
        grep -E '^print_help\(\) \{' "$target" >/dev/null
        ! grep -E '^help\(\) \{' "$target" >/dev/null
    done
}

@test "target help requires print_help and does not fall back to help builtin" {
    local fixture="$BATS_TEST_TMPDIR/interface-fixture.$BATS_TEST_NUMBER"

    mkdir -p "$fixture/bin/lib" "$fixture/bin/yadem.d"
    cp "$(repo_root)/bin/yadem" "$fixture/bin/yadem"
    cp "$(repo_root)/bin/lib/yadem.sh" "$fixture/bin/lib/yadem.sh"
    cat > "$fixture/bin/yadem.d/legacy-help" <<'SH'
#!/usr/bin/env bash

install() {
    say "install should not run"
}

dry_run() {
    say "dry_run should not run"
}

help() {
    say "legacy help should not run"
}
SH
    chmod +x "$fixture/bin/yadem" "$fixture/bin/yadem.d/legacy-help"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" legacy-help --help

    assert_failure
    assert_output_contains "Target 'legacy-help' does not implement print_help()"
    assert_output_not_contains "legacy help should not run"
    assert_output_not_contains "install should not run"
    assert_output_not_contains "dry_run should not run"
}

@test "dotfiles-uninstall help describes single-file and restore modes" {
    run_yadem dotfiles-uninstall --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] dotfiles-uninstall"
    assert_output_contains "-R, --restore"
    assert_output_contains "zshrc or .zshrc"
}

@test "unknown target fails with a useful message" {
    run_yadem nope

    assert_failure
    assert_output_contains "Unknown install target: nope"
    assert_output_contains "Run yadem --list"
}

@test "unknown second target still fails" {
    run_yadem --test brew nope

    assert_failure
    assert_output_contains "Unknown install target: nope"
    assert_output_contains "Run yadem --list"
}

@test "brew dry-run prints Brewfile action and writes a log" {
    run_yadem --test brew

    assert_success
    assert_output_contains "Would install Homebrew packages from"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "brew would-install"
}

@test "gems dry-run prints gem actions and writes a log" {
    run_yadem --test gems

    assert_success
    assert_output_contains "Would install gem: standard"
    assert_output_contains "Would install gem: spoonerize"
    assert_output_contains "Would install gem: standup_md"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "gems would-install Would install gem: standard"
}

@test "dotfiles dry-run reports actions without modifying home" {
    setup_test_dotfiles_repo
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"
    ln -s /tmp/old-dotfile-target "$TEST_HOME/.bashrc"
    mkdir -p "$TEST_HOME/.config"

    run_yadem --test dotfiles

    assert_success
    assert_output_contains "Would back up $TEST_HOME/.zshrc"
    assert_output_contains "Would replace symlink: $TEST_HOME/.bashrc"
    assert_output_contains "Skipped existing directory: $TEST_HOME/.config"
    assert_output_contains "Dry run complete. Log written to $TEST_CACHE/yadem/install.log"
    assert_output_not_contains "Would link:"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles would-back-up"

    [[ ! -L "$TEST_HOME/.zshrc" ]]
    [[ "$(cat "$TEST_HOME/.zshrc")" == "local zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.bashrc")" == "/tmp/old-dotfile-target" ]]
    [[ -d "$TEST_HOME/.config" ]]
}

@test "dotfiles dry-run reports clone when external repo is missing" {
    run_yadem --test dotfiles

    assert_success
    assert_output_contains "Would clone https://github.com/evanthegrayt/dotfiles.git to $TEST_DOTFILES_REPO"
    assert_output_contains "Dry run complete. Log written to $TEST_CACHE/yadem/install.log"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles would-clone"
    [[ ! -e "$TEST_DOTFILES_REPO" ]]
}

@test "dotfiles repo path follows configured repo dir" {
    write_yadem_config "YADEM_REPO_DIR=\"$TEST_HOME/custom-workflow\""

    run_yadem --test dotfiles

    assert_success
    assert_output_contains "Would clone https://github.com/evanthegrayt/dotfiles.git to $TEST_HOME/custom-workflow/dotfiles"
    [[ ! -e "$TEST_HOME/custom-workflow/dotfiles" ]]
}

@test "dotfiles install links missing files" {
    setup_test_dotfiles_repo

    run_yadem dotfiles

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    assert_output_contains "Done. Log written to $TEST_CACHE/yadem/install.log"
    assert_output_not_contains "Linked:"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles linked"
}

@test "dotfiles install clones missing external repo before linking" {
    local fake_bin="$BATS_TEST_TMPDIR/fake-bin.$BATS_TEST_NUMBER"

    mkdir -p "$fake_bin"
    cat > "$fake_bin/git" <<'SH'
#!/usr/bin/env bash
set -e

if [[ "$1" != clone ]]; then
    exit 1
fi

mkdir -p "$3/.git"
mkdir -p "$3/dotfiles"
printf "cloned zshrc\n" > "$3/dotfiles/zshrc"
SH
    chmod +x "$fake_bin/git"

    PATH="$fake_bin:$PATH" run_yadem dotfiles

    assert_success
    assert_output_contains "Cloning https://github.com/evanthegrayt/dotfiles.git to $TEST_DOTFILES_REPO"
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles cloning"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles linked"
}

@test "dotfiles install replaces existing symlinks" {
    setup_test_dotfiles_repo
    ln -s /tmp/old-dotfile-target "$TEST_HOME/.zshrc"

    run_yadem dotfiles

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    assert_output_contains "Replaced symlink: $TEST_HOME/.zshrc"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles replaced-link"
}

@test "dotfiles install backs up existing regular files" {
    setup_test_dotfiles_repo
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"

    run_yadem dotfiles

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    [[ -f "$TEST_CACHE/yadem/zshrc.$(date +%F)" ]]
    [[ "$(cat "$TEST_CACHE/yadem/zshrc.$(date +%F)")" == "local zshrc" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles backed-up"
}

@test "dotfiles install increments backup names when today's backup exists" {
    setup_test_dotfiles_repo
    mkdir -p "$TEST_CACHE/yadem"
    printf "previous backup\n" > "$TEST_CACHE/yadem/zshrc.$(date +%F)"
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"

    run_yadem dotfiles

    assert_success
    [[ -f "$TEST_CACHE/yadem/zshrc.$(date +%F).1" ]]
    [[ "$(cat "$TEST_CACHE/yadem/zshrc.$(date +%F).1")" == "local zshrc" ]]
}

@test "dotfiles install can preserve supported existing files as local files" {
    setup_test_dotfiles_repo
    write_yadem_config \
        "YADEM_LOCALIZE_EXISTING=true" \
        "YADEM_LOCAL_FILES=(zshrc)"
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"

    run_yadem dotfiles

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ -L "$TEST_HOME/.zshrc.local" ]]
    [[ "$(cat "$TEST_HOME/.zshrc.local")" == "local zshrc" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles linked-local"
}

@test "dotfiles install skips existing directories" {
    setup_test_dotfiles_repo
    mkdir -p "$TEST_HOME/.config"

    run_yadem dotfiles

    assert_success
    [[ -d "$TEST_HOME/.config" ]]
    [[ ! -L "$TEST_HOME/.config" ]]
    assert_output_contains "Skipped existing directory: $TEST_HOME/.config"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles skipped-directory"
}

@test "dotfiles install continues when log cannot be written" {
    setup_test_dotfiles_repo
    printf "not a directory\n" > "$TEST_HOME/not-directory"
    export YADEM_LOG="$TEST_HOME/not-directory/install.log"

    run_yadem --test dotfiles

    assert_success
    assert_output_contains "Warning: could not write install log: $YADEM_LOG"
    assert_output_contains "Dry run complete. Log could not be written to $YADEM_LOG"
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

@test "multiple dry-run targets run in order" {
    run_yadem --test brew gems

    assert_success
    assert_output_contains "Would install Homebrew packages from"
    assert_output_contains "Would install gem: standard"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "brew would-install"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "gems would-install"
}

@test "--all runs the configured target sequence" {
    write_yadem_config \
        "YADEM_ALL_TARGETS=(gems)" \
        "YADEM_GEMS=(example_gem)"

    run_yadem --test --all

    assert_success
    assert_output_contains "Running target: gems"
    assert_output_contains "Would install gem: example_gem"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "all running-target Running target: gems"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "gems would-install Would install gem: example_gem"
}

@test "--all dry-run can plan dotfiles-dependent targets on a fresh home" {
    write_yadem_config "YADEM_ALL_TARGETS=(italics dotfiles)"

    run_yadem --test --all

    assert_success
    assert_output_contains "Running target: italics"
    assert_output_contains "Would clone https://github.com/evanthegrayt/dotfiles.git to $TEST_DOTFILES_REPO"
    assert_output_contains "Would run tic $TEST_DOTFILES_DIR/xterm-256color.terminfo"
    assert_output_contains "Running target: dotfiles"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "italics would-run"
}

@test "repos dry-run uses configured repositories" {
    write_yadem_config \
        "YADEM_REPO_DIR=\"$TEST_HOME/workflow\"" \
        "YADEM_REPOS=(https://github.com/example/project)"

    run_yadem --test repos

    assert_success
    assert_output_contains "Would clone https://github.com/example/project.git to $TEST_HOME/workflow/project"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "repos would-clone"
}

@test "shell dry-run reports missing shell configuration" {
    write_yadem_config "YADEM_LOGIN_SHELL=''"

    run_yadem --test shell

    assert_success
    assert_output_contains "YADEM_LOGIN_SHELL is not configured"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "shell skipped"
}
