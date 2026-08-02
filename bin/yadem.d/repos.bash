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

repo_name_for() {
    local repo="$1"

    repo="${repo%.git}"
    printf "%s\n" "${repo##*/}"
}

run_repo_builds() {
    local repo_path="$1"

    if [[ "$YADEM_REPO_AUTO_RUN_BUILD" != true ]]; then
        return
    fi

    if [[ -f "$repo_path/Rakefile" ]]; then
        say_and_log running-rake "Running rake in $repo_path"
        (cd "$repo_path" && rake)
    fi

    if [[ -f "$repo_path/Makefile" ]]; then
        say_and_log running-make "Running make in $repo_path"
        (cd "$repo_path" && make)
    fi
}

install() {
    local repo
    local repo_name
    local repo_path
    local clone_url

    load_yadem_config

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

dry_run() {
    DRY_RUN=true
    install
}
