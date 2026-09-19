#!/bin/bash
# deps-ios.sh — cross-build Ikemen GO native deps for iOS arm64 (static).
# Mirrors build/build.sh android fns (libvpx -> FFmpeg w/ WebM-alpha + libxmp).
# Usage: deps-ios.sh <ios-deps-prefix> <work-dir> <sdl-xcframework-headers>
# Idempotent: skips anything with a finished .pc / installed lib.
set -euo pipefail

PREFIX="$1"; WORK="$2"; SDL_HEADERS="$3"
MIN_IOS="${MIN_IOS:-17.0}"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
IOS_CFLAGS="-arch arm64 -miphoneos-version-min=$MIN_IOS -isysroot $SYSROOT -fPIC"
IOS_LDFLAGS="-arch arm64 -miphoneos-version-min=$MIN_IOS -isysroot $SYSROOT"

mkdir -p "$PREFIX" "$WORK"

echo "==> libvpx (decoder-only, static)"
if [ ! -f "$PREFIX/lib/pkgconfig/vpx.pc" ]; then
  [ -d "$WORK/libvpx" ] || git clone --depth=1 -b v1.15.2 https://github.com/webmproject/libvpx.git "$WORK/libvpx"
  mkdir -p "$WORK/libvpx-ios" && cd "$WORK/libvpx-ios"
  CC="xcrun -sdk iphoneos clang -arch arm64" CXX="xcrun -sdk iphoneos clang++ -arch arm64" \
  CFLAGS="$IOS_CFLAGS" CXXFLAGS="$IOS_CFLAGS" LDFLAGS="$IOS_LDFLAGS" \
  AR="$(xcrun --sdk iphoneos --find ar)" STRIP="$(xcrun --sdk iphoneos --find strip)" \
    "$WORK/libvpx/configure" --prefix="$PREFIX" --target=arm64-darwin-gcc \
    --enable-pic --enable-static --disable-shared \
    --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    --disable-install-bins --disable-install-docs \
    --disable-vp8-encoder --disable-vp9-encoder \
    --enable-vp8-decoder --enable-vp9-decoder --disable-webm-io
  make -j"$JOBS" && make install
  cd - >/dev/null
else echo "    cached"; fi

echo "==> FFmpeg 7.1 (minimal static, libvpx WebM-alpha)"
if [ ! -f "$PREFIX/lib/pkgconfig/libavcodec.pc" ]; then
  [ -d "$WORK/ffmpeg" ] || git clone --depth=1 -b release/7.1 https://github.com/FFmpeg/FFmpeg.git "$WORK/ffmpeg"
  cd "$WORK/ffmpeg"
  ./configure --prefix="$PREFIX" --enable-cross-compile \
    --target-os=darwin --arch=aarch64 \
    --cc="xcrun --sdk iphoneos clang -arch arm64" \
    --sysroot="$SYSROOT" \
    --extra-cflags="$IOS_CFLAGS" --extra-ldflags="$IOS_LDFLAGS" \
    --disable-shared --enable-static \
    --disable-gpl --disable-nonfree --disable-debug --disable-doc \
    --disable-programs --disable-everything --disable-autodetect \
    --enable-avformat --enable-avcodec --enable-avutil \
    --enable-swresample --enable-swscale --enable-avfilter \
    --enable-filter=buffer,buffersink,format,scale,pad,crop \
    --enable-libvpx --enable-protocol=file \
    --enable-demuxer=matroska,webm \
    --enable-decoder=libvpx_vp8,libvpx_vp9,opus,vorbis \
    --enable-parser=vp8,vp9,opus,vorbis \
    --pkg-config="$(which pkg-config)"
  grep -q '^#define CONFIG_LIBVPX_VP8_DECODER 1' config_components.h
  grep -q '^#define CONFIG_LIBVPX_VP9_DECODER 1' config_components.h
  make -j"$JOBS" && make install
  cd - >/dev/null
else echo "    cached"; fi

echo "==> libxmp (static)"
if [ ! -f "$PREFIX/lib/libxmp.a" ]; then
  [ -d "$WORK/libxmp" ] || git clone --depth=1 https://github.com/libxmp/libxmp.git "$WORK/libxmp"
  cmake -S "$WORK/libxmp" -B "$WORK/libxmp-ios" \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DBUILD_SHARED=OFF -DBUILD_STATIC=ON \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
  cmake --build "$WORK/libxmp-ios" --parallel "$JOBS"
  cmake --install "$WORK/libxmp-ios"
else echo "    cached"; fi

echo "==> sdl2.pc (SDL2/ symlink tree -> xcframework headers)"
mkdir -p "$PREFIX/include/SDL2" "$PREFIX/lib/pkgconfig"
for h in "$SDL_HEADERS"/*.h; do
  ln -sf "$h" "$PREFIX/include/SDL2/$(basename "$h")"
done
cat > "$PREFIX/lib/pkgconfig/sdl2.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: sdl2
Description: Simple DirectMedia Layer (iOS xcframework headers)
Version: 2.32.10
Cflags: -I\${includedir} -I$SDL_HEADERS
Libs:
EOF

echo "==> deps done:"; ls "$PREFIX/lib/"*.a; ls "$PREFIX/lib/pkgconfig/"
