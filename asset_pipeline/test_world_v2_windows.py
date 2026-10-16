"""Regression coverage for the actual Windows worker's first execution failures."""
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from world_v2 import models, progress


class WindowsRuntimeTests(unittest.TestCase):
    def test_git_input_is_bytes_and_not_windows_text_translation(self):
        with patch.object(progress.subprocess, 'run', return_value=SimpleNamespace(stdout=b'tree-sha\n')) as run:
            result = progress.git(Path('.'), 'mktree', input='100644 blob abc\tworld_status.json\n')
        self.assertEqual(result, 'tree-sha')
        args, kwargs = run.call_args
        self.assertIsInstance(kwargs['input'], bytes)
        self.assertNotIn('text', kwargs)
        self.assertTrue(kwargs['input'].endswith(b'world_status.json\n'))
        self.assertNotIn(b'\r', kwargs['input'])

    def test_running_comfy_python_precedes_unrelated_system_python(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            executable = root / 'ComfyUI/.venv/Scripts/python.exe'
            versions = {key: 'fixture-version' for key in models.REQUIRED}
            module_file = root / 'asset_pipeline/world_v2/models.py'
            status = root / 'asset_pipeline/staging/world_v2'
            status.mkdir(parents=True)
            (status / 'execution.lock').write_text('job-fixture')
            roots = []
            with patch.object(models, '__file__', str(module_file)), patch.object(models, 'running_comfy_pythons', return_value=[executable]), patch.object(models, 'candidates_for_python', return_value=[Path('other-python')]), patch.object(models.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout=json.dumps(versions))) as run:
                selected, actual = models.select_python(roots)
            self.assertEqual(selected, executable)
            self.assertEqual(actual, versions)
            self.assertEqual(run.call_args[0][0][0], str(executable))
            self.assertIn(root / 'ComfyUI', roots)
            report = json.loads((status / 'runtime_checks.json').read_text())
            self.assertEqual(report['job_id'], 'job-fixture')
            self.assertEqual(report['selected'], 1)
            self.assertNotIn(str(executable), json.dumps(report))
            self.assertNotIn(str(root), json.dumps(report))

    def test_missing_packages_named_without_install(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            versions = {key: 'fixture-version' for key in models.REQUIRED}
            versions['timm'] = None
            with patch.object(models, '__file__', str(root / 'asset_pipeline/world_v2/models.py')), patch.object(models, 'running_comfy_pythons', return_value=[]), patch.object(models, 'candidates_for_python', return_value=[Path('fixture-python')]), patch.object(models.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout=json.dumps(versions))) as run:
                with self.assertRaisesRegex(RuntimeError, '^COMFY_PYTHON_MISSING_TIMM$'):
                    models.select_python([])
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args[0][0][1], '-c')
            self.assertNotIn('pip', run.call_args[0][0])
            report = json.loads((root / 'asset_pipeline/staging/world_v2/runtime_checks.json').read_text())
            self.assertEqual(report['checks'][0]['missing'], ['timm'])

    def test_process_query_returns_executable_only_and_filters_comfy(self):
        with tempfile.TemporaryDirectory() as tmp:
            executable = Path(tmp) / 'python.exe'
            executable.touch()
            with patch.object(models.sys, 'platform', 'win32'), patch.object(models.subprocess, 'run', return_value=SimpleNamespace(stdout=json.dumps(str(executable)))) as run:
                result = models.running_comfy_pythons()
            self.assertEqual(result, [executable])
            command = run.call_args[0][0][-1]
            self.assertIn('ComfyUI.*main[.]py', command)
            self.assertIn('Select-Object -ExpandProperty ExecutablePath', command)
            self.assertNotIn('Stop-Process', command)
            self.assertNotIn('pip', command)

    def test_process_lookup_failure_does_not_install_or_escalate(self):
        with patch.object(models.sys, 'platform', 'win32'), patch.object(models.subprocess, 'run', side_effect=OSError('fixture')) as run:
            self.assertEqual(models.running_comfy_pythons(), [])
        self.assertEqual(run.call_count, 1)
        self.assertNotIn('RunAs', str(run.call_args))


if __name__ == '__main__':
    unittest.main()
