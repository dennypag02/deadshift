# DEADSHIFT-BRIEF — Mandatory repository engineering rules

Read this file before changing GitHub Actions, runner configuration, or automation.

## Personal runner security (non-negotiable)
- NEVER run untrusted pull-request code on any self-hosted runner, including the laptop GPU runner. Do not add pull_request or pull_request_target triggers to workflows with self-hosted jobs unless every self-hosted job has a rigorously verified same-repository trust gate; prefer push on an explicitly controlled branch or workflow_dispatch.
- Do not execute fork-provided scripts, checkout, artifacts, or commands in privileged workflow_run jobs.
- The owner must explicitly approve changes to workflows that execute on the laptop BEFORE merging them. Routine game code changes do not require approval.
- Keep GitHub identity dennypag02 for personal projects. Do not use work identities.

## Required pre-merge review
- Validate triggers, runner labels, job permissions, branch/PR mergeability, trusted event provenance, idempotency, logging of skipped/failure/success, and recovery limits.
- Run the workflow security guard and review changes to the guard itself. Protect its required check and CODEOWNERS/branch protection in GitHub settings; a workflow file alone cannot enforce its own immutability.
- Do not claim workflow_run completion from a PR commit run lookup; inspect the downstream workflow run or persistent event ledger.
- Do not push rapid-fire acceptance commits: wait for one benchmark and orchestrator acknowledgment before the next.
- Keep unqualified visual models in review-only mode; do not promote edits without reviewed evidence.
- Completion requires exact-SHA test/build evidence and a verified artifact. No claims of autonomous certification before dispatch, bridge reasoning, failure recovery, and artifact delivery pass.
