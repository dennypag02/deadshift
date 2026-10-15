"""Publish local curated-selection snapshots to the configured GitHub branch.

Only submission JSON is published. Candidate PNGs remain local until a separate,
explicit promotion approval. Successful git push is the completion boundary.
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import project_library

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
DEST = HERE / "submitted_curations"
ID = re.compile(r"^curation-[0-9a-f]{24}$")


def publish(run, branch: str) -> dict:
    source = project_library.SUBMISSIONS
    if not source.exists():
        return {"published": 0, "pending": 0}
    records = sorted(source.glob("curation-*.json"))
    pending = []
    for file in records:
        if not ID.fullmatch(file.stem):
            continue
        payload = json.loads(file.read_text(encoding="utf-8"))
        if payload.get("submission_id") != file.stem or payload.get("status") != "curated_not_promoted":
            raise ValueError("Invalid curated submission: " + file.name)
        target = DEST / file.name
        if target.exists():
            if target.read_bytes() != file.read_bytes():
                raise ValueError("Published submission ID collision: " + file.name)
            continue
        pending.append((file, target))
    if not pending:
        return {"published": 0, "pending": 0}
    DEST.mkdir(parents=True, exist_ok=True)
    for file, target in pending:
        target.write_bytes(file.read_bytes())
    paths = [target.relative_to(REPO).as_posix() for _, target in pending]
    added = run(["git", "add", "--", *paths], cwd=REPO)
    if added.returncode:
        raise RuntimeError("Git add failed: " + (added.stderr or added.stdout))
    status = run(["git", "status", "--porcelain", "--", *paths], cwd=REPO)
    if status.returncode:
        raise RuntimeError("Git status failed: " + (status.stderr or status.stdout))
    if status.stdout.strip():
        commit = run(["git", "commit", "-m", "Publish curated asset selections", "--", *paths], cwd=REPO)
        if commit.returncode:
            raise RuntimeError("Git commit failed: " + (commit.stderr or commit.stdout))
    push = run(["git", "push", "origin", branch], cwd=REPO)
    if push.returncode:
        raise RuntimeError("Git push failed; local submissions will be retried: " + (push.stderr or push.stdout))
    return {"published": len(pending), "pending": 0}
