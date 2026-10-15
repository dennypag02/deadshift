import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import curated_png_sync as sync


class PNGTransferTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        here = root / "asset_pipeline"
        source = here / "staging" / "candidates" / "icons"
        source.mkdir(parents=True)
        self.png = source / "sample.png"
        self.png.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 8 + (32).to_bytes(4, "big") + (32).to_bytes(4, "big"))
        records = here / "submitted_curations"
        records.mkdir()
        self.id = "curation-" + "a" * 24
        self.cid = "legacy-" + "b" * 24
        (records / (self.id + ".json")).write_text(json.dumps({
            "submission_id": self.id, "status": "curated_not_promoted",
            "candidates": [{"candidate_id": self.cid, "candidate_path": "staging/candidates/icons/sample.png"}]
        }))
        for obj, key, value in [
            (sync, "HERE", here), (sync, "REPO", root), (sync, "SUBMISSIONS", records),
            (sync, "TARGET", here / "submitted_artwork"),
            (sync.project_library, "CANDIDATES", here / "staging" / "candidates")
        ]:
            p = patch.object(obj, key, value)
            p.start()
            self.addCleanup(p.stop)

    def test_stages_and_retries_idempotently(self):
        paths = sync.stage_submissions()
        self.assertEqual(len(paths), 1)
        self.assertEqual(paths, sync.stage_submissions())
        self.assertEqual((sync.REPO / paths[0]).read_bytes(), self.png.read_bytes())

    def test_no_overwrite(self):
        sync.stage_submissions()
        self.png.write_bytes(self.png.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "collision"):
            sync.stage_submissions()

    def test_rejects_traversal(self):
        record = sync.SUBMISSIONS / (self.id + ".json")
        payload = json.loads(record.read_text())
        payload["candidates"][0]["candidate_path"] = "../../outside.png"
        record.write_text(json.dumps(payload))
        with self.assertRaisesRegex(ValueError, "source path"):
            sync.stage_submissions()


if __name__ == "__main__":
    unittest.main()
