#!/usr/bin/env python3
"""Build HTML contact sheets for DeadShift asset candidates."""

from __future__ import annotations

import argparse
import base64
import html
import json
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
MANIFEST_PATH = HERE / "manifest.json"
CANDIDATE_DIR = HERE / "staging" / "candidates"
REVIEW_DIR = HERE / "staging" / "review"


def load_manifest() -> list[dict[str, Any]]:
    if not MANIFEST_PATH.exists():
        raise SystemExit("manifest.json does not exist yet. Generate candidates first.")
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"manifest.json is invalid JSON: {exc}") from exc
    if not isinstance(data, list):
        raise SystemExit("manifest.json must contain a JSON array")
    return data


def build_sheet(category: str, entries: list[dict[str, Any]], output_name: str | None = None) -> Path:
    REVIEW_DIR.mkdir(parents=True, exist_ok=True)
    cards: list[str] = []

    for item in entries:
        candidate = HERE / str(item["candidate_path"])
        if not candidate.exists():
            continue

        encoded = base64.b64encode(candidate.read_bytes()).decode("ascii")
        image_src = f"data:image/png;base64,{encoded}"
        asset = html.escape(str(item.get("asset", "")))
        version = html.escape(str(item.get("version_label", "")))
        seed = html.escape(str(item.get("seed", "")))
        filename = html.escape(candidate.name)

        cards.append(
            f"""
            <article class="card">
              <div class="preview">
                <img src="{image_src}" alt="{filename}">
              </div>
              <div class="meta">
                <div><strong>{asset} {version}</strong></div>
                <div>{filename}</div>
                <div>seed: {seed}</div>
              </div>
            </article>
            """
        )

    if not cards:
        raise SystemExit(f"No candidate files found for category '{category}'")

    document = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>DeadShift review - {html.escape(category)}</title>
<style>
  body {{
    margin: 0;
    padding: 24px;
    background: #202020;
    color: #f0f0f0;
    font-family: Arial, Helvetica, sans-serif;
  }}
  h1 {{
    margin-top: 0;
    font-size: 28px;
  }}
  .grid {{
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: 20px;
  }}
  .card {{
    background: #2a2a2a;
    border: 1px solid #444;
    border-radius: 10px;
    overflow: hidden;
  }}
  .preview {{
    min-height: 320px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #3a3a3a;
    padding: 20px;
  }}
  .preview img {{
    max-width: 100%;
    max-height: 420px;
    image-rendering: auto;
  }}
  .meta {{
    padding: 14px 16px 16px;
    line-height: 1.5;
    word-break: break-word;
  }}
</style>
</head>
<body>
<h1>DeadShift candidates: {html.escape(category)}</h1>
<div class="grid">
{''.join(cards)}
</div>
</body>
</html>
"""

    safe_name = output_name or category
    path = REVIEW_DIR / f"{safe_name}.html"
    path.write_text(document, encoding="utf-8")
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build DeadShift candidate review pages")
    parser.add_argument("--category", help="Build only one category")
    parser.add_argument("--asset", help="Build only one asset")
    parser.add_argument("--job-id", help="Build only one worker job batch")
    parser.add_argument("--latest", type=int, help="Keep only the latest N matching entries")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = load_manifest()

    filtered = [
        item
        for item in manifest
        if item.get("category")
        and (args.category is None or item.get("category") == args.category)
        and (args.asset is None or item.get("asset") == args.asset)
        and (args.job_id is None or item.get("job_id") == args.job_id)
    ]
    if args.latest is not None:
        if args.latest < 1:
            raise SystemExit("--latest must be at least 1")
        filtered = filtered[-args.latest:]

    if not filtered:
        raise SystemExit("No manifest entries matched the requested filters")

    categories = sorted({str(item.get("category")) for item in filtered})
    for category in categories:
        entries = [item for item in filtered if item.get("category") == category]
        output_name = args.job_id or args.asset or category
        path = build_sheet(category, entries, output_name=output_name)
        print(f"Wrote {path}")

    print("Review pages complete.")


if __name__ == "__main__":
    main()
