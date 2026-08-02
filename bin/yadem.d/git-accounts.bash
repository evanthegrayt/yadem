# @description Prints help for the git-accounts target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] git-accounts

Generate or reuse local SSH keys and help add them to GitHub and GitLab.

Configuration:
  YADEM_GIT_ACCOUNTS             Bash array: github, gitlab
  YADEM_GIT_SSH_ENABLED          Generate/reuse/print SSH keys when true
  YADEM_GIT_SSH_KEY_PATH         Private SSH key path
  YADEM_GIT_SSH_KEY_TYPE         ssh-keygen -t value
  YADEM_GIT_SSH_KEYGEN_OPTIONS   Extra ssh-keygen options as a Bash array
  YADEM_GIT_SSH_COMMENT          ssh-keygen -C value
  YADEM_GIT_KEY_TITLE            Key title used by gh/glab uploads
  YADEM_GIT_AUTO_UPLOAD          Try gh/glab uploads when true
  YADEM_GITLAB_WEB_URL           GitLab web base URL for manual links
  YADEM_GPG_ENABLED              Export/upload a configured GPG key when true
  YADEM_GPG_KEY_ID               GPG key ID or email to export
  YADEM_GPG_PUBLIC_KEY_PATH      Exported public GPG key path

SSH behavior:
  Existing keys are reused.
  Missing public keys are derived from existing private keys.
  Missing key pairs are generated with ssh-keygen.
  Public keys are printed so they can be copied manually.

Automation:
  GitHub uses gh when it is installed and authenticated.
  GitLab uses glab when it is installed and authenticated.
  Manual account links are always printed.

GPG behavior:
  This target does not generate GPG keys. When YADEM_GPG_ENABLED=true and
  YADEM_GPG_KEY_ID is configured, it exports the public key and tries supported
  uploads.

Dry-run:
  yadem --test git-accounts

Dry-run reports key generation, export, upload, and link actions without
creating keys or contacting GitHub/GitLab.
HELP
}

# @description Resolves the public key path for a private SSH key path.
# @arg $1 string Private SSH key path.
# @stdout Public SSH key path.
# @exitcode 0 Always.
ssh_public_key_path_for() {
    printf "%s.pub\n" "$1"
}

