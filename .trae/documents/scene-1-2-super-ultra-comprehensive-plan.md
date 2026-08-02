# Scene 1-2 Super Ultra Comprehensive Plan

## Summary

Create a brand-new `1-2` mission that sits beside the current Phase 4 beachhead content instead of replacing it. The new mission must exist in both single-player and co-op form, introduce a more explicit jump-platform traversal route, place the scatter pickup on higher ground so it is earned by platforming, also grant/unlock scatter when the prisoner is released, and change captive evacuation so the prisoner runs back toward safety on the ground rather than forward/upward through the air.

The UX entry flow must also change:

- Single-player: add a dedicated scene-select submenu from the main menu so players can choose between the existing mission and the new `1-2` mission.
- Co-op: keep room creation/join as-is, but add mission selection inside the lobby so the host chooses the co-op mission for the whole room before starting.

## Current State Analysis

### Existing Single-Player Mission

- `game/scenes/levels/phase4_vertical_slice.tscn`
  - Current offline mission geometry is a single 3328px-wide strip with a handful of raised catwalks/platforms.
  - Existing scatter marker is already above floor level at `MissionMarkers/ScatterPickup` (`Vector2(760, 226)`), but the level is still structured as the current beachhead slice rather than the new `1-2` progression requested.
  - Current captive marker is on floor level at `MissionMarkers/Captive` (`Vector2(1680, 320)`).
  - Current safe marker is forward/upward at `MissionMarkers/CaptiveSafe` (`Vector2(1920, 280)`), which pushes the escape path in the unsafe direction and above the base floor.

- `game/scenes/levels/phase4_vertical_slice.gd`
  - The scene spawns pickups directly from the marker positions.
  - Scatter is granted only through physical pickup collection in `_spawn_pickups()`.
  - Releasing the captive only increments `_rescued_count` and shows a banner in `_spawn_rescue_target()`.
  - Objective progression is still tailored to the current beachhead layout (`Reach the scatter cannon crate`, `Rescue the captive worker`, `Board the Assault Rover`, etc.).

### Existing Co-op Mission

- `game/scenes/levels/mp_phase4_coop.tscn`
  - Geometry and mission markers mirror the single-player level almost exactly.
  - Scatter/captive/safe markers use the same core placement pattern as the single-player scene.

- `game/scenes/levels/mp_phase4_coop.gd`
  - Mission progression is host-driven.
  - Scatter currently unlocks automatically for all players when mission front progress reaches the scatter area rather than through an explicit elevated pickup interaction.
  - Captive rescue is still tied to the same forward-moving evacuation structure.

### Existing Captive Behavior

- `game/entities/world/rescue_captive.gd`
  - Escape movement is implemented via `global_position.move_toward(target, run_speed * delta)`.
  - The current fallback/default safe vector is `Vector2(150.0, -18.0)`, which biases movement forward and upward.
  - Because movement is a raw straight-line interpolation rather than ground-constrained walking, the captive can visually “fly” toward an elevated safe marker instead of remaining on the normal level.

### Existing Menu / Navigation Flow

- `game/scenes/menus/main_menu.gd`
  - Single-player currently goes directly to `SceneManager.go_to_phase4_mission()`.
  - Multiplayer currently goes directly to `SceneManager.go_to_multiplayer_menu()`.

- `game/scenes/menus/main_menu.tscn`
  - The main menu currently has a single single-player button and a single multiplayer button.
  - There is no mission/scene selection layer yet.

- `game/scenes/menus/multiplayer_menu.gd`
  - The multiplayer menu is only for player naming and room create/join.
  - This is not the right place for authoritative co-op mission selection because guests should not decide the room’s mission independently.

- `game/scenes/menus/mp_lobby.gd`
  - The lobby already owns the host-only `Start Match` action.
  - This makes the lobby the correct place for host mission selection in co-op.

- `game/autoload/scene_manager.gd`
  - Has routes only for the current single-player and co-op Phase 4 scenes.
  - No route exists yet for a new `1-2` scene, nor for any single-player or co-op scene-select UI.

