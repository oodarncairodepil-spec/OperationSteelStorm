#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$ROOT/game/web}"
HTML_FILE="$OUT_DIR/operation-steelstorm.html"
JS_FILE="$OUT_DIR/operation-steelstorm.js"
WASM_FILE="$OUT_DIR/operation-steelstorm.wasm"
WASM_PUBLIC_URL="${WASM_PUBLIC_URL:-}"
DELETE_LOCAL_WASM="${DELETE_LOCAL_WASM:-1}"

if [[ -z "$WASM_PUBLIC_URL" ]]; then
  echo "WASM_PUBLIC_URL is required." >&2
  exit 1
fi

if [[ ! -f "$HTML_FILE" || ! -f "$JS_FILE" ]]; then
  echo "Expected exported web files in $OUT_DIR." >&2
  exit 1
fi

if ! grep -q "window.GODOT_WASM_URL" "$HTML_FILE"; then
  WASM_PUBLIC_URL="$WASM_PUBLIC_URL" perl -0pi -e '
    my $url = $ENV{"WASM_PUBLIC_URL"};
    s/const GODOT_THREADS_ENABLED = false;\n/const GODOT_THREADS_ENABLED = false;\nwindow.GODOT_WASM_URL = "$url";\n/;
  ' "$HTML_FILE"
fi

if ! grep -q "window.GODOT_WASM_URL ||" "$JS_FILE"; then
  perl -0pi -e '
    s/return `\$\{loadPath\}\.wasm`;/return window.GODOT_WASM_URL || `\$\{loadPath\}\.wasm`;/g;
    s/loadPromise = preloader\.loadPromise\(`\$\{loadPath\}\.wasm`, size, true\);/loadPromise = preloader.loadPromise(window.GODOT_WASM_URL || `\$\{loadPath\}\.wasm`, size, true);/g;
  ' "$JS_FILE"
fi

if [[ "$DELETE_LOCAL_WASM" == "1" && -f "$WASM_FILE" ]]; then
  rm -f "$WASM_FILE"
fi

echo "Configured web export to load WebAssembly from $WASM_PUBLIC_URL"
