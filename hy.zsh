# hy — per-prompt history logger + search shortcut for bash
#
# Source this file from ~/.bashrc:
#     source /path/to/hy.bash
#
# Logs every command to a daily file:
#     ~/.logs/history-YYYY-MM-DD.log
# Format (tab-delimited, exactly one line per command):
#     TIMESTAMP \t PWD \t COMMAND
# where any tabs/newlines inside COMMAND are encoded as the two-char sequences
# \t and \n so each entry stays single-line and unambiguous.
#
# Defines:
#     __hy_log — internal logger, hooked into PROMPT_COMMAND
#     hy       — grep across all daily log files (chronological)
#     hyr      — same as hy but newest match first

# Pick a fast time formatter once at sourcing time:
# bash 4.2+ supports printf '%(...)T'; older bash (e.g. stock /bin/bash 3.2 on
# macOS) falls back to forking date.
if printf -v __hy_probe '%(%s)T' -1 2>/dev/null; then
    __hy_now() { printf -v "$1" '%(%Y-%m-%d.%H:%M:%S)T' -1; printf -v "$2" '%(%Y-%m-%d)T' -1; }
else
    __hy_now() { printf -v "$1" '%s' "$(date '+%Y-%m-%d.%H:%M:%S')"; printf -v "$2" '%s' "$(date '+%Y-%m-%d')"; }
fi
unset __hy_probe

__hy_log() {
    [[ $EUID -eq 0 ]] && return
    [[ -d ~/.logs ]] || mkdir -p ~/.logs
    local ts day cmd
    cmd=$(fc -ln -1 2>/dev/null)
    cmd=${cmd#$'\t'}
    cmd=${cmd# }
    [[ -z $cmd ]] && return
    cmd=${cmd//$'\t'/\\t}
    cmd=${cmd//$'\n'/\\n}
    __hy_now ts day
    printf '%s\t%s\t%s\n' "$ts" "$PWD" "$cmd" >> ~/.logs/history-$day.log
}

# Install __hy_log into PROMPT_COMMAND idempotently.
case ":${PROMPT_COMMAND:-}:" in
    *":__hy_log:"*) ;;
    *) PROMPT_COMMAND="__hy_log${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac

hy() {
    if (( $# == 0 )); then
        echo "Usage: hy <pattern> [grep-options...]" >&2
        return 1
    fi
    grep -h --color=auto "$@" ~/.logs/history-*.log 2>/dev/null
}

hyr() { hy "$@" | { tac 2>/dev/null || tail -r; }; }
