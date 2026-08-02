# @description Prints help for the dotfiles target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] dotfiles [OPTIONS] [FILE]

Symlink files from YADEM_DOTFILES_DIR into \$HOME.

With no FILE, every non-ignored file in YADEM_DOTFILES_DIR is linked into
\$HOME with a leading dot added. For example, zshrc becomes ~/.zshrc.

Pass one FILE to install a single dotfile. FILE may be written with or without
the leading dot:
  yadem dotfiles zshrc
  yadem dotfiles .zshrc

Options:
  --include-ignored  Link files listed in YADEM_DOTFILES_IGNORE

Configuration:
  YADEM_DOTFILES_REPO      Repository cloned when dotfiles are missing
  YADEM_DOTFILES_REPO_DIR  Local clone destination
  YADEM_DOTFILES_DIR       Directory containing source dotfiles
  YADEM_DOTFILES_IGNORE    Source names skipped unless --include-ignored is set
  YADEM_DOTFILES_LOCALIZE_EXISTING
                            Link supported backups back as ~/.<name>.local
  YADEM_DOTFILES_LOCAL_FILES
                            Dotfile names eligible for .local preservation

If YADEM_DOTFILES_DIR is missing, this target clones YADEM_DOTFILES_REPO into
YADEM_DOTFILES_REPO_DIR before linking files.

Existing paths:
  Existing symlinks are replaced.
  Existing regular files are moved to $INSTALL_CACHE_DIR/<name>.<YYYY-MM-DD>.
  Existing directories are skipped.

Dry-run:
  yadem --test dotfiles
  yadem --test dotfiles zshrc
  yadem --test dotfiles --include-ignored README.md

Dry-run reports clone, backup, link, and skip decisions without modifying
files.
HELP
}

# @description Declares that the dotfiles target accepts options and an optional file.
# @noargs
# @stdout Argument usage fragment.
# @exitcode 0 Always.
accepted_arguments() {
    printf "%s\n" "[OPTIONS] [FILE]"
}

# @description Checks whether a dotfile source name is ignored.
# @arg $1 string Dotfile source filename.
# @arg $2 string `true` to include ignored files.
# @exitcode 0 The dotfile is ignored.
# @exitcode 1 The dotfile should be included.
dotfile_is_ignored() {
    local filename="$1"
    local include_ignored="$2"

    # Let `&&` preserve the predicate status: false include_ignored falls through
    # to array_contains, while true include_ignored returns 1 ("not ignored").
    [[ "$include_ignored" != true ]] &&
        array_contains "$filename" "${YADEM_DOTFILES_IGNORE[@]}"
}

# @description Links one dotfile source into `$HOME`.
# @arg $1 string Source file path.
# @arg $2 string Dotfile filename without the leading home-directory dot.
# @exitcode 0 The dotfile was linked, skipped, replaced, or would be handled.
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
            # Existing regular files are user data, so move them aside before
            # creating the managed symlink.
            backup="$(backup_path_for "$target")"
            local_target="$HOME/.$filename.local"

            if [[ "$DRY_RUN" == true ]]; then
                say_and_log would-back-up "Would back up $target to $backup"
                if [[ "$YADEM_DOTFILES_LOCALIZE_EXISTING" == true ]] &&
                    array_contains "$filename" "${YADEM_DOTFILES_LOCAL_FILES[@]}" &&
                    [[ ! -e "$local_target" && ! -L "$local_target" ]]; then
                    say_and_log would-link-local "Would link $local_target -> $backup"
                fi
                say_and_log would-link "Would link $target -> $file"
            else
                yadem_ensure_dir "$INSTALL_CACHE_DIR" || return
                mv -- "$target" "$backup"
                if [[ "$YADEM_DOTFILES_LOCALIZE_EXISTING" == true ]] &&
                    array_contains "$filename" "${YADEM_DOTFILES_LOCAL_FILES[@]}" &&
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

# @description Installs a single dotfile source by name.
# @arg $1 string Dotfile filename without the leading home-directory dot.
# @arg $2 string `true` to include ignored dotfiles.
# @exitcode 0 The dotfile was installed, skipped, or would be handled.
# @exitcode 1 The source file is missing.
install_dotfile() {
    local filename="$1"
    local include_ignored="$2"
    local file="$YADEM_DOTFILES_DIR/$filename"

    if [[ ! -e "$file" && ! -L "$file" ]]; then
        say_and_log missing-dotfile-source "Dotfile source not found: $file"
        return 1
    fi

    if dotfile_is_ignored "$filename" "$include_ignored"; then
        say_and_log skipped-ignored "Skipped ignored dotfile: $filename"
        return
    fi

    link_dotfile "$file" "$filename"
}

# @description Installs all non-ignored dotfiles from `YADEM_DOTFILES_DIR`.
# @arg $1 string `true` to include ignored dotfiles.
# @exitcode 0 Dotfiles were installed, skipped, or would be handled.
install_all_dotfiles() {
    local include_ignored="$1"
    local file
    local filename

    for file in "$YADEM_DOTFILES_DIR"/*; do
        # If the directory is empty, the glob is literal; also include symlinks
        # whose targets may not exist.
        [[ -e "$file" || -L "$file" ]] || continue

        filename="${file##*/}"

        if dotfile_is_ignored "$filename" "$include_ignored"; then
            say_and_log skipped-ignored "Skipped ignored dotfile: $filename"
            continue
        fi

        link_dotfile "$file" "$filename"
    done
}

# @description Installs configured dotfiles into `$HOME`.
# @arg $@ string Optional `--include-ignored` and optional dotfile name.
# @exitcode 0 Dotfiles were installed, skipped, or dry-run completed.
# @exitcode 1 Arguments are invalid, source is missing, or clone failed.
install() {
    local single_file=""
    local include_ignored=false
    local filename
    local source_status

    load_yadem_config

    while (($#)); do
        case "$1" in
            -h|--help)
                print_help
                return
                ;;
            --include-ignored)
                include_ignored=true
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
        # ensure_dotfiles_source returns 2 only for dry-run "would clone".
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
        install_dotfile "$filename" "$include_ignored" || return
    else
        install_all_dotfiles "$include_ignored"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say "Dry run complete. $(log_status_message)"
    else
        say "Done. $(log_status_message)"
    fi
}

# @description Previews dotfile installation.
# @arg $@ string Optional `--include-ignored` and optional dotfile name.
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install "$@"
}
