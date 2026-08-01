# Asset Replacement Guide — Operation Steelstorm

Temporary art uses colored rectangles / labeled placeholders only. No ripped commercial sprites.

## Target visual direction

- Detailed 2D pixel art  
- Retro military science-fiction  
- Exaggerated animation  
- Bright tropical environments  
- Dark mechanical enemies  
- Original comedic reactions  

## Recommended base sizes

| Asset | Size (px) | Pivot |
|-------|-----------|-------|
| Player | 32×32 to 48×48 | Feet center |
| Trooper | 32×32 | Feet center |
| Heavy gunner | 48×48 to 64×64 | Feet center |
| Drone | 24×24 to 32×32 | Body center |
| Assault Rover | 96×48 | Chassis center / wheel line |
| Siege Walker (body) | 160×160+ | Ground contact |
| Tiles | 16×16 | N/A |
| Projectiles | 8×8 to 16×16 | Center |
| UI icons | 16×16 / 32×32 | Center |

## Naming conventions

```text
player_<name>_<anim>_<frame>.png
enemy_<type>_<anim>_<frame>.png
fx_<name>_<frame>.png
ui_<name>.png
tile_<set>_<id>.png
veh_<name>_<anim>_<frame>.png
boss_<name>_<part>_<anim>_<frame>.png
```

## Required animation sets (minimum)

### Player

idle, run, jump, fall, crouch, shoot_stand, shoot_up, throw, hurt, downed, revive  

### Enemies

idle/patrol, detect, attack, hurt, death (+ shield block for shield trooper; hover for drone; telegraph for heavy)

### Vehicle

idle, drive, brake, gun_fire, damaged, explode  

### Boss

intro, move, telegraph×3, attack×3, phase2_idle, part_break, death  

## Collision guidelines

- Hurtboxes slightly tighter than visuals  
- Player crouch hurtbox shorter  
- Shield frontal block uses separate blocking hitbox  
- One-way platforms: top face only  

## Audio buses

Master → Music, SFX, UI, Ambience  

Replace placeholders with original or permissively licensed audio only; document license in `game/assets/audio/LICENSES.md` when added.

## Import settings

- Pixel art: filter **off** (project default canvas texture filter nearest)
- Keep atlas margins consistent with pivot docs above
