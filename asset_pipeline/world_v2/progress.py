"""Local live status plus a separate, metadata-only GitHub progress branch."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess
import threading
from datetime import datetime, timezone

BRANCH = 'automation/world-asset-progress'
ALLOWED_ORIGINS = {'https://github.com/dennypag02/deadshift.git',
                   'https://github.com/dennypag02/deadshift',
                   'git@github.com:dennypag02/deadshift.git'}


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    os.replace(temp, path)


def git(repo, *args, input=None):
    # Binary stdin prevents Windows text mode from adding CR to mktree filenames.
    payload = input.encode('utf-8') if input is not None else None
    result = subprocess.run(['git', *args], cwd=repo, input=payload,
                            capture_output=True, check=True, timeout=35)
    return result.stdout.decode('utf-8', errors='replace').strip()


def publish(repo: Path, data: dict):
    """No checkout/index modifications; non-forced push only to dedicated progress ref."""
    if git(repo, 'remote', 'get-url', 'origin') not in ALLOWED_ORIGINS:
        raise RuntimeError('PERSONAL_REPOSITORY_REQUIRED')
    ref = 'refs/heads/' + BRANCH
    remote = git(repo, 'ls-remote', 'origin', ref)
    parent = remote.split()[0] if remote else None
    if parent:
        git(repo, 'fetch', '--no-tags', 'origin', ref)
    blob = git(repo, 'hash-object', '-w', '--stdin', input=json.dumps(data, indent=2) + '\n')
    tree = git(repo, 'mktree', input=f'100644 blob {blob}\tworld_status.json\n')
    args = ['-c', 'user.name=DeadShift Asset Worker', '-c',
            'user.email=deadshift-worker@users.noreply.github.com', 'commit-tree', tree]
    if parent:
        args += ['-p', parent]
    args += ['-m', 'progress(world): ' + data['state'] + ' ' + data['stage']]
    commit = git(repo, *args)
    git(repo, 'push', 'origin', commit + ':' + ref)  # Reject racing writers; never force.


class Progress:
    def __init__(self, here, job_id):
        self.here, self.job_id = here, job_id
        self.data = {'schema': 'DEADSHIFT_ASSET_PROGRESS_V1', 'job_id': job_id,
                     'state': 'RUNNING', 'stage': 'START', 'generated': 0,
                     'promoted': 0, 'message': 'World-art worker job started.'}
        self.guard = threading.Lock()
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._heartbeat, daemon=True)

    def __enter__(self):
        self.update('START', 'World-art worker job started.')
        self.thread.start()
        return self

    def __exit__(self, *_):
        self.stop.set()
        self.thread.join(timeout=40)

    def update(self, stage, message, state='RUNNING', **values):
        with self.guard:
            self.data.update(stage=stage, state=state, message=message, **values)
            self._write()

    def _write(self):
        self.data['updated_at'] = datetime.now(timezone.utc).isoformat()
        runtime = self.here / 'staging/world_v2/runtime_checks.json'
        if runtime.exists():
            try:
                checks = json.loads(runtime.read_text(encoding='utf-8'))
                if checks.get('job_id') == self.job_id:
                    self.data['runtime_checks'] = checks
            except (ValueError, OSError):
                pass
        atomic_json(self.here / 'staging/world_v2/latest_status.json', self.data)
        local_status = self.here / 'worker_status.json'
        old = json.loads(local_status.read_text(encoding='utf-8')) if local_status.exists() else {}
        old.update(state=self.data['state'].lower(), job_id=self.job_id,
                   asset=self.data.get('asset', 'outskirts_world_v2'), message=self.data['message'],
                   updated_at=self.data['updated_at'])
        atomic_json(local_status, old)
        print(json.dumps(self.data), flush=True)
        try:
            publish(self.here.parent, self.data)
        except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
            # No exception details on the public branch: local logs may contain paths.
            print('PROGRESS_PUBLISH_UNAVAILABLE ' + type(exc).__name__, flush=True)

    def _heartbeat(self):
        while not self.stop.wait(120):
            with self.guard:
                self._write()
