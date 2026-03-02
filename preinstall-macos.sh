#!/usr/bin/env sh

# Install prerequisites for building FFmpeg with NDI on macOS
# Requires Homebrew (https://brew.sh)

set -eu

if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is not installed."
    echo "Install it from https://brew.sh"
    exit 1
fi

echo "Installing build prerequisites via Homebrew..."

brew install \
    automake \
    cmake \
    git \
    libass \
    libtool \
    libvorbis \
    meson \
    nasm \
    ninja \
    openssl \
    pkg-config \
    sdl2 \
    texinfo \
    wget \
    yasm \
    zlib

echo "Done installing prerequisites."
echo "Note: macOS includes Bonjour (mDNS) natively — no separate Avahi install needed."
