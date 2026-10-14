# DeadShift – Core Loop Spec: Power-Ups, Puzzles, Bosses & Pace

## Vision

**An over-the-top, fast, gorgeous zombie horde game.** You start a run as one tough survivor with a scrap gun. Twelve minutes later you are a walking apocalypse: saw blades orbiting you, lightning arcing through the horde, drones raining rockets, the screen full of your own fireworks — and then the district boss arrives and tests everything you built.

### Design pillars (every feature must serve at least one)

1. **Over the top.** Power should escalate visibly and absurdly. If a level-up doesn't change what's on screen, it's too small.
2. **Tons of power-ups.** Every run builds differently. Frequent choices, big combos, secret evolutions.
3. **Fast.** Something happens every few seconds: a level-up, a pickup, an elite, an objective, an explosion. No dead time.
4. **Action puzzles.** Short brain-teasers solved *while fighting*, never by stopping. Solve one → big payoff.
5. **Hard, fair bosses.** Each district ends in a boss that demands a good build *and* good dodging. Every hit is telegraphed and avoidable.
6. **Beautiful.** Every system has a visual payoff (see §12 and `POLISH_SPEC.md`).

### Rules for the agent

- Build in the **phases in §15**, in order. Stop after each phase so I can play-test.
- All numbers here are **starting values**. Put every number in data files (Godot `Resource`s or JSON), not hard-coded, so we can tune without code changes.
- **Build the debug menu first** (§13). We can't tune any of this without it.
- Mobile performance targets in §14 are hard limits.
- Keep the existing hazards, map and polish work. This spec changes the **run structure and player progression**.

---

## 1. Run structure and pacing

**Target run length: 12–14 minutes.** Restart in one tap.

| Segment | Length | What happens |
|---|---|---|
| Waves 1–9 | 60–75 s each | Constant horde pressure + 1 event per wave (objective, elite, or ambush). |
| Breaks between waves | **8 s** (not longer) | Pickups get vacuumed to the player, the next objective is announced, a countdown runs. No shop screen. |
| Wave 5 | — | **Mini-boss** (elite with a chest). |
| Wave 10 | ~2 min | **District boss** (§9). |

