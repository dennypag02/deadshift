"""Pinned official BiRefNet installation. No pip, custom-node or checkpoint installs."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import requests

REVISION = 'e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4'
MODEL_REPO = 'ZhengPeng7/BiRefNet'
WEIGHTS_SHA256 = '9ab37426bf4de0567af6b5d21b16151357149139362e6e8992021b8ce356a154'
SDXL_SHA256 = '31e35c80fc4829d14f90153f4c74cd59c90b779f6afe05a74cd6120b893f7e5b'
CHECKPOINT = 'sd_xl_base_1.0.safetensors'
MODEL_FILES = ('config.json', 'BiRefNet_config.py', 'birefnet.py', 'model.safetensors', 'README.md')
REQUIRED = ('torch', 'torchvision', 'transformers', 'timm', 'einops', 'safetensors', 'Pillow')
LICENSES = {
    MODEL_REPO: {'license': 'MIT', 'revision': REVISION,
        'source': 'https://huggingface.co/ZhengPeng7/BiRefNet',
        'license_source': 'https://github.com/ZhengPeng7/BiRefNet/blob/main/LICENSE',
        'owner_approved': True, 'scope': 'world batch; download official model only if missing'},
    'stabilityai/stable-diffusion-xl-base-1.0': {'license': 'CreativeML Open RAIL++-M',
        'source': 'https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md'},
}


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def install(destination: Path, caches: list[Path], notify=lambda *_: None) -> dict:
    """Use verified existing weights first, download missing files atomically only."""
    destination.mkdir(parents=True, exist_ok=True)
    installed = []
    for name in MODEL_FILES:
        target = destination / name
        if target.is_symlink():
            raise RuntimeError('MODEL_SYMLINK_REFUSED')
        if not target.exists():
            reusable = []
            if name == 'model.safetensors':
                for folder in caches:
                    for filename in ('model.safetensors', 'BiRefNet-general.safetensors'):
                        candidate = folder / filename
                        if candidate.is_file() and digest(candidate) == WEIGHTS_SHA256:
                            reusable.append(candidate)
            part = target.with_suffix(target.suffix + '.partial')
            if part.exists():
                part.unlink()  # Only this installer's unfinished download, never an installed model.
            try:
                if reusable:
                    notify('REUSE_MODEL', name)
                    shutil.copyfile(reusable[0], part)
                else:
                    notify('DOWNLOAD_MODEL_FILE', name)
                    url = f'https://huggingface.co/{MODEL_REPO}/resolve/{REVISION}/{name}'
                    with requests.get(url, stream=True, timeout=(15, 60)) as response:
                        response.raise_for_status()
                        size = 0
                        limit = 600_000_000 if name.endswith('.safetensors') else 2_000_000
                        with part.open('xb') as output:
                            for block in response.iter_content(1024 * 1024):
                                size += len(block)
                                if size > limit:
                                    raise RuntimeError('MODEL_DOWNLOAD_TOO_LARGE')
                                output.write(block)
                    if size == 0:
                        raise RuntimeError('EMPTY_MODEL_FILE')
                if name == 'model.safetensors' and digest(part) != WEIGHTS_SHA256:
                    raise RuntimeError('MODEL_CHECKSUM_MISMATCH')
                if target.exists():
                    raise RuntimeError('REFUSING_MODEL_OVERWRITE')
                part.rename(target)
                installed.append(name)
            finally:
                if part.exists():
                    part.unlink()
        if name == 'model.safetensors' and digest(target) != WEIGHTS_SHA256:
            raise RuntimeError('EXISTING_MODEL_CHECKSUM_MISMATCH')
    # An immutable upstream revision and all actual file hashes are recorded before load.
    receipt = {'repo': MODEL_REPO, 'revision': REVISION, 'license': 'MIT',
               'files': {name: digest(destination / name) for name in MODEL_FILES},
               'new_files': installed}
    previous = destination / 'verified-files.json'
    if previous.exists():
        saved = json.loads(previous.read_text(encoding='utf-8'))
        if saved['files'] != receipt['files']:
            raise RuntimeError('INSTALLED_MODEL_FILES_CHANGED')
    else:
        previous.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def candidates_for_python(roots: list[Path], configured: str | None = None) -> list[Path]:
    paths = [Path(configured)] if configured else []
    for root in roots:
        for parent in (root, root.parent):
            paths += [parent / '.venv/Scripts/python.exe', parent / '.venv/bin/python',
                      parent / 'venv/Scripts/python.exe', parent / 'python_embeded/python.exe']
    paths.append(Path(sys.executable).with_name('python.exe') if sys.platform == 'win32' else Path(sys.executable))
    return list(dict.fromkeys(p for p in paths if p.is_file()))


def running_comfy_pythons() -> list[Path]:
    """Read-only Windows process lookup, restricted to ComfyUI's Python process.

    Command lines are used only as a local filter and are never returned or logged.
    No process termination, package installation or elevated command is used.
    """
    if sys.platform != 'win32':
        return []
    command = (
        "Get-CimInstance Win32_Process -Filter \"Name='python.exe' OR Name='pythonw.exe'\" | "
        "Where-Object { $_.CommandLine -match '(?i)ComfyUI.*main[.]py|main[.]py.*ComfyUI' } | "
        "Select-Object -ExpandProperty ExecutablePath | ConvertTo-Json -Compress"
    )
    try:
        result = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive',
                                 '-Command', command], capture_output=True, text=True,
                                check=True, timeout=20)
        values = json.loads(result.stdout.strip() or '[]')
        if isinstance(values, str):
            values = [values]
        return list(dict.fromkeys(Path(v) for v in values if isinstance(v, str) and Path(v).is_file()))
    except (ValueError, OSError, subprocess.SubprocessError):
        return []


def select_python(roots: list[Path], configured: str | None = None) -> tuple[Path, dict]:
    from .progress import atomic_json
    code = ('import importlib.metadata as m,json; out={}; '
            '\nfor name in ' + repr(REQUIRED) + ':\n'
            ' try: out[name]=m.version(name)\n except m.PackageNotFoundError: out[name]=None\n'
            'print(json.dumps(out))')
    # The running ComfyUI process is a stronger signal than a nearby venv folder.
    running = running_comfy_pythons()
    for executable in running:
        if executable.parent.name.lower() == 'scripts' and executable.parent.parent.name.lower() in ('.venv', 'venv'):
            root = executable.parent.parent.parent
            if root not in roots:
                roots.append(root)
    candidates = list(dict.fromkeys(([Path(configured)] if configured else []) + running + candidates_for_python(roots)))
    status_dir = Path(__file__).resolve().parents[1] / 'staging/world_v2'
    execution_lock = status_dir / 'execution.lock'
    report = {'job_id': execution_lock.read_text().strip() if execution_lock.exists() else None,
              'root_count': len(roots), 'running_comfy_python_count': len(running),
              'checks': [], 'selected': None}
    best_missing = list(REQUIRED)
    for index, executable in enumerate(candidates, 1):
        check = {'candidate': index, 'running_comfy': executable in running}
        try:
            result = subprocess.run([str(executable), '-c', code], capture_output=True, text=True, timeout=45)
            versions = json.loads(result.stdout.strip().splitlines()[-1]) if result.returncode == 0 else {}
            versions = {key: versions.get(key) for key in REQUIRED}
            missing = [key for key, value in versions.items() if not value]
            check.update(versions=versions, missing=missing)
            if len(missing) < len(best_missing):
                best_missing = missing
            report['checks'].append(check)
            if not missing:
                report['selected'] = index
                atomic_json(status_dir / 'runtime_checks.json', report)
                return executable, versions
        except (ValueError, IndexError, OSError, subprocess.SubprocessError) as exc:
            check['error_type'] = type(exc).__name__
            report['checks'].append(check)
    atomic_json(status_dir / 'runtime_checks.json', report)
    if not candidates:
        raise RuntimeError('COMFY_PYTHON_NOT_LOCATED_NO_INSTALL')
    raise RuntimeError('COMFY_PYTHON_MISSING_' + '_'.join(x.upper() for x in best_missing))


def roots_from_stats(stats: dict, local: dict) -> list[Path]:
    values = [local.get('comfyui_root'), os.environ.get('COMFYUI_ROOT')]
    args = stats.get('system', {}).get('argv', [])
    if args and isinstance(args[0], str) and Path(args[0]).is_absolute():
        values.append(str(Path(args[0]).parent))
    for flag in ('--base-directory',):
        if flag in args and len(args) > args.index(flag) + 1:
            values.append(args[args.index(flag) + 1])
    return list(dict.fromkeys(Path(v) for v in values if v and Path(v).is_dir()))


def find_checkpoint(roots: list[Path], local: dict) -> Path:
    candidates = [Path(local['checkpoint_path'])] if local.get('checkpoint_path') else []
    for root in roots:
        folder = root / 'models/checkpoints'
        if folder.is_dir():
            candidates.extend(folder.rglob(CHECKPOINT))
    for candidate in dict.fromkeys(candidates):
        if candidate.is_file() and digest(candidate) == SDXL_SHA256:
            return candidate
    raise RuntimeError('OFFICIAL_SDXL_NOT_LOCATED_OR_HASH_MISMATCH')
