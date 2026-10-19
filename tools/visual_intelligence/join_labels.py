#!/usr/bin/env python3
"""Join reviewed screenshot labels to actual Ollama diagnostic reports.

Never infer ground truth from model output or from mutation filenames.
"""
import argparse
import json
from pathlib import Path


def build_cases(labels, reports):
    if not isinstance(labels, dict) or not isinstance(labels.get("cases"), list):
        raise ValueError("Labels must contain a cases array")
    by_digest = {}
    for report in reports:
        digest = report.get("image_sha256")
        if not isinstance(digest, str) or len(digest) != 64:
            raise ValueError("Invalid image checksum in inference report")
        if digest in by_digest:
            raise ValueError("Duplicate inference report checksum")
        by_digest[digest] = report
    output = []
    for label in labels["cases"]:
        if label.get("reviewed") is not True:
            raise ValueError("Unreviewed labels cannot be scored")
        digest = label.get("image_sha256")
        if digest not in by_digest:
            raise ValueError("Missing inference for labeled screenshot")
        report = by_digest[digest]
        if report.get("qualification") != "REVIEW_UNQUALIFIED":
            raise ValueError("Unexpected inference report qualification marker")
        findings = report.get("prediction", {}).get("findings")
        if not isinstance(findings, list):
            raise ValueError("Invalid findings list")
        predicted = []
        for finding in findings:
            if not isinstance(finding, dict):
                raise ValueError("Invalid finding")
            defect = finding.get("defect_id")
            if not isinstance(defect, str) or not defect.strip():
                raise ValueError("Missing defect_id")
            predicted.append(defect)
        if len(predicted) != len(set(predicted)):
            raise ValueError("Duplicate predicted defect IDs")
        output.append({"id": label["id"], "split": label["split"],
                       "ground_truth": label["ground_truth"],
                       "predicted": predicted})
    from evaluate import validate_cases
    validate_cases(output)
    return {"cases": output}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--reports", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    reports = []
    for path in sorted(args.reports.glob("image-*.json")):
        reports.append(json.loads(path.read_text(encoding="utf-8")))
    if not reports:
        raise SystemExit("No inference reports found")
    labels = json.loads(args.labels.read_text(encoding="utf-8"))
    joined = build_cases(labels, reports)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(joined, indent=2), encoding="utf-8")
    print(f"Joined {len(joined['cases'])} reviewed labels with inference reports")


if __name__ == "__main__":
    main()
