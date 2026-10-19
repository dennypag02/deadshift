import unittest
from join_labels import build_cases


DIGEST = "a" * 64


def report(findings):
    return {"image_sha256": DIGEST, "qualification": "REVIEW_UNQUALIFIED",
            "prediction": {"findings": [{"defect_id": x} for x in findings]}}


def labels(reviewed=True):
    return {"cases": [{"id": "case-1", "split": "holdout", "reviewed": reviewed,
                       "image_sha256": DIGEST, "ground_truth": ["xp_obstruction"]}]}


class JoinLabelsTests(unittest.TestCase):
    def test_joins_actual_prediction(self):
        result = build_cases(labels(), [report(["xp_obstruction"])])
        self.assertEqual(result["cases"][0]["predicted"], ["xp_obstruction"])

    def test_rejects_unreviewed(self):
        with self.assertRaisesRegex(ValueError, "Unreviewed"):
            build_cases(labels(False), [report([])])

    def test_rejects_missing_inference(self):
        with self.assertRaisesRegex(ValueError, "Missing inference"):
            build_cases(labels(), [])

    def test_rejects_duplicate_reports(self):
        with self.assertRaisesRegex(ValueError, "Duplicate inference"):
            build_cases(labels(), [report([]), report([])])

    def test_rejects_duplicate_predictions(self):
        with self.assertRaisesRegex(ValueError, "Duplicate predicted"):
            build_cases(labels(), [report(["xp_obstruction", "xp_obstruction"])])


if __name__ == "__main__":
    unittest.main()
