# Reviewed labels — ingestion contract

The automated benchmark reads `tools/visual_intelligence/reviewed_labels.json`
only when it exists. **Do not commit invented labels to make CI pass.**

Example structure (illustrative values only, not an actual benchmark):

```json
{
  "cases": [
    {
      "id": "capture-a-01",
      "split": "holdout",
      "reviewed": true,
      "image_sha256": "REPLACE_WITH_ACTUAL_64_CHARACTER_SHA256",
      "ground_truth": ["xp_obstruction"]
    }
  ]
}
```

The label digest must match the exact PNG used by `batch_probe.py`.
`join_labels.py` reads per-image inference reports, rejects unreviewed labels
and mismatches, and writes `scored_cases.json`. `evaluate.py` then evaluates
the holdout split with minimum 10 cases, precision >= 0.85 and recall >= 0.90.
These thresholds are provisional and not a guarantee of real-world reliability.

## Next required evidence
- Multiple independent captured gameplay states, not repeats of test.png
- Predeclared defect taxonomy and independently reviewed visual ground truth
- Controlled mutations with recorded scripts and image-family separation
- Holdout metrics, error analysis, and GPU peak usage
- No unattended code changes from unqualified model findings

Until this evidence exists, the workflow should report REVIEW_UNQUALIFIED.
