#!/usr/bin/env python3
"""Evaluate structured visual defect predictions against reviewed labels.

Input JSON schema: {"cases":[{"id":"...","ground_truth":["defect_id"],
"predicted":["defect_id"],"split":"holdout|development"}]}
Only reviewed ground_truth labels belong in this file. Do not treat raw model
prose or an unreviewed screenshot as ground truth.
"""
import argparse
import json
from pathlib import Path


def evaluate(cases):
    tp = fp = fn = 0
    results = []
    for case in cases:
        actual = set(case["ground_truth"])
        predicted = set(case["predicted"])
        if not all(isinstance(x, str) for x in actual | predicted):
            raise ValueError("All defect IDs must be strings")
        hit = actual & predicted
        extra = predicted - actual
        missed = actual - predicted
        tp += len(hit)
        fp += len(extra)
        fn += len(missed)
        results.append({"id": case["id"], "true_positive": sorted(hit),
                        "false_positive": sorted(extra), "false_negative": sorted(missed)})
    precision = tp / (tp + fp) if tp + fp else None
    recall = tp / (tp + fn) if tp + fn else None
    return {"cases": len(cases), "tp": tp, "fp": fp, "fn": fn,
            "precision": precision, "recall": recall, "details": results}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", type=Path)
    parser.add_argument("--split", choices=["development", "holdout"])
    parser.add_argument("--min-precision", type=float, default=0.85)
    parser.add_argument("--min-recall", type=float, default=0.90)
    parser.add_argument("--minimum-cases", type=int, default=10)
    args = parser.parse_args()
    data = json.loads(args.dataset.read_text(encoding="utf-8"))
    cases = [c for c in data["cases"] if args.split is None or c["split"] == args.split]
    ids = [c["id"] for c in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate case IDs")
    result = evaluate(cases)
    result["qualified"] = (
        len(cases) >= args.minimum_cases
        and result["precision"] is not None
        and result["recall"] is not None
        and result["precision"] >= args.min_precision
        and result["recall"] >= args.min_recall
    )
    print(json.dumps(result, indent=2))
    if not result["qualified"]:
        raise SystemExit("REVIEW_UNQUALIFIED: insufficient evidence or thresholds not met")


if __name__ == "__main__":
    main()
