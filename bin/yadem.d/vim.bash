accepted_arguments() {
    printf "%s\n" "[OPTIONS]"
}

prepare_vim_destination() {
    local directory="$1"
    local force="$2"
    local backup

    if [[ ! -e "$directory" && ! -L "$directory" ]]; then
        return
    fi

    if [[ "$force" != true ]]; then
        say_and_log present "Vim files already exist: $directory"
        return 2
    fi

    if [[ -L "$directory" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-replace-link "Would replace symlink: $directory"
        else
            rm -- "$directory"
            say_and_log replaced-link "Replaced symlink: $directory"
        fi
        return
    fi

    if [[ -f "$directory" || -d "$directory" ]]; then
        backup="$(backup_path_for "$directory")"

        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-back-up "Would back up $directory to $backup"
        else
            mkdir -p "$INSTALL_CACHE_DIR"
            mv -- "$directory" "$backup"
            say_and_log backed-up "Backed up $directory to $backup"
        fi
        return
    fi

    say_and_log skipped-existing "Skipped existing path: $directory"
    return 2
}

install() {
    local force=false
    local destination_status

    load_yadem_config

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
                say_and_log invalid-option "Invalid option for vim: $1"
                return 1
                ;;
            *)
                say_and_log invalid-argument "Invalid argument for vim: $1"
                return 1
                ;;
        esac
        shift
    done

    if prepare_vim_destination "$HOME/.vim" "$force"; then
        :
    else
        destination_status=$?
        if [[ "$destination_status" -eq 2 ]]; then
            return
        fi

        return "$destination_status"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-clone "Would clone $YADEM_VIM_REPO to $HOME/.vim"
        return
    fi

    require_command git || return
    say_and_log cloning "Cloning $YADEM_VIM_REPO to $HOME/.vim"
    git clone --recursive "$YADEM_VIM_REPO" "$HOME/.vim"
}

dry_run() {
    DRY_RUN=true
    install "$@"
}

print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] vim

Clone YADEM_VIM_REPO into ~/.vim.

Options:
  -f, --force  Back up or replace an existing ~/.vim before cloning.
HELP
}
