# Part 2: placeholder audio systems

Part 1 was independently merged and delivered as signed APK 0.1.233 with min-HP CSV and logs before audio work began. Its tuning, anti-camp, wave rhythm, promoted icons and objective behavior are preserved. The original SOUND_SPEC.md is copied byte-for-byte into docs/ (Git blob 85d515a92793b777d47e9fe2af21a74160b74628).

## Runtime
SoundManager is the single audio autoload. Master/Music/SFX/UI buses use the specified defaults; Music has a low-pass effect and SFX/Master have -1 dB hard limiters. Twenty-four pooled positional players can grow to thirty, with two reserved music players: total hard cap 32. Per-ID limits, cooldowns, priority, pitch/volume variation and non-repeating variants are data-driven. Protected warning/reward cues wait or coalesce when no lower-priority voice can be replaced. Audio randomness is independent of gameplay RNG.

Saved settings in user://audio_settings.cfg include Music/Effects/UI sliders, Mute all and Vibration. Settings and Credits are reachable from title and pause. Background notifications suspend playback and suppress new cues. Adaptive phase filtering/volume, ducking, XP semitone-climb and current gameplay cue hooks are implemented.

The 66 SFX IDs use 36 cached 44.1kHz mono WAV resources synthesized from nine original in-house jsfxr-compatible oscillator/envelope presets. This is a documented subset, not unmodified upstream jsfxr output. CREDITS.md lists every runtime resource. Five music roles currently share one original synthetic Ogg timing loop with different pitch/tempo behavior; these are placeholders, not final soundtrack pieces. Trucker cues are catalog hooks for a later boss stage, not newly implemented boss gameplay. No third-party sounds or AI audio were promoted and no PC installations were performed.

## Pipeline delivery limitation
The separate local audio_pipeline implementation contains sounds.yaml (66 SFX plus five music pieces), find_sfx.py, generate_audio.py, review_audio.py/html, promote_audio.py, API-template adaptations, configuration, 14 isolated safety tests and a PC setup guide. Its GitHub upload was blocked by a safety check. That blocked request was NOT retried through another route. These pipeline files are delivered in DeadShift-Audio-Pipeline.zip; they are not claimed to be in this repository. The ZIP guide includes extraction into a separate audio worktree without disturbing the running art worker.

Pipeline defaults are non-writing dry runs. Real generation is loopback-only and one job at a time, with provenance/license checks. Selection and processed-preview approval are separate; no-overwrite promotion requires explicit hashes and never switches runtime mappings or pushes to GitHub. Only temporary in-house synthetic fixtures were used for tests. Actual Stable Audio 3 execution on the owner's PC and approval of real sound candidates remain future steps.

## Evidence and acceptance
All seven local gameplay regression suites pass, including 343 audio, 100 tuning and 234 retained movement/fairness assertions. Full-source PR CI 38901195641 and Godot validation 38901195702 passed. The actual-engine 720x1600 H264/AAC recording has 203.9 total seconds, 180.033 active gameplay seconds, normal damage and god mode OFF; it ends at level 9 with 65 HP. Recorded wave minimum HP is 96%, 79%, and 65% (wave 3 partial). It is not physical-phone footage or an FPS benchmark.

Most human deaths in waves 5-9, phone speaker audibility, sustained 60 FPS and ten-minute annoyance/readability remain user acceptance items. Final signed APK, checksums, Android evidence and artifact-delivery receipt are recorded on PR #23 after retrieval. Do not interpret this document as a claim that real audio selection, model setup, or pipeline GitHub publication is complete.
