# Phase 4 Plan — Vertical Slice Mission

## Purpose

This document expands the one-line `ROADMAP.md` Phase 4 stub into a production-ready plan for the first real vertical slice of **Operation Steelstorm**.

Phase 4 is where the project stops being "multiplayer combat proof-of-concept" and starts becoming an actual game mission with a beginning, middle, climax, and resolution.

This plan is intentionally detailed so the repo can use it as the source of truth for:

- gameplay sequencing
- implementation order
- asset dependencies
- UI and results flow
- test coverage additions
- scope control

Related docs:

- `ROADMAP.md`
- `docs/gameplay-design.md`
- `docs/asset-guide.md`
- `docs/testing-guide.md`
- `docs/phase-4-asset-ideation.md`

## Phase 4 Goal

Deliver a **5–10 minute co-op vertical slice** that proves the full fantasy loop:

1. Deploy into an original mission space.
2. Fight through escalating enemy encounters.
3. Find and use expanded weapons.
4. Rescue civilians under pressure.
5. Enter and use the Assault Rover.
6. Defeat the Siege Walker boss.
7. Show a clean result screen and replay loop.

The output of Phase 4 is not "finished content for the whole game."

The output is one highly readable, highly testable, highly replayable mission that proves the structure for future missions, content packs, and polish work in Phase 5.

## Player Promise

When a player finishes Phase 4, they should feel:

- this is clearly a mission-based run-and-gun co-op game
- the team has distinct moment-to-moment combat choices
- the encounter pacing escalates on purpose
- rescue objectives matter and are not decorative
- vehicle use changes the rhythm of the mission
- the boss fight has phases, telegraphs, and spectacle
- the mission ends in a way that invites replay

## Scope Summary

Phase 4 as defined by the roadmap:

- mission flow
- three weapons
- four enemies
- rescue objective
- Assault Rover
- Siege Walker boss
- results screens

This document converts that into concrete production lanes.

## Success Criteria

Phase 4 is successful when all of the following are true:

- a host can start the vertical-slice mission from a stable menu flow
- both players can complete the mission from intro to results without scripted editor intervention
- all three main weapons are obtainable and readable
- all four enemy types appear in authored encounters with distinct combat purpose
- the rescue segment gates progress and can succeed or fail predictably
- the Assault Rover sequence works in both single-player and co-op logic
- the Siege Walker boss has at least two readable combat phases and a finish state
- mission completion and mission failure both route to coherent result screens
- the mission is stable in local native play and practical to validate in browser play

## Explicit Non-Goals

These items remain outside the Phase 4 target unless they fall out trivially from work already being done:

- four-player support
- full campaign progression
- inventory/loadout meta systems
- cinematic cutscene tooling
- full voice acting
- advanced save/progression systems
- final-quality audio mix
- comprehensive art replacement for every placeholder in the project
- complete boss roster beyond the Siege Walker
- rollback networking or dedicated authoritative server migration

## Design Pillars

The vertical slice should be judged against these pillars during every scope decision.

### 1. Fast readable co-op combat

Every encounter must be legible in motion. Readability beats realism.

### 2. Escalation every 30–60 seconds

The mission should keep changing what the player is asked to do:

- movement
- suppression
- rescue pressure
- platforming under threat
- vehicle usage
- boss pattern reading

### 3. Original military-sci-fi identity

Everything must feel inspired by the genre without copying any commercial character, silhouette, staging, animation, or level structure.

### 4. Host-authoritative safety

Any new mission feature has to preserve the networking trust rules already established in earlier phases.

### 5. Cheap to expand later

Phase 4 code and content should become templates for future missions, not dead-end one-offs.

## Mission Structure

Baseline mission path from `docs/gameplay-design.md`:

1. Beachhead cargo pier
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

## Detailed Mission Beat Breakdown

### Beat 1. Beachhead cargo pier

Purpose:

- establish tone
- establish camera framing
- safely hand control to player

Required gameplay:

- spawn players
- short arrival staging
- first movement input opportunity

Required content:

- beach/industrial background silhouettes
- dock props
- low-pressure enemy-free setup
- directional signage or environmental composition that pulls players rightward

Done when:

- players spawn reliably
- camera framing is stable
- players understand movement direction immediately

### Beat 2. Movement tutorial alley

Purpose:

- validate movement basics without using explicit text-heavy tutorialization

Required gameplay:

- small terrain changes for jump/crouch comprehension
- one safe jump
- one crouch gate or low-clearance passage

Required content:

- clear silhouette of climbable/jumpable geometry
- distinct floor vs wall readability

Done when:

- a new player can move through the space without confusion
- no mandatory action feels hidden

### Beat 3. First patrol encounter

Purpose:

- introduce live combat
- teach spacing and return fire

Required gameplay:

- patrol trooper entry
- low-risk exchange
- clear death feedback

Required content:

- enemy entry lane
- minor cover/readability props
- combat-safe space with little clutter

Done when:

- players can defeat the encounter with default weapon
- encounter teaches instead of spikes

### Beat 4. Scatter cannon crate

Purpose:

