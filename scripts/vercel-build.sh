#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$GAME/web"
GODOT_VERSION="${GODOT_VERSION:-4.5-stable}"
GODOT_HOME="${GODOT_HOME:-$HOME/godot}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/4.5.stable"

mkdir -p "$GODOT_HOME" "$TEMPLATE_DIR" "$OUT"

if [[ ! -x "$GODOT_HOME/godot" ]]; then
  echo "Installing Godot $GODOT_VERSION for Vercel build..."
  curl -L -o /tmp/godot.zip \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -o /tmp/godot.zip -d "$GODOT_HOME"
  GODOT_BIN="$(find "$GODOT_HOME" -type f -name 'Godot*' | head -n 1)"
  chmod +x "$GODOT_BIN"
  ln -sf "$GODOT_BIN" "$GODOT_HOME/godot"
fi

if [[ ! -f "$TEMPLATE_DIR/web_release.zip" && ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
  echo "Installing Godot export templates..."
  curl -L -o /tmp/godot-templates.tpz \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  rm -rf /tmp/godot-templates
  mkdir -p /tmp/godot-templates
  unzip -o /tmp/godot-templates.tpz -d /tmp/godot-templates
  if [[ -d /tmp/godot-templates/templates ]]; then
    cp -R /tmp/godot-templates/templates/* "$TEMPLATE_DIR/"
  else
    cp -R /tmp/godot-templates/* "$TEMPLATE_DIR/"
  fi
fi

echo "Exporting Godot Web build for Vercel..."
"$GODOT_HOME/godot" --path "$GAME" --headless --export-release "Web" "web/operation-steelstorm.html"

cat > "$OUT/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="refresh" content="0; url=/operation-steelstorm.html" />
    <title>Operation Steelstorm</title>
  </head>
  <body>
    <p>Redirecting to <a href="/operation-steelstorm.html">Operation Steelstorm</a>...</p>
  </body>
</html>
EOF

echo "Vercel build output ready in $OUT"
