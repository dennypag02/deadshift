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


def validate_cases(cases):
    if not isinstance(cases, list):
        raise ValueError("cases must be a list")
    ids = set()
    for case in cases:
        if not isinstance(case, dict):
            raise ValueError("Each case must be an object")
        if not isinstance(case.get("id"), str) or not case["id"].strip():
            raise ValueError("Case id must be a nonempty string")
        if case["id"] in ids:
            raise ValueError("Duplicate case IDs")
        ids.add(case["id"])
        if case.get("split") not in ("development", "holdout"):
            raise ValueError("Invalid or missing split")
        for key in ("ground_truth", "predicted"):
            values = case.get(key)
            if not isinstance(values, list) or any(not isinstance(v, str) or not v.strip() for v in values):
                raise ValueError(f"{key} must be a list of nonempty defect IDs")
            if len(values) != len(set(values)):
                raise ValueError(f"Duplicate {key} defect IDs")


def evaluate(cases):
    validate_cases(cases)
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
    validate_cases(data["cases"])
    cases = [c for c in data["cases"] if args.split is None or c["split"] == args.split]
    result = evaluate(cases)
    result["qualified"] = (
        args.split == "holdout"
        and         len(cases) >= args.minimum_cases
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
