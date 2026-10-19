# Vision benchmark protocol — v1

The smoke test proves that the GitHub runner can reach Ollama; it does **not**
prove that Qwen's answers are accurate or that a screenshot was sent from CI.

## Dataset construction
1. Capture reproducible high-density combat screenshots with the same viewport,
   seed, camera and HUD state. Store screenshots as Actions artifacts or LFS.
2. For each clean capture, create deterministic, isolated mutations of one UI
   defect at a time: XP-bar label obstruction, arsenal icon scale, HUD crowding,
   minimap obstruction, low contrast. Record mutation script and source SHA.
3. Retain clean controls with no injected defect. Do not assume every clean
   screenshot is defect-free; label pre-existing issues separately.
4. Use at least 10 **reviewed holdout cases** for preliminary qualification;
   expand substantially before unattended production approval.
5. Blind review the images and record defect IDs and visible evidence before
   examining model predictions. Use consistent severity definitions.
6. Keep development and holdout screenshot families disjoint by source scene,
   not just by file name, to prevent near-duplicate leakage.

## Label format
Each JSON case contains:
- id: unique case identifier
- split: development or holdout
- ground_truth: reviewed defect IDs
- predicted: model-returned defect IDs

The current scorer evaluates exact defect-ID matches. It does not yet measure
spatial localization, severity, calibration, or per-critical-defect recall.
It must not be described as a production-qualified visual reviewer.

## Initial exploratory screenshot
Owner screenshot test.png was manually reviewed in chat. Qwen's narrative
included unsupported overlap claims for health and minimap, a partly supported
arsenal/event crowding claim, and a plausible arsenal readability concern. A
text obstruction near the XP bar was not identified by Qwen. These are **notes**,
not machine-readable verified ground truth. Do not turn them into metric labels
without explicit image-level review and taxonomy mapping.

## Qualification policy
- Run `python tools/visual_intelligence/evaluate.py reviewed.json --split holdout`.
- Any insufficient sample size, zero prediction denominator, or failed
  precision/recall threshold results in REVIEW_UNQUALIFIED.
- Thresholds are provisional; do not silently tune them against the holdout.
- No automatic code modification based solely on a non-qualified vision model.
- Record model digest, prompt version, inference options, screenshot checksum,
  latency, VRAM peak, source commit and evaluation report.

## GPU coordination limitation
GitHub Actions concurrency groups serialize cooperating workflows only.
ComfyUI launched outside GitHub Actions is not automatically part of that
group. A genuine cross-process lease/arbiter is still required. Until it
exists, run ComfyUI and visual capture with explicit fail-closed queue checks
and do not claim exclusive GPU scheduling.
