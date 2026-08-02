#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

load test_helper

setup() {
    setup_install_home
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
    assert_output_contains "log"
    assert_output_contains "macos"
    assert_output_contains "repos"
    assert_output_contains "shell"
    assert_output_contains "vim"
    assert_output_contains "zsh"
}

@test "global help includes options and targets" {
    run_yadem --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] TARGET [ARGS...]"
    assert_output_contains "-t, --test"
    assert_output_contains "-a, --all"
    assert_output_contains "-l, --list"
    assert_output_contains "-e, --edit"
    assert_output_contains "YADEM_EDITOR"
    assert_output_contains "Run one target per invocation"
    assert_output_contains "dotfiles [OPTIONS] [FILE]"
    assert_output_contains "dotfiles-uninstall [OPTIONS] [FILE]"
    assert_output_contains "log SUBCOMMAND"
    assert_output_contains "vim [OPTIONS]"
}

@test "target help is delegated to the target script" {
    run_yadem dotfiles --help

    assert_success
    assert_output_contains "USAGE: yadem [OPTIONS] dotfiles"
    assert_output_contains "Existing symlinks are replaced"
}

@test "--edit opens a target with configured YADEM_EDITOR first" {
    local configured_editor="$BATS_TEST_TMPDIR/configured-editor.$BATS_TEST_NUMBER"
    local visual_editor="$BATS_TEST_TMPDIR/visual-editor.$BATS_TEST_NUMBER"
    local editor_editor="$BATS_TEST_TMPDIR/editor-editor.$BATS_TEST_NUMBER"

    make_fake_editor "$configured_editor" configured
    make_fake_editor "$visual_editor" visual
    make_fake_editor "$editor_editor" editor
    write_yadem_config "YADEM_EDITOR=\"$configured_editor\""
    export VISUAL="$visual_editor"
    export EDITOR="$editor_editor"

    run_yadem --edit dotfiles

    assert_success
    [[ "$output" == "configured:$(repo_root)/bin/yadem.d/dotfiles.bash" ]]
}

@test "YADEM_CONFIG can point to an arbitrary config filename" {
    local configured_editor="$BATS_TEST_TMPDIR/configured-editor.$BATS_TEST_NUMBER"

    make_fake_editor "$configured_editor" configured
    write_yadem_config "YADEM_EDITOR=\"$configured_editor\""

    run_yadem --edit dotfiles

    assert_success
    [[ "${TEST_YADEM_CONFIG##*/}" != *yademrc* ]]
    [[ "$output" == "configured:$(repo_root)/bin/yadem.d/dotfiles.bash" ]]
}

@test "user config defaults to HOME yademrc when YADEM_CONFIG is unset" {
    local configured_editor="$BATS_TEST_TMPDIR/configured-editor.$BATS_TEST_NUMBER"

    make_fake_editor "$configured_editor" configured
    printf "YADEM_EDITOR=\"%s\"\n" "$configured_editor" > "$TEST_HOME/.yademrc"
    unset YADEM_CONFIG

    run_yadem --edit dotfiles

    assert_success
    [[ "$output" == "configured:$(repo_root)/bin/yadem.d/dotfiles.bash" ]]
}

@test "--edit falls back to VISUAL then EDITOR then vi" {
    local visual_editor="$BATS_TEST_TMPDIR/visual-editor.$BATS_TEST_NUMBER"
    local editor_editor="$BATS_TEST_TMPDIR/editor-editor.$BATS_TEST_NUMBER"
    local fake_bin="$BATS_TEST_TMPDIR/fake-bin.$BATS_TEST_NUMBER"

    make_fake_editor "$visual_editor" visual
    make_fake_editor "$editor_editor" editor
    mkdir -p "$fake_bin"
    make_fake_editor "$fake_bin/vi" vi

    export VISUAL="$visual_editor"
    export EDITOR="$editor_editor"
    run_yadem --edit brew

    assert_success
    [[ "$output" == "visual:$(repo_root)/bin/yadem.d/brew.bash" ]]

    export VISUAL=""
    export EDITOR="$editor_editor"
    run_yadem --edit brew

    assert_success
    [[ "$output" == "editor:$(repo_root)/bin/yadem.d/brew.bash" ]]

    export VISUAL=""
    export EDITOR=""
    PATH="$fake_bin:$PATH" run_yadem --edit brew

    assert_success
    [[ "$output" == "vi:$(repo_root)/bin/yadem.d/brew.bash" ]]
}

