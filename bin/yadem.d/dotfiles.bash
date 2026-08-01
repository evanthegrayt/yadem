accepted_arguments() {
    printf "%s\n" "[FILE]"
}

link_dotfile() {
    local file="$1"
    local filename="$2"
    local target
    local backup
    local local_target

    target="$HOME/.$filename"

    if [[ -L "$target" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-replace-link "Would replace symlink: $target -> $file"
        else
            rm -- "$target"
            ln -s "$file" "$target"
            say_and_log replaced-link "Replaced symlink: $target -> $file"
        fi
        return
    fi

    if [[ -e "$target" ]]; then
        if [[ -d "$target" ]]; then
            say_and_log skipped-directory "Skipped existing directory: $target"
            return
        fi

        if [[ -f "$target" ]]; then
            backup="$(backup_path_for "$target")"
            local_target="$HOME/.$filename.local"

            if [[ "$DRY_RUN" == true ]]; then
                say_and_log would-back-up "Would back up $target to $backup"
                if [[ "$YADEM_LOCALIZE_EXISTING" == true ]] &&
                    array_contains "$filename" "${YADEM_LOCAL_FILES[@]}" &&
                    [[ ! -e "$local_target" && ! -L "$local_target" ]]; then
                    say_and_log would-link-local "Would link $local_target -> $backup"
                fi
                say_and_log would-link "Would link $target -> $file"
            else
                mkdir -p "$INSTALL_CACHE_DIR"
                mv -- "$target" "$backup"
                if [[ "$YADEM_LOCALIZE_EXISTING" == true ]] &&
                    array_contains "$filename" "${YADEM_LOCAL_FILES[@]}" &&
                    [[ ! -e "$local_target" && ! -L "$local_target" ]]; then
                    ln -s "$backup" "$local_target"
                    say_and_log linked-local "Linked $local_target -> $backup"
                fi
                ln -s "$file" "$target"
                say_and_log backed-up "Backed up $target to $backup"
                say_and_log linked "Linked $target -> $file"
            fi

            return
        fi

        say_and_log skipped-existing "Skipped existing path: $target"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-link "Would link $target -> $file"
    else
        ln -s "$file" "$target"
        say_and_log linked "Linked $target -> $file"
    fi
}

install_dotfile() {
    local filename="$1"
    local file="$YADEM_DOTFILES_DIR/$filename"

    if [[ ! -e "$file" && ! -L "$file" ]]; then
        say_and_log missing-dotfile-source "Dotfile source not found: $file"
        return 1
    fi

    if array_contains "$filename" "${YADEM_DOTFILES_IGNORE[@]}"; then
        say_and_log skipped-ignored "Skipped ignored dotfile: $filename"
        return
    fi

    link_dotfile "$file" "$filename"
}

install_all_dotfiles() {
    local file
    local filename

    for file in "$YADEM_DOTFILES_DIR"/*; do
        [[ -e "$file" || -L "$file" ]] || continue

        filename="${file##*/}"

        if array_contains "$filename" "${YADEM_DOTFILES_IGNORE[@]}"; then
            say_and_log skipped-ignored "Skipped ignored dotfile: $filename"
            continue
        fi

        link_dotfile "$file" "$filename"
    done
}

install() {
    local single_file=""
    local filename
    local source_status

    load_yadem_config

    while (($#)); do
        case "$1" in
            -h|--help)
                print_help
                return
                ;;
            -*)
                say_and_log invalid-option "Invalid option for dotfiles: $1"
                return 1
                ;;
            *)
                if [[ -n "$single_file" ]]; then
                    say_and_log too-many-files "Only one dotfile can be installed at a time"
                    return 1
                fi
                single_file="$1"
                ;;
        esac
        shift
    done

    if ensure_dotfiles_source; then
        :
    else
        source_status=$?
        if [[ "$source_status" -eq 2 ]]; then
            say "Dry run complete. $(log_status_message)"
            return
        fi

        return "$source_status"
    fi

    if [[ -n "$single_file" ]]; then
        if ! filename="$(dotfile_name_for "$single_file")"; then
            say_and_log invalid-dotfile "Invalid dotfile name: $single_file"
            return 1
        fi
        install_dotfile "$filename" || return
    else
        install_all_dotfiles
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

print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] dotfiles [FILE]

Symlink files from YADEM_DOTFILES_DIR into \$HOME.

With no FILE, every non-ignored file is linked. FILE may be passed as name or
.name, for example zshrc or .zshrc.

If YADEM_DOTFILES_DIR is missing, clone YADEM_DOTFILES_REPO into
YADEM_DOTFILES_REPO_DIR first.

Existing symlinks are replaced. Existing regular files are moved to:
  $INSTALL_CACHE_DIR/<name>.<YYYY-MM-DD>

Set YADEM_LOCALIZE_EXISTING=true to link supported backups back as
~/.<name>.local.

Existing directories are skipped.
HELP
}
