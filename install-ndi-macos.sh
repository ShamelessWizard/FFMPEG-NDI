#!/usr/bin/env sh

# Install NDI SDK headers and libraries on macOS for FFmpeg compilation.
#
# Prerequisites: Download and install the NDI SDK for Apple from https://ndi.video/for-developers/ndi-sdk/download/
# The installer places files in /Library/NDI SDK for Apple/ by default.

set -eu

NDI_SDK_DIR="/Library/NDI SDK for Apple"
INCLUDE_DIR="/usr/local/include"
LIB_DIR="/usr/local/lib"

if [ ! -d "$NDI_SDK_DIR" ]; then
    echo "Error: NDI SDK for Apple not found at '$NDI_SDK_DIR'."
    echo ""
    echo "Please download and install the NDI SDK from:"
    echo "  https://ndi.video/for-developers/ndi-sdk/download/"
    echo ""
    echo "After installing, re-run this script."
    exit 1
fi

if [ ! -d "$NDI_SDK_DIR/include" ]; then
    echo "Error: NDI SDK include directory not found at '$NDI_SDK_DIR/include'."
    exit 1
fi

if [ ! -d "$NDI_SDK_DIR/lib/macOS" ]; then
    echo "Error: NDI SDK macOS library directory not found at '$NDI_SDK_DIR/lib/macOS'."
    exit 1
fi

echo "Installing NDI SDK headers and libraries..."

# Create target directories if needed
mkdir -p "$INCLUDE_DIR"
mkdir -p "$LIB_DIR"

# Copy headers
cp "$NDI_SDK_DIR"/include/* "$INCLUDE_DIR"/
echo "  Headers installed to $INCLUDE_DIR/"

# Copy libraries
cp "$NDI_SDK_DIR"/lib/macOS/* "$LIB_DIR"/
echo "  Libraries installed to $LIB_DIR/"

echo "Done"
