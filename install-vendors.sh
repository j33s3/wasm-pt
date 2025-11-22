#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_ROOT="$FRONTEND_ROOT/vendor"
VENDOR_DIR="$VENDOR_ROOT/deps"
mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include"

echo "Frontend root: $FRONTEND_ROOT"
echo "Vendor dir: $VENDOR_DIR"

# -------------------------
# Preconditions
# -------------------------
if ! command -v emcmake >/dev/null 2>&1; then
  echo "❌ emcmake not found in PATH. Make sure Emscripten is installed and on PATH."
  exit 1
fi
if ! command -v emmake >/dev/null 2>&1; then
  echo "❌ emmake not found in PATH. Make sure Emscripten is installed and on PATH."
  exit 1
fi

# # helper to cleanup temp dirs
# cleanup() {
#   if [[ -n "${BUILD_DIR-}" && -d "$BUILD_DIR" ]]; then
#     rm -rf "$BUILD_DIR"
#   fi
# }
# trap cleanup EXIT

# -------------------------
# Helper for copying header files
# -------------------------
# copy_headers() {
#   src_dir="$1"
#   dest_dir="$2"
#   mkdir -p "$dest_dir"
#   cp -r "$src_dir"/* "$dest_dir/" || true
# }


# -------------------------
# Install libjpeg-turbo (JPEG)
# -------------------------
# if [ ! -d "$VENDOR_DIR/include/jpeg" ]; then
#   echo "🔍 JPEG library not found. Installing libjpeg-turbo..."
#   BUILD_DIR="$(mktemp -d)"
#   pushd "$BUILD_DIR" >/dev/null

#   git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git
#   pushd libjpeg-turbo >/dev/null
#   mkdir -p build && cd build
#   emcmake cmake .. \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
#     -DENABLE_SHARED=OFF \
#     -DWITH_SIMD=OFF
#   emmake make -j"$(nproc)" jpeg-static

#   mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/jpeg"
#   cp ./build/libjpeg.a "$VENDOR_DIR/lib/"
#   cp ./build/jconfig.h "$VENDOR_DIR/include/jpeg/"
#   cp ./src/jpeglib.h ./src/jmorecfg.h ./src/jerror.h "$VENDOR_DIR/include/jpeg/"

#   popd >/dev/null
#   popd >/dev/null
#   rm -rf "$BUILD_DIR"

#   touch "$VENDOR_ROOT/.timestamp"
#   echo "✅ JPEG library installed"
# else
#   echo "✅ JPEG library already exists. Skipping install."
# fi

# # -------------------------
# # Install libavif (AVIF) + libyuv + libaom
# # -------------------------
# if [ ! -d "$VENDOR_DIR/include/avif" ]; then
#   echo "🔍 AVIF library not found. Installing libavif + libyuv + aom..."
#   BUILD_DIR="$(mktemp -d)"
#   pushd "$BUILD_DIR" >/dev/null

#   git clone https://github.com/AOMediaCodec/libavif.git
#   pushd libavif >/dev/null

#   # libyuv
#   git clone https://chromium.googlesource.com/libyuv/libyuv
#   mkdir -p libyuv/build && pushd libyuv/build >/dev/null
#   emcmake cmake .. -DCMAKE_BUILD_TYPE=Release
#   emmake make -j"$(nproc)"
#   popd >/dev/null

#   # aom (pin to version your original script used)
#   git clone -b v3.12.1 --depth 1 https://aomedia.googlesource.com/aom
#   mkdir -p aom/build.libavif && pushd aom/build.libavif >/dev/null
#   emcmake cmake .. \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DBUILD_SHARED_LIBS=OFF \
#     -DENABLE_TESTS=OFF \
#     -DAOM_TARGET_CPU=generic \
#     -DAOM_BUILD_CMAKE_SYSTEM_PROCESSOR=wasm32 \
#     -DCONFIG_RUNTIME_CPU_DETECT=0
#   emmake make -j"$(nproc)"
#   popd >/dev/null

