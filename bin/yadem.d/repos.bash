# @description Prints help for the repos target.
# @noargs
# @stdout Target usage and behavior details.
# @exitcode 0 Help was printed.
print_help() {
    cat <<HELP
USAGE: yadem [OPTIONS] repos

Clone configured git repositories into YADEM_REPO_DIR.

Configuration:
  YADEM_REPO_DIR             Directory where repositories are cloned
  YADEM_REPOS                Bash array of repository URLs
  YADEM_REPO_AUTO_RUN_BUILD  Run rake/make after cloning when set to true

Each repository is cloned into YADEM_REPO_DIR using the repository basename. If
a configured URL does not end in .git, yadem adds .git for the clone command.

Existing repositories are left alone when YADEM_REPO_DIR/<name>/.git exists.

Build behavior:
  When YADEM_REPO_AUTO_RUN_BUILD=true, newly cloned repositories run rake if
  they have a Rakefile and make if they have a Makefile.

Dry-run:
  yadem --test repos

Dry-run lists clone destinations without creating directories or running
builds.
HELP
}

# @description Derives a local directory name from a repository URL.
# @arg $1 string Repository URL.
# @stdout Repository basename without a trailing `.git`.
# @exitcode 0 Always.
repo_name_for() {
    local repo="$1"

    # Strip only a trailing .git, then take the basename after the final slash.
    repo="${repo%.git}"
    printf "%s\n" "${repo##*/}"
}

# @description Runs optional post-clone build commands for a repository.
# @arg $1 string Cloned repository path.
# @exitcode 0 Builds are disabled, absent, or completed.
# @exitcode 1 A build command failed.
run_repo_builds() {
    local repo_path="$1"

    if [[ "$YADEM_REPO_AUTO_RUN_BUILD" != true ]]; then
        return
    fi

    if [[ -f "$repo_path/Rakefile" ]]; then
        say_and_log running-rake "Running rake in $repo_path"
        # Use a subshell so the caller's working directory never changes.
        (cd "$repo_path" && rake)
    fi

    if [[ -f "$repo_path/Makefile" ]]; then
        say_and_log running-make "Running make in $repo_path"
        # Use a subshell so the caller's working directory never changes.
        (cd "$repo_path" && make)
    fi
}

# @description Clones configured Git repositories into `YADEM_REPO_DIR`.
# @noargs
# @exitcode 0 Repositories are cloned, present, skipped, or dry-run reported them.
# @exitcode 1 Git is missing or clone/build failed.
install() {
    local repo
    local repo_name
    local repo_path
    local clone_url

    load_yadem_config

    # ${#array[@]} is the number of configured array entries.
    if ((${#YADEM_REPOS[@]} == 0)); then
        say_and_log skipped "No git repositories configured"
        return
    fi

    if [[ "$DRY_RUN" != true ]]; then
        require_command git || return
        mkdir -p "$YADEM_REPO_DIR"
    fi

    for repo in "${YADEM_REPOS[@]}"; do
        repo_name="$(repo_name_for "$repo")"
        repo_path="$YADEM_REPO_DIR/$repo_name"
        clone_url="$(git_clone_url_for "$repo")"

        if [[ -d "$repo_path/.git" ]]; then
            say_and_log present "Repository already cloned: $repo_path"
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            say_and_log would-clone "Would clone $clone_url to $repo_path"
            continue
        fi

        say_and_log cloning "Cloning $clone_url to $repo_path"
        git clone "$clone_url" "$repo_path"
        run_repo_builds "$repo_path"
    done
}

# @description Previews configured repository cloning.
# @noargs
# @exitcode 0 Dry-run completed.
dry_run() {
    DRY_RUN=true
    install
}
