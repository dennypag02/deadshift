# Deadshift V3 — Approved execution sequence

Owner: dennypag02
Approval: V3A through V3E, routine technical and design decisions delegated.
Execution policy: deterministic GitHub Actions for builds/tests; ChatGPT judgment for design and uncertain decisions; no Codex; preserve V2 until accepted.

## Current evidence

- Foundation branch: `feature/v3-godot-scrolling-world`
- Foundation PR: https://github.com/dennypag02/deadshift/pull/6
- Godot parse/smoke CI passed: https://github.com/dennypag02/deadshift/actions/runs/37792657924
- V3A work item: https://github.com/dennypag02/deadshift/issues/7
- V3B work item: https://github.com/dennypag02/deadshift/issues/8
- No V3 Android APK or physical acceptance yet.

## Stage gates

1. **V3A — Art:** Original cohesive top-down survivor, zombie types, environment tiles/props, VFX; transparent game-ready PNG atlases; provenance manifest; actual in-engine visual preview. Gate: assets exist, render on phone-sized viewport, and are not just geometry placeholders.
2. **V3B — Engine:** Port V2 gameplay mechanics (movement, sprint, dodge, auto-fire, grenade, drone, pickups, waves, Brute) to Godot with automated tests. Gate: functional parity evidence.
3. **V3C — World:** Smooth following camera, persistent streamed deterministic map chunks, obstacles/collision, spawns outside view, navigation and backtracking. Gate: automated and visual evidence.
4. **V3D — Polish:** Directional character and enemy animations, lighting, shadows, particles, hit feedback, HUD and performance profiling. Gate: integrated visuals and mobile performance evidence.
5. **V3E — Android:** Versioned Godot APK build and GitHub artifact; launch, movement, combat, scrolling and stability tested on physical Android. Gate: actual phone feedback and explicit acceptance.

## Continuation rule

A green CI result validates only the checks run; it is not automatic proof of art quality or physical acceptance. Never mark a stage complete without evidence. Do not imply ChatGPT automatically executes further stages after the conversation ends. Bridge event delivery and continuation must be independently verified before claiming unattended progression.

## Next executable work

Create V3A original asset set and asset manifest, replace vector placeholders in Godot, then add screenshot/animation verification. Continue into V3B–V3E after each stage gate.
