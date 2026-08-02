print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] zsh

Clone Zsh framework repositories into your home directory.

Options:
  -f, --force  Back up or replace an existing custom directory before cloning

This target touches:
  $HOME/.oh-my-zsh
  $HOME/.oh-my-zsh/custom

Configuration:
  YADEM_ZSH_REPO         Repository cloned to ~/.oh-my-zsh
  YADEM_ZSH_CUSTOM_REPO  Optional repository cloned to ~/.oh-my-zsh/custom

Existing directories are left alone by default. With --force, an existing custom
directory is moved to:
  $INSTALL_CACHE_DIR/zsh-custom.<YYYY-MM-DD>

Dry-run:
  yadem --test zsh
  yadem --test zsh --force

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
                say_and_log invalid-option "Invalid option for zsh: $1"
                return 1
                ;;
            *)
                say_and_log invalid-argument "Invalid argument for zsh: $1"
                return 1
                ;;
        esac
        shift
    done

    clone_or_report oh-my-zsh "$YADEM_ZSH_REPO" "$HOME/.oh-my-zsh"

    if [[ -n "$YADEM_ZSH_CUSTOM_REPO" ]]; then
        if prepare_custom_destination oh-my-zsh-custom "$HOME/.oh-my-zsh/custom" zsh-custom "$force"; then
            :
        else
            destination_status=$?
            if [[ "$destination_status" -eq 2 ]]; then
                return
            fi

            return "$destination_status"
        fi

        if [[ "$DRY_RUN" == true && "$force" == true &&
            ( -e "$HOME/.oh-my-zsh/custom" || -L "$HOME/.oh-my-zsh/custom" ) ]]; then
            say_and_log would-clone "Would clone $YADEM_ZSH_CUSTOM_REPO to $HOME/.oh-my-zsh/custom"
        else
            clone_or_report oh-my-zsh-custom "$YADEM_ZSH_CUSTOM_REPO" "$HOME/.oh-my-zsh/custom"
        fi
    fi
}

dry_run() {
    DRY_RUN=true
    install "$@"
}
