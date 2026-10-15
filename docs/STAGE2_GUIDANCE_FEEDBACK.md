# Stage 2 guidance and approved zombie presentation

Base: tested integration commit `30d13cd4435911dfca2a80ab669b61cc905546b2`.
Artwork: user-selected curation `curation-1821f5654302f816c1f7881b`, pinned asset commit `d070c9a05072436d14a826f05bfe434607ea82c7`.

## Scope
- Exact selected character PNGs under `res://art/characters/`, foot anchors, pooled Y-sorted Sprite2D bodies, uniform height scaling, shared dark-outline shader and soft ellipse shadows. No generated replacement art.
- Survivor visible height 96; shambler/spitter 62.4 (65%), runner 57.6 (60%), elite 81.12 (1.3x shambler), bloater/brute/mechanic 93.6 (1.5x shambler). Ground collider radius is height x 0.28. Enemy health, speed, damage and spawn/density settings remain unchanged. Collision footprints intentionally change with presentation per feedback; this can affect contact outcomes.
- One objective registry for the minimap, expanded labeled map/reward list, current objective card, 1.5-second briefing hold, skippable camera pan, world beacon and obstacle-aware dotted path. The meter scale is 4 meters per 128-unit tile. Briefings/maps pause combat and never grant health.
- Wave titles use current wave; active wave banner subtitle uses current objective. Old queued wave banners are discarded when the wave changes.
- XP collection multiplier 0.60 after level 2; fractional credit accumulates. No changes to enemy density or drop rules. First six XP still reach level 2. Raw/credited XP and each level-up time are logged. L10-12 at 180 seconds remains a human-play calibration goal, not a guaranteed level regardless of kills.
- Real title menu precedes runs. Boss artwork/animation and the broader Stage 2 toolkit remain deferred. The previous erroneous Trucker->elite texture mapping is removed.

## Verification
`tools/verify_feedback_contract.py` verifies exact PNG digests and unchanged difficulty config.
`feedback_tests.gd` covers ratios, collisions, 13 objective locations, path obstruction, collected-target advance, current banners, tap-skip, map pause/resume, XP replay and pool reuse at 180 enemies.
`feedback_evidence.gd` produces actual renderer screenshots, a desktop stress sample and a three-minute scripted-input recording from the real title menu. Gameplay recording has normal damage and no automatic revivals. Stress mode alone uses invulnerability and high enemy health to retain its 180-enemy fixture; it is not a gameplay run.
Desktop llvmpipe numbers are NOT Samsung S25 results. Target-device frame timing and visual acceptance remain required after installing the APK.

Existing project reference filenames POLISH_SPEC.md and OUTSKIRTS_ART_TARGET.png were not present in this checkout. The implementation uses the user's explicit feedback and selected-art receipt, without claiming a comparison against missing references.
