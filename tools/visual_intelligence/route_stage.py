#!/usr/bin/env python3
"""Fail-closed deterministic routing for DeadShift vision benchmark stages.

This records the next permitted action; it does not self-authorize code changes,
fabricate ground truth, or assert that the personal bridge consumed an event.
"""
import argparse
import json
from pathlib import Path


def route(evidence, inference_result, scoring_result):
    summary_file = evidence / "summary.json"
    if inference_result != "success" or not summary_file.is_file():
        return {"state": "BLOCKED", "next_action": "repair_inference",
                "reason": "Inference failed or evidence is missing"}
    try:
        summary = json.loads(summary_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {"state": "BLOCKED", "next_action": "repair_evidence",
                "reason": "Invalid inference summary"}
    if (not isinstance(summary.get("processed"), int)
            or summary["processed"] < 1
            or summary.get("failed") != 0
            or summary.get("passed") != summary["processed"]):
        return {"state": "BLOCKED", "next_action": "repair_inference",
                "reason": "Incomplete inference batch"}
    if scoring_result != "success":
        return {"state": "BLOCKED", "next_action": "repair_scoring",
                "reason": "Reviewed-label scoring failed"}
    scored = evidence / "scored_cases.json"
    if not scored.is_file():
        return {"state": "REVIEW_UNQUALIFIED", "next_action": "collect_reviewed_labels",
                "reason": "No scored reviewed cases; diagnostic only",
                "images_processed": summary["processed"]}
    return {"state": "REVIEW_UNQUALIFIED", "next_action": "verify_holdout_gate",
            "reason": "Scored cases exist but qualification result is not attested",
            "images_processed": summary["processed"]}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--inference-result", required=True)
    p.add_argument("--scoring-result", required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    result = route(args.evidence, args.inference_result, args.scoring_result)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
