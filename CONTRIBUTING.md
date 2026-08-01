# Contributing

Thanks for helping with `yadem`. This project should stay small, readable, and
pleasant to modify. It is personal infrastructure, so boring changes that make
future setup safer are usually better than clever changes that make the
dispatcher know too much.

## Quick Start

From the repository root:

```sh
bin/yadem --list
bin/yadem --help
bats test/yadem.bats
shellcheck bin/yadem bin/lib/yadem.sh bin/yadem.d/*.bash completions/yadem.bash config/yademrc test/*.bash test/*.bats
```

Use dry-run mode while developing target behavior:

```sh
bin/yadem --test dotfiles
bin/yadem --test dotfiles zshrc
```

## Project Shape

`yadem` is a dispatcher plus the minimum default targets needed to bootstrap a
machine. Personal setup logic should be able to move into a separate targets
repository later. Keep `bin/yadem` generic: it should know how to find, load,
and run targets, but it should not contain branches for specific target names or
personal workflows.

The command runs one target per invocation:

```sh
bin/yadem dotfiles zshrc
bin/yadem brew
```

Use `YADEM_ALL_TARGETS` and `bin/yadem --all` for target sequences.

## Target Contract

Each target is a non-executable Bash module named `bin/yadem.d/<name>.bash`.
Users reference it without the extension:

```sh
bin/yadem dotfiles
```

The dispatcher sources the target file and calls one of these required
functions:

- `install`: perform the work
- `dry_run`: report what would happen without changing the system
- `print_help`: describe target-specific usage

Targets that accept trailing arguments should also implement:

```bash
accepted_arguments() {
    printf "%s\n" "[FILE]"
}
```

`accepted_arguments` prints usage metadata for global help and tells the
dispatcher that trailing args are allowed. If it is missing, the dispatcher
rejects arguments before running the target.

Targets own their parsing, validation, and help text. Global options belong in
`bin/yadem`; target-specific options belong in the target.

## Technical Rules

- Target files use the `.bash` extension, have no shebang, and are not
  executable.
- Target names in docs, config, help, completion, and commands do not include
  `.bash`.
- Do not support extensionless target files.
- Do not add target-specific logic to `bin/yadem`.
- Prefer shared helpers in `bin/lib/yadem.sh` only when behavior is genuinely
  common across targets or part of the dispatcher contract.
- Keep dry-run behavior faithful: it should say what would happen and avoid
  modifying the filesystem.
- Use clear failure messages for missing commands, missing source files, invalid
  options, and skipped unsafe operations.

## Tests

Add Bats coverage for user-visible behavior, especially:

- install and dry-run paths
- clear failure messages
- target argument parsing
- backup or restore behavior
- cases that prove unrelated files or targets are not touched

Run before finishing:

```sh
bats test/yadem.bats
shellcheck bin/yadem bin/lib/yadem.sh bin/yadem.d/*.bash completions/yadem.bash config/yademrc test/*.bash test/*.bats
bash -n bin/yadem bin/lib/yadem.sh bin/yadem.d/*.bash completions/yadem.bash test/*.bash test/*.bats
zsh -n completions/yadem.zsh
git diff --check
```

## Notes For Agents

When working in this repo, preserve the separation between dispatcher and
targets. If a target needs new behavior, prefer a small target-owned interface
or a shared helper over hardcoding that target into `bin/yadem`.

Before editing, inspect the existing target and nearby tests. After editing,
run the focused tests if possible, then the full validation commands above.
Avoid unrelated refactors and do not revert user changes in the worktree.
