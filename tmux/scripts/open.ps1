# tmux-open replacement: open the copy-mode selection (piped on stdin) with its Windows handler,
# or search it on Google with -Search. Bound to `o` / `S` in copy mode by ~/.psmux.conf.
param([switch]$Search)

$sel = (@($input) -join "`n").Trim()
if (-not $sel) { exit 0 }

if ($Search) {
    Start-Process ('https://www.google.com/search?q=' + [uri]::EscapeDataString($sel))
} elseif ($sel -match '^(https?|ftp)://\S+$') {
    Start-Process $sel
} else {
    $path = [Environment]::ExpandEnvironmentVariables($sel) -replace '^~', $env:USERPROFILE
    if (Test-Path -LiteralPath $path) { Invoke-Item -LiteralPath $path }
}
