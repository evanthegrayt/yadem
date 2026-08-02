#!/usr/bin/env bats
# shellcheck disable=SC2154

load test_helper

setup() {
    setup_install_home
}

bash_completions() {
    local current="${1:-}"
    local command_path="${2:-$(yadem_bin)}"

    HOME="$TEST_HOME" YADEM_TARGET_DIRS="${YADEM_TARGET_DIRS:-}" run bash -c '
        source "$1"
        COMP_WORDS=("$2" "${3:-}")
        COMP_CWORD=1
        _yadem_completion
        printf "%s\n" "${COMPREPLY[@]}"
    ' bash "$(repo_root)/completions/yadem.bash" "$command_path" "$current"
}

zsh_completions() {
    local command_path="${1:-$(yadem_bin)}"

    HOME="$TEST_HOME" YADEM_TARGET_DIRS="${YADEM_TARGET_DIRS:-}" run zsh -fc '
        words=("$2" "")
        _arguments() {
            state=targets
        }
        _describe() {
            local -a values
            values=("${(@P)2}")
            print -rl -- "${values[@]}"
        }
        source "$1"
    ' zsh "$(repo_root)/completions/yadem.zsh" "$command_path"
}

zsh_completion_options() {
    run zsh -fc '
        words=("$2" "--")
        _arguments() {
            print -rl -- "$@"
        }
        _describe() {
            :
        }
        source "$1"
    ' zsh "$(repo_root)/completions/yadem.zsh" "$(yadem_bin)"
}

completion_bash_includes_verbose_option() { # @test
    bash_completions --

    assert_success
    assert_output_contains "--verbose"
}

completion_zsh_includes_verbose_option() { # @test
    zsh_completion_options

    assert_success
    assert_output_contains "--verbose[show resolved target paths with --list]"
}

completion_bash_resolves_symlinked_yadem_for_bundled_targets() { # @test
    local path_dir="$BATS_TEST_TMPDIR/path-bin.$BATS_TEST_NUMBER"

    mkdir -p "$path_dir"
    ln -s "$(yadem_bin)" "$path_dir/yadem"

    bash_completions "" "$path_dir/yadem"

    assert_success
    assert_output_contains "brew"
    assert_output_contains "dotfiles"
    assert_output_contains "install-self"
}

completion_zsh_resolves_symlinked_yadem_for_bundled_targets() { # @test
    local path_dir="$BATS_TEST_TMPDIR/path-bin.$BATS_TEST_NUMBER"

    mkdir -p "$path_dir"
    ln -s "$(yadem_bin)" "$path_dir/yadem"

    zsh_completions "$path_dir/yadem"

    assert_success
    assert_output_contains "brew"
    assert_output_contains "dotfiles"
    assert_output_contains "install-self"
}

completion_bash_includes_default_user_targets_once_before_bundled_targets() { # @test
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"
    local brew_count

    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/custom.bash"
    printf "\n" > "$target_dir/brew.bash"

    bash_completions

    assert_success
    assert_output_contains "custom"
    assert_output_contains "brew"
    brew_count="$(grep -c -x "brew" <<< "$output")"
    [[ "$brew_count" == 1 ]]
}

completion_zsh_includes_default_user_targets_once_before_bundled_targets() { # @test
    local target_dir="$TEST_HOME/.config/yadem/yadem.d"
    local brew_count

    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/custom.bash"
    printf "\n" > "$target_dir/brew.bash"

    zsh_completions

    assert_success
    assert_output_contains "custom"
    assert_output_contains "brew"
    brew_count="$(grep -c -x "brew" <<< "$output")"
    [[ "$brew_count" == 1 ]]
}

completion_bash_honors_yadem_target_dirs_and_stays_quiet_for_missing_dirs() { # @test
    local missing_dir="$BATS_TEST_TMPDIR/missing-targets.$BATS_TEST_NUMBER"
    local not_dir="$BATS_TEST_TMPDIR/not-a-dir.$BATS_TEST_NUMBER"
    local target_dir="$BATS_TEST_TMPDIR/user-targets.$BATS_TEST_NUMBER"

    printf "not a directory\n" > "$not_dir"
    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/external.bash"
    export YADEM_TARGET_DIRS="$missing_dir:$not_dir:$target_dir"

    bash_completions

    assert_success
    assert_output_contains "external"
    assert_output_contains "brew"
    assert_output_not_contains "missing"
    assert_output_not_contains "not a directory"
}

completion_zsh_honors_yadem_target_dirs_and_stays_quiet_for_missing_dirs() { # @test
    local missing_dir="$BATS_TEST_TMPDIR/missing-targets.$BATS_TEST_NUMBER"
    local not_dir="$BATS_TEST_TMPDIR/not-a-dir.$BATS_TEST_NUMBER"
    local target_dir="$BATS_TEST_TMPDIR/user-targets.$BATS_TEST_NUMBER"

    printf "not a directory\n" > "$not_dir"
    mkdir -p "$target_dir"
    printf "\n" > "$target_dir/external.bash"
    export YADEM_TARGET_DIRS="$missing_dir:$not_dir:$target_dir"

    zsh_completions

    assert_success
    assert_output_contains "external"
    assert_output_contains "brew"
    assert_output_not_contains "missing"
    assert_output_not_contains "not a directory"
}
