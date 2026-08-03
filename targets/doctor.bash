# @description Prints help for the doctor target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] doctor

Print diagnostics for config resolution, target discovery, selected environment
paths, and common command availability.

This target is read-only. It does not install packages, create directories, or
write the install log.

Dry-run:
  yadem --test doctor

Dry-run prints the same diagnostics and notes that no changes will be made.
HELP
}

# @description Prints a path with a compact filesystem status.
# @internal
# @arg $1 string Label.
# @arg $2 string Path.
# @stdout Status line.
# @exitcode 0 Always.
doctor_print_path_status() {
    local label="$1"
    local path="$2"
    local status="missing"

    if [[ -d "$path" ]]; then
        status="directory"
    elif [[ -f "$path" ]]; then
        status="file"
    elif [[ -e "$path" || -L "$path" ]]; then
        status="present"
    fi

    printf "  %s: %s (%s)\n" "$label" "$path" "$status"
}

# @description Prints whether a command is available in PATH.
# @internal
# @arg $1 string Command name.
# @stdout Status line.
# @exitcode 0 Always.
doctor_print_command_status() {
    local command_name="$1"
    local command_path

    if command_path="$(command -v "$command_name" 2>/dev/null)"; then
        printf "  %s: ok (%s)\n" "$command_name" "$command_path"
    else
        printf "  %s: missing\n" "$command_name"
    fi
}

# @description Finds the active path for a previously seen target name.
# @internal
# @arg $1 string Target name.
# @stdout Active target path.
# @exitcode 0 Target was found in the seen arrays.
# @exitcode 1 Target was not found.
doctor_seen_target_path() {
    local target_name="$1"
    local index

    for index in "${!doctor_seen_names[@]}"; do
        if [[ "${doctor_seen_names[$index]}" == "$target_name" ]]; then
            printf "%s\n" "${doctor_seen_paths[$index]}"
            return
        fi
    done

    return 1
}

# @description Prints all duplicate or shadowed target names.
# @internal
# @noargs
# @stdout Duplicate target report.
# @exitcode 0 Always.
doctor_print_shadowed_targets() {
    local target
    local target_dir
    local target_name
    local active_path
    local found_shadowed=false
    local -a doctor_seen_names=()
    local -a doctor_seen_paths=()

    while IFS= read -r target_dir; do
        for target in "$target_dir"/*.bash; do
            [[ -f "$target" ]] || continue
            target_name="${target##*/}"
            target_name="${target_name%.bash}"

            if active_path="$(doctor_seen_target_path "$target_name")"; then
                if [[ "$found_shadowed" == false ]]; then
                    printf "  shadowed targets:\n"
                    found_shadowed=true
                fi

                printf "    %s\n" "$target_name"
                printf "      active: %s\n" "$active_path"
                printf "      shadowed: %s\n" "$target"
            else
                doctor_seen_names+=("$target_name")
                doctor_seen_paths+=("$target")
            fi
        done
    done < <(yadem_target_dirs)

    if [[ "$found_shadowed" == false ]]; then
        printf "  shadowed targets: none\n"
    fi
}

# @description Prints basic path readiness without creating directories.
# @internal
# @arg $1 string Label.
# @arg $2 string Directory path.
# @stdout Status line.
# @exitcode 0 Always.
doctor_print_directory_readiness() {
    local label="$1"
    local directory="$2"
    local parent

    if [[ -d "$directory" ]]; then
        if [[ -w "$directory" ]]; then
            printf "  %s: ok (%s is writable)\n" "$label" "$directory"
        else
            printf "  %s: problem (%s is not writable)\n" "$label" "$directory"
        fi
        return
    fi

    parent="$(dirname -- "$directory")"
    if [[ -d "$parent" && -w "$parent" ]]; then
        printf "  %s: ok (%s can be created)\n" "$label" "$directory"
    else
        printf "  %s: problem (%s cannot be created yet)\n" "$label" "$directory"
    fi
}

# @description Prints yadem diagnostics.
# @noargs
# @exitcode 0 Diagnostics were printed.
install() {
    local active_config
    local command_name
    local default_config
    local target_dir
    local user_config
    local found_active_config=false
    local found_target_dir=false

    yadem_load_config

    default_config="$(yadem_default_config_path)"
    user_config="$(yadem_user_config_path)"

    printf "Yadem doctor\n"
    printf "\nRepository\n"
    printf "  yadem repo path: %s\n" "$INSTALL_PATH"

    printf "\nConfiguration\n"
    doctor_print_path_status "default config" "$default_config"
    if [[ "$user_config" != "$default_config" ]]; then
        doctor_print_path_status "user config" "$user_config"
    fi
    printf "  active config paths:\n"
    while IFS= read -r active_config; do
        printf "    %s\n" "$active_config"
        found_active_config=true
    done < <(yadem_active_config_paths)
    if [[ "$found_active_config" == false ]]; then
        printf "    none\n"
    fi

    printf "\nTargets\n"
    printf "  resolved target dirs:\n"
    while IFS= read -r target_dir; do
        printf "    %s\n" "$target_dir"
        found_target_dir=true
    done < <(yadem_target_dirs)
    if [[ "$found_target_dir" == false ]]; then
        printf "    none\n"
    fi
    doctor_print_shadowed_targets

    printf "\nEnvironment\n"
    printf "  YADEM_DOTFILES_REPO_DIR: %s\n" "$YADEM_DOTFILES_REPO_DIR"
    printf "  YADEM_DOTFILES_DIR: %s\n" "$YADEM_DOTFILES_DIR"
    printf "  INSTALL_CACHE_DIR: %s\n" "$INSTALL_CACHE_DIR"
    printf "  INSTALL_LOG: %s\n" "$INSTALL_LOG"

    printf "\nReadiness checks\n"
    doctor_print_directory_readiness "install cache" "$INSTALL_CACHE_DIR"
    doctor_print_directory_readiness "install log parent" "$(dirname -- "$INSTALL_LOG")"

    printf "\nCommon commands\n"
    for command_name in git bash zsh brew gem tic; do
        doctor_print_command_status "$command_name"
    done
}

# @description Prints read-only yadem diagnostics in dry-run mode.
# @noargs
# @exitcode 0 Diagnostics were printed.
dry_run() {
    printf "Dry-run: doctor is read-only; no changes will be made.\n\n"
    install
}
