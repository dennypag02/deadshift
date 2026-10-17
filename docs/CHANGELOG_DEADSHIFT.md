# DeadShift Rebuild Changelog

Newest entries first. Do not delete historical entries.

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
