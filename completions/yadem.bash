# Bash completion for yadem.
_yadem_completion() {
    local cur
    local cmd
    local script_dir
    local target_dir
    local target
    local targets=()
    local options="-h --help -a --all -l --list -t --test -e --edit"

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    cmd="${COMP_WORDS[0]}"

    if [[ "$cmd" == */* ]]; then
        script_dir="$(cd -- "$(dirname -- "$cmd")" >/dev/null 2>&1 && pwd -P)" || script_dir=""
    else
        script_dir="$(cd -- "$(dirname -- "$(command -v "$cmd" 2>/dev/null)")" >/dev/null 2>&1 && pwd -P)" || script_dir=""
    fi

    target_dir="$script_dir/yadem.d"
    for target in "$target_dir"/*.bash; do
        [[ -f "$target" ]] || continue
        target="${target##*/}"
        targets+=("${target%.bash}")
    done

    if [[ "$cur" == -* ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$options" -- "$cur")
    else
        mapfile -t COMPREPLY < <(compgen -W "${targets[*]}" -- "$cur")
    fi
}

complete -F _yadem_completion bin/yadem ./bin/yadem yadem

# If this repository's bin directory is early in PATH and you want bare
# "yadem" completion, source this file in your shell config.
