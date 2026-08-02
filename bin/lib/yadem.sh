#!/usr/bin/env bash

# @file yadem
# @brief Shared helpers for yadem targets and dispatcher code.
# @description
#   This file is the public shell DSL for target authors. Prefer adding small,
#   well-documented helpers here when target behavior becomes common across
#   multiple target files.

# Resolve paths from this file instead of the caller's working directory.
# BASH_SOURCE[0] still points here when this library is sourced.
INSTALL_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_BIN_DIR="$(cd -- "$INSTALL_LIB_DIR/.." && pwd -P)"
INSTALL_PATH="$(cd -- "$INSTALL_BIN_DIR/.." && pwd -P)"
INSTALL_TARGET_DIR="$INSTALL_BIN_DIR/yadem.d"
INSTALL_USER_TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/yadem/yadem.d"
INSTALL_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yadem"
INSTALL_LOG="${YADEM_LOG:-$INSTALL_CACHE_DIR/install.log}"
DRY_RUN="${DRY_RUN:-false}"
INSTALL_TARGET="${INSTALL_TARGET:-yadem}"
INSTALL_LOG_WRITTEN=false
INSTALL_LOG_FAILED=false

# @description Lists configured target directories in search order.
# @noargs
# @stdout One existing target directory per line.
# @exitcode 0 Always.
yadem_target_dirs() {
    local configured_dirs="${YADEM_TARGET_DIRS:-$INSTALL_USER_TARGET_DIR}"
    local target_dir
    local -a target_dirs
    local -a seen_dirs=()
    local IFS=:

    read -r -a target_dirs <<< "$configured_dirs"
    target_dirs+=("$INSTALL_TARGET_DIR")

    for target_dir in "${target_dirs[@]}"; do
        [[ -n "$target_dir" && -d "$target_dir" ]] || continue
        if array_contains "$target_dir" "${seen_dirs[@]}"; then
            continue
        fi

        printf "%s\n" "$target_dir"
        seen_dirs+=("$target_dir")
    done
}

# @description Builds the preferred target path for a target name.
# @arg $1 string Target name without `.bash`.
# @stdout Absolute target file path.
# @exitcode 0 The target exists in the configured search path.
# @exitcode 1 The target is missing or has an invalid path-like name.
target_path_for() {
    local target="$1"
    local target_dir
    local target_path

    # Reject path-like names before resolving so targets cannot escape target dirs.
    [[ "$target" != */* && "$target" != .* ]] || return 1

    while IFS= read -r target_dir; do
        target_path="$target_dir/$target.bash"
        if [[ -f "$target_path" ]]; then
            printf "%s\n" "$target_path"
            return
        fi
    done < <(yadem_target_dirs)

    return 1
}

# @description Checks whether a target name resolves to a target file.
# @arg $1 string Target name without `.bash`.
# @exitcode 0 The target exists and is safe to load.
# @exitcode 1 The target is missing or has an invalid path-like name.
target_exists() {
    target_path_for "$1" >/dev/null
}

# @description Lists available target names without the `.bash` extension.
# @noargs
# @stdout One target name per line.
# @exitcode 0 Always.
list_targets() {
    local target
    local target_dir
    local target_name
    local -a seen_targets=()

    while IFS= read -r target_dir; do
        for target in "$target_dir"/*.bash; do
            # Without nullglob, an unmatched glob is left literal; this guard skips it.
            [[ -f "$target" ]] || continue
            # ${var##*/} strips the longest directory prefix, leaving the basename.
            target_name="${target##*/}"
            # ${var%.bash} strips one trailing extension without touching the rest.
            target_name="${target_name%.bash}"
            if array_contains "$target_name" "${seen_targets[@]}"; then
                continue
            fi

            printf "%s\n" "$target_name"
            seen_targets+=("$target_name")
        done
    done < <(yadem_target_dirs)
}

# @description Lists target names with the file path that would be loaded.
# @noargs
# @stdout One tab-separated target, path, and optional shadowed marker per line.
# @exitcode 0 Always.
list_targets_verbose() {
    local target
    local target_dir
    local target_name
    local status
    local -a seen_targets=()

    while IFS= read -r target_dir; do
        for target in "$target_dir"/*.bash; do
            [[ -f "$target" ]] || continue
            target_name="${target##*/}"
            target_name="${target_name%.bash}"
            status=""

            if array_contains "$target_name" "${seen_targets[@]}"; then
                status=$'\tshadowed'
            else
                seen_targets+=("$target_name")
            fi

            printf "%s\t%s%s\n" "$target_name" "$target" "$status"
        done
    done < <(yadem_target_dirs)
}

