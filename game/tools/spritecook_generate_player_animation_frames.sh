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

credits_json="$(curl -sS https://api.spritecook.ai/v1/api/credits -H "Authorization: Bearer $SPRITECOOK_API")"
remaining="$(node -e "const d=JSON.parse(process.argv[1]); console.log(d.credits_remaining ?? d.remaining ?? d.subscription_credits ?? d.total ?? 0)" "$credits_json" || echo 0)"

required=48
if [[ "$remaining" -lt "$required" ]]; then
  echo "Not enough credits to generate the full requested player animation set (need >= $required, have $remaining)."
  exit 2
fi

mkdir -p ../tmp/spritecook ../assets/sprites/players/animation_frames

generate_frame() {
  local name="$1"
  local prompt="$2"
  local json_path="../tmp/spritecook/${name}.json"
  local out_path="../assets/sprites/players/animation_frames/${name}.png"

  curl -sS https://api.spritecook.ai/v1/api/generate-sync \
    -H "Authorization: Bearer $SPRITECOOK_API" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\":\"${prompt}\",\"width\":96,\"height\":96,\"variations\":1,\"pixel\":true,\"pixel_perfect\":true,\"bg_mode\":\"transparent\",\"theme\":\"retro military science fiction\",\"style\":\"detailed 2D pixel art, readable in a side-scrolling action game\",\"aspect_ratio\":\"1:1\",\"smart_crop\":false,\"mode\":\"assets\",\"model\":\"gemini-3.1-flash-lite-image\",\"resolution\":\"1K\"}" \
    > "$json_path"

  node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));const url=d?.assets?.[0]?.sprite_url||d?.assets?.[0]?.url||d?.images?.[0]?.url; if(!url){throw new Error('missing sprite url')}; require('child_process').execFileSync('curl',['-L','-sS',url,'-o',process.argv[2]],{stdio:'inherit'});" "$json_path" "$out_path"
}

generate_frame "player_rook_back_idle_01" "playable commando operative, back-facing side-scroller turnaround frame, tropical retro military sci-fi, olive tactical gear, compact proportions, full body fully visible from head to boots, transparent background, original game character sprite"
generate_frame "player_rook_shoot_northwest_01" "playable commando operative, side view aiming and shooting northwest, rifle angled up-left, tropical retro military sci-fi, full body fully visible from head to boots, transparent background, original game character sprite"
generate_frame "player_rook_shoot_northeast_01" "playable commando operative, side view aiming and shooting northeast, rifle angled up-right, tropical retro military sci-fi, full body fully visible from head to boots, transparent background, original game character sprite"
generate_frame "player_rook_shoot_north_01" "playable commando operative, side view aiming and shooting straight upward, rifle raised overhead, tropical retro military sci-fi, full body fully visible from head to boots, transparent background, original game character sprite"
generate_frame "player_rook_run_01" "playable commando operative, side view running cycle keyframe, tropical retro military sci-fi, dynamic stride, full body fully visible from head to boots, transparent background, original game character sprite"
generate_frame "player_rook_squat_01" "playable commando operative, side view squat/crouch pose, tropical retro military sci-fi, compact tactical posture, full body fully visible, transparent background, original game character sprite"

echo "Generated requested player animation source frames."
