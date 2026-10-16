"""Offline tests: no images generated, no model installed, no network required."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image, ImageDraw
from world_v2 import images, models, runner, progress


class ImageTests(unittest.TestCase):
    def test_landscape_sprite_uniform_fit(self):
        source = Image.new('RGBA', (200, 100), (0,0,0,0))
        ImageDraw.Draw(source).rectangle((20,30,179,69), fill=(50,60,70,255))
        result = images.fit(source, (256,128))
        self.assertEqual(result.size, (256,128))
        self.assertEqual(result.getchannel('A').getbbox(), (0,32,256,96))

    def test_portrait_sprite_uniform_fit(self):
        result = images.fit(Image.new('RGBA',(40,160),(1,2,3,255)), (128,128))
        self.assertEqual(result.getchannel('A').getbbox(), (48,0,80,128))

    def test_empty_alpha_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Empty'):
            images.fit(Image.new('RGBA',(10,10)), (32,32))

    def test_exact_long_side_canvas(self):
        self.assertEqual(images.dimensions({'long_side':160}), (160,160))

    def test_crop_is_explicit(self):
        source = Image.new('RGBA',(160,80),(1,2,3,255))
        self.assertEqual(images.fit(source,(64,64),mode='crop').size, (64,64))
        with self.assertRaises(ValueError):
            images.fit(source,(64,64),mode='stretch')

    def test_mask_is_explicit_not_texture_alpha_removal(self):
        source = Image.new('RGB',(256,256),(10,20,30))
        prepared = images.prepare_inpaint(source, band=16)
        self.assertEqual(prepared.getpixel((128,128))[3], 0)
        self.assertEqual(prepared.getpixel((10,10))[3], 255)

    def test_wrap_and_final_grid(self):
        source = Image.new('RGB',(32,32))
        for y in range(32):
            for x in range(32):
                source.putpixel((x,y),(x*7,y*7,(x+y)*3))
        result = images.periodic_edges(source,band=4)
        images.validate_wrap(result)
        self.assertEqual(result.mode,'RGB')
        self.assertEqual(images.grid3(result).size,(96,96))
        self.assertEqual(images.periodic_edges(source,band=4).tobytes(), result.tobytes())
        self.assertNotEqual(source.tobytes(), result.tobytes())

    def test_bad_wrap_rejected(self):
        source=Image.new('RGB',(16,16))
        source.putpixel((0,0),(255,255,255))
        with self.assertRaises(ValueError):
            images.validate_wrap(source)


class ModelTests(unittest.TestCase):
    def test_official_pin_not_bria_or_mirror(self):
        self.assertEqual(models.MODEL_REPO,'ZhengPeng7/BiRefNet')
        self.assertEqual(len(models.REVISION),40)
        self.assertEqual(len(models.WEIGHTS_SHA256),64)
        self.assertEqual(models.LICENSES[models.MODEL_REPO]['license'],'MIT')

    def test_existing_verified_model_not_downloaded_or_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            for name in models.MODEL_FILES:
                (folder/name).write_bytes(b'fixture-'+name.encode())
            expected=models.digest(folder/'model.safetensors')
            before={p.name:p.read_bytes() for p in folder.iterdir()}
            with patch.object(models,'WEIGHTS_SHA256',expected), patch.object(models.requests,'get') as get:
                result=models.install(folder,[])
                models.install(folder,[])
            get.assert_not_called()
            self.assertEqual(result['new_files'],[])
            for name,value in before.items():
                self.assertEqual((folder/name).read_bytes(),value)

    def test_wrong_existing_weight_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            for name in models.MODEL_FILES:
                (folder/name).write_bytes(b'invalid')
            with patch.object(models.requests,'get') as get:
                with self.assertRaisesRegex(RuntimeError,'EXISTING_MODEL_CHECKSUM_MISMATCH'):
                    models.install(folder,[])
            get.assert_not_called()
            self.assertEqual((folder/'model.safetensors').read_bytes(),b'invalid')

    def test_cache_reused_before_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'destination';folder.mkdir()
            cache=Path(tmp)/'cache';cache.mkdir()
            (cache/'model.safetensors').write_bytes(b'cached official weights fixture')
            for name in models.MODEL_FILES:
                if name != 'model.safetensors': (folder/name).write_bytes(b'support')
            expected=models.digest(cache/'model.safetensors')
            with patch.object(models,'WEIGHTS_SHA256',expected), patch.object(models.requests,'get') as get:
                result=models.install(folder,[cache])
            get.assert_not_called()
            self.assertEqual(result['files']['model.safetensors'],expected)

    def test_tampered_support_file_rejected_after_install(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            for name in models.MODEL_FILES: (folder/name).write_bytes(name.encode())
            expected=models.digest(folder/'model.safetensors')
            with patch.object(models,'WEIGHTS_SHA256',expected):
                models.install(folder,[])
                (folder/'birefnet.py').write_text('changed')
                with self.assertRaisesRegex(RuntimeError,'FILES_CHANGED'):
                    models.install(folder,[])


class RunnerTests(unittest.TestCase):
    def test_full_world_scope_duplicate_names_are_not_done_assets(self):
        config, assets, report=runner.definitions()
        self.assertEqual(len(assets),34)
        self.assertEqual(len(config['assets']),100)
        self.assertEqual(len(report['skipped_duplicate_names']),32)
        self.assertEqual(assets['tex_asphalt']['category'],'terrain')
        self.assertEqual(assets['tex_asphalt']['target'],{'width':128,'height':128})
        self.assertEqual(assets['tex_grass']['category'],'textures')

    def test_offline_dry_run_never_contacts_comfy_or_installs(self):
        with patch.object(models,'install') as install, patch.object(runner.requests,'post') as post:
            runner.run({'world_assets':['obj_generator'],'count':4},dry_run=True)
        install.assert_not_called();post.assert_not_called()

    def test_invalid_names_count_rejected(self):
        for names,count in [(['../escape'],4),(['obj_generator']*2,4),([],4),(['obj_generator'],True),(['obj_generator'],5)]:
            with self.subTest(names=names,count=count):
                with self.assertRaises(ValueError):
                    runner.run({'world_assets':names,'count':count},dry_run=True)

    def test_missing_reference_is_not_invented(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError,'ART_REFERENCE_REQUIRED'):
                runner.reference_file(Path(tmp),{})

    def test_reference_bound_to_actual_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            here=Path(tmp)
            target=here/'OUTSKIRTS_ART_TARGET.png'
            Image.new('RGB',(20,20)).save(target)
            self.assertEqual(runner.reference_file(here,{}),target)

    def test_no_implicit_family_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError,'APPROVAL_REQUIRED'):
                runner.approved_reference(Path(tmp),'out_diner')

    def test_core_graph_only_with_full_sampler(self):
        config,assets,_=runner.definitions()
        asset=assets['obj_generator'];category=config['categories'][asset['category']]
        graph=runner.graph_for(asset,category,123,'fixture')
        self.assertEqual(graph['5']['inputs']['seed'],123)
        self.assertEqual(graph['4']['inputs']['batch_size'],1)
        self.assertEqual(graph['5']['inputs']['steps'],30)
        self.assertFalse(any('RMBG' in n['class_type'] for n in graph.values()))
        self.assertIn('red', graph['3']['inputs']['text'])

    def test_texture_inpaint_graph_has_mask_not_rmbg(self):
        config,assets,_=runner.definitions()
        asset=assets['tex_grass']
        graph=runner.graph_for(asset,config['categories']['textures'],123,'fixture','offset.png',True)
        self.assertEqual(graph['9']['class_type'],'VAEEncodeForInpaint')
        self.assertEqual(graph['9']['inputs']['mask'],['8',1])
        self.assertNotIn('4',graph)

    def test_unknown_schema_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'NODE_MISSING'):
            runner.validate_graph({'1':{'class_type':'Missing','inputs':{}}},{})

    def test_new_upload_allowed_after_schema_snapshot(self):
        runner.validate_graph({'1':{'class_type':'LoadImage','inputs':{'image':'new.png'}}},
                              {'LoadImage':{'input':{'required':{'image':[['old.png']]}}}})

    def test_existing_worker_can_read_v2_envelope(self):
        import local_worker
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'world-job.yaml'
            path.write_text('job_id: fixture\nasset: obj_generator\ncategory: debris\npositive: world_v2\nnegative: red\ncount: 4\npipeline: world_v2\nworld_assets: [obj_generator]\n')
            self.assertEqual(local_worker.read_job(path)['pipeline'],'world_v2')


class ProgressTests(unittest.TestCase):
    def test_identity_boundary(self):
        with patch.object(progress,'git',return_value='https://github.com/dpaganelli-xpodigital/work.git'):
            with self.assertRaisesRegex(RuntimeError,'PERSONAL_REPOSITORY_REQUIRED'):
                progress.publish(Path('.'),{})

    def test_metadata_branch_does_not_change_checkout_or_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); remote=root/'remote.git';repo=root/'repo';repo.mkdir()
            subprocess.run(['git','init','--bare',str(remote)],check=True,capture_output=True)
            def git(*args):
                return progress.git(repo,*args)
            git('init');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid')
            git('remote','add','origin',str(remote))
            (repo/'base.txt').write_text('base')
            git('add','base.txt');git('commit','-m','fixture')
            (repo/'unrelated.txt').write_text('unrelated staged user work')
            git('add','unrelated.txt')
            before=(git('rev-parse','HEAD'),git('status','--porcelain'),git('diff','--cached'))
            with patch.object(progress,'ALLOWED_ORIGINS',{str(remote)}):
                progress.publish(repo,{'state':'RUNNING','stage':'MODEL_SETUP'})
                progress.publish(repo,{'state':'COMPLETE','stage':'MODEL_READY'})
            self.assertEqual(before,(git('rev-parse','HEAD'),git('status','--porcelain'),git('diff','--cached')))
            content=subprocess.run(['git','--git-dir',str(remote),'show','automation/world-asset-progress:world_status.json'],
                                   capture_output=True,text=True,check=True).stdout
            self.assertEqual(json.loads(content)['stage'],'MODEL_READY')


if __name__ == '__main__':
    unittest.main()
