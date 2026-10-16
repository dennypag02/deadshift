# World art v2 execution: approved official BiRefNet

Owner approval: October 16, 2026, this Deadshift Asset Creation conversation.
Scope: official ZhengPeng7/BiRefNet background removal; install the model locally
only if missing. No new packages, custom nodes, paid nodes or cloud image generation.

## Delivery stages (do not conflate)

1. PR/CI validates software, not the PC installation or generated artwork.
2. Merge to feature/asset-pipeline-step1, the existing worker's polling branch.
3. Copy the tested planned job to jobs/queued. The existing worker launches the
   new generate.py entrypoint fresh. No worker process restart is required.
4. Local runtime identifies the existing ComfyUI Python, checks required installed
   packages, hashes the installed SDXL checkpoint, installs missing official model
   files, and tests a local model load. It does NOT install dependencies to fix a failure.
5. Resolve OUTSKIRTS_ART_TARGET.png. If unavailable, stop with
   ART_REFERENCE_REQUIRED after publishing model readiness. Do not generate a
   supposedly reference-matched image without the actual reference.
6. First visual review: four obj_generator anchor candidates. Related objective
   assets follow an explicitly approved reference, not shared seeds or auto-picks.
7. Candidate selection, final cleanup/promotion, provenance commit, Godot/APK and
   device review remain separate. Nothing is promoted by this runner.

The 34 requested names remain in scope. 17 are duplicate manifest entries, not
proof of generated/approved images. The v2 runner composes the existing definitions
with the 17 new entries in memory; it does not rewrite the live legacy manifest.
Existing 128px terrain entries remain 128px, not silently migrated to 256px.
Long-side-only sprites use an exact N x N transparent review canvas, with a
uniformly scaled object inside it. Source targets and collision are unchanged.

## Official model, not a similarly named dropdown

The current ComfyUI-RMBG add-on's BiRefNet-general option uses 1038lab/BiRefNet.
This task instead pins ZhengPeng7/BiRefNet revision
`e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4` and verifies its official weight SHA-256:
`9ab37426bf4de0567af6b5d21b16151357149139362e6e8992021b8ce356a154`.
It reuses any discovered local weights only after an exact hash match. Missing
files are fetched from that immutable official revision into ignored local staging.
Installed files are not overwritten. Every support file gets a recorded hash.

Sources checked October 16, 2026:
- https://huggingface.co/ZhengPeng7/BiRefNet
- https://huggingface.co/ZhengPeng7/BiRefNet/blob/main/model.safetensors
- https://github.com/ZhengPeng7/BiRefNet/blob/main/LICENSE (MIT)
- https://raw.githubusercontent.com/1038lab/ComfyUI-RMBG/main/py/AILab_BiRefNet.py
- https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/sd_xl_base_1.0.safetensors
- https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md

ComfyUI still generates images locally with SDXL. The official BiRefNet helper
uses the existing ComfyUI Python environment for a separate CPU alpha-preview
pass, avoiding competition with SDXL GPU memory. It loads local-only, pinned model
code, not a remote unpinned module. A preview is not on-device asset acceptance.

## Processing and provenance

Sprites: raw saved first; BiRefNet alpha preview; alpha bounds; uniform Lanczos
fit; exact transparent padding. No stretch. Unique filenames never replace prior
candidates. Terrain: no background removal; explicit half-offset cross-mask
inpainting, periodic edge blending, exact opposite-edge check, full-size and
final-size 3x3 grids. Edge equality does not prove visual quality; inspect the grids.
Related assets use an explicit reference_asset bound to an asset_approvals.json
record and candidate hash; unapproved references are rejected.

Each candidate gets full raw/inpaint API graphs, submission IDs, history, raw
image, effective specification, source geometry lock, source reference hashes,
checkpoint hash, model/support-file hashes, dependency versions, ComfyUI system
metadata, sampler parameters and processing choices. Raw images/model caches stay
local. Commit approved assets and the relevant records at promotion/integration.

A pending prompt marker prevents automatic duplicate submissions after an
ambiguous network failure. Reconcile its recorded prompt_id with ComfyUI history
before clearing it; don't blindly retry or cancel the user's other queued jobs.

## Local configuration (not committed)

Use `world_v2` keys in ignored asset_pipeline/local.yaml only where autodetection
cannot resolve an existing installation. All paths are values, never shell code:

```yaml
world_v2:
  comfyui_root: "<existing ComfyUI root>"
  python: "<existing ComfyUI Python executable>"
  checkpoint_path: "<existing sd_xl_base_1.0.safetensors>"
  birefnet_cache: "<optional existing official BiRefNet snapshot directory>"
  art_reference: "<existing OUTSKIRTS_ART_TARGET.png>"
```

Without an explicit art_reference, inspect only the repository/pipeline root,
asset_pipeline/references, docs, and the project's level-01 folder. There is no
whole-PC search. Metadata receipts contain no local paths, images or credentials.

## Live evidence

Local worker_status.json and staging/world_v2/latest_status.json receive milestones
and 120-second bounded heartbeats while this job executes. Metadata-only receipts
are pushed through the existing personal-repository Git auth to the isolated
`automation/world-asset-progress` branch, `world_status.json`. Non-forced pushes
only; no checkout changes and no use of the user's index. Publication failures
remain explicit in the local log and do not become fabricated remote progress.

No automation is scheduled by this file. A QUEUED record is not a PC acknowledgment;
MODEL_READY requires the actual local checksum and load test; COMPLETE is scoped
to the requested candidates, never an APK or device acceptance claim.
