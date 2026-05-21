# FFMPEG-NDI Project Digest
# For: ShamelessWizard (5283835+ShamelessWizard@users.noreply.github.com)
# Purpose: Resume context for Claude in a new conversation

## Project
Fork of lplassman/FFMPEG-NDI updated for FFmpeg master + NDI 6 SDK with
Windows static binary build support.

GitHub: https://github.com/ShamelessWizard/FFMPEG-NDI
FFmpeg tested against: N-124447-g75a65e62bc

## Repo Structure
FFMPEG-NDI repo sits alongside FFmpeg source:
  C:\git\FFMPEG-NDI\   -- the fork (scripts, patch, source files)
  C:\git\FFmpeg\       -- FFmpeg source (patched, built here)

All scripts are called from within C:\git\FFmpeg\ as:
  ..\FFMPEG-NDI\build-windows.ps1
  ..\FFMPEG-NDI\build-windows.ps1 -DistClean

Output lands in: C:\git\FFmpeg\dist\ffmpeg-ndi-YYYYMMDD-HHMMSS\
  (fresh timestamped directory per build; prior builds are preserved)

## Files Changed vs lplassman
### New (Windows build)
  build-windows.ps1                  -- PowerShell entry point
  configure-and-compile-windows.sh  -- MSYS2 bash build logic
  setup-msys2-ffmpeg.bat            -- one-time MSYS2 dependency install
  apply-patch-windows.ps1           -- patch --fuzz=5 wrapper (no git am, no cp)
  apply-patch-posix.sh              -- POSIX counterpart for Linux/macOS
  distclean-windows.ps1             -- removed, merged into build-windows.ps1 -DistClean

### Updated
  libndi.patch                      -- sole source of truth for NDI files;
                                       adds dec.c/enc.c/common.h plus configure,
                                       Makefile, alldevices.c, docs in one patch
  README.md                         -- full rewrite
  download_NDI_SDK.sh               -- updated to NDI 6
  install-ndi-x86_64.sh             -- updated for NDI 6 install paths
  install-ndi-macos.sh              -- macOS installer for NDI SDK for Apple
  handle_NDI_Advanced_SDK.sh        -- v6 Advanced SDK extractor, set -eu

### Removed
  libavdevice/libndi_newtek_*       -- standalone copies deleted; patch is now
                                       sole source of truth. cp step removed
                                       from apply-patch-windows.ps1 and README
                                       Linux/macOS instructions.

## Key Technical Changes

### FFmpeg API (dec.c / enc.c)
- AVInputFormat/AVOutputFormat -> FFInputFormat/FFOutputFormat
- Public fields now nested under .p.* (e.g. .p.name, .p.flags)
- Added #include libavformat/demux.h and mux.h
- st->codecpar->channels -> av_channel_layout_default(&st->codecpar->ch_layout, n)
- AVFMTCTX_NOHEADER removed entirely -- modern FFmpeg doesn't reliably call
  read_packet via avformat_find_stream_info for devices with no initial streams.
  ndi_read_header now waits up to 10 seconds for first video+audio frames
  before returning, establishing streams synchronously.
- NDIlib_initialize() balanced with NDIlib_destroy() in ndi_read_close
  and ndi_write_trailer (NDI runtime uses ref-counting).

### NDI 6 SDK
- NDIlib_find_create_v2 (replaces deprecated NDIlib_find_create)
- NDIlib_util_audio_to_interleaved_16s_v2
- NDIlib_recv_free_audio_v2 / NDIlib_recv_free_video_v2
- NDIlib_source_t.p_url_address (replaces deprecated p_ip_address)
- Forward declarations added for ndi_create_video_stream/ndi_create_audio_stream
- Deprecation warnings suppressed via #pragma GCC diagnostic in common.h

### Windows Build (configure-and-compile-windows.sh)
- MSYS2 MinGW64 via bash --login
- source /etc/profile BEFORE set -euo pipefail (profile scripts return non-zero)
- PKG_CONFIG_PATH set to /mingw64/lib/pkgconfig:/mingw64/share/pkgconfig
- NDI headers copied to space-free temp path (Program Files breaks gcc -I)
- gendef + dlltool generates MinGW libndi.a from NDI DLL
- --ld=g++ required for C++ runtime (harfbuzz/graphite2 are C++ libs)
- --pkg-config-flags=--static for static deps
- A/53 closed caption pass-through: built into mpeg2video encoder upstream since
  commit 45daaf2c (May 2025) — no configure flag needed. Use -a53cc 1 at runtime
  (it is already the encoder default). CC data from H.264 SEI is re-embedded in
  MPEG-2 user_data automatically.
