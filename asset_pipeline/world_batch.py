#!/usr/bin/env python3
"""Offline Outskirts v2 preflight. Never queues jobs or changes live assets.yaml.

The prepared manifest is a merge proposal, NOT input to the legacy generator.
Source-derived geometry is reported separately from on-device validation.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

import yaml

HERE = Path(__file__).resolve().parent
REQUEST = HERE / 'batches' / 'assets_batch_world.yaml'
GAMEPLAY_SHA = '20f06d229591417315ce8506779541da527cb3f1'
GAME_SOURCE_SHA256 = '23acf038ca5a9bade4960f173f3df126c695f0258e54cc26a100774b14b66d3e'
SYMBOLS = {
    'out_diner': 'OUT_DINER_ART', 'out_minimart': 'OUT_MINIMART_ART',
    'out_motel_north': 'OUT_MOTEL_N_ART', 'out_motel_east': 'OUT_MOTEL_E_ART',
    'out_autoshop': 'OUT_AUTOSHOP_ART', 'out_canopy_roof': 'OUT_CANOPY_ART',
    'out_semi_trailer': 'OUT_SEMI_ART', 'out_pump_island': 'OUT_PUMP_ART',
    'out_barrels': 'OUT_BARRELS_ART', 'out_barrier': 'OUT_BARRIER_ART',
    'out_fence': 'OUT_FENCE_ART', 'out_tanker_wreck': 'OUT_TANKER_ART',
}


class UniqueLoader(yaml.SafeLoader):
    """Reject duplicate keys rather than silently discarding input."""


def unique_mapping(loader: UniqueLoader, node: Any, deep: bool = False) -> dict:
    result: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f'Duplicate YAML key: {key}')
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def load_yaml(path: Path) -> dict:
    result = yaml.load(path.read_text(encoding='utf-8'), Loader=UniqueLoader)
    if not isinstance(result, dict):
        raise ValueError(f'{path.name} must contain a YAML mapping')
    return result


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_target(target: Any) -> None:
    if not isinstance(target, dict) or set(target) not in ({'long_side'}, {'width', 'height'}):
        raise ValueError('Target must have long_side or width and height')
    if any(type(value) is not int or value < 1 for value in target.values()):
        raise ValueError('Target dimensions must be positive integers')


def validate(config: dict, inherited: dict | None = None) -> None:
    categories = dict(inherited or {})
    if not isinstance(config.get('categories'), dict) or not isinstance(config.get('assets'), list):
        raise ValueError('Expected categories mapping and assets list')
    categories.update(config['categories'])
    for category, settings in categories.items():
        if not isinstance(settings, dict) or settings.get('workflow') not in ('sprite', 'scene', 'texture'):
            raise ValueError(f'Unsupported workflow: {category}')
        size = settings.get('size')
        if not isinstance(size, list) or len(size) != 2 or any(type(v) is not int or v < 1 or v % 8 for v in size):
            raise ValueError(f'Invalid generation size: {category}')
        check_target(settings.get('target'))
        if type(settings.get('count')) is not int or settings['count'] < 1:
            raise ValueError(f'Invalid count: {category}')
        if settings['workflow'] == 'texture' and settings.get('tileable') is not True:
            raise ValueError('Texture workflow requires tileable: true')
        for field in ('style', 'negative'):
            if not isinstance(settings.get(field), str):
                raise ValueError(f'Missing {field}: {category}')
    seen: set[str] = set()
    for asset in config['assets']:
        if not isinstance(asset, dict):
            raise ValueError('Asset must be a mapping')
        name = asset.get('name')
        if not isinstance(name, str) or not re.fullmatch(r'[a-z][a-z0-9_]*', name):
            raise ValueError(f'Invalid asset name: {name}')
        if name in seen:
            raise ValueError(f'Duplicate asset name: {name}')
        seen.add(name)
        if asset.get('category') not in categories:
            raise ValueError(f'Unknown category: {name}')
        if not isinstance(asset.get('prompt'), str) or not asset['prompt'].strip():
            raise ValueError(f'Missing prompt: {name}')
        check_target(asset.get('target', categories[asset['category']]['target']))
        if 'size' in asset and (not isinstance(asset['size'], list) or len(asset['size']) != 2 or any(type(v) is not int or v < 1 or v % 8 for v in asset['size'])):
            raise ValueError(f'Invalid generation size: {name}')
        if 'count' in asset and (type(asset['count']) is not int or asset['count'] < 1):
            raise ValueError(f'Invalid count: {name}')


def function_body(text: str, name: str) -> str:
    found = re.search(r'^func ' + re.escape(name) + r'\([^\n]*\n(.*?)(?=^func |\Z)', text, re.M | re.S)
    if not found:
        raise ValueError(f'Cannot audit missing function: {name}')
    return found.group(1)


def blocker_components(rows: list[str], kind: str) -> list[set[tuple[int, int]]]:
    pending = {(x, y) for y, row in enumerate(rows) for x, char in enumerate(row) if char == kind}
    components = []
    while pending:
        start = min(pending)
        pending.remove(start)
        found, frontier = {start}, [start]
        while frontier:
            x, y = frontier.pop()
            for adjacent in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if adjacent in pending:
                    pending.remove(adjacent)
                    found.add(adjacent)
                    frontier.append(adjacent)
        components.append(found)
    return components


def measure_geometry(text: str) -> dict:
    """Read render rectangles and static collision cells; do not execute game code."""
    tile_match = re.search(r'^const TILE\s*:?=\s*([\d.]+)', text, re.M)
    rows_match = re.search(r'const MAP_ROWS[^=]*=\s*\[(.*?)\n\]', text, re.S)
    block_match = re.search(r'const BLOCKING_CHARS\s*:?=\s*"([^"]+)"', text)
    if not tile_match or not rows_match or not block_match:
        raise ValueError('Missing TILE, MAP_ROWS or BLOCKING_CHARS')
    tile_value = float(tile_match.group(1))
    if not tile_value.is_integer() or tile_value <= 0:
        raise ValueError('Tile pixel size must be a positive integer')
    tile = int(tile_value)
    rows = re.findall(r'"([^"]*)"', rows_match.group(1))
    blocking = block_match.group(1)
    body = function_body(text, '_draw_map_art')
    loop_sites: list[tuple[int, int]] = []
    data: dict = {}
    loop_text = ''
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith('for p in ['):
            loop_text = stripped
        elif loop_text and ']' not in loop_text:
            loop_text += stripped
        if loop_text and ']' in loop_text:
            loop_sites = [(int(x), int(y)) for x, y in re.findall(r'Vector2i\(\s*(\d+)\s*,\s*(\d+)\s*\)', loop_text)]
            loop_text = ''
        match = re.search(r'_draw_art_rect\((OUT_[A-Z_]+),\s*_tiles_rect\(([^)]+)\)', line)
        if not match:
            continue
        symbol, arguments = match.groups()
        arguments = [part.strip() for part in arguments.split(',')]
        if len(arguments) != 4 or not all(v.isdigit() for v in arguments[2:]):
            raise ValueError(f'Unrecognized render geometry for {symbol}')
        width, height = map(int, arguments[2:])
        sites = loop_sites if arguments[:2] == ['p.x', 'p.y'] else [tuple(map(int, arguments[:2]))]
        if not sites:
            raise ValueError(f'No placement sites for {symbol}')
        current = data.setdefault(symbol, {'footprint_tiles': [width, height], 'target_px': [width * tile, height * tile], 'placements': []})
        if current['footprint_tiles'] != [width, height]:
            raise ValueError(f'Multiple incompatible sizes for {symbol}')
        for x, y in sites:
            if y < 0 or y + height > len(rows):
                raise ValueError(f'Render rectangle outside MAP_ROWS for {symbol}')
            cells = []
            # Godot substr past a short row yields an empty string: not a blocker.
            for yy in range(y, y + height):
                cells.append(''.join(rows[yy][xx:xx + 1] if rows[yy][xx:xx + 1] in blocking and rows[yy][xx:xx + 1] else '.' for xx in range(x, x + width)))
            current['placements'].append({'tile_origin': [x, y], 'static_collision_mask': cells, 'blocking_cells': sum(ch != '.' for row in cells for ch in row)})
    result = {}
    for name, symbol in SYMBOLS.items():
        if symbol not in data:
            raise ValueError(f'Footprint not found: {name}')
        result[name] = data[symbol]
        result[name]['source_symbol'] = symbol
    alignment = []
    for name, kind in (('out_semi_trailer', 'T'), ('out_fence', 'F')):
        for placement in result[name]['placements']:
            x, y = placement['tile_origin']
            width, height = result[name]['footprint_tiles']
            rendered = {(xx, yy) for xx in range(x, x + width) for yy in range(y, y + height)}
            candidates = blocker_components(rows, kind)
            if not candidates:
                raise ValueError(f'Missing collision component for {name}')
            closest = max(candidates, key=lambda cells: len(rendered & cells))
            origin = [min(xx for xx, _ in closest), min(yy for _, yy in closest)]
            extent = [max(xx for xx, _ in closest) - origin[0] + 1, max(yy for _, yy in closest) - origin[1] + 1]
            if closest != rendered:
                alignment.append({'name': name, 'render_tile_origin': [x, y],
                                  'collision_tile_origin': origin, 'collision_bbox_tiles': extent,
                                  'action': 'Review sprite placement at integration; do not move collision or stretch art'})
    return {'tile_px': tile, 'blocking_chars': blocking, 'assets': result, 'alignment_findings': alignment,
            'method': 'Source audit of _draw_map_art and MAP_ROWS, not an engine/device test',
            'notes': ['Canopy overlay is not a solid building; only underlying P cells block.',
                      'K tanker-event cells are not in BLOCKING_CHARS.',
                      'Fences use grid movement collision; bullets pass through.',
                      'Generated cars and cleared ground hazards are not new building collision.',
                      'Static masks are reported, not replaced by solid art rectangles.']}


def merge_proposal(base: dict, request: dict, geometry: dict) -> tuple[dict, dict]:
    validate(base)
    validate(request, base['categories'])
    merged = copy.deepcopy(base)
    existing = {item['name']: item for item in base['assets']}
    category_conflicts = []
    for name, settings in request['categories'].items():
        if name not in merged['categories']:
            merged['categories'][name] = copy.deepcopy(settings)
        elif settings != merged['categories'][name]:
            category_conflicts.append(name)
    new, skipped, changes, conflicts = [], [], [], []
    for item in request['assets']:
        name = item['name']
        proposed = copy.deepcopy(item)
        if name in geometry['assets']:
            pixels = geometry['assets'][name]['target_px']
            target = dict(zip(('width', 'height'), pixels))
            if proposed.get('target') != target:
                changes.append({'name': name, 'submitted': proposed.get('target'), 'measured': target})
                proposed['target'] = target
        if name in existing:
            skipped.append(name)
            saved = existing[name]
            saved_target = saved.get('target', base['categories'][saved['category']]['target'])
            proposed_target = proposed.get('target', merged['categories'][proposed['category']]['target'])
            differences = {key: {'existing': saved.get(key), 'submitted': proposed.get(key)} for key in ('category', 'prompt', 'seed_group') if saved.get(key) != proposed.get(key)}
            if saved_target != proposed_target:
                differences['target'] = {'existing': saved_target, 'submitted': proposed_target}
            if differences:
                conflicts.append({'name': name, 'preserved_existing': True, 'differences': differences})
        else:
            merged['assets'].append(proposed)
            new.append(proposed)
    validate(merged)
    counts = Counter(item['category'] for item in new)
    jobs = sum(item.get('count', merged['categories'][item['category']]['count']) for item in new)
    report = {'requested_assets': len(request['assets']), 'new_assets': len(new),
              'new_by_category': dict(sorted(counts.items())), 'planned_new_candidates': jobs,
              'existing_assets': len(base['assets']), 'proposed_total_assets': len(merged['assets']),
              'new_names': [item['name'] for item in new], 'skipped_duplicate_names': skipped,
              'category_conflicts_preserved': category_conflicts, 'duplicate_differences': conflicts,
              'target_changes_from_source': changes, 'geometry': geometry,
              'generation_state': 'BLOCKED_PREFLIGHT', 'images_queued': 0, 'promoted_assets': 0,
              'merge_state': 'PROPOSAL_ONLY', 'live_manifest_changed': False,
              'release_gates': [
                  'Verify locally installed, commercially permitted background removal; BRIA RMBG-2.0 free weights are not approved for this commercial pipeline.',
                  'Implement and validate texture offset/inpaint or circular-padding workflow; no alpha removal, plus 3x3 seam review at generation and final size.',
                  'Replace legacy fixed-width/height stretch with alpha trim, uniform scale and explicit pad/crop.',
                  'Capture each full submitted graph, model hashes, parameters, licenses and ComfyUI/custom-node versions.',
                  'Resolve the named OUTSKIRTS_ART_TARGET.png reference and bind related-asset references; seed_group is not visual consistency.',
                  'Inspect local worker readiness; no current PC heartbeat was available to this audit.',
                  'User candidate approval before promotion, then Godot validation, APK and phone review.'
              ]}
    return merged, report


def build_report(game_source: Path, request_path: Path = REQUEST, assets_path: Path = HERE / 'assets.yaml') -> tuple[dict, dict]:
    base = load_yaml(assets_path)
    request = load_yaml(request_path)
    merged, report = merge_proposal(base, request, measure_geometry(game_source.read_text(encoding='utf-8')))
    report['source'] = {'request_sha256': sha256(request_path), 'manifest_sha256': sha256(assets_path),
                        'game_source_sha256': sha256(game_source), 'audited_gameplay_commit': GAMEPLAY_SHA if sha256(game_source) == GAME_SOURCE_SHA256 else None}
    return merged, report


def write_outputs(path: Path, merged: dict, report: dict) -> None:
    """Only create a new report directory; refuse protected paths and overwrites."""
    path = path.resolve()
    repo = HERE.parent.resolve()
    for protected in (HERE.resolve(), (repo / 'godot').resolve()):
        if path == protected or protected in path.parents:
            raise ValueError('Reports must be outside asset_pipeline and godot')
    proposed = path.with_name('assets_world_merge_PROPOSAL.yaml')
    if path == proposed or path.exists() or proposed.exists():
        raise ValueError('Refusing to overwrite an existing report or proposal')
    path.parent.mkdir(parents=True, exist_ok=True)
    with proposed.open('x', encoding='utf-8') as output:
        output.write('# PROPOSAL ONLY. NOT COMPATIBLE WITH THE LEGACY GENERATOR.\n')
        output.write('# Resolve world-audit release_gates before applying. No jobs are queued.\n')
        yaml.safe_dump(merged, output, sort_keys=False, allow_unicode=True)
    with path.open('x', encoding='utf-8') as output:
        json.dump(report, output, indent=2)
        output.write('\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', required=True)
    parser.add_argument('--game-source', type=Path, required=True)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    print('RUNNING scope=offline_world_preflight images_queued=0', flush=True)
    merged, report = build_report(args.game_source)
    for key in ('requested_assets', 'new_assets', 'new_by_category', 'planned_new_candidates', 'skipped_duplicate_names', 'target_changes_from_source'):
        print(f'{key}: {json.dumps(report[key])}')
    print('Building/structure render sizes and static collision masks audited: 12')
    print('alignment_findings: ' + json.dumps(report['geometry']['alignment_findings']))
    for gate in report['release_gates']:
        print('HELD: ' + gate)
    if args.report:
        write_outputs(args.report, merged, report)
    print('COMPLETE scope=offline_world_preflight generation=BLOCKED_PREFLIGHT promotion=NOT_STARTED', flush=True)


if __name__ == '__main__':
    main()