# @description Loads repository defaults and user configuration into YADEM_* variables.
# @noargs
# @set YADEM_REPO_DIR string Directory used by repository-oriented targets.
# @set YADEM_ALL_TARGETS array Ordered targets used by the `all` target.
# @set YADEM_GEMS array Ruby gems used by the `gems` target.
# @set YADEM_REPOS array Git repositories used by the `repos` target.
# @exitcode 0 Configuration was loaded.
load_yadem_config() {
    local default_config="$INSTALL_PATH/config/yademrc"
    local user_config="${YADEM_CONFIG:-$HOME/.yademrc}"
    local default_git_key_label

    if [[ -f "$default_config" ]]; then
        # Source configs so array assignments and exported variables affect this shell.
        # shellcheck source=config/yademrc
        . "$default_config"
    fi

    if [[ -f "$user_config" && "$user_config" != "$default_config" ]]; then
        # The user config path is runtime-configurable, so shellcheck cannot resolve it.
        # shellcheck disable=SC1090
        . "$user_config"
    fi

    YADEM_REPO_DIR="${YADEM_REPO_DIR:-$HOME/workflow}"
    YADEM_DOTFILES_REPO="${YADEM_DOTFILES_REPO:-https://github.com/evanthegrayt/dotfiles}"
    YADEM_DOTFILES_REPO_DIR="${YADEM_DOTFILES_REPO_DIR:-$YADEM_REPO_DIR/dotfiles}"
    YADEM_DOTFILES_DIR="${YADEM_DOTFILES_DIR:-$YADEM_DOTFILES_REPO_DIR/dotfiles}"
    YADEM_VIM_REPO="${YADEM_VIM_REPO:-https://github.com/evanthegrayt/vimfiles.git}"
    YADEM_ZSH_REPO="${YADEM_ZSH_REPO:-https://github.com/ohmyzsh/ohmyzsh.git}"
    YADEM_ZSH_CUSTOM_REPO="${YADEM_ZSH_CUSTOM_REPO:-https://github.com/evanthegrayt/oh-my-zsh-custom.git}"
    YADEM_BASH_REPO="${YADEM_BASH_REPO:-https://github.com/Bash-it/bash-it.git}"
    YADEM_BASH_CUSTOM_REPO="${YADEM_BASH_CUSTOM_REPO:-https://github.com/evanthegrayt/bash-it-custom.git}"
    YADEM_SCREENSHOT_DIR="${YADEM_SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
    YADEM_LOGIN_SHELL="${YADEM_LOGIN_SHELL:-}"
    YADEM_EDITOR="${YADEM_EDITOR:-}"
    YADEM_REPO_AUTO_RUN_BUILD="${YADEM_REPO_AUTO_RUN_BUILD:-false}"
    YADEM_LOCALIZE_EXISTING="${YADEM_LOCALIZE_EXISTING:-false}"
    default_git_key_label="${HOSTNAME:-$(hostname 2>/dev/null || printf "unknown-host")}"
    YADEM_GIT_SSH_ENABLED="${YADEM_GIT_SSH_ENABLED:-true}"
    YADEM_GIT_SSH_KEY_PATH="${YADEM_GIT_SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
    YADEM_GIT_SSH_KEY_TYPE="${YADEM_GIT_SSH_KEY_TYPE:-ed25519}"
    YADEM_GIT_SSH_COMMENT="${YADEM_GIT_SSH_COMMENT:-${USER:-yadem}@$default_git_key_label}"
    YADEM_GIT_KEY_TITLE="${YADEM_GIT_KEY_TITLE:-$default_git_key_label}"
    YADEM_GIT_AUTO_UPLOAD="${YADEM_GIT_AUTO_UPLOAD:-true}"
    YADEM_GITLAB_WEB_URL="${YADEM_GITLAB_WEB_URL:-https://gitlab.com}"
    YADEM_GPG_ENABLED="${YADEM_GPG_ENABLED:-false}"
    YADEM_GPG_KEY_ID="${YADEM_GPG_KEY_ID:-}"
    YADEM_GPG_PUBLIC_KEY_PATH="${YADEM_GPG_PUBLIC_KEY_PATH:-$INSTALL_CACHE_DIR/git-accounts-gpg-public-key.asc}"

    # declare -p distinguishes "unset" from "set but empty", which matters for
    # arrays a user may intentionally configure as empty.
    if ! declare -p YADEM_ALL_TARGETS >/dev/null 2>&1; then
        YADEM_ALL_TARGETS=(homebrew brew repos gems vim zsh bash italics dotfiles)
    fi

    if ! declare -p YADEM_GEMS >/dev/null 2>&1; then
        YADEM_GEMS=(standard spoonerize standup_md)
    fi

    if ! declare -p YADEM_REPOS >/dev/null 2>&1; then
        YADEM_REPOS=()
    fi

    if ! declare -p YADEM_GIT_ACCOUNTS >/dev/null 2>&1; then
        YADEM_GIT_ACCOUNTS=(github gitlab)
    fi

    if ! declare -p YADEM_GIT_SSH_KEYGEN_OPTIONS >/dev/null 2>&1; then
        YADEM_GIT_SSH_KEYGEN_OPTIONS=()
    fi

    if ! declare -p YADEM_LOCAL_FILES >/dev/null 2>&1; then
        YADEM_LOCAL_FILES=(inputrc bashrc shellrc zshrc profile aliases irbrc pryrc cshrc bash_profile)
    fi

    if ! declare -p YADEM_DOTFILES_IGNORE >/dev/null 2>&1; then
        YADEM_DOTFILES_IGNORE=(README.md LICENSE xterm-256color.terminfo)
    fi
}

