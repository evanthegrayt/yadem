# @description Prints help for the homebrew target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] homebrew

Install Homebrew if brew is not already available.

This target first checks common brew locations and PATH. If Homebrew is already
installed, it reports the existing brew path and exits successfully.

Install behavior:
  /usr/bin/env bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Non-dry-run installs require curl and run Homebrew's official install script.

Dry-run:
  yadem --test homebrew

Dry-run prints the install command without running curl or modifying the system.
HELP
}

# @description Installs Homebrew when no brew executable is available.
# @noargs
# @exitcode 0 Homebrew exists, was installed, or dry-run reported installation.
# @exitcode 1 curl is missing or the Homebrew installer failed.
install() {
    local brew_path
    local install_command

    install_command="/usr/bin/env bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    if brew_path="$(yadem_brew_executable)"; then
        yadem_say_and_log present "Homebrew is already installed: $brew_path"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        yadem_say_and_log would-install "Would install Homebrew with:"
        yadem_say "$install_command"
        yadem_log_event would-run "$install_command"
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        yadem_say_and_log missing-curl "curl is required to install Homebrew"
        return 1
    fi

    yadem_say_and_log installing "Installing Homebrew"
    /usr/bin/env bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    yadem_log_event installed "Homebrew install command completed"
}

# @description Previews Homebrew installation.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
