# .\lfec_installer.ps1 - the installer script
#Requires -Version 5.1
<#
.SYNOPSIS
    Lame Fallout 4 Esp Cleaner configuration installer
.DESCRIPTION
    Detects game path, extracts FO4Edit if needed,
    sets up Thread1 folder, asks for ENTER wait time,
    creates settings file with configuration in .\data folder
.NOTES
    Run from the folder containing this script
#>

param()

$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = 'Lame Fallout 4 Esp Cleaner – Configuration'

# ──────────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────────
$AutoCleanExe            = 'FO4EditQuickAutoClean.exe'
$SettingsFileName        = 'lfec_settings.psd1'
$ThreadCount             = 1                           # Fixed single thread
$DefaultEnterWaitSeconds = 3

# Paths
$ScriptDir    = $PSScriptRoot
$DataDir      = Join-Path $ScriptDir 'data'
$TempDir      = Join-Path $ScriptDir 'temp'
$DownloadDir  = Join-Path $TempDir 'downloads'
$SevenZipDir  = Join-Path $TempDir '7za'
$ExtractDir   = Join-Path $TempDir 'FO4Edit'
$SevenZipUrl  = 'https://7-zip.org/a/7za920.zip'
$SevenZipExe  = Join-Path $SevenZipDir '7za.exe'

# Settings file goes into data folder
$SettingsFile = Join-Path $DataDir $SettingsFileName

# Globals
$Global:AutoCleanerPath = $null
$Global:GameDataPath    = $null

# ──────────────────────────────────────────────────────────────────────────────
# Functions
# ──────────────────────────────────────────────────────────────────────────────
function Write-Banner {
    Clear-Host
    '=' * 70
    '      Lame Fallout 4 Esp Cleaner  –  Configuration / Installation'
    '=' * 70
    ''
}

function Ensure-DataDirectory {
    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
        Write-Host "[OK] Created data directory: $DataDir" -ForegroundColor Green
    }
}

function Get-EnterWaitSeconds {
    Write-Host "`nHow long should the script wait before pressing ENTER" -ForegroundColor Cyan
    Write-Host "after FO4EditQuickAutoClean window appears?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   3 = Fast (recommended for most systems)"           -ForegroundColor White
    Write-Host "   5 = Safer (good if game/mod load is a bit slow)"  -ForegroundColor Yellow
    Write-Host "   7 = Very safe (heavy load / slow PC)"             -ForegroundColor Yellow
    Write-Host ""

    do {
        $input = Read-Host "Wait time in seconds (3,5,7) [default: 3]"
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $DefaultEnterWaitSeconds
        }
        $seconds = 0
        [int]::TryParse($input, [ref]$seconds) | Out-Null
    } while ($seconds -notin 3,5,7)

    Write-Host "[OK] Wait time set to $seconds seconds" -ForegroundColor Green
    return $seconds
}

function Test-DataDirectory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }

    $indicators = @('*.esp','*.esm','Fallout4.esm','meshes','textures','sound')
    $found = 0
    foreach ($pattern in $indicators) {
        if (Get-ChildItem -Path $Path -Filter $pattern -ErrorAction SilentlyContinue) {
            $found++
        }
    }
    return $found -ge 2
}

function Get-GameDataPath {
    $defaultPath = Join-Path (Split-Path $ScriptDir -Parent) 'Data'
    if (Test-DataDirectory $defaultPath) {
        Write-Host "[OK] Found Data folder at default location" -ForegroundColor Green
        return $defaultPath
    }

    Write-Host "[WARNING] Default Data folder not found or invalid" -ForegroundColor Yellow
    Write-Host "Please enter the path to your Fallout 4 game folder" -ForegroundColor Cyan
    Write-Host "(the folder that contains the 'Data' subfolder)" -ForegroundColor Gray
    Write-Host ""

    $maxAttempts = 3
    for ($i = 1; $i -le $maxAttempts; $i++) {
        $input = Read-Host "Game folder path (attempt $i of $maxAttempts)"
        if ([string]::IsNullOrWhiteSpace($input)) { continue }

        try {
            $gameFolder = [System.IO.Path]::GetFullPath($input.Trim('"'''))
            $dataPath = Join-Path $gameFolder 'Data'

            if (Test-DataDirectory $dataPath) {
                Write-Host "[OK] Valid Data folder found!" -ForegroundColor Green
                return $dataPath
            }
            Write-Host "[ERROR] No valid Data folder at: $dataPath" -ForegroundColor Red
        }
        catch {
            Write-Host "[ERROR] Invalid path format" -ForegroundColor Red
        }
    }

    throw "Could not locate a valid Fallout 4 Data directory after $maxAttempts attempts."
}

