#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "repos dry-run uses configured repositories" {
    write_yadem_config \
        "YADEM_REPOS_DIR=\"$TEST_HOME/workflow\"" \
        "YADEM_REPOS=(https://github.com/example/project)"

    run_yadem --test repos

    assert_success
    assert_output_contains "Would clone https://github.com/example/project.git to $TEST_HOME/workflow/project"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "repos would-clone"
}

@test "repos can run builds after cloning" {
    local fake_bin="$BATS_TEST_TMPDIR/fake-bin.$BATS_TEST_NUMBER"
    local repo_path="$TEST_HOME/workflow/project"

    mkdir -p "$fake_bin"
    cat > "$fake_bin/git" <<'SH'
#!/usr/bin/env bash
set -e

if [[ "$1" != clone ]]; then
    exit 1
fi

mkdir -p "$3/.git"
printf "task :default\n" > "$3/Rakefile"
SH
    chmod +x "$fake_bin/git"

    cat > "$fake_bin/rake" <<'SH'
#!/usr/bin/env bash
set -e

printf "ran\n" > .rake-ran
SH
    chmod +x "$fake_bin/rake"

    write_yadem_config \
        "YADEM_REPOS_DIR=\"$TEST_HOME/workflow\"" \
        "YADEM_REPOS=(https://github.com/example/project)" \
        "YADEM_REPOS_AUTO_RUN_BUILD=true"

    PATH="$fake_bin:$PATH" run_yadem repos

    assert_success
    [[ -f "$repo_path/.rake-ran" ]]
    assert_output_contains "Running rake in $repo_path"
}
