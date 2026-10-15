# DeadShift – Next Build Brief (Stages 1–2): "Make It Dangerous"

Phase C is done and the game is fun. The new problem: **the survivor is too powerful and dying is rare.** This build makes the game dangerous again *without* taking the power fantasy away and turns puzzles into the player's secret weapons. **The boss is not part of this build.**

Design documents this builds on: `CORE_LOOP_SPEC.md`, `POLISH_SPEC.md`, `OUTSKIRTS_GRAYBOX_SPEC.md`, `OUTSKIRTS_ART_TARGET.png`. (`BOSS_SPEC_TRUCKER.md` is for a later build — do not start it.) Where this brief conflicts with them, **this brief wins.**

---

## The direction (read this first)

DeadShift is an **over-the-top horde survival game where you win with your head, not just your build.**

1. **Power fantasy, real threat.** The player should feel absurdly powerful *and* constantly in danger. The horde grows as fast as the survivor does. Getting stronger lets you survive bigger moments; it never makes the game safe.
2. **The map is a weapon.** Oil, pumps, barrels, chokepoints and trailers are as important as guns.
3. **Puzzles are ambush tools.** Puzzles are optional timed events. Completing them earns tools (turret, floodlights, airstrike, fewer spawns) that turn the final battle from brutal into a satisfying ambush. They never block progress.
4. **Bosses are won by strategy.** Every district ends in a way-over-the-top boss whose armor can only be broken by luring him into danger and using puzzle rewards. Stats alone lose.
5. **Every death feels fair.** Threats are readable and telegraphed. The player dies because of a decision, not a surprise.

---

## Rules for this build

- Work in the **2 stages** below. **Stop after each stage**, send a 3-minute recording from the title screen plus the logs listed and a new Android APK, and wait for my go-ahead.
- Do **not** start any boss work in this build.
- All numbers are starting values and must live in data files, not code.
- Keep the anti-burst protections (hit cooldowns, damage cap). Difficulty comes from **pressure, variety and scaling**, not from instant deaths.
- 60 fps on my phone (Samsung S25, arm64) is a hard requirement. Respect the caps in CORE_LOOP_SPEC §14.
- Haptics must go through the single safe vibration helper (VIBRATE permission stays in the export preset).

---

## STAGE 1 — Make it dangerous (difficulty + enemy variety)

### 1.1 Difficulty targets (what "right" looks like)
Measured on runs **without meta upgrades** by a new player:
- HP drops **below 50% at least twice per run**.
- About **half of first runs end before wave 10**, mostly between waves 5–9.
- A good player who uses the map reaches wave 10 with 40–80% HP.
- No death should come from damage the player couldn't see coming.

### 1.2 Threat scales with the player
The horde must keep up with the build.
- **Enemy HP** × (1 + 0.15 × wave) × (1 + 0.03 × player level)
- **Enemy damage** × (1 + 0.08 × wave)
- **Enemy speed** +2% per wave (cap +20%)
- **On-screen pressure targets** (spawn to maintain these, ramping within each wave, surge at the end):

| Wave | Start → end of wave (zombies on screen) |
|---|---|
| 1 | 20 → 40 |
| 2 | 40 → 60 |
| 3 | 55 → 80 |
| 4–5 | 70 → 110 |
| 6–7 | 100 → 150 |
| 8–9 | 140 → 200 (cap 250) |

- **End-of-wave surge:** the last 10 s of each wave spawn a ring of zombies from all directions at once.

### 1.3 Enemy roster (variety forces movement and decisions)
| Enemy | From wave | Behavior | Counterplay |
|---|---|---|---|
| **Shambler** | 1 | Slow, weak, numerous | Basic |
| **Runner** | 2 | Fast, fragile, packs of 4–8, distinct pale look + speed lines | Prioritize; red off-screen arrows |
| **Bloater** | 4 | Slow, tanky, explodes on death into a **slowing goo puddle** (5 s) | Kill at range, avoid the puddle |
| **Spitter** | 5 | Keeps distance, lobs acid with a **0.8 s orange landing circle**, leaves an acid puddle (damage over time, 4 s) | Keep moving; close the distance |
| **Brute** | 6 | Big, armored front (takes 50% from the front), **telegraphed charge** in a straight line | Dodge sideways, hit from behind, bait into obstacles |
| **Elite** (any type) | 3 | Gold aura, 4× HP, bigger, drops a chest | High-value target |

At least 2 different enemy types should be active at once from wave 3 on, spawning from **different directions** so the player gets pinched between a slow wall and a fast group.

### 1.4 Survival tuning
- Hit invulnerability: 0.5 s → **0.35 s**. Per-zombie hit cooldown stays 0.8 s. Contact damage cap stays 35% max HP/second (projectiles, explosions and boss attacks are not capped but are always telegraphed).
- **Healing is scarce:** Medkit heals **20%** (was 30%); medkit drop rate halved; no free healing between waves.
- Player explosions (pumps, barrels) still damage the player.

