#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source ../.env
set +a

if [[ -z "${SPRITECOOK:-}" ]]; then
  echo "SPRITECOOK env var missing"
  exit 1
fi

credits_json="$(curl -sS https://api.spritecook.ai/v1/api/credits -H "Authorization: Bearer $SPRITECOOK")"
remaining="$(node -e "const d=JSON.parse(process.argv[1]); console.log(d.credits_remaining ?? d.remaining ?? d.total ?? 0)" "$credits_json" || echo 0)"

echo "credits_remaining=$remaining"

if [[ "$remaining" -lt 16 ]]; then
  echo "Not enough credits to generate rover+boss v2 (need >= 16)."
  exit 2
fi

mkdir -p ../tmp/spritecook

curl -sS https://api.spritecook.ai/v1/api/generate-sync \
  -H "Authorization: Bearer $SPRITECOOK" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"compact assault rover vehicle, side view, armored cab variant, chunky tires, mounted turret silhouette, stronger contrast, tropical island combat, original side-scrolling game vehicle sprite","width":192,"height":96,"variations":1,"pixel":true,"pixel_perfect":true,"bg_mode":"transparent","theme":"retro military science fiction","style":"detailed 2D pixel art, readable in a side-scrolling action game","aspect_ratio":"1:1","smart_crop":true,"mode":"assets","model":"gemini-3.1-flash-lite-image","resolution":"1K"}' \
  > ../tmp/spritecook/rover_v2.json

curl -sS https://api.spritecook.ai/v1/api/generate-sync \
  -H "Authorization: Bearer $SPRITECOOK" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"giant siege walker boss, side view, heavier industrial plating, stronger silhouette separation, readable core reactor window, orange hazard accents, original side-scrolling boss sprite","width":192,"height":192,"variations":1,"pixel":true,"pixel_perfect":true,"bg_mode":"transparent","theme":"retro military science fiction","style":"detailed 2D pixel art, readable in a side-scrolling action game","aspect_ratio":"1:1","smart_crop":true,"mode":"assets","model":"gemini-3.1-flash-lite-image","resolution":"1K"}' \
  > ../tmp/spritecook/siege_walker_v2.json

node -e "const fs=require('fs'); const {execFileSync}=require('child_process'); const get=(o,p)=>p.split('.').reduce((a,k)=>a==null?a:(/^\\d+$/.test(k)?a[Number(k)]:a[k]),o); const jobs=[['../tmp/spritecook/rover_v2.json','assets.0.sprite_url','assets/sprites/vehicles/veh_assault_rover_idle_02.png'],['../tmp/spritecook/siege_walker_v2.json','assets.0.sprite_url','assets/sprites/bosses/boss_siegewalker_body_idle_02.png']]; for (const [json,key,out] of jobs){ const d=JSON.parse(fs.readFileSync(json,'utf8')); const url=get(d,key); if(!url) throw new Error('missing url '+json); execFileSync('curl',['-L','-sS',url,'-o',out],{stdio:'inherit'}); } console.log('done');"
