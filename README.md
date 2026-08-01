# yadem
[![Language: Bash](https://img.shields.io/static/v1?label=language&message=Bash&color=4EAA25&style=flat&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Completions: zsh | bash](https://img.shields.io/static/v1?label=completions&message=zsh%20%7C%20bash&color=4EAA25&style=flat&logo=shell&logoColor=white)](#usage)
[![Build Status](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fevanthegrayt%2Fcdc%2Fbadge%3Fref%3Dmaster&style=flat)](https://actions-badge.atrox.dev/evanthegrayt/cdc/goto?ref=master)

Yet Another Dotfile and Environment Manager.

`yadem` is a small target dispatcher for setting up a personal development
environment. The command stays thin; each setup concern lives in its own target
script under `bin/yadem.d/`.

The project is split into two repositories:

- `yadem`: installer framework, targets, config, tests, docs
- `dotfiles`: personal dotfiles consumed by the `dotfiles` target

## Bootstrap

There is no way around the first few machine-level prerequisites: you need a
shell, `git`, and usually `curl` before `yadem` can clone itself or install
Homebrew. Those first steps belong in the README because they have to happen
before this command exists locally.

```sh
git clone https://github.com/evanthegrayt/yadem.git
cd yadem
bin/yadem --list
```

Once cloned, run individual targets:

```sh
bin/yadem dotfiles
bin/yadem dotfiles-uninstall
bin/yadem homebrew
bin/yadem brew
```

Preview work without changing the system:

```sh
bin/yadem --test dotfiles
bin/yadem --test brew gems
```

Run the configured setup sequence:

```sh
bin/yadem --all
```

Show target-specific help:

```sh
bin/yadem dotfiles --help
```

## Target Contract

Each executable file in `bin/yadem.d/` is a target. A target must implement:

- `install`: perform the work
- `dry_run`: print what would happen without doing it
- `print_help`: print target-specific usage

The dispatcher sets these variables for every target:

- `INSTALL_PATH`: repository root
- `INSTALL_BIN_DIR`: `bin/`
- `INSTALL_TARGET_DIR`: `bin/yadem.d/`
- `INSTALL_CACHE_DIR`: cache and backup directory
- `INSTALL_LOG`: log file path
- `INSTALL_TARGET`: current target name
- `DRY_RUN`: `true` or `false`

Shared helpers live in `bin/lib/yadem.sh`.

## Targets

Current targets:

- `all`: run the configured `YADEM_ALL_TARGETS` sequence
- `bash`: clone bash-it and optional custom files
- `brew`: install packages from `Brewfile`
- `dotfiles`: symlink dotfiles into `$HOME`
- `dotfiles-uninstall`: remove managed dotfile symlinks from `$HOME`
- `gems`: install configured Ruby gems
- `homebrew`: install Homebrew if missing
- `italics`: compile `xterm-256color.terminfo`
- `macos`: apply macOS-specific setup
- `repos`: clone configured git repositories
- `shell`: change the login shell
- `vim`: clone vimfiles into `~/.vim`
- `zsh`: clone oh-my-zsh and optional custom files

`macos` and `shell` are intentionally not in the default `--all` sequence.

## Configuration

Defaults live in `config/yademrc`. Copy it to `~/.yademrc` or set
`YADEM_CONFIG=/path/to/yademrc` for local overrides.

Notable settings:

- `YADEM_ALL_TARGETS`: ordered targets for `bin/yadem --all`
- `YADEM_DOTFILES_DIR`: source directory for the `dotfiles` target
- `YADEM_DOTFILES_REPO`: git repository cloned when dotfiles are missing
- `YADEM_DOTFILES_REPO_DIR`: local clone destination for `YADEM_DOTFILES_REPO`
- `YADEM_DOTFILES_IGNORE`: dotfile source names to skip
- `YADEM_LOCALIZE_EXISTING`: link supported backups back as `~/.name.local`
- `YADEM_LOCAL_FILES`: dotfiles eligible for `.local` preservation
- `YADEM_REPO_DIR`: clone destination for `repos`
- `YADEM_REPOS`: git repositories to clone
- `YADEM_REPO_AUTO_RUN_BUILD`: opt into running `rake`/`make` after clone
- `YADEM_GEMS`: Ruby gems to install
- `YADEM_LOGIN_SHELL`: shell name for the `shell` target

Installer output is written to:

```sh
${XDG_CACHE_HOME:-$HOME/.cache}/yadem/install.log
```

Set `YADEM_LOG` to override the log path.

## Dotfiles

The `dotfiles` target treats dotfiles as an external repository dependency. By
default it expects:

```sh
YADEM_REPO_DIR="$HOME/workflow"
YADEM_DOTFILES_REPO="https://github.com/evanthegrayt/dotfiles"
YADEM_DOTFILES_REPO_DIR="$YADEM_REPO_DIR/dotfiles"
YADEM_DOTFILES_DIR="$YADEM_DOTFILES_REPO_DIR/dotfiles"
```

If `YADEM_DOTFILES_DIR` is missing, dry-run reports the clone that would happen.
Install clones `YADEM_DOTFILES_REPO` into `YADEM_DOTFILES_REPO_DIR`, then links
files from `YADEM_DOTFILES_DIR` into `$HOME` with a leading dot added. For
example, `zshrc` becomes `~/.zshrc`.

Existing symlinks are replaced. Existing regular files are moved to
`$INSTALL_CACHE_DIR/<name>.<YYYY-MM-DD>` before the new symlink is created.
Existing directories are skipped.

If `YADEM_LOCALIZE_EXISTING=true`, supported existing files are backed up and
linked back as `~/.<name>.local`, preserving the old `yadem` local override
workflow.

To remove managed dotfile symlinks, run:

```sh
bin/yadem dotfiles-uninstall
```

Only symlinks pointing into `YADEM_DOTFILES_DIR` are removed. Pass a single file
as `name` or `.name` to remove one link:

```sh
bin/yadem dotfiles-uninstall zshrc
bin/yadem dotfiles-uninstall .zshrc
```

Add `--restore` or `-R` to move the newest matching backup from
`INSTALL_CACHE_DIR` back into `$HOME` after the symlink is removed.

## Completions

Completion scripts are available in `completions/`:

- `completions/yadem.bash`
- `completions/yadem.zsh`

## Tests

The installer has a Bats test suite. Install `bats-core`, then run:

```sh
bats test
shellcheck bin/yadem bin/lib/yadem.sh bin/yadem.d/* completions/yadem.bash config/yademrc test/*.bash test/*.bats
```

## Development Status

This rebuild keeps `yadem` focused on the dispatcher, target scripts, config,
tests, completions, and `Brewfile` support. Personal dotfiles live in the
separate dotfiles repository and are consumed through the `dotfiles` target.
