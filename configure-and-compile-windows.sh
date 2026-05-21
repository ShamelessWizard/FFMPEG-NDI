#!/bin/bash
# configure-and-compile-windows.sh
# Called by build-windows.ps1 with NDI path env vars pre-set.
# Can also be run directly on Linux/macOS by setting the vars manually.
#
# Required env vars (set by build-windows.ps1):
#   NDI_INCLUDE_WIN  - Windows path to NDI SDK Include dir
#   NDI_DLL_WIN      - Windows path to NDI DLL
#   FFMPEG_SRC_WIN   - Windows path to FFmpeg source root
#   WORK_WIN         - Windows path to scratch directory

# Source the MSYS2 profile BEFORE strict mode.
# Profile scripts contain commands that intentionally return non-zero
# (optional file checks, etc.) which would kill the script under set -e.
# ---------------------------------------------------------------
export MSYSTEM=MINGW64
export PATH="/mingw64/bin:/usr/bin:/bin:$PATH"
# shellcheck disable=SC1091
source /etc/profile

# Strict mode on after profile is loaded
set -euo pipefail

# Confirm we have the native Windows gcc, not the MSYS one.
# x86_64-w64-mingw32 = correct.  x86_64-pc-msys = wrong.
COMPILER_TARGET="$(gcc -dumpmachine)"
echo "[INFO] gcc    : $(which gcc)"
echo "[INFO] target : $COMPILER_TARGET"
if [[ "$COMPILER_TARGET" != *mingw* ]]; then
    echo "[ERROR] Wrong gcc - expected x86_64-w64-mingw32, got $COMPILER_TARGET"
    echo "        Ensure mingw-w64-x86_64-toolchain is installed via pacman."
    exit 1
fi

