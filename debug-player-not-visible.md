[OPEN] Debug Session: player-not-visible

## Symptom
- Player character is not visible in-game.

## Expected
- Player sprite is visible (Sprite2D renders) in gameplay scenes.

## Actual
- Player is missing / invisible.

## Hypotheses
- H1: Player node is not spawned / added to scene tree (scene logic regression).
- H2: Player is spawned but Sprite2D is hidden, fully transparent, or scale is ~0.
- H3: Player is spawned but camera / z-index / canvas layer causes it to render off-screen or behind something.
- H4: A runtime error (physics-callback removal / null tree) aborts before visuals update, leaving player unrendered.
- H5: Web export asset load failure (texture missing) causes Sprite2D texture to be null.

## Evidence Plan
- Instrument player _ready / _physics_process: report visibility, position, scale, texture.
- Instrument level spawn path: report when player instance is created and added.
- Reproduce in browser and collect logs.

## Notes
- Keep changes instrumentation-only until evidence confirms root cause.

