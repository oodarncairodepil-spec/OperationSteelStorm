# Phase 4 Asset Ideation — SpriteCook Generation Plan

## Purpose

This document defines how Phase 4 art assets should be **invented, generated, reviewed, named, refined, and imported** for the vertical slice of **Operation Steelstorm**.

It is not just an art wish list.

It is a practical production plan built around the current repo structure, the existing `docs/asset-guide.md`, and a live `SpriteCook` API connection verified from this workspace.

## Why This Exists

Earlier phases could survive on rectangles, labels, and simple stand-ins.

Phase 4 cannot.

The moment the game adds:

- a mission arc
- civilian rescue
- a rover
- multiple weapon identities
- a multi-part boss
- results presentation

the placeholder approach stops carrying the experience.

The vertical slice needs assets that communicate:

- role
- threat
- weapon function
- interactability
- state changes
- mission progress

This document turns asset generation into a deliberate workflow instead of an improvised prompt spree.

## Inputs Already Locked By The Project

From `docs/asset-guide.md` and `docs/gameplay-design.md`, the visual direction is already constrained by these rules:

- detailed 2D pixel art
- retro military science-fiction
- bright tropical environments
- dark mechanical enemies
- exaggerated animation
- original comedic reactions
- side-view readability
- crisp pixel treatment at the project's scale

Asset size guidance already exists for:

- players
- enemies
- vehicles
- boss parts
- tiles
- projectiles
- UI icons

That means the real Phase 4 task is not "pick a style from scratch."

The task is to generate a **consistent original visual library** that obeys those constraints.

## Primary Art Thesis

The asset set should read as:

- **hero side:** colorful tropical resistance/spec-ops energy
- **enemy side:** darker angular industrial automation
- **environment side:** warm island light colliding with cold machinery
- **UI side:** clean military overlays with arcade clarity

Short version:

**sunlit tropical battlefield + chunky readable pixel silhouettes + hostile industrial machine faction**

## Live SpriteCook Connection Status

The `SpriteCook` API key from `.env` was used successfully from this workspace on 2026-08-01.

Verified live API calls:

- `GET /v1/api/models`
- `GET /v1/api/credits`
- `POST /v1/api/generate-sync`

Live credit state observed before sample generation:

- total credits: `80`
- tier: `free`
- concurrent jobs: `1`

Three low-cost probe generations were completed successfully with `gemini-3.1-flash-lite-image` at `1K` resolution and `pixel=true`.

### Probe assets

| Probe | Purpose | Asset ID | Returned size | Credits used |
|------|---------|----------|---------------|--------------|
| Operative anchor | Test player-facing hero silhouette | `914641de-3ca9-41fc-a849-5e7d363e9ad1` | `66x66` | `8` |
| Shield trooper anchor | Test enemy readability and faction silhouette | `975a0268-cf87-4f12-b47e-2a527d2190a9` | `132x132` | `8` |
| Rover anchor | Test vehicle width and side-view readability | `9816dddb-b80b-4823-8e2d-f9c618cedd50` | `128x64` | `8` |

Live credit state observed after the probe set:

- remaining credits: `56`

Important operational note:

- signed asset URLs are temporary
- `asset_id` is the stable thing to preserve in docs/manifests
- future consistent generations should use saved reference asset IDs rather than relying on expiring URLs

## Current Model Snapshot

The live `GET /v1/api/models` response exposed these useful options for planning:

| Model | Best use | 1K cost | Notes |
|------|----------|---------|-------|
| `gemini-3.1-flash-lite-image` | cheap ideation passes | `8` | best for fast exploration |
| `gpt-image-2` | higher control / quality tuning | `9` at medium | supports quality levels |
| `gemini-3.1-flash-image` | stronger default baseline | `12` | good when exploration narrows |
| `gemini-3-pro-image` | expensive special passes | `16` | reserve for priority hero shots |

Recommended production default for this project:

- ideation and exploration: `gemini-3.1-flash-lite-image`
- anchor/keeper stills: `gemini-3.1-flash-image` or `gpt-image-2`
- do not use expensive models for bulk experimentation until silhouettes are approved

## Core Generation Strategy

Do **not** generate assets randomly by category.

Generate them in layers:

### Layer 1. Style anchors

Create a tiny set of "truth assets" first:

- one operative anchor
- one enemy anchor
- one environment prop anchor
- one UI anchor
- one vehicle anchor
- one boss-part anchor

These are not final shipping art yet.

They establish:

- palette tendencies
- line density
- material readability
- silhouette chunkiness
- scale expectations