**Pace rules (the "always something happening" checklist):**
- First zombie on screen within **2 s** of the run starting. First level-up within **~10 s**.
- Level-up every **10–15 s** early, **20–30 s** mid-run, **30–45 s** late.
- A notable event (elite, objective step, chest, power-up drop, ambush) at least every **30 s**.
- Zombie pressure ramps *within* each wave (starts at 60%, ends at 130% of the wave's base rate) so every wave ends in a surge.
- Kill counts should land around **1,500–2,000 per run**.

**Wave 1 is shortened:** about 60 s and a light horde. The current wave 1 (190+ zombies, over a minute and still going) is too long for a first impression.

---

## 2. XP and leveling

### XP drops
Every kill drops an **XP gem** that the player collects by walking near it (pickup radius **1.2 tiles**, boosted by Magnet).

| Enemy | XP | Gem look |
|---|---|---|
| Shambler | 1 | small blue gem |
| Runner | 2 | small green gem |
| Bloater / Spitter | 4 | medium green gem |
| Brute | 10 | large purple gem |
| Elite (any enemy with a gold aura) | 25 + chest | large gold gem |

- **Gem merging:** if more than 200 gems are on the ground, merge the oldest nearby gems into bigger gems (value preserved). Keeps performance safe and looks great.
- Gems fly to the player with a slight arc and a "tink" sound (pitch rises with combo).

### Level curve
XP needed to go from level *n* to *n+1*:

```
xp_required(n) = round(6 + 4*(n-1) + 0.12*(n-1)^2)
```

| Level | XP to next | Cumulative |
|---|---|---|
| 1 → 2 | 6 | 6 |
| 3 → 4 | 14 | 30 |
| 5 → 6 | 24 | 73 |
| 10 → 11 | 52 | 274 |
| 15 → 16 | 86 | 632 |
| 20 → 21 | 125 | 1,177 |
| 25 → 26 | 171 | 1,938 |
| 30 → 31 | 223 | 2,946 |

A good run reaches **level 25–30**. That fills most weapon and passive slots, which is the point: by the boss, the player should feel fully loaded.

---

## 3. The level-up screen

When the XP bar fills:

1. The game **pauses** with a quick 0.15 s slow-down (not a hard cut), the world darkens and blurs slightly.
2. **Three upgrade cards** slide up from the bottom, staggered 0.08 s apart.
3. The player taps one. The card flashes, the others fly away, and the game resumes with a 0.5 s **invulnerability window** and a shockwave that pushes nearby zombies back.

**Card layout** (portrait, each card ~300×460 px, 3 side by side):
- Rarity frame color (see below), large icon (from the ComfyUI pipeline, §12), name in Bebas, level pips (●●●○○), one-line effect with real numbers ("+1 saw blade, +15% damage").
- **NEW** tag for weapons/passives the player doesn't own yet.
- **EVOLUTION READY** glow when the card completes an evolution recipe (§6).

**Buttons under the cards:**
- **Reroll** (2 per run): draw 3 new cards.
- **Banish** (1 per run): remove an upgrade from the pool for this run.
- Both counts can be increased with meta upgrades (§11).

**Card rarity** (affects only how strong the upgrade's numbers are):

| Rarity | Frame | Chance | Effect |
|---|---|---|---|
| Common | steel gray | 70% | normal step |
| Rare | blue | 22% | step +50% |
| Epic | purple | 7% | double step |
| Legendary | gold, animated | 1% | double step + bonus effect |

Luck (passive / meta) shifts these odds upward.

**Build limits:** max **6 weapons** and **6 passives**. When full, only upgrades for owned items are offered (plus gold/heal fallback cards when everything is maxed).

---

## 4. Weapons (8)

All weapons fire automatically. Each has **5 levels** and one **evolution** (§6). The survivor starts with the **Scrap SMG**.

| # | Weapon | Behavior | Level-up steps (L2 → L5) | Visual |
|---|---|---|---|---|
| 1 | **Scrap SMG** (starter) | Fast bullets at the nearest zombie. | +1 bullet per burst / +20% fire rate / pierce 1 / +1 bullet / +25% damage | Bright tracers, brass shell casings |
| 2 | **Boomstick** | Shotgun cone in the facing direction, big knockback. | +2 pellets / +20% damage / wider cone / +2 pellets / knockback ×2 | Muzzle blast, pellets spark on impact |
| 3 | **Molotov Lobber** | Throws bottles that leave burning pools for 3 s. | +1 bottle / +30% pool size / +1 s burn / +1 bottle / pools ignite oil hazards (bonus) | Arcing bottle, flame pool, heat shimmer |
| 4 | **Buzzsaw Orbit** | Saw blades circle the player. | +1 blade / +20% damage / +25% radius / +1 blade / +30% speed | Spinning blades, sparks and blood spray |
| 5 | **Lightning Rod** | Bolt that chains between zombies. | +1 chain / +20% damage / −15% cooldown / +2 chains / stuns 0.3 s | Jagged electric arcs, white flash |
| 6 | **Rocket Pod** | Homing rockets that explode in an area. | +1 rocket / +25% blast radius / +20% damage / +1 rocket / leaves fire | Smoke trails, big explosions, screen shake |
| 7 | **Attack Drone** | Drone that follows the player and fires on its own. | +1 drone / +20% fire rate / drones pierce / +1 drone / drones fire mini-rockets | Hovering drones with blinking lights |
| 8 | **Hubcap Chakram** | Spinning hubcap that flies out and boomerangs back, piercing everything. | +1 hubcap / +20% damage / +30% range / +1 hubcap / bounces between walls | Spinning chrome disc with motion trail |

## 5. Passives (11)

Passives scale weapons. Each has **5 levels**.

| Passive | Effect per level |
|---|---|
| **Muscle** | +10% all damage |
| **Ammo Belt** | +1 projectile at L1, L3, L5 (all weapons that fire projectiles) |
| **Trigger Finger** | +8% fire rate / attack speed |
| **Battery Pack** | −8% cooldowns |
| **Blast Radius** | +12% area (explosions, pools, chains, orbits) |
| **Fuel Tank** | +15% effect duration (burns, pools, stuns) |
| **Ball Bearings** | +12% projectile speed and orbit speed |
| **Magnet** | +30% pickup radius |
| **Thick Hide** | +15% max HP and +1 armor |
| **Sharpened Edge** | +6% critical chance (crits deal ×2 and pop bigger numbers) |
| **Rabbit's Foot** | +10% luck (better card rarity, more chests and power-up drops) |

## 6. Evolutions (the secret combos)

When a weapon is at **level 5** and the player owns its **partner passive**, the next **chest** (elite, mini-boss or boss) offers the **evolution**. Evolutions are screen-changing and should feel absurd.

| Weapon + passive | Evolution | What it does |
|---|---|---|
| Scrap SMG + Ammo Belt | **Lead Hurricane** | Bullets fire in all directions in a spinning spiral. |
| Boomstick + Muscle | **Dragon's Breath** | Incendiary cone that sets everything on fire. |
| Molotov Lobber + Fuel Tank | **Napalm Rain** | Bottles rain from the sky over the whole screen. |
| Buzzsaw Orbit + Ball Bearings | **Meat Grinder** | Two counter-rotating rings of 8 saws. |
| Lightning Rod + Battery Pack | **Thunderdome** | A permanent storm: bolts strike every 0.4 s around the player. |
| Rocket Pod + Blast Radius | **Carpet Bomber** | Airstrike lines of explosions across the screen. |
| Attack Drone + Trigger Finger | **Drone Swarm** | 8 drones that dive-bomb zombies like missiles. |
| Hubcap Chakram + Sharpened Edge | **Chrome Tornado** | Giant hubcap that orbits the screen edge, always critting. |

- Show evolution recipes in a **Codex** on the main menu. Unknown ones appear as silhouettes ("???") until discovered once — discovery is part of the fun.
- Evolved weapons get a gold icon frame and their own VFX color.

---

## 7. Power-up pickups (temporary, on the map)

Dropped by elites, chests, objective rewards and rarely by normal zombies (base 0.4% per kill, raised by luck). They glow, bob and have a colored beam of light so they're visible across the screen.

| Pickup | Effect | Duration |
|---|---|---|
| **Rage** | ×2 fire rate, ×1.5 move speed, survivor glows and grows 20% | 10 s |
| **Mega Gun** | Survivor pulls out a ridiculous minigun: huge bullets, constant fire, screen shake | 8 s |
| **Nuke** | Flash, shockwave, kills every normal zombie on screen (elites take 50%) | instant |
| **Magnet** | Pulls every XP gem on the map to the player | instant |
| **Freeze** | Freezes all zombies on screen; frozen zombies shatter when hit | 5 s |
| **Medkit** | Heals 30% HP | instant |
| **Scrap Pile** | +50 scrap (meta currency) | instant |
| **Chest** | 1, 3 or 5 upgrades with a slot-machine reveal (5 is rare and huge) | — |

**Chest reveal:** the chest bursts open, upgrade icons spin like a slot machine and lock in one by one with a sound sting. Pure dopamine — worth doing well.

---

## 8. Action puzzles

Puzzles are what make DeadShift different from other horde games. They must keep the pace high, so every puzzle follows these rules:

1. **Solved while fighting**, in **10–30 seconds**. The game never pauses for a puzzle.
2. **Only the player's normal verbs:** move, stand on, shoot, carry. No new controls.
3. **Readable at a glance:** icons and color, shown on the objects themselves and on the minimap. Never rely on text alone or on memorizing long sequences.
4. **Failure adds pressure, not death:** a wrong step spawns an ambush or resets the puzzle, but never kills the player outright.
5. **Big payoff:** a chest, a power-up, a screen-clearing trap, or a new path.
6. **One new puzzle type per wave** in the first district. Later districts can combine them.

**Simplify what's there now:** the current relay color order (RED > BLUE > YELLOW > RED) plus color traps plus lockdowns plus generator plus supplies at once is too much for a first district. Spread them across waves as below and move the multi-color relay order to a later district.

### Outskirts puzzle set (one per wave)

| Wave | Puzzle | How it works | Payoff |
|---|---|---|---|
| 1 | **Power the generator** | Stand in the generator ring for 4 s (progress ring fills; zombies interrupt by hitting you). | Lights come on, turret at the canopy activates for the rest of the run. |
| 2 | **Supply run** | 3 crates appear (arrows point to them). Walk over each. | Chest. |
| 3 | **Chain reaction** | Zombies crowd the forecourt. Shoot the pumps in the right order — glowing arrows on the ground show which pump's blast reaches the next. | Pump chain clears the forecourt + Nuke drop. |
| 4 | **Fuel run** | Pick up a gas can (move speed −20% while carrying), carry it to the truck-stop generator. Dropping it when hit leaves a fire pool. | Activates a flamethrower trap at the highway gap. |
| 5 | **Mini-boss: The Mechanic** | Elite brute with a wrench shield; shoot the fuel tank on his back when he winds up a charge. | Big chest (evolution chance). |
| 6 | **Motel lockdown** | Two switches at opposite ends of the motel; both must be hit within 6 s of each other to seal the doors. | Motel spawns stop for the wave. |
| 7 | **Oil trap** | Lure the horde onto the auto-shop oil, then shoot the burning barrel into it. | Burning oil kills the horde; XP shower. |
| 8 | **Relay switches (simple)** | 3 relays light up one at a time; stand on the lit one. Order shown by numbered icons. | Opens the highway gate for the boss. |
| 9 | **Hold the line** | Defend the canopy for 30 s while barricades auto-build. | Fortified arena for the boss. |
| 10 | **Boss: The Trucker** | See §9. | District cleared, Downtown unlocked. |

### Puzzle ideas for later districts (to keep variety)

- **Docks:** crane drop (shoot the release when the shadow covers the boss/horde); container slide (shoot containers to push them and open paths).
- **Downtown:** power grid (rotate junction boxes by shooting them until the line lights up); traffic jam (blow cars to clear the boss path).
- **Hospital:** quarantine (seal vents in the right order to gas the horde); blood bank (carry glowing vials to a centrifuge while infected chase you).
- **Mall:** escalator control; fountain short-circuit (lure into water, shoot the power box).
- **Military:** missile launch codes (relay color order lives here), minefield (shoot mines to clear a path).

---

## 9. Bosses

### Boss rules
- **Telegraph everything** 0.6–1.0 s ahead: wind-up animation + ground warning shape in **bright orange/yellow** (not red; red stays the survivor's color).
- **No unavoidable damage.** Every attack has a gap or safe spot.
- **3 phases**, changing at 66% and 33% HP, each adding one new attack and a visual change (armor breaks off, rage glow).
- **Adds** keep pressure on but stay light (≤40 zombies) so the boss is the focus.
- **Weak points** reward aiming position: hitting a glowing weak spot deals ×2 damage.
- **Boss HP bar** at the top: name in Bebas, phase markers on the bar.
- **Enrage** at 3:00: attacks speed up 30% (prevents endless kiting).
- **Defeat:** 1 s slow-motion, giant explosion, screen flash, gold chest with guaranteed evolution (if eligible) + big scrap reward.
- HP scales with run power: base HP × (1 + 0.04 × player level), so strong builds still get a fight.

### Outskirts boss: **The Trucker** (wave 10)

Arrives in the burning tanker crash. A massive zombie in a trucker cap, chains wrapped around his arms, dragging a twisted car door as a shield.

| Phase | HP | Attacks |
|---|---|---|
| 1 | 100–66% | **Charge** (lowers head, orange line telegraphs the path, rams in a straight line; hitting a car or pump stuns him 2 s and exposes his back = weak point). **Chain Whip** (sweeping arc in front of him). |
| 2 | 66–33% | Rips the car door off → **Door Toss** (throws it; it slides and bounces off walls). **Horn Blast** (loud honk summons 15 runners from the highway). |
| 3 | 33–0% | Tanker fuel on his back ignites. **Fire Trail** (charges leave burning lines for 5 s). **Ground Pound** (3 expanding shockwave rings; jump timing = walk through the gaps). |

The arena's pumps, barrels and oil still work, so a smart player uses the map: bait charges into pumps for stuns, lure him through oil.

### Bosses for the other districts (to design in detail later)

| District | Boss | Hook |
|---|---|---|
| Downtown | **The Skyscraper** | Giant mutant that climbs buildings and slams down; shoot the crane to drop steel beams on it. |
| Suburbs | **The Brood Mother** | Bloated queen that births runners; destroy egg sacs around the cul-de-sac to weaken her. |
| Mall | **Big Box** | Mutant fused with shopping carts and mannequins; rolls through the food court like a wrecking ball. |
| Docks | **The Drowned Captain** | Rises from the harbor with an anchor on a chain; the crane-drop puzzle is part of the fight. |
| Hospital | **Patient Zero** | Splits into 3 copies; only the real one has a heartbeat (audio + pulse cue). |
| Military Checkpoint | **The Abomination** | Final boss: zombie fused with a tank. Multi-part fight (destroy turrets, then treads, then the core). |

---

## 10. Difficulty curve

- **Wave difficulty** rises through HP and speed scaling **and** new enemy types, not just more zombies:
  - Waves 1–2 shamblers → 3 runners → 4 bloaters (explode into slowing goo) → 5 elites + mini-boss → 6 spitters (ranged, telegraphed) → 7 armored brutes → 8–9 mixed elite packs → 10 boss.
- Enemy HP × (1 + 0.12 × wave); damage × (1 + 0.06 × wave).
- **Elites** (gold aura, 4× HP, bigger, drop chests) appear from wave 3, about 1 per 45 s.
- **Heat levels** (after first clearing a district): optional difficulty modifiers like Hades' Heat: faster zombies, fewer heals, extra elites, boss gains a 4th phase. Each Heat level boosts scrap rewards. This keeps hardcore players coming back.

---

## 11. Meta progression (between runs)

Every run, win or lose, earns **Scrap** (wave reached, kills, objectives, bosses, Scrap Piles).

**The Garage** (main menu) — permanent upgrades bought with scrap:

| Upgrade | Levels | Effect per level |
|---|---|---|
| Toughness | 10 | +5% max HP |
| Firepower | 10 | +3% damage |
| Scavenger | 5 | +10% scrap earned |
| Magnet | 5 | +10% pickup radius |
| Lucky Charm | 5 | +5% luck |
| Second Wind | 1 | Revive once per run with 50% HP |
| Reroll | 3 | +1 reroll per run |
| Banish | 2 | +1 banish per run |
| Head Start | 3 | Start each run at level 2/3/4 |

**Unlocks:**
- **Weapons** start locked except SMG, Boomstick, Buzzsaw and Molotov. Others unlock through achievements (e.g. "Kill 500 zombies with fire" unlocks Rocket Pod). This keeps the early pool small and easy to learn.
- **Survivors:** the main survivor first; later unlockable characters with different starting weapons and a perk (e.g. *The Mechanic* starts with a drone; *The Medic* heals 1 HP per 10 kills).
- **Districts** unlock by beating the previous boss.
- **Codex:** evolutions, enemies and bosses discovered.

**Light retention hooks (no pay-to-win):** daily challenge run (fixed seed + modifier), 3 daily missions for bonus scrap, achievements.

---

## 12. Visual payoff (tie-in with POLISH_SPEC.md)

- **Every weapon and evolution needs its own VFX**, readable and distinct by color and shape (bullets yellow-white, fire orange, lightning cyan-white, saws silver sparks, explosions orange with smoke). The screen should look like fireworks by minute 10.
- **Damage numbers** (toggle in Settings): white normal, large yellow crits with a pop. Merge numbers on the same enemy within 0.15 s.
- **The survivor visibly powers up:** subtle aura that grows with level, gold aura during Rage, sparks when evolutions are owned.
- **Level-up moment:** shockwave ring, light beam on the survivor, "LEVEL UP!" text burst before the cards.
- **Boss intro:** 2-second cinematic: camera zooms to the boss, name card slams in ("THE TRUCKER — King of the Highway"), then back to the player.

### New art for the ComfyUI pipeline

Add an `icons` category to `assets.yaml` (one icon per weapon, evolution, passive and pickup — about 40 icons). Style:

```yaml
  icons:
    workflow: sprite
    size: [1024, 1024]
    target: {long_side: 192}
    count: 4
    style: "(flat vector illustration:1.3), game UI icon, bold dark outlines, cel shaded, centered single object, slight 3/4 angle, high contrast, vibrant highlight color on muted rust and steel base, (isolated on plain white background:1.4)"
    negative: "photograph, photorealistic, 3D render, text, letters, numbers, frame, border, multiple objects, cropped, blurry, watermark, background scenery"
```

Example entries:
```yaml
  - {name: icon_scrap_smg,      category: icons, prompt: "makeshift submachine gun made of scrap metal and duct tape, glowing hot barrel"}
  - {name: icon_buzzsaw,        category: icons, prompt: "spinning circular saw blade with motion sparks"}
  - {name: icon_lightning_rod,  category: icons, prompt: "metal rod crackling with bright cyan lightning"}
  - {name: icon_meat_grinder,   category: icons, prompt: "two interlocking rings of saw blades glowing gold, evolution weapon"}
  - {name: icon_muscle,         category: icons, prompt: "flexing muscular arm with a bandage"}
  - {name: icon_rabbit_foot,    category: icons, prompt: "lucky rabbit's foot keychain with a four leaf clover tag"}
  - {name: icon_pickup_nuke,    category: icons, prompt: "small cartoon nuclear bomb with a hazard symbol, glowing"}
```
Bosses and new enemies (bloater, spitter, elite, The Mechanic, The Trucker) go in the `characters` category.

---

## 13. Debug menu (build first)

A hidden debug panel (e.g. triple-tap the pause button in dev builds):
- Give any weapon/passive at any level; trigger evolution.
- Add XP / set player level.
- Spawn any enemy, elite, mini-boss or boss.
- Jump to any wave; trigger any puzzle.
- God mode; time scale ×0.5 / ×2 / ×4.
- Show FPS, active enemy count, projectile count.

## 14. Mobile performance limits

- Target **60 fps** on a mid-range Android phone.
- **Max 250 active zombies**; beyond that, hold spawns or merge into elites.
- **Max 400 active projectiles**; pool everything (bullets, gems, particles, damage numbers).
- XP gems merge above 200 on the ground.
- Use `MultiMesh`/batched drawing for zombies and gems if needed; avoid per-zombie `Light2D`.
- Damage numbers capped at 40 on screen.

---

## 15. Build phases (stop after each one)

| Phase | Contents | Test |
|---|---|---|
| **A** | Debug menu, XP gems, level curve, level-up screen with cards, 3 weapons (SMG, Boomstick, Buzzsaw), 5 passives (Muscle, Ammo Belt, Trigger Finger, Magnet, Thick Hide). | Does leveling feel fast and exciting in the first 2 minutes? |
| **B** | Remaining 5 weapons and 6 passives, rarity, reroll/banish, build limits, damage numbers. | Do different runs feel different? |
| **C** | Chests with slot-machine reveal, elites, the 8 evolutions, power-up pickups. | Do evolutions feel absurd and worth chasing? |
| **D** | New run pacing (60–75 s waves, 8 s breaks), new enemy types, wave difficulty curve. | Is there something happening every 30 s? Is a run 12–14 min? |
| **E** | Outskirts puzzle set (§8), simplified from the current objectives. | Can a new player understand each puzzle in under 5 s? |
| **F** | The Mechanic mini-boss and The Trucker boss with intro cinematic and boss HP bar. | Is the boss hard but fair? Does every death feel like the player's fault? |
| **G** | Meta progression: scrap, Garage, unlocks, Codex, daily challenge. | Does a failed run still feel worth it? |

## Definition of done (whole spec)

- [ ] A full Outskirts run takes 12–14 minutes and ends with The Trucker.
- [ ] Level-ups happen within 10 s of the start and keep coming throughout.
- [ ] Two runs with different choices look and play noticeably differently.
- [ ] At least 3 evolutions are reachable in a normal run.
- [ ] Each puzzle is understood in under 5 s and solved in under 30 s while fighting.
- [ ] Boss attacks are all telegraphed and avoidable.
- [ ] Losing a run still earns scrap and progress.
- [ ] 60 fps on my phone with 250 zombies and an evolved build on screen.