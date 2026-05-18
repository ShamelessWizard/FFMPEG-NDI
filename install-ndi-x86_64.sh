#!/usr/bin/env sh

# Install NDI 6 SDK libraries for x86_64 (Intel/AMD) Linux systems.
# The NDI 6 installer places files under /usr/local/ directly,
# so no manual copy step is needed after running the installer.

set -eu

echo "Downloading and installing NDI 6 SDK for x86_64..."
sudo bash "$(dirname "$0")"/download_NDI_SDK.sh

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
