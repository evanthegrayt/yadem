# Writing yadem Targets

Targets are small Bash modules that teach `yadem` how to perform one setup
task. A target can live in this repository, in a personal target directory, or
in a separate target repository that users add to `YADEM_TARGET_DIRS`.

Users run targets by name, without the `.bash` extension:

```sh
bin/yadem my-target
bin/yadem --test my-target
bin/yadem my-target --help
```

## Target Locations

By default, yadem searches for target files in this order:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/yadem/yadem.d
bin/yadem.d
```

Set `YADEM_TARGET_DIRS` to a colon-separated list to use one or more external
target directories before the bundled targets:

```sh
export YADEM_TARGET_DIRS="$HOME/workflow/yadem-targets:$HOME/.local/share/yadem.d"
```

yadem ignores missing paths and non-directories. The first matching
`<name>.bash` file wins, so a user target named `brew.bash` overrides the
bundled `brew` target. Use `bin/yadem --list --verbose` to see the resolved
target paths and any shadowed built-ins.

Target names cannot contain slashes, cannot start with `.`, and are referenced
without `.bash` in commands, docs, help text, config, and completions.

## Minimal Template

Save this as `<target-dir>/example.bash` and run it with `bin/yadem example`.
Target files are sourced by the dispatcher, so they should not have a shebang
and should not be executable.

```bash
# @description Prints help for the example target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] example

Describe what this target installs or configures.

Configuration:
  YADEM_EXAMPLE_PATH defaults to \$HOME/.example

Dry-run:
  yadem --test example

Dry-run reports what would happen without changing files.
HELP
}

# @description Installs or configures the example target.
# @noargs
# @exitcode 0 The target is installed or dry-run reported the work.
# @exitcode 1 A required command, file, or operation failed.
install() {
    load_yadem_config

    local example_path="${YADEM_EXAMPLE_PATH:-$HOME/.example}"

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-create "Would create $example_path"
        return
    fi

    yadem_ensure_dir "$(dirname -- "$example_path")" || return
    printf "created by yadem\n" > "$example_path"
    say_and_log created "Created $example_path"
}

# @description Previews the example target.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
```

If a target accepts trailing arguments, add `accepted_arguments()`:

```bash
accepted_arguments() {
    printf "%s\n" "[OPTIONS] [NAME]"
}
```

Without `accepted_arguments`, the dispatcher rejects target arguments before it
runs the target. The target owns parsing and validation for any arguments it
accepts.

## Required Functions

Each target must define these functions:

- `install`: performs the real work and returns non-zero on failure.
- `dry_run`: reports what would happen without changing the system.
- `print_help`: prints target-specific help for `yadem <target> --help`.

`print_help` is the required help function. Do not define a function named
`help`; Bash already has a `help` builtin, and yadem intentionally does not use
it as a fallback.

Put `print_help()` first in the file. When a user opens a target with
`bin/yadem --edit <target>`, the first visible function should explain what the
target does before showing implementation details.

## Shared Helpers And Variables

yadem sources `bin/lib/yadem.sh` before it sources the target. The helper file
sets common variables and exposes a small target DSL.

Use `load_yadem_config` near the start of `install()` when a target reads
`YADEM_*` settings. It loads repository defaults from `config/yademrc`, then
loads `${YADEM_CONFIG:-$HOME/.yademrc}` when it exists. User config overrides
repo defaults while unset values still fall back to the default config.

Use target-owned variable names under a target-specific `YADEM_` prefix, for
example `YADEM_NODE_VERSION`, `YADEM_NOTES_DIR`, or
`YADEM_WORK_NOTES_DIR`. Bundled targets follow names such as
`YADEM_DOTFILES_*`, `YADEM_VIM_*`, `YADEM_REPOS_*`, and `YADEM_SHELL_*`.
Document each variable in `print_help()` and give it a safe default in the
target after `load_yadem_config`.

Use `DRY_RUN` to decide whether the target may change the system. The
dispatcher sets it to `true` for `bin/yadem --test <target>`. Most targets keep
`dry_run()` tiny:

```bash
dry_run() {
    DRY_RUN=true
    install "$@"
}
```

Use `INSTALL_CACHE_DIR` for yadem-owned cache files, backups, generated helper
files, and temporary durable artifacts:

```bash
local marker="$INSTALL_CACHE_DIR/my-target-installed"
```

`INSTALL_CACHE_DIR` defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/yadem`.

