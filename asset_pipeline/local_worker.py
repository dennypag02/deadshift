#!/usr/bin/env python3
"""DeadShift local worker.

Polls GitHub-backed job files, runs local ComfyUI generation, builds a review
page, and serves review pages at http://127.0.0.1:8765/.
"""

from __future__ import annotations

import html
import asset_approval
import project_library
import curation_sync
import json
import logging
import shutil
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse

import requests
import yaml

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
QUEUE_DIR = HERE / "jobs" / "queued"
PROMOTION_QUEUE_DIR = HERE / "jobs" / "promote"
REVIEW_DIR = HERE / "staging" / "review"
STATE_PATH = HERE / "worker_state.json"
STATUS_PATH = HERE / "worker_status.json"
LOG_PATH = HERE / "worker.log"
MANIFEST_PATH = HERE / "manifest.json"

BRANCH = "feature/asset-pipeline-step1"
POLL_SECONDS = 60
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 8765

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)


def write_status(**values: object) -> None:
    status = {}
    if STATUS_PATH.exists():
        try:
            loaded = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                status.update(loaded)
        except Exception:
            pass
    status.update(values)
    status["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    STATUS_PATH.write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")


def load_state() -> dict:
    if not STATE_PATH.exists():
        return {"processed": []}
    try:
        data = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {"processed": []}
    if not isinstance(data, dict):
        return {"processed": []}
    if not isinstance(data.get("processed"), list):
        data["processed"] = []
    return data


def save_state(state: dict) -> None:
    STATE_PATH.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")


def run(command: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    logging.info("RUN %s", " ".join(command))
    kwargs = {}
    if sys.platform == "win32":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0
        kwargs["startupinfo"] = startupinfo
        kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
    return subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
        **kwargs,
    )


def update_repo() -> bool:
    result = run(["git", "pull", "--ff-only", "origin", BRANCH], cwd=REPO_ROOT)
    if result.returncode != 0:
        logging.warning("git pull failed: %s %s", result.stdout, result.stderr)
        write_status(state="git_error", message=(result.stderr or result.stdout).strip())
        return False
    return True


def comfy_reachable() -> bool:
    for port in (8000, 8188):
        try:
            response = requests.get(f"http://127.0.0.1:{port}/system_stats", timeout=2)
            if response.ok:
                return True
        except requests.RequestException:
            pass
    return False