# Point pkg-config at the MinGW64 package tree. Without this it either finds
# nothing or picks up MSYS packages which have different link flags.
export PKG_CONFIG_PATH="/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig"
export PKG_CONFIG_LIBDIR="/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig"
echo "[INFO] PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo "[INFO] pkg-config x264      : $(pkg-config --modversion x264       2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config x265      : $(pkg-config --modversion x265       2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config opus      : $(pkg-config --modversion opus       2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config vorbis    : $(pkg-config --modversion vorbis     2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config vpx       : $(pkg-config --modversion vpx        2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config freetype2 : $(pkg-config --modversion freetype2  2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config libass    : $(pkg-config --modversion libass     2>/dev/null || echo 'NOT FOUND')"
echo "[INFO] pkg-config srt       : $(pkg-config --modversion srt        2>/dev/null || echo 'NOT FOUND - run: pacman -S mingw-w64-x86_64-libsrt')"
echo "[INFO] pkg-config openssl   : $(pkg-config --modversion openssl    2>/dev/null || echo 'NOT FOUND - run: pacman -S mingw-w64-x86_64-openssl')"
echo ""
echo "[INFO] If any show NOT FOUND, run: pacman -S mingw-w64-x86_64-<package>"
echo "" 

# ---------------------------------------------------------------
# Convert Windows paths to POSIX
# ---------------------------------------------------------------
NDI_INC="$(cygpath -u "$NDI_INCLUDE_WIN")"
NDI_DLL="$(cygpath -u "$NDI_DLL_WIN")"
FFMPEG_SRC="$(cygpath -u "$FFMPEG_SRC_WIN")"
WORK="$(cygpath -u "$WORK_WIN")"

mkdir -p "$WORK"

echo "[INFO] FFmpeg src : $FFMPEG_SRC"
echo "[INFO] NDI include: $NDI_INC"
echo "[INFO] Scratch dir: $WORK"

# ---------------------------------------------------------------
# Step 1: Generate MinGW import library from the NDI DLL
# ---------------------------------------------------------------
echo ""
echo "[STEP 1] Generating libndi.a from NDI DLL..."
gendef - "$NDI_DLL" > "$WORK/libndi_newtek.def"
dlltool -d "$WORK/libndi_newtek.def" \
        -l "$WORK/libndi.a" \
        -D "$NDI_DLL"
echo "[INFO]   libndi.a created at $WORK/libndi.a"

# Copy NDI headers to a space-free path inside the scratch dir.
# FFmpeg's configure passes --extra-cflags directly to gcc without
# re-quoting, so any spaces in the include path break the compiler
# test ("C:/Program Files/..." gets split into separate arguments).
NDI_INC_SAFE="$WORK/ndi-include"
mkdir -p "$NDI_INC_SAFE"
cp -r "$NDI_INC/." "$NDI_INC_SAFE/"
echo "[INFO]   NDI headers copied to $NDI_INC_SAFE"

# Create a patched x264.pc that removes -DX264_API_IMPORTS from Cflags.
# The MSYS2 x264.pc has -DX264_API_IMPORTS in Cflags (for DLL builds) and
# -UX264_API_IMPORTS in Cflags.private (for static builds). However, FFmpeg's
# configure appends Cflags AFTER our --extra-cflags so -DX264_API_IMPORTS
# always wins regardless of order. Removing it from the .pc entirely fixes this.
mkdir -p "$WORK/pkgconfig"
sed 's/-DX264_API_IMPORTS//' /mingw64/lib/pkgconfig/x264.pc > "$WORK/pkgconfig/x264.pc"
export PKG_CONFIG_PATH="$WORK/pkgconfig:/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig"
export PKG_CONFIG_LIBDIR="$WORK/pkgconfig:/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig"
echo "[INFO]   Patched x264.pc to remove -DX264_API_IMPORTS"

# ---------------------------------------------------------------
# Step 2: Configure FFmpeg
# ---------------------------------------------------------------
echo ""
echo "[STEP 2] Configuring FFmpeg..."
cd "$FFMPEG_SRC"

# A/53 closed caption pass-through is built into the mpeg2video encoder with no
# separate configure flag (upstream since commit 45daaf2c, May 2025). Use -a53cc 1
# (the encoder default) when transcoding to mpeg2video — CC data from H.264 SEI
# or MPEG-2 user_data on the input is automatically re-embedded in the output.
# --enable-version3 is required alongside --enable-gpl when OpenSSL >=3.0 is
# linked; included here as standard practice.
PKG_CONFIG_PATH="$WORK/pkgconfig:/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig" \
PKG_CONFIG_LIBDIR="$WORK/pkgconfig:/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig" \
./configure \
    --enable-nonfree \
    --enable-libndi_newtek \
    --enable-gpl \
    --enable-version3 \
    --enable-openssl \
    --enable-libsrt \
    --enable-libx264 \
    --enable-libx265 \
    --enable-ffnvcodec \
    --enable-nvdec \
    --enable-nvenc \
    --enable-cuvid \
    --enable-amf \
    --enable-static \
    --disable-shared \
    --extra-cflags="-I${NDI_INC_SAFE}" \
    --ld="g++" \
    --host-cflags="-mcmodel=medium" \
    --pkg-config-flags="--static" \
    --extra-ldflags="-L${WORK} -static -static-libgcc -static-libstdc++" \
    --extra-libs="-lndi -lpsapi -lole32 -lstrmiids -luuid -loleaut32 -lshlwapi -lpthread"

# ---------------------------------------------------------------
# Step 3: Build
# ---------------------------------------------------------------
echo ""
echo "[STEP 3] Building FFmpeg (this will take several minutes)..."
make -j"$(nproc)"

# ---------------------------------------------------------------
# Step 4: Package into dist/ffmpeg-ndi-YYYYMMDD-HHMMSS
# Copies executables, NDI DLL, and any MinGW runtime DLLs that
# could not be statically linked (discovered via ldd).
# ---------------------------------------------------------------
DIST="$FFMPEG_SRC/dist/ffmpeg-ndi-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DIST"

echo ""
echo "[STEP 4] Packaging to $DIST ..."

# Copy main executables
for bin in ffmpeg ffprobe ffplay; do
    if [ -f "$FFMPEG_SRC/${bin}.exe" ]; then
        cp "$FFMPEG_SRC/${bin}.exe" "$DIST/"
        echo "[INFO]   ${bin}.exe"
    fi
done

# Copy NDI runtime DLL - cannot be statically linked
cp "$NDI_DLL" "$DIST/"
echo "[INFO]   $(basename "$NDI_DLL")"

# Copy any MinGW runtime DLLs reported by ldd as dependencies
# from /mingw64/bin/ - these are ones that were not statically linked
echo "[INFO]   Scanning for MinGW runtime dependencies..."
for bin in "$DIST"/*.exe; do
    dlls=$(ldd "$bin" 2>/dev/null | grep -i '/mingw64/bin/' | awk '{print $3}' || true)
    for dll in $dlls; do
        name="$(basename "$dll")"
        if [ -f "$dll" ] && [ ! -f "$DIST/$name" ]; then
            cp "$dll" "$DIST/"
            echo "[INFO]   $name (runtime dep)"
        fi
    done
done

echo ""
echo "=========================================="
echo " Build complete!"
echo " Output : $DIST"
echo "=========================================="
