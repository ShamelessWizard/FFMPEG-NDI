# FFMPEG-NDI

Builds FFmpeg with NDI 6 (NewTek/Vizrt Network Device Interface) input and output support.

> **This fork targets FFmpeg master (current HEAD)** — not a pinned release. The original [lplassman/FFMPEG-NDI](https://github.com/lplassman/FFMPEG-NDI) targeted FFmpeg n5.1 (released 2022). This version has been substantially updated for the current FFmpeg codebase and NDI 6 SDK, including API changes to `FFInputFormat`/`FFOutputFormat`, the `AVChannelLayout` channel layout API, and NDI 6 SDK function signatures. A Windows static binary build is also added.

The patch and source files work identically on Linux, macOS, and Windows — the C source changes are platform-agnostic; only the build environment and NDI SDK paths differ per platform.

> **NDI SDK required.** NDI is non-free software. You must separately download and agree to the NDI SDK license from [ndi.video](https://ndi.video/for-developers/ndi-sdk/download/).

## Current status

| Feature | Status |
|---|---|
| NDI input (receive) | ✅ Working |
| NDI output (send) | ✅ Working |
| FFmpeg master (current HEAD) | ✅ Tested |
| Linux x86\_64 | ✅ Supported |
| Linux ARM (RPi 3/4) | ✅ Supported |
| macOS | ✅ Supported |
| Windows static binary | ✅ Working |
| x264 / x265 (Windows) | ✅ Working — enabled by default in the Windows build script; requires `mingw-w64-x86_64-x264` and `mingw-w64-x86_64-x265` installed via `setup-msys2-ffmpeg.bat` |
| x264 / x265 (Linux/macOS) | ✅ Add `--enable-libx264 --enable-libx265` to configure |
| NVIDIA NVENC/NVDEC (Windows) | ✅ Enabled by default — requires NVIDIA driver and `nv-codec-headers` installed via `setup-msys2-ffmpeg.bat` |
| AMD AMF (Windows) | ✅ Enabled by default — headers installed via `setup-msys2-ffmpeg.bat` |
| Intel QSV (Windows) | ⚠️ Not currently supported — oneVPL not available via pacman; requires manual build from source |

---

## What the patch does

`libndi.patch` modifies five files in the FFmpeg source tree and adds three new source files:

| File | Change |
|---|---|
| `configure` | Adds `--enable-libndi_newtek` option and NDI to the nonfree library list |
| `libavdevice/Makefile` | Registers the NDI encoder/decoder objects |
| `libavdevice/alldevices.c` | Declares the NDI muxer/demuxer to FFmpeg's device registry |
| `doc/indevs.texi` | NDI input device documentation |
| `doc/outdevs.texi` | NDI output device documentation |
| `libavdevice/libndi_newtek_common.h` | Shared NDI constants (`NDI_TIME_BASE`, etc.) |
| `libavdevice/libndi_newtek_dec.c` | NDI input (receive) demuxer |
| `libavdevice/libndi_newtek_enc.c` | NDI output (send) muxer |

---

## Linux

### 1. Install prerequisites

```bash
sudo apt update
sudo apt install git
```

Clone this repository and the FFmpeg source:

```bash
git clone https://github.com/ShamelessWizard/FFMPEG-NDI.git
git clone https://git.ffmpeg.org/ffmpeg.git && cd ffmpeg
```

The patch targets **FFmpeg master** — no specific tag checkout needed.

### 2. Apply the patch

```bash
../FFMPEG-NDI/apply-patch-posix.sh
```

This applies `libndi.patch` using `patch --fuzz=5`. The patch adds the
new NDI source files (`libndi_newtek_dec.c`, `libndi_newtek_enc.c`,
`libndi_newtek_common.h`) and wires them into FFmpeg's `configure`,
`Makefile`, `alldevices.c`, and docs in a single step. More robust than
`git am` as FFmpeg master moves forward — `git am` fails when context
lines drift, `patch` with fuzz tolerance handles it gracefully. No git
identity config is needed.

### 3. Install FFmpeg build prerequisites

```bash
sudo bash ../FFMPEG-NDI/preinstall.sh
```

### 4. Download and install the NDI 6 SDK

Choose the script for your CPU architecture:

#### x86_64 (Intel/AMD desktop/server)

```bash
sudo bash ../FFMPEG-NDI/install-ndi-x86_64.sh
```

This downloads the NDI 6 SDK and installs headers to `/usr/local/include/` and the shared library to `/usr/local/lib/`.

#### Raspberry Pi 4 — 64-bit (aarch64)

```bash
sudo bash ../FFMPEG-NDI/install-ndi-rpi4-aarch64.sh
```

#### Raspberry Pi 4 — 32-bit (armhf)

```bash
sudo bash ../FFMPEG-NDI/install-ndi-rpi4-armhf.sh
```

#### Raspberry Pi 3 — 32-bit (armhf)

```bash
sudo bash ../FFMPEG-NDI/install-ndi-rpi3-armhf.sh
```

#### Generic ARM64 / ARM32 (NDI Advanced SDK required)

The NDI Advanced SDK must be manually downloaded from [ndi.video](https://ndi.video/for-developers/ndi-sdk/download/) due to licensing. Extract the `.tar` file and copy it to the ffmpeg directory, then run the appropriate script:

```bash
# ARM64
sudo bash ../FFMPEG-NDI/install-ndi-generic-aarch64.sh

# ARM32
sudo bash ../FFMPEG-NDI/install-ndi-generic-armhf.sh
```

### 5. Build and install FFmpeg (Linux)

The minimal configuration for NDI send and receive:

```bash
./configure --enable-nonfree --enable-libndi_newtek
make -j$(nproc)
sudo make install
```

If the NDI headers or library are not found automatically:

```bash
./configure --enable-nonfree --enable-libndi_newtek \
    --extra-cflags="-I/usr/local/include" \
    --extra-ldflags="-L/usr/local/lib"
make -j$(nproc)
sudo make install
```

After installing, update the dynamic linker cache:

```bash
sudo ldconfig
```

---

## macOS

### 1. Install prerequisites

Install [Homebrew](https://brew.sh) if not already present.

Clone the repositories:

```bash
git clone https://github.com/ShamelessWizard/FFMPEG-NDI.git
git clone https://git.ffmpeg.org/ffmpeg.git && cd ffmpeg
```

### 2. Download and install the NDI SDK for Apple

Download and run the installer from [ndi.video](https://ndi.video/for-developers/ndi-sdk/download/).  
It installs to `/Library/NDI SDK for Apple/` by default.

### 3. Apply the patch

```bash
../FFMPEG-NDI/apply-patch-posix.sh
```

This applies `libndi.patch` using `patch --fuzz=5`. The patch adds the
new NDI source files (`libndi_newtek_dec.c`, `libndi_newtek_enc.c`,
`libndi_newtek_common.h`) and wires them into FFmpeg's `configure`,
`Makefile`, `alldevices.c`, and docs in a single step. More robust than
`git am` as FFmpeg master moves forward — `git am` fails when context
lines drift, `patch` with fuzz tolerance handles it gracefully. No git
identity config is needed.

### 4. Install build prerequisites

```bash
bash ../FFMPEG-NDI/preinstall-macos.sh
```

### 5. Install NDI libraries to system paths

This copies headers and the library from the NDI SDK into `/usr/local/` so FFmpeg's configure can find them automatically:

```bash
sudo bash ../FFMPEG-NDI/install-ndi-macos.sh
```

### 6. Apply the mathops patch (Intel Macs only)

On Intel Macs, a clang inline assembly fix is needed:

```bash
patch -p1 --fuzz=5 < ../FFMPEG-NDI/mathops.patch
```

This is **not** needed on Apple Silicon (M-series) Macs.

### 7. Build and install FFmpeg (macOS)

```bash
./configure --enable-nonfree --enable-libndi_newtek
make -j$(sysctl -n hw.ncpu)
sudo make install
```

If the NDI SDK is not found automatically, pass the paths explicitly:

```bash
./configure --enable-nonfree --enable-libndi_newtek \
    --extra-cflags="-I/Library/NDI SDK for Apple/include" \
    --extra-ldflags="-L/Library/NDI SDK for Apple/lib/macOS"
make -j$(sysctl -n hw.ncpu)
sudo make install
```

---

## Windows

FFmpeg's build system requires a Unix-like environment even on Windows. The recommended approach is [MSYS2](https://www.msys2.org/) with the MinGW-w64 toolchain. The build scripts live in the FFMPEG-NDI repo and are called from the FFmpeg source directory — the same pattern as the Linux and macOS scripts.

### Prerequisites

| Requirement | Notes |
|---|---|
| [MSYS2](https://www.msys2.org/) | Install to the default path `C:\msys64`, or `winget install -e --id MSYS2.MSYS2` |
| [NDI 6 SDK for Windows](https://ndi.video/for-developers/ndi-sdk/download/) | Install to the default path `C:\Program Files\NDI\NDI 6 SDK` |

### 1. Clone repositories

```powershell
git clone https://github.com/ShamelessWizard/FFMPEG-NDI.git
git clone https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg
```

### 2. Set up MSYS2 and install build dependencies

Run once from a **PowerShell or command prompt**:

```powershell
..\FFMPEG-NDI\setup-msys2-ffmpeg.bat
```

This installs the MinGW-w64 toolchain and all codec library dependencies via `pacman`.

### 3. Apply the patch

```powershell
..\FFMPEG-NDI\apply-patch-windows.ps1
```

This applies `libndi.patch` using `patch --fuzz=5`. The patch adds the
new NDI source files and wires them into FFmpeg's `configure`,
`Makefile`, `alldevices.c`, and docs in one step. More robust than
`git am` as FFmpeg master moves forward — `git am` fails when context
lines drift, `patch` with fuzz tolerance handles it gracefully.

### 4. Build FFmpeg with NDI

From a **PowerShell prompt** inside the FFmpeg source directory:

```powershell
# Build
..\FFMPEG-NDI\build-windows.ps1

# Clean build artifacts before a fresh build
..\FFMPEG-NDI\build-windows.ps1 -DistClean
```

The build script will:

1. Validate MSYS2 and NDI 6 SDK are present at their default paths
2. Copy NDI headers to a space-free temp path (avoids `Program Files` breaking gcc's `-I` flag)
3. Generate a MinGW-compatible `libndi.a` from `Processing.NDI.Lib.x64.dll` via `gendef` + `dlltool`
4. Run `./configure` with static linking flags
5. Run `make -j$(nproc)`
6. Package `ffmpeg.exe`, `ffprobe.exe`, `ffplay.exe`, `Processing.NDI.Lib.x64.dll`, and any required MinGW runtime DLLs into `dist\ffmpeg-ndi-YYYYMMDD-HHMMSS\` inside the FFmpeg source tree (a fresh timestamped directory is created on every build)

### 5. Manual configure (if you prefer to build by hand)

Open an **MSYS2 MinGW64 shell**, `cd` to the FFmpeg source, then:

```bash
# Copy NDI headers to a space-free path (Program Files breaks gcc's -I flag)
NDI_INC_SAFE="/tmp/ndi-include"
mkdir -p "$NDI_INC_SAFE"
cp -r "/c/Program Files/NDI/NDI 6 SDK/Include/." "$NDI_INC_SAFE/"

# Generate MinGW import library from NDI DLL
gendef - "/c/Program Files/NDI/NDI 6 SDK/Bin/x64/Processing.NDI.Lib.x64.dll" > /tmp/libndi.def
dlltool -d /tmp/libndi.def -l /tmp/libndi.a -D "Processing.NDI.Lib.x64.dll"

./configure \
  --enable-nonfree \
  --enable-libndi_newtek \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 \
  --enable-ffnvcodec \
  --enable-nvdec \
  --enable-nvenc \
  --enable-cuvid \
  --enable-amf \
  --enable-static \
  --disable-shared \
  --ld="g++" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I${NDI_INC_SAFE}" \
  --extra-ldflags="-L/tmp -static -static-libgcc -static-libstdc++" \
  --extra-libs="-lndi -lpsapi -lole32 -lstrmiids -luuid -loleaut32 -lshlwapi -lpthread"

make -j$(nproc)
```

### 6. Runtime DLL and packaging

The automated build packages everything into a timestamped `dist\ffmpeg-ndi-YYYYMMDD-HHMMSS\` directory including `Processing.NDI.Lib.x64.dll` and any MinGW runtime DLLs detected via `ldd`. For manual builds:

```powershell
# Create output directory
New-Item -ItemType Directory -Force -Path dist\ffmpeg-ndi

# Copy executables
Copy-Item ffmpeg.exe, ffprobe.exe, ffplay.exe dist\ffmpeg-ndi\

# Copy NDI runtime DLL
Copy-Item "C:\Program Files\NDI\NDI 6 SDK\Bin\x64\Processing.NDI.Lib.x64.dll" dist\ffmpeg-ndi\
```

---

## Usage

### List all NDI sources on the network

```bash
ffmpeg -f libndi_newtek -find_sources 1 -i dummy
```

### List sources including a remote host (unicast scan)

```bash
ffmpeg -f libndi_newtek -extra_ips "192.168.1.50" -find_sources 1 -i dummy
```

### Receive an NDI stream and play it

```bash
ffplay -f libndi_newtek -i "SOURCE NAME (stream)"
```

### Low-latency NDI monitor

```bash
ffplay -fs -alwaysontop \
  -fflags nobuffer -flags low_delay \
  -framedrop -analyzeduration 0 \
  -max_probe_packets 1 -max_delay 0 \
  -probesize 100000 \
  -f libndi_newtek -bandwidth 0 \
  -i "NDI-SOURCE (Stream 1)"
```

### Stream a webcam to NDI (Linux / v4l2)

```bash
ffmpeg -f v4l2 -framerate 30 -video_size 1280x720 \
  -pixel_format mjpeg -i /dev/video0 \
  -f libndi_newtek -pix_fmt uyvy422 CameraOut
```

### Stream a webcam to NDI (macOS / AVFoundation)

```bash
ffmpeg -f avfoundation -framerate 30 -video_size 1280x720 \
  -i "0" -f libndi_newtek -pix_fmt uyvy422 CameraOut
```

### Stream a webcam to NDI (Windows / DirectShow)

```bash
# List available DirectShow devices first:
ffmpeg -list_devices true -f dshow -i dummy

# Then stream:
ffmpeg -f dshow -framerate 30 -video_size 1280x720 \
  -i video="Your Camera Name" \
  -f libndi_newtek -pix_fmt uyvy422 CameraOut
```

### Restream NDI to NDI

```bash
ffmpeg -f libndi_newtek -i "SOURCE (Input Stream)" \
  -f libndi_newtek -y OutputStreamName
```

### `-bandwidth` receive modes

| Value | Mode |
|---|---|
| `0` | High bandwidth (default) |
| `1` | Low bandwidth |
| `2` | Audio only |

---

## Notes on NDI SDK versions

| FFmpeg-NDI version | NDI SDK | FFmpeg target | Notes |
|---|---|---|---|
| This fork (ShamelessWizard) | NDI 6 | FFmpeg master (current HEAD) | Windows static build, updated API |
| lplassman/FFMPEG-NDI | NDI 5 | FFmpeg n5.1 (2022) | Original |

The NDI 6 SDK introduces `NDIlib_find_create_v2`, `NDIlib_util_audio_to_interleaved_16s_v2`, and `NDIlib_recv_free_audio_v2`. The source files in `libavdevice/` have been updated to use these v2 APIs. If you are compiling against NDI 5, replace the `_v2` suffixed calls with their unsuffixed equivalents.

---

## Helpful tips

View all FFmpeg/FFplay options:
```bash
ffmpeg --help full
ffmpeg -h demuxer=libndi_newtek
ffmpeg -h muxer=libndi_newtek
```

Compress FFmpeg source to a tarball:
```bash
tar -zcvf ffmpeg.tar.gz ffmpeg
```
