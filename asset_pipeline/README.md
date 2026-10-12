# DeadShift automated asset pipeline

This folder builds local game art with ComfyUI and prepares it for the Godot project.

## Step 1 - inspect ComfyUI

Keep ComfyUI Desktop open, then run:

```powershell
python inspect_comfy.py
```

The inspector detects port 8000 or 8188 and checks the configured SDXL checkpoint and RMBG nodes.

## Step 2 - build API workflows

Run:

```powershell
python build_workflows.py
```

The builder reads the live `/object_info` schema before writing anything. It refuses to build if the expected node classes, required inputs, SDXL checkpoint, `RMBG-2.0` model, or Alpha background option are unavailable.

It writes:

- `workflow_sprite.json`: SDXL -> prompts -> latent -> KSampler -> VAE Decode -> RMBG-2.0 (Alpha) -> SaveImage
- `workflow_scene.json`: SDXL -> prompts -> latent -> KSampler -> VAE Decode -> SaveImage

Both workflows use batch size 1. Default sampling is `dpmpp_2m`, `karras`, 28 steps, CFG 6.5, denoise 1.0. The generator will raise steps to 30 for arenas/screens.

The JSON files use clear titles and placeholder values so `generate.py` can replace positive prompt, negative prompt, width, height, seed, and filename prefix.

## Safety rules

- Local/free ComfyUI only; never use Partner/API paid nodes.
- Generate one image at a time.
- Never overwrite existing Godot art without asking.
- Do not install additional packages or models without approval.
- Preserve prompt and seed for every generated candidate.

## Next implementation slice

`generate.py`, `review.py`, `promote.py`, `manifest.json`, `picks.yaml`, and staging folders are added after the two API workflows pass the local schema/build test.
