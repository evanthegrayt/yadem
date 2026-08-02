print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] macos

Apply macOS-specific setup.

This target only runs on Darwin. On other systems, it reports that the target is
skipped and exits successfully.

Configuration:
  YADEM_SCREENSHOT_DIR  Screenshot directory written with defaults

Install behavior on macOS:
  Creates YADEM_SCREENSHOT_DIR when configured.
  Runs defaults write com.apple.screencapture location <dir>.
  Restarts SystemUIServer when possible.
  Opens the Xcode Command Line Tools installer with xcode-select --install.

This target is intentionally not included in the default YADEM_ALL_TARGETS
sequence.

Dry-run:
  yadem --test macos

Dry-run reports the screenshot directory and xcode-select command without
changing system settings.
HELP
}

install() {
    load_yadem_config

    if [[ "$(uname -s)" != Darwin ]]; then
        say_and_log skipped "macos target only runs on Darwin"
        return
    fi

    if [[ -n "$YADEM_SCREENSHOT_DIR" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-configure "Would set screenshot directory to $YADEM_SCREENSHOT_DIR"
        else
            mkdir -p "$YADEM_SCREENSHOT_DIR"
            defaults write com.apple.screencapture location "$YADEM_SCREENSHOT_DIR"
            killall SystemUIServer >/dev/null 2>&1 || true
            say_and_log configured "Set screenshot directory to $YADEM_SCREENSHOT_DIR"
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-run "Would run xcode-select --install"
        return
    fi

    say_and_log installing "Opening Xcode Command Line Tools installer"
    xcode-select --install
}

dry_run() {
    DRY_RUN=true
    install
}
