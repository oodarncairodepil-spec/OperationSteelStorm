#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source ../.env
set +a

SPRITECOOK_API="${SPRITECOOKSUPER:-}"
if [[ -z "${SPRITECOOK_API}" ]]; then
  echo "SPRITECOOKSUPER env var missing."
  exit 1
fi

credits_json="$(curl -sS https://api.spritecook.ai/v1/api/credits -H "Authorization: Bearer $SPRITECOOK_API")"
remaining="$(node -e "const d=JSON.parse(process.argv[1]); console.log(d.credits_remaining ?? d.remaining ?? d.subscription_credits ?? d.total ?? 0)" "$credits_json" || echo 0)"
required=35
if [[ "$remaining" -lt "$required" ]]; then
  echo "Not enough credits to generate player idle + walk cycle (need >= $required, have $remaining)."
  exit 2
fi

mkdir -p ../tmp/spritecook

generate_frame() {
  local name="$1"
  local prompt="$2"
  local json_path="../tmp/spritecook/${name}.json"
  local out_path="assets/sprites/players/${name}.png"

  curl -sS https://api.spritecook.ai/v1/api/generate-sync \
    -H "Authorization: Bearer $SPRITECOOK_API" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\":\"${prompt}\",\"width\":128,\"height\":128,\"variations\":1,\"pixel\":true,\"pixel_perfect\":true,\"bg_mode\":\"transparent\",\"theme\":\"retro military science fiction\",\"style\":\"high-clarity detailed 2D pixel art, crisp readable edges, sharp anti-blur pixel treatment, readable in a side-scrolling action game\",\"aspect_ratio\":\"1:1\",\"smart_crop\":false,\"mode\":\"assets\",\"model\":\"gpt-image-2\",\"quality\":\"medium\",\"resolution\":\"2K\"}" \
    > "$json_path"

  node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));const url=d?.assets?.[0]?.sprite_url||d?.assets?.[0]?.url||d?.images?.[0]?.url; if(!url){throw new Error('missing sprite url')}; require('child_process').execFileSync('curl',['-L','-sS',url,'-o',process.argv[2]],{stdio:'inherit'});" "$json_path" "$out_path"
}

generate_frame "player_rook_idle_02" "playable commando operative, side view, green tactical fatigues and black rifle, tropical retro military sci-fi, compact heroic proportions, whole body fully visible from head to boots, crisp readable pixel silhouette, idle ready stance, transparent background, original game character sprite"
generate_frame "player_rook_walk_01" "same playable commando operative, side view walk cycle frame 1, left leg forward, rifle carried ready, green tactical fatigues, whole body fully visible from head to boots, crisp readable pixel silhouette, transparent background, original game character sprite"
generate_frame "player_rook_walk_02" "same playable commando operative, side view walk cycle frame 2, passing step, rifle carried ready, green tactical fatigues, whole body fully visible from head to boots, crisp readable pixel silhouette, transparent background, original game character sprite"
generate_frame "player_rook_walk_03" "same playable commando operative, side view walk cycle frame 3, right leg forward, rifle carried ready, green tactical fatigues, whole body fully visible from head to boots, crisp readable pixel silhouette, transparent background, original game character sprite"
generate_frame "player_rook_walk_04" "same playable commando operative, side view walk cycle frame 4, passing step mirrored, rifle carried ready, green tactical fatigues, whole body fully visible from head to boots, crisp readable pixel silhouette, transparent background, original game character sprite"

echo "Generated player idle + walk cycle."
