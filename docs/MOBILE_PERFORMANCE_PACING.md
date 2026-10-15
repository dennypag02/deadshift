# Mobile performance and pacing pass

State: RUNNING - implementation and measured validation in progress.
Base: 18fb452444978f09dba7c7335c4bb4ca1281d2b5 (approved guidance/art build).

Scope authorized by user:
- Preserve exact approved character source PNGs, scale, objective guidance and enemy combat/spawn data.
- Shared derived atlas and MultiMesh batches for zombies/shadows/gems/terrain; no per-zombie scene nodes.
- Bounded reusable transient records, spatial broad phase, reduced off-screen AI/steering work.
- CORE_LOOP_SPEC section 14: 250 enemies, 400 combined projectiles, merge gems above 200, 40 damage numbers. Existing blood decal cap 40; explicit particle/effect budgets in data.
- Front-loaded XP via data only: L2 around 8-10s, early 10-15s gaps, later 20-30s, target level 10-12 at 180s.
- Wave 1 60s; subsequent waves 67.5s; 8s surge inside the deadline; 4s break. Timer uses unscaled active combat time, not hit-stop time. UI/map/briefing pauses excluded and logged separately. Remaining zombies persist.
- Main objective routes become clear asphalt without moving blockers or deleting off-route slow terrain.
- FPS, p95 frame time, active entity counts, wave starts/ends and level events in pacing JSONL/log.

Evidence requirements:
- Strict Godot tests and exact approved-art hashes.
- Before/after identical 220-enemy six-weapon stress fixture. Desktop llvmpipe is not phone performance.
- Three-minute-from-title normal-damage recording, scripted input, explicitly label offline frame rendering.
- Signed Android APK, extracted and checksum-verified, delivered in chat.
- 60 FPS on the user's Samsung phone with 200+ enemies remains physical-device acceptance; do not report a desktop or fixed-FPS recording as that pass.

No new boss work or asset regeneration. Stop after delivery for phone feedback.