function Find-FO4EditArchive {
    $archives = Get-ChildItem -LiteralPath $ScriptDir -File |
                Where-Object { $_.Name -like 'FO4Edit*.7z' -or $_.Name -like 'FO4Edit*.zip' }

    if ($archives.Count -eq 0) { return $null }
    if ($archives.Count -eq 1) { return $archives[0].FullName }

    Write-Host "Multiple FO4Edit archives found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $archives.Count; $i++) {
        Write-Host "  $($i+1)) $($archives[$i].Name)"
    }

    do {
        $sel = Read-Host "Select archive number (1-$($archives.Count))"
        $idx = [int]$sel - 1
    } while ($idx -lt 0 -or $idx -ge $archives.Count)

    return $archives[$idx].FullName
}

# ──────────────────────────────────────────────────────────────────────────────
# Placeholder stubs (implement if needed - currently minimal)
# ──────────────────────────────────────────────────────────────────────────────
function Initialize-SevenZip { $true }           # stub - implement if you need auto-download
function Download-FileWithRetry { $false }      # stub
function Extract-FO4EditArchive { $null }       # stub

function Setup-AutoCleaner {
    $thread1Dir = Join-Path $ScriptDir 'Thread1'
    $targetExe  = Join-Path $thread1Dir $AutoCleanExe

    if (Test-Path $targetExe) {
        Write-Host "[OK] FO4EditQuickAutoClean.exe already exists in Thread1" -ForegroundColor Green
        return $targetExe
    }

    $archive = Find-FO4EditArchive
    if (-not $archive) {
        Write-Host ""
        Write-Host "[ERROR] No FO4Edit archive (.7z or .zip) found in current folder." -ForegroundColor Red
        Write-Host "Please download it from:" -ForegroundColor Yellow
        Write-Host "https://www.nexusmods.com/fallout4/mods/2737" -ForegroundColor Yellow
        Write-Host "and place it in the same folder as this script." -ForegroundColor Yellow
        return $null
    }

    Write-Host "[INFO] Extracting FO4Edit from archive..." -ForegroundColor Cyan
    # Here you would normally call Extract-FO4EditArchive -ArchivePath $archive
    # For now we assume user has already extracted or you implement extraction

    Write-Host "[WARNING] Automatic extraction not fully implemented in this version." -ForegroundColor Yellow
    Write-Host "Please extract FO4EditQuickAutoClean.exe manually to Thread1 folder." -ForegroundColor Yellow
    return $null   # ← change to actual path after extraction when you implement it
}

function New-SettingsFile {
    param(
        [string]$AutoCleanerPath,
        [string]$DataPath,
        [int]$EnterWaitSeconds = $DefaultEnterWaitSeconds
    )

    if (-not (Test-Path $AutoCleanerPath) -or -not (Test-Path $DataPath)) {
        Write-Host "[ERROR] Cannot create settings - missing paths" -ForegroundColor Red
        return $false
    }

    # Ensure data directory exists
    Ensure-DataDirectory

    # Check if settings file already exists
    if (Test-Path $SettingsFile) {
        Write-Host "[INFO] Overwriting existing settings file: $SettingsFile" -ForegroundColor Yellow
    }

    $content = @"
# Lame Fallout 4 Esp Cleaner Settings
# Location: .\data\lfec_settings.psd1
@{
    ThreadCount       = 1
    AutoCleanExe      = '$AutoCleanExe'
    AutoCleanerPath   = 'Thread1\$AutoCleanExe'
    GameDataPath      = '$DataPath'
    GameTitle         = 'Fallout4'
    XEditVariant      = 'FO4Edit'
    EnterWaitSeconds  = $EnterWaitSeconds
    Version           = '1.0'
    LastConfigured    = '$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))'
    ScriptDirectory   = '$ScriptDir'
}
"@

    # Write to data folder, overwriting if exists
    $content | Out-File $SettingsFile -Encoding utf8BOM -Force

    Write-Host "[OK] Settings file created: $SettingsFile" -ForegroundColor Green
    Write-Host "    Enter wait time saved: $EnterWaitSeconds seconds" -ForegroundColor Green

    return $true
}