#   # build libavif
#   mkdir -p build && cd build
#   emcmake cmake .. \
#     -DAVIF_CODEC_AOM=LOCAL \
#     -DBUILD_SHARED_LIBS=OFF \
#     -DAVIF_LIBYUV=LOCAL \
#     -DAVIF_BUILD_APPS=OFF \
#     -DAVIF_BUILD_EXAMPLES=OFF \
#     -DAVIF_BUILD_TESTS=OFF \
#     -DCMAKE_BUILD_TYPE=Release
#   emmake make -j"$(nproc)"

#   # copy artifacts
#   mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/avif" "$VENDOR_DIR/include/aom" "$VENDOR_DIR/include/yuv"
#   cp ext/libyuv/build/libyuv.a "$VENDOR_DIR/lib/" || true
#   cp -r ext/libyuv/include/* "$VENDOR_DIR/include/yuv/" || true
#   cp ext/aom/build.libavif/libaom.a "$VENDOR_DIR/lib/" || true
#   cp -r ext/aom/aom/ "$VENDOR_DIR/include/aom/" || true
#   cp build/libavif.a "$Optional: cache the vendor folder VENDOR_DIR/lib/" || true
#   cp include/avif/*.h "$VENDOR_DIR/include/avif/" || true

#   popd >/dev/null   # libavif
#   popd >/dev/null   # BUILD_DIR
#   rm -rf "$BUILD_DIR"

#   touch "$VENDOR_ROOT/.timestamp"
#   echo "✅ AVIF library installed"
# else
#   echo "✅ AVIF library already exists. Skipping install."
# fi

# # -------------------------
# # Install libExif-pt (EXIF)
# # -------------------------
# if [ ! -d "$VENDOR_DIR/include/exif" ]; then
#   echo "🔍 EXIF library not found. Installing libExif-pt..."
#   BUILD_DIR="$(mktemp -d)"
#   pushd "$BUILD_DIR" >/dev/null

#   git clone https://github.com/j33s3/libExif-pt.git
#   pushd libExif-pt >/dev/null
#   mkdir -p build && cd build
#   emcmake cmake .. \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DVERBOSE=1 \
#     -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
#     -DENABLE_SHARED=OFF
#   emmake make -j"$(nproc)"

#   mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/exif"
#   cp build/libexifparser.a "$VENDOR_DIR/lib/" || true
#   cp include/*.h "$VENDOR_DIR/include/exif/" || true

#   popd >/dev/null
#   popd >/dev/null
#   rm -rf "$BUILD_DIR"

#   touch "$VENDOR_ROOT/.timestamp"
#   echo "✅ EXIF library installed"
# else
#   echo "✅ EXIF library already exists. Skipping install."
# fi

# echo "All vendor installs complete."


if [ ! -d "$VENDOR_DIR/include/jpeg" ]; then
  echo "🔍 JPEG library not found. Installing..."

# ** JPEG
    git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git && \
        cd libjpeg-turbo && \
            mkdir build && cd build && \
            emcmake cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_SHARED=OFF \
            -DWITH_SIMD=OFF && \
            emmake make -j$(nproc) jpeg-static
        cd .. && \
            mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/jpeg" && \
            cp ./build/libjpeg.a "$VENDOR_DIR/lib" && \
            cp ./build/jconfig.h "$VENDOR_DIR/include/jpeg" && \
            cp ./src/jpeglib.h ./src/jmorecfg.h ./src/jerror.h "$VENDOR_DIR/include/jpeg"
      
      # For breaking docker caching
      touch "$VENDOR_ROOT/.timestamp"

    ls -lh "$VENDOR_DIR/include/jpeg" && echo "✅ JPEG library installed" || echo "❌ Failed to install JPEG library"

    # back to working dir and remove left over files
    cd ..
    rm -rf libjpeg-turbo
    ls -lh libjpeg-turbo && echo "❌ JPEG cleanup failed" || echo "✅ JPEG cleanup Success"
