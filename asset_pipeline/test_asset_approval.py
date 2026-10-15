"""Offline tests for local asset approval actions."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import asset_approval as a


class ApprovalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.here = root / "asset_pipeline"
        self.here.mkdir()
        (self.here / "staging" / "candidates" / "characters").mkdir(parents=True)
        (self.here / "staging" / "candidates" / "characters" / "zombie.png").write_bytes(b"PNG")
        (self.here / "manifest.json").write_text(json.dumps([{
            "asset": "zombie", "category": "characters", "seed": 123,
            "version": 1, "version_label": "v01",
            "candidate_path": "staging/candidates/characters/zombie.png",
        }]))
        (self.here / "assets.yaml").write_text("""categories:
  characters:
    style: stylized
    negative: blurry
assets:
  - name: zombie
    category: characters
    prompt: zombie standing
""")
        self.patches = [
            patch.object(a, "HERE", self.here),
            patch.object(a, "ROOT", root),
            patch.object(a, "MANIFEST", self.here / "manifest.json"),
            patch.object(a, "SELECTIONS", self.here / "asset_selections.json"),
            patch.object(a, "APPROVALS", self.here / "asset_approvals.json"),
            patch.object(a, "QUEUE", self.here / "jobs" / "queued"),
            patch.object(a, "PROMOTIONS", self.here / "jobs" / "promote"),
        ]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def test_selection_does_not_promote(self):
        self.assertIn("Saved selection", a.action({"asset": ["zombie"], "seed": ["123"], "action": ["select"]}))
        self.assertFalse(a.PROMOTIONS.exists())

    def test_approve_queues_non_overwrite(self):
        self.assertIn("Promotion queued", a.action({"asset": ["zombie"], "seed": ["123"], "action": ["approve"]}))
        jobs = list(a.PROMOTIONS.glob("*.yaml"))
        self.assertEqual(len(jobs), 1)
        import yaml
        self.assertFalse(yaml.safe_load(jobs[0].read_text())["overwrite"])
        with self.assertRaises(ValueError):
            a.action({"asset": ["zombie"], "seed": ["123"], "action": ["approve"]})

    def test_existing_art_is_protected(self):
        target = a.ROOT / "godot" / "art" / "characters" / "zombie.png"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"original")
        with self.assertRaisesRegex(ValueError, "already exists"):
            a.action({"asset": ["zombie"], "seed": ["123"], "action": ["approve"]})
        self.assertEqual(target.read_bytes(), b"original")

    def test_regenerate_queues_four(self):
        self.assertIn("Queued four", a.action({"asset": ["zombie"], "action": ["regenerate"]}))
        import yaml
        job = yaml.safe_load(next(a.QUEUE.glob("*.yaml")).read_text())
        self.assertEqual(job["count"], 4)
        self.assertEqual(job["asset"], "zombie")

    def test_invalid_seed(self):
        with self.assertRaises(ValueError):
            a.action({"asset": ["zombie"], "seed": ["999"], "action": ["approve"]})


if __name__ == "__main__":
    unittest.main()
