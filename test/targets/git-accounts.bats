#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2154

load ../test_helper

setup() {
    setup_install_home
}

setup_fake_git_account_tools() {
    TEST_FAKE_BIN="$BATS_TEST_TMPDIR/fake-bin.$BATS_TEST_NUMBER"
    export TEST_FAKE_BIN

    mkdir -p "$TEST_FAKE_BIN"

    cat > "$TEST_FAKE_BIN/ssh-keygen" <<'SH'
#!/usr/bin/env bash
set -e

if [[ "$1" == -y ]]; then
    while (($#)); do
        if [[ "$1" == -f ]]; then
            shift
            key_path="$1"
            break
        fi
        shift
    done
    printf "ssh-ed25519 derived-from-%s\n" "$key_path"
    exit
fi

while (($#)); do
    case "$1" in
        -t)
            shift
            key_type="$1"
            ;;
        -C)
            shift
            comment="$1"
            ;;
        -f)
            shift
            key_path="$1"
            ;;
        *)
            printf "%s\n" "$1" >> "${TEST_KEYGEN_ARGS_LOG:?}"
            ;;
    esac
    shift
done

mkdir -p "$(dirname -- "$key_path")"
printf "private %s %s\n" "$key_type" "$comment" > "$key_path"
printf "ssh-%s fake-public-key %s\n" "$key_type" "$comment" > "$key_path.pub"
SH

    cat > "$TEST_FAKE_BIN/gh" <<'SH'
#!/usr/bin/env bash
set -e

if [[ "$1 $2" == "auth status" ]]; then
    exit "${TEST_GH_AUTH_STATUS:-0}"
fi

{
    printf "gh"
    printf " <%s>" "$@"
    printf "\n"
} >> "${TEST_UPLOAD_LOG:?}"
SH

    cat > "$TEST_FAKE_BIN/glab" <<'SH'
#!/usr/bin/env bash
set -e

if [[ "$1 $2" == "auth status" ]]; then
    exit "${TEST_GLAB_AUTH_STATUS:-0}"
fi

{
    printf "glab"
    printf " <%s>" "$@"
    printf "\n"
} >> "${TEST_UPLOAD_LOG:?}"
SH

    cat > "$TEST_FAKE_BIN/gpg" <<'SH'
#!/usr/bin/env bash
set -e

if [[ "$1 $2" != "--armor --export" ]]; then
    exit 1
fi

printf "%s\n" "-----BEGIN PGP PUBLIC KEY BLOCK-----"
printf "fake-gpg-key %s\n" "$3"
printf "%s\n" "-----END PGP PUBLIC KEY BLOCK-----"
SH

    chmod +x "$TEST_FAKE_BIN/ssh-keygen" "$TEST_FAKE_BIN/gh" "$TEST_FAKE_BIN/glab" "$TEST_FAKE_BIN/gpg"
}

@test "git-accounts dry-run reports ssh setup, uploads, and manual links" {
    run_yadem --test git-accounts

    assert_success
    assert_output_contains "Would generate SSH key: $TEST_HOME/.ssh/id_ed25519"
    assert_output_contains "Would upload SSH key to GitHub with gh when available and authenticated"
    assert_output_contains "Would upload SSH key to GitLab with glab when available and authenticated"
    assert_output_contains "Add GitHub SSH key: https://github.com/settings/ssh/new"
    assert_output_contains "Add GitLab SSH key: https://gitlab.com/-/user_settings/ssh_keys"
    assert_output_contains "Dry run complete."
}

@test "git-accounts generates an ssh key and uploads with authenticated cli tools" {
    setup_fake_git_account_tools
    export PATH="$TEST_FAKE_BIN:$PATH"
    export TEST_UPLOAD_LOG="$BATS_TEST_TMPDIR/uploads.$BATS_TEST_NUMBER"
    export TEST_KEYGEN_ARGS_LOG="$BATS_TEST_TMPDIR/keygen-args.$BATS_TEST_NUMBER"
    write_yadem_config \
        "YADEM_GIT_SSH_KEY_PATH=\"$TEST_HOME/.ssh/custom_ed25519\"" \
        "YADEM_GIT_SSH_COMMENT=\"me@example.com\"" \
        "YADEM_GIT_KEY_TITLE=\"Test Machine\"" \
        "YADEM_GIT_SSH_KEYGEN_OPTIONS=(-N \"\")"

    run_yadem git-accounts

    assert_success
    assert_output_contains "Generating SSH key: $TEST_HOME/.ssh/custom_ed25519"
    assert_output_contains "SSH public key ($TEST_HOME/.ssh/custom_ed25519.pub):"
    assert_output_contains "ssh-ed25519 fake-public-key me@example.com"
    assert_output_contains "Uploaded SSH key to GitHub: Test Machine"
    assert_output_contains "Uploaded SSH key to GitLab: Test Machine"
    assert_file_contains "$TEST_UPLOAD_LOG" "gh <ssh-key> <add> <$TEST_HOME/.ssh/custom_ed25519.pub> <--title> <Test Machine> <--type> <authentication>"
    assert_file_contains "$TEST_UPLOAD_LOG" "glab <ssh-key> <add> <$TEST_HOME/.ssh/custom_ed25519.pub> <-t> <Test Machine> <--usage-type> <auth>"
    assert_file_contains "$TEST_KEYGEN_ARGS_LOG" "-N"
}

