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

install() {
    local target
    local args=()

    load_yadem_config

    if [[ "$DRY_RUN" == true ]]; then
        args+=(--test)
    fi

    for target in "${YADEM_ALL_TARGETS[@]}"; do
        if [[ "$target" == all ]]; then
            say_and_log skipped "Skipping recursive all target"
            continue
        fi

        say_and_log running-target "Running target: $target"
        "$INSTALL_BIN_DIR/yadem" "${args[@]}" "$target"
    done
}

dry_run() {
    DRY_RUN=true
    install
}
