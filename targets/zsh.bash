# @description Prints help for the zsh target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
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

# @description Declares that the zsh target accepts target-specific options.
# @noargs
# @stdout Argument usage fragment.
# @exitcode 0 Always.
accepted_arguments() {
    printf "%s\n" "[OPTIONS]"
}

# @description Installs Zsh framework repositories.
# @arg $@ string Optional `-f` or `--force`.
# @exitcode 0 Zsh repositories are present, cloned, or skipped safely.
# @exitcode 1 Options were invalid or a clone failed.
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
                yadem_say_and_log invalid-option "Invalid option for zsh: $1"
                return 1
                ;;
            *)
                yadem_say_and_log invalid-argument "Invalid argument for zsh: $1"
                return 1
                ;;
        esac
        shift
    done

    yadem_clone_repo_if_missing oh-my-zsh "$YADEM_ZSH_REPO" "$HOME/.oh-my-zsh" true

    if [[ -n "$YADEM_ZSH_CUSTOM_REPO" ]]; then
        if yadem_prepare_destination oh-my-zsh-custom "$HOME/.oh-my-zsh/custom" zsh-custom "$force"; then
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
        # clone that would follow instead of letting clone-if-missing report present.
        if [[ "$DRY_RUN" == true && "$force" == true &&
            ( -e "$HOME/.oh-my-zsh/custom" || -L "$HOME/.oh-my-zsh/custom" ) ]]; then
            yadem_say_and_log would-clone "Would clone $YADEM_ZSH_CUSTOM_REPO to $HOME/.oh-my-zsh/custom"
        else
            yadem_clone_repo_if_missing oh-my-zsh-custom "$YADEM_ZSH_CUSTOM_REPO" "$HOME/.oh-my-zsh/custom" true
        fi
    fi
}

# @description Previews the zsh target.
# @arg $@ string Optional `-f` or `--force`.
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install "$@"
}