@test "git-accounts prints links when cli tools are unavailable" {
    write_yadem_config \
        "YADEM_GIT_SSH_KEY_PATH=\"$TEST_HOME/.ssh/id_ed25519\"" \
        "YADEM_GIT_AUTO_UPLOAD=true"
    mkdir -p "$TEST_HOME/.ssh"
    printf "private\n" > "$TEST_HOME/.ssh/id_ed25519"
    printf "ssh-ed25519 fake-public-key\n" > "$TEST_HOME/.ssh/id_ed25519.pub"

    run_yadem git-accounts

    assert_success
    assert_output_contains "GitHub SSH upload skipped: gh is missing or unauthenticated"
    assert_output_contains "GitLab SSH upload skipped: glab is missing or unauthenticated"
    assert_output_contains "Add GitHub SSH key: https://github.com/settings/ssh/new"
    assert_output_contains "Add GitLab SSH key: https://gitlab.com/-/user_settings/ssh_keys"
}

@test "git-accounts supports custom ssh key type and options" {
    setup_fake_git_account_tools
    export PATH="$TEST_FAKE_BIN:$PATH"
    export TEST_UPLOAD_LOG="$BATS_TEST_TMPDIR/uploads.$BATS_TEST_NUMBER"
    export TEST_KEYGEN_ARGS_LOG="$BATS_TEST_TMPDIR/keygen-args.$BATS_TEST_NUMBER"
    write_yadem_config \
        "YADEM_GIT_ACCOUNTS=(gitlab)" \
        "YADEM_GIT_AUTO_UPLOAD=false" \
        "YADEM_GIT_SSH_KEY_PATH=\"$TEST_HOME/.ssh/id_ed25519_sk\"" \
        "YADEM_GIT_SSH_KEY_TYPE=\"ed25519-sk\"" \
        "YADEM_GIT_SSH_COMMENT=\"security-key@example.com\"" \
        "YADEM_GIT_SSH_KEYGEN_OPTIONS=(-O resident -N \"\")"

    run_yadem git-accounts

    assert_success
    assert_output_contains "ssh-ed25519-sk fake-public-key security-key@example.com"
    assert_output_contains "GitLab SSH upload skipped: YADEM_GIT_AUTO_UPLOAD is not true"
    assert_output_not_contains "GitHub"
    assert_file_contains "$TEST_KEYGEN_ARGS_LOG" "-O"
    assert_file_contains "$TEST_KEYGEN_ARGS_LOG" "resident"
}

@test "git-accounts derives a missing public key from an existing private key" {
    setup_fake_git_account_tools
    export PATH="$TEST_FAKE_BIN:$PATH"
    export TEST_UPLOAD_LOG="$BATS_TEST_TMPDIR/uploads.$BATS_TEST_NUMBER"
    export TEST_KEYGEN_ARGS_LOG="$BATS_TEST_TMPDIR/keygen-args.$BATS_TEST_NUMBER"
    write_yadem_config \
        "YADEM_GIT_ACCOUNTS=(github)" \
        "YADEM_GIT_AUTO_UPLOAD=false" \
        "YADEM_GIT_SSH_KEY_PATH=\"$TEST_HOME/.ssh/id_ed25519\""
    mkdir -p "$TEST_HOME/.ssh"
    printf "private\n" > "$TEST_HOME/.ssh/id_ed25519"

    run_yadem git-accounts

    assert_success
    assert_output_contains "Derived SSH public key: $TEST_HOME/.ssh/id_ed25519.pub"
    assert_output_contains "ssh-ed25519 derived-from-$TEST_HOME/.ssh/id_ed25519"
}

@test "git-accounts exports and uploads a configured gpg key" {
    setup_fake_git_account_tools
    export PATH="$TEST_FAKE_BIN:$PATH"
    export TEST_UPLOAD_LOG="$BATS_TEST_TMPDIR/uploads.$BATS_TEST_NUMBER"
    export TEST_KEYGEN_ARGS_LOG="$BATS_TEST_TMPDIR/keygen-args.$BATS_TEST_NUMBER"
    write_yadem_config \
        "YADEM_GIT_ACCOUNTS=(github gitlab)" \
        "YADEM_GIT_SSH_ENABLED=false" \
        "YADEM_GPG_ENABLED=true" \
        "YADEM_GPG_KEY_ID=\"me@example.com\"" \
        "YADEM_GPG_PUBLIC_KEY_PATH=\"$TEST_HOME/gpg-public.asc\"" \
        "YADEM_GIT_KEY_TITLE=\"Test Machine\""

    run_yadem git-accounts

    assert_success
    assert_output_contains "Exported GPG public key: $TEST_HOME/gpg-public.asc"
    assert_output_contains "GPG public key ($TEST_HOME/gpg-public.asc):"
    assert_output_contains "fake-gpg-key me@example.com"
    assert_output_contains "Uploaded GPG key to GitHub: Test Machine"
    assert_output_contains "Uploaded GPG key to GitLab: Test Machine"
    assert_output_contains "Add GitHub GPG key: https://github.com/settings/gpg/new"
    assert_output_contains "Add GitLab GPG key: https://gitlab.com/-/user_settings/gpg_keys"
    assert_file_contains "$TEST_UPLOAD_LOG" "gh <gpg-key> <add> <$TEST_HOME/gpg-public.asc> <--title> <Test Machine>"
    assert_file_contains "$TEST_UPLOAD_LOG" "glab <gpg-key> <add> <$TEST_HOME/gpg-public.asc>"
}
