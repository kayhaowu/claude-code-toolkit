<#
.SYNOPSIS
    Install the psmux (native Windows tmux) port of tmux/tmux.conf.

.DESCRIPTION
    Copies tmux\psmux.conf to <TargetHome>\.psmux.conf and tmux\scripts\* to
    <TargetHome>\.config\psmux\scripts\. An existing target file whose content differs
    is backed up to <name>.bak-<yyyyMMdd-HHmmss> before it is overwritten; identical
    files are left alone, so re-running is safe.

    Checks for psmux, PowerShell 7 (pwsh) and a Nerd Font. Nothing is installed unless
    -InstallDeps is given; without it, missing psmux/pwsh print the winget command and
    the script exits with code 1.

    Run with:
        powershell -ExecutionPolicy Bypass -File tmux\install.ps1

.PARAMETER TargetHome
    Home directory to install into. Defaults to $env:USERPROFILE.

.PARAMETER InstallDeps
    Install missing psmux, PowerShell 7 and Nerd Font packages with winget.

.PARAMETER FontPackage
    winget package id of the Nerd Font to install with -InstallDeps.
#>
[CmdletBinding()]
param(
    [string]$TargetHome = $env:USERPROFILE,
    [switch]$InstallDeps,
    [string]$FontPackage = 'DEVCOM.JetBrainsMonoNerdFont'
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "  $msg" }
function Write-Ok($msg)   { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [warn] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  [miss] $msg" -ForegroundColor Red }

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Invoke-Winget($id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found; install '$id' manually."
    }
    Write-Info "winget install --id $id -e"
    & winget install --id $id -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget install $id failed (exit $LASTEXITCODE)." }
    Update-SessionPath
}

function Test-NerdFont {
    $pattern = '(?i)nerd ?font|\bNF[MP]?\b'
    $keys = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach ($k in $keys) {
        $props = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if ($props -and ($props.PSObject.Properties.Name -match $pattern)) { return $true }
    }
    $dirs = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'), (Join-Path $env:WINDIR 'Fonts')
    foreach ($d in $dirs) {
        if (Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern }) {
            return $true
        }
    }
    return $false
}

function Install-File($src, $dst, $stamp) {
    $dir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path -LiteralPath $dst) {
        # Byte compare instead of Get-FileHash, which is missing from some PowerShell 5.1 sessions.
        $same = [Convert]::ToBase64String([IO.File]::ReadAllBytes($src)) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($dst))
        if ($same) {
            Write-Ok "$dst (unchanged)"
            return
        }
        $backup = "$dst.bak-$stamp"
        Copy-Item -LiteralPath $dst -Destination $backup -Force
        Write-Info "backup: $backup"
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Ok $dst
}

$srcConf = Join-Path $PSScriptRoot 'psmux.conf'
$srcScripts = Join-Path $PSScriptRoot 'scripts'
if (-not (Test-Path -LiteralPath $srcConf) -or -not (Test-Path -LiteralPath $srcScripts)) {
    Write-Error "psmux.conf or scripts\ not found next to $PSCommandPath"
    exit 1
}
if (-not (Test-Path -LiteralPath $TargetHome)) {
    Write-Error "TargetHome does not exist: $TargetHome"
    exit 1
}
$TargetHome = (Resolve-Path -LiteralPath $TargetHome).Path

# -- Dependencies ------------------------------------------------------------
Write-Host "Checking dependencies"
$required = @(
    @{ Name = 'psmux'; Command = 'psmux'; Package = 'marlocarlo.psmux' },
    @{ Name = 'PowerShell 7 (pwsh, the default-shell in psmux.conf)'; Command = 'pwsh'; Package = 'Microsoft.PowerShell' }
)
$missing = @()
foreach ($dep in $required) {
    if (Get-Command $dep.Command -ErrorAction SilentlyContinue) {
        Write-Ok $dep.Name
    } elseif ($InstallDeps) {
        Invoke-Winget $dep.Package
        if (Get-Command $dep.Command -ErrorAction SilentlyContinue) {
            Write-Ok "$($dep.Name) installed"
        } else {
            Write-Warn "$($dep.Name) installed but not on PATH yet; open a new terminal."
        }
    } else {
        Write-Fail "$($dep.Name): winget install $($dep.Package)"
        $missing += $dep
    }
}

$fontMissing = $false
if (Test-NerdFont) {
    Write-Ok 'Nerd Font'
} elseif ($InstallDeps) {
    Invoke-Winget $FontPackage
    Write-Ok "Nerd Font installed ($FontPackage)"
    $fontMissing = $true
} else {
    Write-Warn "No Nerd Font detected (status icons need one): winget install $FontPackage"
    $fontMissing = $true
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok 'git'
} else {
    Write-Warn 'Git for Windows not found (git branch and Claude monitor need it): winget install Git.Git'
}

$claudeScript = Join-Path $TargetHome '.claude\tmux-sessions.sh'
if (Test-Path -LiteralPath $claudeScript) {
    $bash = Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bash)) {
        Write-Warn "Claude monitor expects Git Bash at $bash; edit the status-format[1] line in .psmux.conf if Git is installed elsewhere."
    }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Warn 'Claude monitor needs jq: winget install jqlang.jq'
    }
}

if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Host 'Install the missing packages above, or re-run with -InstallDeps to install them with winget.'
    exit 1
}

# -- Files -------------------------------------------------------------------
Write-Host ''
Write-Host "Installing into $TargetHome"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$psmuxDir = Join-Path $TargetHome '.config\psmux'
Install-File $srcConf (Join-Path $TargetHome '.psmux.conf') $stamp
foreach ($f in Get-ChildItem -LiteralPath $srcScripts -File) {
    Install-File $f.FullName (Join-Path (Join-Path $psmuxDir 'scripts') $f.Name) $stamp
}
New-Item -ItemType Directory -Force -Path (Join-Path $psmuxDir 'cache') | Out-Null

# psmux loads only the first config it finds:
# ~/.psmux.conf, ~/.psmuxrc, ~/.tmux.conf, ~/.config/psmux/psmux.conf
foreach ($name in '.psmuxrc', '.tmux.conf', '.config\psmux\psmux.conf') {
    $p = Join-Path $TargetHome $name
    if (Test-Path -LiteralPath $p) {
        Write-Warn "$p exists but is ignored: psmux reads ~/.psmux.conf first. Merge anything you need into ~/.psmux.conf."
    }
}
if ($env:PSMUX_CONFIG_FILE) {
    Write-Warn "PSMUX_CONFIG_FILE=$env:PSMUX_CONFIG_FILE overrides ~/.psmux.conf; unset it to use this config."
}

# -- Next steps --------------------------------------------------------------
Write-Host ''
Write-Host 'Next steps:'
Write-Info '1. Open a new terminal (so PATH and fonts are picked up).'
if ($fontMissing) {
    Write-Info '2. Select the Nerd Font (e.g. "JetBrainsMono Nerd Font") in your terminal settings.'
} else {
    Write-Info '2. Make sure your terminal uses a Nerd Font.'
}
Write-Info '3. Run: tmux   (or psmux)'
Write-Info '4. In sessions that were already running, press C-a r to reload the config.'
