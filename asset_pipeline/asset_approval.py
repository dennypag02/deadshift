"""Local-only asset selection, approval and regeneration interface.

Candidate selection never modifies game art. Promotion is a separate explicit
action, uses manifest-bound sources, and never overwrites an existing target.
"""
from __future__ import annotations

import html
import json
import re
import secrets
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, quote
import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
MANIFEST = HERE / "manifest.json"
SELECTIONS = HERE / "asset_selections.json"
APPROVALS = HERE / "asset_approvals.json"
QUEUE = HERE / "jobs" / "queued"
PROMOTIONS = HERE / "jobs" / "promote"


def read_json(path, fallback):
    if not path.exists():
        return fallback
    data = json.loads(path.read_text(encoding="utf-8"))
    return data


def save_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def candidates():
    items = read_json(MANIFEST, [])
    if not isinstance(items, list):
        raise ValueError("manifest must be an array")
    found = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        asset = str(item.get("asset", ""))
        candidate = str(item.get("candidate_path", ""))
        if not asset or not candidate:
            continue
        path = (HERE / candidate).resolve()
        base = (HERE / "staging" / "candidates").resolve()
        if base not in path.parents or not path.is_file() or path.suffix.lower() != ".png":
            continue
        found.setdefault(asset, []).append(item)
    return found


def safe_name(value):
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", value):
        raise ValueError("Invalid asset name")
    return value


def find_candidate(asset, seed, found):
    for item in found.get(asset, []):
        if str(item.get("seed")) == seed:
            return item
    raise ValueError("Candidate not found in local manifest")


def render():
    found = candidates()
    selected = read_json(SELECTIONS, {})
    approved = read_json(APPROVALS, {})
    cards = []
    for asset in sorted(found):
        safe_name(asset)
        choices = []
        for item in sorted(found[asset], key=lambda x: int(x.get("version", 0)), reverse=True):
            seed = str(item.get("seed"))
            candidate = str(item["candidate_path"])
            path = (HERE / candidate).resolve()
            # Serve images from the existing review server through a bounded route.
            checked = " checked" if selected.get(asset) == seed else ""
            label = html.escape(str(item.get("version_label", "")))
            choices.append(
                "<label class='choice'><img loading='lazy' src='/candidate?asset="
                + quote(asset) + "&seed=" + quote(seed) + "' alt='"
                + html.escape(asset + " " + label, quote=True) + "'>"
                + "<span><input type='radio' name='seed' value='" + html.escape(seed, quote=True)
                + "'" + checked + "> " + label + " &middot; seed " + html.escape(seed) + "</span></label>"
            )
        status = "Promoted / approved" if asset in approved else ("Selected" if asset in selected else "Not selected")
        cards.append(
            "<section class='asset'><h2>" + html.escape(asset) + "</h2><p>Status: "
            + html.escape(status) + "</p><form action='/asset-action' method='post'>"
            + "<input type='hidden' name='asset' value='" + html.escape(asset, quote=True) + "'>"
            + "<div class='grid'>" + "".join(choices) + "</div>"
            + "<button name='action' value='select'>Save selection</button>"
            + "<button class='approve' name='action' value='approve' onclick=\"return confirm('Approve and queue promotion? Existing game art will NOT be overwritten.')\">Approve &amp; Promote selected</button>"
            + "<button class='regen' name='action' value='regenerate' onclick=\"return confirm('Queue four new candidates for this asset?')\">Regenerate 4</button>"
            + "</form></section>"
        )
    return """<!doctype html><html><head><meta charset='utf-8'><title>DeadShift Asset Approval</title>
<style>body{font:16px Arial,sans-serif;background:#202020;color:#eee;margin:28px;max-width:1400px}
a{color:#9ecbff}.asset{background:#303030;padding:20px;margin:18px 0;border-radius:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px}
.choice{border:2px solid #666;border-radius:9px;padding:10px;cursor:pointer;display:flex;flex-direction:column;gap:10px}
.choice:has(input:checked){border-color:#3d8bff;background:#25354a}
.choice img{width:100%;height:210px;object-fit:contain;background:#444;border-radius:6px}
button{padding:12px;margin:14px 10px 0 0;background:#45617e;border:0;border-radius:7px;color:white;cursor:pointer}
button.approve{background:#286a48}button.regen{background:#735225}
p{color:#ccc}</style></head><body><h1>DeadShift Asset Approval</h1>
<p><a href='/'>Worker status</a> | <a href='/library'>Asset Library</a></p>
<p>Choose one candidate per asset. Save selection first, or approve it directly.
Approval queues a non-overwriting promotion to Godot art; game integration and APK validation remain separate.
Regeneration creates four new candidates and keeps all prior versions.</p>""" + "".join(cards) + "</body></html>"