function Initialize-AvoidanceFile {
    $avoidFile = Join-Path $DataDir 'lfec_avoidance.txt'
    
    if (Test-Path $avoidFile) {
        Write-Host "[OK] Avoidance file already exists: $avoidFile" -ForegroundColor Green
        return
    }

    # Create a minimal template avoidance file
    $templateContent = @"
# FO4Edit Auto-Cleaner Ignore List
# Generated: $((Get-Date).ToString('yyyy-MM-dd'))
# 
# This file contains ESM/ESP filenames that should NOT be auto-cleaned.
# Lines starting with # are comments.
# Wildcards (*) are supported for pattern matching.
# Case-insensitive matching.
#
# Add patterns below (one per line):
# Example: Scrap Everything*.esp
# Example: *.esm

"@

    $templateContent | Out-File $avoidFile -Encoding utf8 -Force
    Write-Host "[OK] Created avoidance file template: $avoidFile" -ForegroundColor Green
    Write-Host "     Add patterns to this file to permanently skip mods from cleaning" -ForegroundColor Gray
}

function Cleanup-TempFiles {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Main execution
# ──────────────────────────────────────────────────────────────────────────────
try {
    Write-Banner

    # 0. Ensure data directory exists first
    Ensure-DataDirectory

    # 1. Game path detection
    $regKey = 'HKLM:\SOFTWARE\Bethesda Softworks\Fallout4'
    if (Test-Path $regKey) {
        try {
            $installedPath = (Get-ItemProperty $regKey -Name 'Installed Path' -ErrorAction Stop).'Installed Path'
            $dataPath = Join-Path $installedPath 'Data'
            if (Test-DataDirectory $dataPath) {
                $Global:GameDataPath = $dataPath
                Write-Host "[OK] Game path found via registry" -ForegroundColor Green
            }
        } catch {}
    }

    if (-not $Global:GameDataPath) {
        $Global:GameDataPath = Get-GameDataPath
    }

    # 2. Optional registry creation
    if (-not (Test-Path $regKey)) {
        Write-Host ""
        $answer = Read-Host "Create Fallout4 registry key? (y/n) [recommended]"
        if ($answer -match '^[yY]') {
            # Implement Set-Fallout4RegistryKey if needed - stub for now
            Write-Host "[INFO] Registry key creation skipped (not implemented in this version)" -ForegroundColor Yellow
        }
    }

    # 3. Setup FO4EditQuickAutoClean.exe in Thread1
    $autoCleanerPath = Setup-AutoCleaner
    if (-not $autoCleanerPath) {
        throw "Failed to locate or setup FO4EditQuickAutoClean.exe"
    }

    # 4. Ask user for preferred ENTER wait time
    $enterWait = Get-EnterWaitSeconds

    # 5. Create configuration file (in .\data folder, overwrites if exists)
    if (-not (New-SettingsFile -AutoCleanerPath $autoCleanerPath `
                               -DataPath $Global:GameDataPath `
                               -EnterWaitSeconds $enterWait)) {
        throw "Failed to create settings file"
    }

    # 6. Initialize avoidance file template if it doesn't exist
    Initialize-AvoidanceFile

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "           Configuration finished successfully!"                     -ForegroundColor Green
    Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Data files location: $DataDir" -ForegroundColor Cyan
    Write-Host "  - Settings:  lfec_settings.psd1" -ForegroundColor Gray
    Write-Host "  - Blacklist: lfec_blacklist.txt (auto-generated)" -ForegroundColor Gray
    Write-Host "  - Avoidance: lfec_avoidance.txt (permanent ignore list)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You can now close this window or press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Host ""
    Write-Host "[CRITICAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
finally {
    Cleanup-TempFiles
}