#!/usr/bin/env sh

# Install NDI 6 SDK libraries for x86_64 (Intel/AMD) Linux systems.
# If "NDI SDK for Linux" is already present next to this script, it installs
# directly from that local copy. Otherwise falls back to downloading from NDI.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NDI_SDK_DIR="$SCRIPT_DIR/NDI SDK for Linux"

if [ -f "$NDI_SDK_DIR/include/Processing.NDI.Lib.h" ] && \
   [ -d "$NDI_SDK_DIR/lib/x86_64-linux-gnu" ]; then
    echo "Installing NDI 6 SDK from local copy..."
    cp -r "$NDI_SDK_DIR/include/." /usr/local/include/
    # Copy the versioned .so as the real file, then create soname and unversioned symlinks.
    # Using plain 'cp libndi.so*' would follow symlinks and create three 27 MB copies.
    NDI_LIB_SRC="$(ls "$NDI_SDK_DIR/lib/x86_64-linux-gnu/"libndi.so.*.* 2>/dev/null | head -1)"
    NDI_LIB_NAME="$(basename "$NDI_LIB_SRC")"
    NDI_SONAME="libndi.so.$(echo "$NDI_LIB_NAME" | cut -d. -f3)"
    cp "$NDI_LIB_SRC" /usr/local/lib/
    ln -sf "$NDI_LIB_NAME" /usr/local/lib/"$NDI_SONAME"
    ln -sf "$NDI_SONAME"   /usr/local/lib/libndi.so
    echo "NDI 6 SDK installed from local copy."
else
    echo "Local NDI SDK not found — downloading from NDI..."
    bash "$SCRIPT_DIR/download_NDI_SDK.sh"
fi

# Ensure /usr/local/lib is in the ldconfig search path, then refresh the cache.
# Without this, libndi.so.6 will not be found by the dynamic linker at runtime.
if ! grep -qr '/usr/local/lib' /etc/ld.so.conf /etc/ld.so.conf.d/ 2>/dev/null; then
    echo "/usr/local/lib" > /etc/ld.so.conf.d/usr-local-lib.conf
    echo "  [INFO] Added /usr/local/lib to ldconfig search path"
fi
ldconfig

echo "Done. Verifying installation..."

if [ -f /usr/local/include/Processing.NDI.Lib.h ]; then
    echo "  [OK] Header found: /usr/local/include/Processing.NDI.Lib.h"
else
    echo "  [WARN] Header not found at /usr/local/include/Processing.NDI.Lib.h"
    echo "         Try: --extra-cflags=-I/usr/local/include when running ./configure"
fi

if [ -f /usr/local/lib/libndi.so.6 ] || [ -f /usr/local/lib/libndi.so ]; then
    echo "  [OK] Library found in /usr/local/lib/"
else
    echo "  [WARN] libndi.so not found in /usr/local/lib/"
    echo "         Try: --extra-ldflags=-L/usr/local/lib when running ./configure"
fi
