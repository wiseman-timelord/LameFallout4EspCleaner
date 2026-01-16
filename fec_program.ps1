# Updated fec_program.ps1 - Task Queue Version with PSD1 Integration
#Requires -Version 5.1
# Lame Fallout 4 Esp Cleaner - Single-Thread Version with PSD1 Integration

# Constants
$DaysSkip = 7
$ScriptDir = $PSScriptRoot
$TempDir = "$ScriptDir\temp"
$BlackFile = "$ScriptDir\lfec_blacklist.txt"
$ErrorFile = "$ScriptDir\lfec_errorlist.txt"
$SettingsFile = "$ScriptDir\lfec_settings.psd1"

# Settings variables
$AutoCleanExe = 'FO4EditQuickAutoClean.exe'
$GameTitle = 'Fallout4'
$XEditVariant = 'FO4Edit'
$GameDataPath = $null
$ScriptDirectory = $null

# Load settings
function Load-Settings {
    if (-not (Test-Path $SettingsFile)) {
        Write-Host "[ERROR] Run configuration first: $SettingsFile missing" -ForegroundColor Red
        return $false
    }
    
    $settings = Import-PowerShellDataFile $SettingsFile
    $script:AutoCleanExe = $settings.AutoCleanExe
    $script:GameTitle = $settings.GameTitle
    $script:XEditVariant = $settings.XEditVariant
    $script:GameDataPath = $settings.GameDataPath
    $script:ScriptDirectory = $settings.ScriptDirectory
    
    Write-Host "[OK] Loaded settings. Data Path: $GameDataPath" -ForegroundColor Green
    return $true
}

# Add assemblies for SendKeys and window handling
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
    }
"@

# Functions
function Write-Separator {
    Write-Host ('=' * 79)
}

function CleanOld {
    if (-not (Test-Path $BlackFile)) { return }
    $cut = (Get-Date).AddDays(-$DaysSkip).ToString('yyyy-MM-dd')
    (Get-Content $BlackFile) | Where-Object { $_ -match '^(\d{4}-\d{2}-\d{2})' -and $matches[1] -ge $cut } | Set-Content $BlackFile
}

function PreventSleep($on) {
    # (Kept as-is)
}

function Clean($esp) {
    $CleanerExe = "$ScriptDir\Thread1\$AutoCleanExe"
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $CleanerExe
        $psi.Arguments = "-iknowwhatimdoing -quickautoclean -autoexit -DontCache -D:`"$GameDataPath`" `"$esp`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $false
        $psi.WorkingDirectory = Split-Path $CleanerExe -Parent

        Write-Host "Launching for: $(Split-Path $esp -Leaf)" -ForegroundColor Cyan
        $p = [System.Diagnostics.Process]::Start($psi)

        # Wait 3s, then send ENTER once
        Start-Sleep -Seconds 3
        try {
            [Microsoft.VisualBasic.Interaction]::AppActivate($p.Id)
        } catch {
            $fg = [Win32]::GetForegroundWindow()
            if ($fg -ne [IntPtr]::Zero) { [Win32]::SetForegroundWindow($fg) }
        }
        Start-Sleep -Milliseconds 500
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Write-Host "Sent ENTER after 3s" -ForegroundColor Gray

        # Wait for exit
        $p.WaitForExit(1800000)  # 30min timeout
        if (-not $p.HasExited) {
            $p.Kill()
            Write-Host "TIMEOUT - Killed process" -ForegroundColor Red
            return $false
        }

        return ($p.ExitCode -eq 0)
    } catch {
        Write-Host "EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function AddLog($file, $ok) {
    "$(Get-Date -f 'yyyy-MM-dd')`t$file`t$ok" | Add-Content $BlackFile -Encoding utf8
}

function AddError($file) {
    "$(Get-Date -f 'yyyy-MM-dd')`t$file" | Add-Content $ErrorFile -Encoding utf8
}

# Main
Clear-Host
Write-Separator
Write-Host "    Lame Fallout 4 Esp Cleaner (Single-Thread)" -ForegroundColor Cyan
Write-Separator

if (-not (Load-Settings)) { exit 1 }

CleanOld
Write-Host "[OK] Blacklist cleaned" -ForegroundColor Green

if (-not (Test-Path $GameDataPath)) {
    Write-Host "[ERROR] Data path invalid: $GameDataPath" -ForegroundColor Red
    exit 1
}

$esps = Get-ChildItem "$GameDataPath\*.esp"
if (-not $esps) {
    Write-Host "[ERROR] No ESPs found" -ForegroundColor Red
    exit 0
}

$black = @{}
if (Test-Path $BlackFile) {
    Get-Content $BlackFile | ForEach-Object {
        if ($_ -match '^(\d{4}-\d{2}-\d{2})\t([^\t]+)\t') {
            $black[$matches[2]] = [DateTime]::ParseExact($matches[1], 'yyyy-MM-dd', $null)
        }
    }
}

$cut = (Get-Date).AddDays(-$DaysSkip)
$todo = $esps | Where-Object { -not $black.ContainsKey($_.Name) -or $black[$_.Name] -lt $cut }

if (-not $todo) {
    Write-Host "[INFO] All ESPs skipped" -ForegroundColor Cyan
    exit 0
}

Write-Host "[OK] Processing $($todo.Count) ESPs (skipped $($esps.Count - $todo.Count))" -ForegroundColor Green

PreventSleep $true
try {
    $successful = 0
    $failed = 0
    
    foreach ($esp in $todo) {
        $name = $esp.Name
        if (-not (Test-Path $esp.FullName)) {
            Write-Host "MISSING: $name" -ForegroundColor Yellow
            $failed++
            continue
        }
        
        $ok = Clean $esp.FullName
        if ($ok) {
            Write-Host "SUCCESS: $name" -ForegroundColor Green
            $successful++
        } else {
            Write-Host "FAILED: $name" -ForegroundColor Red
            AddError $name
            $failed++
        }
        
        AddLog $name $ok
    }
    
    Write-Host "`nResults: $successful successful, $failed failed" -ForegroundColor Green
} finally {
    PreventSleep $false
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit 0