- introduce weapon pickup and force a tactical change

Required gameplay:

- pickup presentation
- ammo state visibility
- obvious close-range payoff soon after pickup

Required content:

- authored pickup prop or crate
- weapon icon/readout update

Done when:

- players notice the pickup
- at least one near-term enemy group rewards using it

### Beat 5. Smelter catwalk platforming

Purpose:

- combine traversal with combat risk

Required gameplay:

- vertical layering
- small hazard/readability pressure
- enemies positioned to encourage movement timing

Required content:

- catwalk tileset pieces
- heat/smelter background props
- fall-safe or bounded spaces appropriate to mission pacing

Done when:

- traversal adds tension without becoming precision-platform punishment

### Beat 6. Co-op choke point

Purpose:

- create a moment where two-player coordination is visibly beneficial

Required gameplay:

- simultaneous enemy pressure from different angles or elevations
- revive risk opportunity
- weapon complementarity

Required content:

- encounter geometry that supports cross-cover fire
- spawn logic that does not overwhelm single-player fallback

Done when:

- co-op feels advantageous but not mandatory for understanding the encounter

### Beat 7. Civilian lockup rescue

Purpose:

- make the mission objective more than "kill everything"

Required gameplay:

- interact prompt or rescue trigger
- enemy pressure during or around rescue
- clear success/failure messaging

Required content:

- civilian sprites/placeholders
- lockup cell or secure holding area
- rescue feedback VFX/UI

Done when:

- players understand who must be rescued
- rescue state is network-safe and visible to both peers

### Beat 8. Assault Rover yard

Purpose:

- turn the mission into a new combat mode before the boss

Required gameplay:

- enter/exit logic
- rover movement and durability
- optional seat handling or simplified shared-use flow

Required content:

- vehicle yard layout
- entry prompt readability
- enough open space to teach rover handling

Done when:

- vehicle use feels like a reward, not a control burden

### Beat 9. Heavy gunner plaza

Purpose:

- pressure test advanced combat before the boss

Required gameplay:

- heavy gunner telegraphing
- overlapping enemy support
- use of limited weapons and rover advantage

Required content:

- wider arena
- readable projectile lanes
- cover silhouettes that do not hide critical action

Done when:

- encounter feels clearly harder than previous beats
- defeat is fair and readable

### Beat 10. Siege Walker drydock arena

Purpose:

- deliver the vertical slice climax

Required gameplay:

- boss intro
- weak-point or phase logic
- clear telegraphs
- part break or visible phase transition
- mission-complete state

Required content:

- boss arena bounds
- high-contrast background staging
- boss sprite parts and effects
- end-of-fight feedback

Done when:

- the boss feels like a different class of encounter
- players can learn and beat it without hidden rules

### Beat 11. Result screen

Purpose:

- provide closure, feedback, and replay motivation

Required gameplay:

- mission complete or fail state
- result summary
- restart/return flow

Required content:

- result UI layout
- headline art or icon treatment
- stat categories

Done when:

- the run ends cleanly
- players know whether they succeeded and why

## Feature Lanes

### Gameplay lane

Must deliver:

- mission scene flow controller
- encounter triggers/checkpoints
- rescue objective state
- vehicle interaction flow
- boss state machine
- result routing

Preferred implementation shape:

- mission-specific resources for encounter sequencing
- clear trigger volumes and reusable encounter controller script
- mission state owned by authoritative host

### Weapon lane

Target usable set for Phase 4:

- standard rifle
- scatter cannon
- rapid pulse gun
- frag charges if retained as part of the core loop

Requirements:

- distinct role differentiation
- clear ammo/readiness feedback
- drop or pickup acquisition path

### Enemy lane

Required encounterable enemies:

- patrol trooper
- shield trooper
- drone unit
- heavy gunner

Each enemy must have:

- clear battlefield role
- readable attack tell
- readable hurt/death feedback
- authored encounter use-case

### Rescue lane

Minimum requirements:

- civilians visibly present in the mission
- one clear rescue interaction model
- mission logic responds to rescue state
- both peers see the same rescue outcome

### Vehicle lane

Minimum requirements:

- rover presence is not decorative
- entering it changes combat or traversal in a noticeable way
- vehicle damage state is readable
- network ownership rules are defined and stable

### Boss lane

Minimum requirements:

- unique intro
- multiple attack patterns
- telegraphed danger windows
- visible phase transition
- defeat state with result routing

### UI lane

Must add or extend:

- mission intro text or title card
- weapon pickup clarity
- rescue status
- boss health/state
- result screen
- failure messaging

## Asset Dependency Map

Phase 4 depends on authored assets far more than earlier phases. Asset work is no longer optional dressing.

Critical asset groups:

- player variants and weapon poses
- four enemy families
- civilians
- rover
- boss parts
- mission environment tiles and props
- mission UI icons and result layouts
- combat FX

The detailed generation strategy lives in `docs/phase-4-asset-ideation.md`.

## Production Order

This is the recommended implementation order because it respects dependency chains.

### Milestone A. Mission scaffolding

Build first:

- mission scene shell
- checkpoint layout
- event hooks
- placeholder trigger sequence

