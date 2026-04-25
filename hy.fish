# hy — per-command history logger + search shortcut for fish
#
# Source this file from ~/.config/fish/config.fish:
#     source /path/to/hy.fish
# Or symlink it into ~/.config/fish/conf.d/ for auto-loading:
#     ln -s /path/to/hy.fish ~/.config/fish/conf.d/hy.fish
#
# Logs every command to a daily file:
#     ~/.logs/history-YYYY-MM-DD.log
# Format (tab-delimited, exactly one line per command):
#     TIMESTAMP \t PWD \t COMMAND
# where any tabs/newlines inside COMMAND are encoded as the two-char sequences
# \t and \n so each entry stays single-line and unambiguous.
#
# Defines:
#     __hy_log — internal logger, fires on fish_postexec
#     hy       — grep across all daily log files (chronological)
#     hyr      — same as hy but newest match first

function __hy_log --on-event fish_postexec --description 'log each command to ~/.logs/history-DATE.log'
    if test (id -u) -eq 0
        return
    end
    test -d ~/.logs; or mkdir -p ~/.logs
    set -l cmd $argv[1]
    if test -z "$cmd"
        return
    end
    set -l ts  (date "+%Y-%m-%d.%H:%M:%S")
    set -l day (date "+%Y-%m-%d")
    set cmd (string replace --all \t '\t' -- $cmd)
    set cmd (string replace --all \n '\n' -- $cmd)
    printf '%s\t%s\t%s\n' "$ts" "$PWD" "$cmd" >> ~/.logs/history-$day.log
end

function hy --description 'grep across ~/.logs history files'
    if test (count $argv) -eq 0
        echo "Usage: hy <pattern> [grep-options...]" >&2
        return 1
    end
    set -l files (find ~/.logs -maxdepth 1 -name 'history-*.log' -type f 2>/dev/null | sort)
    if test (count $files) -eq 0
        return 0
    end
    grep -h --color=auto $argv $files
end

function hyr --description 'hy, newest match first'
    if command -q tac
        hy $argv | tac
    else
        hy $argv | tail -r
    end
end