### Existing Co-op Match Start / Signaling

- `game/autoload/network_manager.gd`
  - `rpc_start_match()` currently always routes to `SceneManager.go_to_mp_phase4_mission()`.
  - No selected mission/scene ID is synchronized through lobby state.

- `signaling-server/src/protocol.ts`
- `signaling-server/src/room-store.ts`
- `signaling-server/src/server.ts`
- `cloudflare/signaling-worker/src/index.ts`
  - Existing room protocol supports room create/join, ready state, and host changes.
  - There is no room-level mission selection field yet, so co-op scene selection will need protocol/state expansion if the host’s lobby choice must be visible to both peers and applied when the match starts.

### Existing Verification Coverage

- `game/tests/phase4_smoke.gd`
  - Only validates the existing offline Phase 4 scene.
  - No smoke coverage exists for a second single-player mission variant or for the new menu scene-select flow.

## Assumptions & Decisions

### Locked Product Decisions

- Add the new `1-2` scene beside the current mission rather than replacing the current beachhead mission.
- Scatter must be obtainable in two valid ways:
  - by reaching and collecting it on higher ground;
  - by rescuing/releasing the prisoner, if the player has not already collected it.
- The redesign must be mirrored in both single-player and co-op.
- Single-player access must use a new scene-select submenu.
- Co-op access must use a co-op scene-select flow in the lobby, not a hidden route and not a direct replacement.

### Implementation Decisions For The Executor

- Keep the existing current beachhead missions untouched as separate options.
- Introduce new level files rather than mutating `phase4_vertical_slice.*` into `1-2`.
- Use consistent names in the existing `game/scenes/levels/` directory:
  - `game/scenes/levels/phase4_scene_1_2.gd`
  - `game/scenes/levels/phase4_scene_1_2.tscn`
  - `game/scenes/levels/mp_phase4_scene_1_2.gd`
  - `game/scenes/levels/mp_phase4_scene_1_2.tscn`
- Add a new single-player scene-select menu:
  - `game/scenes/menus/single_player_scene_select.gd`
  - `game/scenes/menus/single_player_scene_select.tscn`
- Do not add a second co-op scene-select screen before room creation.
  - Instead, extend the existing co-op lobby so the host can choose the mission there and guests can see the selected mission.
- Represent the co-op mission choice as a stable scene/mission ID string propagated through room state, for example:
  - `phase4_beachhead`
  - `phase4_scene_1_2`
- Keep the new `1-2` scene as a platforming-focused mission slice and not a pure duplicate of the beachhead file.
- Keep captive retreat grounded by moving the safe point behind the prison break location and by rewriting escape movement to preserve floor-level walking instead of straight-line air travel.

## Proposed Changes

### 1. Add New Single-Player Scene 1-2

**New files**

- `game/scenes/levels/phase4_scene_1_2.tscn`
- `game/scenes/levels/phase4_scene_1_2.gd`

**What**

- Create a new single-player mission scene for `1-2`.
- Rebuild the traversal so the player must:
  - jump onto a lower obstacle/platform,
  - jump to a higher platform,
  - jump off again to continue the route.
- Place the scatter pickup on the elevated route so the player must jump to reach it.
- Place the prisoner on a normal ground tile/floor segment, not on a floating/elevated path.
- Place the prisoner’s safe point behind the prison location so “running back” means moving toward the safer cleared area.

**Why**

- The user wants a distinct new scene rather than reshaping the existing beachhead mission.
- The scene needs obvious jump-on / jump-to / jump-off geometry and a high-ground scatter reward.
- The captive retreat must feel grounded and safe.

**How**

- Start from the structural pattern of `phase4_vertical_slice.tscn`:
  - base floor static body,
  - a few `StaticBody2D` platforms,
  - marker-driven mission setup.
- Build a more explicit three-step traversal route than the current layout:
  - a first obstacle accessible from the floor,
  - a second/highest platform holding the scatter pickup,
  - a landing/off-ramp platform or clear descent path to continue the mission.
