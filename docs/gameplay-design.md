# Gameplay Design — Operation Steelstorm

## Working title

**Operation Steelstorm** (temporary, easy to replace)

## Pitch

Elite recovery operatives drop onto a **tropical industrial island** seized by the **Aegis Automaton Directorate (AAD)** — a rogue automated military faction that turned corporate security drones and bipedal walkers against the civilian workforce.

Tone: fast arcade action with original comic character reactions — never a clone of any existing IP.

## Vertical-slice cast (placeholders first)

| Role | Working name | Notes |
|------|----------------|-------|
| Operative A | **Rook Varga** | Rifle specialist |
| Operative B | **Mira Solace** | Demo / support |
| Faction | Aegis Automaton Directorate | Dark mechanical enemies |
| Boss | **Siege Walker** | Multi-part mechanical walking platform |
| Vehicle | **Assault Rover** | Drive + optional gunner seat |

## Core fantasy loop

Run → clear troopers → grab weapons → rescue civilians → board rover → siege the walker → extract.

## Mission 01 outline (~5–10 minutes)

Original setting sequence (not copied from any commercial level):

1. Beachhead cargo pier (intro)
2. Movement tutorial alley
3. First patrol encounter
4. Scatter cannon crate
5. Smelter catwalk platforming
6. Co-op choke point
7. Civilian lockup rescue
8. Assault Rover yard
9. Heavy gunner plaza
10. Siege Walker drydock arena
11. Result screen

## Weapons (Resource-driven)

1. **Standard rifle** — infinite ammo, medium RoF/damage  
2. **Scatter cannon** — limited ammo, short range, multi-pellet  
3. **Rapid pulse gun** — limited ammo, high RoF, lower damage  
4. **Frag charges** (grenades) — arc, radius, no friendly fire by default  

## Player durability (MVP)

- 3 HP, configurable  
- I-frames after hit  
- Downed at 0 HP; teammate revive  
- All downed → mission fail  
- Offline continues (limited)  

## Enemies (framework later)

1. Patrol trooper  
2. Shield trooper  
3. Drone unit  
4. Heavy gunner  

## Camera

Shared side-scroller; keep both players framed; soft separation limits; boss arena bounds; no split-screen MVP.

## Out of scope for Phase 0

All combat implementation — design only.
