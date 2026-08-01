#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source ../.env
set +a

SPRITECOOK_API="${SPRITECOOKLAP:-${SPRITECOOK:-}}"
if [[ -z "${SPRITECOOK_API}" ]]; then
  echo "SpriteCook API key missing (expected SPRITECOOKLAP or SPRITECOOK)."
  exit 1
fi

mkdir -p ../tmp/spritecook

credits_json="$(curl -sS https://api.spritecook.ai/v1/api/credits -H "Authorization: Bearer $SPRITECOOK_API")"
remaining="$(node -e "const d=JSON.parse(process.argv[1]); console.log(d.credits_remaining ?? d.remaining ?? d.subscription_credits ?? d.total ?? 0)" "$credits_json" || echo 0)"
if [[ "$remaining" -lt 16 ]]; then
  echo "Not enough credits to regenerate both full-body variants (need >= 16, have $remaining)."
  exit 2
fi

echo "Regenerating full-body player/shield variants..."

curl -sS https://api.spritecook.ai/v1/api/generate-sync \
  -H "Authorization: Bearer $SPRITECOOK_API" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"playable commando operative, side view, tropical retro military sci-fi, olive tactical gear, expressive face, compact proportions, rifle ready pose, full body fully visible from head to boots, entire arms and weapon fully inside frame, no cropped limbs, transparent background, original game character sprite","width":96,"height":96,"variations":1,"pixel":true,"pixel_perfect":true,"bg_mode":"transparent","theme":"retro military science fiction","style":"detailed 2D pixel art, readable in a side-scrolling action game","aspect_ratio":"1:1","smart_crop":false,"mode":"assets","model":"gemini-3.1-flash-lite-image","resolution":"1K"}' \
  > ../tmp/spritecook/player_rook_idle_02_regen.json

curl -sS https://api.spritecook.ai/v1/api/generate-sync \
  -H "Authorization: Bearer $SPRITECOOK_API" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"enemy shield trooper robot, side view, dark mechanical armor, tropical-industrial military sci-fi, readable shield silhouette, aggressive stance, full body fully visible from head to feet, entire shield and weapon fully inside frame, no cropped limbs, transparent background, original side-scrolling game sprite","width":160,"height":160,"variations":1,"pixel":true,"pixel_perfect":true,"bg_mode":"transparent","theme":"retro military science fiction","style":"detailed 2D pixel art, readable in a side-scrolling action game","aspect_ratio":"1:1","smart_crop":false,"mode":"assets","model":"gemini-3.1-flash-lite-image","resolution":"1K"}' \
  > ../tmp/spritecook/enemy_shieldtrooper_idle_02_regen.json

node - <<'NODE'
const fs = require('fs');
const { execFileSync } = require('child_process');

const jobs = [
  ['../tmp/spritecook/player_rook_idle_02_regen.json', 'assets/sprites/players/player_rook_idle_02.png'],
  ['../tmp/spritecook/enemy_shieldtrooper_idle_02_regen.json', 'assets/sprites/enemies/enemy_shieldtrooper_idle_02.png'],
];

function firstUrl(data) {
  const candidates = [
    data?.assets?.[0]?.sprite_url,
    data?.assets?.[0]?.url,
    data?.asset?.sprite_url,
    data?.asset?.url,
    data?.images?.[0]?.url,
  ];
  return candidates.find(Boolean);
}

for (const [jsonPath, outPath] of jobs) {
  const payload = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const url = firstUrl(payload);
  if (!url) {
    throw new Error(`Missing sprite URL in ${jsonPath}: ${JSON.stringify(payload).slice(0, 300)}`);
  }
  execFileSync('curl', ['-L', '-sS', url, '-o', outPath], { stdio: 'inherit' });
}
NODE

echo "Done. Reimport in Godot if needed."
