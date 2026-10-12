#!/usr/bin/env python3
"""Generate DeadShift art through the user's local ComfyUI server.

Reads assets.yaml, mutates the schema-validated API workflows, queues one image
at a time, downloads ComfyUI output, post-processes it with Pillow, and records
reproducibility metadata in manifest.json.
"""

from __future__ import annotations

import argparse
import copy
import json
import secrets
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
import yaml
from PIL import Image

HERE = Path(__file__).resolve().parent
ASSETS_PATH = HERE / "assets.yaml"
MANIFEST_PATH = HERE / "manifest.json"
RAW_DIR = HERE / "staging" / "raw"
CANDIDATE_DIR = HERE / "staging" / "candidates"
PORTS = (8000, 8188)
HOST = "127.0.0.1"
HTTP_TIMEOUT = 15
POLL_SECONDS = 1.0
JOB_TIMEOUT_SECONDS = 900


def get_json(base_url: str, path: str) -> Any:
    response = requests.get(f"{base_url}{path}", timeout=HTTP_TIMEOUT)
    response.raise_for_status()
    return response.json()


def detect_server() -> str:
    for port in PORTS:
        base_url = f"http://{HOST}:{port}"
        try:
            stats = get_json(base_url, "/system_stats")
            if isinstance(stats, dict):
                return base_url
        except (requests.RequestException, ValueError):
            pass
    raise SystemExit(
        "ComfyUI is not reachable on ports 8000 or 8188. "
        "Open ComfyUI Desktop, wait for startup to finish, and run again."
    )


def ensure_workflows() -> None:
    needed = [HERE / "workflow_sprite.json", HERE / "workflow_scene.json"]
    if all(path.exists() for path in needed):
        return

    print("Workflow JSON is missing; rebuilding it against live ComfyUI...")
    import build_workflows

    build_workflows.main()


def load_config() -> dict[str, Any]:
    if not ASSETS_PATH.exists():
        raise SystemExit(f"Missing {ASSETS_PATH}")
    data = yaml.safe_load(ASSETS_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("assets.yaml must contain a YAML mapping")
    if not isinstance(data.get("categories"), dict) or not isinstance(data.get("assets"), list):
        raise SystemExit("assets.yaml must contain 'categories' and 'assets'")
    return data


def load_manifest() -> list[dict[str, Any]]:
    if not MANIFEST_PATH.exists():
        return []
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"manifest.json is invalid JSON: {exc}") from exc
    if not isinstance(data, list):
        raise SystemExit("manifest.json must contain a JSON array")
    return data


def save_manifest(entries: list[dict[str, Any]]) -> None:
    MANIFEST_PATH.write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")


def next_version(manifest: list[dict[str, Any]], asset_name: str) -> int:
    versions = [
        int(item["version"])
        for item in manifest
        if item.get("asset") == asset_name and str(item.get("version", "")).isdigit()
    ]
    return max(versions, default=0) + 1


def load_workflow(kind: str) -> dict[str, Any]:
    path = HERE / f"workflow_{kind}.json"
    try:
        workflow = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"Missing workflow: {path}") from exc
    if not isinstance(workflow, dict):
        raise SystemExit(f"{path.name} must contain a JSON object")
    return workflow


def node_by_title(workflow: dict[str, Any], title: str) -> dict[str, Any]:
    for node in workflow.values():
        if isinstance(node, dict) and node.get("_meta", {}).get("title") == title:
            return node
    raise SystemExit(f"Workflow is missing node titled '{title}'")


def configure_workflow(
    template: dict[str, Any],
    *,
    positive: str,
    negative: str,
    width: int,
    height: int,
    seed: int,
    steps: int,
    filename_prefix: str,
) -> dict[str, Any]:
    workflow = copy.deepcopy(template)

    node_by_title(workflow, "Positive Prompt")["inputs"]["text"] = positive
    node_by_title(workflow, "Negative Prompt")["inputs"]["text"] = negative

    latent = node_by_title(workflow, "Latent")["inputs"]
    latent["width"] = int(width)
    latent["height"] = int(height)
    latent["batch_size"] = 1

    sampler = node_by_title(workflow, "Sampler")["inputs"]
    sampler["seed"] = int(seed)
    sampler["steps"] = int(steps)
    sampler["cfg"] = 6.5
    sampler["sampler_name"] = "dpmpp_2m"
    sampler["scheduler"] = "karras"
    sampler["denoise"] = 1.0

    node_by_title(workflow, "Save Image")["inputs"]["filename_prefix"] = filename_prefix
    return workflow


def queue_prompt(base_url: str, workflow: dict[str, Any]) -> str:
    payload = {"prompt": workflow, "client_id": str(uuid.uuid4())}
    response = requests.post(f"{base_url}/prompt", json=payload, timeout=HTTP_TIMEOUT)
    if not response.ok:
        raise RuntimeError(f"ComfyUI rejected prompt ({response.status_code}): {response.text}")
    data = response.json()
    prompt_id = data.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"ComfyUI did not return a prompt_id: {data}")
    return str(prompt_id)


