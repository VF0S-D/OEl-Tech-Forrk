# Install Qt 6.11.0 (msvc2022_64) for the RPCS3 build.
# Uses RPCS3 CI's direct dated-URL pattern because aqtinstall's Updates.xml
# index lags behind the mirror by weeks for newly-released Qt versions.
# Match the version + date to SRC/GIT/rpcs3/.github/workflows/rpcs3.yml.
# Safe to re-run; skips if Qt is already extracted.

# Pinned versions. Bump these to update.
$QtVer    = "6.11.0"
$QtUrlVer = "6110"                           # QtVer with dots removed
$QtDate   = "202603180535"                   # exact mirror build timestamp from upstream CI
$QtMsvc   = "msvc2022"
$QtMsvcUp = "MSVC2022"
$QtHost   = "http://qt.mirror.constant.com"

$ErrorActionPreference = "Stop"

$QtTarget = "C:\Qt\$QtVer\${QtMsvc}_64"
if (Test-Path "$QtTarget\bin\qmake.exe") {
    Write-Host "Qt $QtVer already installed at $QtTarget, skipping." -ForegroundColor DarkGray
    [Environment]::SetEnvironmentVariable("QTDIR", $QtTarget, "Machine")
    return
}

$QtPrefix  = "$QtHost/online/qtsdkrepository/windows_x86/desktop/qt6_$QtUrlVer/qt6_${QtUrlVer}_${QtMsvc}_64/qt.qt6.$QtUrlVer."
$QtPrefix2 = "win64_${QtMsvc}_64/$QtVer-0-$QtDate"
$QtSuffix  = "-Windows-Windows_11_24H2-${QtMsvcUp}-Windows-Windows_11_24H2-X86_64.7z"

$modules = @(
    @{ name = "qtbase";         url = "${QtPrefix}${QtPrefix2}qtbase${QtSuffix}" },
    @{ name = "qtdeclarative";  url = "${QtPrefix}${QtPrefix2}qtdeclarative${QtSuffix}" },
    @{ name = "qttools";        url = "${QtPrefix}${QtPrefix2}qttools${QtSuffix}" },
    @{ name = "qtmultimedia";   url = "${QtPrefix}addons.qtmultimedia.${QtPrefix2}qtmultimedia${QtSuffix}" },
    @{ name = "qtsvg";          url = "${QtPrefix}${QtPrefix2}qtsvg${QtSuffix}" },
    @{ name = "qttranslations"; url = "${QtPrefix}${QtPrefix2}qttranslations${QtSuffix}" }
)

$workDir = "$env:TEMP\qt-install"
New-Item -ItemType Directory -Force -Path $workDir  | Out-Null
New-Item -ItemType Directory -Force -Path $QtTarget | Out-Null

$sevenZ = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $sevenZ)) { throw "7-Zip not found at $sevenZ" }

$ProgressPreference = 'SilentlyContinue'

# The .7z archives contain bin/, lib/, include/ at their root, so they extract
# straight into the versioned msvc2022_64 directory (matching RPCS3 CI behavior).
foreach ($mod in $modules) {
    $file = Join-Path $workDir "$($mod.name).7z"
    Write-Host "Downloading $($mod.name)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $mod.url -OutFile $file
    Write-Host "Extracting $($mod.name)..." -ForegroundColor Cyan
    & $sevenZ x $file "-o$QtTarget" -y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7z extraction failed for $($mod.name)" }
}

Write-Host ""
Write-Host "Qt $QtVer installed to $QtTarget" -ForegroundColor Green
Get-ChildItem "$QtTarget\bin" | Select-Object -First 5

[Environment]::SetEnvironmentVariable("QTDIR", $QtTarget, "Machine")
Write-Host "QTDIR set (machine scope). Open a new shell for it to propagate." -ForegroundColor Green
