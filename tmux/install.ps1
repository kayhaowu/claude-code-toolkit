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

.PARAMETER FontArchive
    Nerd Fonts release archive (<name>.tar.xz) installed for the current user when the
    winget font install fails. Default JetBrainsMono.

.PARAMETER FontVersion
    Nerd Fonts release tag for -FontArchive. Default v3.3.0 (v3 is required: the status
    line uses Material Design icons from the v3 code points).

.PARAMETER SetTerminalFont
    Set profiles.defaults.font.face in Windows Terminal's settings.json to -TerminalFont.
    The file is backed up to settings.json.bak-<yyyyMMdd-HHmmss> before it is changed.

.PARAMETER TerminalFont
    Font face for -SetTerminalFont. Default 'JetBrainsMono Nerd Font'.
#>
[CmdletBinding()]
param(
    [string]$TargetHome = $env:USERPROFILE,
    [switch]$InstallDeps,
    [string]$FontPackage = 'DEVCOM.JetBrainsMonoNerdFont',
    [string]$FontArchive = 'JetBrainsMono',
    [string]$FontVersion = 'v3.3.0',
    [switch]$SetTerminalFont,
    [string]$TerminalFont = 'JetBrainsMono Nerd Font'
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

function Install-NerdFontArchive($name, $version) {
    if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
        throw 'tar.exe not found (it ships with Windows 10 1803 and later).'
    }
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$version/$name.tar.xz"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nerdfont-$name-$version"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $archive = Join-Path $tmp "$name.tar.xz"
    Write-Info "download $url"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'  # the progress bar makes Invoke-WebRequest very slow on 5.1
    try { Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing } finally { $ProgressPreference = $oldProgress }
    & tar -xf $archive -C $tmp
    if ($LASTEXITCODE -ne 0) { throw "tar could not extract $archive (exit $LASTEXITCODE)." }

    # <Name>NerdFont-<Style>.ttf only; the NerdFontMono/NerdFontPropo variants and other
    # families in the archive (e.g. JetBrainsMonoNL) are not needed. Some archives use a
    # different file prefix (CascadiaCode -> CaskaydiaCove), hence the generic fallback.
    $fonts = @(Get-ChildItem -LiteralPath $tmp -Filter "${name}NerdFont-*.ttf" -File)
    if ($fonts.Count -eq 0) { $fonts = @(Get-ChildItem -LiteralPath $tmp -Filter '*NerdFont-*.ttf' -File) }
    if ($fonts.Count -eq 0) { throw "No *NerdFont-*.ttf files in $archive." }
    $dst = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    $reg = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path -LiteralPath $reg)) { New-Item -Path $reg -Force | Out-Null }
    if (-not ('FontApi' -as [type])) {
        Add-Type -Name FontApi -Namespace '' -MemberDefinition '[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResourceW(string file);'
    }
    foreach ($f in $fonts) {
        $target = Join-Path $dst $f.Name
        # An installed font may be locked by a running app; skip files that are already there.
        if (-not (Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $target).Length -ne $f.Length) {
            Copy-Item -LiteralPath $f.FullName -Destination $target -Force
        }
        $valueName = ($f.BaseName -replace 'NerdFont-', ' Nerd Font ') + ' (TrueType)'
        Set-ItemProperty -Path $reg -Name $valueName -Value $target
        # Makes the font usable in this logon session without signing out.
        [void][FontApi]::AddFontResourceW($target)
    }
    Write-Info "$($fonts.Count) font files installed to $dst"
}

function Set-TerminalFont($face, $stamp) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $paths = @($candidates | Where-Object { Test-Path -LiteralPath $_ })
    if ($paths.Count -eq 0) {
        Write-Warn "Windows Terminal settings.json not found (start Windows Terminal once first); select '$face' in your terminal by hand."
        return
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    foreach ($p in $paths) {
        try {
            $json = [IO.File]::ReadAllText($p, $utf8) | ConvertFrom-Json
        } catch {
            Write-Warn "$p could not be parsed (comments are not supported here); set profiles.defaults.font.face to '$face' by hand."
            continue
        }
        $profiles = $json.profiles
        if (-not $profiles -or $profiles -is [array]) {
            Write-Warn "$p has no profiles.defaults section; set the font to '$face' in Windows Terminal by hand."
            continue
        }
        if (-not $profiles.PSObject.Properties['defaults']) { $profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
        $defaults = $profiles.defaults
        if (-not $defaults.PSObject.Properties['font']) { $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) }
        $font = $defaults.font
        foreach ($prof in @($profiles.list)) {
            if ($prof -and $prof.PSObject.Properties['font'] -and $prof.font.PSObject.Properties['face'] -and $prof.font.face -ne $face) {
                Write-Warn "Profile '$($prof.name)' sets its own font ($($prof.font.face)), which overrides the default."
            }
        }
        if ($font.PSObject.Properties['face'] -and $font.face -eq $face) {
            Write-Ok "$p (font already $face)"
            continue
        }
        $backup = "$p.bak-$stamp"
        Copy-Item -LiteralPath $p -Destination $backup -Force
        Write-Info "backup: $backup"
        if ($font.PSObject.Properties['face']) { $font.face = $face } else { $font | Add-Member -NotePropertyName face -NotePropertyValue $face }
        [IO.File]::WriteAllText($p, ($json | ConvertTo-Json -Depth 100), $utf8)
        Write-Ok "$p (profiles.defaults.font.face = $face)"
    }
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
    try {
        Invoke-Winget $FontPackage
        Write-Ok "Nerd Font installed ($FontPackage)"
    } catch {
        Write-Warn "$($_.Exception.Message) Falling back to the Nerd Fonts release archive."
        Install-NerdFontArchive $FontArchive $FontVersion
        Write-Ok "Nerd Font installed for the current user ($FontArchive $FontVersion)"
    }
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

if ($SetTerminalFont) {
    Write-Host ''
    Write-Host 'Windows Terminal font'
    Set-TerminalFont $TerminalFont $stamp
}

# -- Next steps --------------------------------------------------------------
Write-Host ''
Write-Host 'Next steps:'
Write-Info '1. Open a new terminal (so PATH and fonts are picked up).'
if ($SetTerminalFont) {
    Write-Info "2. Close every Windows Terminal window and reopen it to load '$TerminalFont'."
} elseif ($fontMissing) {
    Write-Info '2. Select the Nerd Font (e.g. "JetBrainsMono Nerd Font") in your terminal settings.'
} else {
    Write-Info '2. Make sure your terminal uses a Nerd Font.'
}
Write-Info '3. Run: tmux   (or psmux)'
Write-Info '4. In sessions that were already running, press C-a r to reload the config.'
