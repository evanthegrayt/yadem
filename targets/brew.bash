# @description Prints help for the brew target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] brew

Install Homebrew packages from Homebrew's global Brewfile.

This target uses Homebrew's global Brewfile lookup:
  \$HOMEBREW_BUNDLE_FILE_GLOBAL, if set
  \${XDG_CONFIG_HOME}/homebrew/Brewfile, if XDG_CONFIG_HOME is set
  ~/.homebrew/Brewfile
  ~/.Brewfile

It requires Homebrew to be installed first. If brew is missing, run:
  yadem homebrew

Install behavior:
  brew bundle install --global

Dry-run:
  yadem --test brew

Dry-run reports the global Brewfile install without installing packages.
HELP
}

# @description Installs Homebrew packages from Homebrew's global Brewfile.
# @noargs
# @exitcode 0 Brewfile packages are installed or dry-run reported them.
# @exitcode 1 Homebrew is missing or bundle install failed.
install() {
    local brew_path

    if [[ "$DRY_RUN" == true ]]; then
        yadem_say_and_log would-install "Would install Homebrew packages from the global Brewfile"
        return
    fi

    if ! brew_path="$(yadem_brew_executable)"; then
        yadem_say_and_log missing-homebrew "Homebrew is required to install packages from the global Brewfile"
        yadem_say "Install Homebrew first with: bin/yadem homebrew"
        return 1
    fi

    yadem_say_and_log installing "Installing Homebrew packages from the global Brewfile"
    "$brew_path" bundle install --global
    yadem_log_event installed "Homebrew packages installed from the global Brewfile"
}

# @description Previews Brewfile package installation.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
