"""Non-destructive project/scope asset curation for the local worker.

Legacy candidates remain at their original paths. Bulk submission records kept
candidate IDs; it never copies files to Godot or promotes anything.
"""
from __future__ import annotations

import hashlib
import html
import json
import os
import re
import secrets
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

HERE = Path(__file__).resolve().parent
PROJECTS = HERE / "projects"
MANIFEST = HERE / "manifest.json"
STATE = HERE / "curation_state.json"
SUBMISSIONS = HERE / "curation_submissions"
CANDIDATES = HERE / "staging" / "candidates"
SLUG = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
DEFAULT_PROJECT = "deadshift"


def slug(value: str) -> str:
    if not SLUG.fullmatch(value):
        raise ValueError("Invalid project, scope or asset identifier")
    return value


def scope_key(scope: str) -> str:
    if scope == "general":
        return scope
    parts = scope.split("/")
    if len(parts) == 2 and parts[0] == "levels":
        return "levels/" + slug(parts[1])
    raise ValueError("Invalid scope")


def read_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def atomic_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + "." + secrets.token_hex(6) + ".tmp")
    try:
        tmp.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def project_scopes() -> dict[str, list[str]]:
    projects = {}
    if PROJECTS.exists():
        for directory in sorted(PROJECTS.iterdir()):
            if not directory.is_dir() or not SLUG.fullmatch(directory.name):
                continue
            scopes = ["general"]
            level_root = directory / "levels"
            if level_root.exists():
                scopes += ["levels/" + p.name for p in sorted(level_root.iterdir())
                           if p.is_dir() and SLUG.fullmatch(p.name)]
            projects[directory.name] = scopes
    return projects


def legacy_project_scope(item: dict) -> tuple[str, str]:
    project = slug(str(item.get("project_id") or DEFAULT_PROJECT))
    scope = scope_key(str(item.get("scope_id") or "general"))
    return project, scope


