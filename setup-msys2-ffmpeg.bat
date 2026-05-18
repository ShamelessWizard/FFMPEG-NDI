@echo off
:: ============================================================
:: setup-msys2-ffmpeg.bat
:: Installs all MSYS2/MinGW-w64 packages needed to build
:: FFmpeg with NDI 6 SDK support.
::
:: Run this ONCE before running build-ffmpeg-ndi-windows.bat
:: ============================================================

set "MSYS2_DIR=C:\msys64"
set "BASH=%MSYS2_DIR%\usr\bin\bash.exe"

if not exist "%BASH%" (
    echo [ERROR] MSYS2 not found at %MSYS2_DIR%
    echo         Download and install from https://www.msys2.org/
    echo         or
    echo         winget install -e --id MSYS2.MSYS2
    exit /b 1
)

echo [INFO] Updating MSYS2 package database...
set MSYSTEM=MINGW64
"%BASH%" --login -c "pacman -Syu --noconfirm"

echo.
echo [INFO] Installing MinGW-w64 toolchain and FFmpeg dependencies...
"%BASH%" --login -c "pacman -S --noconfirm --needed base-devel mingw-w64-x86_64-toolchain mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm mingw-w64-x86_64-pkg-config mingw-w64-x86_64-binutils mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 mingw-w64-x86_64-lame mingw-w64-x86_64-opus mingw-w64-x86_64-libvorbis mingw-w64-x86_64-libvpx mingw-w64-x86_64-freetype mingw-w64-x86_64-libass git"

echo.
echo [INFO] Installing static build dependencies for freetype2 and libass...
echo [INFO] ^(brotli, harfbuzz, graphite2, fribidi, fontconfig and their dev files^)
"%BASH%" --login -c "pacman -S --noconfirm --needed mingw-w64-x86_64-brotli mingw-w64-x86_64-bzip2 mingw-w64-x86_64-libpng mingw-w64-x86_64-zlib mingw-w64-x86_64-harfbuzz mingw-w64-x86_64-graphite2 mingw-w64-x86_64-fribidi mingw-w64-x86_64-fontconfig mingw-w64-x86_64-cairo mingw-w64-x86_64-glib2 mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-libunibreak"

echo.
echo [INFO] Installing AMF headers for AMD hardware encoding...
"%BASH%" --login -c "pacman -S --noconfirm --needed mingw-w64-x86_64-amf-headers"

echo.
echo [INFO] Installing nv-codec-headers for NVIDIA NVENC/NVDEC...
"%BASH%" --login -c "cd /tmp && git clone https://github.com/FFmpeg/nv-codec-headers.git && cd nv-codec-headers && make install PREFIX=/mingw64"

echo.
echo [INFO] Verifying gendef and dlltool are available...
"%BASH%" --login -c "which gendef && which dlltool && echo [OK] Tools found"
if errorlevel 1 (
    echo [ERROR] gendef or dlltool not found after install.
    exit /b 1
)

echo.
echo [INFO] Setup complete. Run build-ffmpeg-ndi-windows.bat from the FFmpeg source directory.
