"""Offline world intake tests. No ComfyUI, model install, art write or job enqueue."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import world_batch as world

GAME = next((p for p in (world.HERE.parent / '_game_reference/godot/scripts/outskirts.gd',
                        world.HERE.parent / 'game_reference/outskirts.gd') if p.exists()), None)


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.base = world.load_yaml(world.HERE / 'tests/fixtures/assets_oct15.yaml')
        self.request = world.load_yaml(world.REQUEST)
        self.geometry = {'assets': {}}

    def test_counts_and_unique_names(self):
        merged, report = world.merge_proposal(self.base, self.request, self.geometry)
        self.assertEqual((report['requested_assets'], report['new_assets'], report['planned_new_candidates']), (34, 17, 68))
        self.assertEqual(report['new_by_category'], {'debris': 9, 'decals': 6, 'textures': 2})
        self.assertEqual(len(merged['assets']), 100)
        self.assertEqual(len({a['name'] for a in merged['assets']}), 100)

    def test_existing_entries_and_inputs_unchanged(self):
        original_base, original_request = copy.deepcopy(self.base), copy.deepcopy(self.request)
        merged, report = world.merge_proposal(self.base, self.request, self.geometry)
        self.assertEqual(self.base, original_base)
        self.assertEqual(self.request, original_request)
        self.assertEqual(merged['assets'][:len(self.base['assets'])], self.base['assets'])
        self.assertEqual(len(report['skipped_duplicate_names']), 17)
        for name, settings in self.base['categories'].items():
            self.assertEqual(merged['categories'][name], settings)

    def test_existing_textures_do_not_silently_migrate(self):
        merged, report = world.merge_proposal(self.base, self.request, self.geometry)
        asphalt = next(a for a in merged['assets'] if a['name'] == 'tex_asphalt')
        self.assertEqual(asphalt['category'], 'terrain')
        self.assertEqual(asphalt['target'], {'width': 128, 'height': 128})
        self.assertTrue(any(x['name'] == 'tex_asphalt' and 'category' in x['differences'] for x in report['duplicate_differences']))

    def test_texture_is_not_scene(self):
        merged, _ = world.merge_proposal(self.base, self.request, self.geometry)
        self.assertEqual(merged['categories']['textures']['workflow'], 'texture')
        self.assertIs(merged['categories']['textures']['tileable'], True)

    def test_no_generation_or_promotion_claim(self):
        _, report = world.merge_proposal(self.base, self.request, self.geometry)
        self.assertEqual(report['generation_state'], 'BLOCKED_PREFLIGHT')
        self.assertEqual(report['images_queued'], 0)
        self.assertEqual(report['promoted_assets'], 0)
        self.assertFalse(report['live_manifest_changed'])

    def test_existing_category_override_kept_and_reported(self):
        self.base['categories']['decals'] = copy.deepcopy(self.request['categories']['decals'])
        self.base['categories']['decals']['style'] = 'existing approved direction'
        merged, report = world.merge_proposal(self.base, self.request, self.geometry)
        self.assertEqual(report['category_conflicts_preserved'], ['decals'])
        self.assertEqual(merged['categories']['decals']['style'], 'existing approved direction')

    def test_duplicate_yaml_keys_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'bad.yaml'
            source.write_text('assets: []\nassets: []\n')
            with self.assertRaisesRegex(ValueError, 'Duplicate YAML key'):
                world.load_yaml(source)

    def test_invalid_assets_rejected(self):
        for field, value in [('name', '../escape'), ('category', 'unknown'), ('prompt', ''),
                             ('count', True), ('count', 0), ('size', [999, 1024]),
                             ('target', {'width': -1, 'height': 32})]:
            with self.subTest(field=field, value=value):
                modified = copy.deepcopy(self.request)
                modified['assets'][0][field] = value
                with self.assertRaises(ValueError):
                    world.validate(modified, self.base['categories'])

    def test_duplicate_asset_names_rejected(self):
        self.request['assets'].append(copy.deepcopy(self.request['assets'][0]))
        with self.assertRaisesRegex(ValueError, 'Duplicate asset name'):
            world.validate(self.request, self.base['categories'])

    def test_texture_requires_explicit_tiling(self):
        self.request['categories']['textures']['tileable'] = False
        with self.assertRaisesRegex(ValueError, 'tileable'):
            world.validate(self.request, self.base['categories'])

    def test_output_refuses_protected_paths(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            world.write_outputs(world.HERE / 'assets.yaml', {}, {})
        with self.assertRaisesRegex(ValueError, 'outside'):
            world.write_outputs(world.HERE.parent / 'godot/art/report.json', {}, {})

    def test_output_is_marked_proposal_and_no_overwrite(self):
        merged, report = world.merge_proposal(self.base, self.request, self.geometry)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'audit.json'
            world.write_outputs(path, merged, report)
            self.assertEqual(json.loads(path.read_text())['images_queued'], 0)
            proposal = path.with_name('assets_world_merge_PROPOSAL.yaml')
            before = proposal.read_bytes()
            self.assertTrue(before.startswith(b'# PROPOSAL ONLY'))
            with self.assertRaisesRegex(ValueError, 'overwrite'):
                world.write_outputs(path, {}, {})
            self.assertEqual(proposal.read_bytes(), before)


@unittest.skipUnless(GAME is not None, 'Pinned game checkout required for source geometry tests')
class GeometryTests(unittest.TestCase):
    def setUp(self):
        self.text = GAME.read_text(encoding='utf-8')
        self.geometry = world.measure_geometry(self.text)

    def test_all_twelve_dimensions(self):
        expected = {'out_diner': [896, 768], 'out_minimart': [1024, 512],
                    'out_motel_north': [1024, 384], 'out_motel_east': [384, 896],
                    'out_autoshop': [896, 768], 'out_canopy_roof': [1280, 1024],
                    'out_semi_trailer': [256, 896], 'out_pump_island': [256, 128],
                    'out_barrels': [256, 128], 'out_barrier': [128, 128],
                    'out_fence': [768, 128], 'out_tanker_wreck': [896, 384]}
        self.assertEqual({name: a['target_px'] for name, a in self.geometry['assets'].items()}, expected)
        self.assertEqual(self.geometry['tile_px'], 128)

    def test_collision_not_art_rectangle(self):
        self.assertEqual(self.geometry['assets']['out_canopy_roof']['placements'][0]['blocking_cells'], 8)
        self.assertEqual(self.geometry['assets']['out_tanker_wreck']['placements'][0]['blocking_cells'], 0)

    def test_alignment_issues_preserved_not_fixed(self):
        issues = self.geometry['alignment_findings']
        self.assertEqual(len(issues), 2)
        self.assertEqual(issues[0]['render_tile_origin'], [27, 22])
        self.assertEqual(issues[0]['collision_tile_origin'], [28, 22])
        self.assertEqual(issues[1]['render_tile_origin'], [23, 2])
        self.assertEqual(issues[1]['collision_tile_origin'], [22, 2])

    def test_readonly_audit_request_hash(self):
        paths = [world.REQUEST, world.HERE / 'tests/fixtures/assets_oct15.yaml', GAME]
        before = [p.read_bytes() for p in paths]
        merged, report = world.build_report(GAME, assets_path=world.HERE / 'tests/fixtures/assets_oct15.yaml')
        self.assertEqual(report['source']['request_sha256'], 'a97a1eb034ae2db0463912f9915344f774dcb24f90adc26dbe76b117f2928e04')
        self.assertEqual(report['source']['audited_gameplay_commit'], world.GAMEPLAY_SHA)
        self.assertEqual(report['target_changes_from_source'], [])
        self.assertEqual([p.read_bytes() for p in paths], before)

    def test_changed_geometry_updates_proposal_not_input(self):
        request = world.load_yaml(world.REQUEST)
        base = {'categories': world.load_yaml(world.HERE / 'tests/fixtures/assets_oct15.yaml')['categories'], 'assets': []}
        original = copy.deepcopy(request)
        text = self.text.replace('_tiles_rect(1, 8, 7, 6)', '_tiles_rect(1, 8, 7, 5)')
        merged, report = world.merge_proposal(base, request, world.measure_geometry(text))
        diner = next(a for a in merged['assets'] if a['name'] == 'out_diner')
        self.assertEqual(diner['target'], {'width': 896, 'height': 640})
        self.assertEqual(len(report['target_changes_from_source']), 1)
        self.assertEqual(request, original)

    def test_missing_geometry_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'Footprint not found'):
            world.measure_geometry(self.text.replace('OUT_DINER_ART, _tiles_rect', 'OTHER_DINER, _tiles_rect'))


if __name__ == '__main__':
    unittest.main()
