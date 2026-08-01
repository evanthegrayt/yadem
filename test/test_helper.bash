# shellcheck disable=SC2154

repo_root() {
    cd -- "$BATS_TEST_DIRNAME/.." && pwd -P
}

yadem_bin() {
    printf "%s/bin/yadem\n" "$(repo_root)"
}

setup_install_home() {
    TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/home.XXXXXX")"
    TEST_CACHE="$(mktemp -d "${BATS_TEST_TMPDIR}/cache.XXXXXX")"
    TEST_DOTFILES_REPO="$TEST_HOME/workflow/dotfiles"
    TEST_DOTFILES_DIR="$TEST_DOTFILES_REPO/dotfiles"
    export TEST_HOME TEST_CACHE
    export TEST_DOTFILES_REPO TEST_DOTFILES_DIR
}

run_yadem() {
    HOME="$TEST_HOME" XDG_CACHE_HOME="$TEST_CACHE" run "$(yadem_bin)" "$@"
}

setup_test_dotfiles_repo() {
    mkdir -p "$TEST_DOTFILES_DIR"
    mkdir -p "$TEST_DOTFILES_DIR/config"
    mkdir -p "$TEST_DOTFILES_REPO/.git"
    printf "external zshrc\n" > "$TEST_DOTFILES_DIR/zshrc"
    printf "external bashrc\n" > "$TEST_DOTFILES_DIR/bashrc"
    printf "ignored readme\n" > "$TEST_DOTFILES_DIR/README.md"
}

assert_success() {
    if [[ "$status" -ne 0 ]]; then
        printf "expected success, got status %s\n" "$status" >&2
        printf "%s\n" "$output" >&2
        return 1
    fi
}

assert_failure() {
    if [[ "$status" -eq 0 ]]; then
        printf "expected failure, got status 0\n" >&2
        printf "%s\n" "$output" >&2
        return 1
    fi
}

assert_output_contains() {
    local expected="$1"

    if [[ "$output" != *"$expected"* ]]; then
        printf "expected output to contain: %s\n" "$expected" >&2
        printf "%s\n" "$output" >&2
        return 1
    fi
}

assert_output_not_contains() {
    local unexpected="$1"

    if [[ "$output" == *"$unexpected"* ]]; then
        printf "expected output not to contain: %s\n" "$unexpected" >&2
        printf "%s\n" "$output" >&2
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local expected="$2"

    if [[ ! -f "$file" ]]; then
        printf "expected file to exist: %s\n" "$file" >&2
        return 1
    fi

    if ! grep -F -- "$expected" "$file" >/dev/null 2>&1; then
        printf "expected %s to contain: %s\n" "$file" "$expected" >&2
        printf "%s\n" "$(cat "$file")" >&2
        return 1
    fi
}
