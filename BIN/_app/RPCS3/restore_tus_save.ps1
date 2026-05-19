# OPERATION ETERNAL LIBERATION — TUS Save Restore
# Run via restore_tus_save.bat (next to rpcs3.exe)
#
# Parameters:
#   -Choice <string>   Non-interactive selection, e.g. "1", "1-4", "1-4,6".
#                      When supplied, skips the interactive menu and exits after staging.

param(
    [string]$Choice = ""
)

# Resolve config dir the same way RPCS3 does:
#   1. <exe_dir>\portable\  if that folder exists
#   2. $env:RPCS3_CONFIG_DIR if set
#   3. <exe_dir>\ otherwise
$exeDir = $PSScriptRoot
if (Test-Path (Join-Path $exeDir 'portable')) {
    $configDir = Join-Path $exeDir 'portable'
} elseif ($env:RPCS3_CONFIG_DIR) {
    $configDir = $env:RPCS3_CONFIG_DIR.TrimEnd('\','/')
} else {
    $configDir = $exeDir
}
$tusRoot = Join-Path $configDir 'tus'

if (-not (Test-Path $tusRoot)) {
    Write-Host ""
    Write-Host "  No TUS backup folder found."
    Write-Host "  Resolved config dir: $configDir"
    Write-Host "  Expected tus folder: $tusRoot"
    Write-Host ""
    Write-Host "  Boot the game at least once so a backup is created."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# Collect all backup files
$files = Get-ChildItem -Path $tusRoot -Recurse -Filter '*.tdt' |
         Where-Object { $_.DirectoryName -like '*\backups' } |
         Sort-Object Name

if ($files.Count -eq 0) {
    Write-Host ""
    Write-Host "  No .tdt backup files found under $tusRoot"
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# Parse each filename: YYYY-MM-DD_HHMMSS_COMMID_<slot20d>.tdt
$entries = foreach ($f in $files) {
    $n = $f.BaseName  # e.g. 2026-05-10_182917_<comm_id>_00000000000000000002
    [PSCustomObject]@{
        Index      = 0
        Date       = $n.Substring(0, 10)
        Time       = "$($n.Substring(11,2)):$($n.Substring(13,2)):$($n.Substring(15,2))"
        Session    = $n.Substring(0, 15)   # YYYY-MM-DD_HHMM — groups files saved in the same minute
        Slot       = $n.Substring($n.Length - 20)
        SizeKB     = [math]::Ceiling($f.Length / 1KB)
        File       = $f.FullName
        SlotDir    = $f.Directory.Parent.FullName
    }
}

# Assign display indices
$i = 1
foreach ($e in $entries) { $e.Index = $i++ }

# Display
Write-Host ""
Write-Host "  ================================================================"
Write-Host "  OPERATION ETERNAL LIBERATION -- TUS Save Backups  ($($entries.Count) file(s))"
Write-Host "  ================================================================"
Write-Host ""
Write-Host ("  {0,-4} {1,-10}  {2,-8}  {3}" -f '#', 'Date', 'Time', 'Slot (20-digit)')
Write-Host ("  {0,-4} {1,-10}  {2,-8}  {3}" -f '----', '----------', '--------', '--------------------')

$lastSession = ''
foreach ($e in $entries) {
    if ($e.Session -ne $lastSession) {
        if ($lastSession -ne '') { Write-Host "" }
        $lastSession = $e.Session
    }
    Write-Host ("  {0,-4} {1,-10}  {2,-8}  {3}  ({4} KB)" -f $e.Index, $e.Date, $e.Time, $e.Slot, $e.SizeKB)
}

Write-Host ""
Write-Host "  ================================================================"
Write-Host ""
Write-Host "  Files grouped by blank lines share the same save minute (one session)."
Write-Host "  Restore all slots from a session to fully revert your progress."
Write-Host ""
if ([string]::IsNullOrWhiteSpace($Choice)) {
    Write-Host "  Enter a single number  (e.g.  3  ) to restore one slot."
    Write-Host "  Enter a range          (e.g.  1-4  ) to restore a full session."
    Write-Host "  Combine with commas    (e.g.  1-4,6) to mix ranges and singles."
    Write-Host "  Press Enter to cancel."
    Write-Host ""
    $Choice = Read-Host "  Choice"
}

if ([string]::IsNullOrWhiteSpace($Choice)) {
    Write-Host "  Cancelled."
    exit 0
}

# Parse comma-separated list of numbers and ranges, e.g. "1,3-5,7"
$selected = [System.Collections.Generic.HashSet[int]]::new()
foreach ($token in $Choice -split ',') {
    $token = $token.Trim()
    if ($token -match '^\d+$') {
        [void]$selected.Add([int]$token)
    } elseif ($token -match '^(\d+)-(\d+)$') {
        $a = [int]$Matches[1]; $b = [int]$Matches[2]
        if ($a -gt $b) { $a, $b = $b, $a }
        $a..$b | ForEach-Object { [void]$selected.Add($_) }
    } else {
        Write-Host "  Invalid token '$token'. Use numbers or ranges like 2-5."
        Read-Host "  Press Enter to exit"
        exit 1
    }
}

$selected = $selected | Where-Object { $_ -ge 1 -and $_ -le $entries.Count } | Sort-Object

if ($selected.Count -eq 0) {
    Write-Host "  No valid indices selected. Cancelled."
    Read-Host "  Press Enter to exit"
    exit 1
}

# Stage restore sentinels
$staged = 0
foreach ($e in $entries[($selected | ForEach-Object { $_ - 1 })]) {
    $sentinel = Join-Path $e.SlotDir "$($e.Slot).tdt.restore"
    try {
        Copy-Item -Path $e.File -Destination $sentinel -Force
        Write-Host "  [OK] Staged slot $($e.Slot)"
        $staged++
    } catch {
        Write-Host "  [FAIL] Could not write: $sentinel"
        Write-Host "         $_"
    }
}

Write-Host ""
if ($staged -gt 0) {
    Write-Host "  ================================================================"
    Write-Host "   $staged slot(s) staged for restore."
    Write-Host ""
    Write-Host "   Steps:"
    Write-Host "     1. Open RPCS3 and start the game."
    Write-Host "     2. Load your save from the in-game menu."
    Write-Host "        RPCS3 will serve the backup automatically (one time only)."
    Write-Host "     3. Save in-game to push the restored data back to RPCN."
    Write-Host "  ================================================================"
} else {
    Write-Host "  No files were staged. Check that the tus\ folder is writable."
}

Write-Host ""
if ($Choice -eq "") { Read-Host "  Press Enter to exit" }
