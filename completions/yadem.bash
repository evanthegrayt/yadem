# Bash completion for yadem.
#
# @description Completes global yadem options and discovered target names in Bash.
# @internal
# @noargs
# @set COMPREPLY array Bash completion candidates.
# @exitcode 0 Completion candidates were generated.
_yadem_completion() {
    local cur
    local cmd
    local script_dir
    local install_target_dir
    local user_target_dir
    local configured_target_dirs
    local target
    local target_dir
    local target_name
    local seen_dir
    local seen_target
    local already_seen
    local old_ifs
    local -a target_dirs=()
    local -a seen_dirs=()
    local -a seen_targets=()
    local targets=()
    local options="-h --help -a --all -l --list -t --test -e --edit --verbose"

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    cmd="${COMP_WORDS[0]}"

    if [[ "$cmd" == */* ]]; then
        # When completing ./bin/yadem, resolve target files relative to that path.
        script_dir="$(cd -- "$(dirname -- "$cmd")" >/dev/null 2>&1 && pwd -P)" || script_dir=""
    else
        # For bare `yadem`, ask PATH which executable the shell would run.
        script_dir="$(cd -- "$(dirname -- "$(command -v "$cmd" 2>/dev/null)")" >/dev/null 2>&1 && pwd -P)" || script_dir=""
    fi

    install_target_dir="$script_dir/yadem.d"
    user_target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/yadem/yadem.d"
    configured_target_dirs="${YADEM_TARGET_DIRS:-$user_target_dir}"
    old_ifs="$IFS"
    IFS=:
    read -r -a target_dirs <<< "$configured_target_dirs"
    IFS="$old_ifs"
    target_dirs+=("$install_target_dir")

    for target_dir in "${target_dirs[@]}"; do
        [[ -n "$target_dir" && -d "$target_dir" ]] || continue

        already_seen=false
        for seen_dir in "${seen_dirs[@]}"; do
            if [[ "$seen_dir" == "$target_dir" ]]; then
                already_seen=true
                break
            fi
        done
        [[ "$already_seen" == false ]] || continue
        seen_dirs+=("$target_dir")

        for target in "$target_dir"/*.bash; do
            # Bash leaves an unmatched glob literal unless nullglob is enabled.
            [[ -f "$target" ]] || continue
            target_name="${target##*/}"
            target_name="${target_name%.bash}"

            already_seen=false
            for seen_target in "${seen_targets[@]}"; do
                if [[ "$seen_target" == "$target_name" ]]; then
                    already_seen=true
                    break
                fi
            done
            [[ "$already_seen" == false ]] || continue

            seen_targets+=("$target_name")
            targets+=("$target_name")
        done
    done

    if [[ "$cur" == -* ]]; then
        while IFS= read -r target; do
            COMPREPLY+=("$target")
        done < <(compgen -W "$options" -- "$cur")
    else
        while IFS= read -r target; do
            COMPREPLY+=("$target")
        done < <(compgen -W "${targets[*]}" -- "$cur")
    fi
}

complete -F _yadem_completion bin/yadem ./bin/yadem yadem

# If this repository's bin directory is early in PATH and you want bare
# "yadem" completion, source this file in your shell config.
