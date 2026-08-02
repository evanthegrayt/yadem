#!/usr/bin/env bats

load ../test_helper

setup() {
    setup_install_home
}

@test "repos dry-run uses configured repositories" {
    write_yadem_config \
        "YADEM_REPO_DIR=\"$TEST_HOME/workflow\"" \
        "YADEM_REPOS=(https://github.com/example/project)"

    run_yadem --test repos

    assert_success
    assert_output_contains "Would clone https://github.com/example/project.git to $TEST_HOME/workflow/project"
    assert_file_contains "$TEST_CACHE/yadem/install.log" "repos would-clone"
}
