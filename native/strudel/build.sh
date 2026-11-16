#!/usr/bin/env bash
# Builds the Strudel GDExtension (JsRuntime + StrudelSynth) into native/strudel/bin/.
#   native/strudel/build.sh            # Linux x86_64 (cmake, a C/C++ compiler)
#   native/strudel/build.sh windows    # cross-build, needs mingw-w64
#                                         # (Arch: pacman -S mingw-w64-gcc)
# Dependencies are cloned at pinned commits into .deps/ (gitignored; Godot
# skips dot-directories).
set -euo pipefail
cd "$(dirname "$0")"

GODOT_CPP_REF=507ed9d840c01a3c5b2a39af8bb4000bfac30bf5  # 10.0.0-stable
QUICKJS_REF=947ffe4a22426666f209be5835b25d0cb45440fd    # quickjs-ng, 2026-11-13
PLATFORM="${1:-linux}"

fetch() {  # <dir> <url> <commit>
	if [[ ! -d ".deps/$1/.git" ]]; then
		git init -q ".deps/$1"
		git -C ".deps/$1" remote add origin "$2"
	fi
	if [[ "$(git -C ".deps/$1" rev-parse -q --verify HEAD 2>/dev/null)" != "$3" ]]; then
		git -C ".deps/$1" fetch -q --depth 1 origin "$3"
		git -C ".deps/$1" checkout -q FETCH_HEAD
	fi
}
fetch godot-cpp https://github.com/godotengine/godot-cpp.git "$GODOT_CPP_REF"
fetch quickjs https://github.com/quickjs-ng/quickjs.git "$QUICKJS_REF"

ARGS=(-DCMAKE_BUILD_TYPE=Release
	"-DGODOT_CPP_DIR=$PWD/.deps/godot-cpp" "-DQUICKJS_DIR=$PWD/.deps/quickjs")
if [[ "$PLATFORM" == windows ]]; then
	ARGS+=(-DCMAKE_SYSTEM_NAME=Windows
		-DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc
		-DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++)
fi
cmake -S . -B ".build/$PLATFORM" "${ARGS[@]}"
cmake --build ".build/$PLATFORM" -j "$(nproc)"
ls -l bin/
