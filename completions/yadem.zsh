#compdef yadem bin/yadem ./bin/yadem

_yadem() {
    emulate -L zsh

    local cmd
    local script_dir
    local target_dir
    local target
    local -a targets

    cmd="${words[1]}"

    if [[ "$cmd" == */* ]]; then
        script_dir="${cmd:h:A}"
    else
        script_dir="${commands[$cmd]:h}"
    fi

    target_dir="$script_dir/yadem.d"
    targets=()

    for target in "$target_dir"/*.bash(.N); do
        targets+=("${${target:t}%.bash}")
    done

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
