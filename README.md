# hy

Per-prompt shell history logger plus a `hy <pattern>` search shortcut. The repo provides three sourceable files, one per shell, that all write the same on-disk format.

## What This Does

Every command you run gets appended to a daily log file under `~/.logs/`:

```text
~/.logs/history-2026-04-25.log
~/.logs/history-2026-04-26.log
...
```

Each entry is exactly one line, tab-delimited:

```text
TIMESTAMP  ⇥  PWD  ⇥  COMMAND
```

Two design choices avoid the common failure modes of naive history loggers:

- Fields are tab-delimited, not space-delimited, so paths with spaces stay intact.
- Newlines and tabs inside commands are encoded as the two-character sequences `\n` and `\t`, so multi-line commands remain a single log entry.

You then search across all daily logs with `hy` in chronological order or `hyr` in reverse chronological order:

```sh
hy "rsync"
hy -i FOR
hy "dir with spaces"
hyr git
```

## Files

- `hy.zsh`: hooks `precmd`; uses `zsh/datetime` and `strftime` to avoid forking `date`.
- `hy.bash`: hooks `PROMPT_COMMAND` idempotently; uses `printf '%(…)T'` on bash 4.2+ and falls back to `date` on bash 3.2.
- `hy.fish`: hooks `fish_postexec`; receives the command directly as `$argv[1]`, so multi-line capture is automatic.

All three write the same log format, so shell changes do not break search history continuity.

## Installation

Each one-liner downloads the correct file and wires it into the matching shell startup path.

### zsh

Downloads to `~/.config/hy/hy.zsh` and adds a guarded `source` line to `~/.zshrc`:

```sh
mkdir -p ~/.config/hy && curl -fsSL "__BASE__/hy.zsh?v=$(date +%s)-$$" -o ~/.config/hy/hy.zsh && { grep -qxF 'source ~/.config/hy/hy.zsh' ~/.zshrc 2>/dev/null || echo 'source ~/.config/hy/hy.zsh' >> ~/.zshrc; } && source ~/.config/hy/hy.zsh
```

Registered via `add-zsh-hook precmd`, so it coexists with existing prompt hooks and remains idempotent when re-sourced.

### bash

Downloads to `~/.config/hy/hy.bash` and adds a guarded `source` line to `~/.bashrc`:

```sh
mkdir -p ~/.config/hy && curl -fsSL "__BASE__/hy.bash?v=$(date +%s)-$$" -o ~/.config/hy/hy.bash && { grep -qxF 'source ~/.config/hy/hy.bash' ~/.bashrc 2>/dev/null || echo 'source ~/.config/hy/hy.bash' >> ~/.bashrc; } && source ~/.config/hy/hy.bash
```

### fish

Drops the file into `~/.config/fish/conf.d/`; fish auto-loads files there:

```fish
mkdir -p ~/.config/fish/conf.d && curl -fsSL "__BASE__/hy.fish?v="(date +%s)"-$fish_pid" -o ~/.config/fish/conf.d/hy.fish && exec fish
```

Replace `__BASE__` with the actual URL serving this repo, or use the copy-ready commands from `index.html`.

## Defined Hooks And Commands

| Name | Kind | Purpose |
| --- | --- | --- |
| `precmd` (zsh) / `__hy_log` (bash, fish) | hook | Runs before or after each prompt and appends one log entry. |
| `hy <pattern> [grep-opts...]` | function | Greps across `~/.logs/history-*.log` in chronological order. |
| `hyr <pattern> [grep-opts...]` | function | Same as `hy`, but newest matches first. |

## Verification

After sourcing one of the shell files, try:

```sh
mkdir -p "/tmp/dir with spaces" && cd "/tmp/dir with spaces" && ls

for i in 1 2 3; do
  echo $i
done

git status

tail ~/.logs/history-$(date +%Y-%m-%d).log

hy ls
hyr ls
hy -i FOR
hy "dir with spaces"
```

What to confirm:

- Each log line contains exactly two tab characters.
- The multi-line `for` loop appears as one log line containing literal `\n`.
- The directory with spaces remains intact in field 2.

## Notes And Trade-Offs

- To reconstruct multi-line formatting for display, pipe a log line through `printf '%b\n'` or `sed 's/\\n/\n/g; s/\\t/\t/g'`.
- Older space-delimited log entries remain searchable by content, but they are not tab-parseable.
- Root sessions (`EUID == 0`) are skipped by all three implementations.
- On zsh and bash, the first prompt of a fresh session can log the previous shell's last command.
- `~/.logs` is created on demand if missing.
