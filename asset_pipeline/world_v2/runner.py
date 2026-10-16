"""Opt-in ComfyUI world-art jobs with official BiRefNet and v2 provenance.

The old worker starts this through generate.py --job-file, so no worker restart
is needed. There is no automatic selection, promotion, model substitution,
package install, or overwrite of approved art.
"""
from __future__ import annotations
import copy
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
from urllib.parse import quote
import requests
import yaml
from PIL import Image
from . import images, models
from .progress import Progress, atomic_json

HERE = Path(__file__).resolve().parents[1]


def settings(here=HERE):
    path = here / 'local.yaml'
    data = yaml.safe_load(path.read_text(encoding='utf-8')) if path.exists() else {}
    return (data or {}).get('world_v2', {})


def definitions(here=HERE):
    import world_batch
    base = world_batch.load_yaml(here / 'assets.yaml')
    request = world_batch.load_yaml(here / 'batches/assets_batch_world.yaml')
    lock = json.loads((here / 'world_v2/geometry_lock.json').read_text(encoding='utf-8'))
    merged, report = world_batch.merge_proposal(base, request, lock['geometry'])
    names = {x['name'] for x in request['assets']}
    return merged, {x['name']: x for x in merged['assets'] if x['name'] in names}, report


def reference_file(here, local):
    candidates = [Path(local['art_reference'])] if local.get('art_reference') else []
    for folder in (here / 'references', here, here.parent,
                   here.parent / 'docs', here / 'projects/deadshift/levels/level-01'):
        candidates.append(folder / 'OUTSKIRTS_ART_TARGET.png')
    for candidate in candidates:
        if candidate.is_file():
            with Image.open(candidate) as image:
                image.verify()
            return candidate
    raise RuntimeError('ART_REFERENCE_REQUIRED: OUTSKIRTS_ART_TARGET.png')


def graph_for(asset, category, seed, prefix, input_image=None, inpaint=False):
    import build_workflows
    graph = build_workflows.scene_workflow()  # Core SDXL nodes only, no old RMBG graph.
    w, h = asset.get('size', category['size'])
    positive = category['style'] + ', ' + asset['prompt']
    negative = category['negative']
    remove = asset.get('negative_remove', '')
    if remove:
        negative = ', '.join(p.strip() for p in negative.split(',') if p.strip().lower() != remove.lower())
    negative += ', ' + asset.get('negative_extra', '') + ', red, amber interaction glow, interface symbols'
    graph['2']['inputs']['text'] = positive
    graph['3']['inputs']['text'] = negative
    graph['4']['inputs'].update(width=w, height=h, batch_size=1)
    graph['5']['inputs'].update(seed=seed, steps=30, cfg=6.5)
    graph['7']['inputs']['filename_prefix'] = prefix
    if input_image:
        del graph['4']
        graph['8'] = {'class_type': 'LoadImage', 'inputs': {'image': input_image}}
        if inpaint:
            graph['9'] = {'class_type': 'VAEEncodeForInpaint', 'inputs': {
                'pixels': ['8', 0], 'vae': ['1', 2], 'mask': ['8', 1], 'grow_mask_by': 6}}
        else:
            graph['9'] = {'class_type': 'VAEEncode', 'inputs': {'pixels': ['8', 0], 'vae': ['1', 2]}}
        graph['5']['inputs'].update(latent_image=['9', 0], denoise=0.65 if inpaint else 0.6)
    return graph


def validate_graph(graph, schema):
    for node in graph.values():
        name = node['class_type']
        if name not in schema:
            raise RuntimeError('COMFY_CORE_NODE_MISSING: ' + name)
        required = schema[name].get('input', {}).get('required', {})
        if set(required) - set(node['inputs']):
            raise RuntimeError('COMFY_SCHEMA_CHANGED: ' + name)
        for key, value in node['inputs'].items():
            spec = required.get(key, [])
            if name == 'LoadImage' and key == 'image':
                continue  # Newly uploaded files postdate the schema snapshot.
            if spec and isinstance(spec[0], list) and value not in spec[0]:
                raise RuntimeError('COMFY_OPTION_UNAVAILABLE: ' + name + '.' + key)


