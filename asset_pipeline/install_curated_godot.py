"""Materialize curated image files from an immutable selection manifest into Godot.

Run in CI after checking out asset_pipeline/submitted_artwork from the source branch.
No resize or overwrite of existing art.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "asset_pipeline" / "submitted_artwork"
MANIFEST = ROOT / "asset_pipeline" / "submitted_curations" / "curation-1821f5654302f816c1f7881b.json"
DEST = ROOT / "godot" / "art" / "curated"


def main():
    record = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if record["status"] != "curated_not_promoted" or len(record["candidates"]) != 45:
        raise ValueError("Expected exact reviewed selection of 45 candidates")
    submission = record["submission_id"]
    copied = 0
    for candidate in record["candidates"]:
        asset = candidate["asset"]
        cid = candidate["candidate_id"]
        if not asset.replace("_", "").isalnum() or not cid.replace("-", "").isalnum():
            raise ValueError("Invalid candidate mapping")
        source = SOURCE / submission / (cid + ".png")
        target = DEST / (asset + ".png")
        if not source.is_file() or source.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Missing or invalid selected PNG: " + asset)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() != source.read_bytes():
            raise ValueError("Refusing overwrite of approved art: " + str(target))
        shutil.copyfile(source, target)
        copied += 1
    print(f"Prepared {copied} reviewed PNGs for Godot import; no image resizing")


if __name__ == "__main__":
    main()
