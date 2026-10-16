# Stage 2: fairness and meaningful movement

Status: RUNNING. Baseline: 59c4295a5eaa648f6cd89e4a4a0d110bf6423051 on feature/phase-a-progression, delivered game 0.1.231. The recovered Godot subtree was verified against the live Git tree: 5e82910d415f3d0a36b3afbe273ad6a4b0328402.

Priority: prevent unreadable wave-5 burst deaths before changing encounter pressure. All incoming sources share a rolling 35%-max-HP-per-second budget; single pump damage is at most 30%. Reveals pause gameplay and grant one second of recovery protection. Notification banners are queued in a small top band, never over the survivor. Damage history and a named killer are required.

Then: wire existing promoted icons with a missing-icon fallback; nearby reachable HOLD/GRAB/DESTROY objectives; bounded fading goo; maintain specified on-screen pressure; early fixed-position spitter/brute telegraphs; facing SMG/Boomstick; earned XP collection and 20-second gem expiry; rewards 6-12 metres away; data-driven anti-camp pressure after eight seconds within three metres; real shader warm-up and measured performance comparison. Hide Garage-only scrap summary.

No new art promotion, no approved PNG replacement, no end-boss work, no app-permission changes. A source-snapshot workflow write was blocked by a safety check and was not retried. Existing source artifacts and verified repository reads are used for local work instead.

Acceptance evidence required: strict functional regressions, three stationary runs and three moving runs with all outcomes retained, matched baseline moving runs, a real-engine three-minute 720p normal-run recording, damage logs, and a verified signed APK. Scripted tests cannot establish human-player difficulty or Samsung physical-phone FPS. Do not mark complete until evidence exists; preserve failures and report any unmet gate.