def upload(base, path):
    with path.open('rb') as stream:
        response = requests.post(base + '/upload/image',
            files={'image': (path.name, stream, 'image/png')},
            data={'type': 'input', 'overwrite': 'false'}, timeout=60)
    response.raise_for_status()
    value = response.json()
    return '/'.join(p for p in (value.get('subfolder', ''), value['name']) if p)


def execute_graph(base, graph, schema, folder, label):
    import generate
    validate_graph(graph, schema)
    queue = generate.get_json(base, '/queue')
    if queue.get('queue_running') or queue.get('queue_pending'):
        raise RuntimeError('COMFY_BUSY_NO_JOB_SUBMITTED')
    atomic_json(folder / (label + '-graph.json'), graph)
    pending = HERE / 'staging/world_v2/outstanding.json'
    if pending.exists():
        raise RuntimeError('OUTSTANDING_PROMPT_REQUIRES_RECONCILIATION')
    atomic_json(pending, {'record': folder.name, 'stage': label, 'prompt_id': None})
    prompt_id = generate.queue_prompt(base, graph)
    atomic_json(pending, {'record': folder.name, 'stage': label, 'prompt_id': prompt_id})
    atomic_json(folder / (label + '-submission.json'), {'prompt_id': prompt_id})
    history = generate.wait_for_history(base, prompt_id)
    atomic_json(folder / (label + '-history.json'), history)
    target = folder / (label + '.png')
    if target.exists():
        raise RuntimeError('REFUSING_RAW_OVERWRITE')
    generate.download_image(base, generate.find_saved_image(history), target)
    pending.unlink()  # History plus raw bytes are durable; next job may now start.
    return target, prompt_id


def approved_reference(here, name):
    path = here / 'asset_approvals.json'
    approvals = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
    approval = approvals.get(name)
    if not approval:
        raise RuntimeError('FAMILY_REFERENCE_APPROVAL_REQUIRED: ' + name)
    manifest = json.loads((here / 'manifest.json').read_text(encoding='utf-8'))
    item = next((x for x in manifest if x.get('asset') == name and str(x.get('seed')) == str(approval['seed'])), None)
    if not item:
        raise RuntimeError('APPROVED_REFERENCE_NOT_IN_MANIFEST')
    candidate = (here / item['candidate_path']).resolve()
    if not candidate.is_relative_to((here / 'staging/candidates').resolve()) or not candidate.is_file():
        raise RuntimeError('INVALID_REFERENCE_PATH')
    return candidate


