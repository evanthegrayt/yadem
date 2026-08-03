# @description Prints help for the log target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
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

# @description Declares the log target subcommand argument.
# @noargs
# @stdout Argument usage fragment.
# @exitcode 0 Always.
accepted_arguments() {
    printf "%s\n" "SUBCOMMAND"
}

# @description Checks whether the current install log path exists.
# @noargs
# @exitcode 0 The log path exists.
# @exitcode 1 The log path does not exist.
log_exists() {
    [[ -e "$INSTALL_LOG" || -L "$INSTALL_LOG" ]]
}

# @description Requires the current install log path to exist.
# @noargs
# @stderr Missing-log message.
# @exitcode 0 The log path exists.
# @exitcode 1 The log path does not exist.
require_log() {
    if log_exists; then
        return
    fi

    printf "No log found at %s\n" "$INSTALL_LOG" >&2
    return 1
}

# @description Prints the current install log.
# @noargs
# @stdout Log contents.
# @stderr Missing, non-file, or unreadable log errors.
# @exitcode 0 The log was printed.
# @exitcode 1 The log cannot be read.
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

# @description Deletes the current install log.
# @noargs
# @stdout Delete or dry-run message.
# @stderr Missing-log or directory errors.
# @exitcode 0 The log was deleted or dry-run reported deletion.
# @exitcode 1 The log cannot be deleted safely.
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

# @description Dispatches the requested log subcommand.
# @arg $1 string Optional subcommand: `path`, `list`, `show`, or `delete`.
# @exitcode 0 Subcommand completed or help was printed.
# @exitcode 1 The subcommand is invalid or failed.
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

# @description Previews log target operations.
# @arg $1 string Optional subcommand.
# @exitcode 0 Dry-run completed or help was printed.
dry_run() {
    DRY_RUN=true
    install "$@"
}
