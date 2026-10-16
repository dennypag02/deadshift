# Outskirts world batch: preparation and unresolved generation gates

Status: offline intake/audit implemented. No image generation, promotion, model installation, or live assets.yaml change.

## Source and branch boundaries

User request: batches/assets_batch_world.yaml, preserved byte for byte.
Request SHA-256: a97a1eb034ae2db0463912f9915344f774dcb24f90adc26dbe76b117f2928e04.
Pipeline baseline: feature/asset-pipeline-step1 at d070c9a05072436d14a826f05bfe434607ea82c7.
Gameplay source inspected: 20f06d229591417315ce8506779541da527cb3f1, godot/scripts/outskirts.gd.
The game-source file hash is checked before attributing the report to that commit. This is source analysis, not a Godot or phone test.

This work is on assets/outskirts-world-v2. It does not change the gameplay branch, approved PNGs, worker job queue, or existing manifest. Do not merge the proposed manifest into the live generator until its v2 execution path is ready.

## Intake result

34 requested entries, 17 existing names preserved, 17 new entries proposed.
New entries: 9 objective props in debris, 6 ground decals, 2 textures.
Four candidates per new entry = 68 planned new images. Zero images queued.
The proposed merged manifest contains the original 83 entries unchanged plus 17 new entries: 100 total.
An existing name does NOT prove an image was generated, approved, or integrated.

Preserved duplicate names:
- Buildings: out_diner, out_minimart, out_motel_north, out_motel_east, out_autoshop, out_canopy_roof.
- Structures: out_semi_trailer, out_pump_island, out_barrels, out_barrier, out_fence, out_tanker_wreck.
- Terrain: tex_asphalt, tex_highway, tex_forecourt, tex_gravel, tex_scrub.

The five existing terrain entries remain category terrain with 128 x 128 targets. They are not silently migrated to the submitted textures category at 256 x 256. tex_sidewalk and tex_grass are new. Other duplicate differences, including seed_group and forecourt prompt changes, are reported without overwriting the original entries.

## Footprints and alignment

All twelve submitted building/structure canvas dimensions match the current source render dimensions. No target-size change is needed in this snapshot.
The collision audit preserves per-placement static masks instead of treating every art rectangle as solid.
The canopy is a passable overlay with eight underlying pump blocker cells, not an 80-cell solid building. Tanker K cells are not movement blockers.

Two existing placement discrepancies need attention during approved-art integration, not a physics change:
- Eastern trailer: rendered tile origin (27,22), collision origin (28,22), same 2 x 7 footprint. Art should move 128 px right.
- Eastern fence: rendered tile origin (23,2), collision origin (22,2), same 6 x 1 footprint. Art should move 128 px left.

No placement or collision change has been applied by this preparation task.

## Why generation is held

The current sprite graph requests BRIA RMBG-2.0. Its publicly available weights require a separate agreement for commercial use. No commercial entitlement was established in this audit. Do not use that graph for this batch by default.
Official source checked October 16, 2026: https://huggingface.co/briaai/RMBG-2.0

Official ZhengPeng7/BiRefNet is a potential local alternative; its model card identifies MIT licensing. Check the exact installed model, node code and license before use. Do not assume that a BRIA model is covered just because it uses BiRefNet architecture. No model/node/package installation is authorized by this file.
Model card: https://huggingface.co/ZhengPeng7/BiRefNet
License: https://huggingface.co/ZhengPeng7/BiRefNet/blob/0e818151209a9d201f0603120ce986311bd34e7c/BiRefNet_github/LICENSE
SDXL base license: https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md

Remaining implementation/verification work before running the new batch:
1. Inspect the PC's existing licensed background-removal setup; request approval before installing anything missing.
2. Add the real texture workflow with offset/inpaint or circular padding, no background removal, and 3 x 3 seam checks. The old generator accepts sprite/scene only.
3. Replace fixed-size stretching in the execution path with alpha trim, uniform scale and explicit fit/pad/crop.
4. Record the full submitted graph, actual local checkpoint/model hashes, sampler settings, licenses and ComfyUI/custom-node versions for every candidate.
5. Retrieve and bind OUTSKIRTS_ART_TARGET.png and approved related-asset references. The filename is specified in the request, but its image bytes were not recovered during this audit. Shared seeds alone do not establish continuity.
6. Keep user selection/approval separate from cleanup, promotion, integration, Godot validation, Android build and phone review.

The world preflight script does not implement these missing generation steps or imply they passed. It does not contact localhost or make claims about whether the user's PC is online.

## Reproduce the audit

CI checks out the gameplay revision separately into _game_reference and runs:

```sh
python -m unittest discover -s asset_pipeline -p 'test_*.py' -v
python asset_pipeline/generate.py --dry-run
python asset_pipeline/world_batch.py --dry-run --game-source _game_reference/godot/scripts/outskirts.gd --report verification/world-audit.json
```

The last command emits a machine-readable audit plus assets_world_merge_PROPOSAL.yaml. The proposal is intentionally not installed over assets.yaml and is NOT compatible with the current legacy generator. Reports refuse to overwrite an existing output and cannot be written into asset_pipeline or godot.

CI uploads the report, proposal, source fingerprints, dry-run log and tests as a verification artifact. COMPLETE in world_batch output refers only to offline preflight; generation remains BLOCKED_PREFLIGHT and promotion remains NOT_STARTED.