- SRT input: --enable-libsrt (requires mingw-w64-x86_64-libsrt via setup-msys2-ffmpeg.bat)
- HTTPS: --enable-openssl (required for HLS sources over HTTPS, e.g. Akamai CDN)
  (requires mingw-w64-x86_64-openssl via setup-msys2-ffmpeg.bat)
- Hardware acceleration (default):
  NVENC/NVDEC: --enable-ffnvcodec --enable-nvdec --enable-nvenc --enable-cuvid
  AMF: --enable-amf
  Intel QSV: not enabled - oneVPL not available via pacman
- x264 WORKAROUND: MSYS2 x264.pc has -DX264_API_IMPORTS in Cflags which
  forces DLL import mode even when linking statically. Cflags.private has
  -UX264_API_IMPORTS but pkg-config --static does NOT include Cflags.private
  (only Libs.private). Fix: copy x264.pc to $WORK/pkgconfig/, strip
  -DX264_API_IMPORTS with sed, prepend $WORK/pkgconfig to PKG_CONFIG_PATH
  and PKG_CONFIG_LIBDIR on the configure call.
- ldd scans dist/ executables for /mingw64/bin/ deps and copies them
  (|| true prevents failure when nothing to copy - fully static build)
- Output: dist/ffmpeg-ndi-YYYYMMDD-HHMMSS/ with ffmpeg.exe, ffprobe.exe,
  ffplay.exe, Processing.NDI.Lib.x64.dll, any MinGW runtime DLLs.
  build-windows.ps1 finds the newest matching dir via Get-ChildItem to
  print the real Output / Quick test paths in the success message.

### Known Issues / Future Work
- x264/x265 require the x264.pc workaround (documented above)
- Linux/macOS scripts from lplassman carried over unchanged (not tested in this session)
- libass/freetype/harfbuzz/graphite2 chain requires --ld=g++ for C++ runtime
  (graphite2 is a C++ library, needs __gxx_personality_seh0 etc.)
- Intel QSV/oneVPL not currently supported on Windows - not in pacman,
  requires manual cmake build from github.com/intel/libvpl
- NVIDIA NVENC/NVDEC: runtime requires NVIDIA driver on target machine
- AMF: headers installed, AMD GPU required at runtime

## Build Workflow (Windows)
1. winget install -e --id MSYS2.MSYS2
2. Install NDI 6 SDK from ndi.video
3. git clone https://github.com/ShamelessWizard/FFMPEG-NDI
4. git clone https://git.ffmpeg.org/ffmpeg.git && cd ffmpeg
5. ..\FFMPEG-NDI\setup-msys2-ffmpeg.bat   (run once - installs toolchain, codec libs, nv-codec-headers, AMF)
6. ..\FFMPEG-NDI\apply-patch-windows.ps1  (applies patch + copies source files)
7. ..\FFMPEG-NDI\build-windows.ps1

## Patch Notes
- Use apply-patch-windows.ps1 instead of git am
  Uses patch --fuzz=5 which handles FFmpeg master context drift
  git am will fail as FFmpeg master moves forward

## Working Test Command
.\dist\ffmpeg-ndi-YYYYMMDD-HHMMSS\ffmpeg.exe -f libndi_newtek -i "SOURCE NAME" ^
  -c:v mpeg2video -b:v 4500k -maxrate 5000k -bufsize 2M -pix_fmt yuv420p ^
  -r 29.97 -s 1280x720 -c:a ac3 -b:a 384k -ar 48000 ^
  -f mpegts "udp://x.x.x.x:5000?pkt_size=1316"

## Environment
- Windows 11, MSYS2 MinGW64, GCC 16.1.0
- NDI 6 SDK at C:\Program Files\NDI\NDI 6 SDK
- MSYS2 at C:\msys64