# @description Checks whether a value appears in a shell array.
# @arg $1 string Value to find.
# @arg $@ string Array values to search.
# @exitcode 0 The value was found.
# @exitcode 1 The value was not found.
array_contains() {
    local needle="$1"
    local item
    shift

    # `for item; do` iterates over the remaining positional parameters.
    for item; do
        [[ "$item" == "$needle" ]] && return
    done

    return 1
}

# @description Normalizes a dotfile argument into a bare filename.
# @arg $1 string Dotfile name with or without a leading dot.
# @stdout Bare dotfile name, without a leading dot.
# @exitcode 0 The name is non-empty and does not contain a slash.
# @exitcode 1 The name is empty or contains a slash.
dotfile_name_for() {
    local name="$1"

    # Remove at most one leading dot so users may pass either "zshrc" or ".zshrc".
    name="${name#.}"
    if [[ -z "$name" || "$name" == */* ]]; then
        return 1
    fi

    printf "%s\n" "$name"
}

# @description Requires an executable command to be available in PATH.
# @arg $1 string Command name.
# @exitcode 0 The command exists.
# @exitcode 1 The command is missing.
require_command() {
    local command_name="$1"

    if command -v "$command_name" >/dev/null 2>&1; then
        return
    fi

    say_and_log missing-command "$command_name is required"
    return 1
}

# @description Ensures a Git clone URL ends in `.git`.
# @arg $1 string Repository URL.
# @stdout Repository URL ending in `.git`.
# @exitcode 0 Always.
git_clone_url_for() {
    local repo="$1"

    if [[ "$repo" != *.git ]]; then
        repo="$repo.git"
    fi

    printf "%s\n" "$repo"
}

# @description Ensures a directory exists.
# @arg $1 string Directory path.
# @exitcode 0 The directory exists or was created.
# @exitcode 1 The directory could not be created.
yadem_ensure_dir() {
    local directory="$1"

    mkdir -p "$directory"
}

# @description Copies a regular file only when the destination does not exist.
# @arg $1 string Source file path.
# @arg $2 string Destination file path.
# @exitcode 0 The file was copied, would be copied, or was skipped safely.
# @exitcode 1 The source is missing or the copy failed.
yadem_copy_file_if_missing() {
    local source="$1"
    local destination="$2"

    if [[ ! -f "$source" ]]; then
        say_and_log missing-source "Source file not found: $source"
        return 1
    fi

    # `-L` is checked with `-e` so a broken destination symlink is still preserved.
    if [[ -e "$destination" || -L "$destination" ]]; then
        say_and_log skipped-existing "Skipped existing path: $destination"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-copy "Would copy $source to $destination"
        return
    fi

    yadem_ensure_dir "$(dirname -- "$destination")" || return
    cp -p "$source" "$destination"
    say_and_log copied "Copied $source to $destination"
}

# @description Clones a Git repository only when the destination is missing.
# @arg $1 string Human-readable repository label for log messages.
# @arg $2 string Repository URL.
# @arg $3 string Destination directory.
# @arg $4 string Optional `true` to clone recursively.
# @exitcode 0 The destination exists, would be cloned, or was cloned.
# @exitcode 1 Git is missing or clone failed.
yadem_clone_repo_if_missing() {
    local name="$1"
    local repo="$2"
    local directory="$3"
    local recursive="${4:-false}"
    local clone_args=(clone)

    # Treat any existing path, including a broken symlink, as user-owned.
    if [[ -e "$directory" || -L "$directory" ]]; then
        say_and_log present "$name already exists: $directory"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-clone "Would clone $repo to $directory"
        return
    fi

    require_command git || return
    if [[ "$recursive" == true ]]; then
        clone_args+=(--recursive)
    fi

    say_and_log cloning "Cloning $repo to $directory"
    git "${clone_args[@]}" "$repo" "$directory"
}

# @description Prepares an existing destination for a forced install.
# @arg $1 string Human-readable destination label for log messages.
# @arg $2 string Destination path.
# @arg $3 string Backup basename. Pass an empty string to derive it from the destination.
# @arg $4 string `true` to remove or back up existing paths; otherwise preserve them.
# @arg $5 string Optional message used when an existing path is preserved.
# @exitcode 0 Destination is absent, would be prepared, or was prepared.
# @exitcode 1 Directory creation or backup failed.
# @exitcode 2 Existing destination was preserved or skipped.
yadem_prepare_destination() {
    local name="$1"
    local directory="$2"
    local backup_name="$3"
    local force="$4"
    local present_message="${5:-$name already exists: $directory}"
    local backup

    # `-L` catches broken symlinks that `-e` intentionally reports as absent.
    if [[ ! -e "$directory" && ! -L "$directory" ]]; then
        return
    fi

    if [[ "$force" != true ]]; then
        # Return 2 is a non-error sentinel: callers usually stop without failing.
        say_and_log present "$present_message"
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
        # A supplied backup name lets targets group paths such as
        # ~/.oh-my-zsh/custom under a cleaner logical backup prefix.
        if [[ -n "$backup_name" ]]; then
            backup="$(backup_path_for_name "$backup_name")"
        else
            backup="$(backup_path_for "$directory")"
        fi

        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-back-up "Would back up $directory to $backup"
        else
            yadem_ensure_dir "$INSTALL_CACHE_DIR" || return
            mv -- "$directory" "$backup"
            say_and_log backed-up "Backed up $directory to $backup"
        fi
        return
    fi

    # Uncommon filesystem types are neither removed nor backed up automatically.
    say_and_log skipped-existing "Skipped existing path: $directory"
    return 2
}

# @description Ensures the configured dotfiles source directory exists.
# @noargs
# @exitcode 0 The dotfiles source directory exists.
# @exitcode 1 Configuration is invalid or cloning failed.
# @exitcode 2 Dry-run reported a missing source clone.
ensure_dotfiles_source() {
    local clone_url

    if [[ -d "$YADEM_DOTFILES_DIR" ]]; then
        return
    fi

    if [[ -z "$YADEM_DOTFILES_REPO" ]]; then
        say_and_log missing-dotfiles-repo "YADEM_DOTFILES_REPO is not configured"
        return 1
    fi

    clone_url="$(git_clone_url_for "$YADEM_DOTFILES_REPO")"

    if [[ "$DRY_RUN" == true ]]; then
        # Dry-run cannot clone, so distinguish "would clone" from hard failures
        # with the non-error sentinel status 2.
        if [[ -e "$YADEM_DOTFILES_REPO_DIR" && ! -d "$YADEM_DOTFILES_REPO_DIR/.git" ]]; then
            say_and_log invalid-dotfiles-repo-dir "Dotfiles repository path exists but is not a git repository: $YADEM_DOTFILES_REPO_DIR"
            return 1
        fi

        if [[ -d "$YADEM_DOTFILES_REPO_DIR/.git" ]]; then
            say_and_log missing-dotfiles-dir "Dotfiles directory not found in repository: $YADEM_DOTFILES_DIR"
            return 1
        fi

        say_and_log would-clone "Would clone $clone_url to $YADEM_DOTFILES_REPO_DIR"
        return 2
    fi

    require_command git || return

    if [[ -e "$YADEM_DOTFILES_REPO_DIR" && ! -d "$YADEM_DOTFILES_REPO_DIR/.git" ]]; then
        say_and_log invalid-dotfiles-repo-dir "Dotfiles repository path exists but is not a git repository: $YADEM_DOTFILES_REPO_DIR"
        return 1
    fi

    if [[ ! -d "$YADEM_DOTFILES_REPO_DIR/.git" ]]; then
        yadem_ensure_dir "$(dirname -- "$YADEM_DOTFILES_REPO_DIR")" || return
        say_and_log cloning "Cloning $clone_url to $YADEM_DOTFILES_REPO_DIR"
        git clone "$clone_url" "$YADEM_DOTFILES_REPO_DIR"
    fi

    if [[ ! -d "$YADEM_DOTFILES_DIR" ]]; then
        say_and_log missing-dotfiles-dir "Dotfiles directory not found after clone: $YADEM_DOTFILES_DIR"
        return 1
    fi
}

# @description Resolves the Homebrew executable from PATH or common install paths.
# @noargs
# @stdout Absolute brew executable path.
# @exitcode 0 A brew executable was found.
# @exitcode 1 Homebrew was not found.
brew_executable() {
    local brew_path

    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return
    fi

    for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [[ -x "$brew_path" ]]; then
            printf "%s\n" "$brew_path"
            return
        fi
    done

    return 1
}

# @description Writes a structured install log entry.
# @arg $1 string Log action key.
# @arg $@ string Message words to append after the action key.
# @set INSTALL_LOG_WRITTEN boolean True after any successful log write.
# @set INSTALL_LOG_FAILED boolean True after the first failed log write.
# @exitcode 0 The function never fails callers because logging is best-effort.
log_event() {
    local action="$1"
    shift

    if yadem_ensure_dir "$(dirname -- "$INSTALL_LOG")" 2>/dev/null &&
        printf "%s %s %s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$INSTALL_TARGET" "$action" "$*" 2>/dev/null >> "$INSTALL_LOG"; then
        INSTALL_LOG_WRITTEN=true
        return
    fi

    if [[ "$INSTALL_LOG_FAILED" != true ]]; then
        printf "Warning: could not write install log: %s\n" "$INSTALL_LOG" >&2
    fi

    INSTALL_LOG_FAILED=true
}

# @description Prints a message to stdout.
# @arg $@ string Message words.
# @stdout The joined message followed by a newline.
# @exitcode 0 The message was printed.
say() {
    printf "%s\n" "$*"
}

# @description Prints a message and records it in the install log.
# @arg $1 string Log action key.
# @arg $@ string Message words to print and log.
# @exitcode 0 The message was printed; logging remains best-effort.
say_and_log() {
    local action="$1"
    shift

    say "$*"
    log_event "$action" "$*"
}

# @description Summarizes whether this process wrote an install log.
# @noargs
# @stdout A short sentence suitable for final target output.
# @exitcode 0 Always.
log_status_message() {
    if [[ "$INSTALL_LOG_WRITTEN" == true ]]; then
        printf "Log written to %s\n" "$INSTALL_LOG"
    elif [[ "$INSTALL_LOG_FAILED" == true ]]; then
        printf "Log could not be written to %s\n" "$INSTALL_LOG"
    else
        printf "No log entries written.\n"
    fi
}

# @description Builds the next backup path for an existing filesystem path.
# @arg $1 string Path whose basename should be used for the backup.
# @stdout Unique backup path under `INSTALL_CACHE_DIR`.
# @exitcode 0 Always.
backup_path_for() {
    local target="$1"
    # Strip directory and one leading dot so ~/.zshrc backs up as zshrc.DATE.
    local name="${target##*/}"

    name="${name#.}"
    backup_path_for_name "$name"
}

# @description Builds the next backup path for a logical backup name.
# @arg $1 string Backup basename.
# @stdout Unique backup path under `INSTALL_CACHE_DIR`.
# @exitcode 0 Always.
backup_path_for_name() {
    local name="$1"
    local backup
    local counter

    backup="$INSTALL_CACHE_DIR/$name.$(date +%F)"

    if [[ ! -e "$backup" && ! -L "$backup" ]]; then
        printf "%s\n" "$backup"
        return
    fi

    counter=1
    # Keep incrementing while either a real path or a broken symlink exists.
    while [[ -e "$backup.$counter" || -L "$backup.$counter" ]]; do
        counter=$((counter + 1))
    done

    printf "%s\n" "$backup.$counter"
}