### Layer 2. Family variants

Once anchor art is approved, generate related assets by referencing the family anchor.

Examples:

- operative weapon poses from operative anchor
- shield trooper hurt/death variants from shield trooper anchor
- rover damaged/exploding states from rover anchor

### Layer 3. Animation source frames

After stills are approved, decide case-by-case whether to:

- animate in SpriteCook
- hand-edit frames
- use hybrid workflows

Not every asset needs AI-generated animation immediately.

For Phase 4, **stills and readable state variants matter more than full animation luxury**.

## Asset Priorities

Use this exact order. It matches gameplay dependency, not artistic preference.

### Priority 0: must exist before Phase 4 feels real

- player operative visual anchor
- shield trooper
- drone
- heavy gunner
- civilian
- scatter cannon pickup icon/sprite
- rapid pulse gun pickup icon/sprite
- Assault Rover
- Siege Walker body anchor
- mission UI result panel

### Priority 1: must exist before the slice feels polished enough to present

- player hurt/downed/revive states
- enemy hit/death states
- rescue indicator assets
- boss weak-point and telegraph FX
- mission signage props
- environment prop kit
- projectile and muzzle FX

### Priority 2: should exist if time and credits permit

- character portrait UI
- extra prop variants
- boss debris variations
- environmental storytelling props
- alternate civilian silhouettes

## Asset Inventory By Family

### 1. Player assets

Needed for Phase 4:

- operative idle
- operative run
- operative jump/fall
- operative crouch
- operative rifle firing
- operative upward firing
- operative hurt
- operative downed
- operative revive
- optional throw/grenade windup

Ideation goals:

- readable head/torso separation
- expressive face even at small scale
- compact proportions that do not fight the camera
- tactical gear without over-detailing
- silhouette readable from enemy silhouettes

Prompt direction:

- playable commando
- side view
- tropical retro military sci-fi
- expressive face
- compact proportions
- original game character

### 2. Enemy assets

#### Patrol trooper

Goal:

- baseline enemy readability

Visual notes:

- simplest AAD infantry silhouette
- rifle-ready posture
- darker than player but not visually muddy

#### Shield trooper

Goal:

- instantly communicates frontal denial

Visual notes:

- oversized shield silhouette
- broad front profile
- shield and body read separately

#### Drone unit

Goal:

- readable aerial harassment

Visual notes:

- distinct hover shape
- glowing sensors or propulsor read points
- simple underside danger language

#### Heavy gunner

Goal:

- telegraphed slow threat

Visual notes:

- bulkier mass
- heavier weapon silhouette
- anticipation pose should read before firing

### 3. Civilian assets

Needed for the rescue sequence:

- idle captive
- distress/reaction
- rescued or released variant

Ideation goals:

- clearly non-combatant
- high readability against industrial background
- sympathetic but not overly realistic

### 4. Weapon assets

Needed:

- rifle icon refinement if desired
- scatter cannon pickup/world sprite
- rapid pulse gun pickup/world sprite
- frag charge icon/world sprite if retained

Ideation goals:

- weapon silhouettes readable at tiny pickup scale
- immediate differentiation from one another
- color language supports weapon role

### 5. Vehicle assets

Needed:

- rover idle base
- rover moving/dust state
- rover damaged state
- rover explosion or wreck state

Ideation goals:

- low profile
- chunky wheel read
- side-scrolling friendly shape
- turret silhouette that remains readable even if gameplay is simplified

### 6. Boss assets

Needed:

- Siege Walker body anchor
- leg components or readable lower structure
- attack tell variants
- weak-point state
- damage/break state
- death collapse concept

Ideation goals:

- huge but readable
- not too detailed for 640x360 composition
- different from standard enemies at first glance
- believable as a mission climax

### 7. Environment assets

Needed:

- cargo pier props
- smelter props
- tropical industrial set dressing
- lockup props
- rover yard props
- drydock arena props

Ideation goals:

- environment supports mission beats
- props clarify place and pacing
- tropical warmth and industrial cold coexist

### 8. UI assets

Needed:

- weapon icons
- rescue icon/state badge
- boss warning badge
- results screen treatment
- mission objective markers

Ideation goals:

- clean arcade readability
- military framing without clutter
- usable on both native and web export

## Style Guardrails

Every generation prompt and review pass should enforce these rules:

- original designs only
- no references to commercial franchises or character names
- no over-rendered painterly look
- no front-facing perspective for side-scroller gameplay assets unless the asset is explicitly UI
- no muddy low-contrast mechanical enemies
- no giant decorative micro-detail that disappears at gameplay size
- no realistic firearm fetish styling that overwhelms silhouette clarity

