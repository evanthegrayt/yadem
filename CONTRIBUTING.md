# Contributing

Thanks for helping with `yadem`. This project should stay small, readable, and
pleasant to modify. It is personal infrastructure, so boring changes that make
future setup safer are usually better than clever changes that make the
dispatcher know too much.

## Audience And Direction

`yadem` is for technical users who want to inspect, adapt, and eventually write
their own setup targets. It starts as a dotfiles installer for one person's
configuration, but the long-term shape is a generic dispatcher plus target
repositories that people can fork, replace, or publish independently.

Treat target files as user-facing source, not hidden internals. A user should be
able to understand a target with `yadem <target> --help`, preview it with
`yadem --test <target>`, and open the implementation with an editor command such
as `yadem --edit <target>` when that workflow exists. Those affordances are part
of the product, not just contributor conveniences.

## Quick Start

From the repository root:

```sh
bin/yadem --list
bin/yadem --help
bin/yadem dotfiles --help
bin/yadem --edit dotfiles
bats -r test
shellcheck bin/yadem lib/yadem.sh targets/*.bash completions/yadem.bash config/yademrc $(find test \( -name '*.bash' -o -name '*.bats' \))
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

## Shared DSL

Shared behavior belongs in `lib/yadem.sh` when it is useful to target
authors beyond one target. Keep the helper small, document it with `shdoc`
annotations, and add tests when the helper has branching behavior.

Use a DSL-minded version of the boy scout rule: each time you add or change a
target, look for one bit of Bash complexity that could become a clear helper
for future target authors. Do the extraction only when it keeps the current
change focused; otherwise leave a note near the target or in the issue so the
next pass has a clean starting point.

Good DSL candidates include safe directory creation, no-overwrite file copies,
clone-if-missing behavior, backup path selection, dry-run-aware filesystem
changes, and consistent status/log output. Avoid helpers that know about a
single personal repository, package list, or machine preference.

## Target Contract

Each target is a non-executable Bash module named `targets/<name>.bash`.
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

## Configuration Names

Keep configuration names predictable by reserving broad `YADEM_*` names for
core dispatcher behavior and shared settings. New target-level settings should
use a target-specific prefix, such as `YADEM_DOTFILES_*`, `YADEM_VIM_*`,
`YADEM_REPOS_*`, or `YADEM_SHELL_*`.

When migrating an existing config name to a target-specific prefix during early
development, update the default config, docs, target help, examples, and tests
to the new name.

## Help Text Standard

Target help is part of the user interface. A technical user should be able to
run `yadem <target> --help` and understand what the target will do without
opening the source first.

Prefer explanatory target help over dense comments. Comments should explain
implementation choices that are not obvious from the code; `print_help()` should
explain the target's behavior, inputs, effects, and safety boundaries.

Target help should usually include:

- a plain-language summary of what the target does
- accepted arguments and target-specific options
- files, directories, repositories, packages, or system settings it touches
- configuration variables that affect behavior
- what happens to existing files, symlinks, backups, skipped paths, and missing
  dependencies
- what `yadem --test <target>` will report
- examples for non-obvious modes

Put `print_help()` first in each target file. When a user opens a target with
`yadem --edit <target>`, the first visible function should describe the target
before the implementation details begin.

## Shell API Docs

Use [`shdoc`](https://github.com/reconquest/shdoc)-style comments for shell
functions. Public helpers should be documented for generated API docs; internal
dispatcher or implementation details should also be documented in source and
marked with `@internal` when they should not appear in public API output.

Use `@stdout` for functions that return values by printing strings for command
substitution. Use `@exitcode` for meaningful status contracts. It is fine to
omit `@exitcode` when a tiny target wrapper has no useful contract beyond
normal shell failure behavior.

Generated docs belong under `docs/`, which is ignored on `master`.

Also document uncommon Bash syntax at the point of use. Prefer a short comment
when code relies on parameter expansion such as `${name##*/}`, process
substitution, glob behavior, intentional subshells, sentinel return codes,
array length checks, or zsh completion modifiers. These comments are for future
contributors who know what the target should do but may not know the shell
corner that makes it work.

## Technical Rules

- Target files use the `.bash` extension, have no shebang, and are not
  executable.
- Maintain compatibility with macOS system Bash 3.2. Avoid Bash 4+ features
  such as `mapfile`, `declare -A`, and newer parameter expansions unless the
  project explicitly raises its Bash requirement.
- Target names in docs, config, help, completion, and commands do not include
  `.bash`.
- When adding or changing global options, target discovery, or user-facing
  command arguments, update Bash and Zsh completions and add completion tests
  when behavior changes.
- Do not support extensionless target files.
- Do not add target-specific logic to `bin/yadem`.
- Keep `print_help()` as the first function in target files.
- Prefer shared helpers in `lib/yadem.sh` only when behavior is genuinely
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

Dispatcher tests live in `test/dispatcher.bats`. Target-specific tests live in
`test/targets/<target>.bats`.

Run before finishing:

```sh
bats -r test
shellcheck bin/yadem lib/yadem.sh targets/*.bash completions/yadem.bash config/yademrc $(find test \( -name '*.bash' -o -name '*.bats' \))
bash -n bin/yadem lib/yadem.sh targets/*.bash completions/yadem.bash $(find test \( -name '*.bash' -o -name '*.bats' \))
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
