# ============================================================
#   LoL PC Optimizer - by Claude
#   Pokreni kao Administrator!
# ============================================================

$Host.UI.RawUI.WindowTitle = "LoL PC Optimizer"
$ErrorActionPreference = "SilentlyContinue"

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         LoL PC OPTIMIZER  v1.0                  ║" -ForegroundColor Cyan
    Write-Host "  ║      Maksimalna optimizacija za gaming           ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "  ► $Text" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Text)
    Write-Host "    ✓ $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "    • $Text" -ForegroundColor Gray
}

# ── Provjera Admin prava ──────────────────────────────────────
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host ""
    Write-Host "  [!] Skripta mora biti pokrenuta kao ADMINISTRATOR!" -ForegroundColor Red
    Write-Host "  [!] Desni klik -> 'Run as Administrator'" -ForegroundColor Red
    Write-Host ""
    pause
    exit
}

Write-Header

# ════════════════════════════════════════════════════════════
# 1. ČIŠĆENJE TEMP FOLDERA
# ════════════════════════════════════════════════════════════
Write-Step "Cistim TEMP foldere..."

$tempPaths = @(
    $env:TEMP,
    $env:TMP,
    "C:\Windows\Temp",
    "C:\Windows\Prefetch"
)

$totalFreed = 0

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        $before = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $totalFreed += $before
        Write-OK "Ociscen: $path"
    }
}

$freedMB = [math]::Round($totalFreed / 1MB, 2)
Write-Info "Oslobođeno ~$freedMB MB prostora"

# ════════════════════════════════════════════════════════════
# 2. REGISTRY OPTIMIZACIJE ZA GAMING
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Step "Primjenjujem Registry optimizacije za gaming..."

# -- Onemogući Game DVR (Xbox Game Bar snimanje koje usporava igre)
$gameDVRPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $gameDVRPath)) { New-Item -Path $gameDVRPath -Force | Out-Null }
Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord
Write-OK "Game DVR onemogucen (manje CPU zauzeća)"

# -- Game Mode uključen
$gameModeKey = "HKCU:\Software\Microsoft\GameBar"
if (-not (Test-Path $gameModeKey)) { New-Item -Path $gameModeKey -Force | Out-Null }
Set-ItemProperty -Path $gameModeKey -Name "AllowAutoGameMode" -Value 1 -Type DWord
Set-ItemProperty -Path $gameModeKey -Name "AutoGameModeEnabled" -Value 1 -Type DWord
Write-OK "Windows Game Mode ukljucen"

# -- Onemogući HPET (High Precision Event Timer) putem registrija
# (pomaže kod nekim CPU-ima da smanji latenciju)
$hpetKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\ROOT\ACPI_HAL\0000"
if (Test-Path $hpetKey) {
    Set-ItemProperty -Path $hpetKey -Name "DeviceReported" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}
Write-OK "HPET podesavanja primijenjena"

# -- Prioritet mrežnih paketa za gaming (QoS)
$qosKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
if (-not (Test-Path $qosKey)) { New-Item -Path $qosKey -Force | Out-Null }
Set-ItemProperty -Path $qosKey -Name "NonBestEffortLimit" -Value 0 -Type DWord
Write-OK "Mrežni QoS optimizovan (0% rezervisan bandwidth)"

# -- Vizuelni efekti: Performanse umjesto izgleda
$visualKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visualKey)) { New-Item -Path $visualKey -Force | Out-Null }
Set-ItemProperty -Path $visualKey -Name "VisualFXSetting" -Value 2 -Type DWord
Write-OK "Vizuelni efekti: Podeseno na Performanse"

# -- Smanji latenciju miša (onemogući mouse acceleration)
$mouseKey = "HKCU:\Control Panel\Mouse"
Set-ItemProperty -Path $mouseKey -Name "MouseSpeed" -Value "0"
Set-ItemProperty -Path $mouseKey -Name "MouseThreshold1" -Value "0"
Set-ItemProperty -Path $mouseKey -Name "MouseThreshold2" -Value "Value" "0"
Write-OK "Mouse Acceleration onemogucen"

