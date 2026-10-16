# Exact October 14-15 execution restored at owner request

The owner explicitly requested the original workflow without deviation. This supersedes the previous model-switch implementation for this batch. The uploaded assets_batch_world.yaml is retained unchanged; no re-upload is required.

## Runtime

Restore generate.py to Git blob b5211781f309453071d55df9d089ac7f013397de from d070c9a05072436d14a826f05bfe434607ea82c7. Keep local_worker.py, build_workflows.py, review.py, asset_approval.py, project_library.py, curation_sync.py, curated_png_sync.py and inspect_comfy.py byte-for-byte as at that same revision. Tests assert all nine blob hashes.

The path is unchanged: GitHub jobs/queued on feature/asset-pipeline-step1 -> existing Windows local_worker.py -> original generate.py -> existing ComfyUI API sprite graph (SDXL base, KSampler, VAE Decode, RMBG-2.0 Alpha, SaveImage) -> original review.py / Asset Library -> owner's selection -> separate explicit promotion. Original sampler defaults and original resizing remain unchanged. No new runner, CPU inference helper, interpreter discovery, model installation, package installation, anchor approval gate, or mandatory reference-file gate is active in this path.

The abandoned world_v2 modules and failed receipts remain as history, not execution. The two failed v2 jobs are archived outside jobs/queued so the restored original parser cannot misinterpret them. No local model cache or user file is deleted. Existing queued jobs and processed-state records remain untouched.

## Input data only

The original 83 manifest entries and all original categories are preserved. Add the submitted decals category (workflow sprite) and 15 new sprite entries: nine objective props and six decals. Result: 98 entries. No duplicate existing name is appended or treated as proof of generated art.

Preserved duplicate names from the 34-entry request:
out_diner, out_minimart, out_motel_north, out_motel_east, out_autoshop, out_canopy_roof, out_semi_trailer, out_pump_island, out_barrels, out_barrier, out_fence, out_tanker_wreck, tex_asphalt, tex_highway, tex_forecourt, tex_gravel, tex_scrub.

27 standard original-schema sprite jobs are prepared, four candidates per asset: 108 planned candidates. Each uses the existing category style plus the effective manifest prompt; red is appended to its negative prompt as required by the submitted brief. These are configuration inputs, not code-path changes. No asset is selected, overwritten, promoted or added to the game by generation.

## Explicit unsupported portion

All seven requested seamless textures remain pending: tex_asphalt, tex_highway, tex_forecourt, tex_sidewalk, tex_gravel, tex_scrub, tex_grass. The exact historical loader accepts only sprite and scene, not workflow texture; its scene path has no seam repair. Do not relabel texture as scene or invent a tiling implementation and call it the same workflow. Existing five terrain definitions remain unchanged but are not queued as though they satisfy the new seamless requirement. No new texture pipeline is authorized by this restoration.

The source-audited 12 building/structure targets are unchanged. No engine collision/placement edits occur. OUTSKIRTS_ART_TARGET.png has not been visually verified in this chat; matching its text description is not proof of reference-image matching. This original pipeline has no mandatory reference file check; none is introduced.

## Evidence limits

CI tests and dry-runs prove source equality/configuration, not PC generation. The old worker does not publish the new world-v2 progress branch. Old world_status.json is historical and must not be used as status of these new jobs. Read the existing local worker/library for actual generation results; never claim completion from queue publication.

Generation is for candidate review. Restoring the historical RMBG-2.0 choice is not commercial-license clearance; promotion/publication still requires applicable rights. No commercial release or APK is performed here. The preserved historical audit tests use the frozen original manifest fixture rather than misinterpreting the expanded live manifest as that old snapshot.
