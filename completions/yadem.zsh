#compdef yadem bin/yadem ./bin/yadem

# @description Completes global yadem options and discovered target names in Zsh.
# @internal
# @arg $@ string Completion arguments supplied by Zsh.
# @exitcode 0 Completion candidates were generated.
_yadem() {
    # Localize option changes and use zsh completion semantics inside the function.
    emulate -L zsh

    local cmd
    local script_dir
    local repo_dir
    local install_target_dir
    local user_target_dir
    local configured_target_dirs
    local target_dir
    local target
    local target_name
    local -a target_dirs
    local -a seen_dirs
    local -a targets

    cmd="${words[1]}"

    if [[ "$cmd" == */* ]]; then
        # zsh modifiers: :h takes the dirname, :A resolves it to an absolute path.
        script_dir="${cmd:A:h}"
    else
        # $commands maps executable names to the path zsh would run.
        script_dir="${commands[$cmd]:A:h}"
    fi

    repo_dir="${script_dir:h}"
    install_target_dir="$repo_dir/targets"
    user_target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/yadem/yadem.d"
    configured_target_dirs="${YADEM_TARGET_DIRS:-$user_target_dir}"
    target_dirs=("${(@s.:.)configured_target_dirs}" "$install_target_dir")
    seen_dirs=()
    targets=()

    for target_dir in "${target_dirs[@]}"; do
        [[ -n "$target_dir" && -d "$target_dir" ]] || continue
        if (( ${seen_dirs[(Ie)$target_dir]} )); then
            continue
        fi
        seen_dirs+=("$target_dir")

        for target in "$target_dir"/*.bash(.N); do
            # Glob qualifiers: . limits matches to plain files and N suppresses
            # errors when there are no matches.
            target_name="${${target:t}%.bash}"
            if (( ${targets[(Ie)$target_name]} )); then
                continue
            fi
            targets+=("$target_name")
        done
    done

    # _arguments declares option completions and sends positional words to the
    # `targets` state handled below.
    _arguments -C \
        '(-t --test)'{-t,--test}'[show what would happen without installing]' \
        '(-a --all)'{-a,--all}'[run the configured target sequence]' \
        '(-l --list)'{-l,--list}'[list available install targets]' \
        '--verbose[show resolved target paths with --list]' \
        '(-e --edit)'{-e,--edit}'[open a target in an editor]' \
        '(-h --help)'{-h,--help}'[display help]' \
        '*:target:->targets'

    case "$state" in
        targets)
            _describe 'install target' targets
            ;;
    esac
}

_yadem "$@"
