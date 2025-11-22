#!/bin/bash
set -e

# Find the repo root relative to the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTAINER_ROOT="$(cd "$REPO_ROOT/.." && pwd)"

echo "Script Dir: $SCRIPT_DIR"
echo "Repo Root: $REPO_ROOT"



# Load emscripten environment
if [ -f "$CONTAINER_ROOT/emsdk/emsdk_env.sh"]; then
    echo "Loading emsdk environment from repo"
    source "$CONTAINER_ROOT/emsdk/emsdk_env.sh"
elif [ -n "$EMSDK" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
    echo "Loading emsdk environment from \$EMSDK=$EMSDK"
else 
    echo "Could not find emsdk_env.sh. Assuming emcc is already in PATH"
fi

echo "Listing include folders:"
ls -R "$REPO_ROOT/deps/include" || echo "❌ vendor includes not found"
ls -R "$REPO_ROOT/deps/lib" || echo "❌ vendor libs not found"


# # GLUE
emcc scripts/image_processor.c \
-o "$REPO_ROOT/src/lib/wasm/image_processor.js" \
-I "$REPO_ROOT/deps/include/jpeg" \
-I "$REPO_ROOT/deps/include/" \
-I "$REPO_ROOT/deps/include/yuv" \
-I "$REPO_ROOT/deps/include/aom" \
-I "$REPO_ROOT/deps/include/exif" \
-L "$REPO_ROOT/deps/lib" -ljpeg -lavif -laom -lyuv -lexifparser \
-s MODULARIZE=1 -s EXPORT_ES6=1 -s ENVIRONMENT=web -s \
-s EXPORTED_FUNCTIONS="['_process_image', '_is_jpeg', '_is_valid_avif_or_heic', '_find_exif_jpeg','_convert_jpeg_to_avif', '_malloc', '_free']" \
-s EXPORTED_RUNTIME_METHODS="['ccall', 'cwrap', 'HEAPU8', 'UTF8ToString', 'HEAPU32', 'getValue']" \
-s ALLOW_MEMORY_GROWTH=1 \
-s EXPORT_NAME='createWasmModule' \
-O3 



echo "✅ WASM build complete"
ls -lh src/lib/wasm/*.wasm || echo "❌ No WASM file found!"
