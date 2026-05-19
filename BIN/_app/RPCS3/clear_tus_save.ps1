# OPERATION ETERNAL LIBERATION — TUS New Game Override
# Places a zero-byte .tdt.restore sentinel for every known slot so the game
# reports "no data" and prompts you to create a new save.
#
# Run via clear_tus_save.bat (next to rpcs3.exe).
#
# The sentinel is consumed on the FIRST GetData call for each slot (one-shot),
# exactly like the backup restore path.  If you want to go back to the cloud
# save afterwards, simply boot the game without running this script.
#
# Parameters:
#   -Confirm    Skip the interactive "Type YES to proceed" prompt and run immediately.

param(
    [switch]$Confirm
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

Write-Host ""
Write-Host "  ================================================================"
Write-Host "  OPERATION ETERNAL LIBERATION -- TUS New Game Override"
Write-Host "  ================================================================"
Write-Host ""

if (-not (Test-Path $tusRoot)) {
    Write-Host "  No TUS folder found."
    Write-Host "  Resolved config dir: $configDir"
    Write-Host "  Expected tus folder: $tusRoot"
    Write-Host ""
    Write-Host "  Boot the game at least once so the tus folder is created."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# Collect all slot IDs that have ever been backed up.
# Backup filename: YYYY-MM-DD_HHMMSS_COMMID_<slot20d>.tdt  (in a 'backups' subfolder)
# We also scan for existing .tdt.restore files so we pick up slots that were
# created by a previous run of this script or the restore script.
$backupFiles  = Get-ChildItem -Path $tusRoot -Recurse -Filter '*.tdt' |
                Where-Object { $_.DirectoryName -like '*\backups' }
$restoreFiles = Get-ChildItem -Path $tusRoot -Recurse -Filter '*.tdt.restore'

if ($backupFiles.Count -eq 0 -and $restoreFiles.Count -eq 0) {
    Write-Host "  No backup or restore files found under:"
    Write-Host "  $tusRoot"
    Write-Host ""
    Write-Host "  There is nothing to override yet."
    Write-Host "  Boot the game at least once so slot data is discovered and backed up."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# Build a deduplicated list of (SlotDir, SlotId) pairs.
# SlotDir = <tusRoot>\<commId>\<npId>   (the directory that holds .tdt.restore files)
$slots = [System.Collections.Generic.List[PSCustomObject]]::new()
$seen  = [System.Collections.Generic.HashSet[string]]::new()

foreach ($f in $backupFiles) {
    # BaseName example: 2026-05-10_182917_<comm_id>_00000000000000000002
    $slotId  = $f.BaseName.Substring($f.BaseName.Length - 20)
    $slotDir = $f.Directory.Parent.FullName   # strip \backups
    $key     = "$slotDir|$slotId"
    if ($seen.Add($key)) {
        $slots.Add([PSCustomObject]@{ SlotDir = $slotDir; SlotId = $slotId })
    }
}

foreach ($f in $restoreFiles) {
    # BaseName example: 00000000000000000002.tdt  (extension already stripped by BaseName)
    # But BaseName strips one extension, so for "foo.tdt.restore" BaseName = "foo.tdt"
    # Strip the remaining .tdt manually.
    $baseName = $f.BaseName -replace '\.tdt$', ''
    if ($baseName -match '^\d{20}$') {
        $slotId  = $baseName
        $slotDir = $f.DirectoryName
        $key     = "$slotDir|$slotId"
        if ($seen.Add($key)) {
            $slots.Add([PSCustomObject]@{ SlotDir = $slotDir; SlotId = $slotId })
        }
    }
}

if ($slots.Count -eq 0) {
    Write-Host "  Could not parse any slot IDs from the discovered files."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

Write-Host "  This will place a zero-byte restore sentinel for $($slots.Count) slot(s)."
Write-Host "  When you next boot the game, each of those slots will"
Write-Host "  report 'no data' and the game will offer to create a new save."
Write-Host ""
Write-Host "  Slots found:"
foreach ($s in $slots) {
    $rel = $s.SlotDir.Replace($tusRoot, '').TrimStart('\','/')
    Write-Host "    [$rel]  slot $($s.SlotId)"
}
Write-Host ""
Write-Host "  WARNING: This does NOT delete your cloud save on RPCN."
Write-Host "  After the game creates a new save and you save in-game, the old"
Write-Host "  cloud data will be overwritten.  Make a backup first if needed."
Write-Host ""
if ($Confirm) {
    $confirmInput = 'YES'
} else {
    $confirmInput = Read-Host "  Type YES to proceed, or press Enter to cancel"
}

if ($confirmInput -ne 'YES') {
    Write-Host "  Cancelled."
    if (-not $Confirm) { Read-Host "  Press Enter to exit" }
    exit 0
}

Write-Host ""
$staged = 0
foreach ($s in $slots) {
    $sentinel = Join-Path $s.SlotDir "$($s.SlotId).tdt.restore"
    try {
        # Zero-byte file — signals "no data" to RPCS3's TUS handler.
        [System.IO.File]::WriteAllBytes($sentinel, [byte[]]@())
        Write-Host "  [OK] $sentinel"
        $staged++
    } catch {
        Write-Host "  [FAIL] Could not write: $sentinel"
        Write-Host "         $_"
    }
}

Write-Host ""
if ($staged -gt 0) {
    Write-Host "  ================================================================"
    Write-Host "   $staged slot(s) staged for new-game override."
    Write-Host ""
    Write-Host "   Steps:"
    Write-Host "     1. Open RPCS3 and start the game."
    Write-Host "     2. The game will see no save data and prompt you to start fresh."
    Write-Host "     3. Play through the intro and save in-game to commit the new save."
    Write-Host "  ================================================================"
} else {
    Write-Host "  No sentinels were written. Check that the tus\ folder is writable."
}

Write-Host ""
if (-not $Confirm) { Read-Host "  Press Enter to exit" }