else
  echo "✅ JPEG library already exists. Skipping install."
fi




if [ ! -d "$VENDOR_DIR/include/avif" ]; then
  echo "🔍 AVIF library not found. Installing..."

  # ** AVIF
  git clone https://github.com/AOMediaCodec/libavif.git && \
      cd libavif/ext && \
        git clone https://chromium.googlesource.com/libyuv/libyuv && \
      mkdir libyuv/build && cd libyuv/build && \
        emcmake cmake .. -DCMAKE_BUILD_TYPE=Release && \
        emmake make -j$(nproc) && \
      cd ../.. && \
        git clone -b v3.12.1 --depth 1 https://aomedia.googlesource.com/aom && \
        mkdir aom/build.libavif && \
      cd aom/build.libavif && \
        emcmake cmake .. \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_SHARED_LIBS=OFF \
          -DENABLE_TESTS=OFF \
          -DAOM_TARGET_CPU=generic \
          -DAOM_BUILD_CMAKE_SYSTEM_PROCESSOR=wasm32 \
          -DCONFIG_RUNTIME_CPU_DETECT=0 && \
        emmake make -j$(nproc) && \
      cd ../../../ && \
        mkdir build && cd build && \
        emcmake cmake .. \
          -DAVIF_CODEC_AOM=LOCAL \
          -DBUILD_SHARED_LIBS=OFF \
          -DAVIF_LIBYUV=LOCAL \
          -DAVIF_BUILD_APPS=OFF \
          -DAVIF_BUILD_EXAMPLES=OFF \
          -DAVIF_BUILD_TESTS=OFF \
          -DCMAKE_BUILD_TYPE=Release && \
        emmake make -j$(nproc) && \
      cd .. && \
        mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/avif" "$VENDOR_DIR/include/aom" "$VENDOR_DIR/include/yuv" && \
        cp ext/libyuv/build/libyuv.a "$VENDOR_DIR/lib" && \
        cp -r ext/libyuv/include/* "$VENDOR_DIR/include/yuv" && \
        cp ext/aom/build.libavif/libaom.a "$VENDOR_DIR/lib" && \
        cp -r ext/aom/aom/ "$VENDOR_DIR/include/aom" && \
        cp build/libavif.a "$VENDOR_DIR/lib" && \
        cp include/avif/*.h "$VENDOR_DIR/include/avif"

      # For breaking docker caching
      touch "$VENDOR_ROOT/.timestamp"

      ls -lh "$VENDOR_DIR/include/avif" && echo "✅ AVIF library installed" || echo "❌ Failed to install AVIF library"
      
      # back to working dir and remove left over files
      cd ..
      rm -rf libavif
      ls -lh libavif && echo "❌ AVIF cleanup failed" || echo "✅ AVIF cleanup Success"
else
  echo "✅ AVIF library already exists. Skipping install."
fi


if [ ! -d "$VENDOR_DIR/include/exif" ]; then
  echo "🔍 EXIF library not found. Installing..."

  git clone https://github.com/j33s3/libExif-pt && \
    cd libExif-pt && \
    mkdir build && cd build && \
    emcmake cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DVERBOSE=1 \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DENABLE_SHARED=OFF && \
    emmake make -j$(nproc) && \
    cd .. && \
    mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/exif" && \
    cp build/libexifparser.a "$VENDOR_DIR/lib" && \
    cp include/*.h "$VENDOR_DIR/include/exif"

    # For breaking docker caching
    touch "$VENDOR_ROOT/.timestamp"

    ls -lh "$VENDOR_DIR/include/exif" && echo "✅ EXIF library installed" || echo "❌ Failed to install EXIF library"
    
    # back to working dir and remove left over files
    cd ..
    rm -rf libExif-pt
    ls -lh libExif-pt && echo "❌ EXIF cleanup failed" || echo "✅ EXIF cleanup Success"

else
  echo "✅ EXIF library already exists. Skipping install."
fi