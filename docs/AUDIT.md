# DeadShift Rebuild Milestone 1 Audit

Date: 2026-10-16
Audit branch: `mutations/01-audit`
Audited gameplay baseline: `feature/stage2-early-tuning` @ `a9349f80d5c05df06738a599a0e8c2c458404f61`

## Executive summary

The current playable DeadShift prototype is **not** the repository default branch. `main` is the older React Native/TypeScript prototype. The current game that has been tested and iterated through Stage 2 lives on `feature/stage2-early-tuning`, and this rebuild must preserve that branch as the gameplay baseline.

The active prototype is already a Godot 4.x project. `godot/project.godot` declares the 4.x project format/features, and the Android workflow installs and exports with Godot **4.4.1 stable**. The mutation-system architecture in the rebuild spec can therefore be implemented directly in Godot 4 without an engine migration.

No gameplay has been changed in this milestone.

## 1. Engine and build baseline

- Engine family: Godot 4.x.
- CI/export engine: Godot 4.4.1 stable.
- Active main scene: `res://scenes/Outskirts.tscn`.
- Project render path: GL Compatibility.
- Mobile viewport: 432 x 960 portrait.
- Android target: arm64-v8a enabled; x86_64 retained for emulator/CI use.
- Android package: `com.dennypag02.deadshift`.
- Signed debug APK workflow and stable development signing already exist.
- VIBRATE permission remains enabled.
- Audio is intentionally disabled in the current build and must remain unchanged unless a later milestone explicitly changes it.

## 2. Current scene and script entry path

`Outskirts.tscn` is intentionally thin and delegates to the tuned gameplay script chain:

`Outskirts.tscn` -> `tuned_game.gd` -> movement/gameplay inheritance -> `outskirts.gd`

The runtime then creates supporting systems in code, including:

- actor presentation
- objective guidance
- tactical minimap
- Stage 2 timed events
- progression / level-up system
- HUD and modal UI
- pacing telemetry and run telemetry
- deterministic terrain/record batching helpers

This means the rebuild should avoid replacing the entire scene graph at once. The safest path is to introduce the new autoload/data/event backbone beside the existing runtime and then retire old systems milestone by milestone.

## 3. Current map structure

The current playable map is one large handcrafted Outskirts district.

### Dimensions

- Tile size: 128 px/world units.
- Grid: 32 x 40 tiles.
- World footprint: 4096 x 5120 units.

### Construction

The layout is encoded directly in `outskirts.gd` as `MAP_ROWS`, a 40-row character map. Collision and environmental meaning are derived from character codes. The runtime then adds limited randomization:

- cars are moved among valid nearby cells
- rubble/debris-like tile variation is scattered
- fixed objective positions remain deterministic

The map therefore is **not modular** today. It is one large fixed district with light procedural decoration.

### Fixed objective/world positions

The current script hard-codes locations for:

- generator
- three supply caches
- four infestation nests
- relay pads
- fuel/puzzle locations
- gas pumps
- diner, motel, auto shop and highway landmarks
- spawn lanes / edge entry points

These coordinates are tightly coupled to the current Outskirts map and Stage 2 event logic.

### Rebuild implication

Milestone 6 should retire this large map from active play and replace it with fixed-size district scenes plus `MapBuilder`. The existing Outskirts map should remain in the repository for reference/history but become unused, exactly as the new spec requires.

## 4. Current power-up and progression architecture

The current progression system is centered in `phase_a_progression.gd`, configured primarily by `res://data/phase_a.json`, and surfaced through `phase_a_ui.gd`.

### Level-up loop

- Player begins with `scrap_smg` level 1.
- XP gems are dropped by enemies.
- Level thresholds come from data.
- Level-up pauses/queues a modal picker.
- Three choices are offered.
- Reroll and banish mechanics exist.
- Rarity tiers exist: Common, Rare, Epic, Legendary.
- Weapons and passives can level repeatedly.
- Weapon/passive caps are enforced.
- The crate system has already been unified with the same level-up card UI through a modal queue.

### Current weapons

The current data/code supports:

- Scrap SMG
- Boomstick
- Molotov Lobber
- Buzzsaw Orbit
- Lightning Rod
- Rocket Pod
- Attack Drone
- Hubcap Chakram

### Current passives

The current data/code supports:

- Muscle
- Ammo Belt
- Trigger Finger
- Battery Pack
- Blast Radius
- Fuel Tank
- Ball Bearings
- Magnet
- Thick Hide
- Sharpened Edge
- Rabbit's Foot

### Current evolutions

The system has fixed weapon/passive evolution pairs such as Scrap SMG + Ammo Belt and other combinations. Evolution logic is hard-coded through lookup dictionaries rather than fully data-driven.

### Current pickups / temporary power-ups

The Outskirts runtime also tracks temporary or world pickups separately from the level-up system, including current Stage 2 reward/pickup concepts such as medkit, magnet, rage, nuke, freeze and temporary weapon effects.

### Rebuild implication

Milestone 3 should remove the old weapon/passive/rarity/evolution choice system and replace it with the five-slot mutation picker. The current modal queue and card presentation patterns can be reused, but choice eligibility, ownership, leveling and replacement logic must be replaced by `MutationManager`.

The current base Scrap SMG can technically remain as the non-mutation starting attack because it is already isolated as the default weapon. Whether it should remain is still an explicit owner decision in the rebuild spec and is not changed by this audit.

## 5. Current combat systems worth preserving

The rebuild should preserve the proven low-level combat feel and fairness systems unless a later milestone explicitly supersedes them:

