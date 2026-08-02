#!/usr/bin/env bash

INSTALL_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_BIN_DIR="$(cd -- "$INSTALL_LIB_DIR/.." && pwd -P)"
INSTALL_PATH="$(cd -- "$INSTALL_BIN_DIR/.." && pwd -P)"
INSTALL_TARGET_DIR="$INSTALL_BIN_DIR/yadem.d"
INSTALL_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yadem"
INSTALL_LOG="${YADEM_LOG:-$INSTALL_CACHE_DIR/install.log}"
DRY_RUN="${DRY_RUN:-false}"
INSTALL_TARGET="${INSTALL_TARGET:-yadem}"
INSTALL_LOG_WRITTEN=false
INSTALL_LOG_FAILED=false

list_targets() {
    local target
    local target_name

    for target in "$INSTALL_TARGET_DIR"/*.bash; do
        [[ -f "$target" ]] || continue
        target_name="${target##*/}"
        printf "%s\n" "${target_name%.bash}"
    done
}

load_yadem_config() {
    local default_config="$INSTALL_PATH/config/yademrc"
    local user_config="${YADEM_CONFIG:-$HOME/.yademrc}"

    if [[ -f "$default_config" ]]; then
        # shellcheck source=config/yademrc
        . "$default_config"
    fi

    if [[ -f "$user_config" && "$user_config" != "$default_config" ]]; then
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

    if ! declare -p YADEM_ALL_TARGETS >/dev/null 2>&1; then
        YADEM_ALL_TARGETS=(homebrew brew repos gems vim zsh bash italics dotfiles)
    fi

    if ! declare -p YADEM_GEMS >/dev/null 2>&1; then
        YADEM_GEMS=(standard spoonerize standup_md)
    fi

    if ! declare -p YADEM_REPOS >/dev/null 2>&1; then
        YADEM_REPOS=()
    fi

    if ! declare -p YADEM_LOCAL_FILES >/dev/null 2>&1; then
        YADEM_LOCAL_FILES=(inputrc bashrc shellrc zshrc profile aliases irbrc pryrc cshrc bash_profile)
    fi

    if ! declare -p YADEM_DOTFILES_IGNORE >/dev/null 2>&1; then
        YADEM_DOTFILES_IGNORE=(README.md LICENSE xterm-256color.terminfo)
    fi
}

array_contains() {
    local needle="$1"
    local item
    shift

    for item; do
        [[ "$item" == "$needle" ]] && return
    done

    return 1
}

dotfile_name_for() {
    local name="$1"

    name="${name#.}"
    if [[ -z "$name" || "$name" == */* ]]; then
        return 1
    fi

    printf "%s\n" "$name"
}

require_command() {
    local command_name="$1"

    if command -v "$command_name" >/dev/null 2>&1; then
        return
    fi

    say_and_log missing-command "$command_name is required"
    return 1
}

git_clone_url_for() {
    local repo="$1"

    if [[ "$repo" != *.git ]]; then
        repo="$repo.git"
    fi

    printf "%s\n" "$repo"
}

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
        mkdir -p "$(dirname -- "$YADEM_DOTFILES_REPO_DIR")"
        say_and_log cloning "Cloning $clone_url to $YADEM_DOTFILES_REPO_DIR"
        git clone "$clone_url" "$YADEM_DOTFILES_REPO_DIR"
    fi

    if [[ ! -d "$YADEM_DOTFILES_DIR" ]]; then
        say_and_log missing-dotfiles-dir "Dotfiles directory not found after clone: $YADEM_DOTFILES_DIR"
        return 1
    fi
}

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

log_event() {
    local action="$1"
    shift

    if mkdir -p "$(dirname -- "$INSTALL_LOG")" 2>/dev/null &&
        printf "%s %s %s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$INSTALL_TARGET" "$action" "$*" 2>/dev/null >> "$INSTALL_LOG"; then
        INSTALL_LOG_WRITTEN=true
        return
    fi

    if [[ "$INSTALL_LOG_FAILED" != true ]]; then
        printf "Warning: could not write install log: %s\n" "$INSTALL_LOG" >&2
    fi

    INSTALL_LOG_FAILED=true
}

say() {
    printf "%s\n" "$*"
}

say_and_log() {
    local action="$1"
    shift

    say "$*"
    log_event "$action" "$*"
}

log_status_message() {
    if [[ "$INSTALL_LOG_WRITTEN" == true ]]; then
        printf "Log written to %s\n" "$INSTALL_LOG"
    elif [[ "$INSTALL_LOG_FAILED" == true ]]; then
        printf "Log could not be written to %s\n" "$INSTALL_LOG"
    else
        printf "No log entries written.\n"
    fi
}

backup_path_for() {
    local target="$1"
    local name="${target##*/}"
    local backup
    local counter

    name="${name#.}"
    backup="$INSTALL_CACHE_DIR/$name.$(date +%F)"

    if [[ ! -e "$backup" && ! -L "$backup" ]]; then
        printf "%s\n" "$backup"
        return
    fi

    counter=1
    while [[ -e "$backup.$counter" || -L "$backup.$counter" ]]; do
        counter=$((counter + 1))
    done

    printf "%s\n" "$backup.$counter"
}
