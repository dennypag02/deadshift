"""Transfer explicitly submitted PNGs into immutable GitHub staging.

Does not change approved Godot art or promote candidates to game slots.
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
from pathlib import Path

import project_library

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
SUBMISSIONS = HERE / "submitted_curations"
TARGET = HERE / "submitted_artwork"
ID = re.compile(r"^curation-[a-f0-9]{24}$")
PNG_HEADER = b"\x89PNG\r\n\x1a\n"


def stage_submissions() -> list[str]:
    paths = []
    for record in sorted(SUBMISSIONS.glob("curation-*.json")):
        if not ID.fullmatch(record.stem):
            continue
        payload = json.loads(record.read_text(encoding="utf-8"))
        if payload.get("submission_id") != record.stem or payload.get("status") != "curated_not_promoted":
            raise ValueError("Invalid submission record")
        candidates = payload.get("candidates")
        if not isinstance(candidates, list):
            raise ValueError("Invalid candidate list")
        for item in candidates:
            cid = str(item.get("candidate_id", ""))
            if not re.fullmatch(r"[a-zA-Z0-9_-]{8,128}", cid):
                raise ValueError("Invalid candidate ID")
            relative = str(item.get("candidate_path", ""))
            source = (HERE / relative).resolve()
            if project_library.CANDIDATES.resolve() not in source.parents or source.suffix.lower() != ".png":
                raise ValueError("Invalid candidate source path")
            if not source.is_file():
                raise FileNotFoundError("Missing locally selected artwork: " + relative)
            data = source.read_bytes()
            if len(data) < 24 or not data.startswith(PNG_HEADER):
                raise ValueError("Invalid PNG header: " + relative)
            width = int.from_bytes(data[16:20], "big")
            height = int.from_bytes(data[20:24], "big")
            if width < 1 or height < 1 or width > 8192 or height > 8192:
                raise ValueError("Invalid PNG dimensions: " + relative)
            dest = TARGET / record.stem / (cid + ".png")
            if dest.exists() and dest.read_bytes() != data:
                raise ValueError("Immutable candidate collision: " + cid)
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists():
                dest.write_bytes(data)
            paths.append(dest.relative_to(REPO).as_posix())
    return sorted(set(paths))


def publish(run, branch: str) -> dict:
    paths = stage_submissions()
    if not paths:
        return {"staged": 0}
    for args in (["git", "add", "--", *paths],
                 ["git", "status", "--porcelain", "--", *paths]):
        result = run(args, cwd=REPO)
        if result.returncode:
            raise RuntimeError("Git staging failed: " + (result.stderr or result.stdout))
        if args[1] == "status" and result.stdout.strip():
            commit = run(["git", "commit", "-m", "Transfer selected artwork to immutable staging", "--", *paths], cwd=REPO)
            if commit.returncode:
                raise RuntimeError("Git commit failed: " + (commit.stderr or commit.stdout))
    pushed = run(["git", "push", "origin", branch], cwd=REPO)
    if pushed.returncode:
        raise RuntimeError("Git push failed: " + (pushed.stderr or pushed.stdout))
    return {"staged": len(paths)}
