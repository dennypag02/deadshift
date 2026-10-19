#!/usr/bin/env python3
"""Local Ollama benchmark probe: real images, structured findings, and provenance.

This is a diagnostic run, NOT a qualified model evaluation. The image source
must be a real PNG captured from the game; do not substitute an invented image.
"""
import argparse
import base64
import hashlib
import json
import os
import time
from pathlib import Path
from urllib.request import Request, urlopen


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--image", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--model", default="qwen2.5vl:3b")
    p.add_argument("--endpoint", default="http://127.0.0.1:11434")
    args = p.parse_args()
    if not args.image.is_file():
        raise SystemExit("Screenshot path does not exist")
    raw = args.image.read_bytes()
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit("Expected a real PNG screenshot")
    prompt = (
        "Inspect this DeadShift game screenshot. Return concise JSON with a "
        "findings array. Each finding has defect_id, location, visible_evidence, "
        "confidence (low/medium/high). Focus on XP bar text obstruction, HUD "
        "overlap, tiny arsenal icons, and minimap occlusion. Report only what "
        "is actually visible. An empty findings array is valid."
    )
    body = json.dumps({"model": args.model, "stream": False, "prompt": prompt,
                       "format": "json", "images": [base64.b64encode(raw).decode("ascii")]})
    request = Request(args.endpoint.rstrip("/") + "/api/generate",
                      data=body.encode("utf-8"),
                      headers={"Content-Type": "application/json"})
    start = time.monotonic()
    with urlopen(request, timeout=240) as response:
        result = json.load(response)
    elapsed = round(time.monotonic() - start, 3)
    try:
        prediction = json.loads(result["response"])
    except (ValueError, KeyError) as exc:
        raise SystemExit(f"Unparseable Ollama JSON: {exc}")
    if not isinstance(prediction, dict) or not isinstance(prediction.get("findings"), list):
        raise SystemExit("Ollama response missing findings array")
    report = {
        "qualification": "REVIEW_UNQUALIFIED",
        "purpose": "unscored diagnostic inference",
        "image_sha256": hashlib.sha256(raw).hexdigest(),
        "image_name": args.image.name,
        "model": args.model,
        "source_commit": os.environ.get("GITHUB_SHA"),
        "elapsed_seconds": elapsed,
        "model_total_duration_ns": result.get("total_duration"),
        "prediction": prediction,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k != "prediction"}, indent=2))
    print(f"Findings: {len(prediction['findings'])}; diagnostic only")


if __name__ == "__main__":
    main()
