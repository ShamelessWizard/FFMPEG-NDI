# apply-patch-windows.ps1
# Applies libndi.patch to the FFmpeg source using patch with fuzz tolerance.
# More robust than git am against FFmpeg master context drift.
#
# Run from the FFmpeg source directory:
#   ..\FFMPEG-NDI\apply-patch-windows.ps1

$ErrorActionPreference = "Stop"

$MSYS2_DIR = "C:\msys64"
$BASH      = "$MSYS2_DIR\usr\bin\bash.exe"
$PATCH     = Join-Path $PSScriptRoot "libndi.patch"

if (-not (Test-Path $BASH)) {
    Write-Error "MSYS2 not found at $BASH`nInstall from https://www.msys2.org/ or: winget install -e --id MSYS2.MSYS2"
}
if (-not (Test-Path $PATCH)) {
    Write-Error "libndi.patch not found at $PATCH"
}

function To-Posix($p) {
    $p = $p.Replace([char]92, [char]47)
    return '/' + $p.Substring(0,1).ToLower() + $p.Substring(2)
}

$srcPosix   = To-Posix ($PWD.Path)
$patchPosix = To-Posix $PATCH

# Files created new by the patch (not in FFmpeg git — just delete them)
$newFiles = @(
    "libavdevice\libndi_newtek_common.h",
    "libavdevice\libndi_newtek_dec.c",
    "libavdevice\libndi_newtek_enc.c"
)

# Files modified by the patch (restore via git checkout)
$modFiles = @(
    "configure",
    "libavdevice/alldevices.c",
    "libavdevice/Makefile",
    "doc/indevs.texi",
    "doc/outdevs.texi"
)

if (Test-Path "libavdevice\libndi_newtek_dec.c") {
    Write-Host "[INFO] Previous patch application detected — cleaning up before re-applying..."
    foreach ($f in $newFiles) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Host "[INFO]   Removed $f" }
    }
    $env:MSYSTEM = "MINGW64"
    & $BASH --login -c "cd '$srcPosix' && git checkout -- $($modFiles -join ' ')"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] git checkout failed. Ensure you are running from the FFmpeg git repo root."
        exit 1
    }
    Write-Host "[INFO] Cleanup complete."
}

Write-Host "[INFO] Applying libndi.patch to $PWD ..."
$env:MSYSTEM = "MINGW64"
& $BASH --login -c "cd '$srcPosix' && patch -p1 --fuzz=5 < '$patchPosix'"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] patch failed. Check output above for rejected hunks."
    Write-Host "        Rejected hunks will be saved as *.rej files."
    exit 1
}

Write-Host ""
Write-Host "Patch applied successfully. Run build-windows.ps1 to build."
