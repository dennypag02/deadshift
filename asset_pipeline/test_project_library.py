"""Offline acceptance tests for Phases A/B project folders and bulk curation."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import project_library as lib


class ProjectLibraryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.here = root / "asset_pipeline"
        folder = self.here / "staging" / "candidates" / "characters"
        folder.mkdir(parents=True)
        (folder / "zombie_v01.png").write_bytes(b"one")
        (folder / "zombie_v02.png").write_bytes(b"two")
        manifest = [
            {"asset": "zombie", "category": "characters", "seed": 42,
             "version": n, "version_label": "v0" + str(n), "job_id": "old",
             "candidate_path": "staging/candidates/characters/zombie_v0" + str(n) + ".png"}
            for n in (1, 2)
        ]
        (self.here / "manifest.json").write_text(json.dumps(manifest))
        (self.here / "projects" / "deadshift" / "general").mkdir(parents=True)
        (self.here / "projects" / "deadshift" / "levels" / "level-01").mkdir(parents=True)
        paths = {"HERE": self.here, "PROJECTS": self.here / "projects",
                 "MANIFEST": self.here / "manifest.json", "STATE": self.here / "curation_state.json",
                 "SUBMISSIONS": self.here / "curation_submissions",
                 "CANDIDATES": self.here / "staging" / "candidates"}
        for name, value in paths.items():
            patcher = patch.object(lib, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.original_manifest = (self.here / "manifest.json").read_bytes()

    def test_folders_and_legacy_catalog(self):
        self.assertEqual(lib.project_scopes()["deadshift"], ["general", "levels/level-01"])
        items = lib.catalog("deadshift", "general")["zombie"]
        self.assertEqual(len(items), 2)
        self.assertNotEqual(items[0]["candidate_id"], items[1]["candidate_id"])
        self.assertEqual(items[0]["candidate_id"], lib.catalog("deadshift", "general")["zombie"][0]["candidate_id"])

    def test_multi_keep_and_submit_non_destructive(self):
        ids = [item["candidate_id"] for item in lib.catalog("deadshift", "general")["zombie"]]
        self.assertEqual(lib.save_selection("deadshift", "general", ids)["kept"], 2)
        result = lib.submit_folder("deadshift", "general", ids)
        self.assertEqual(result["kept"], 2)
        record = json.loads(next(lib.SUBMISSIONS.glob("*.json")).read_text())
        self.assertEqual(record["status"], "curated_not_promoted")
        self.assertEqual(len(record["candidates"]), 2)
        self.assertEqual((self.here / "manifest.json").read_bytes(), self.original_manifest)
        self.assertFalse((self.here.parent / "godot").exists())

    def test_uncheck_all_keeps_archive(self):
        ids = [item["candidate_id"] for item in lib.catalog("deadshift", "general")["zombie"]]
        lib.save_selection("deadshift", "general", ids)
        lib.save_selection("deadshift", "general", [])
        self.assertEqual(lib.state()["folders"]["deadshift:general"]["kept_candidate_ids"], [])
        self.assertEqual(len(lib.catalog("deadshift", "general")["zombie"]), 2)

    def test_unknown_id_is_rejected_without_mutation(self):
        with self.assertRaisesRegex(ValueError, "unknown"):
            lib.save_selection("deadshift", "general", ["fake"])
        self.assertFalse(lib.STATE.exists())

    def test_no_cross_project_leak(self):
        (lib.PROJECTS / "other" / "general").mkdir(parents=True)
        self.assertEqual(lib.catalog("other", "general"), {})
        self.assertEqual(lib.catalog("deadshift", "levels/level-01"), {})

    def test_path_traversal_rejected(self):
        with self.assertRaises(ValueError):
            lib.catalog("../outside", "general")
        with self.assertRaises(ValueError):
            lib.catalog("deadshift", "levels/../other")


if __name__ == "__main__":
    unittest.main()
