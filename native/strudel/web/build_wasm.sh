#!/usr/bin/env bash
# Builds the synth as a freestanding WebAssembly module for the web build
# (needs clang with the wasm32 target and wasm-ld; no emscripten, no libc).
#   native/strudel/web/build_wasm.sh [out.wasm]
# The output (presentation/audio/music/synth.wasm, loaded by music_web.js)
# is committed; rebuild after changing src/synth.c.
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-../../../presentation/audio/music/synth.wasm}"
clang --target=wasm32 -O2 -nostdlib -ffreestanding -fno-builtin -Wall -Wextra \
	-Wl,--no-entry -Wl,--strip-all -Wl,--initial-memory=4194304 \
	-o "$OUT" synth_wasm.c
ls -l "$OUT"