- player movement and touch steering
- follow camera
- enemy pursuit/spawn infrastructure
- auto-targeting of enemies
- bullet/projectile handling
- anti-burst / hit-cooldown protections
- damage caps and damage-source telemetry
- enemy off-screen/readability feedback
- object pooling / batching and mobile performance safeguards
- wave timing framework
- run telemetry
- modal queue that prevents overlapping menus
- signed Android export and regression validation

These are implementation assets, not design constraints. Mutation effects should call into these shared combat primitives where possible rather than duplicating them.

## 6. Current enemy roster

The Stage 2 prototype already contains a useful enemy framework and art/runtime definitions for:

- Shambler
- Runner
- Bloater
- Spitter
- Brute
- Elite variants
- Mechanic mini-boss

The new mutation/city spec does not ask to remove the enemy roster, so these should remain unless a later balancing milestone changes them.

## 7. Current puzzles, objectives and boss status

The existing prototype **does have environmental objectives worth preserving conceptually**, although the implementation is tightly coupled to the Outskirts map.

The current Stage 2 timed-event schedule includes:

- generator charging
- supply collection
- ordered gas-pump chain reaction
- fuel delivery
- Mechanic mini-boss
- motel lockdown switches
- oil-trap lure
- relay pads
- infestation nest
- wave-10 Final Stand

This is strong precedent for the new district-objective direction. The rebuild should preserve the design principle that the environment is interactive and can become a weapon, but the old event scheduler should not be copied wholesale into the new modular district system.

### Boss status

There is **no completed district boss matching the new wave-8 boss requirement** in the current active build. Wave 10 is a Final Stand placeholder. The Mechanic is a timed mini-boss event, not a full district boss.

Therefore the audit answers the first open question in the new spec as follows:

- Existing puzzles/objectives: **yes, conceptually worth keeping and adapting**.
- Existing full boss: **no, nothing should be carried forward as the wave-8 boss implementation**.

## 8. Current environmental hazards

The current map already contains useful environmental-combat concepts:

- fuel pumps / explosive props
- cars
- oil areas
- barricades/fences
- objective props
- tanker / industrial scenery
- hazard telemetry and tuned explosion behavior

Recent fixes also ensure automatic targeting does not deliberately select pumps and restrict which splash sources can heat explosives.

These concepts should be preserved when the new generic `Hazard` system is introduced, but reactions must become data-driven through `reacts_to` tags rather than map-specific conditionals.

## 9. What the rebuild replaces

The following current systems are intended to be retired or substantially replaced by the new spec:

1. **Level-up weapon/passive picker**
   - replaced by five body-slot mutation offers.

2. **Hard-coded evolution pair system**
   - replaced by data-driven mutation fusion.

3. **Current rarity-centric upgrade ownership model**
   - not part of the mutation spec.

4. **Single giant Outskirts map**
   - replaced by four modular district tiles in a 2 x 2 layout.

5. **Map-specific objective/event coupling**
   - replaced by district scenes, reusable hazards and generic wave events.

6. **Hard-coded effect-combination logic**
   - replaced by tag statuses, stack thresholds and combo data.

7. **Current visual survivor as a single static identity**
   - later replaced/extended with layered body-slot mutation sprites and mutation-stage forms.

## 10. What stays

The following should remain unless later milestones require otherwise:

- Godot 4.4.1 build/export toolchain
- Android package/signing identity
- portrait mobile viewport and safe mobile rendering approach
- touch movement
- camera behavior
- basic enemy actor framework
- current enemy roster
- low-level projectile/combat primitives
- fairness protections
- performance caps/object pooling
- telemetry/logging infrastructure
- modal queue pattern
- existing approved art kept untouched until the art milestone
- current Outskirts files retained in the repository as inactive reference after modular districts replace them

## 11. Architecture migration risk

The largest technical risk is that `outskirts.gd` currently owns too many responsibilities: map encoding, spawning, combat state, objectives, hazards, wave state and presentation hooks.

The new spec is directionally correct to split rules into:

- DataRegistry
- EventBus
- RunState
- MutationManager
- StatusSystem
- MapBuilder
- WaveDirector

Milestone 2 should add only the backbone and validation while preserving current gameplay byte-for-behavior as much as practical. Systems should then migrate behind the event bus incrementally. A wholesale rewrite in one milestone would create unnecessary regression risk.

## 12. Baseline decisions for Milestone 2

Subject to owner approval of this audit:

- Base implementation branch: `feature/stage2-early-tuning` @ `a9349f8...`.
- Godot version target: 4.4.1 stable.
- New data root: `res://data/`.
- New autoloads may be introduced without routing existing gameplay through them yet.
- Existing gameplay must remain playable and visually unchanged during Milestone 2.
- No ComfyUI/art generation is needed before Milestone 8.
- No audio work is introduced.
- No boss implementation begins in Milestone 2.

## 13. Open owner decisions carried forward

These are explicitly unresolved in the rebuild spec and should not be guessed:

1. Keep the current Scrap SMG as the starting attack, or replace the starting attack with a mutation.
2. Final fixed district tile size after validating phone-visible world scale.
3. Whether later runs unlock persistent content; meta-progression remains out of scope now.
4. Wave-8 boss concept: large zombie vs mutated survivor rival.

Only item 1 can affect Milestone 3 directly. Items 2 and 4 can remain deferred until their relevant milestones.

## Milestone 1 acceptance

Milestone 1 makes no gameplay changes.

Acceptance requirement: **owner reads and approves this audit before Milestone 2 begins.**
