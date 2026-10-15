"""Offline tests: only curated JSON is pushed, failures can retry."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import curation_sync


class Result:
    def __init__(self, returncode=0):
        self.returncode = returncode
        self.stdout = "A  asset_pipeline/submitted_curations/curation-" + "a"*24 + ".json"
        self.stderr = "push failed" if returncode else ""


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.src = root / "asset_pipeline" / "curation_submissions"
        self.dst = root / "asset_pipeline" / "submitted_curations"
        self.src.mkdir(parents=True)
        self.name = "curation-" + "a"*24
        (self.src / (self.name + ".json")).write_text(json.dumps({
            "submission_id": self.name, "status": "curated_not_promoted",
            "project_id": "deadshift", "scope_id": "general", "candidates": []
        }))
        for obj, attr, val in [(curation_sync, "DEST", self.dst),
                               (curation_sync, "REPO", root),
                               (curation_sync.project_library, "SUBMISSIONS", self.src)]:
            p = patch.object(obj, attr, val)
            p.start()
            self.addCleanup(p.stop)

    def test_publish_json_only(self):
        commands = []
        def run(args, cwd):
            commands.append(args)
            return Result()
        self.assertEqual(curation_sync.publish(run, "feature/asset-pipeline-step1")["published"], 1)
        self.assertEqual(len(list(self.dst.glob("*.json"))), 1)
        self.assertEqual(len(list(self.dst.glob("*.png"))), 0)
        self.assertTrue(any(args[:2] == ["git", "push"] for args in commands))

    def test_failed_push_retries(self):
        def fail(args, cwd):
            return Result(1) if args[:2] == ["git", "push"] else Result()
        with self.assertRaises(RuntimeError):
            curation_sync.publish(fail, "feature/asset-pipeline-step1")
        calls = []
        def succeed(args, cwd):
            calls.append(args)
            return Result()
        self.assertEqual(curation_sync.publish(succeed, "feature/asset-pipeline-step1")["published"], 0)
        self.assertTrue(any(args[:2] == ["git", "push"] for args in calls))


if __name__ == "__main__":
    unittest.main()
