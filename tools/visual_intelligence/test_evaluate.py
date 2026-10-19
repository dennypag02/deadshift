"""Unit tests for fail-closed visual defect scoring."""
import unittest
from evaluate import evaluate


class EvaluateTests(unittest.TestCase):
    def test_clean_control_false_positive(self):
        result = evaluate([{"id": "clean", "ground_truth": [], "predicted": ["fake_overlap"]}])
        self.assertEqual(result["fp"], 1)
        self.assertEqual(result["precision"], 0)

    def test_missed_critical_defect(self):
        result = evaluate([{"id": "defect", "ground_truth": ["xp_text_obstructed"], "predicted": []}])
        self.assertEqual(result["fn"], 1)
        self.assertEqual(result["recall"], 0)

    def test_perfect_detection(self):
        result = evaluate([{"id": "correct", "ground_truth": ["xp_text_obstructed"],
                            "predicted": ["xp_text_obstructed"]}])
        self.assertEqual(result["precision"], 1)
        self.assertEqual(result["recall"], 1)

    def test_no_defects_is_not_qualified_evidence(self):
        result = evaluate([{"id": "clean", "ground_truth": [], "predicted": []}])
        self.assertIsNone(result["precision"])
        self.assertIsNone(result["recall"])


if __name__ == "__main__":
    unittest.main()