### 1.5 Power check (log this)
Log the player's damage per second each wave. Rough targets for a typical build:
- Wave 3: a shambler dies in 1 hit, an elite takes ~6 s.
- Wave 6: a brute takes ~4 s from the front, ~2 s from behind.
- Wave 9: an elite takes ~8 s even with a strong build.
If any single weapon or passive combination makes the player untouchable (e.g. stacked Ammo Belt + Lightning chains), flag it and propose a cap.

### Stage 1 logs
Per wave: min HP %, damage taken by source (contact / spitter / bloater / brute / explosion), zombies on screen (avg/max), player DPS, level, time. Per run: wave of death, or Final Stand result.

---

## STAGE 2 — Puzzles become the ambush toolkit

Replaces CORE_LOOP_SPEC §8 gating.

### 2.1 Rules
- **No gating:** the run always continues to wave 10 no matter what.
- **Until the boss exists, wave 10 is a "FINAL STAND":** a 90-second maximum-pressure horde surge (all enemy types, elites, from every direction). Surviving it clears the district. Boss-only rewards are used here for now (see 2.3).
- **One puzzle event per wave**, one active at a time, **timed** (30–60 s). Announced with a banner showing *what, reward, timer* — e.g. **"⚡ GENERATOR OFFLINE — power it in 45 s → AUTO-TURRET"**.
- If the timer runs out, the event fails quietly (no penalty except losing the reward).
- **Guidance:** tall amber light beam on the target, ground arrow from the player, pulsing minimap + screen-edge marker, countdown ring on the objective card.
- **One "interact" language:** everything puzzle-related glows **amber**. Stand-in zones fill a progress ring; shootable targets have amber crosshairs; carryables bob with an amber outline.
- **Teaching:** during the first event (wave 1), spawn pressure drops 40%.
- **"FINAL STAND IN X WAVES"** indicator next to the wave pill (rename to "BOSS IN X WAVES" once the boss exists).
- Show earned tools as small icons ("ARSENAL") under the objective card.

### 2.2 Outskirts event schedule
| Wave | Event | How | Reward |
|---|---|---|---|
| 1 | **Generator offline** | Stand in the ring 4 s (hits interrupt) | Auto-turret on the canopy for the run **+ floodlights for the Final Stand** |
| 2 | **Supply drop** | Grab 3 crates | Chest |
| 3 | **Chain reaction** | Shoot the marked pumps in order while zombies crowd the forecourt | Nuke pickup |
| 4 | **Fuel run** | Carry the gas can (−20% speed) to the truck stop | Flamethrower trap at the highway gap |
| 5 | **Mini-boss: The Mechanic** | Shoot the fuel tank on his back when he winds up | Big chest (evolution chance) |
| 6 | **Motel lockdown** | Hit both switches within 6 s | Motel spawns stop for the run |
| 7 | **Oil trap** | Lure the horde onto the auto-shop oil, shoot the burning barrel | XP shower |
| 8 | **Relay signal** | Stand on 3 lit pads in order (simple; no color code) | **Airstrike** for the Final Stand |
| 9 | **Nest** | Destroy the infestation nest | −25% spawns for the run **+ −25% Final Stand pressure** |
| 10 | **FINAL STAND** (boss placeholder) | Survive 90 s of maximum pressure | District cleared |

The multi-color relay code puzzle is removed from the Outskirts (saved for a later district).

### 2.3 Rewards in the Final Stand (temporary, until the boss is built)
The rewards are designed for the boss fight, so for now they pay off in the Final Stand:
| Reward | Effect in the Final Stand |
|---|---|
| Auto-turret (generator) | Keeps firing from the canopy |
| Floodlights (generator) | The Final Stand happens at night; without floodlights visibility shrinks to a ~4-tile light radius around the survivor |
| Airstrike (relays) | One-use button (bottom-right; game slows to 30% while aiming), clears a large area |
| Fewer spawns (nest) | Final Stand pressure −25% |
Build these as reusable "arsenal" rewards so they plug straight into the boss fight later.

### Stage 2 logs
Per run: events offered / completed / failed, time to complete each, rewards carried into wave 10, and whether the player survived the Final Stand.

---

## Not in this build (coming next)
- **The Trucker boss** (all phases) — later build, per `BOSS_SPEC_TRUCKER.md`, after these two stages are approved.
- Boss and environment art (ComfyUI puppet parts, buildings, props per the art target).
- Meta progression (scrap, Garage, unlocks), audio, and the store/launch work.

## Definition of done (whole build)
- [ ] New players regularly drop below 50% HP and about half of first runs end before wave 10.
- [ ] 5 enemy types plus elites appear on schedule, each requiring a different response.
- [ ] Every puzzle event is noticed and understood within 5 s; none blocks progress.
- [ ] Rewards visibly carry into the Final Stand and are built to plug into the boss fight later.
- [ ] The Final Stand feels like a climax and is hard without rewards.
- [ ] 60 fps on my phone throughout.