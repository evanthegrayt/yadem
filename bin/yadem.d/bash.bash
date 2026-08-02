print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] bash

Clone Bash shell framework repositories into your home directory.

Options:
  -f, --force  Back up or replace an existing custom directory before cloning

This target touches:
  $HOME/.bash_it
  $HOME/.bash_it/custom

Configuration:
  YADEM_BASH_REPO         Repository cloned to ~/.bash_it
  YADEM_BASH_CUSTOM_REPO  Optional repository cloned to ~/.bash_it/custom

Existing directories are left alone by default. With --force, an existing custom
directory is moved to:
  $INSTALL_CACHE_DIR/bash-custom.<YYYY-MM-DD>

Dry-run:
  yadem --test bash
  yadem --test bash --force

Dry-run reports backup, replacement, and clone decisions without modifying
files.
HELP
}

accepted_arguments() {
    printf "%s\n" "[OPTIONS]"
}

clone_or_report() {
    local name="$1"
    local repo="$2"
    local directory="$3"

    if [[ -d "$directory/.git" || -d "$directory" ]]; then
        say_and_log present "$name already exists: $directory"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-clone "Would clone $repo to $directory"
        return
    fi

    require_command git || return
    say_and_log cloning "Cloning $repo to $directory"
    git clone --recursive "$repo" "$directory"
}

prepare_custom_destination() {
    local name="$1"
    local directory="$2"
    local backup_name="$3"
    local force="$4"
    local backup

    if [[ ! -e "$directory" && ! -L "$directory" ]]; then
        return
    fi

    if [[ "$force" != true ]]; then
        say_and_log present "$name already exists: $directory"
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
        backup="$(backup_path_for_name "$backup_name")"

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
                say_and_log invalid-option "Invalid option for bash: $1"
                return 1
                ;;
            *)
                say_and_log invalid-argument "Invalid argument for bash: $1"
                return 1
                ;;
        esac
        shift
    done

    clone_or_report bash-it "$YADEM_BASH_REPO" "$HOME/.bash_it"

    if [[ -n "$YADEM_BASH_CUSTOM_REPO" ]]; then
        if prepare_custom_destination bash-it-custom "$HOME/.bash_it/custom" bash-custom "$force"; then
            :
        else
            destination_status=$?
            if [[ "$destination_status" -eq 2 ]]; then
                return
            fi

            return "$destination_status"
        fi

        if [[ "$DRY_RUN" == true && "$force" == true &&
            ( -e "$HOME/.bash_it/custom" || -L "$HOME/.bash_it/custom" ) ]]; then
            say_and_log would-clone "Would clone $YADEM_BASH_CUSTOM_REPO to $HOME/.bash_it/custom"
        else
            clone_or_report bash-it-custom "$YADEM_BASH_CUSTOM_REPO" "$HOME/.bash_it/custom"
        fi
    fi
}

dry_run() {
    DRY_RUN=true
    install "$@"
}