def candidate_id(item: dict) -> str:
    existing = str(item.get("candidate_id") or "")
    if existing:
        if not re.fullmatch(r"[a-zA-Z0-9_-]{8,128}", existing):
            raise ValueError("Invalid candidate ID")
        return existing
    # Stable identity for legacy manifest entries, even if seed repeats.
    fields = [item.get(k) for k in ("asset", "category", "version", "seed", "candidate_path", "job_id")]
    return "legacy-" + hashlib.sha256(json.dumps(fields, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()[:24]


def catalog(project: str, scope: str) -> dict[str, list[dict]]:
    slug(project)
    scope_key(scope)
    items = read_json(MANIFEST, [])
    if not isinstance(items, list):
        raise ValueError("Invalid manifest")
    grouped: dict[str, list[dict]] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            owner, item_scope = legacy_project_scope(item)
            asset = slug(str(item.get("asset", "")))
            cid = candidate_id(item)
            relative = str(item.get("candidate_path", ""))
            path = (HERE / relative).resolve()
            if owner != project or item_scope != scope:
                continue
            if CANDIDATES.resolve() not in path.parents or path.suffix.lower() != ".png" or not path.is_file():
                continue
        except (ValueError, OSError):
            continue
        enriched = dict(item)
        enriched["candidate_id"] = cid
        grouped.setdefault(asset, []).append(enriched)
    for group in grouped.values():
        group.sort(key=lambda x: (int(x.get("version") or 0), x["candidate_id"]))
    return grouped


def state():
    value = read_json(STATE, {"folders": {}})
    if not isinstance(value, dict) or not isinstance(value.get("folders"), dict):
        raise ValueError("Invalid curation state")
    return value


def folder_id(project: str, scope: str) -> str:
    return slug(project) + ":" + scope_key(scope)


def save_selection(project: str, scope: str, ids: list[str]) -> dict:
    if scope not in project_scopes().get(project, []):
        raise ValueError("Unknown project folder")
    grouped = catalog(project, scope)
    available = {item["candidate_id"] for group in grouped.values() for item in group}
    requested = set(ids)
    if not requested.issubset(available):
        raise ValueError("Selection contains unknown or unavailable candidates")
    current = state()
    key = folder_id(project, scope)
    folder = current["folders"].setdefault(key, {})
    folder["kept_candidate_ids"] = sorted(requested)
    folder["updated_at"] = datetime.now(timezone.utc).isoformat()
    atomic_json(STATE, current)
    return {"kept": len(requested), "folder": key}


def submit_folder(project: str, scope: str, ids: list[str]) -> dict:
    # Submission is an immutable, reviewed snapshot of kept IDs, not game promotion.
    result = save_selection(project, scope, ids)
    grouped = catalog(project, scope)
    lookup = {item["candidate_id"]: item for group in grouped.values() for item in group}
    selected = [lookup[cid] for cid in sorted(set(ids))]
    record = {
        "submission_id": "curation-" + secrets.token_hex(12),
        "project_id": project, "scope_id": scope,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "status": "curated_not_promoted",
        "candidates": [{
            "candidate_id": item["candidate_id"], "asset": item["asset"],
            "candidate_path": item["candidate_path"], "seed": item.get("seed"),
            "job_id": item.get("job_id"), "version": item.get("version"),
        } for item in selected],
    }
    SUBMISSIONS.mkdir(parents=True, exist_ok=True)
    atomic_json(SUBMISSIONS / (record["submission_id"] + ".json"), record)
    return {"kept": result["kept"], "submission_id": record["submission_id"]}


def image_bytes(project: str, scope: str, cid: str) -> bytes:
    for group in catalog(project, scope).values():
        for item in group:
            if item["candidate_id"] == cid:
                return (HERE / item["candidate_path"]).read_bytes()
    raise ValueError("Candidate not found")


def create_folder(action: str, project: str, level: str = "") -> str:
    project = slug(project)
    if action == "create_project":
        destination = PROJECTS / project
        if destination.exists():
            raise ValueError("Project already exists")
        (destination / "general").mkdir(parents=True)
        (destination / "levels").mkdir()
        (destination / "project.yaml").write_text(
            "project_id: " + project + "\\nart_direction:\\n  policy: Standard ComfyUI Game Asset Workflow v2\\n",
            encoding="utf-8")
        (destination / "general" / "art_direction.yaml").write_text(
            "scope: general\\ninherits: project\\n", encoding="utf-8")
        return "Created project " + project
    if action == "create_level":
        level = slug(level)
        if project not in project_scopes():
            raise ValueError("Unknown project")
        destination = PROJECTS / project / "levels" / level
        if destination.exists():
            raise ValueError("Level already exists")
        destination.mkdir(parents=True)
        (destination / "art_direction.yaml").write_text(
            "scope: levels/" + level + "\\ninherits: general\\n", encoding="utf-8")
        return "Created level " + level + " in " + project
    raise ValueError("Unknown folder action")


def render(project: str = DEFAULT_PROJECT, scope: str = "general") -> str:
    scopes = project_scopes()
    if project not in scopes or scope not in scopes[project]:
        raise ValueError("Unknown project or folder")
    grouped = catalog(project, scope)
    selected = set(state()["folders"].get(folder_id(project, scope), {}).get("kept_candidate_ids", []))
    navigation = []
    for name, folders in scopes.items():
        navigation.append("<h3>" + html.escape(name) + "</h3>")
        for folder in folders:
            href = "/curate?project=" + quote(name) + "&scope=" + quote(folder)
            navigation.append("<a href='" + href + "'>" + html.escape(folder) + "</a>")
    cards = []
    for asset, group in sorted(grouped.items()):
        entries = []
        for item in group:
            cid = item["candidate_id"]
            checked = " checked" if cid in selected else ""
            image = "/curation-image?project=" + quote(project) + "&scope=" + quote(scope) + "&id=" + quote(cid)
            entries.append("<label class='candidate'><img loading='lazy' src='" + image + "' alt='"
                           + html.escape(asset, quote=True) + "'><span><input type='checkbox' name='candidate_id' value='"
                           + html.escape(cid, quote=True) + "'" + checked + "> Keep "
                           + html.escape(str(item.get("version_label", ""))) + "</span>"
                           + "<small>Seed " + html.escape(str(item.get("seed", ""))) + "</small></label>")
        cards.append("<section><h2>" + html.escape(asset) + "</h2><div class='grid'>" + "".join(entries) + "</div></section>")
    return """<!doctype html><html><head><meta charset='utf-8'><title>Game Asset Library</title>
<style>body{font:16px Arial;background:#202020;color:#eee;margin:20px}a{color:#a8d0ff;display:block;margin:7px}
.layout{display:grid;grid-template-columns:230px 1fr;gap:24px}aside,section{background:#303030;padding:16px;border-radius:10px;margin-bottom:18px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(175px,1fr));gap:12px}
.candidate{display:flex;flex-direction:column;gap:8px;padding:8px;border:2px solid #666;border-radius:8px}
.candidate:has(input:checked){border-color:#3d8bff}.candidate img{width:100%;height:170px;object-fit:contain;background:#444}
button{background:#45617e;color:white;border:0;border-radius:6px;padding:12px;margin:10px 8px 0 0;cursor:pointer}
button.submit{background:#286a48}small{color:#aaa}</style></head><body>
<h1>Game Project Asset Library</h1><p>Keep any number of candidates. Saving or submitting does not install artwork in the game.</p>
<div class='layout'><aside><h2>Projects &amp; Folders</h2>""" + "".join(navigation) + """
<hr><h3>Create folders</h3>
<form action='/curation-action' method='post'>
<label>New project ID <input name='project' required pattern='[a-z0-9][a-z0-9_-]*'></label>
<button name='action' value='create_project'>Create game project</button>
</form>
<form action='/curation-action' method='post'>
<input type='hidden' name='project' value='""" + html.escape(project, quote=True) + """'>
<label>New level ID <input name='level' required pattern='[a-z0-9][a-z0-9_-]*'></label>
<button name='action' value='create_level'>Create level folder</button>
</form></aside>
<main><h2>""" + html.escape(project + " / " + scope) + """</h2>
<form action='/curation-action' method='post'>
<input type='hidden' name='project' value='""" + html.escape(project, quote=True) + """'>
<input type='hidden' name='scope' value='""" + html.escape(scope, quote=True) + """'>
<button name='action' value='save'>Save kept selections</button>
<button class='submit' name='action' value='submit' onclick="return confirm('Submit all checked candidates to the curated library? No game art will change.')">Submit folder selections</button>
<p>""" + str(sum(len(x) for x in grouped.values())) + """ available candidates across """ + str(len(grouped)) + """ assets.</p>
""" + "".join(cards) + """<button name='action' value='save'>Save kept selections</button>
<button class='submit' name='action' value='submit'>Submit folder selections</button></form></main></div></body></html>"""
