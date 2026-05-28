#!/usr/bin/env bash
# build-linux.sh
# Configures, compiles, and packages FFmpeg with NDI 6 support for Linux x86_64.
# Run from the FFmpeg source directory:
#   ../FFMPEG-NDI/build-linux.sh
#
# Options:
#   --distclean    Run make distclean and exit (no build)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FFMPEG_SRC="$(pwd)"

# Validate we are in an FFmpeg source tree
if [ ! -f "$FFMPEG_SRC/configure" ] || [ ! -d "$FFMPEG_SRC/libavdevice" ]; then
    echo "[ERROR] Run this from inside the FFmpeg source directory." >&2
    exit 1
fi

# DistClean mode
if [[ "${1:-}" == "--distclean" ]]; then
    echo "[INFO] Running make distclean in $FFMPEG_SRC ..."
    make distclean 2>/dev/null || true
    echo ""
    echo "Clean. Run ../FFMPEG-NDI/build-linux.sh to reconfigure and build."
    exit 0
fi

# ---------------------------------------------------------------
# Validate NDI SDK is installed
# ---------------------------------------------------------------
NDI_INCLUDE_DIR="/usr/local/include"
NDI_LIB_DIR="/usr/local/lib"
NDI_HEADER="$NDI_INCLUDE_DIR/Processing.NDI.Lib.h"

if [ ! -f "$NDI_HEADER" ]; then
    echo "[ERROR] NDI SDK header not found: $NDI_HEADER" >&2
    echo "        Install with: sudo bash $SCRIPT_DIR/install-ndi-x86_64.sh" >&2
    exit 1
fi

NDI_LIB="$(ls "$NDI_LIB_DIR"/libndi.so.* 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$NDI_LIB" ]; then
    echo "[ERROR] libndi.so not found in $NDI_LIB_DIR" >&2
    echo "        Install with: sudo bash $SCRIPT_DIR/install-ndi-x86_64.sh" >&2
    exit 1
fi

echo "[INFO] NDI SDK  : $NDI_HEADER"
echo "[INFO] NDI lib  : $NDI_LIB"
echo "[INFO] FFmpeg   : $FFMPEG_SRC"
echo ""

# ---------------------------------------------------------------
# Detect optional features
# ---------------------------------------------------------------
EXTRA_FLAGS=()

if pkg-config --exists x264 2>/dev/null; then
    EXTRA_FLAGS+=(--enable-libx264)
    echo "[INFO] x264     : $(pkg-config --modversion x264)"
else
    echo "[WARN] x264 not found - skipping  (apt install libx264-dev)"
fi

if pkg-config --exists x265 2>/dev/null; then
    EXTRA_FLAGS+=(--enable-libx265)
    echo "[INFO] x265     : $(pkg-config --modversion x265)"
else
    echo "[WARN] x265 not found - skipping  (apt install libx265-dev)"
fi

if pkg-config --exists srt 2>/dev/null; then
    EXTRA_FLAGS+=(--enable-libsrt)
    echo "[INFO] srt      : $(pkg-config --modversion srt)"
else
    echo "[WARN] SRT not found  - skipping  (apt install libsrt-openssl-dev)"
fi

if pkg-config --exists ffnvcodec 2>/dev/null; then
    EXTRA_FLAGS+=(--enable-ffnvcodec --enable-nvdec --enable-nvenc --enable-cuvid)
    echo "[INFO] ffnvcodec: $(pkg-config --modversion ffnvcodec)"
else
    echo "[WARN] NVIDIA codec headers not found - skipping NVENC/NVDEC"
    echo "       Install from: https://github.com/FFmpeg/nv-codec-headers"
fi

echo ""

# ---------------------------------------------------------------
# Step 1: Configure FFmpeg
# ---------------------------------------------------------------
echo "[STEP 1] Configuring FFmpeg..."

./configure \
    --enable-nonfree \
    --enable-libndi_newtek \
    --enable-gpl \
    --enable-version3 \
    --enable-openssl \
    --extra-cflags="-I${NDI_INCLUDE_DIR}" \
    --extra-ldflags="-L${NDI_LIB_DIR}" \
    "${EXTRA_FLAGS[@]}"

# ---------------------------------------------------------------
# Step 2: Build
# ---------------------------------------------------------------
echo ""
echo "[STEP 2] Building FFmpeg (this will take several minutes)..."
make -j"$(nproc)"

# ---------------------------------------------------------------
# Step 3: Package into dist/ffmpeg-ndi-YYYYMMDD-HHMMSS
# Copies executables and the NDI shared library required at runtime.
# ---------------------------------------------------------------
DIST="$FFMPEG_SRC/dist/ffmpeg-ndi-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DIST"

echo ""
echo "[STEP 3] Packaging to $DIST ..."

for bin in ffmpeg ffprobe ffplay; do
    if [ -f "$FFMPEG_SRC/$bin" ]; then
        cp "$FFMPEG_SRC/$bin" "$DIST/"
        echo "[INFO]   $bin"
    fi
done

# NDI shared library cannot be statically linked - must ship with the binaries.
# Copy the real file and create the soname symlink (libndi.so.6) that the binary resolves at runtime.
NDI_LIB_NAME="$(basename "$NDI_LIB")"
NDI_SONAME="$(objdump -p "$NDI_LIB" 2>/dev/null | awk '/SONAME/{print $2}' || echo '')"
cp "$NDI_LIB" "$DIST/"
echo "[INFO]   $NDI_LIB_NAME"
if [ -n "$NDI_SONAME" ] && [ "$NDI_SONAME" != "$NDI_LIB_NAME" ]; then
    ln -sf "$NDI_LIB_NAME" "$DIST/$NDI_SONAME"
    echo "[INFO]   $NDI_SONAME -> $NDI_LIB_NAME"
fi

# Copy any non-system shared library dependencies (e.g. SRT, x264 if not installed system-wide)
echo "[INFO] Scanning shared library dependencies..."
for bin in "$DIST"/ffmpeg "$DIST"/ffprobe "$DIST"/ffplay; do
    [ -f "$bin" ] || continue
    ldd "$bin" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
        lib_dir="$(dirname "$lib")"
        # Only bundle libs from non-standard locations (skip /lib, /lib64, /usr/lib, /usr/lib64)
        if [[ "$lib_dir" != /lib* ]] && [[ "$lib_dir" != /usr/lib* ]]; then
            name="$(basename "$lib")"
            if [ ! -f "$DIST/$name" ]; then
                cp "$lib" "$DIST/"
                echo "[INFO]   $name (non-system dep)"
            fi
        fi
    done
done

echo ""
echo "=========================================="
echo " FFmpeg + NDI 6 build complete!"
echo " Output : $DIST"
echo "=========================================="
echo ""
echo "Quick test:"
echo "  cd $DIST"
echo "  ./ffmpeg -f libndi_newtek -find_sources 1 -i dummy"
