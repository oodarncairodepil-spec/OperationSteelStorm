#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$(cd "$(dirname "$0")" && pwd)/build-web-export.sh"

if [[ -n "${WASM_PUBLIC_URL:-}" ]]; then
  echo "Rewriting Cloudflare web export to load WebAssembly from R2/public storage..."
  bash "$ROOT/scripts/offload-web-wasm.sh" "$ROOT/game/web"
fi
