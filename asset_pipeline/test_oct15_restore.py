"""Verify the restored production route, without contacting ComfyUI or a PC."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest
import yaml
import generate

HERE=Path(__file__).resolve().parent

class ExactRestoreTests(unittest.TestCase):
    def test_nine_production_files_match_oct15_git_blobs(self):
        expected=json.loads((HERE/'tests/fixtures/oct15_source_hashes.json').read_text())
        for name,sha in expected.items():
            data=(HERE/name).read_bytes()
            actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
            with self.subTest(name=name):self.assertEqual(actual,sha)

    def test_old_manifest_entries_and_categories_unchanged(self):
        old=yaml.safe_load((HERE/'tests/fixtures/assets_oct15.yaml').read_text())
        current=generate.load_config()
        self.assertEqual(current['assets'][:len(old['assets'])],old['assets'])
        self.assertEqual(len(current['assets']),98)
        for name,settings in old['categories'].items():
            self.assertEqual(current['categories'][name],settings)
        self.assertEqual(set(current['categories'])-set(old['categories']),{'decals'})

    def test_historical_oct15_jobs_remain_frozen(self):
        paths=sorted((HERE/'jobs/planned/oct15-world').glob('*.yaml'))
        actual=[]
        for path in paths:
            job=yaml.safe_load(path.read_text())
            self.assertEqual(set(job),{'job_id','asset','category','positive','negative','count'})
            self.assertEqual(job['count'],4)
            self.assertEqual(job['job_id'],path.stem)
            self.assertIn('red',[x.strip() for x in job['negative'].split(',')])
            actual.append(job['asset'])
        self.assertEqual(len(paths),27)
        self.assertEqual(len(set(actual)),27)
        self.assertEqual(yaml.safe_load(paths[0].read_text())['asset'],'obj_generator')
        rejected={'out_diner','out_minimart','out_motel_north','out_motel_east','out_autoshop','out_canopy_roof'}
        self.assertTrue(rejected.issubset(set(actual)))
        self.assertFalse(any(name.startswith('roof_') for name in actual))

    def test_each_original_cli_job_dry_run(self):
        for path in sorted((HERE/'jobs/planned/oct15-world').glob('*.yaml')):
            result=subprocess.run([sys.executable,str(HERE/'generate.py'),'--job-file',str(path),'--dry-run'],
                                  cwd=HERE,capture_output=True,text=True,timeout=20)
            with self.subTest(job=path.stem):
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertEqual(result.stdout.count(' seed='),4)
                self.assertIn('nothing was queued',result.stdout)

    def test_alternate_jobs_archived_not_reinterpreted(self):
        for path in (HERE/'jobs/queued').glob('*.yaml'):
            job=yaml.safe_load(path.read_text())
            self.assertNotEqual(job.get('pipeline'),'world_v2')
        self.assertEqual(len(list((HERE/'jobs/archive/world-v2-abandoned').glob('*.yaml'))),2)
        self.assertNotIn('world_v2',(HERE/'generate.py').read_text())

    def test_texture_request_is_preserved_not_disguised_as_scene(self):
        request=yaml.safe_load((HERE/'batches/assets_batch_world.yaml').read_text())
        textures=[a for a in request['assets'] if a['category']=='textures']
        self.assertEqual(len(textures),11)
        self.assertEqual(request['categories']['textures']['workflow'],'texture')
        self.assertNotIn('textures',generate.load_config()['categories'])

if __name__=='__main__':unittest.main()
