# Buka proyek Godot di sini

Godot mencari `project.godot` di folder yang Anda pilih.

Repository monorepo ini **tidak** punya `project.godot` di root.
File yang benar:

```text
game/project.godot
```

## Cara buka

1. Godot Project Manager → **Import**
2. Pilih file: `…/ok-thank-you/game/project.godot`
3. Atau **Scan** / buka folder `game/` (bukan `ok-thank-you/`)

Dari terminal:

```bash
/path/to/Godot --path game
```

atau:

```bash
./scripts/run-godot.sh
```
