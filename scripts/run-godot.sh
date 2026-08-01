#!/usr/bin/env bash
# Launch Operation Steelstorm Godot project (game/ subfolder).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if [[ -x /tmp/godot-extract/Godot.app/Contents/MacOS/Godot ]]; then
    GODOT_BIN=/tmp/godot-extract/Godot.app/Contents/MacOS/Godot
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
  fi
fi

if [[ -z "${GODOT_BIN}" || ! -x "$GODOT_BIN" ]]; then
  echo "Godot executable not found. Set GODOT_BIN or install Godot."
  echo "Then open folder: $GAME"
  exit 1
fi

echo "Opening Godot project: $GAME"
exec "$GODOT_BIN" --path "$GAME" "$@"
