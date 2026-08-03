# @description Prints help for the bash target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
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

# @description Declares that the bash target accepts target-specific options.
# @noargs
# @stdout Argument usage fragment.
# @exitcode 0 Always.
accepted_arguments() {
    printf "%s\n" "[OPTIONS]"
}

# @description Installs Bash framework repositories.
# @arg $@ string Optional `-f` or `--force`.
# @exitcode 0 Bash repositories are present, cloned, or skipped safely.
# @exitcode 1 Options were invalid or a clone failed.
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

    yadem_clone_repo_if_missing bash-it "$YADEM_BASH_REPO" "$HOME/.bash_it" true

    if [[ -n "$YADEM_BASH_CUSTOM_REPO" ]]; then
        if yadem_prepare_destination bash-it-custom "$HOME/.bash_it/custom" bash-custom "$force"; then
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

        # After a dry-run force backup, the directory still exists, so report the
        # clone that would follow instead of letting clone-if-missing say present.
        if [[ "$DRY_RUN" == true && "$force" == true &&
            ( -e "$HOME/.bash_it/custom" || -L "$HOME/.bash_it/custom" ) ]]; then
            say_and_log would-clone "Would clone $YADEM_BASH_CUSTOM_REPO to $HOME/.bash_it/custom"
        else
            yadem_clone_repo_if_missing bash-it-custom "$YADEM_BASH_CUSTOM_REPO" "$HOME/.bash_it/custom" true
        fi
    fi
}

# @description Previews the bash target.
# @arg $@ string Optional `-f` or `--force`.
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install "$@"
}