def read_job(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("job file must contain a YAML mapping")

    group = str(data.get("seed_group", "")).strip()
    required = () if group else ("asset", "category", "positive", "negative")
    missing = [key for key in required if not str(data.get(key, "")).strip()]
    if missing:
        raise ValueError("missing required fields: " + ", ".join(missing))

    data["job_id"] = str(data.get("job_id") or path.stem)
    if group:
        if any(key in data for key in ("asset", "category", "positive", "negative", "count")):
            raise ValueError("seed-group jobs cannot override asset, category, prompts, or count")
    else:
        data["count"] = int(data.get("count", 20))
        if data["count"] < 1 or data["count"] > 100:
            raise ValueError("count must be between 1 and 100")
    return data



def read_promotion_job(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("promotion job file must contain a YAML mapping")

    if not str(data.get("asset", "")).strip():
        raise ValueError("missing required field: asset")
    if not str(data.get("target", "")).strip():
        raise ValueError("missing required field: target")
    if not str(data.get("source", "")).strip() and not str(data.get("seed", "")).strip():
        raise ValueError("promotion job requires either source or seed")

    data["job_id"] = str(data.get("job_id") or path.stem)
    data["overwrite"] = bool(data.get("overwrite", False))
    return data


def process_promotion_job(path: Path, job: dict) -> bool:
    job_id = str(job["job_id"])
    asset = str(job["asset"])
    source_value = str(job.get("source", "")).strip()
    if not source_value:
        seed = str(job.get("seed", "")).strip()
        manifest = []
        if MANIFEST_PATH.exists():
            try:
                loaded = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
                if isinstance(loaded, list):
                    manifest = loaded
            except Exception as exc:
                raise ValueError(f"could not read manifest for seed lookup: {exc}") from exc
        matches = [
            item for item in manifest
            if str(item.get("seed", "")).strip() == seed
            and str(item.get("candidate_path", "")).strip()
        ]
        if not matches:
            write_status(
                state="promotion_waiting_for_source",
                job_id=job_id,
                asset=asset,
                message=f"No local candidate found for seed {seed}.",
            )
            return False
        source_value = str(matches[-1]["candidate_path"])
    source = (HERE / source_value).resolve() if source_value.startswith("staging/") else (REPO_ROOT / source_value).resolve()
    target = (REPO_ROOT / str(job["target"])).resolve()
    repo_root = REPO_ROOT.resolve()
    godot_art = (REPO_ROOT / "godot" / "art").resolve()

    if repo_root not in source.parents:
        raise ValueError("promotion source must be inside the repository")
    if godot_art != target.parent and godot_art not in target.parents:
        raise ValueError("promotion target must be inside godot/art")
    if not source.exists():
        write_status(
            state="promotion_waiting_for_source",
            job_id=job_id,
            asset=asset,
            message=f"Waiting for approved source image: {source.name}",
        )
        return False

    if target.exists() and target.read_bytes() != source.read_bytes() and not job["overwrite"]:
        write_status(
            state="failed",
            job_id=job_id,
            asset=asset,
            message=f"Promotion target already exists and overwrite is disabled: {target.relative_to(REPO_ROOT)}",
        )
        return True

    write_status(
        state="promoting",
        job_id=job_id,
        asset=asset,
        message=f"Promoting {source.name} into Godot.",
    )

    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.read_bytes() != source.read_bytes():
        shutil.copy2(source, target)

    rel_target = target.relative_to(REPO_ROOT).as_posix()
    add = run(["git", "add", "--", rel_target], cwd=REPO_ROOT)
    if add.returncode != 0:
        message = (add.stderr or add.stdout or "git add failed").strip()
        write_status(state="failed", job_id=job_id, asset=asset, message=message)
        return True

    status = run(["git", "status", "--porcelain", "--", rel_target], cwd=REPO_ROOT)
    if status.returncode != 0:
        message = (status.stderr or status.stdout or "git status failed").strip()
        write_status(state="failed", job_id=job_id, asset=asset, message=message)
        return True

    if status.stdout.strip():
        commit = run(
            ["git", "commit", "-m", f"Promote approved DeadShift asset: {asset}", "--", rel_target],
            cwd=REPO_ROOT,
        )
        if commit.returncode != 0:
            message = (commit.stderr or commit.stdout or "git commit failed").strip()
            write_status(state="failed", job_id=job_id, asset=asset, message=message)
            return True

    push = run(["git", "push", "origin", BRANCH], cwd=REPO_ROOT)
    if push.returncode != 0:
        message = (push.stderr or push.stdout or "git push failed").strip()
        write_status(
            state="promotion_waiting_for_git_auth",
            job_id=job_id,
            asset=asset,
            message=message,
        )
        return False

    write_status(
        state="promotion_complete",
        job_id=job_id,
        asset=asset,
        promoted_file=rel_target,
        message=f"Promoted {asset} into Godot and pushed it to GitHub.",
    )
    logging.info("completed promotion job %s", job_id)
    return True



def process_job(path: Path, job: dict) -> bool:
    job_id = str(job["job_id"])
    asset = str(job.get("asset") or job.get("seed_group"))

    if not comfy_reachable():
        write_status(
            state="waiting_for_comfyui",
            job_id=job_id,
            asset=asset,
            message="Open ComfyUI Desktop. The worker will continue automatically.",
        )
        return False

    write_status(
        state="running",
        job_id=job_id,
        asset=asset,
        count=job.get("count"),
        message=f"Generating candidates for {asset}.",
    )

    generate = run(
        [sys.executable, str(HERE / "generate.py"), "--job-file", str(path)],
        cwd=HERE,
    )
    if generate.returncode != 0:
        message = (generate.stderr or generate.stdout or "generation failed").strip()
        logging.error("generation failed for %s: %s", job_id, message)
        write_status(state="failed", job_id=job_id, asset=asset, message=message)
        return True

    review = run(
        [sys.executable, str(HERE / "review.py"), "--job-id", job_id],
        cwd=HERE,
    )
    if review.returncode != 0:
        message = (review.stderr or review.stdout or "review build failed").strip()
        logging.error("review failed for %s: %s", job_id, message)
        write_status(state="failed", job_id=job_id, asset=asset, message=message)
        return True

    review_file = f"{job_id}.html"
    write_status(
        state="complete",
        job_id=job_id,
        asset=asset,
        count=job.get("count"),
        review_file=review_file,
        message="Review batch is ready.",
    )
    logging.info("completed job %s", job_id)
    webbrowser.open(f"http://{SERVER_HOST}:{SERVER_PORT}/latest")
    return True



def queued_promotions(processed: set[str]) -> list[Path]:
    PROMOTION_QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    files = sorted(
        [*PROMOTION_QUEUE_DIR.glob("*.yaml"), *PROMOTION_QUEUE_DIR.glob("*.yml")],
        key=lambda p: p.name,
    )
    return [path for path in files if path.stem not in processed]



def queued_jobs(processed: set[str]) -> list[Path]:
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    files = sorted(
        [*QUEUE_DIR.glob("*.yaml"), *QUEUE_DIR.glob("*.yml")],
        key=lambda p: p.name,
    )
    return [path for path in files if path.stem not in processed]


def worker_loop() -> None:
    write_status(state="idle", message="Worker is running and waiting for jobs.")
    while True:
        try:
            if update_repo():
                try:
                    result = curation_sync.publish(run, BRANCH)
                    if result["published"]:
                        write_status(state="curation_published", message=f"Published {result['published']} curated submission(s) to GitHub.")
                except Exception as exc:
                    logging.exception("curation sync failed")
                    write_status(state="curation_sync_error", message=str(exc))
            state = load_state()
            processed = set(str(item) for item in state.get("processed", []))

            for path in queued_promotions(processed):
                try:
                    job = read_promotion_job(path)
                except Exception as exc:
                    logging.exception("invalid promotion job %s", path)
                    write_status(
                        state="failed",
                        job_id=path.stem,
                        message=f"Invalid promotion job file: {exc}",
                    )
                    processed.add(path.stem)
                    state["processed"] = sorted(processed)
                    save_state(state)
                    continue

                job_id = str(job["job_id"])
                if job_id in processed:
                    continue

                finished = process_promotion_job(path, job)
                if finished:
                    processed.add(job_id)
                    state["processed"] = sorted(processed)
                    save_state(state)
                else:
                    break

            for path in queued_jobs(processed):
                try:
                    job = read_job(path)
                except Exception as exc:
                    logging.exception("invalid job %s", path)
                    write_status(
                        state="failed",
                        job_id=path.stem,
                        message=f"Invalid job file: {exc}",
                    )
                    processed.add(path.stem)
                    state["processed"] = sorted(processed)
                    save_state(state)
                    continue

                job_id = str(job["job_id"])
                if job_id in processed:
                    continue

                finished = process_job(path, job)
                if finished:
                    processed.add(job_id)
                    state["processed"] = sorted(processed)
                    save_state(state)
                else:
                    break

            if not queued_jobs(processed) and not queued_promotions(processed):
                current = {}
                if STATUS_PATH.exists():
                    try:
                        current = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
                    except Exception:
                        pass
                if current.get("state") not in {"complete", "failed", "waiting_for_comfyui"}:
                    write_status(state="idle", message="Worker is running and waiting for jobs.")

        except Exception:
            logging.exception("worker loop error")
            write_status(state="worker_error", message="See worker.log for details.")

        time.sleep(POLL_SECONDS)


class ReviewHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        REVIEW_DIR.mkdir(parents=True, exist_ok=True)
        super().__init__(*args, directory=str(REVIEW_DIR), **kwargs)

    def log_message(self, format: str, *args: object) -> None:
        logging.info("HTTP " + format, *args)

    def do_GET(self) -> None:
        path = urlparse(self.path).path

        if path == "/latest":
            status = {}
            if STATUS_PATH.exists():
                try:
                    status = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
                except Exception:
                    pass
            review_file = status.get("review_file")
            if review_file and (REVIEW_DIR / str(review_file)).exists():
                self.send_response(302)
                self.send_header("Location", "/" + quote(str(review_file)))
                self.end_headers()
                return
            self._send_status_page(status)
            return

        if path == "/curate":
            query = parse_qs(urlparse(self.path).query)
            try:
                page = project_library.render(
                    str(query.get("project", ["deadshift"])[0]),
                    str(query.get("scope", ["general"])[0]),
                )
                self._send_bytes(page.encode("utf-8"), "text/html; charset=utf-8")
            except (ValueError, OSError) as exc:
                self.send_error(400, str(exc))
            return

        if path == "/curation-image":
            query = parse_qs(urlparse(self.path).query)
            try:
                payload = project_library.image_bytes(
                    str(query.get("project", [""])[0]),
                    str(query.get("scope", [""])[0]),
                    str(query.get("id", [""])[0]),
                )
                self._send_bytes(payload, "image/png")
            except (ValueError, OSError) as exc:
                self.send_error(404, str(exc))
            return

        if path == "/approvals":
            try:
                self._send_bytes(asset_approval.render().encode("utf-8"), "text/html; charset=utf-8")
            except Exception as exc:
                self.send_error(500, str(exc))
            return

        if path == "/candidate":
            query = parse_qs(urlparse(self.path).query)
            try:
                image = asset_approval.image_bytes(
                    str(query.get("asset", [""])[0]), str(query.get("seed", [""])[0])
                )
                self._send_bytes(image, "image/png")
            except (ValueError, OSError) as exc:
                self.send_error(404, str(exc))
            return

        if path == "/library":
            query = parse_qs(urlparse(self.path).query)
            asset = str(query.get("asset", [""])[0]).strip()
            self._send_library_page(asset)
            return

        if path == "/":
            status = {}
            if STATUS_PATH.exists():
                try:
                    status = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
                except Exception:
                    pass
            self._send_status_page(status)
            return

        super().do_GET()

    def _send_bytes(self, payload: bytes, content_type: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self) -> None:
        route = urlparse(self.path).path
        if route not in ("/asset-action", "/curation-action"):
            self.send_error(404)
            return
        origin = self.headers.get("Origin", "")
        if origin and origin not in ("http://127.0.0.1:8765", "http://localhost:8765"):
            self.send_error(403, "Invalid origin")
            return
        host = self.headers.get("Host", "")
        if host not in ("127.0.0.1:8765", "localhost:8765"):
            self.send_error(403, "Invalid host")
            return
        if self.headers.get("Content-Type", "").split(";")[0].strip() != "application/x-www-form-urlencoded":
            self.send_error(415)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > 8192:
                raise ValueError("Invalid form length")
            fields = parse_qs(self.rfile.read(length).decode("utf-8"), keep_blank_values=True)
            if route == "/curation-action":
                project = str(fields.get("project", [""])[0])
                scope = str(fields.get("scope", [""])[0])
                ids = [str(value) for value in fields.get("candidate_id", [])]
                action = str(fields.get("action", [""])[0])
                if action in ("create_project", "create_level"):
                    result = project_library.create_folder(action, project, str(fields.get("level", [""])[0]))
                elif action == "save":
                    outcome = project_library.save_selection(project, scope, ids)
                    result = f"Saved {outcome['kept']} kept candidates in {outcome['folder']}."
                elif action == "submit":
                    outcome = project_library.submit_folder(project, scope, ids)
                    result = f"Submitted {outcome['kept']} curated candidates as {outcome['submission_id']}. No game art changed."
                else:
                    raise ValueError("Unknown curation action")
            else:
                result = asset_approval.action(fields)
        except (ValueError, OSError, KeyError) as exc:
            self.send_error(400, str(exc))
            return
        page = ("<!doctype html><meta charset='utf-8'><title>DeadShift Approval</title>"
                "<body style='font:18px Arial;background:#202020;color:white;padding:30px'>"
                "<p>" + html.escape(result) + "</p><a style='color:#9ecbff' href='/curate'>Back to project library</a> | <a style='color:#9ecbff' href='/approvals'>Back to approvals</a></body>")
        self._send_bytes(page.encode("utf-8"), "text/html; charset=utf-8")

    def _send_status_page(self, status: dict) -> None:
        state = html.escape(str(status.get("state", "starting")))
        message = html.escape(str(status.get("message", "Worker is starting.")))
        job_id = html.escape(str(status.get("job_id", "")))
        asset = html.escape(str(status.get("asset", "")))

        refresh = ""
        if state not in {"complete", "failed"}:
            refresh = '<meta http-equiv="refresh" content="5">'

        body = f"""<!doctype html>
<html><head><meta charset="utf-8">{refresh}
<title>DeadShift Asset Worker</title>
<style>
body{{font-family:Arial,sans-serif;background:#202020;color:#eee;padding:32px}}
.card{{max-width:760px;background:#2d2d2d;border:1px solid #444;border-radius:12px;padding:24px}}
code{{color:#ddd}} a{{color:#9ecbff}}
</style></head>
<body><div class="card">
<h1>DeadShift Asset Worker</h1>
<p><strong>Status:</strong> {state}</p>
<p>{message}</p>
<p><strong>Job:</strong> {job_id or "none"}</p>
<p><strong>Asset:</strong> {asset or "none"}</p>
<p><a href="/library">Open Asset Library</a> &nbsp;|&nbsp; <a href="/curate">Project Folders / Bulk Selection</a> &nbsp;|&nbsp; <a href="/approvals">Select / Approve Assets</a> &nbsp;|&nbsp; <a href="/latest">Open Latest Review</a></p>
<p>This page refreshes automatically while work is in progress.</p>
</div></body></html>"""
        encoded = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


    def _send_library_page(self, selected_asset: str = "") -> None:
        manifest: list[dict] = []
        if MANIFEST_PATH.exists():
            try:
                loaded = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
                if isinstance(loaded, list):
                    manifest = [item for item in loaded if isinstance(item, dict)]
            except Exception:
                logging.exception("could not load asset manifest")

        available: dict[str, dict[str, object]] = {}
        for item in manifest:
            asset_name = str(item.get("asset", "")).strip()
            category = str(item.get("category", "")).strip()
            candidate_path = str(item.get("candidate_path", "")).strip()
            if not asset_name or not candidate_path:
                continue
            candidate = HERE / candidate_path
            if not candidate.exists():
                continue
            record = available.setdefault(asset_name, {"category": category, "count": 0})
            record["count"] = int(record["count"]) + 1

        if not selected_asset:
            rows = []
            for asset_name in sorted(available):
                record = available[asset_name]
                rows.append(
                    "<tr>"
                    f"<td><a href='/library?asset={quote(asset_name)}'>{html.escape(asset_name)}</a></td>"
                    f"<td>{html.escape(str(record['category']))}</td>"
                    f"<td>{record['count']}</td>"
                    "</tr>"
                )
            content = (
                "<h1>DeadShift Asset Library</h1>"
                "<p><a href='/'>Worker Status</a> &nbsp;|&nbsp; <a href='/latest'>Latest Review</a></p>"
                "<p>All generated candidates that still exist locally are listed below.</p>"
                "<table><thead><tr><th>Asset</th><th>Category</th><th>Candidates</th></tr></thead>"
                f"<tbody>{''.join(rows) if rows else '<tr><td colspan=3>No local candidates found.</td></tr>'}</tbody></table>"
            )
        else:
            cards = []
            entries = [item for item in manifest if str(item.get("asset", "")).strip() == selected_asset]
            for item in entries:
                candidate_path = str(item.get("candidate_path", "")).strip()
                if not candidate_path:
                    continue
                candidate = HERE / candidate_path
                if not candidate.exists():
                    continue
                try:
                    import base64
                    encoded_image = base64.b64encode(candidate.read_bytes()).decode("ascii")
                except Exception:
                    logging.exception("could not embed candidate %s", candidate)
                    continue
                version = html.escape(str(item.get("version_label", "")))
                seed = html.escape(str(item.get("seed", "")))
                filename = html.escape(candidate.name)
                cards.append(
                    "<article class='asset-card'>"
                    "<div class='preview'>"
                    f"<img src='data:image/png;base64,{encoded_image}' alt='{filename}'>"
                    "</div>"
                    "<div class='meta'>"
                    f"<strong>{html.escape(selected_asset)} {version}</strong><br>"
                    f"{filename}<br>seed: {seed}"
                    "</div></article>"
                )
            content = (
                f"<h1>{html.escape(selected_asset)} history</h1>"
                "<p><a href='/library'>Back to Asset Library</a> &nbsp;|&nbsp; <a href='/'>Worker Status</a></p>"
                f"<p>{len(cards)} locally available candidate(s).</p>"
                f"<div class='asset-grid'>{''.join(cards) if cards else '<p>No local candidates found for this asset.</p>'}</div>"
            )

        body = f"""<!doctype html>
<html><head><meta charset="utf-8">
<title>DeadShift Asset Library</title>
<style>
body{{font-family:Arial,sans-serif;background:#202020;color:#eee;padding:32px}}
a{{color:#9ecbff}} table{{border-collapse:collapse;min-width:620px;background:#2d2d2d}}
th,td{{padding:12px 16px;border-bottom:1px solid #444;text-align:left}}
.asset-grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:18px}}
.asset-card{{background:#2d2d2d;border:1px solid #444;border-radius:10px;overflow:hidden}}
.preview{{min-height:280px;background:#3a3a3a;display:flex;align-items:center;justify-content:center;padding:16px}}
.preview img{{max-width:100%;max-height:380px}}
.meta{{padding:12px 14px;line-height:1.5;word-break:break-word}}
</style></head><body>{content}</body></html>"""
        encoded = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def start_server() -> ThreadingHTTPServer:
    try:
        server = ThreadingHTTPServer((SERVER_HOST, SERVER_PORT), ReviewHandler)
    except OSError as exc:
        raise SystemExit(
            f"Could not start review server on port {SERVER_PORT}. "
            "The DeadShift worker may already be running."
        ) from exc

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def main() -> None:
    logging.info("DeadShift worker starting")
    REVIEW_DIR.mkdir(parents=True, exist_ok=True)
    start_server()
    worker_loop()


if __name__ == "__main__":
    main()
