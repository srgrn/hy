# hy - per-prompt history logger + search shortcut for PowerShell
#
# Dot-source this file from your PowerShell profile:
#     . "$HOME/.config/hy/hy.ps1"
#
# Logs every command to a daily file:
#     ~/.logs/history-YYYY-MM-DD.log
# Format (tab-delimited, exactly one line per command):
#     TIMESTAMP \t PWD \t COMMAND
# where any tabs/newlines inside COMMAND are encoded as the two-char sequences
# \t and \n so each entry stays single-line and unambiguous.
#
# Defines:
#     __hy_log - internal logger, hooked by wrapping prompt
#     hy       - searches across all daily log files (chronological)
#     hyr      - same as hy but newest match first

function global:__hy_is_elevated_or_root {
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            return $false
        }
    }

    return [Environment]::UserName -eq 'root'
}

function global:__hy_escape_field {
    param(
        [AllowNull()]
        [string] $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return $Value.Replace("`t", '\t').Replace("`r`n", '\n').Replace("`n", '\n').Replace("`r", '\n')
}

function global:__hy_log {
    if (__hy_is_elevated_or_root) {
        return
    }

    $latest = Get-History -Count 1 -ErrorAction SilentlyContinue
    if ($null -eq $latest -or [string]::IsNullOrWhiteSpace($latest.CommandLine)) {
        return
    }

    if ($global:__hy_LastHistoryId -eq $latest.Id) {
        return
    }
    $global:__hy_LastHistoryId = $latest.Id

    $logDir = Join-Path $HOME '.logs'
    if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $now = Get-Date
    $command = __hy_escape_field $latest.CommandLine.Trim()
    if ([string]::IsNullOrWhiteSpace($command)) {
        return
    }

    $line = '{0:yyyy-MM-dd.HH:mm:ss}{1}{2}{1}{3}' -f $now, "`t", (Get-Location).Path, $command
    $logFile = Join-Path $logDir ('history-{0:yyyy-MM-dd}.log' -f $now)
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::AppendAllText($logFile, "$line`n", $utf8NoBom)
}

function global:hy {
    if ($args.Count -eq 0) {
        Write-Error 'Usage: hy <pattern> [-i|--ignore-case] [-F|--fixed-strings]'
        return
    }

    $caseSensitive = $true
    $simpleMatch = $false
    $patterns = [System.Collections.Generic.List[string]]::new()

    foreach ($arg in $args) {
        switch -Regex ($arg) {
            '^-i$|^--ignore-case$' {
                $caseSensitive = $false
                continue
            }
            '^-F$|^--fixed-strings$' {
                $simpleMatch = $true
                continue
            }
            default {
                $patterns.Add([string] $arg)
            }
        }
    }

    if ($patterns.Count -eq 0) {
        Write-Error 'Usage: hy <pattern> [-i|--ignore-case] [-F|--fixed-strings]'
        return
    }

    $logDir = Join-Path $HOME '.logs'
    $files = @(Get-ChildItem -LiteralPath $logDir -Filter 'history-*.log' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($files.Count -eq 0) {
        return
    }

    $selectArgs = @{
        Path = $files.FullName
        Pattern = ($patterns -join ' ')
        ErrorAction = 'SilentlyContinue'
    }

    if ($caseSensitive) {
        $selectArgs.CaseSensitive = $true
    }
    if ($simpleMatch) {
        $selectArgs.SimpleMatch = $true
    }

    Select-String @selectArgs | ForEach-Object { $_.Line }
}

function global:hyr {
    $matches = @(hy @args)
    [array]::Reverse($matches)
    $matches
}

# Install __hy_log by wrapping prompt idempotently. PowerShell invokes prompt
# after each command, which gives us access to the latest Get-History entry.
if (-not $global:__hy_PromptInstalled) {
    if (Test-Path Function:\prompt) {
        $global:__hy_OriginalPrompt = (Get-Command prompt -CommandType Function).ScriptBlock
    } else {
        $global:__hy_OriginalPrompt = {
            "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
        }
    }

    $latest = Get-History -Count 1 -ErrorAction SilentlyContinue
    $global:__hy_LastHistoryId = if ($null -eq $latest) { 0 } else { $latest.Id }
    $global:__hy_PromptInstalled = $true
}

function global:prompt {
    __hy_log
    & $global:__hy_OriginalPrompt
}
