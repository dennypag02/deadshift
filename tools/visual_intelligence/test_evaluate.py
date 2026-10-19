"""Unit tests for fail-closed visual defect scoring."""
import unittest
from evaluate import evaluate, validate_cases


class EvaluateTests(unittest.TestCase):
    def test_clean_control_false_positive(self):
        result = evaluate([{"id": "clean", "split": "development", "ground_truth": [], "predicted": ["fake_overlap"]}])
        self.assertEqual(result["fp"], 1)
        self.assertEqual(result["precision"], 0)

    def test_missed_critical_defect(self):
        result = evaluate([{"id": "defect", "split": "development", "ground_truth": ["xp_text_obstructed"], "predicted": []}])
        self.assertEqual(result["fn"], 1)
        self.assertEqual(result["recall"], 0)

    def test_perfect_detection(self):
        result = evaluate([{"id": "correct", "split": "holdout", "ground_truth": ["xp_text_obstructed"],
                            "predicted": ["xp_text_obstructed"]}])
        self.assertEqual(result["precision"], 1)
        self.assertEqual(result["recall"], 1)

    def test_no_defects_is_not_qualified_evidence(self):
        result = evaluate([{"id": "clean", "split": "development", "ground_truth": [], "predicted": []}])
        self.assertIsNone(result["precision"])
        self.assertIsNone(result["recall"])

    def test_duplicate_case_id_rejected(self):
        case = {"id": "dup", "split": "holdout", "ground_truth": [], "predicted": []}
        with self.assertRaisesRegex(ValueError, "Duplicate case IDs"):
            validate_cases([case, case])

    def test_missing_split_rejected(self):
        with self.assertRaisesRegex(ValueError, "split"):
            validate_cases([{"id": "x", "ground_truth": [], "predicted": []}])

    def test_duplicate_defect_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate ground_truth"):
            validate_cases([{"id": "x", "split": "holdout",
                             "ground_truth": ["a", "a"], "predicted": []}])


if __name__ == "__main__":
    unittest.main()