- Use actual `StaticBody2D` collision geometry in the new `.tscn` rather than relying only on markers, so traversal is deterministic and easy to verify.
- Position prisoner and safe markers on the same floor elevation (or a clearly grounded stepped floor path) so the captive never has to path toward an elevated target.
- Wire the new script to:
  - spawn the player and enemies similarly to the existing Phase 4 scene;
  - spawn the prisoner and pickups from local markers;
  - track whether scatter is obtained by pickup and/or rescue.

### 2. Grant Scatter On Rescue As Well As Pickup

**Files**

- `game/scenes/levels/phase4_scene_1_2.gd`
- `game/scenes/levels/mp_phase4_scene_1_2.gd`
- Potentially reuse logic patterns from:
  - `game/scenes/levels/phase4_vertical_slice.gd`
  - `game/scenes/levels/mp_phase4_coop.gd`

**What**

- Make scatter available via the elevated pickup route.
- Also grant scatter when the prisoner is released, if the player/team has not already obtained it.

**Why**

- This is a direct user requirement.
- It prevents the player from getting locked out of the scatter reward if the scene flow favors rescue first.

**How**

- Introduce a single source of truth in each new scene for “scatter unlocked/obtained”.
- On pickup:
  - mark scatter obtained,
  - equip/unlock the scatter weapon,
  - show the existing “SCATTER CANNON ONLINE” style feedback.
- On rescue:
  - if scatter is not already obtained, unlock/equip it immediately and mark the state.
- Ensure the logic is idempotent so rescue after pickup does not duplicate state changes or banners.
- In co-op, the host must own the unlock and broadcast it to both players.

### 3. Make Prisoner Run Back On Ground, Not Forward / Flying

**Files**

- `game/entities/world/rescue_captive.gd`
- `game/scenes/levels/phase4_scene_1_2.tscn`
- `game/scenes/levels/mp_phase4_scene_1_2.tscn`

**What**

- Change captive evacuation behavior so the prisoner retreats back toward a safer cleared area.
- Make the movement visually grounded and walking-like.

**Why**

- The current implementation can move forward/upward.
- The current `move_toward()` behavior toward an elevated safe marker makes the prisoner appear to fly.
- The user explicitly wants “run back, not forward” and “walking on the normal level/tile”.

**How**

- Replace the new scene’s captive safe marker positions so the escape destination is behind the rescue point and on floor level.
- Update `RescueCaptive` behavior so evacuation is floor-constrained:
  - simplest acceptable route: horizontal walking only while rescued, toward a same-height safe position;
  - if minor Y correction is needed, clamp it tightly to the original floor level instead of using free diagonal interpolation.
- Update label/visual text only if needed; keep current rescue/evacuated signals intact so existing mission code keeps working.
- Preserve compatibility for current scenes by making the walking behavior robust rather than hard-coding it only for `1-2`.

### 4. Mirror Scene 1-2 In Co-op

**New files**

- `game/scenes/levels/mp_phase4_scene_1_2.tscn`
- `game/scenes/levels/mp_phase4_scene_1_2.gd`

**What**

- Build a co-op version of the new `1-2` mission with the same traversal goals and prisoner/scatter rules.

**Why**

- The user explicitly wants the redesign mirrored in co-op.

**How**

- Start from the shape of `mp_phase4_coop.tscn` and `mp_phase4_coop.gd`.
- Mirror the new geometry and markers from the single-player `1-2` scene.
- Replace the current progress-triggered scatter unlock with explicit elevated scatter acquisition logic plus rescue-based fallback unlock.
- Keep existing co-op architecture intact:
  - host-authoritative enemy progression,
  - player spawning,
  - rover/captive/boss syncing if reused.
- If the new `1-2` scene does not need the rover/boss slice, scope the co-op scene to the requested traversal + rescue loop and reflect that in objective text and completion conditions.

### 5. Add Single-Player Scene Select

**New files**

- `game/scenes/menus/single_player_scene_select.tscn`
- `game/scenes/menus/single_player_scene_select.gd`

**Files to update**

