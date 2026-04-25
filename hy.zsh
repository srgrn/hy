# hy — per-prompt history logger + search shortcut for zsh
#
# Source this file from ~/.zshrc:
#     source /path/to/hy.zsh
#
# Logs every command to a daily file:
#     ~/.logs/history-YYYY-MM-DD.log
# Format (tab-delimited, exactly one line per command):
#     TIMESTAMP \t PWD \t COMMAND
# where any tabs/newlines inside COMMAND are encoded as the two-char sequences
# \t and \n so each entry stays single-line and unambiguous.
#
# Defines:
#     __hy_log — runs before every prompt; logs the just-executed command
#                (registered via add-zsh-hook so it coexists with oh-my-zsh,
#                starship, prezto, your own precmd, etc.)
#     hy       — grep across all daily log files (chronological)
#     hyr      — same as hy but newest match first

zmodload zsh/datetime
autoload -Uz add-zsh-hook

__hy_log() {
    [[ $EUID -eq 0 ]] && return
    [[ -d ~/.logs ]] || mkdir -p ~/.logs
    local ts day cmd
    strftime -s ts  "%Y-%m-%d.%H:%M:%S" $EPOCHSECONDS
    strftime -s day "%Y-%m-%d"          $EPOCHSECONDS
    cmd=$(fc -ln -1)
    cmd=${cmd#$'\t'}
    cmd=${cmd//$'\t'/\\t}
    cmd=${cmd//$'\n'/\\n}
    [[ -z $cmd ]] && return
    printf '%s\t%s\t%s\n' "$ts" "$PWD" "$cmd" >> ~/.logs/history-$day.log
}

# Register idempotently — add-zsh-hook dedupes by function name, so re-sourcing
# this file won't stack duplicate hooks.
add-zsh-hook precmd __hy_log

hy() {
    if (( $# == 0 )); then
        print -u2 "Usage: hy <pattern> [grep-options...]"
        return 1
    fi
    grep -h --color=auto "$@" ~/.logs/history-*.log 2>/dev/null
}

hyr() { hy "$@" | (tac 2>/dev/null || tail -r) }