# @description Prints extra ssh-keygen options for messages.
# @noargs
# @stdout Joined configured ssh-keygen options.
# @exitcode 0 Always.
ssh_keygen_options_summary() {
    if ((${#YADEM_GIT_SSH_KEYGEN_OPTIONS[@]} == 0)); then
        printf "%s\n" "(none)"
        return
    fi

    printf "%s " "${YADEM_GIT_SSH_KEYGEN_OPTIONS[@]}"
    printf "\n"
}

# @description Generates, reuses, or repairs the configured SSH key pair.
# @noargs
# @exitcode 0 SSH is disabled or a public key is available.
# @exitcode 1 ssh-keygen is missing or key generation failed.
prepare_ssh_key() {
    local key_path="$YADEM_GIT_SSH_KEY_PATH"
    local public_key_path

    public_key_path="$(ssh_public_key_path_for "$key_path")"

    if [[ "$YADEM_GIT_SSH_ENABLED" != true ]]; then
        say_and_log skipped "SSH key setup is disabled"
        return
    fi

    if [[ -f "$key_path" && -f "$public_key_path" ]]; then
        say_and_log present "SSH key already exists: $key_path"
        return
    fi

    if [[ -f "$key_path" && ! -f "$public_key_path" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-derive-public-key "Would derive SSH public key: $public_key_path"
            return
        fi

        require_command ssh-keygen || return
        ssh-keygen -y -f "$key_path" > "$public_key_path"
        say_and_log derived-public-key "Derived SSH public key: $public_key_path"
        return
    fi

    if [[ ! -f "$key_path" && -f "$public_key_path" ]]; then
        say_and_log present "SSH public key exists without private key: $public_key_path"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-generate "Would generate SSH key: $key_path"
        say_and_log would-run "Would run ssh-keygen with type $YADEM_GIT_SSH_KEY_TYPE and options: $(ssh_keygen_options_summary)"
        return
    fi

    require_command ssh-keygen || return
    yadem_ensure_dir "$(dirname -- "$key_path")" || return
    chmod 700 "$(dirname -- "$key_path")" 2>/dev/null || true
    say_and_log generating "Generating SSH key: $key_path"
    ssh-keygen \
        -t "$YADEM_GIT_SSH_KEY_TYPE" \
        -C "$YADEM_GIT_SSH_COMMENT" \
        -f "$key_path" \
        "${YADEM_GIT_SSH_KEYGEN_OPTIONS[@]}"

    if [[ ! -f "$key_path" || ! -f "$public_key_path" ]]; then
        say_and_log missing-generated-key "ssh-keygen did not create expected key pair: $key_path"
        return 1
    fi
}

# @description Prints the configured SSH public key.
# @noargs
# @exitcode 0 SSH is disabled or the public key was printed.
# @exitcode 1 SSH is enabled but the public key is missing.
print_ssh_public_key() {
    local public_key_path

    [[ "$YADEM_GIT_SSH_ENABLED" == true ]] || return 0

    public_key_path="$(ssh_public_key_path_for "$YADEM_GIT_SSH_KEY_PATH")"
    if [[ ! -f "$public_key_path" ]]; then
        say_and_log missing-public-key "SSH public key not found: $public_key_path"
        return 1
    fi

    say "SSH public key ($public_key_path):"
    cat "$public_key_path"
    log_event printed-public-key "Printed SSH public key: $public_key_path"
}

# @description Builds a GitLab user settings URL.
# @arg $1 string Settings path such as ssh_keys or gpg_keys.
# @stdout GitLab settings URL.
# @exitcode 0 Always.
gitlab_settings_url() {
    local settings_path="$1"
    local web_url="${YADEM_GITLAB_WEB_URL%/}"

    printf "%s/-/user_settings/%s\n" "$web_url" "$settings_path"
}

# @description Prints manual account links for a configured account.
# @arg $1 string Account name.
# @exitcode 0 A link was printed or the account was unknown.
print_manual_links() {
    local account="$1"

    case "$account" in
        github)
            if [[ "$YADEM_GIT_SSH_ENABLED" == true ]]; then
                say_and_log manual-link "Add GitHub SSH key: https://github.com/settings/ssh/new"
            fi
            if [[ "$YADEM_GPG_ENABLED" == true ]]; then
                say_and_log manual-link "Add GitHub GPG key: https://github.com/settings/gpg/new"
            fi
            ;;
        gitlab)
            if [[ "$YADEM_GIT_SSH_ENABLED" == true ]]; then
                say_and_log manual-link "Add GitLab SSH key: $(gitlab_settings_url ssh_keys)"
            fi
            if [[ "$YADEM_GPG_ENABLED" == true ]]; then
                say_and_log manual-link "Add GitLab GPG key: $(gitlab_settings_url gpg_keys)"
            fi
            ;;
        *)
            say_and_log skipped-account "Unsupported git account: $account"
            ;;
    esac
}

# @description Checks whether a CLI is installed and authenticated.
# @arg $1 string CLI executable name.
# @exitcode 0 CLI exists and auth status succeeds.
# @exitcode 1 CLI is missing or unauthenticated.
git_account_cli_authenticated() {
    local cli="$1"

    command -v "$cli" >/dev/null 2>&1 || return 1
    "$cli" auth status >/dev/null 2>&1
}

# @description Uploads the configured SSH key to GitHub when possible.
# @exitcode 0 Upload succeeded, was skipped, or dry-run reported it.
# @exitcode 1 gh upload failed.
upload_github_ssh_key() {
    local public_key_path

    [[ "$YADEM_GIT_SSH_ENABLED" == true ]] || return 0
    public_key_path="$(ssh_public_key_path_for "$YADEM_GIT_SSH_KEY_PATH")"

    if [[ "$YADEM_GIT_AUTO_UPLOAD" != true ]]; then
        say_and_log skipped-upload "GitHub SSH upload skipped: YADEM_GIT_AUTO_UPLOAD is not true"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-upload "Would upload SSH key to GitHub with gh when available and authenticated"
        return
    fi

    if ! git_account_cli_authenticated gh; then
        say_and_log skipped-upload "GitHub SSH upload skipped: gh is missing or unauthenticated"
        return
    fi

    gh ssh-key add "$public_key_path" --title "$YADEM_GIT_KEY_TITLE" --type authentication
    say_and_log uploaded "Uploaded SSH key to GitHub: $YADEM_GIT_KEY_TITLE"
}

# @description Uploads the configured SSH key to GitLab when possible.
# @exitcode 0 Upload succeeded, was skipped, or dry-run reported it.
# @exitcode 1 glab upload failed.
upload_gitlab_ssh_key() {
    local public_key_path

    [[ "$YADEM_GIT_SSH_ENABLED" == true ]] || return 0
    public_key_path="$(ssh_public_key_path_for "$YADEM_GIT_SSH_KEY_PATH")"

    if [[ "$YADEM_GIT_AUTO_UPLOAD" != true ]]; then
        say_and_log skipped-upload "GitLab SSH upload skipped: YADEM_GIT_AUTO_UPLOAD is not true"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-upload "Would upload SSH key to GitLab with glab when available and authenticated"
        return
    fi

    if ! git_account_cli_authenticated glab; then
        say_and_log skipped-upload "GitLab SSH upload skipped: glab is missing or unauthenticated"
        return
    fi

    glab ssh-key add "$public_key_path" -t "$YADEM_GIT_KEY_TITLE" --usage-type auth
    say_and_log uploaded "Uploaded SSH key to GitLab: $YADEM_GIT_KEY_TITLE"
}

# @description Exports the configured public GPG key.
# @exitcode 0 GPG is disabled, skipped, exported, or dry-run reported it.
# @exitcode 1 gpg is missing or export failed.
prepare_gpg_public_key() {
    if [[ "$YADEM_GPG_ENABLED" != true ]]; then
        return
    fi

    if [[ -z "$YADEM_GPG_KEY_ID" ]]; then
        say_and_log skipped-gpg "GPG key export skipped: YADEM_GPG_KEY_ID is not configured"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-export-gpg "Would export GPG public key for $YADEM_GPG_KEY_ID to $YADEM_GPG_PUBLIC_KEY_PATH"
        return
    fi

    require_command gpg || return
    yadem_ensure_dir "$(dirname -- "$YADEM_GPG_PUBLIC_KEY_PATH")" || return
    gpg --armor --export "$YADEM_GPG_KEY_ID" > "$YADEM_GPG_PUBLIC_KEY_PATH"
    say_and_log exported-gpg "Exported GPG public key: $YADEM_GPG_PUBLIC_KEY_PATH"
}

# @description Prints the configured exported GPG public key.
# @exitcode 0 GPG is disabled, skipped, or the key was printed.
# @exitcode 1 GPG is enabled but the exported key is missing.
print_gpg_public_key() {
    [[ "$YADEM_GPG_ENABLED" == true ]] || return 0
    [[ -n "$YADEM_GPG_KEY_ID" ]] || return 0

    if [[ ! -f "$YADEM_GPG_PUBLIC_KEY_PATH" ]]; then
        say_and_log missing-gpg-public-key "GPG public key export not found: $YADEM_GPG_PUBLIC_KEY_PATH"
        return 1
    fi

    say "GPG public key ($YADEM_GPG_PUBLIC_KEY_PATH):"
    cat "$YADEM_GPG_PUBLIC_KEY_PATH"
    log_event printed-gpg-public-key "Printed GPG public key: $YADEM_GPG_PUBLIC_KEY_PATH"
}

# @description Uploads the configured GPG key to GitHub when possible.
# @exitcode 0 Upload succeeded, was skipped, or dry-run reported it.
# @exitcode 1 gh upload failed.
upload_github_gpg_key() {
    [[ "$YADEM_GPG_ENABLED" == true && -n "$YADEM_GPG_KEY_ID" ]] || return 0

    if [[ "$YADEM_GIT_AUTO_UPLOAD" != true ]]; then
        say_and_log skipped-upload "GitHub GPG upload skipped: YADEM_GIT_AUTO_UPLOAD is not true"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-upload "Would upload GPG key to GitHub with gh when available and authenticated"
        return
    fi

    if ! git_account_cli_authenticated gh; then
        say_and_log skipped-upload "GitHub GPG upload skipped: gh is missing or unauthenticated"
        return
    fi

    gh gpg-key add "$YADEM_GPG_PUBLIC_KEY_PATH" --title "$YADEM_GIT_KEY_TITLE"
    say_and_log uploaded "Uploaded GPG key to GitHub: $YADEM_GIT_KEY_TITLE"
}

# @description Uploads the configured GPG key to GitLab when possible.
# @exitcode 0 Upload succeeded, was skipped, or dry-run reported it.
# @exitcode 1 glab upload failed.
upload_gitlab_gpg_key() {
    [[ "$YADEM_GPG_ENABLED" == true && -n "$YADEM_GPG_KEY_ID" ]] || return 0

    if [[ "$YADEM_GIT_AUTO_UPLOAD" != true ]]; then
        say_and_log skipped-upload "GitLab GPG upload skipped: YADEM_GIT_AUTO_UPLOAD is not true"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-upload "Would upload GPG key to GitLab with glab when available and authenticated"
        return
    fi

    if ! git_account_cli_authenticated glab; then
        say_and_log skipped-upload "GitLab GPG upload skipped: glab is missing or unauthenticated"
        return
    fi

    glab gpg-key add "$YADEM_GPG_PUBLIC_KEY_PATH"
    say_and_log uploaded "Uploaded GPG key to GitLab: $YADEM_GIT_KEY_TITLE"
}

# @description Handles upload attempts for one configured account.
# @arg $1 string Account name.
# @exitcode 0 Account was handled or skipped.
# @exitcode 1 A supported upload failed.
handle_account() {
    local account="$1"

    case "$account" in
        github)
            upload_github_ssh_key || return
            upload_github_gpg_key || return
            ;;
        gitlab)
            upload_gitlab_ssh_key || return
            upload_gitlab_gpg_key || return
            ;;
        *)
            say_and_log skipped-account "Unsupported git account: $account"
            return
            ;;
    esac

    print_manual_links "$account"
}

# @description Prepares local keys and helps add them to GitHub/GitLab.
# @noargs
# @exitcode 0 Keys were prepared, printed, uploaded, skipped, or dry-run reported actions.
# @exitcode 1 A required command or upload failed.
install() {
    local account

    load_yadem_config

    prepare_ssh_key || return
    if [[ "$DRY_RUN" != true ]]; then
        print_ssh_public_key || return
    fi

    prepare_gpg_public_key || return
    if [[ "$DRY_RUN" != true ]]; then
        print_gpg_public_key || return
    fi

    for account in "${YADEM_GIT_ACCOUNTS[@]}"; do
        handle_account "$account" || return
    done

    if [[ "$DRY_RUN" == true ]]; then
        say "Dry run complete. $(log_status_message)"
    else
        say "Done. $(log_status_message)"
    fi
}

# @description Previews git account key setup.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