- `game/scenes/menus/main_menu.gd`
- `game/scenes/menus/main_menu.tscn`
- `game/autoload/scene_manager.gd`

**What**

- Insert a single-player scene-select submenu between the main menu and the actual single-player mission load.
- Let players choose:
  - the existing current mission;
  - the new `1-2` mission.

**Why**

- The user wants the new scene added beside the current one, not replacing it.
- The user explicitly chose a scene-select submenu for single-player.

**How**

- Change main menu single-player button behavior to route to the new scene-select screen instead of directly calling `go_to_phase4_mission()`.
- Add new `SceneManager` routes for:
  - the single-player scene-select menu;
  - the new single-player `1-2` scene.
- Keep the current mission reachable as a separate option.
- Update menu hints/subtitles so the UI no longer implies there is only one single-player mission.

### 6. Add Co-op Scene Select In Lobby

**Files**

- `game/scenes/menus/mp_lobby.gd`
- `game/scenes/menus/mp_lobby.tscn`
- `game/autoload/network_manager.gd`
- `game/autoload/scene_manager.gd`
- `signaling-server/src/protocol.ts`
- `signaling-server/src/room-store.ts`
- `signaling-server/src/server.ts`
- `cloudflare/signaling-worker/src/index.ts`

**What**

- Add co-op mission selection to the lobby UI.
- The host chooses the mission for the room.
- Guests see the currently selected mission.
- Starting the match routes both peers into the selected co-op scene.

**Why**

- The user wants a co-op scene-select flow too.
- The existing lobby already owns the host-only `Start Match` control, so this is the most grounded and least disruptive insertion point.

**How**

- Extend lobby UI with a host-visible selector and guest-visible current mission label.
- Add room-level mission state to the lobby/signaling protocol:
  - include selected mission in room-created / room-joined / lobby update payloads;
  - add a host-only message for updating room mission selection.
- Store the selected co-op mission in `NetworkManager`.
- Change `rpc_start_match()` so it routes to the correct co-op scene based on the selected mission ID instead of always calling `go_to_mp_phase4_mission()`.
- Add `SceneManager` routes for the new co-op `1-2` scene.
- Update local Node signaling server and Cloudflare Worker signaling server together so local dev and deployed rooms behave consistently.

### 7. Preserve Current Beachhead Content As A Separate Choice

**Files**

- `game/autoload/scene_manager.gd`
- `game/scenes/menus/main_menu.gd`
- `game/scenes/menus/main_menu.tscn`
- `game/scenes/menus/single_player_scene_select.gd` (new)
- `game/scenes/menus/single_player_scene_select.tscn` (new)
- `game/scenes/menus/mp_lobby.gd`
- `game/scenes/menus/mp_lobby.tscn`

**What**

- Keep current Phase 4 beachhead single-player and co-op content accessible.

**Why**

- The user explicitly chose “add beside current”.

**How**

- Do not repoint existing beachhead scene files.
- Expose them as selectable mission options:
  - single-player scene select;
  - co-op lobby mission choice.

### 8. Update Objectives / Progression Text For The New Scene

**Files**

- `game/scenes/levels/phase4_scene_1_2.gd`
- `game/scenes/levels/mp_phase4_scene_1_2.gd`

**What**

- Write new objective text that matches the new traversal/rescue layout.

**Why**

- Current objective text is specific to beachhead, rover, pulse cache, and drydock flow.
- The new mission needs objective copy that matches:
  - jump route,
  - high-ground scatter,
  - prisoner rescue,
  - backward evacuation.

**How**

- Sequence objectives around:
  - reaching the first obstacle,
  - climbing to the high scatter route,
  - freeing the prisoner,
  - protecting/confirming safe retreat,
  - any final cleanup or exit condition.
- Mirror the same logic in co-op with host-authoritative state updates.

### 9. Add/Update Verification Coverage

**Files**

- `game/tests/phase4_smoke.gd`
- New recommended smoke tests:
  - `game/tests/phase4_scene_1_2_smoke.gd`
  - optionally `game/tests/phase4_scene_select_smoke.gd`

**What**