def create_candidate(job, asset, config, base, schema, executable, model_dir, provenance, art_ref, progress):
    import generate
    name, category_name = asset['name'], asset['category']
    category = config['categories'][category_name]
    manifest = generate.load_manifest()
    version = generate.next_version(manifest, name)
    seed = secrets.randbits(63)
    candidate_id = f'{name}_v{version:02d}_{seed}'
    folder = HERE / 'staging/world_v2/records' / candidate_id
    folder.mkdir(parents=True, exist_ok=False)
    reference = None
    ref_receipt = {'art_direction_sha256': models.digest(art_ref), 'art_direction_file': art_ref.name,
                   'technique': 'anchor_text2img_for_user_review'}
    if job.get('reference_asset'):
        reference = approved_reference(HERE, job['reference_asset'])
        prepared = images.fit(Image.open(reference), tuple(asset.get('size', category['size'])),
                              background=(255,255,255,255)).convert('RGB')
        path = folder / 'reference.png'
        prepared.save(path)
        reference_name = upload(base, path)
        ref_receipt.update(asset=job['reference_asset'], sha256=models.digest(reference), technique='approved_reference_img2img')
    else:
        reference_name = None
    raw_graph = graph_for(asset, category, seed, 'deadshift/world_v2/' + candidate_id, reference_name)
    spec = {'asset': asset, 'category': category, 'target_px': list(images.dimensions(asset.get('target', category['target']))),
            'fit': 'pad', 'reference': ref_receipt, 'provenance': provenance,
            'licenses': models.LICENSES, 'approval': 'NOT_APPROVED', 'promotion': 'NOT_STARTED',
            'promotion_gates': ['user selection', 'commit PNG with provenance and import settings', 'Godot/APK/device review'],
            'geometry_lock': json.loads((HERE / 'world_v2/geometry_lock.json').read_text(encoding='utf-8'))}
    atomic_json(folder / 'generation-record.json', spec)
    progress.update('GENERATE', 'Generating ' + name + f' candidate {version}.', asset=name)
    raw, prompt_id = execute_graph(base, raw_graph, schema, folder, 'raw')
    texture = category['workflow'] == 'texture' or category_name == 'terrain'
    size = tuple(spec['target_px'])
    if texture:
        shifted = folder / 'offset-mask.png'
        images.prepare_inpaint(Image.open(raw)).save(shifted)
        seam_graph = graph_for(asset, category, seed, 'deadshift/world_v2/' + candidate_id + '_seams', upload(base, shifted), True)
        repaired, _ = execute_graph(base, seam_graph, schema, folder, 'seams')
        full = images.periodic_edges(Image.open(repaired))
        full.save(folder / 'tile-full.png')
        images.grid3(full).save(folder / 'tile-grid-full.png')
        processed = images.periodic_edges(images.fit(full, size, trim=False, mode='crop').convert('RGB'), band=4)
        images.validate_wrap(processed)
        images.grid3(processed).save(folder / 'tile-grid-final.png')
        method = 'offset-cross-inpaint-plus-periodic-edge-blend; visual-3x3-review-required'
    else:
        preview = folder / 'alpha-preview.png'
        progress.update('ALPHA_PREVIEW', 'Making the BiRefNet review preview for ' + name + '.', asset=name)
        subprocess.run([str(executable), str(Path(__file__).with_name('infer.py')),
                        '--model', str(model_dir), '--source', str(raw), '--target', str(preview)],
                       check=True, timeout=900)
        processed = images.fit(Image.open(preview), size)
        method = 'BiRefNet-preview-alpha-trim-uniform-Lanczos-pad'
    destination = HERE / 'staging/candidates' / category_name / (candidate_id + '.png')
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise RuntimeError('REFUSING_CANDIDATE_OVERWRITE')
    processed.save(destination)
    spec.update(postprocess=method, candidate_sha256=models.digest(destination), raw_sha256=models.digest(raw),
                graphs={p.name: models.digest(p) for p in folder.glob('*-graph.json')})
    atomic_json(folder / 'generation-record.json', spec)
    entry = {'asset': name, 'category': category_name, 'job_id': job['job_id'],
             'version': version, 'version_label': f'v{version:02d}', 'seed': seed,
             'pipeline': 'world_v2', 'candidate_id': candidate_id, 'prompt_id': prompt_id,
             'candidate_path': destination.relative_to(HERE).as_posix(),
             'raw_path': raw.relative_to(HERE).as_posix(),
             'generation_record': (folder / 'generation-record.json').relative_to(HERE).as_posix(),
             'generation_record_sha256': models.digest(folder / 'generation-record.json'),
             'settings': spec, 'prompt': raw_graph['2']['inputs']['text'],
             'negative': raw_graph['3']['inputs']['text']}
    manifest.append(entry)
    atomic_json(HERE / 'manifest.json', manifest)
    progress.update('CANDIDATE_READY', 'Candidate added to the local asset library; not approved or promoted.',
                    generated=progress.data['generated'] + 1, candidate_id=candidate_id)


