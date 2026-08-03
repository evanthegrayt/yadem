# @description Prints help for the vim target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] vim [OPTIONS]

Clone YADEM_VIM_REPO into ~/.vim.

Options:
  -f, --force  Back up or replace an existing ~/.vim before cloning

Configuration:
  YADEM_VIM_REPO  Repository cloned recursively into ~/.vim

Existing paths:
  Without --force, an existing ~/.vim path is left alone.
  With --force, an existing symlink is removed.
  With --force, an existing file or directory is moved to:
    $INSTALL_CACHE_DIR/vim.<YYYY-MM-DD>

Dry-run:
  yadem --test vim
  yadem --test vim --force

Dry-run reports backup, replacement, and clone decisions without modifying
files.
HELP
}

# @description Declares that the vim target accepts target-specific options.
# @noargs
# @stdout Argument usage fragment.
# @exitcode 0 Always.
accepted_arguments() {
    printf "%s\n" "[OPTIONS]"
}

# @description Installs the configured Vim repository.
# @arg $@ string Optional `-f` or `--force`.
# @exitcode 0 Vim files are present, cloned, or skipped safely.
# @exitcode 1 Options were invalid or cloning failed.
install() {
    local force=false
    local destination_status

    yadem_load_config

    while (($#)); do
        case "$1" in
            -h|--help)
                print_help
                return
                ;;
            -f|--force)
                force=true
                ;;
            -*)
                yadem_say_and_log invalid-option "Invalid option for vim: $1"
                return 1
                ;;
            *)
                yadem_say_and_log invalid-argument "Invalid argument for vim: $1"
                return 1
                ;;
        esac
        shift
    done

    if yadem_prepare_destination "Vim files" "$HOME/.vim" "" "$force" "Vim files already exist: $HOME/.vim"; then
        :
    else
        destination_status=$?
        # yadem_prepare_destination returns 2 when an existing path should be
        # preserved, which is a successful no-op for this target.
        if [[ "$destination_status" -eq 2 ]]; then
            return
        fi

        return "$destination_status"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        # Dry-run force mode leaves ~/.vim in place, but the real install would
        # remove or back it up before cloning.
        yadem_say_and_log would-clone "Would clone $YADEM_VIM_REPO to $HOME/.vim"
        return
    fi

    yadem_clone_repo_if_missing vim "$YADEM_VIM_REPO" "$HOME/.vim" true
}

# @description Previews the vim target.
# @arg $@ string Optional `-f` or `--force`.
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install "$@"
}
