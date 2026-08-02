# Debug Session: combat-physics-logs [OPEN]

## Symptoms
- Enemy cannot be killed in the live browser build.
- Browser console shows physics-callback removal errors for `CollisionObject`.
- Player still lacks true sprite-based shoot-up / northwest / northeast / squat poses.

## Scope
- Gameplay combat flow
- Enemy death/despawn flow
- Projectile / hit handling
- Player visual pose system

## Initial Hypotheses
- H1: An enemy or projectile is being freed directly inside a physics callback, causing Godot to abort part of the hit/death flow.
- H2: Recent player alignment / pose changes shifted muzzle or collision behavior enough that projectiles no longer overlap enemy hurtboxes correctly.
- H3: Host-authoritative damage still applies, but a runtime exception during collision cleanup prevents enemy health from reaching or persisting at dead state.
- H4: Projectile lifetime / ownership filtering rejects hits against enemies after the recent visual refactor, making enemies appear immortal.
- H5: The current player pose system only applies procedural transforms to one idle sprite, so directional fire/crouch "poses" exist as rotation/offset only, not true frame-specific art.

## Evidence Plan
- Instrument projectile hit, enemy hurtbox damage, enemy death, and removal code paths.
- Instrument the exact node removal / queue-free path for collision objects.
- Verify whether damage is applied before the physics-callback error appears.
- Verify whether the missing player poses are a runtime state issue or simply absent art assets.
