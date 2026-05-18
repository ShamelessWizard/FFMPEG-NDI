#!/usr/bin/env sh

# Download and install the NDI 6 SDK for Linux.
# The installer places headers in /usr/local/include/ and the
# shared library (libndi.so.6) in /usr/local/lib/.

set -eu

NDI_URL="https://downloads.ndi.tv/SDK/NDI_SDK_Linux/Install_NDI_SDK_v6_Linux.tar.gz"
INSTALLER_TGZ="/tmp/Install_NDI_SDK_v6_Linux.tar.gz"
INSTALLER_DIR="/tmp"

echo "Downloading NDI 6 SDK..."
curl -L -o "${INSTALLER_TGZ}" "${NDI_URL}"

echo "Extracting..."
tar -xzf "${INSTALLER_TGZ}" -C "${INSTALLER_DIR}"

# Accept the license non-interactively (press q to quit pager, then y to accept)
echo "Installing NDI 6 SDK to /usr/local/ ..."
yes y | bash "${INSTALLER_DIR}"/Install_NDI_SDK_v6_Linux.sh > /dev/null

# Refresh the dynamic linker cache so libndi.so.6 is found at runtime
ldconfig

echo "NDI 6 SDK installed."
echo "  Headers : /usr/local/include/Processing.NDI.Lib.h"
echo "  Library : /usr/local/lib/libndi.so.6"
