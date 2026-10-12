#!/usr/bin/env python3
"""Interactive DeadShift asset generation/review loop.

Runs the existing generator and contact-sheet builder repeatedly so the user
does not need to copy/paste PowerShell commands.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import webbrowser
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
MANIFEST_PATH = HERE / "manifest.json"
PICKS_PATH = HERE / "picks.yaml"
REVIEW_DIR = HERE / "staging" / "review"


def run_python(script: str, *args: str) -> None:
    command = [sys.executable, str(HERE / script), *args]
    print("\n> " + " ".join(command))
    subprocess.run(command, cwd=HERE, check=True)


def load_manifest() -> list[dict]:
    if not MANIFEST_PATH.exists():
        return []
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("manifest.json must contain a JSON array")
    return data


def versions_for(asset_name: str) -> list[str]:
    versions: list[tuple[int, str]] = []
    for item in load_manifest():
        if item.get("asset") != asset_name:
            continue
        number = item.get("version")
        label = item.get("version_label")
        if isinstance(number, int) and isinstance(label, str):
            versions.append((number, label))
    versions.sort()
    return [label for _, label in versions]


def save_pick(asset_name: str, version_label: str) -> None:
    picks = {}
    if PICKS_PATH.exists():
        loaded = yaml.safe_load(PICKS_PATH.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            picks.update(loaded)
    picks[asset_name] = version_label
    PICKS_PATH.write_text(yaml.safe_dump(picks, sort_keys=True), encoding="utf-8")


def open_review(category: str) -> Path:
    page = REVIEW_DIR / f"{category}.html"
    if not page.exists():
        raise SystemExit(f"Review page not found: {page}")
    webbrowser.open(page.resolve().as_uri())
    return page


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="DeadShift guided asset review loop")
    parser.add_argument("--asset", default="car_suv", help="Asset name to iterate")
    parser.add_argument("--category", default="cars", help="Asset category")
    parser.add_argument("--count", type=int, default=2, help="Candidates per round")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.count < 1:
        raise SystemExit("--count must be at least 1")

    print("DeadShift Asset Review")
    print("======================")
    print(f"Asset: {args.asset}")
    print(f"Candidates per round: {args.count}")
    print("ComfyUI Desktop must remain open.")

    while True:
        before = set(versions_for(args.asset))

        run_python("generate.py", "--only", args.asset, "--count", str(args.count))
        run_python("review.py", "--category", args.category)

        after = versions_for(args.asset)
        newest = [version for version in after if version not in before]
        if not newest:
            print("No new candidate versions were found.")
            return

        page = open_review(args.category)
        print(f"\nReview page opened: {page}")
        print("New candidates this round: " + ", ".join(newest))

        while True:
            answer = input(
                "\nChoose a version to keep "
                f"({', '.join(newest)}), R = reject all/generate again, Q = quit: "
            ).strip()

            normalized = answer.lower()
            lookup = {version.lower(): version for version in newest}

            if normalized in lookup:
                chosen = lookup[normalized]
                save_pick(args.asset, chosen)
                print(f"\nSaved pick: {args.asset}: {chosen}")
                print("Nothing has been copied into Godot yet.")
                return

            if normalized in {"r", "reject"}:
                print("\nRejected this round. Generating the next pair...")
                break

            if normalized in {"q", "quit"}:
                print("\nStopped. No candidate was selected.")
                return

            print("Please enter one of the shown version labels, R, or Q.")


if __name__ == "__main__":
    main()
