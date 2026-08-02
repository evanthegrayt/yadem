print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] italics

Enable terminal italics by compiling xterm-256color.terminfo.

This target reads:
  YADEM_DOTFILES_DIR/xterm-256color.terminfo

If YADEM_DOTFILES_DIR is missing, it uses YADEM_DOTFILES_REPO and
YADEM_DOTFILES_REPO_DIR the same way the dotfiles target does.

Install behavior:
  tic "\$YADEM_DOTFILES_DIR/xterm-256color.terminfo"

Non-dry-run installs require the tic command.

Dry-run:
  yadem --test italics

Dry-run reports the dotfiles clone if needed and the tic command that would run.
HELP
}

install() {
    local terminfo
    local source_status=0

    load_yadem_config
    terminfo="$YADEM_DOTFILES_DIR/xterm-256color.terminfo"

    if ensure_dotfiles_source; then
        :
    else
        source_status=$?
        if [[ "$source_status" -ne 2 ]]; then
            return "$source_status"
        fi
    fi

    if [[ ! -f "$terminfo" && "$source_status" -ne 2 ]]; then
        say_and_log missing-terminfo "Terminfo file not found: $terminfo"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-run "Would run tic $terminfo"
        return
    fi

    require_command tic || return
    say_and_log enabling "Enabling terminal italics from $terminfo"
    tic "$terminfo"
}

dry_run() {
    DRY_RUN=true
    install
}
