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

## Step 3 - generate candidates

Pull the latest branch, then dry-run the first acceptance-test asset:

```powershell
git pull
python generate.py --only car_suv --count 2 --dry-run
```

A dry run prints the two planned jobs and queues nothing.

If the dry run looks correct, generate the two real candidates:

```powershell
python generate.py --only car_suv --count 2
```

The generator:

- detects ComfyUI on port 8000 or 8188;
- rebuilds workflow JSON automatically if it is missing;
- queues exactly one image at a time and waits for it to finish;
- uses random 63-bit seeds and records each seed and full prompt;
- downloads untouched ComfyUI output into `staging/raw/<category>/`;
- crops sprite output to its alpha bounds and resizes it with Pillow LANCZOS;
- resizes scene output to the configured target dimensions;
- writes game-ready candidates to `staging/candidates/<category>/`;
- appends each successful image immediately to `manifest.json`.

Generation defaults are `dpmpp_2m`, `karras`, CFG 6.5, denoise 1.0, batch size 1, 28 steps for sprites and 30 for scenes.

## Next implementation slice

After the two `car_suv` candidates succeed, add `review.py` and the HTML contact sheet, then `promote.py` and `picks.yaml`.


## No-terminal review workflow

For normal use on Windows, double-click:

`DeadShift-Asset-Review.bat`

The launcher automatically:

1. updates the current branch with `git pull --ff-only`;
2. runs the local ComfyUI generator for two `car_suv` candidates;
3. rebuilds and opens the HTML contact sheet in your browser;
4. asks you to pick one version, reject both, or quit;
5. if you reject both, generates the next pair automatically;
6. saves an accepted version into `picks.yaml`.

It never promotes or overwrites Godot art automatically. Promotion remains a separate explicit step.


## Chat-to-local worker

The one-time Windows setup is `Install-DeadShift-Worker.bat`.

After installation, the worker starts with Windows, polls the GitHub-backed
`jobs/queued/` folder every 20 seconds, waits for local ComfyUI when needed,
generates each batch sequentially, and serves the latest review at:

`http://127.0.0.1:8765/latest`

Normal operation requires no PowerShell or YAML editing. The user tells ChatGPT
the asset plus positive and negative prompt. ChatGPT queues the job in GitHub.
The local worker handles generation and opens the completed review automatically.

Local generated images, manifests, workflows, logs, worker state, and status are
ignored by Git and remain on the PC.

## Enemy, Trucker concept, and upgrade icon batch

The 48-asset batch is configured in `assets.yaml` (7 enemies, 2 Trucker concept
images, 39 icons). All have four versions by default, for 192 candidate images.
The `enemies`, `trucker`, and `icons` seed groups reuse the same seed for
the corresponding version across their members.

Optional per-asset settings: `size: [width, height]`, `target:
{long_side: N}` or `target: {width: W, height: H}`, `count: N`,
`negative_extra`, and `seed_group`. Command-line `--count` takes
precedence over the asset count. Old entries retain their previous defaults.
Configuration is validated before any jobs are queued.

From the repository root in PowerShell:

```powershell
git fetch origin
git switch assets/enemies-icons-batch
git pull --ff-only
cd asset_pipeline
python generate.py --dry-run
```

The dry run is offline and does not contact ComfyUI or create images.
**Important:** it covers *all* assets in the configuration, including the
35 existing ones. To generate just the new batch without also generating
existing assets, run the three categories separately with explicit `--only`
where categories contain older entries. The 39 icons can be generated with
`python generate.py --category icons`. Enemies and Trucker assets should be
selected by name, using `python generate.py --only NAME`, to avoid generating
the existing survivor and screen art.

ComfyUI must be started before real generation. The local generator creates
candidates only; review and promotion remain separate user-controlled steps.
Do not wire candidate art into the game.
