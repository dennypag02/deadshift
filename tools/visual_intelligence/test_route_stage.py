import json
import tempfile
import unittest
from pathlib import Path
from route_stage import route


class StageRouterTests(unittest.TestCase):
    def test_missing_evidence_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(route(Path(d), "success", "success")["state"], "BLOCKED")

    def test_successful_diagnostic_requires_labels(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "summary.json").write_text(json.dumps({
                "processed": 1, "passed": 1, "failed": 0}), encoding="utf-8")
            result = route(root, "success", "success")
            self.assertEqual(result["state"], "REVIEW_UNQUALIFIED")
            self.assertEqual(result["next_action"], "collect_reviewed_labels")

    def test_failed_scoring_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "summary.json").write_text(json.dumps({
                "processed": 1, "passed": 1, "failed": 0}), encoding="utf-8")
            self.assertEqual(route(root, "success", "failure")["state"], "BLOCKED")

    def test_partial_batch_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "summary.json").write_text(json.dumps({
                "processed": 2, "passed": 1, "failed": 1}), encoding="utf-8")
            self.assertEqual(route(root, "success", "success")["state"], "BLOCKED")


if __name__ == "__main__":
    unittest.main()
