print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] log SUBCOMMAND

Inspect or remove the current yadem log file.

The log path defaults to:
  $INSTALL_LOG

Set YADEM_LOG to choose a different log file.

Subcommands:
  path    Print the resolved log path, even if the file does not exist
  list    Print the log path only if the log exists
  show    Print the log contents
  delete  Delete the log file

Dry-run:
  yadem --test log delete

Dry-run only affects delete. It reports the file that would be removed.
HELP
}

accepted_arguments() {
    printf "%s\n" "SUBCOMMAND"
}

log_exists() {
    [[ -e "$INSTALL_LOG" || -L "$INSTALL_LOG" ]]
}

require_log() {
    if log_exists; then
        return
    fi

    printf "No log found at %s\n" "$INSTALL_LOG" >&2
    return 1
}

show_log() {
    require_log || return

    if [[ ! -f "$INSTALL_LOG" ]]; then
        printf "Log path is not a regular file: %s\n" "$INSTALL_LOG" >&2
        return 1
    fi

    if [[ ! -r "$INSTALL_LOG" ]]; then
        printf "Log is not readable: %s\n" "$INSTALL_LOG" >&2
        return 1
    fi

    cat -- "$INSTALL_LOG"
}

delete_log() {
    require_log || return

    if [[ "$DRY_RUN" == true ]]; then
        printf "Would delete log: %s\n" "$INSTALL_LOG"
        return
    fi

    if [[ -d "$INSTALL_LOG" && ! -L "$INSTALL_LOG" ]]; then
        printf "Log path is a directory: %s\n" "$INSTALL_LOG" >&2
        return 1
    fi

    rm -- "$INSTALL_LOG"
    printf "Deleted log: %s\n" "$INSTALL_LOG"
}

install() {
    local subcommand="${1:-}"

    if (($# > 1)); then
        printf "log accepts one subcommand at a time.\n" >&2
        return 1
    fi

    case "$subcommand" in
        path)
            printf "%s\n" "$INSTALL_LOG"
            ;;
        list)
            require_log || return
            printf "%s\n" "$INSTALL_LOG"
            ;;
        show)
            show_log
            ;;
        delete)
            delete_log
            ;;
        -h|--help|"")
            print_help
            ;;
        *)
            printf "Unknown log subcommand: %s\n" "$subcommand" >&2
            print_help >&2
            return 1
            ;;
    esac
}

dry_run() {
    DRY_RUN=true
    install "$@"
}
