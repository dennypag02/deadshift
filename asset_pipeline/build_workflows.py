#!/usr/bin/env python3
"""Build DeadShift ComfyUI API workflows from the live /object_info schema."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import requests

HOST = "127.0.0.1"
PORTS = (8000, 8188)
CHECKPOINT = "sd_xl_base_1.0.safetensors"
OUT_DIR = Path(__file__).resolve().parent

REQUIRED_INPUTS = {
    "CheckpointLoaderSimple": {"ckpt_name"},
    "CLIPTextEncode": {"text", "clip"},
    "EmptyLatentImage": {"width", "height", "batch_size"},
    "KSampler": {
        "model", "seed", "steps", "cfg", "sampler_name", "scheduler",
        "positive", "negative", "latent_image", "denoise",
    },
    "VAEDecode": {"samples", "vae"},
    "SaveImage": {"images", "filename_prefix"},
    "RMBG": {"image", "model"},
}


def get_json(base_url: str, path: str) -> Any:
    response = requests.get(f"{base_url}{path}", timeout=5)
    response.raise_for_status()
    return response.json()


def detect_server() -> str:
    for port in PORTS:
        base = f"http://{HOST}:{port}"
        try:
            stats = get_json(base, "/system_stats")
            if isinstance(stats, dict):
                return base
        except (requests.RequestException, ValueError):
            pass
    raise SystemExit("ComfyUI is not reachable. Open ComfyUI Desktop and run this command again.")


def required_keys(info: dict[str, Any]) -> set[str]:
    required = info.get("input", {}).get("required", {})
    return set(required) if isinstance(required, dict) else set()


def validate_schema(object_info: dict[str, Any]) -> None:
    failures: list[str] = []
    for class_name, expected in REQUIRED_INPUTS.items():
        info = object_info.get(class_name)
        if not isinstance(info, dict):
            failures.append(f"missing node class: {class_name}")
            continue
        actual = required_keys(info)
        missing = expected - actual
        if missing:
            failures.append(f"{class_name} missing required inputs: {sorted(missing)}")

    loader = object_info.get("CheckpointLoaderSimple", {})
    ckpt_spec = loader.get("input", {}).get("required", {}).get("ckpt_name", [])
    choices = ckpt_spec[0] if isinstance(ckpt_spec, list) and ckpt_spec else []
    if CHECKPOINT not in choices:
        failures.append(f"checkpoint not advertised by CheckpointLoaderSimple: {CHECKPOINT}")

    rmbg = object_info.get("RMBG", {})
    rmbg_inputs = rmbg.get("input", {})
    model_spec = rmbg_inputs.get("required", {}).get("model", [])
    model_choices = model_spec[0] if isinstance(model_spec, list) and model_spec else []
    if "RMBG-2.0" not in model_choices:
        failures.append("RMBG node does not advertise model RMBG-2.0")

    background_spec = rmbg_inputs.get("optional", {}).get("background", [])
    background_choices = background_spec[0] if isinstance(background_spec, list) and background_spec else []
    if "Alpha" not in background_choices:
        failures.append("RMBG node does not advertise background=Alpha")

    if failures:
        print("Workflow build stopped because the live ComfyUI schema did not match expectations:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        raise SystemExit(2)


def base_workflow() -> dict[str, Any]:
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "_meta": {"title": "Checkpoint"},
            "inputs": {"ckpt_name": CHECKPOINT},
        },
        "2": {
            "class_type": "CLIPTextEncode",
            "_meta": {"title": "Positive Prompt"},
            "inputs": {"text": "__POSITIVE_PROMPT__", "clip": ["1", 1]},
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "_meta": {"title": "Negative Prompt"},
            "inputs": {"text": "__NEGATIVE_PROMPT__", "clip": ["1", 1]},
        },
        "4": {
            "class_type": "EmptyLatentImage",
            "_meta": {"title": "Latent"},
            "inputs": {"width": 1024, "height": 1024, "batch_size": 1},
        },
        "5": {
            "class_type": "KSampler",
            "_meta": {"title": "Sampler"},
            "inputs": {
                "model": ["1", 0],
                "seed": 1,
                "steps": 28,
                "cfg": 6.5,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0],
                "denoise": 1.0,
            },
        },
        "6": {
            "class_type": "VAEDecode",
            "_meta": {"title": "Decode"},
            "inputs": {"samples": ["5", 0], "vae": ["1", 2]},
        },
    }


def scene_workflow() -> dict[str, Any]:
    workflow = base_workflow()
    workflow["7"] = {
        "class_type": "SaveImage",
        "_meta": {"title": "Save Image"},
        "inputs": {"images": ["6", 0], "filename_prefix": "__FILENAME_PREFIX__"},
    }
    return workflow


def sprite_workflow() -> dict[str, Any]:
    workflow = base_workflow()
    workflow["7"] = {
        "class_type": "RMBG",
        "_meta": {"title": "Remove Background (RMBG)"},
        "inputs": {
            "image": ["6", 0],
            "model": "RMBG-2.0",
            "sensitivity": 1.0,
            "process_res": 1024,
            "mask_blur": 0,
            "mask_offset": 0,
            "invert_output": False,
            "refine_foreground": False,
            "background": "Alpha",
            "background_color": "#222222",
        },
    }
    workflow["8"] = {
        "class_type": "SaveImage",
        "_meta": {"title": "Save Image"},
        "inputs": {"images": ["7", 0], "filename_prefix": "__FILENAME_PREFIX__"},
    }
    return workflow


def write_json(name: str, workflow: dict[str, Any]) -> None:
    path = OUT_DIR / name
    path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {path}")


def main() -> None:
    base_url = detect_server()
    object_info = get_json(base_url, "/object_info")
    if not isinstance(object_info, dict):
        raise SystemExit("/object_info did not return a JSON object")
    validate_schema(object_info)
    write_json("workflow_sprite.json", sprite_workflow())
    write_json("workflow_scene.json", scene_workflow())
    print(f"Validated against live ComfyUI at {base_url}")
    print("Sprite workflow: SDXL -> KSampler -> VAE Decode -> RMBG-2.0 Alpha -> SaveImage")
    print("Scene workflow:  SDXL -> KSampler -> VAE Decode -> SaveImage")


if __name__ == "__main__":
    main()
