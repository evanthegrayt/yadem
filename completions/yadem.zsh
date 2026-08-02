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
    local target_dir
    local target
    local -a targets

    cmd="${words[1]}"

    if [[ "$cmd" == */* ]]; then
        # zsh modifiers: :h takes the dirname, :A resolves it to an absolute path.
        script_dir="${cmd:h:A}"
    else
        # $commands maps executable names to the path zsh would run.
        script_dir="${commands[$cmd]:h}"
    fi

    target_dir="$script_dir/yadem.d"
    targets=()

    for target in "$target_dir"/*.bash(.N); do
        # Glob qualifiers: . limits matches to plain files and N suppresses
        # errors when there are no matches.
        targets+=("${${target:t}%.bash}")
    done

    # _arguments declares option completions and sends positional words to the
    # `targets` state handled below.
    _arguments -C \
        '(-t --test)'{-t,--test}'[show what would happen without installing]' \
        '(-a --all)'{-a,--all}'[run the configured target sequence]' \
        '(-l --list)'{-l,--list}'[list available install targets]' \
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
