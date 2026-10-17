# DeadShift Rebuild Changelog

Newest entries first. Do not delete historical entries.

## 2026-10-17 — Milestone 3 mutation progression implementation

- Owner phone-tested Milestone 2 and confirmed it felt exactly the same; PR #31 merged as `b77ce885317726ebfa553d18075ef95de41d9515`.
- Added the 15 starter mutations from the approved spec as one JSON file per mutation: three each for arms, legs, torso, back and head.
- Added `MutationManager` with five-slot ownership, three random offers, max level 3, replacement behavior, tag counting and the eight approved generic effect types.
- Kept the prototype Scrap SMG as the mutation-free starting attack, matching the spec's explicit first-run rule.
- Replaced XP-driven weapon/passive choices with between-wave mutation offers. XP and player level remain for existing difficulty scaling and telemetry only.
- Added a 15-second between-wave picker with Skip and two-tap replacement confirmation.
- Added placeholder gameplay visuals, allied crawler placeholders, and the five tag-count HUD pills. Production mutation art remains deferred to Milestone 8.
- Mutation effects emit `hit_landed` with their tags; persistent statuses, tag-stack bonuses, combos, mutation meter and fusion are intentionally not implemented before their later milestones.
- Added deterministic tests for 15 definitions, 5 slots, level 1–3, replacement, dual-tag counts and 3-offer generation.
- Extended signed Android CI to run the mutation tests while retaining all Stage 2 regression suites.

## 2026-10-16 — Milestone 2 stale APK asset assertion and fix

- Signed APK run `38994808724` passed Godot import, DataRegistry validation, all seven legacy regression suites, and APK export.
- It then failed only in package-content verification because the workflow still expected six whole-building PNGs that PR #29 had explicitly rejected and replaced with SVG placeholders.
- Updated the verifier to require the current canonical placeholder basenames for diner, minimart, motel north/east, auto shop, and canopy while continuing to require promoted PNGs for the remaining Outskirts/objective/decal assets.
- This is a CI-evidence correction to match the already-approved Stage 2 baseline; no game resource, gameplay code, tuning, collision, art selection, audio, objective, or mutation behavior changed.

## 2026-10-16 — Milestone 2 validator array-type failure and fix

- Signed APK run `38994519094` failed in the new DataRegistry test and timed out before legacy suites could complete.
- The malformed-JSON check itself produced the expected clear `DATAREGISTRY_ERROR ... malformed_json` message.
- The next missing-field probe called `validate_json_file` dynamically with a generic `Array`, while the validator parameter was declared `Array[String]`; Godot rejected the runtime type mismatch.
- Changed only the validator's optional `required_fields` parameter to generic `Array`, preserving string field checks internally and allowing deterministic dynamic test calls.
- No gameplay, map, combat, tuning, art, audio, collision, objective, or mutation behavior changed.

## 2026-10-16 — Milestone 2 CI typing failure and fix

- Signed APK run `38994426266` failed before export in the regression step.
- Existing approved-art/base-combat and silent-audio contract checks passed.
- Failure was isolated to `godot/tests/data_registry_test.gd`: Godot 4.4.1 refused inferred types for dynamically instantiated test objects.
- Fixed the test to use explicit `Script`, `Node`, `Array`, `int`, and `bool` types plus dynamic `call/get` access.
- No runtime gameplay code, tuning, art, collision, audio, or mutation behavior changed.

## 2026-10-16 — Milestone 2 data and event backbone

- Owner approved Milestone 1; PR #30 merged into the Stage 2 gameplay baseline as `758cfaecc0b919d4058465438828e5952a965148`.
- Added inert Godot autoloads: `DataRegistry`, `EventBus`, and `RunState`.
- Added `res://data/mutations/` as the first rebuild-owned data folder without adding mutation gameplay yet.
- `DataRegistry` recursively loads JSON, reports malformed JSON and missing required fields with explicit `DATAREGISTRY_ERROR` messages, and leaves schema-specific validation for the milestones that introduce those schemas.
- Added deterministic malformed-JSON and missing-field tests.
- Existing Stage 2 gameplay remains the active runtime; no existing weapons, passives, map, enemy behavior, art, audio, collision, tuning, or objectives were rewired.
- Extended the signed Android workflow to validate this milestone branch and include the new registry regression test.

## 2026-10-16 — Milestone 1 audit baseline selection

- Audited the current playable prototype from `feature/stage2-early-tuning` at `a9349f80d5c05df06738a599a0e8c2c458404f61`.
- Repository default branch `main` is an older React Native prototype and is not the current gameplay baseline.
- No gameplay or art changed.
- Created `docs/AUDIT.md` documenting the Godot version, current progression/power-up system, map structure, systems to replace, systems to preserve, and unresolved owner decisions.
- Milestone 2 remains blocked on owner approval of the audit.