def wait_for_history(base_url: str, prompt_id: str) -> dict[str, Any]:
    deadline = time.monotonic() + JOB_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        history = get_json(base_url, f"/history/{prompt_id}")
        if isinstance(history, dict) and prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {}) if isinstance(entry, dict) else {}
            if status.get("status_str") == "error":
                raise RuntimeError(f"ComfyUI job failed: {status}")
            if isinstance(entry, dict) and entry.get("outputs"):
                return entry
            if status.get("completed") is True:
                return entry
        time.sleep(POLL_SECONDS)
    raise TimeoutError(f"ComfyUI job {prompt_id} did not finish within {JOB_TIMEOUT_SECONDS} seconds")


def find_saved_image(history_entry: dict[str, Any]) -> dict[str, Any]:
    outputs = history_entry.get("outputs", {})
    if not isinstance(outputs, dict):
        raise RuntimeError("ComfyUI history did not contain outputs")

    images: list[dict[str, Any]] = []
    for output in outputs.values():
        if not isinstance(output, dict):
            continue
        value = output.get("images")
        if isinstance(value, list):
            images.extend(item for item in value if isinstance(item, dict))

    if not images:
        raise RuntimeError(f"ComfyUI completed but returned no saved images: {outputs}")
    return images[-1]


def download_image(base_url: str, image_info: dict[str, Any], destination: Path) -> None:
    params = {
        "filename": image_info["filename"],
        "subfolder": image_info.get("subfolder", ""),
        "type": image_info.get("type", "output"),
    }
    response = requests.get(f"{base_url}/view", params=params, timeout=60)
    response.raise_for_status()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(response.content)


def postprocess_sprite(source: Path, destination: Path, long_side: int) -> None:
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        bbox = alpha.getbbox()
        if bbox:
            rgba = rgba.crop(bbox)

        width, height = rgba.size
        if width <= 0 or height <= 0:
            raise RuntimeError(f"Generated image has invalid dimensions: {rgba.size}")

        scale = float(long_side) / max(width, height)
        target_size = (
            max(1, round(width * scale)),
            max(1, round(height * scale)),
        )
        processed = rgba.resize(target_size, Image.Resampling.LANCZOS)
        destination.parent.mkdir(parents=True, exist_ok=True)
        processed.save(destination, format="PNG")


def postprocess_scene(source: Path, destination: Path, width: int, height: int) -> None:
    with Image.open(source) as image:
        processed = image.convert("RGBA").resize((int(width), int(height)), Image.Resampling.LANCZOS)
        destination.parent.mkdir(parents=True, exist_ok=True)
        processed.save(destination, format="PNG")


def select_assets(
    config: dict[str, Any],
    *,
    only: str | None,
    category: str | None,
) -> list[dict[str, Any]]:
    assets = config["assets"]
    selected = [
        item
        for item in assets
        if isinstance(item, dict)
        and (only is None or item.get("name") == only)
        and (category is None or item.get("category") == category)
    ]
    if not selected:
        filters = []
        if only:
            filters.append(f"asset={only!r}")
        if category:
            filters.append(f"category={category!r}")
        raise SystemExit("No assets matched " + ", ".join(filters or ["the requested filters"]))
    return selected