def image_bytes(asset, seed):
    item = find_candidate(safe_name(asset), seed, candidates())
    return (HERE / str(item["candidate_path"])).read_bytes()


def action(fields):
    asset = safe_name(fields.get("asset", [""])[0])
    action_name = fields.get("action", [""])[0]
    if action_name not in {"select", "approve", "regenerate"}:
        raise ValueError("Unknown action")
    found = candidates()
    if asset not in found:
        raise ValueError("Unknown asset")
    if action_name == "regenerate":
        config = yaml.safe_load((HERE / "assets.yaml").read_text(encoding="utf-8"))
        definition = next((x for x in config["assets"] if x.get("name") == asset), None)
        if not definition:
            raise ValueError("Missing asset definition")
        category = config["categories"][definition["category"]]
        base_negative = str(category["negative"])
        remove = str(definition.get("negative_remove", "")).strip()
        if remove:
            base_negative = ", ".join(p.strip() for p in base_negative.split(",") if p.strip().lower() != remove.lower())
        extra = str(definition.get("negative_extra", "")).strip()
        if extra:
            base_negative += ", " + extra
        job = {
            "job_id": "regen-" + asset + "-" + secrets.token_hex(6),
            "asset": asset,
            "category": definition["category"],
            "positive": str(category["style"]) + ", " + str(definition["prompt"]),
            "negative": base_negative,
            "count": 4,
        }
        QUEUE.mkdir(parents=True, exist_ok=True)
        path = QUEUE / (job["job_id"] + ".yaml")
        path.write_text(yaml.safe_dump(job, sort_keys=False), encoding="utf-8")
        return "Queued four new candidates for " + asset
    seed = fields.get("seed", [""])[0]
    item = find_candidate(asset, seed, found)
    selected = read_json(SELECTIONS, {})
    selected[asset] = seed
    save_json(SELECTIONS, selected)
    if action_name == "select":
        return "Saved selection for " + asset
    approvals = read_json(APPROVALS, {})
    if asset in approvals:
        raise ValueError("Asset already approved. Replacement requires a separate explicit review.")
    category = safe_name(str(item["category"]))
    target = ROOT / "godot" / "art" / category / (asset + ".png")
    if target.exists():
        raise ValueError("Target already exists. Existing artwork will not be overwritten.")
    job_id = "approve-" + asset + "-" + secrets.token_hex(6)
    job = {
        "job_id": job_id,
        "asset": asset,
        "source": str(item["candidate_path"]),
        "target": "godot/art/" + category + "/" + asset + ".png",
        "overwrite": False,
    }
    PROMOTIONS.mkdir(parents=True, exist_ok=True)
    (PROMOTIONS / (job_id + ".yaml")).write_text(yaml.safe_dump(job, sort_keys=False), encoding="utf-8")
    approvals[asset] = {"seed": seed, "version": item.get("version_label"), "candidate_path": item["candidate_path"],
                        "job_id": job_id, "queued_at": datetime.now(timezone.utc).isoformat(), "status": "queued"}
    save_json(APPROVALS, approvals)
    return "Promotion queued for " + asset + "; verify worker completion and GitHub push."
