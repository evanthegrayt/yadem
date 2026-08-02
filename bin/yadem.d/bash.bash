print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] bash

Clone Bash shell framework repositories into your home directory.

This target touches:
  $HOME/.bash_it
  $HOME/.bash_it/custom

Configuration:
  YADEM_BASH_REPO         Repository cloned to ~/.bash_it
  YADEM_BASH_CUSTOM_REPO  Optional repository cloned to ~/.bash_it/custom

Existing directories are left alone. This target does not update or replace an
existing clone.

Dry-run:
  yadem --test bash

Dry-run reports which repositories would be cloned without creating
directories.
HELP
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

install() {
    load_yadem_config

    clone_or_report bash-it "$YADEM_BASH_REPO" "$HOME/.bash_it"

    if [[ -n "$YADEM_BASH_CUSTOM_REPO" ]]; then
        clone_or_report bash-it-custom "$YADEM_BASH_CUSTOM_REPO" "$HOME/.bash_it/custom"
    fi
}

dry_run() {
    DRY_RUN=true
    install
}
