#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
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

@test "dotfiles install skips ignored files by default" {
    setup_test_dotfiles_repo

    run_yadem dotfiles

    assert_success
    assert_output_contains "Skipped ignored dotfile: README.md"
    [[ ! -e "$TEST_HOME/.README.md" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles skipped-ignored"
}

@test "dotfiles all-file install can include ignored files explicitly" {
    setup_test_dotfiles_repo

    run_yadem dotfiles --include-ignored

    assert_success
    [[ -L "$TEST_HOME/.README.md" ]]
    [[ "$(readlink "$TEST_HOME/.README.md")" == "$TEST_DOTFILES_DIR/README.md" ]]
    assert_output_contains "Linked $TEST_HOME/.README.md -> $TEST_DOTFILES_DIR/README.md"
    assert_output_not_contains "Skipped ignored dotfile: README.md"
}

@test "--all dotfiles install skips ignored files by default" {
    setup_test_dotfiles_repo
    write_yadem_config "YADEM_ALL_TARGETS=(dotfiles)"

    run_yadem --all

    assert_success
    assert_output_contains "Running target: dotfiles"
    assert_output_contains "Skipped ignored dotfile: README.md"
    [[ ! -e "$TEST_HOME/.README.md" ]]
}

@test "dotfiles single-file install accepts name without touching unrelated dotfiles" {
    setup_test_dotfiles_repo

    run_yadem dotfiles zshrc

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
    assert_output_contains "Linked $TEST_HOME/.zshrc -> $TEST_DOTFILES_DIR/zshrc"
    assert_output_not_contains "$TEST_HOME/.bashrc"
}

@test "dotfiles single-file install accepts leading dot" {
    setup_test_dotfiles_repo

    run_yadem dotfiles .zshrc

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
}

@test "dotfiles single-file install can include an ignored file explicitly" {
    setup_test_dotfiles_repo

    run_yadem dotfiles --include-ignored README.md

    assert_success
    [[ -L "$TEST_HOME/.README.md" ]]
    [[ "$(readlink "$TEST_HOME/.README.md")" == "$TEST_DOTFILES_DIR/README.md" ]]
    [[ ! -e "$TEST_HOME/.zshrc" ]]
    assert_output_contains "Linked $TEST_HOME/.README.md -> $TEST_DOTFILES_DIR/README.md"
    assert_output_not_contains "Skipped ignored dotfile: README.md"
}

@test "dotfiles single-file dry-run can include an ignored file explicitly" {
    setup_test_dotfiles_repo

    run_yadem --test dotfiles --include-ignored README.md

    assert_success
    assert_output_contains "Would link $TEST_HOME/.README.md -> $TEST_DOTFILES_DIR/README.md"
    assert_output_not_contains "Skipped ignored dotfile: README.md"
    [[ ! -e "$TEST_HOME/.README.md" ]]
}

@test "dotfiles single-file dry-run reports action without modifying home" {
    setup_test_dotfiles_repo

    run_yadem --test dotfiles zshrc

    assert_success
    assert_output_contains "Would link $TEST_HOME/.zshrc -> $TEST_DOTFILES_DIR/zshrc"
    assert_output_contains "Dry run complete. Log written to $TEST_CACHE/yadem/install.log"
    assert_output_not_contains "$TEST_HOME/.bashrc"
    [[ ! -e "$TEST_HOME/.zshrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
}

@test "dotfiles single-file install fails clearly when source is missing" {
    setup_test_dotfiles_repo

    run_yadem dotfiles vimrc

    assert_failure
    assert_output_contains "Dotfile source not found: $TEST_DOTFILES_DIR/vimrc"
    [[ ! -e "$TEST_HOME/.vimrc" ]]
    [[ ! -e "$TEST_HOME/.zshrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
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

@test "dotfiles single-file install backs up existing regular file" {
    setup_test_dotfiles_repo
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"

    run_yadem dotfiles zshrc

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ "$(readlink "$TEST_HOME/.zshrc")" == "$TEST_DOTFILES_DIR/zshrc" ]]
    [[ -f "$TEST_CACHE/yadem/zshrc.$(date +%F)" ]]
    [[ "$(cat "$TEST_CACHE/yadem/zshrc.$(date +%F)")" == "local zshrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles backed-up"
}

@test "dotfiles single-file install can preserve supported existing files as local files" {
    setup_test_dotfiles_repo
    write_yadem_config \
        "YADEM_LOCALIZE_EXISTING=true" \
        "YADEM_LOCAL_FILES=(zshrc)"
    printf "local zshrc\n" > "$TEST_HOME/.zshrc"

    run_yadem dotfiles zshrc

    assert_success
    [[ -L "$TEST_HOME/.zshrc" ]]
    [[ -L "$TEST_HOME/.zshrc.local" ]]
    [[ "$(cat "$TEST_HOME/.zshrc.local")" == "local zshrc" ]]
    [[ ! -e "$TEST_HOME/.bashrc" ]]
    assert_file_contains "$TEST_CACHE/yadem/install.log" "dotfiles linked-local"
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

    YADEM_LOG="$TEST_HOME/not-directory/install.log" run_yadem --test dotfiles

    assert_success
    assert_output_contains "Warning: could not write install log: $TEST_HOME/not-directory/install.log"
    assert_output_contains "Dry run complete. Log could not be written to $TEST_HOME/not-directory/install.log"
}