@test "--edit validates target shape before opening an editor" {
    local editor_path="$BATS_TEST_TMPDIR/editor.$BATS_TEST_NUMBER"

    make_fake_editor "$editor_path" editor
    export VISUAL="$editor_path"

    run_yadem --edit nope

    assert_failure
    assert_output_contains "Unknown install target: nope"
    assert_output_not_contains "editor:"
}

@test "built-in targets implement print_help without defining help" {
    local target

    for target in "$(repo_root)"/bin/yadem.d/*.bash; do
        [[ -f "$target" ]] || continue
        [[ "$(grep -E -m 1 '^[[:alnum:]_]+\(\) \{' "$target")" == "print_help() {" ]]
        ! grep -E '^help\(\) \{' "$target" >/dev/null
        [[ ! -x "$target" ]]
        [[ "$(head -n 1 "$target")" != "#!"* ]]
    done
}

@test "target help requires print_help and does not fall back to help builtin" {
    local fixture="$BATS_TEST_TMPDIR/interface-fixture.$BATS_TEST_NUMBER"

    mkdir -p "$fixture/bin/lib" "$fixture/bin/yadem.d"
    cp "$(repo_root)/bin/yadem" "$fixture/bin/yadem"
    cp "$(repo_root)/bin/lib/yadem.sh" "$fixture/bin/lib/yadem.sh"
    cat > "$fixture/bin/yadem.d/legacy-help.bash" <<'SH'
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
    chmod +x "$fixture/bin/yadem"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" legacy-help --help

    assert_failure
    assert_output_contains "Target 'legacy-help' does not implement print_help()"
    assert_output_not_contains "legacy help should not run"
    assert_output_not_contains "install should not run"
    assert_output_not_contains "dry_run should not run"
}

@test "target args are opt-in through accepted_arguments" {
    local fixture="$BATS_TEST_TMPDIR/args-fixture.$BATS_TEST_NUMBER"

    mkdir -p "$fixture/bin/lib" "$fixture/bin/yadem.d"
    cp "$(repo_root)/bin/yadem" "$fixture/bin/yadem"
    cp "$(repo_root)/bin/lib/yadem.sh" "$fixture/bin/lib/yadem.sh"
    cat > "$fixture/bin/yadem.d/echo-args.bash" <<'SH'
accepted_arguments() {
    printf "%s\n" "[ARG...]"
}

install() {
    printf "args:"
    printf " <%s>" "$@"
    printf "\n"
}

dry_run() {
    install "$@"
}

print_help() {
    say "echo-args help"
}
SH
    cat > "$fixture/bin/yadem.d/no-args.bash" <<'SH'
install() {
    say "no-args count: $#"
}

dry_run() {
    install
}

print_help() {
    say "no-args help"
}
SH
    printf "%s\n" "extensionless target should be ignored" > "$fixture/bin/yadem.d/extensionless"
    chmod +x "$fixture/bin/yadem"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" echo-args --flag value

    assert_success
    assert_output_contains "args: <--flag> <value>"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" no-args value

    assert_failure
    assert_output_contains "Target 'no-args' does not accept arguments: value"
    assert_output_not_contains "no-args count"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" --list

    assert_success
    assert_output_contains "echo-args"
    assert_output_contains "no-args"
    assert_output_not_contains "echo-args.bash"
    assert_output_not_contains "extensionless"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" --help

    assert_success
    assert_output_contains "echo-args [ARG...]"
    assert_output_contains "no-args"

    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$fixture/bin/yadem" extensionless

    assert_failure
    assert_output_contains "Unknown install target: extensionless"
}

@test "default user target dir is searched before bundled targets" {
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"

    mkdir -p "$target_dir"
    cat > "$target_dir/custom.bash" <<'SH'
accepted_arguments() {
    printf "%s\n" "[VALUE]"
}

print_help() {
    say "custom help"
}

install() {
    printf "custom install: %s\n" "$1"
}

dry_run() {
    printf "custom dry-run: %s\n" "$1"
}
SH

    run_yadem --list

    assert_success
    assert_output_contains "custom"
    assert_output_contains "brew"

    run_yadem custom value

    assert_success
    assert_output_contains "custom install: value"

    run_yadem custom --help

    assert_success
    assert_output_contains "custom help"
}

@test "YADEM_TARGET_DIRS can add target dirs while ignoring missing paths" {
    local missing_dir="$BATS_TEST_TMPDIR/missing-targets.$BATS_TEST_NUMBER"
    local not_dir="$BATS_TEST_TMPDIR/not-a-dir.$BATS_TEST_NUMBER"
    local target_dir="$BATS_TEST_TMPDIR/user-targets.$BATS_TEST_NUMBER"

    printf "not a directory\n" > "$not_dir"
    mkdir -p "$target_dir"
    cat > "$target_dir/external.bash" <<'SH'
print_help() {
    say "external help"
}

install() {
    say "external install"
}

dry_run() {
    say "external dry-run"
}
SH
    export YADEM_TARGET_DIRS="$missing_dir:$not_dir:$target_dir"

    run_yadem --list

    assert_success
    assert_output_contains "external"
    assert_output_contains "brew"

    run_yadem external

    assert_success
    assert_output_contains "external install"
}

@test "user targets override bundled targets by name" {
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"
    local brew_count

    mkdir -p "$target_dir"
    cat > "$target_dir/brew.bash" <<'SH'
print_help() {
    say "user brew help"
}

install() {
    say "user brew install"
}

dry_run() {
    say "user brew dry-run"
}
SH

    run_yadem --list

    assert_success
    brew_count="$(grep -c -x "brew" <<< "$output")"
    [[ "$brew_count" == 1 ]]

    run_yadem brew

    assert_success
    assert_output_contains "user brew install"
    assert_output_not_contains "Installing Homebrew packages from"

    run_yadem brew --help

    assert_success
    assert_output_contains "user brew help"
    assert_output_not_contains "Install packages from the repository Brewfile"
}

@test "normal list stays compact when user targets exist" {
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"

    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/custom.bash"

    run_yadem --list

    assert_success
    assert_output_contains "custom"
    assert_output_contains "brew"
    assert_output_not_contains "$target_dir/custom.bash"
    assert_output_not_contains "$(repo_root)/bin/yadem.d/brew.bash"
}

@test "verbose list shows resolved built-in and user target paths" {
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"

    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/custom.bash"

    run_yadem --list --verbose

    assert_success
    assert_output_contains $'custom\t'"$target_dir/custom.bash"
    assert_output_contains $'brew\t'"$(repo_root)/bin/yadem.d/brew.bash"
    assert_output_not_contains "shadowed"
}

@test "verbose list shows overridden targets as shadowed" {
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"
    local first_brew

    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/brew.bash"

    run_yadem --list --verbose

    assert_success
    first_brew="$(grep -m 1 $'^brew\t' <<< "$output")"
    [[ "$first_brew" == $'brew\t'"$target_dir/brew.bash" ]]
    assert_output_contains $'brew\t'"$(repo_root)/bin/yadem.d/brew.bash"$'\tshadowed'
}

@test "--verbose requires --list" {
    run_yadem --verbose

    assert_failure
    assert_output_contains "--verbose requires --list."
}

@test "unknown target fails with a useful message" {
    run_yadem nope

    assert_failure
    assert_output_contains "Unknown install target: nope"
    assert_output_contains "Run yadem --list"
}

@test "targets that do not accept arguments reject trailing words" {
    run_yadem --test brew nope

    assert_failure
    assert_output_contains "Target 'brew' does not accept arguments: nope"
    assert_output_not_contains "Would install Homebrew packages from"
}

@test "argument-owning targets consume following tokens as arguments" {
    setup_test_dotfiles_repo

    run_yadem --test dotfiles bash

    assert_failure
    assert_output_contains "Dotfile source not found: $TEST_DOTFILES_DIR/bash"
    assert_output_not_contains "Would clone https://github.com/Bash-it/bash-it.git"
}

@test "multiple positional targets are rejected" {
    run_yadem --test brew gems

    assert_failure
    assert_output_contains "Target 'brew' does not accept arguments: gems"
    assert_output_not_contains "Would install Homebrew packages from"
    [[ ! -e "$TEST_CACHE/yadem/install.log" ]]
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
