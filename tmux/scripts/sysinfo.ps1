# psmux status collector: CPU / RAM / battery segments (replaces tmux-cpu + tmux-battery).
# Started by ~/.psmux.conf with `run-shell -b`. One instance per user (named mutex).
# Writes pre-formatted Catppuccin Mocha segments to the cache file every $IntervalSec seconds;
# the status line reads it with `#(type ...)`, so no PowerShell starts on each status refresh.
# Exits on its own once no psmux session is left on the default socket (checked every ~30 s).
param(
    [int]$IntervalSec = 2,
    [string]$CacheFile = (Join-Path $env:USERPROFILE '.config\psmux\cache\sysinfo.txt')
)

$ErrorActionPreference = 'SilentlyContinue'

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\psmux-sysinfo-collector', [ref]$created)
if (-not $created) { exit 0 }

$psmux = (Get-Command psmux, tmux -ErrorAction SilentlyContinue | Select-Object -First 1).Source
New-Item -ItemType Directory -Force -Path (Split-Path $CacheFile) | Out-Null
$tmp = "$CacheFile.tmp"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Win32 calls instead of CIM: polling Win32_Processor every 2 s cost ~6% of a core.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PsmuxSys {
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
    [StructLayout(LayoutKind.Sequential)] public class MEMSTAT {
        public uint dwLength = (uint)Marshal.SizeOf(typeof(MEMSTAT)); public uint dwMemoryLoad;
        public ulong a, b, c, d, e, f, g;
    }
    [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx([In, Out] MEMSTAT m);
    [StructLayout(LayoutKind.Sequential)] public struct POWER {
        public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag; public int a, b;
    }
    [DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out POWER p);
    static long pi, pt;
    public static int Cpu() {
        long i, k, u; GetSystemTimes(out i, out k, out u);
        long t = k + u, dt = t - pt, di = i - pi; pi = i; pt = t;
        return dt <= 0 ? 0 : (int)Math.Round(100.0 * (dt - di) / dt);
    }
    public static int Ram() { var m = new MEMSTAT(); GlobalMemoryStatusEx(m); return (int)m.dwMemoryLoad; }
}
'@
[void][PsmuxSys]::Cpu()

# Catppuccin Mocha
$crust = '#11111b'; $mantle = '#181825'; $surface0 = '#313244'; $text = '#cdd6f4'
$green = '#a6e3a1'; $yellow = '#f9e2af'; $red = '#f38ba8'; $teal = '#94e2d5'; $lavender = '#b4befe'
$L = [char]0xE0B6   # rounded left cap
$R = [char]0x2588   # catppuccin default right separator (full block)

function Module($color, $icon, $value) {
    "#[fg=$color,bg=$mantle]$L#[fg=$crust,bg=$color]$icon#[fg=$text,bg=$surface0] $value#[fg=$surface0,bg=$mantle]$R"
}

function BatteryIcon($pct, $ac, $charging) {
    if ($charging) { return [char]::ConvertFromUtf32(0xF0084) }                           # charging
    if ($ac) {
        if ($pct -ge 95) { return [char]::ConvertFromUtf32(0xF06A5) }                    # plugged, full
        return [char]::ConvertFromUtf32(0xF0084)
    }
    $tiers = 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079
    $i = [math]::Min(9, [math]::Max(0, [math]::Floor($pct / 10)))
    [char]::ConvertFromUtf32($tiers[$i])
}

$tick = 0
while ($true) {
    [System.Threading.Thread]::Sleep($IntervalSec * 1000)
    $cpu = [PsmuxSys]::Cpu()
    $ram = [PsmuxSys]::Ram()
    $pw = New-Object PsmuxSys+POWER
    [void][PsmuxSys]::GetSystemPowerStatus([ref]$pw)

    # tmux-cpu default thresholds: medium >= 30, high >= 80
    $cpuColor = if ($cpu -ge 80) { $red } elseif ($cpu -ge 30) { $yellow } else { $green }

    $out = Module $cpuColor ' CPU ' ("{0,3}%" -f $cpu)
    $out += "#[fg=$teal,bg=$mantle]$L#[fg=$crust,bg=$teal] RAM #[fg=$text,bg=$mantle] $ram% "
    # BatteryFlag 128 = no system battery, 255 = unknown (desktop): no battery segment
    if ($pw.BatteryFlag -ne 128 -and $pw.BatteryFlag -ne 255 -and $pw.BatteryLifePercent -le 100) {
        $pct = [int]$pw.BatteryLifePercent
        $icon = BatteryIcon $pct ($pw.ACLineStatus -eq 1) (($pw.BatteryFlag -band 8) -ne 0)
        $out += Module $lavender ($icon + ' ') "$pct%"
    }

    [System.IO.File]::WriteAllText($tmp, $out, $utf8)
    [System.IO.File]::Copy($tmp, $CacheFile, $true)

    $tick++
    if ($psmux -and ($tick % 15) -eq 0) {
        $sessions = & $psmux ls 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $sessions) { break }
    }
}

Remove-Item -LiteralPath $CacheFile, $tmp -Force -ErrorAction SilentlyContinue
$mutex.ReleaseMutex()