## Generation Prompt Structure

Use this prompt format:

`subject + gameplay role + camera/view + shape language + material language + setting context + readability rule + originality rule`

Example:

`enemy shield trooper robot, side view, broad armored silhouette with a large frontal shield, dark industrial military sci-fi plating, tropical smelter setting context, readable in a side-scrolling action game, original game enemy sprite`

This structure works better than vague "cool pixel art" prompting because it encodes gameplay readability.

## Baseline SpriteCook Settings

Recommended defaults for early Phase 4 ideation:

```json
{
  "width": 64,
  "height": 64,
  "variations": 1,
  "pixel": true,
  "pixel_perfect": true,
  "bg_mode": "transparent",
  "theme": "retro military science fiction",
  "style": "detailed 2D pixel art, readable in a side-scrolling action game",
  "aspect_ratio": "1:1",
  "smart_crop": true,
  "mode": "assets",
  "model": "gemini-3.1-flash-lite-image",
  "resolution": "1K"
}
```

Adjust size hints by asset class:

- humanoids: `64x64`
- drones: `48x48` to `64x64`
- pickups/icons: `32x32` or `64x64`
- rover: `128x64`
- boss body concepts: `160x160` or larger
- prop concepts: `64x64` or `96x96`

## Live Prompt Recipes

These prompts are aligned with the project and were either used directly in the probe set or derived from that successful structure.

### Operative anchor

```json
{
  "prompt": "playable commando operative, side view, tropical retro military sci-fi, olive tactical gear, expressive face, compact proportions, clean silhouette, idle pose, original game character sprite"
}
```

### Shield trooper anchor

```json
{
  "prompt": "enemy shield trooper robot, side view, dark mechanical armor, tropical-industrial military sci-fi, readable shield silhouette, aggressive stance, original side-scrolling game sprite"
}
```

### Assault Rover anchor

```json
{
  "prompt": "compact assault rover vehicle, side view, two-seat military sci-fi buggy, chunky tires, mounted turret silhouette, tropical island combat, original side-scrolling game vehicle sprite"
}
```

### Civilian rescue anchor

```json
{
  "prompt": "civilian worker hostage, side view, tropical industrial island setting, bright utilitarian clothing, anxious expression, readable non-combat silhouette, original side-scrolling game sprite"
}
```

### Siege Walker anchor

```json
{
  "prompt": "giant siege walker boss, side view, heavy industrial military machine, multi-leg silhouette, readable cockpit and weapon pods, dark mechanical enemy faction, original side-scrolling boss sprite"
}
```

## Consistency Workflow

The most important rule for Phase 4 asset generation:

**once a family anchor is approved, stop prompting that family from scratch**

Instead:

1. save the approved `asset_id`
2. treat it as the reference source
3. generate adjacent variants from that reference
4. keep a manifest of family relationships

Suggested first anchor manifest:

```json
{
  "operative_anchor_asset_id": "914641de-3ca9-41fc-a849-5e7d363e9ad1",
  "shield_trooper_anchor_asset_id": "975a0268-cf87-4f12-b47e-2a527d2190a9",
  "rover_anchor_asset_id": "9816dddb-b80b-4823-8e2d-f9c618cedd50"
}
```

This prevents "same faction, totally different rendering logic" drift.

## Proposed Asset Manifest

Store a lightweight manifest later in the repo once generation starts in earnest.

Suggested path:

- `game/assets/sprites/spritecook-manifest.json`

Suggested structure:

```json
{
  "families": {
    "operative": {
      "anchor_asset_id": "replace_me",
      "variants": {
        "idle": "replace_me",
        "run": "replace_me",
        "hurt": "replace_me"
      }
    },
    "shield_trooper": {
      "anchor_asset_id": "replace_me",
      "variants": {
        "idle": "replace_me",
        "attack": "replace_me",
        "death": "replace_me"
      }
    }
  }
}
```

This should record:

- stable asset IDs
- local exported file names
- family grouping
- intended in-game use

## Naming Convention

Keep using the repo naming guide from `docs/asset-guide.md`.

Examples:

- `player_rook_idle_01.png`
- `enemy_shieldtrooper_attack_03.png`
- `veh_assault_rover_idle_01.png`
- `boss_siegewalker_core_telegraph_01.png`
- `ui_rescue_badge.png`

If an asset originates in SpriteCook, append the source ID inside the manifest, not the file name.

