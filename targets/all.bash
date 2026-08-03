# @description Prints help for the all target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] all

Run the configured target sequence from YADEM_ALL_TARGETS.

This target calls yadem once for each configured target, in order. It skips an
accidental recursive "all" entry so the sequence cannot call itself forever.

Configuration:
  YADEM_ALL_TARGETS  Bash array of target names to run

Dry-run:
  yadem --test all

Dry-run passes --test to each target in the sequence. The sequence itself is not
special beyond orchestration; each target still owns its own behavior, help, and
validation.
HELP
}

# @description Runs each configured target in order.
# @noargs
# @exitcode 0 All configured targets completed.
# @exitcode 1 A configured target failed.
install() {
    local target
    local args=()

    yadem_load_config

    if [[ "$DRY_RUN" == true ]]; then
        args+=(--test)
    fi

    for target in "${YADEM_ALL_TARGETS[@]}"; do
        if [[ "$target" == all ]]; then
            yadem_say_and_log skipped "Skipping recursive all target"
            continue
        fi

        yadem_say_and_log running-target "Running target: $target"
        "$INSTALL_BIN_DIR/yadem" "${args[@]}" "$target"
    done
}

# @description Previews the configured target sequence.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
