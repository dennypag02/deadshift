# Multi-project asset library v3 — implementation contract

Status: DESIGN / NOT DEPLOYED. The Standard ComfyUI Game Asset Workflow v2 remains authoritative.

## Objective
Turn the local DeadShift-only candidate browser into a reusable multi-project, scoped,
non-destructive asset library. Preserve all existing candidate PNGs and manifest entries.

## Data model
- `project_id`: stable slug, e.g. `deadshift`; project config stores art direction, approved references, engine repo, and default output targets.
- `scope_id`: `general` or `levels/<level-slug>`. A level has its own palette, environment and reference set; inherits the project's global art direction.
- `asset_id`: stable logical asset identifier, unique within project/scope.
- `candidate_id`: immutable UUID or stable manifest ID, not seed alone. Existing manifest rows are migrated using a deterministic ID derived from their existing asset, version, seed, path and job ID.
- `generation_batch_id`: links candidates produced by the same job; new regenerations append, never replace.
- `kept_candidate_ids`: set of zero or more immutable candidates per asset.
- `slot_assignment`: at most one candidate per target game slot; keeping multiple candidates does not automatically promote all of them.
- `promotion_state`: draft -> explicitly approved -> queued -> locally copied -> GitHub pushed -> engine validated -> APK reviewed. Never label queued as complete.

## Folder layout (local; avoid moving existing files until migration passes)
```
asset_pipeline/projects/
  deadshift/
    project.yaml
    general/
      art_direction.yaml
    levels/
      level-01/
        art_direction.yaml
        references/
      level-02/
        art_direction.yaml
        references/
```
Candidate library remains append-only; new generation paths use
`staging/candidates/<project>/<scope>/<asset>/<batch>/<candidate_id>.png`.
Existing `staging/candidates/<category>/<name>_vNN.png` stays valid via manifest mapping.
Do not infer actual levels from illustrative folder names; create level folders from game configuration.

## UI
1. Project selector -> General Assets / Levels -> category -> asset.
2. Each candidate has a **Keep** checkbox (multiple allowed), preview, seed, version,
   generation batch, and approval provenance.
3. **Save kept selections** persists all checked IDs atomically; unchecked items remain in
   the archive, never deleted.
4. **Submit folder selections** submits a reviewed batch of kept candidates to the
   project's curated library; this does NOT overwrite Godot files.
5. Separate **Assign to game slot** single-choice control; **Approve & Promote batch**
   requires confirmation and shows exact source -> target mapping and collisions.
6. **Regenerate 4** queues new candidates in the same project/scope, inheriting
   global+level art direction and explicit approved references; old batches remain visible.
7. Filter: all / kept / assigned / promoted / historical; batch history and side-by-side comparison.
8. Batch operations must be all-or-nothing at validation stage; errors identify each
   missing candidate or target collision. Promotion queue IDs idempotent.
9. No automatic overwrite. Replacing promoted art requires a separate explicit
   replacement approval and a versioned rollback record.

## Safety and reproducibility
- Existing manifest and files backed up before migration; no deletion or destructive renames.
- Each candidate retains full prompts, negative prompts, seed, model hash/version and
  license provenance, LoRA licenses, workflow graph/hash, ComfyUI version, reference
  candidate IDs, processing steps, final dimensions, alpha/tiling validation, and file hashes.
- Candidate files never stretch to fill dimensions; deterministic crop/contain/pad rules
  and locked gameplay footprint precede layout-dependent generation.
- Promotion must pass license and file validation; GitHub is the source of truth for
  promoted art. Engine import, APK build, and device review are separate gates.
- Local worker binds loopback; POST actions require same-origin/host validation.
- Do not assume seed uniquely identifies a candidate (seed can recur across assets/batches).

## Optional AI art director — staged rollout
Phase 1: Agent generates **recommendations only** with evidence and a scored rubric:
silhouette/readability at actual mobile size, perspective, palette/style cohesion,
level identity, reference similarity, transparency, animation suitability,
gameplay footprint, license/provenance, and technical checks. Store agent/model
version, rubric, reasons and confidence with each recommendation.
Phase 2: Human reviews agent's curated shortlist, approves the actual batch.
Phase 3 (separate explicit opt-in): agent may auto-keep candidates that pass
objective checks, but never auto-promote/overwrite major art or alter gameplay.
Human approval remains required for key characters, bosses, art-direction changes,
and replacement of existing promoted assets. Low-confidence results are escalated.
Assess agreement against human selections before any autonomous authority.

## Migration and acceptance tests
- Back up the existing 48-asset batch and all manifest/selection/approval state.
- Every existing candidate remains browseable, unchanged and selectable.
- Multiple candidates for the same asset can be kept in one action.
- Batch submission preserves candidate IDs and provenance, no loss on retries.
- Regeneration adds a new batch without modifying existing files or selected state.
- A level inherits global style and can override level-specific palette/references.
- Unapproved selections never write to Godot; collisions cannot overwrite.
- Simulated crash/retry cannot duplicate promotions or corrupt JSON.
- AI recommendations are clearly labeled and do not silently approve.
- Tests: offline unit tests, HTTP integration tests, manifest migration/rollback,
  Godot import, APK build and target-device review.

## Delivery sequence
A. Schema, manifest migration and append-only storage + tests.
B. Project/scope navigation, multi-select keep, bulk submit + tests.
C. Regeneration history, reference-based generation and safe batch promotion + tests.
D. AI art-director recommendation report, evaluated against human preferences.
E. End-to-end engine/APK/device validation before production acceptance.