def generate_one(
    *,
    base_url: str,
    config: dict[str, Any],
    asset: dict[str, Any],
    version: int,
    seed: int,
    dry_run: bool,
    positive_override: str | None = None,
    negative_override: str | None = None,
    job_id: str | None = None,
) -> dict[str, Any] | None:
    name = str(asset["name"])
    category_name = str(asset["category"])
    category = config["categories"].get(category_name)
    if not isinstance(category, dict):
        raise SystemExit(f"Asset {name} references unknown category {category_name}")

    workflow_kind = str(category["workflow"])
    source_size = asset.get("size", category["size"])
    width, height = [int(value) for value in source_size]
    steps = int(asset.get("steps", 30 if workflow_kind == "scene" else 28))
    positive = positive_override or f"{category['style']}, {asset['prompt']}"
    base_negative = str(category["negative"])
    negative_remove = str(asset.get("negative_remove", "")).strip()
    if negative_remove:
        parts = [part.strip() for part in base_negative.split(",") if part.strip()]
        parts = [part for part in parts if part.lower() != negative_remove.lower()]
        base_negative = ", ".join(parts)
    negative_extra = str(asset.get("negative_extra", "")).strip()
    if negative_extra:
        base_negative = f"{base_negative}, {negative_extra}"
    negative = negative_override or base_negative
    version_label = f"v{version:02d}"
    filename_prefix = f"deadshift/{category_name}/{name}_{version_label}_{seed}"

    print(f"{name} {version_label}: seed={seed} {width}x{height} {workflow_kind}")

    if dry_run:
        print(f"  positive: {positive}")
        print(f"  negative: {negative}")
        return None

    template = load_workflow(workflow_kind)
    workflow = configure_workflow(
        template,
        positive=positive,
        negative=negative,
        width=width,
        height=height,
        seed=seed,
        steps=steps,
        filename_prefix=filename_prefix,
    )

    prompt_id = queue_prompt(base_url, workflow)
    print(f"  queued: {prompt_id}")
    history_entry = wait_for_history(base_url, prompt_id)
    saved = find_saved_image(history_entry)

    raw_path = RAW_DIR / category_name / f"{name}_{version_label}_{seed}.png"
    candidate_path = CANDIDATE_DIR / category_name / f"{name}_{version_label}.png"
    download_image(base_url, saved, raw_path)

    target = asset.get("target", category["target"])
    if "width" in target and "height" in target:
        postprocess_scene(raw_path, candidate_path, int(target["width"]), int(target["height"]))
    elif workflow_kind == "sprite":
        postprocess_sprite(raw_path, candidate_path, int(target["long_side"]))
    else:
        raise SystemExit(f"Asset {name} requires target width/height or category long_side")

    print(f"  candidate: {candidate_path.relative_to(HERE)}")
    return {
        "asset": name,
        "category": category_name,
        "job_id": job_id,
        "version": version,
        "version_label": version_label,
        "seed": seed,
        "prompt": positive,
        "negative": negative,
        "settings": {
            "checkpoint": "sd_xl_base_1.0.safetensors",
            "workflow": workflow_kind,
            "source_size": [width, height],
            "steps": steps,
            "cfg": 6.5,
            "sampler": "dpmpp_2m",
            "scheduler": "karras",
            "denoise": 1.0,
            "batch_size": 1,
            "rmbg_model": "RMBG-2.0" if workflow_kind == "sprite" else None,
            "rmbg_background": "Alpha" if workflow_kind == "sprite" else None,
            "target": target,
        },
        "prompt_id": prompt_id,
        "raw_path": raw_path.relative_to(HERE).as_posix(),
        "candidate_path": candidate_path.relative_to(HERE).as_posix(),
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate DeadShift assets with local ComfyUI")
    parser.add_argument("--only", help="Generate one named asset")
    parser.add_argument("--category", help="Generate only one category")
    parser.add_argument("--count", type=int, help="Override the configured count per asset")
    parser.add_argument("--positive", help="Replace the full positive prompt")
    parser.add_argument("--negative", help="Replace the full negative prompt")
    parser.add_argument("--job-id", help="Tag manifest entries with a worker job id")
    parser.add_argument("--job-file", type=Path, help="Load asset/count/prompt overrides from a YAML job file")
    parser.add_argument("--dry-run", action="store_true", help="Print jobs without queueing them")
    return parser.parse_args()


def apply_job_file(args: argparse.Namespace) -> argparse.Namespace:
    if args.job_file is None:
        return args
    try:
        job = yaml.safe_load(args.job_file.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"Job file not found: {args.job_file}") from exc
    if not isinstance(job, dict):
        raise SystemExit("Job file must contain a YAML mapping")

    args.only = job.get("asset", args.only)
    args.category = job.get("category", args.category)
    args.count = int(job.get("count", args.count or 20))
    args.positive = job.get("positive", args.positive)
    args.negative = job.get("negative", args.negative)
    args.job_id = str(job.get("job_id") or args.job_file.stem)
    return args


def main() -> None:
    args = apply_job_file(parse_args())
    if args.count is not None and args.count < 1:
        raise SystemExit("--count must be at least 1")

    base_url = detect_server()
    ensure_workflows()
    config = load_config()
    selected = select_assets(config, only=args.only, category=args.category)
    manifest = load_manifest()

    print(f"ComfyUI: {base_url}")
    print(f"Assets selected: {len(selected)}")

    for asset in selected:
        category = config["categories"][asset["category"]]
        count = args.count if args.count is not None else int(category["count"])
        version = next_version(manifest, str(asset["name"]))

        for offset in range(count):
            seed = secrets.randbits(63)
            entry = generate_one(
                base_url=base_url,
                config=config,
                asset=asset,
                version=version + offset,
                seed=seed,
                dry_run=args.dry_run,
                positive_override=args.positive,
                negative_override=args.negative,
                job_id=args.job_id,
            )
            if entry is not None:
                manifest.append(entry)
                save_manifest(manifest)

    if args.dry_run:
        print("Dry run complete; nothing was queued or written to manifest.json.")
    else:
        print(f"Generation complete. Manifest entries: {len(manifest)}")


if __name__ == "__main__":
    main()