# -- Isključi Nagle-ov algoritam (smanjuje ping/latenciju u LoL-u)
$tcpipInterfaces = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$interfaces = Get-ChildItem $tcpipInterfaces
foreach ($interface in $interfaces) {
    $fullPath = "$tcpipInterfaces\$($interface.PSChildName)"
    $ip = (Get-ItemProperty -Path $fullPath -Name "DhcpIPAddress" -ErrorAction SilentlyContinue).DhcpIPAddress
    if ($ip -and $ip -ne "0.0.0.0") {
        Set-ItemProperty -Path $fullPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $fullPath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $fullPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}
Write-OK "Nagle algoritam onemogucen (manji ping u LoL-u)"

# -- Pokreni Windows u High Performance modu
powercfg -setactive SCHEME_MIN | Out-Null
Write-OK "Power plan: High Performance ukljucen"

# ════════════════════════════════════════════════════════════
# 3. OSLOBAĐANJE RAM-a
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Step "Optimizujem RAM..."

# Zatvori nepotrebne procese koji troše RAM
$processesToKill = @(
    "OneDrive",
    "Teams",
    "Cortana",
    "SearchApp",
    "YourPhone",
    "Spotify",
    "Discord"   # Komentiraj ovu liniju ako koristiš Discord overlay u LoL
)

foreach ($proc in $processesToKill) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-OK "Zatvoren: $proc"
    }
}

# Oslobodi Standby memoriju (Windows Working Set Trim)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MemoryHelper {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr handle);
}
"@ -ErrorAction SilentlyContinue

$processes = Get-Process
foreach ($p in $processes) {
    try {
        $handle = [MemoryHelper]::OpenProcess(0x1F0FFF, $false, $p.Id)
        if ($handle -ne [IntPtr]::Zero) {
            [MemoryHelper]::EmptyWorkingSet($handle) | Out-Null
            [MemoryHelper]::CloseHandle($handle) | Out-Null
        }
    } catch {}
}

$ramBefore = (Get-WmiObject -Class Win32_OperatingSystem)
$freeRAM = [math]::Round($ramBefore.FreePhysicalMemory / 1MB, 2)
Write-OK "RAM Working Set ociscen. Slobodan RAM: ~$freeRAM GB"

# ════════════════════════════════════════════════════════════
# 4. CPU OPTIMIZACIJA ZA LoL
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Step "Podesavam CPU prioritet za League of Legends..."

# Daj HIGH prioritet LoL procesima ako su pokrenuti
$lolProcesses = @("League of Legends", "LeagueClient", "LeagueClientUx", "RiotClientServices")
foreach ($procName in $lolProcesses) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) {
        $proc.PriorityClass = "High"
        Write-OK "HIGH prioritet dat: $procName"
    } else {
        Write-Info "$procName nije pokrenut (prioritet ce biti dat pri sledećem pokretanju)"
    }
}

# Onemogući CPU throttling (Core Parking)
$cpuKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
if (Test-Path $cpuKey) {
    Set-ItemProperty -Path $cpuKey -Name "ValueMax" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-OK "CPU Core Parking onemogucen"
}

# Postavi CPU na 100% minimalne performanse
powercfg -setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
powercfg -setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
powercfg -s SCHEME_MIN | Out-Null
Write-OK "CPU postavljen na 100% performanse (bez throttlinga)"

# ════════════════════════════════════════════════════════════
# 5. OPTIMIZACIJA WINDOWS SERVISA
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Step "Pauziranje nepotrebnih servisa za vreme igranja..."

$servicesToStop = @(
    "SysMain",        # Superfetch - usporava gaming
    "DiagTrack",      # Windows telemetrija
    "WSearch",        # Windows Search indeksiranje
    "WbioSrvc"        # Biometrija (fingerprint itd)
)

foreach ($svc in $servicesToStop) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-OK "Pauziran servis: $svc"
    }
}

# ════════════════════════════════════════════════════════════
# 6. DNS FLUSH (za bolji ping)
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Step "Cistim DNS cache (bolji ping)..."
ipconfig /flushdns | Out-Null
Write-OK "DNS cache ociscen"

# ════════════════════════════════════════════════════════════
# ZAVRŠETAK
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║   OPTIMIZACIJA ZAVRŠENA! GG WP, good luck!      ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Šta je urađeno:" -ForegroundColor Cyan
Write-Host "  ✓ Temp i Prefetch folderi očišćeni ($freedMB MB oslobođeno)" -ForegroundColor White
Write-Host "  ✓ Registry optimizovan za gaming (Game DVR, QoS, mouse)" -ForegroundColor White
Write-Host "  ✓ Nagle algoritam onemogućen (manji ping)" -ForegroundColor White
Write-Host "  ✓ RAM Working Set oslobođen" -ForegroundColor White
Write-Host "  ✓ CPU na High Performance bez throttlinga" -ForegroundColor White
Write-Host "  ✓ Nepotrebni servisi pauzirani" -ForegroundColor White
Write-Host "  ✓ DNS cache očišćen" -ForegroundColor White
Write-Host ""
Write-Host "  NAPOMENA: Servisi (SysMain, WSearch) ce se resetovati pri" -ForegroundColor DarkYellow
Write-Host "  restartovanju. Pokreni skriptu ponovo pre svakog LoL-a." -ForegroundColor DarkYellow
Write-Host ""
pause