def run(job, dry_run=False):
    config, assets, report = definitions()
    names = job.get('world_assets', [])
    if not isinstance(names, list) or not names or len(names) != len(set(names)) or any(n not in assets for n in names):
        raise ValueError('world_assets must list unique names from the submitted world batch')
    count = job.get('count', 4)
    if type(count) is not int or not 1 <= count <= 4:
        raise ValueError('World review jobs allow one to four candidates per asset')
    if dry_run:
        print(json.dumps({'requested_names': names, 'candidate_count': len(names)*count,
                          'skipped_manifest_duplicates': report['skipped_duplicate_names'],
                          'generation': 'DRY_RUN', 'images_queued': 0}, indent=2))
        return
    import generate
    local = settings()
    (HERE / 'staging/world_v2').mkdir(parents=True, exist_ok=True)
    lock = HERE / 'staging/world_v2/execution.lock'
    with lock.open('x') as stream:
        stream.write(job['job_id'])
    try:
        with Progress(HERE, job['job_id']) as progress:
            try:
                base = generate.detect_server()
                stats = generate.get_json(base, '/system_stats')
                schema = generate.get_json(base, '/object_info')
                roots = models.roots_from_stats(stats, local)
                executable, versions = models.select_python(roots, local.get('python'))
                progress.update('VERIFY_SDXL', 'Verifying the installed SDXL checkpoint; no checkpoint download.')
                checkpoint = models.find_checkpoint(roots, local)
                model_dir = HERE / 'staging/world_v2/models' / models.REVISION
                caches = [root / 'models/RMBG/BiRefNet' for root in roots]
                hf = Path(os.environ.get('HF_HOME', str(Path.home() / '.cache/huggingface'))) / 'hub/models--ZhengPeng7--BiRefNet/snapshots'
                if hf.is_dir():
                    caches += list(hf.iterdir())
                if local.get('birefnet_cache'):
                    caches.insert(0, Path(local['birefnet_cache']))
                progress.update('MODEL_SETUP', 'Checking official BiRefNet; downloading only missing model files.')
                receipt = models.install(model_dir, caches, lambda stage, name: progress.update(stage, 'Official BiRefNet: ' + name))
                progress.update('MODEL_LOAD_TEST', 'Testing the official model in the existing ComfyUI Python environment.')
                subprocess.run([str(executable), str(Path(__file__).with_name('infer.py')), '--model', str(model_dir)],
                               check=True, timeout=900)
                progress.update('MODEL_READY', 'Official BiRefNet checksum and local load test passed.',
                                model_sha256=models.WEIGHTS_SHA256, model_revision=models.REVISION)
                art_ref = reference_file(HERE, local)
                provenance = {'model': receipt, 'checkpoint_sha256': models.digest(checkpoint),
                              'dependency_versions': versions, 'comfy_system': stats,
                              'custom_nodes_used': [], 'background_device': 'cpu', 'background_dtype': 'float32'}
                atomic_json(HERE / 'staging/world_v2/object_info.json', schema)
                provenance['object_info_sha256'] = models.digest(HERE / 'staging/world_v2/object_info.json')
                for name in names:
                    for _ in range(count):
                        create_candidate(job, assets[name], config, base, schema, executable,
                                         model_dir, provenance, art_ref, progress)
                progress.update('AWAITING_ART_APPROVAL', 'Requested candidates are ready in the library. No art promoted.', state='COMPLETE')
            except BaseException as exc:
                # Explicit failure/blocked state instead of an idle page implying nonexistent art.
                message = str(exc)
                code = message.split(':')[0]
                if not code.replace('_','').isalnum() or len(code)>100:
                    code = type(exc).__name__
                progress.update('BLOCKED' if code.endswith('REQUIRED') else 'FAILED',
                                code, state='FAILED')
                raise
    finally:
        lock.unlink(missing_ok=True)
