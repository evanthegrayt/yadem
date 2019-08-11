# Yet Another Dotfile and Environment Manager
A command line interface installation script for your custom Mac/Linux
environment, with a boat-load of features.

## Rationale
Ideally, you shouldn't need a script this hefty for installing your
configuration, as most people only need to get their environment set up once
per-computer they purchase. However, I regularly have to set up my workflow on
various VMs and Vagrant boxes, and I got tired of constantly having to manually
set up my dotfiles, `vim`, `rvm`, `zsh`, `virtualbox`, `vagrant`, `git-lfs`, and
the like. So, I made a script that does it all for me.

## Installation
Clone the repository wherever you want it:
```sh
git clone https://github.com/evanthegrayt/yadem.git
```

## Features
### Config File
This script reads a [config file](config/yademrc). This file contains all of my
preferred configurations. If you'd like to change anything, you can copy the
file to `~/.yademrc`, and change whatever values you'd like.

The biggest appeal to this script is the dotfile installation aspect, so
requiring a dotfile to be located in your home directory for installation can be
counter-intuitive. For this reason, you can pass the config file with `-r
/path/to/config_file`. Note that the config file must still be called either
`yademrc` or `.yademrc`.

Currently, if a custom `yademrc` file is passed, that file will be sourced,
while `config/yademrc` will not be sourced at all. If people would rather just
have `~/.yademrc` sourced *after* `config/yademrc`, that would be easy enough to
implement, so just let me know.

### Dotfile Installation
Running `bin/install -f` will link the files from `$DOTFILE_DIR` to `$HOME` as
dotfiles, unless the file is in the `IGNORE` array. These values can be changed
in the [config file](config/yademrc). Currently, the files must not
start with a dot; when it links them to the home directory, it will add the dot
automatically. This is by design, as I didn't want to have a repository of
hidden files.

By default, the script won't move or overwrite currently-existing
files. To change the way existing files are handled, see the options under
"Handling old dotfiles" in the [help documentation](lib/help_menu.txt). There
are also a lot of other options, including installing a single file, cloning
shell frameworks, etc.

### "Local" Config Files
There are settings I have that are specifically for work that I didn't want to
commit to a public repository, so I have added a feature to deal with this
issue in my dotfiles themselves: If a file exists in your home directory with
the same name, but has a `.local` extension, that file will be sourced *after*
the file from the repository is loaded. This allows for overriding settings from
the files in the repository.  You can keep these locally, or store them in a
private repository, which is what I've done. You can edit which files will
source "local" counterparts in the [config file](config/yademrc).

When running the install script, you can pass `-L`, and if the file already
exists, it'll be backed up, and then re-linked to `$HOME` as `[FILE].local`. To
use this feature, you'll need to add a `source` line at the end of your file.
```sh
# zshrc
# ...normal zshrc stuff would go here!
[[ -f $HOME/.zshrc.local ]] && source $HOME/.zshrc.local
```

### Custom Repositories
You can add repositories to the `GIT_REPOS` array in the `yademrc` file.  These
will be cloned when the `-c` option is passed. When this option is passed, the
repository will be cloned, and if there's a `Rakefile` or `Makefile`, it will be
executed.

### Install Packages with Brew
There are two arrays in the `yademrc` file which allow you to add programs to be
installed with `brew install` (`BREW_TAPS`) or `brew cask install`
(`BREW_CASKS`). If you don't know the difference between the two, I recommend
researching them.

### Ruby Gems
You can add ruby gems to the `RUBY_GEMS` array and install them with `-g`. This
might be changed to use a `Gemfile` at some point.

### Logging
Everything that's done by the install script is logged, whether it's
installation of programs or linking of files. There will be a log file for every
day the `bin/install` script is run, and these will be located in the `log/`
directory, along with time stamps. You can print the log file for today's date
using `bin/install -p`. To print an older log file, run `bin/install -P [DATE]`.
To get a list of log files, run `bin/install -l`.

## Un-Installation
If you want to uninstall just the dotfiles, just run the `install` script with
the `-u` option; however, this script *does* come with a way to safely remove
the entire repository without losing the files saved in the `backup` directory.
Just run the `safely_uninstall_repo` script in the `bin` directory. It will move
all the files in the `backup` directory to your `$HOME` directory before
removing the entire repository.

## FAQ
#### Why not use submodules?
I tried keeping repositories in here as submodules (such as `vim`, `oh-my-zsh`,
etc.), but I didn't like it, as I wanted more control over what gets installed
from system to system. Having the option to install these other repositories via
the `install` script seemed like the best compromise.

## Disclaimers
Obviously, the variables set in the [config file](config/yademrc) are set up for
my workflow, so don't be surprised if some things don't work for you, or if you
don't like my setup.

Also, I've given users a lot of options for saving/backing up their
old dotfiles, but it IS possible to delete your old files. I recommend keeping
them in a separate repository, or at least a backup of some kind.

## Reporting Bugs
If issues are found, please [creating an issue in the
repository](https://github.com/evanthegrayt/yadem/issues/new)
detailing the problem.

