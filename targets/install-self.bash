# @description Prints help for the install-self target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] install-self

Install yadem into PATH by symlinking this repository's bin/yadem.

Default destination:
  \${HOME}/.local/bin/yadem

Configuration:
  YADEM_PATH_DIR  Directory where the yadem symlink should be created

Install behavior:
  Create YADEM_PATH_DIR when needed
  Link "\$YADEM_PATH_DIR/yadem" to "$INSTALL_BIN_DIR/yadem"
  Report whether YADEM_PATH_DIR is already in PATH

Dry-run:
  yadem --test install-self

Dry-run reports the directory, symlink, and PATH status without changing files.
HELP
}

# @description Prints the directory where yadem should be linked.
# @noargs
# @stdout Destination directory.
# @exitcode 0 Always.
install_self_path_dir() {
    printf "%s\n" "${YADEM_PATH_DIR:-$HOME/.local/bin}"
}

# @description Checks whether PATH contains a directory exactly.
# @arg $1 string Directory to find.
# @exitcode 0 The directory is in PATH.
# @exitcode 1 The directory is not in PATH.
install_self_path_contains_dir() {
    local directory="$1"
    local entry
    local old_ifs="$IFS"
    local -a path_entries=()

    IFS=:
    read -r -a path_entries <<< "${PATH:-}"
    IFS="$old_ifs"

    for entry in "${path_entries[@]}"; do
        [[ "$entry" == "$directory" ]] && return
    done

    return 1
}

# @description Reports whether PATH contains the configured destination directory.
# @arg $1 string Destination directory.
# @stdout PATH status message.
# @exitcode 0 Always.
install_self_report_path_status() {
    local directory="$1"

    if install_self_path_contains_dir "$directory"; then
        yadem_say "PATH contains $directory"
    else
        yadem_say "PATH does not contain $directory"
    fi
}

# @description Resolves an existing path by following symlinks.
# @arg $1 string Path to resolve.
# @stdout Physical path.
# @exitcode 0 Path was resolved.
# @exitcode 1 Path could not be resolved.
install_self_resolve_path() {
    local source="$1"
    local source_dir
    local linked_source

    while [[ -L "$source" ]]; do
        source_dir="$(cd -- "$(dirname -- "$source")" >/dev/null 2>&1 && pwd -P)" || return 1
        linked_source="$(readlink "$source")" || return 1

        if [[ "$linked_source" == /* ]]; then
            source="$linked_source"
        else
            source="$source_dir/$linked_source"
        fi
    done

    source_dir="$(cd -- "$(dirname -- "$source")" >/dev/null 2>&1 && pwd -P)" || return 1
    printf "%s/%s\n" "$source_dir" "$(basename -- "$source")"
}

# @description Installs yadem into PATH by creating or updating a symlink.
# @noargs
# @exitcode 0 Symlink exists, was created, was updated, or dry-run reported work.
# @exitcode 1 Destination cannot be changed safely.
install() {
    local source="$INSTALL_BIN_DIR/yadem"
    local path_dir
    local destination
    local resolved_destination

    yadem_load_config

    path_dir="$(install_self_path_dir)"
    destination="$path_dir/yadem"

    if [[ ! -f "$source" ]]; then
        yadem_say_and_log missing-source "yadem executable not found: $source"
        return 1
    fi

    if [[ "$destination" == "$source" ]]; then
        yadem_say_and_log present "yadem already available at $destination"
        install_self_report_path_status "$path_dir"
        return
    fi

    if [[ -L "$destination" ]]; then
        resolved_destination="$(install_self_resolve_path "$destination")" || resolved_destination=""
        if [[ "$resolved_destination" == "$source" ]]; then
            yadem_say_and_log present "yadem symlink already present: $destination -> $source"
            install_self_report_path_status "$path_dir"
            return
        fi
    elif [[ -e "$destination" ]]; then
        yadem_say_and_log blocked-existing "Refusing to replace existing non-yadem path: $destination"
        install_self_report_path_status "$path_dir"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        if [[ ! -d "$path_dir" ]]; then
            yadem_say_and_log would-create-dir "Would create directory: $path_dir"
        fi
        yadem_say_and_log would-link "Would link $destination -> $source"
        install_self_report_path_status "$path_dir"
        return
    fi

    yadem_ensure_dir "$path_dir" || return

    if [[ -L "$destination" ]]; then
        rm -- "$destination"
        ln -s "$source" "$destination"
        yadem_say_and_log updated-link "Updated yadem symlink: $destination -> $source"
    else
        ln -s "$source" "$destination"
        yadem_say_and_log linked "Linked yadem: $destination -> $source"
    fi

    install_self_report_path_status "$path_dir"
}

# @description Previews installing yadem into PATH.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
