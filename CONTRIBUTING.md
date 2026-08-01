# Contributing

Thanks for helping keep `yadem` small, boring, and easy to move around.

## Project Direction

`yadem` is a target dispatcher plus the minimum default targets needed to
bootstrap a new machine. Personal setup logic should be able to live outside
this repository in a separate targets repo, so avoid adding coupling from
`bin/yadem` back to specific target names or personal workflows.

When a target needs behavior beyond the default contract, make that behavior
part of the target interface. For example, targets that accept trailing
arguments should implement:

```bash
target_accepts_args() {
    return 0
}
```

If `target_accepts_args` is missing, the dispatcher assumes the target does not
accept trailing arguments.

## Target Expectations

Each `*.bash` target file in `bin/yadem.d/` is referenced without the extension,
sourced by the dispatcher, and should implement:

- `install`: perform the work
- `dry_run`: report what would happen without changing the system
- `print_help`: describe target-specific usage

Targets should own their parsing, validation, and help text. Global options
belong in `bin/yadem`; target-specific options belong in the target.

Use shared helpers from `bin/lib/yadem.sh` when behavior is genuinely common.
Do not add target-specific branches to shared code unless the dispatcher or
multiple targets need the same interface.

## Tests

Add Bats coverage for user-visible behavior, especially:

- install and dry-run paths
- clear failure messages
- backup or restore behavior
- cases that prove unrelated files or targets are not touched

Run before submitting:

```sh
bats test/yadem.bats
git diff --check
```
