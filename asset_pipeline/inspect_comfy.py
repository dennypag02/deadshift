#!/usr/bin/env python3
"""DeadShift ComfyUI Step-1 inspector.

Detects a local ComfyUI Desktop/standard server, confirms the configured SDXL
checkpoint is advertised, and reports candidate background-removal nodes from
/object_info without guessing class or input names.
"""

from __future__ import annotations

import json
import sys
from typing import Any

import requests

PORTS = (8000, 8188)
HOST = "127.0.0.1"
CHECKPOINT = "sd_xl_base_1.0.safetensors"
TIMEOUT = 3


def get_json(base_url: str, path: str) -> Any:
    response = requests.get(f"{base_url}{path}", timeout=TIMEOUT)
    response.raise_for_status()
    return response.json()


def detect_server() -> tuple[str, dict[str, Any]]:
    errors: list[str] = []
    for port in PORTS:
        base_url = f"http://{HOST}:{port}"
        try:
            stats = get_json(base_url, "/system_stats")
            if isinstance(stats, dict):
                return base_url, stats
            errors.append(f"{base_url}: /system_stats returned non-object JSON")
        except requests.RequestException as exc:
            errors.append(f"{base_url}: {exc.__class__.__name__}: {exc}")
        except ValueError as exc:
            errors.append(f"{base_url}: invalid JSON: {exc}")

    print("ERROR: ComfyUI is not reachable on ports 8000 or 8188.", file=sys.stderr)
    print("Open ComfyUI Desktop and wait until it finishes starting, then run this again.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    raise SystemExit(2)


def find_checkpoint_nodes(object_info: dict[str, Any]) -> list[dict[str, Any]]:
    matches: list[dict[str, Any]] = []
    for class_name, info in object_info.items():
        if not isinstance(info, dict):
            continue
        required = info.get("input", {}).get("required", {})
        if not isinstance(required, dict):
            continue
        for input_name, spec in required.items():
            values = spec[0] if isinstance(spec, list) and spec else None
            if isinstance(values, list) and CHECKPOINT in values:
                matches.append({
                    "class_name": class_name,
                    "display_name": info.get("display_name"),
                    "checkpoint_input": input_name,
                    "advertises_checkpoint": CHECKPOINT,
                })
    return matches


def find_rmbg_candidates(object_info: dict[str, Any]) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for class_name, info in object_info.items():
        if not isinstance(info, dict):
            continue
        display_name = str(info.get("display_name") or "")
        category = str(info.get("category") or "")
        haystack = " ".join((class_name, display_name, category)).lower()
        if any(token in haystack for token in ("rmbg", "remove background", "background removal")):
            candidates.append({
                "class_name": class_name,
                "display_name": info.get("display_name"),
                "category": info.get("category"),
                "input": info.get("input", {}),
                "output": info.get("output"),
                "output_name": info.get("output_name"),
            })
    return candidates


def main() -> None:
    base_url, system_stats = detect_server()
    try:
        object_info = get_json(base_url, "/object_info")
    except (requests.RequestException, ValueError) as exc:
        print(f"ERROR: Connected to {base_url}, but /object_info failed: {exc}", file=sys.stderr)
        raise SystemExit(3)

    if not isinstance(object_info, dict):
        print("ERROR: /object_info returned unexpected JSON.", file=sys.stderr)
        raise SystemExit(4)

    report = {
        "status": "ok",
        "base_url": base_url,
        "checkpoint_expected": CHECKPOINT,
        "checkpoint_nodes": find_checkpoint_nodes(object_info),
        "rmbg_candidates": find_rmbg_candidates(object_info),
        "system_stats": system_stats,
    }

    if not report["checkpoint_nodes"]:
        report["status"] = "missing_checkpoint"
    if not report["rmbg_candidates"]:
        report["status"] = (
            "missing_checkpoint_and_rmbg" if report["status"] == "missing_checkpoint" else "missing_rmbg"
        )

    print(json.dumps(report, indent=2, sort_keys=True))

    if report["status"] != "ok":
        raise SystemExit(5)


if __name__ == "__main__":
    main()
