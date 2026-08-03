# @description Prints help for the gems target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] gems

Install Ruby gems listed in YADEM_GEMS.

Configuration:
  YADEM_GEMS  Bash array of gem names to install

Install behavior:
  gem install <name>

If YADEM_GEMS is empty, this target exits successfully after saying no gems are
configured. Non-dry-run installs require the gem command.

Dry-run:
  yadem --test gems

Dry-run lists each configured gem without installing anything.
HELP
}

# @description Installs configured Ruby gems.
# @noargs
# @exitcode 0 Gems are installed, skipped, or dry-run reported them.
# @exitcode 1 RubyGems is missing or gem installation failed.
install() {
    local ruby_gem

    if [[ "$DRY_RUN" != true ]] && ! command -v gem >/dev/null 2>&1; then
        yadem_say_and_log missing-rubygems "RubyGems is required to install gems"
        return 1
    fi

    yadem_load_config

    if ((${#YADEM_GEMS[@]} == 0)); then
        yadem_say_and_log skipped "No Ruby gems configured"
        return
    fi

    for ruby_gem in "${YADEM_GEMS[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            yadem_say_and_log would-install "Would install gem: $ruby_gem"
        else
            yadem_say_and_log installing "Installing gem: $ruby_gem"
            gem install "$ruby_gem"
            yadem_log_event installed "Installed gem: $ruby_gem"
        fi
    done
}

# @description Previews configured Ruby gem installation.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
