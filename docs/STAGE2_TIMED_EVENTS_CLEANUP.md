# Stage 2 timed-event cleanup

Baseline: approved mobile-performance build 0.1.229, commit `412307603ca132f0b726ff5140f43f1589fa8ee9` on `feature/phase-a-progression`. PR #19 continues that branch, not the older default-branch prototype. No artwork promotion or End Boss work.

## Requested behavior

- `stage2_events.gd` owns the active optional event. One offer per wave; completing, missing, or interrupting it never immediately starts another offer. The next offer waits for the next wave. Missing objectives does not gate district progression.
- The HUD's crate row is visible only for supplies. Generator progress is uninterrupted charge percentage; damage resets charge. Nest progress is actual HP damaged by shots, not proximity. Relay progress is ordered pads completed. An outer countdown ring is separate from objective progress, and the card displays the existing approved reward icon. Banner text includes objective, available time, and reward. Expiration clears guidance and produces a quiet two-second `MISSED` toast.
- First generator offer only: initial groups, horde target, and applicable surge count use a 0.60 multiplier. The central spawn gate excludes both the direct player-to-target approach and the existing obstacle-aware route. It does not teleport or remove existing enemies. Protection ends immediately on completion, miss, or interruption; later ordinary pressure is unchanged.
- The event configuration is in `godot/data/stage2_events.json`. It connects the previously specified wave offers to existing gameplay objects/rewards. Approved character/environment PNGs, renderer/atlas, base combat configuration, XP data, ordinary wave deadlines and breaks remain unchanged. Full later-event and final-stand game feel still requires device acceptance; this is not an End Boss implementation.

## Durable per-attempt telemetry

`run_telemetry.gd` writes append-only `events.jsonl` and an atomic `summary.json` under `user://runs/<run_id>/`. It also prints JSON rows with the `STAGE2` prefix for diagnostic capture. These are local logs, not network uploads.

Records include offers, outcomes, elapsed/completion time, rewards, wave starts/ends and partial waves, minimum HP and percentage, damage source totals, level timestamps, and early-death classification. HP is sampled at damage time so a low-HP moment immediately followed by healing is retained. Events interrupted by death/retry/capture end are not silently counted as missed. Counts reconcile: offered = completed + missed + interrupted + active.

Actual human attempts have `run_kind=human` and an installation-local attempt number/first-run flag. Scripted validation uses an explicit separate run kind. A three-minute sample ending in wave 3 is censored, not evidence of survival to wave 4. Unfinished/crashed runs must not be counted as survivors. Do not infer a human first-run survival rate from the scripted fixture.

## Reproduction and validation

Godot 4.4.1; seven strict suites: `stage2_tests`, `performance_tests`, `feedback_tests`, `phase_a_xp_check`, `phase_b_check`, `survivability_ui_check`, `hud_layout_check`. `tools/verify_mobile_contract.py` verifies all 45 promoted original artwork hashes and the preserved base configuration. Dedicated assertions test typed progress, deadline pauses, hit interruption, reward idempotence, spawn exclusion, expiry, 5-HP-then-heal telemetry, early-death classification, accounting and durable summaries.

The canonical Android workflow remains `v3-godot-android-apk.yml`, using the existing stable development signing certificate. It verifies packaged event data, scripts, signature and source checksums. The canonical capture workflow remains `phase-a-pacing-capture.yml`, now using `performance_capture.gd` with normal damage, god mode OFF, seed 20261015, 180 active seconds and the actual title screen. It records an early death honestly rather than reviving, fabricating or waiting forever.

Six separate headless scripted qualification runs use seeds 20261015 through 20261020 and stop at 210 active seconds or normal death. Preserve every result, including failures. These are not representative player measurements or a frame-rate benchmark.

Source transport: `apply_stage2_v2.py` validates the three v2 chunks and every before/after hash before writing any file, runs tests, then commits ordinary readable source. The older incomplete `stage2_source_01.b64` is not applied. The actual committed Godot files, not transport chunks, are the runtime source of truth.

## Acceptance boundary

GitHub jobs, source hashes and artifact checks establish implementation/build evidence. The fixed-30-fps movie is real desktop Godot rendering with scripted controls, not Android footage or proof of 60fps. Target-phone performance, subjective readability and real first-attempt survival frequency remain device/player acceptance items. Keep the preserved failed progress-comment run 38786756499 as failure evidence; its permission restriction was repaired without broadening app permissions.
