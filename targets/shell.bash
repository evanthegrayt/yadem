# @description Prints help for the shell target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] shell

Change the login shell to YADEM_SHELL_LOGIN.

Configuration:
  YADEM_SHELL_LOGIN  Supported values: bash, zsh, csh

This target reads /etc/shells and uses the last executable path ending in the
configured shell name. If YADEM_SHELL_LOGIN is empty, it skips successfully.

Install behavior:
  chsh -s <resolved-shell-path>

Dry-run:
  yadem --test shell

Dry-run reports the resolved shell path without changing the login shell.
HELP
}

# @description Changes the login shell to the configured shell name.
# @noargs
# @exitcode 0 Login shell changed, skipped, or dry-run reported it.
# @exitcode 1 Configuration is invalid, the shell is missing, or `chsh` failed.
install() {
    local shell_name
    local shell_path

    yadem_load_config
    shell_name="$YADEM_SHELL_LOGIN"

    if [[ -z "$shell_name" ]]; then
        yadem_say_and_log skipped "YADEM_SHELL_LOGIN is not configured"
        return
    fi

    case "$shell_name" in
        bash|zsh|csh) ;;
        *)
            yadem_say_and_log invalid-shell "Unsupported shell: $shell_name"
            return 1
            ;;
    esac

    shell_path="$(grep "/$shell_name$" /etc/shells 2>/dev/null | tail -n 1 || true)"

    if [[ -z "$shell_path" || ! -x "$shell_path" ]]; then
        yadem_say_and_log missing-shell "Login shell not found in /etc/shells: $shell_name"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        yadem_say_and_log would-change "Would change login shell to $shell_path"
        return
    fi

    yadem_say_and_log changing "Changing login shell to $shell_path"
    chsh -s "$shell_path"
}

# @description Previews login shell changes.
# @noargs
# @exitcode 0 Dry-run completed or setup was skipped.
dry_run() {
    DRY_RUN=true
    install
}