Do **not** put raw UUIDs in shipping asset file names.

## Review Checklist For Every Generated Asset

Before importing an asset, ask:

- does the silhouette read at gameplay size?
- does it match the faction family?
- is the value contrast strong enough?
- does it look original?
- does it fit side-view gameplay?
- is the shape readable against tropical and industrial backgrounds?
- does it need manual cleanup before use?

If two or more answers are "no", do not import it yet.

## Post-Generation Cleanup Workflow

SpriteCook should be treated as the generator, not the whole art pipeline.

Expected cleanup steps:

1. export the chosen asset
2. trim or pad to project-friendly dimensions
3. align pivot expectations with `docs/asset-guide.md`
4. fix stray pixels or silhouette noise
5. standardize palette/value where needed
6. import into Godot with nearest filtering
7. verify readability in-motion inside the actual camera framing

## Animation Plan

Phase 4 should not assume every animation must be fully AI-generated from day one.

Use this order:

### For characters and enemies

- lock still silhouette first
- create key gameplay states second
- animate only the states that are needed to ship the vertical slice

### For the rover

- still base
- damaged state
- movement embellishment
- explosion/wreck

### For the boss

- intro pose
- idle threat pose
- attack tell state
- attack state
- break/damage state
- death state

If animation quality slips below readability standards, ship fewer animations with cleaner frames.

## Credit Budgeting

The live probe showed a reliable low-cost exploration pattern:

- `gemini-3.1-flash-lite-image`
- `1K`
- `pixel=true`
- `variations=1`
- `8 credits` per generated image in the current model snapshot

Planning budget example:

- 5 anchor explorations: `40 credits`
- 10 follow-up keeper passes: `80 credits`
- 10 variant experiments: `80 credits`

That means a full exploration sprint can become expensive quickly if prompts are unfocused.

Therefore:

- approve text direction before batch generation
- generate anchors first
- avoid bulk variation spam
- reuse approved asset IDs as references

## Recommended Generation Sprint

### Sprint 1: identity lock

Generate:

- 2 operative anchors
- 2 shield troopers
- 1 drone
- 1 heavy gunner
- 1 civilian
- 1 rover
- 1 boss anchor

Goal:

- lock the visual language

### Sprint 2: gameplay coverage

Generate:

- player state variants
- enemy role variants
- pickup assets
- rescue UI assets
- boss telegraph concepts

Goal:

- support playable mission content

### Sprint 3: presentation support

Generate:

- results screen motif
- extra props
- polish FX
- alternate damage states

Goal:

- make the slice presentable externally

## Godot Import Targets

Likely target folders based on current repo structure:

- `game/assets/sprites/players/`
- `game/assets/sprites/enemies/`
- `game/assets/sprites/vehicles/`
- `game/assets/sprites/bosses/`
- `game/assets/sprites/ui/`
- `game/assets/tilesets/phase4/`
- `game/assets/placeholders/phase4/` for transitional testing if needed

The repo does not currently contain these subfolders yet, but this is the cleanest future layout.

## Risks And Mitigations

### Risk: inconsistent family look

Mitigation:

- use anchor assets
- save `asset_id`s
- generate by family, not by mood

### Risk: generated assets are too detailed

Mitigation:

- review at gameplay scale early
- favor chunkier shapes
- lower detail density in prompt wording

### Risk: boss art overwhelms the screen

Mitigation:

- test boss concepts inside actual arena framing
- keep major forms readable from a distance

### Risk: UI style clashes with world art

Mitigation:

- generate one UI anchor early
- keep UI cleaner and flatter than gameplay sprites

### Risk: credit burn without output quality

Mitigation:

- set generation batches in advance
- review each batch before the next one
- do not brute-force style decisions

## Recommended Immediate Decisions

Before a full asset sprint begins, approve these:

1. Which operative silhouette becomes the hero baseline.
2. Whether the AAD faction leans more angular-industrial or rounded-industrial.
3. Whether civilians are workers, scientists, or mixed island labor silhouettes.
4. Whether the rover is open-frame or armored-cab in the final silhouette.
5. Whether the boss weak point is a cockpit core, leg joints, or exposed reactor.

## Best Next Actions

1. Generate the remaining anchor families not yet probed: civilian, drone, heavy gunner, boss, and one UI anchor.
2. Save all approved anchor `asset_id`s into a repo manifest.
3. Export the chosen assets into structured sprite folders.
4. Test each imported asset in actual 640x360 gameplay framing before mass generation.
5. Only then move into animation and large batch production.