Reason:

- everything else depends on level flow existing

### Milestone B. Combat expansion

Build next:

- weapon pickups
- shield trooper
- drone
- heavy gunner
- encounter logic updates

Reason:

- mission beats cannot be tuned until combat variety exists

### Milestone C. Objective flow

Build next:

- civilian rescue logic
- rescue UI
- fail/success gates

Reason:

- objective cadence defines the middle of the mission

### Milestone D. Vehicle sequence

Build next:

- rover interaction
- rover combat/traversal
- authored yard sequence

Reason:

- rover changes pacing before the boss and must be fun before boss tuning begins

### Milestone E. Boss implementation

Build next:

- boss arena
- boss state machine
- telegraphs
- part break/phase shift
- mission complete

Reason:

- boss is the final validation of the slice

### Milestone F. Results and finish loop

Build last for core scope:

- result screens
- stats
- retry/return loop

Reason:

- results should consume the final mission state once earlier systems are stable

## Critical Path

The true blockers for Phase 4 are:

- mission flow controller
- encounter authoring support
- new enemy behaviors
- rescue state logic
- rover control and authority rules
- boss implementation
- minimum viable asset set for readability

If any of those slip, the whole vertical slice slips.

## Content Acceptance Criteria

Use these as content review gates before calling the phase complete.

### Weapons

- each weapon has a unique combat job
- pickup/use feedback is readable in one glance
- players are never confused about what they currently hold

### Enemies

- each enemy type adds a new decision, not just more HP
- telegraphs are visible against the level background
- hurtboxes feel fair relative to visuals

### Rescue

- civilians are recognizable at gameplay distance
- rescue cannot soft-lock the mission
- objective messaging is visible without blocking action

### Rover

- players know when they can enter
- vehicle collision and damage do not feel random
- exit flow is deterministic

### Boss

- every major attack is learnable
- phase change is obvious
- defeat sequence is satisfying but short enough to replay

### Results

- complete and fail routes both work
- screens never leave players unsure of next action
- restart path is fast

## Technical Constraints

These rules should remain active while implementing Phase 4.

- preserve host-authoritative logic for mission-critical state
- avoid phase-specific hacks that hardcode one arena directly into shared combat systems
- keep browser export compatibility in mind for all new effects and shaders
- maintain readability at the project's 640×360 internal resolution
- avoid giant over-detailed sprites that break the established scale language

## Test Plan Additions

`docs/testing-guide.md` should eventually gain a dedicated Phase 4 section with at least these checks:

### Automated or scriptable smoke goals

- mission scene loads without missing dependencies
- mission controller can advance through required states
- rescue success/failure states resolve
- boss can spawn and enter at least one attack phase
- mission complete and fail paths route to result scenes

### Manual gameplay checks

- complete mission in single-player
- complete mission in two-player local/native setup
- verify rescue sync across peers
- verify rover enter/use/exit sync across peers
- verify boss health and phase sync across peers
- verify result screen consistency across peers

### Browser checks

- mission starts in exported web build
- no unreadable UI scaling regressions
- boss arena remains performant enough for practical playtest

## Risks

### Risk: boss scope balloons

Mitigation:

- lock boss to two phases minimum
- cap unique attacks to a manageable set
- favor readability over cinematic excess

### Risk: rover becomes a second game

Mitigation:

- keep controls simple
- avoid full simulation ambitions
- make rover sequence short and high-impact

### Risk: asset generation creates inconsistent silhouettes

Mitigation:

- establish style anchors early
- use reference-driven generation workflow
- review against a single silhouette checklist

### Risk: rescue objective feels bolted on

Mitigation:

- gate progression with it
- connect enemy pressure to the rescue timing
- make success/failure readable immediately

### Risk: co-op edge cases multiply late

Mitigation:

- validate every new system in authority terms when first added
- do not wait until "content complete" to test networking paths

## Recommended Work Breakdown

Suggested execution sequence for implementation tickets:

1. Mission controller and beat trigger framework
2. Phase 4 level blockout
3. Weapon pickup/drop routing
4. Shield trooper and drone
5. Heavy gunner
6. Rescue objective logic and UI
7. Rover prototype in mission context
8. Boss arena and intro
9. Boss attacks and phase shift
10. Results screen flow
11. Content tuning pass
12. Browser/performance pass

## Definition Of Done

Phase 4 is done only when:

- mission start-to-finish flow is playable
- authored content covers every planned beat
- the mission can be completed and failed intentionally
- core art/UI placeholders are good enough to support readability
- co-op logic remains stable
- the team can point to this slice and say "this is the game"

## Immediate Next Actions

These should happen before major implementation begins:

1. Lock the mission blockout and beat ordering.
2. Approve the asset generation plan in `docs/phase-4-asset-ideation.md`.
3. Decide whether the rover is dual-seat, single-seat, or simplified shared interaction for MVP.
4. Decide whether civilians are escort-free "release and count as rescued" or require follow behavior.
5. Confirm the boss weak-point model before animation work starts.
6. Convert this plan into actionable implementation tasks.
