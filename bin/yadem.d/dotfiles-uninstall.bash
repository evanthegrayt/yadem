print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] dotfiles-uninstall [OPTIONS] [FILE]

Remove managed dotfile symlinks from \$HOME.

Managed symlinks are links in \$HOME that point into YADEM_DOTFILES_DIR. This
target does not remove regular files, directories, or symlinks pointing
somewhere else.

With no FILE, all managed dotfile symlinks are removed. Pass one FILE to remove
a single dotfile link. FILE may be written with or without the leading dot, for
example zshrc or .zshrc:
  yadem dotfiles-uninstall zshrc
  yadem dotfiles-uninstall .zshrc

Options:
  -R, --restore  Restore newest matching backup from INSTALL_CACHE_DIR

Configuration:
  YADEM_DOTFILES_DIR  Directory that managed symlinks must point into
  INSTALL_CACHE_DIR   Backup directory searched by --restore

Restore behavior:
  --restore looks for $INSTALL_CACHE_DIR/<name>.* and moves the newest matching
  backup back to \$HOME after removing the managed symlink.

Dry-run:
  yadem --test dotfiles-uninstall
  yadem --test dotfiles-uninstall --restore zshrc

Dry-run reports remove and restore decisions without modifying files.
HELP
}

accepted_arguments() {
    printf "%s\n" "[OPTIONS] [FILE]"
}

readlink_target_for() {
    local target="$1"

    readlink "$target"
}

symlink_points_into_dotfiles_dir() {
    local target="$1"
    local link_target

    [[ -L "$target" ]] || return 1

    link_target="$(readlink_target_for "$target")"
    [[ "$link_target" == "$YADEM_DOTFILES_DIR"/* ]]
}

newest_backup_for() {
    local name="$1"
    local backup
    local newest=""

    for backup in "$INSTALL_CACHE_DIR/$name."*; do
        [[ -e "$backup" || -L "$backup" ]] || continue
        if [[ -z "$newest" || "$backup" > "$newest" ]]; then
            newest="$backup"
        fi
    done

    [[ -n "$newest" ]] || return 1
    printf "%s\n" "$newest"
}

restore_backup_for() {
    local name="$1"
    local target="$2"
    local backup

    if backup="$(newest_backup_for "$name")"; then
        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-restore "Would restore $target from $backup"
        else
            mv -- "$backup" "$target"
            say_and_log restored "Restored $target from $backup"
        fi
    else
        say_and_log no-backup "No backup found for $name in $INSTALL_CACHE_DIR"
    fi
}

uninstall_dotfile() {
    local name="$1"
    local restore="$2"
    local target="$HOME/.$name"
    local link_target

    if ! [[ -L "$target" ]]; then
        say_and_log skipped-no-symlink "$target is not a symlink. Skipping."
        return
    fi

    link_target="$(readlink_target_for "$target")"
    if ! symlink_points_into_dotfiles_dir "$target"; then
        say_and_log skipped-unmanaged "Skipped unmanaged symlink: $target -> $link_target"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-remove-link "Would remove symlink: $target -> $link_target"
    else
        rm -- "$target"
        say_and_log removed-link "Removed symlink: $target -> $link_target"
    fi

    if [[ "$restore" == true ]]; then
        restore_backup_for "$name" "$target"
    fi
}

uninstall_all_dotfiles() {
    local restore="$1"
    local target
    local name
    local found=false

    for target in "$HOME"/.[!.]* "$HOME"/..?*; do
        [[ -L "$target" ]] || continue
        symlink_points_into_dotfiles_dir "$target" || continue

        found=true
        name="${target##*/}"
        name="${name#.}"
        uninstall_dotfile "$name" "$restore"
    done

    if [[ "$found" != true ]]; then
        say_and_log no-managed-symlinks "No dotfile symlinks into $YADEM_DOTFILES_DIR found in $HOME"
    fi
}

install() {
    local restore=false
    local single_file=""
    local name

    load_yadem_config

    while (($#)); do
        case "$1" in
            -R|--restore)
                restore=true
                ;;
            -h|--help)
                print_help
                return
                ;;
            -*)
                say_and_log invalid-option "Invalid option for dotfiles-uninstall: $1"
                return 1
                ;;
            *)
                if [[ -n "$single_file" ]]; then
                    say_and_log too-many-files "Only one dotfile can be uninstalled at a time"
                    return 1
                fi
                single_file="$1"
                ;;
        esac
        shift
    done

    if [[ -n "$single_file" ]]; then
        if ! name="$(dotfile_name_for "$single_file")"; then
            say_and_log invalid-dotfile "Invalid dotfile name: $single_file"
            return 1
        fi
        uninstall_dotfile "$name" "$restore"
    else
        uninstall_all_dotfiles "$restore"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say "Dry run complete. $(log_status_message)"
    else
        say "Done. $(log_status_message)"
    fi
}

dry_run() {
    DRY_RUN=true
    install "$@"
}