Use `say` for user-facing status that does not need to be logged:

```bash
say "Nothing to do."
```

Use `say_and_log` for install actions, skipped work, dry-run plans, and failure
messages that should appear in the install log:

```bash
say_and_log would-install "Would install example-tool"
say_and_log installed "Installed example-tool"
say_and_log missing-config "Config file not found: $config_file"
```

The first argument to `say_and_log` is a short action key used in the log. The
remaining words are printed to stdout and written to the install log. Logging is
best-effort and uses `${YADEM_LOG:-$INSTALL_CACHE_DIR/install.log}`.

Use `require_command` before invoking external commands:

```bash
require_command git || return
```

It prints and logs a clear missing-command message, then returns non-zero.

## Conventions

Dry-run behavior should be faithful. It should say what would happen, including
paths, repositories, commands, and skipped work, and it should not modify files,
create directories, install packages, change shell settings, or call APIs with
side effects.

Prefer helpers from `bin/lib/yadem.sh` for common operations such as safe
directory creation, copy-if-missing behavior, clone-if-missing behavior, backup
path selection, and consistent output. Add a new shared helper only when it is
useful across targets.

Treat existing user files as user-owned. If a target might replace, remove, or
back up a path, document that behavior in `print_help()` and report it during
dry-run.

Use clear non-zero failures for missing commands, missing source files, invalid
options, unsafe existing paths, and failed external commands. A simple pattern
is:

```bash
if [[ ! -f "$source_file" ]]; then
    say_and_log missing-source "Source file not found: $source_file"
    return 1
fi
```

Let normal Bash failure propagation handle straightforward command failures
when the message is already clear. yadem runs targets with `set -eo pipefail`,
so unhandled failures stop the target.

## Simple Example Target

This target creates a local notes directory and a README file. It demonstrates
config loading, dry-run behavior, logging, cache usage, and safe failure
handling without depending on a particular package manager.

Save it as `notes.bash` in a user target directory:

```bash
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] notes

Create a personal notes directory with a starter README.

Configuration:
  YADEM_NOTES_DIR defaults to \$HOME/notes

Dry-run:
  yadem --test notes

Dry-run reports the directory and README that would be created.
HELP
}

install() {
    load_yadem_config

    local notes_dir="${YADEM_NOTES_DIR:-$HOME/notes}"
    local readme="$notes_dir/README.md"
    local marker="$INSTALL_CACHE_DIR/notes-target.last-run"

    if [[ -e "$readme" ]]; then
        say_and_log present "Notes README already exists: $readme"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        say_and_log would-create "Would create $notes_dir"
        say_and_log would-create "Would create $readme"
        say "Would record run marker at $marker"
        return
    fi

    yadem_ensure_dir "$notes_dir" || return
    yadem_ensure_dir "$INSTALL_CACHE_DIR" || return

    printf "# Notes\n" > "$readme"
    printf "%s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" > "$marker"

    say_and_log created "Created $readme"
    say_and_log cached "Recorded run marker at $marker"
}

dry_run() {
    DRY_RUN=true
    install
}
```

Install and test it:

```sh
mkdir -p "$HOME/.config/yadem/yadem.d"
cp notes.bash "$HOME/.config/yadem/yadem.d/notes.bash"

bin/yadem --list --verbose
bin/yadem notes --help
bin/yadem --test notes
bin/yadem notes
```

Override the default directory in `${YADEM_CONFIG:-$HOME/.yademrc}`:

```bash
YADEM_NOTES_DIR="$HOME/workflow/notes"
```

## Testing Targets

Use Bats for target behavior. Focus on the user-visible contract:

- help output
- install behavior
- dry-run behavior
- missing commands and invalid config
- argument parsing
- existing-file and skipped-work cases
- proof that unrelated files are not touched

In this repository, dispatcher behavior is covered in `test/dispatcher.bats`
and bundled targets have tests under `test/targets/<target>.bats`.

For an external target repository, keep the same shape if it helps:

```text
targets/
  notes.bash
test/
  notes.bats
  test_helper.bash
```

A minimal test should run the target through `bin/yadem`, not by sourcing the
target directly. That exercises discovery, argument handling, `DRY_RUN`, config
loading, helper availability, and output the same way users experience them.