- Add smoke coverage for the new single-player `1-2` scene and updated navigation expectations.

**Why**

- The repo already uses lightweight smoke tests for major scene entrypoints.
- The new scene plus new menu routing adds regression risk.

**How**

- Keep the existing `phase4_smoke.gd` for the original beachhead scene.
- Add a new smoke test that loads the `1-2` scene and checks for:
  - player exists,
  - captive exists,
  - scatter pickup marker path is reachable/spawned,
  - required world/platform nodes exist.
- If navigation logic is changed significantly, add a focused menu/scene-select smoke test rather than bloating the existing phase test.

## Detailed Implementation Sequence

1. **Add SceneManager routes**
   - Add scene constants and helper methods for:
     - single-player scene-select menu;
     - new single-player `1-2` scene;
     - new co-op `1-2` scene.

2. **Build the single-player scene-select menu**
   - Add the new submenu scene.
   - Update the main menu to route into it.
   - Keep the current mission as one option and the new `1-2` scene as the second option.

3. **Author the new single-player `1-2` level scene**
   - Create grounded platform geometry and marker layout.
   - Place scatter on the highest platform.
   - Place prisoner on normal ground.
   - Place prisoner safe marker behind the rescue area on floor level.

4. **Implement single-player `1-2` mission logic**
   - Spawn pickups/captive/enemies/objectives.
   - Add dual scatter unlock logic (pickup + rescue).
   - Add objective text matching the new route.

5. **Ground the captive movement**
   - Update `RescueCaptive` so retreat is walking/grounded rather than diagonal flying.
   - Verify the behavior is safe for both current and new scenes.

6. **Author the co-op `1-2` level scene**
   - Mirror geometry and markers from the single-player `1-2`.
   - Rebuild co-op mission logic around host authority and mirrored scatter/rescue rules.

7. **Add co-op mission selection in the lobby**
   - Extend lobby UI with mission display/selection.
   - Extend room protocol/state so mission selection is synchronized.
   - Route match start into the selected co-op scene.

8. **Add/update smoke tests**
   - Keep old beachhead smoke coverage.
   - Add new `1-2` smoke coverage.
   - Optionally add scene-select smoke coverage if needed.

9. **Manual verification**
   - Verify both current and new missions remain reachable.
   - Verify single-player and co-op flows both honor the selected mission.

## Verification Steps

### Single-Player Acceptance

1. Start at main menu.
2. Press single-player and confirm a scene-select submenu appears.
3. Confirm the current beachhead mission is still selectable.
4. Select new `1-2`.
5. Verify the level contains explicit jump-on / jump-to / jump-off traversal.
6. Verify scatter is on higher ground and requires jumping to reach.
7. Rescue the prisoner before collecting scatter and confirm scatter is still granted.
8. Rescue the prisoner after collecting scatter and confirm the unlock is not duplicated.
9. Verify the prisoner runs back toward the safer cleared area.
10. Verify the prisoner remains on ground/floor tiles and does not float through the air.

### Co-op Acceptance

1. Enter multiplayer flow and create/join a room normally.
2. In the lobby, verify the host can choose between current co-op mission and new co-op `1-2`.
3. Verify the guest sees the selected mission.
4. Start the match and confirm both peers load the chosen mission.
5. Verify scatter acquisition works through the elevated route.
6. Verify prisoner rescue also unlocks scatter if not already collected.
7. Verify prisoner retreat is backward and grounded.

### Regression Checks

1. Existing single-player beachhead mission still loads from the new single-player scene-select menu.
2. Existing co-op beachhead mission still loads when selected in the lobby.
3. Main menu and multiplayer menu text still make sense after the new branching flow.
4. Existing smoke tests still pass after route changes.
5. New smoke tests pass for the new scene.

## Out of Scope

- Reworking the existing beachhead scene into the new `1-2` scene.
- Adding art polish or custom tileset art beyond the collision/platform layout needed to support the new traversal.
- Replacing the current current-mission flow globally without scene selection.
- Changing unrelated combat systems unless required to make the new scene logic work.
