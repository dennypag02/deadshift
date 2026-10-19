# Autonomous Visual Improvement Pipeline v1 — Foundation

Status: implementation plan; not yet operational.
Owner: creative director. Personal GitHub identity: dennypag02.
Target: DeadShift, one deterministic high-density-combat HUD readability scenario.

## Approval boundaries
- Owner approves versioned Art Direction Briefs before they guide generation or review.
- Owner approves every ComfyUI asset promotion; all generated assets remain candidates.
- Owner merges pull requests. Agents work on feature branches and never push to main.
- Routine coding, tests and capture proceed autonomously within the approved scope.

## v1 acceptance
1. Seeded Godot Movie Maker capture of high-density combat HUD.
2. Tier 0 checks: UI node bounds/overlap, minimum text size, contrast, missing textures, unexpected opaque backgrounds. Instrument scene hierarchy; do not infer node geometry from pixels alone.
3. Tier 1: benchmark-qualified local vision model for HUD readability, with structured evidence and uncertainty.
4. One scoped safe fix to the XP-bar/text obstruction; gameplay and approved assets preserved.
5. Rebuild, same-seed recapture, before/after comparison, regression checks, and verified APK SHA-256.
6. PR-only output; owner merges. No auto-promotion of art.

## Vision evaluation
- Keep original screenshots and annotations as CI artifacts or Git LFS, not ordinary Git blobs.
- Create labeled eval cases from actual DeadShift captures, including seeded known defects and clean controls.
- Measure precision/recall per tier, with sample counts, holdout separation, model ID, quantization, VRAM and latency.
- Proposed initial Tier 1 thresholds: critical-defect recall >= 0.90 and precision >= 0.85; revise only with recorded rationale.
- Failure to qualify is REVIEW_UNQUALIFIED, not an implicit pass or paid API fallback.
- Model baseline candidate: Ollama qwen2.5vl:3b (owner locally verified load and image inference, **not** accuracy).
- Initial qualitative findings: false claims of health-bar/minimap overlap; partial claim of arsenal/event overlap; plausible arsenal readability issue; missed XP-bar text obstruction. These must be confirmed as labeled examples before metric computation.

## Reference intelligence
- Reference library tracks source, purpose, usage type, license and attribution as applicable.
- Third-party game references: design-principle analysis only. Never use them as img2img, ControlNet or IP-Adapter inputs for promotable assets.
- Owner-approved project art may be used for consistency.
- Versioned Art Direction Brief schema: palette, materials, lighting, UI principles, readability rules, provenance, owner approval record.
- Tier 2 brief-consistency interface exists in v1 but is not a gate until approved brief and qualified reviewer.
- Tier 3 multi-game reference analysis is a stub in v1; no autonomous reference-inspired generation yet.
- All generation must follow Standard ComfyUI Game Asset Workflow v2; exact authoritative repository path must be verified before integration.

## GPU/runner safety
- Self-hosted Windows GPU runner must run in the logged-in interactive user session, not Session 0.
- Require AC power and sleep-disabled during work; log NVIDIA driver, GPU, renderer and session.
- One exclusive cross-workflow GPU lease for Godot capture, Ollama vision and ComfyUI. No concurrent GPU jobs.
- Fail closed if ComfyUI status cannot be checked or GPU lease cannot be acquired; never continue after timeout.
- Recover cleanly from disconnected/sleeping runner or report FAILED; provide a kill switch.
- Use debug-only seeded scenario/input loader, absent from release APK.
- Android device verification distinct from emulator/desktop FPS; signing secrets never in repository.
- Record artifact retention and checksums.

## Known audit findings
- Existing .github/workflows/gpu-visual-capture.yml uses self-hosted Windows gpu runner, seeded capture and 180-enemy stress.
- Its ComfyUI wait currently proceeds after 30-minute timeout and treats connection failure as idle: unsafe; replace before production use.
- Runner appeared online/idle in owner's GitHub screenshot; Windows nvidia-smi reports RTX 3060 6 GB.
- Ollama 0.40.6 and qwen2.5vl:3b tested by owner, 100% GPU reported.
- Runner-session and in-job GPU access still need independent CI verification.

## Implementation order
1. Verify runner session and run GPU smoke test in Actions.
2. Add GPU lease + fail-closed scheduling and evidence capture.
3. Build labeled eval harness and Tier 0/Tier 1 review adapters.
4. Benchmark, gate and record model performance.
5. Verify personal GitHub bridge supports autonomous image-finding -> coding task -> PR path.
6. Execute one-scenario acceptance and deliver APK evidence.
