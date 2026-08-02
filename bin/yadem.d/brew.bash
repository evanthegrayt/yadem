print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] brew

Install Homebrew packages from this repository's Brewfile.

This target reads:
  $INSTALL_PATH/Brewfile

It requires Homebrew to be installed first. If brew is missing, run:
  yadem homebrew

Install behavior:
  brew bundle install --file "$INSTALL_PATH/Brewfile"

Dry-run:
  yadem --test brew

Dry-run reports the Brewfile path without installing packages.
HELP
}

install() {
    local brewfile="$INSTALL_PATH/Brewfile"
    local brew_path

    if [[ ! -f "$brewfile" ]]; then
        say_and_log missing-brewfile "Brewfile not found: $brewfile"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-install "Would install Homebrew packages from $brewfile"
        return
    fi

    if ! brew_path="$(brew_executable)"; then
        say_and_log missing-homebrew "Homebrew is required to install packages from $brewfile"
        say "Install Homebrew first with: bin/yadem homebrew"
        return 1
    fi

    say_and_log installing "Installing Homebrew packages from $brewfile"
    "$brew_path" bundle install --file "$brewfile"
    log_event installed "Homebrew packages installed from $brewfile"
}

dry_run() {
    DRY_RUN=true
    install
}
