# build-windows.ps1
# Run from the FFmpeg source directory:
#  ..\FFMPEG-NDI\build-windows.ps1
#
# Options:
#   -DistClean    Run make distclean and exit (no build)

param(
    [switch]$DistClean
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
$MSYS2_DIR    = "C:\msys64"
$BASH         = "$MSYS2_DIR\usr\bin\bash.exe"
$NDI_SDK      = "C:\Program Files\NDI\NDI 6 SDK"
$NDI_INCLUDE  = "$NDI_SDK\Include"
$NDI_DLL_DIR  = "$NDI_SDK\Bin\x64"
$NDI_DLL_NAME = "Processing.NDI.Lib.x64.dll"
$WORK         = "$env:TEMP\ffmpeg-ndi-build"
$BUILD_SH     = Join-Path $PSScriptRoot "configure-and-compile-windows.sh"

# ---------------------------------------------------------------
# Validation
# ---------------------------------------------------------------
if (-not (Test-Path $BASH)) {
    Write-Error "MSYS2 not found at $BASH`nInstall from https://www.msys2.org/ or: winget install -e --id MSYS2.MSYS2"
}
if (-not (Test-Path "$NDI_INCLUDE\Processing.NDI.Lib.h")) {
    Write-Error "NDI SDK header not found: $NDI_INCLUDE\Processing.NDI.Lib.h`nInstall NDI 6 SDK from https://ndi.video/for-developers/ndi-sdk/"
}
if (-not (Test-Path "$NDI_DLL_DIR\$NDI_DLL_NAME")) {
    Write-Error "NDI DLL not found: $NDI_DLL_DIR\$NDI_DLL_NAME"
}
if (-not (Test-Path $BUILD_SH)) {
    Write-Error "configure-and-compile-windows.sh not found at $BUILD_SH`nEnsure it is in the same directory as this script."
}

New-Item -ItemType Directory -Force -Path $WORK | Out-Null

Write-Host "[INFO] NDI SDK : $NDI_SDK"
Write-Host "[INFO] MSYS2   : $MSYS2_DIR"
Write-Host "[INFO] Source  : $PWD"
Write-Host ""

# ---------------------------------------------------------------
# Convert a Windows path to a POSIX path for bash
# e.g. C:\git\ffmpeg -> /c/git/ffmpeg
# ---------------------------------------------------------------
function To-Posix($p) {
    $p = $p.Replace([char]92, [char]47)
    return '/' + $p.Substring(0,1).ToLower() + $p.Substring(2)
}

$ndlInc   = To-Posix $NDI_INCLUDE
$ndlDll   = To-Posix ($NDI_DLL_DIR + '\' + $NDI_DLL_NAME)
$srcPosix = To-Posix ($PWD.Path)
$wrkPosix = To-Posix $WORK
$shPosix  = To-Posix $BUILD_SH

# ---------------------------------------------------------------
# DistClean mode - run make distclean and exit
# ---------------------------------------------------------------
if ($DistClean) {
    Write-Host "[INFO] Running make distclean in $PWD ..."
    $env:MSYSTEM = "MINGW64"
    $src = To-Posix ($PWD.Path)
    & $BASH --login -c "cd '$src' && make distclean 2>/dev/null; echo Done"
    Write-Host ""
    Write-Host "Clean. Run ..\FFMPEG-NDI\build-windows.ps1 to reconfigure and build."
    exit 0
}

# ---------------------------------------------------------------
# Strip CRLF from the shell script
# ---------------------------------------------------------------
& $BASH --login -c "dos2unix '$shPosix' 2>/dev/null || sed -i 's/\r//' '$shPosix'"

# ---------------------------------------------------------------
# Write a wrapper that exports all variables then execs the build
# ---------------------------------------------------------------
$wrapperLines = @(
    "#!/bin/bash",
    "export MSYSTEM=MINGW64",
    "export PATH=/mingw64/bin:/usr/bin:/bin:`$PATH",
    "source /etc/profile",
    "export NDI_INCLUDE_WIN='$ndlInc'",
    "export NDI_DLL_WIN='$ndlDll'",
    "export FFMPEG_SRC_WIN='$srcPosix'",
    "export WORK_WIN='$wrkPosix'",
    "exec bash '$shPosix'"
)

$wrapperFile  = Join-Path $WORK "run-build.sh"
$wrapperPosix = To-Posix $wrapperFile
[System.IO.File]::WriteAllText($wrapperFile, ($wrapperLines -join "`n") + "`n")

# ---------------------------------------------------------------
# Launch the build
# ---------------------------------------------------------------
Write-Host "[INFO] Launching MSYS2 MinGW64 build shell..."
$env:MSYSTEM = "MINGW64"
& $BASH --login $wrapperPosix
$exit = $LASTEXITCODE

if ($exit -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Build failed (exit code $exit)."
    Write-Host "        FFmpeg configure log: $PWD\ffbuild\config.log"
    exit $exit
}

$latestDist = Get-ChildItem -Path "$PWD\dist" -Directory -Filter "ffmpeg-ndi-*" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host ""
Write-Host "=========================================="
Write-Host " FFmpeg + NDI 6 build complete!"
if ($latestDist) {
    Write-Host " Output: $($latestDist.FullName)\"
} else {
    Write-Host " Output: $PWD\dist\ffmpeg-ndi-<timestamp>\"
}
Write-Host "=========================================="
Write-Host ""
Write-Host "Quick test:"
if ($latestDist) {
    Write-Host "  cd $($latestDist.FullName)"
} else {
    Write-Host "  cd $PWD\dist\ffmpeg-ndi-<timestamp>"
}
Write-Host "  .\ffmpeg.exe -f libndi_newtek -find_sources 1 -i dummy"
