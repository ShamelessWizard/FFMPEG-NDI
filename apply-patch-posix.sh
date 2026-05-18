#!/usr/bin/env sh
# apply-patch-posix.sh
# Applies libndi.patch to the FFmpeg source using patch with fuzz tolerance.
# More robust than git am against FFmpeg master context drift.
#
# Run from the FFmpeg source directory:
#   ../FFMPEG-NDI/apply-patch-posix.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH="$SCRIPT_DIR/libndi.patch"

if [ ! -f "$PATCH" ]; then
    echo "[ERROR] libndi.patch not found at $PATCH" >&2
    exit 1
fi

if [ ! -f "./configure" ] || [ ! -d "./libavdevice" ]; then
    echo "[ERROR] Run this from inside the FFmpeg source directory." >&2
    echo "        ./configure and ./libavdevice/ must be present." >&2
    exit 1
fi

echo "[INFO] Applying libndi.patch to $PWD ..."
if ! patch -p1 --fuzz=5 < "$PATCH"; then
    echo "" >&2
    echo "[ERROR] patch failed. Check output above for rejected hunks." >&2
    echo "        Rejected hunks will be saved as *.rej files." >&2
    exit 1
fi

echo ""
echo "Patch applied successfully. Now run ./configure and make."
