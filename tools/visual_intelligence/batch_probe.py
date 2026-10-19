#!/usr/bin/env python3
"""Run repeatable diagnostic inference on a bounded directory of real PNGs.

No labels are inferred, no accuracy claims made, and no code is modified.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--images", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--max-images", type=int, default=12)
    args = p.parse_args()
    if not 1 <= args.max_images <= 50:
        raise SystemExit("max-images must be between 1 and 50")
    images = sorted(args.images.glob("*.png")) if args.images.is_dir() else [args.images]
    if not images or not all(path.is_file() for path in images):
        raise SystemExit("No real PNG screenshot files found")
    images = images[:args.max_images]
    digests = [hashlib.sha256(path.read_bytes()).hexdigest() for path in images]
    if len(set(digests)) != len(digests):
        raise SystemExit("Duplicate screenshot content detected; refusing inflated sample count")
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    failed = 0
    for i, path in enumerate(images):
        digest = digests[i]
        report = args.output / f"image-{i:03d}-{digest[:12]}.json"
        cmd = [sys.executable, str(Path(__file__).with_name("ollama_probe.py")),
               "--image", str(path), "--output", str(report)]
        try:
            completed = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            ok = completed.returncode == 0 and report.is_file()
            error = (completed.stderr or completed.stdout)[-1000:] if not ok else None
        except subprocess.TimeoutExpired:
            ok, error = False, "Inference timed out after 300 seconds"
        results.append({"image": path.name, "sha256": digest, "success": ok,
                        "report": report.name if ok else None, "error": error})
        print(f"{path.name}: {'PASS' if ok else 'FAIL'}", flush=True)
        failed += not ok
    summary = {"qualification": "REVIEW_UNQUALIFIED",
               "source_commit": os.environ.get("GITHUB_SHA"),
               "processed": len(results), "passed": len(results) - failed,
               "failed": failed, "cases": results}
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({"processed": len(results), "passed": len(results)-failed, "failed": failed}))
    if failed:
        raise SystemExit("Diagnostic batch incomplete")


if __name__ == "__main__":
    main()
