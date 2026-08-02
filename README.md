# yadem

[![Language: Bash](https://img.shields.io/static/v1?label=language&message=Bash&color=4EAA25&style=flat&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Completions: zsh | bash](https://img.shields.io/static/v1?label=completions&message=zsh%20%7C%20bash&color=4EAA25&style=flat&logo=shell&logoColor=white)](#bootstrap)
[![Build Status](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fevanthegrayt%2Fyadem%2Fbadge%3Fref%3Dmaster&style=flat)](https://actions-badge.atrox.dev/evanthegrayt/yadem/goto?ref=master)

Yet Another Dotfile and Environment Manager.

`yadem` is a small Bash dispatcher for machine setup targets. The long-term
shape is a generic core plus target files that users can inspect, replace,
fork, or publish independently. The targets bundled here are useful defaults
and examples, but they are not the point of the project: the point is making it
pleasant to write your own setup behavior.

## Status

This repository is still under active development. Some bundled defaults are
still personal and may later move to a separate target repository. Core
dispatcher behavior, self-bootstrapping support, shared helpers, tests, and
documentation belong here.

## Bootstrap

Clone the repository and list available targets:

```sh
git clone https://github.com/evanthegrayt/yadem.git
cd yadem
bin/yadem --list
```

Show the resolved target files, including shadowed overrides:

```sh
bin/yadem --list --verbose
```

Run a target:

```sh
bin/yadem dotfiles
bin/yadem brew
```

Preview a target without changing the system:

```sh
bin/yadem --test dotfiles
```

Run the configured sequence:

```sh
bin/yadem --all
```

Open a target for inspection or editing:

```sh
bin/yadem --edit dotfiles
```

Editor resolution checks `YADEM_EDITOR`, then `VISUAL`, then `EDITOR`, then
falls back to `vi`.

## Writing Targets

Targets are Bash modules with the `.bash` extension. Users run them without the
extension:

```sh
bin/yadem my-target
```

By default, yadem searches for targets in:

- `${XDG_CONFIG_HOME:-$HOME/.config}/yadem/yadem.d`
- the bundled `bin/yadem.d/`

Set the `YADEM_TARGET_DIRS` environment variable to a colon-separated list of
user target directories to search before bundled targets:

```sh
YADEM_TARGET_DIRS="$HOME/workflow/yadem-targets:$HOME/.local/share/yadem.d"
```

Missing paths and non-directories are ignored. When multiple directories define
the same target name, the first match wins, so user targets can override bundled
targets.

Each target must implement:

- `print_help`: print target-specific usage and behavior
- `install`: perform the work
- `dry_run`: report what would happen without changing the system

Targets that accept trailing arguments should also implement:

```bash
accepted_arguments() {
    printf "%s\n" "[OPTIONS] [FILE]"
}
```

If `accepted_arguments` is missing, the dispatcher rejects target arguments
before running the target.

Target files should put `print_help()` first. A user opening a target should see
the contract before the implementation.

## Shared DSL

Shared target helpers live in `bin/lib/yadem.sh`. Target authors should prefer
these helpers when they fit instead of reimplementing common shell behavior.
Current helpers include:

- `load_yadem_config`: load defaults and user overrides
- `say` and `say_and_log`: print consistent target output
- `require_command`: fail clearly when an executable is missing
- `array_contains`: check membership in Bash arrays
- `git_clone_url_for`: normalize repository clone URLs
- `yadem_ensure_dir`: create a directory when missing
- `yadem_copy_file_if_missing`: copy a file without overwriting
- `yadem_clone_repo_if_missing`: clone a Git repository when the destination is missing
- `yadem_prepare_destination`: preserve, replace, or back up an existing path
- `backup_path_for` and `backup_path_for_name`: choose non-clobbering backup paths

The DSL is intentionally small. New helpers should earn their place by removing
real duplication or making target code safer for people who do not know every
Bash edge case.

## Documentation

Shell API comments use the
[`shdoc`](https://github.com/reconquest/shdoc) format. Generated API docs should
be written under `docs/`, which is ignored on `master`.

Example:

```bash
# @description Copies a regular file only when the destination does not exist.
# @arg $1 string Source file path.
# @arg $2 string Destination file path.
# @exitcode 0 The file was copied, would be copied, or was skipped safely.
# @exitcode 1 The source is missing or the copy failed.
yadem_copy_file_if_missing() {
    :
}
```

Use `@stdout` for functions whose primary result is printed for command
substitution:

```bash
# @description Builds the target path for a target name.
# @arg $1 string Target name without `.bash`.
# @stdout Absolute target file path.
target_path_for() {
    :
}
```

Use `@internal` for dispatcher or implementation details that should remain
documented in source but hidden from public API docs.

When `shdoc` is available:

```sh
mkdir -p docs
shdoc bin/lib/yadem.sh > docs/yadem-api.md
```

## Configuration

Defaults and examples live in `config/yademrc`. yadem loads that file first,
then loads `${YADEM_CONFIG:-$HOME/.yademrc}` when it exists, so user config
overrides repo defaults while unset values still come from the repo config. Set
`YADEM_CONFIG=/path/to/config` to use a different override file; the path can
have any filename.

Common settings:

- `YADEM_ALL_TARGETS`: ordered targets for `bin/yadem --all`
- `YADEM_EDITOR`: editor command used by `bin/yadem --edit <target>`
- `YADEM_GIT_ACCOUNTS`: accounts used by `bin/yadem git-accounts`
- `YADEM_GIT_SSH_KEY_PATH`: SSH key path used by `bin/yadem git-accounts`
- `YADEM_GIT_SSH_KEY_TYPE`: `ssh-keygen -t` value for `bin/yadem git-accounts`
- `YADEM_LOG`: optional install log path override
- `YADEM_REPO_DIR`: base directory used by repository-oriented targets

Bundled targets define additional settings in their help output.

Installer output is written to:

```sh
${XDG_CACHE_HOME:-$HOME/.cache}/yadem/install.log
```

Inspect the log with:

```sh
bin/yadem log path
bin/yadem log list
bin/yadem log show
bin/yadem log delete
```

## Bundled Targets

Bundled targets are examples and useful defaults:

- `all`: run the configured `YADEM_ALL_TARGETS` sequence
- `bash`: clone bash-it and optional custom files
- `brew`: install packages from `Brewfile`
- `dotfiles`: symlink dotfiles into `$HOME`
- `dotfiles-uninstall`: remove managed dotfile symlinks from `$HOME`
- `gems`: install configured Ruby gems
- `git-accounts`: generate/reuse keys and help add them to GitHub/GitLab
- `homebrew`: install Homebrew if missing
- `italics`: compile `xterm-256color.terminfo`
- `log`: inspect or remove the current installer log
- `macos`: apply macOS-specific setup
- `repos`: clone configured Git repositories
- `shell`: change the login shell
- `vim`: clone vimfiles into `~/.vim`
- `zsh`: clone oh-my-zsh and optional custom files

Run target help for current behavior:

```sh
bin/yadem dotfiles --help
bin/yadem vim --help
```

## Development

Run the validation suite:

```sh
bats -r test
shellcheck bin/yadem bin/lib/yadem.sh bin/yadem.d/*.bash completions/yadem.bash config/yademrc $(find test \( -name '*.bash' -o -name '*.bats' \))
bash -n bin/yadem bin/lib/yadem.sh bin/yadem.d/*.bash completions/yadem.bash $(find test \( -name '*.bash' -o -name '*.bats' \))
zsh -n completions/yadem.zsh
git diff --check
```
