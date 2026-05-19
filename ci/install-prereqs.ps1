# Install all RPCS3 / RPCN build prerequisites except Qt.
# Run as Administrator. Reboot recommended after this script finishes
# so the new machine-scope env vars propagate to all sessions.
# Qt is handled separately by install-qt.ps1.
# Safe to re-run; already-installed components are skipped.

# Pinned versions. Bump these to update.
$PythonVer  = "3.12"
$VulkanVer  = "1.4.341.1"                   # must match SRC/GIT/rpcs3/.github/workflows/rpcs3.yml
$VsChannel  = "17"                          # 17 = Visual Studio 2022
$VsWinSdk   = "Microsoft.VisualStudio.Component.Windows11SDK.22621"
$ProtocVer  = "28.3"                        # RPCN build.rs uses prost_build / protoc

$ErrorActionPreference = "Stop"

# 1. winget-installable tools
$wingetPackages = @(
    "Git.Git",
    "7zip.7zip",
    "Kitware.CMake",
    "Python.Python.$PythonVer",
    "Rustlang.Rustup",
    "JRSoftware.InnoSetup",
    "ccache.ccache",
    "StrawberryPerl.StrawberryPerl",         # openssl-src needs Perl to generate OpenSSL config
    "NASM.NASM"                              # openssl-src uses NASM for optimized asm
)
foreach ($pkg in $wingetPackages) {
    $installed = (winget list --id $pkg -e --accept-source-agreements 2>$null | Select-String -Pattern $pkg -Quiet)
    if ($installed) {
        Write-Host "$pkg already installed, skipping." -ForegroundColor DarkGray
        continue
    }
    Write-Host "Installing $pkg..." -ForegroundColor Cyan
    winget install --id $pkg -e --accept-source-agreements --accept-package-agreements
}

# 2. Rust toolchain. Refresh in-process PATH so rustup from the winget step is visible.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")
rustup default stable
rustup target add x86_64-pc-windows-msvc

# 3. Visual Studio Build Tools with C++ workload.
# winget can install the bootstrapper but not select workloads; drive it directly.
# The bootstrapper is idempotent: detects existing install and skips/updates.
$vsUrl  = "https://aka.ms/vs/$VsChannel/release/vs_buildtools.exe"
$vsFile = "$env:TEMP\vs_buildtools.exe"
Write-Host "Downloading VS Build Tools bootstrapper..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $vsUrl -OutFile $vsFile
Write-Host "Installing VS Build Tools (10-15 min, no progress UI)..." -ForegroundColor Cyan
Start-Process -Wait -FilePath $vsFile -ArgumentList @(
    "--quiet", "--wait", "--norestart", "--nocache",
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "--add", $VsWinSdk,
    "--add", "Microsoft.VisualStudio.Component.VC.ATL",
    "--add", "Microsoft.VisualStudio.Component.VC.ATLMFC",
    "--includeRecommended"
)

# 4. protoc. Not on winget reliably; mirror the arduino/setup-protoc behavior by
# pulling the release zip from GitHub directly.
$protocRoot = "C:\protoc"
if (Test-Path "$protocRoot\bin\protoc.exe") {
    Write-Host "protoc $ProtocVer already installed at $protocRoot, skipping." -ForegroundColor DarkGray
} else {
    $protocUrl  = "https://github.com/protocolbuffers/protobuf/releases/download/v$ProtocVer/protoc-$ProtocVer-win64.zip"
    $protocFile = "$env:TEMP\protoc.zip"
    Write-Host "Downloading protoc $ProtocVer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $protocUrl -OutFile $protocFile
    Write-Host "Extracting protoc..." -ForegroundColor Cyan
    Expand-Archive -Path $protocFile -DestinationPath $protocRoot -Force
}
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*$protocRoot\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$machinePath;$protocRoot\bin", "Machine")
}

# 5. Vulkan SDK. LunarG prunes old versions; keep a local copy if you need to redeploy later.
$vulkanRoot = "C:\VulkanSDK\$VulkanVer"
if (Test-Path $vulkanRoot) {
    Write-Host "Vulkan SDK $VulkanVer already installed at $vulkanRoot, skipping." -ForegroundColor DarkGray
} else {
    $vulkanUrl  = "https://sdk.lunarg.com/sdk/download/$VulkanVer/windows/vulkansdk-windows-X64-$VulkanVer.exe"
    $vulkanFile = "$env:TEMP\vulkan-sdk.exe"
    Write-Host "Downloading Vulkan SDK $VulkanVer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $vulkanUrl -OutFile $vulkanFile
    Write-Host "Installing Vulkan SDK..." -ForegroundColor Cyan
    Start-Process -Wait -FilePath $vulkanFile -ArgumentList @(
        "--accept-licenses", "--default-answer", "--confirm-command", "install"
    )
}
[Environment]::SetEnvironmentVariable("VULKAN_SDK", $vulkanRoot, "Machine")

Write-Host ""
Write-Host "Prereqs installed. Next: ci\install-qt.ps1" -ForegroundColor Green
Write-Host "Reboot recommended so VULKAN_SDK + PATH propagate to all sessions." -ForegroundColor Yellow
