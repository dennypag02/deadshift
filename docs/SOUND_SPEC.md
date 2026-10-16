# DeadShift – Sound & Music Spec

**Goal:** make DeadShift sound as big as it plays — punchy weapons, satisfying rewards, a driving soundtrack — without ever becoming annoying, and without costing money.

Builds on: `POLISH_SPEC.md`, `CORE_LOOP_SPEC.md`, `BOSS_SPEC_TRUCKER.md`, `ASSET_PIPELINE.md`. Where this conflicts with them, this spec wins for audio.

---

## 1. Direction & rules

1. **Gritty highway apocalypse, not haunted house.** Music is driving dirty-rock / dark-synth action. Sound effects are chunky, mechanical and loud — scrap metal, diesel, shotguns, fire.
2. **The game must be 100% playable with sound off.** Many mobile players play muted. Every warning stays visual; sound only reinforces it.
3. **Zombies are mostly silent.** No ambient moaning. Only special enemies get a voice, and only at meaningful moments (see §5). A zombie sound should mean "pay attention."
4. **Rewards sound better than damage.** XP, level-ups, chests and puzzle completions get the most satisfying sounds in the game.
5. **Nothing repeats robotically.** Every repeated sound gets random pitch/volume variation and a cap on simultaneous copies.
6. **Free and local only** (same rule as art). Sources allowed: Sonniss GDC bundles, Kenney CC0 packs, jsfxr, Freesound **CC0/CC-BY only** (never NC), Pixabay Music, incompetech (CC-BY), and Stable Audio 3 running in my local ComfyUI.
7. **Every file is logged in `CREDITS.md`** (§9) before it enters the game.
8. **Ask before installing** anything (ComfyUI updates, models, ffmpeg, Python packages beyond `requests`, `Pillow`, `pyyaml`).

---

## 2. Godot audio setup

### Buses
| Bus | Default volume | Notes |
|---|---|---|
| Master | 100% | |
| Music | 70% | Has a **LowPassFilter** effect (used by the adaptive music, §4) |
| SFX | 85% | Has a **Limiter** effect (ceiling −1 dB) so 200 explosions don't clip |
| UI | 80% | Menus, cards, buttons |

### Settings menu
- Sliders: **Music**, **Effects**, **UI** (0–100%), plus a **Mute all** toggle. Saved between sessions.
- Also reachable from the pause menu.
- Pause all audio when the app goes to the background; resume on return.

### Voice management (performance + no-annoyance)
- One `SoundManager` autoload. Gameplay code calls `SoundManager.play("shotgun_fire", position)` — never creates players directly.
- Pool of AudioStreamPlayer2D nodes (start with 24). **Hard cap 32 simultaneous sounds.**
- Per-sound settings in a data file (`sounds.json` or `.tres`): `max_instances`, `cooldown_ms`, `pitch_range`, `volume_db`, `priority`.
- Default variation: pitch ±8%, volume ±2 dB. Sounds with 2–4 file variants pick randomly, never the same one twice in a row.
- When the cap is hit, drop the **lowest-priority, quietest** sound — never a warning or reward sound.
- Preload all SFX at run start (with the shader warm-up). Music streams from disk.

### Formats
- SFX: `.wav`, 44.1 kHz, mono (stereo only for big explosions/ambience), trimmed with no silence at the start.
- Music: `.ogg` (Vorbis, ~128–160 kbps), loop enabled in the import settings.
- Loudness: music normalized to about **−16 LUFS**; SFX peaks at **−1 dBFS**. Normalize in the pipeline (§7), not by ear.

---

## 3. Mix priorities (what you hear first)

1. **Warnings** — boss telegraphs, spitter landing, brute charge wind-up, low-HP heartbeat
2. **Rewards** — level-up, chest, puzzle complete, evolution
3. **Player weapons** — but quieter than you'd expect; they play constantly
4. **Explosions / hazards**
5. **Enemy deaths & hits** — short, low, heavily capped
6. **Music**
7. **Ambience**

**Ducking:** during the boss intro, level-up screen and big banners, the Music bus drops by 6 dB (0.3 s in, 0.8 s out).

---

## 4. Music

### The adaptive trick (one track, two moods)
We don't need separate "calm" and "intense" versions that perfectly match. Use the **same gameplay track** and change the Music bus low-pass filter:

| Wave phase (from the wave rhythm) | Low-pass cutoff | Music volume |
|---|---|---|
| Breather / break | 900 Hz (muffled, "distant") | −4 dB |
| Announce | 900 → 20,000 Hz over 2 s | ramps to 0 dB |
| Event | 20,000 Hz (full) | 0 dB |
| Surge | full + **surge stinger** on entry | +1 dB |
| Level-up screen / pause | 600 Hz | −6 dB |
| HP below 25% | full + heartbeat SFX layered on top | 0 dB |

Transitions are smooth tweens (1.5 s), never cuts. This makes the game feel dynamic with a single track.

### The pieces
| # | Piece | Length | Tempo | Loop? | Notes |
|---|---|---|---|---|---|
| M1 | **Title theme** | 60–90 s | ~100 BPM | yes | Heavy, slow-burn riff. Sells the mood in the first 10 s. |
| M2 | **Outskirts gameplay** | 90–120 s | ~140 BPM | yes | Driving drums + dirty guitar/synth. The filter trick does the rest. |
| M3 | **Boss: The Trucker** | 90–120 s | ~160 BPM | yes | Faster and heavier than M2. Starts on the horn blast. |
| M4 | **Game over** | 3–5 s | — | no | Low, heavy, a little mournful. Not a sad trombone. |
| M5 | **Victory / boss defeated** | 4–6 s | — | no | Big, triumphant riff hit. |

Later districts each get their own gameplay track and boss track.

- On the Trucker's **phase 3** ("Diesel Inferno"), raise M3's playback pitch slightly (+3%) and add the distorted engine drone ambience on top — cheap, and it feels like an escalation.
- Music never stops abruptly: fade out 0.5 s for game over/victory stingers.

### Generating music (Stable Audio 3, local ComfyUI)
Use the official ComfyUI template **"Stable Audio 3 Small Music"** (or **Medium** if my GPU handles it). Generate **6 versions** per piece; I pick.

Common negative: `vocals, singing, lyrics, speech, choir, orchestral, cinematic strings, lo-fi, muffled, distorted clipping, fade out, silence`

| Piece | Prompt |
|---|---|
| M1 Title | `gritty dark rock instrumental, heavy slow distorted guitar riff, pounding tom drums, ominous synth drone, post-apocalyptic highway, 100 BPM, game title theme, loopable` |
| M2 Gameplay | `high energy action rock instrumental, driving drums, dirty overdriven guitar riff, aggressive bass, dark synth stabs, relentless, video game combat loop, 140 BPM, loopable` |
| M3 Boss | `intense heavy metal boss battle instrumental, double kick drums, chugging downtuned guitars, diesel engine roar, truck horn hits, menacing, 160 BPM, video game boss fight loop` |
| M4 Game over | `short heavy rock ending, single low distorted guitar chord ringing out, deep drum hit, ominous, 4 seconds` |
| M5 Victory | `short triumphant rock fanfare, big guitar power chord riff, crash cymbal, victorious, 5 seconds` |

**Backup if the generated music isn't good enough:** Pixabay Music (no credit needed) or incompetech.com (credit line) — search "action rock", "industrial", "dark synth". Log in `CREDITS.md`.

### Making loops seamless (agent)
AI tracks rarely loop perfectly. The pipeline should: find a loop point on a downbeat near the end, crossfade the last 50–100 ms into the start, and export the `.ogg` with Godot loop points. I approve by ear in the review page (§7).

---

## 5. Sound effects list

Source key: **SON** = Sonniss GDC bundle · **KEN** = Kenney CC0 · **JSFXR** = jsfxr (made by the agent) · **SA3** = Stable Audio 3 Small SFX (local ComfyUI) · **FS** = Freesound CC0/CC-BY.
`max` = max simultaneous copies.

### Weapons
| Name | Sound | Source | max | Notes |
|---|---|---|---|---|
| smg_fire | Short, light, mechanical bursts | SON | 3 | 3 variants. Quiet — it fires constantly. |
| shotgun_fire | Big boom + shell rack | SON | 2 | Signature sound; make it meaty. |
| molotov_throw / molotov_burst | Glass whoosh / glass smash + fire whoomp | SON | 2 / 3 | |
| buzzsaw_loop | Spinning metal whir (loop) | SON | 1 | One loop regardless of saw count. |
| lightning_zap | Electric crack | SON | 3 | |
| rocket_launch / rocket_hit | Whoosh / explosion (small) | SON | 2 / 3 | |
| drone_fire | Tiny rapid pew | JSFXR | 2 | |
| hubcap_throw | Metal spinning whoosh + clang | SON | 2 | |
| evolution_fire_layer | Extra low "thump" under evolved weapons | SON | 2 | Makes evolutions *feel* stronger. |

### Player
| Name | Sound | Source | max | Notes |
|---|---|---|---|---|
| player_hurt | Body hit + grunt (short) | SON | 1 | Cooldown 300 ms. |
| low_hp_heartbeat | Heartbeat loop below 25% HP | SON | 1 | Stops when healed. |
| player_death | Heavy impact + music cut | SON | 1 | |
| footsteps | — | — | — | **Skip.** Not needed and would get annoying. |

### Enemies (voices kept to a minimum)
| Name | Sound | Source | max | Notes |
|---|---|---|---|---|
| zombie_hit | Soft wet thud | SON | 4 | Cooldown 40 ms. Very quiet. |
| zombie_death | Short squelch/crunch | SON | 4 | 4 variants. Quiet. |
| runner_pack_shriek | One shriek when a runner pack appears | SA3 | 1 | Cooldown 6 s. Paired with the off-screen arrows. |
| bloater_pop | Wet pop + goo splash | SA3 | 2 | Satisfying, not gross-loud. |
| spitter_spit | Hock + whistle of the acid lob | SA3 | 2 | Plays with the orange landing circle. |
| acid_land | Sizzle | SON | 2 | |
| brute_roar | Short roar at charge wind-up | SA3 | 1 | Warning sound — high priority. |
| brute_slam | Heavy impact when the charge hits | SON | 1 | |
| elite_spawn | Low gold "shimmer" + growl | SA3 | 1 | |
| mechanic_wrench | Wrench clang, tank hiss on wind-up | SON + SA3 | 1 | |

Regular shamblers have **no voice**.

### Pickups & progression (the most satisfying sounds)
| Name | Sound | Source | max | Notes |
|---|---|---|---|---|
| xp_gem | Tiny bright blip | JSFXR | 6 | **Pitch rises** with each gem collected in quick succession (+1 semitone per gem within 0.3 s, resets after). Classic, addictive. |
| level_up | Rising chime + whoosh | JSFXR + SON | 1 | |
| card_hover / card_pick | Soft tick / solid confirm | KEN | 1 | |
| reroll / banish | Shuffle / swipe | KEN | 1 | |
| chest_open | Creak + rising sparkle | SON + JSFXR | 1 | Longer and bigger for big chests. |
| evolution | Big power-up riser + impact | SA3 | 1 | Second-best sound in the game after the boss kill. |
| pickup_rage / mega_gun / nuke / magnet / freeze / medkit | One distinct sound each | SON / JSFXR | 1 | Nuke = huge boom + ringing. Freeze = icy crack. |

### Objectives & world
| Name | Sound | Source | max | Notes |
|---|---|---|---|---|
| event_announce | Radio crackle + alert tone | SON | 1 | Plays with the objective card. |
| event_progress | Soft rising tick while holding a zone | JSFXR | 1 | |
| event_complete | Stinger: confirm hit + reward chime | JSFXR + SON | 1 | |
| event_failed | Low muted "bwomp" | JSFXR | 1 | Gentle — failing isn't punished. |
| surge_warning | Alarm swell (1 s) at surge start | SON | 1 | |
| wave_cleared | Short riff hit / stinger | SA3 (music) | 1 | |
| pump_explode | Huge explosion + metal debris | SON | 2 | |
| barrel_explode | Explosion (smaller) | SON | 3 | |
| fire_loop | Crackling fire (loop) | SON | 2 | Positional; fades with distance. |
| oil_ignite | Whoomp | SON | 2 | |
| turret_fire | Mechanical rattle | SON | 1 | |
| airstrike | Jet flyby + whistle + explosion | SON | 1 | |
| ambience_outskirts | Wind, distant sirens, faint metal creaks (loop) | SON | 1 | Very low under the music. |

### Boss: The Trucker
| Name | Sound | Source | Notes |
|---|---|---|---|
| trucker_horn | Massive air horn | SON | Intro + Horn Blast attack. |
| trucker_roar | Monstrous roar | SA3 | Intro and phase changes only. |
| trucker_engine_rev | Revving diesel (charge telegraph) | SON | Warning — top priority. |
| trucker_charge_impact | Huge metal crash | SON | |
| plate_break | Metal shatter + ring | SON | Must feel amazing. |
| chain_whip | Chain swing whoosh + crack | SON | |
| trailer_drag | Scraping metal loop | SON | |
| weak_point_hit | Bright metallic "ding" layer | JSFXR | Tells the player "this is working." |
| boss_victory | Explosion + slow-mo whoosh, then M5 | SON | |

### UI
| Name | Source |
|---|---|
| button_tap, back, toggle, slider_tick | KEN |
| pause_open / pause_close | KEN |

### Generated SFX prompts (Stable Audio 3 Small SFX)
Generate **4 versions** each. Common negative: `music, melody, speech, words, singing, background noise, reverb tail, silence`

| Name | Prompt |
|---|---|
| runner_pack_shriek | `short feral zombie shriek, raspy, aggressive, close, 1 second` |
| bloater_pop | `wet fleshy balloon pop with thick goo splash, squelch, 1 second` |
| spitter_spit | `wet throat hock and spit, then a short whistling projectile, 1 second` |
| brute_roar | `deep monstrous roar, heavy breath, short and powerful, 1.5 seconds` |
| elite_spawn | `low eerie shimmer with a deep growl, magical golden power, 1.5 seconds` |
| mechanic_wrench (hiss part) | `pressurized fuel tank hiss building up, metal creak, 1.5 seconds` |
| evolution | `epic power up riser building to a heavy impact boom, sci-fi energy, 2 seconds` |
| trucker_roar | `gigantic monster roar mixed with diesel engine growl, terrifying, 3 seconds` |

---

## 6. Haptics pairing
Haptics go through the single safe vibration helper (VIBRATE permission stays). Pair, don't spam:
- Light tap: level-up, chest open, event complete
- Medium: player hurt (cooldown 300 ms)
- Heavy: pump explosion near the player, plate break, boss charge impact
- Settings toggle: **Vibration on/off**.

---

## 7. Audio pipeline (same workflow as the art)

```
sounds.yaml  →  generate_audio.py  →  staging/audio/<name>/<name>_v1..v6.wav   (SA3 via my local ComfyUI API)
find_sfx.py  →  staging/audio/<name>/  (shortlist copied from the Sonniss/Kenney folders by keyword)
             →  review_audio.py → review_audio.html (one row per sound, an audio player per version)
             →  I pick → picks_audio.yaml
             →  promote_audio.py → trims silence, normalizes loudness, converts (wav/ogg), sets loop points
                                 → res://audio/sfx/<name>.wav, res://audio/music/<name>.ogg
                                 → appends the entry to CREDITS.md
```

- **sounds.yaml** fields per sound: `name`, `type` (sfx/music), `source` (sa3 / library / jsfxr), `prompt` + `negative` (sa3), `keywords` (library search), `length_s`, `count`, `loop`, `seed`.
- **generate_audio.py:** uses the official Stable Audio 3 ComfyUI template exported in API format; one job at a time; records prompt, seed, model and settings in `manifest_audio.json`.
- **find_sfx.py:** searches my downloaded library folders (path set in a config, e.g. `D:/SFX/Sonniss_GDC`) by filename keywords and copies the **top 6 matches** per sound into staging. Never modifies the library.
- **jsfxr sounds:** the agent may create these with a small script (sfxr parameters stored in `sounds.yaml` so they're reproducible).
- **review_audio.html:** opens locally in my browser; each sound shows its versions as players with the name, source and license.
- **promote_audio.py:** same safety rules as `promote.py` — never overwrite anything in `res://audio/` without asking; write `<name>_new` and tell me.
- Loudness normalization and conversion need **ffmpeg** — **ask me before installing it**.
- `staging/audio/` stays out of git.

### Setup I do on my PC (agent: list exact steps, don't do it unasked)
1. Update ComfyUI to **0.22.0 or newer**.
2. Open the template **"Stable Audio 3 Small SFX"** (and **"Small Music"**), download the models it asks for, and run one test generation.
3. Download the **Sonniss GDC Game Audio Bundle** (gdc.sonniss.com — this year's and earlier years') and the Kenney audio packs into one folder, e.g. `D:/SFX/`.
4. Tell the agent the folder path.

---

## 8. Implementation order

| Step | What | Stop & send me |
|---|---|---|
| **A. Systems** | Buses, settings menu, SoundManager with pooling/caps/variation, data file, ducking, low-pass adaptive music hooks. Use **placeholder jsfxr sounds** for everything so the timing can be tested now. | Recording with sound on |
| **B. Pipeline** | `sounds.yaml`, `find_sfx.py`, `generate_audio.py`, review page, `promote_audio.py`, `CREDITS.md`. Dry run. | Exact commands for my PC |
| **C. SFX pass** | After I pick & promote: swap placeholders for real sounds, tune volumes against the mix priorities. | Recording |
| **D. Music** | Wire M1–M5 with the adaptive filter. | Recording of a full wave cycle (breather → surge) |
| **E. Boss audio** | Trucker sounds + M3 when the boss build happens. | With the boss stage |

Don't block the current gameplay fixes (unfair death, anti-camping, objectives) — audio step A can run alongside them, but those come first if there's a conflict.

---

## 9. CREDITS.md format

```
| File | Source | Author / pack | License | Attribution needed | Notes |
|---|---|---|---|---|---|
| shotgun_fire.wav | Sonniss GDC 2026 | <vendor pack name> | Sonniss GDC license (royalty-free) | No | trimmed, normalized |
| xp_gem.wav | jsfxr | made in-house | Own work | No | params in sounds.yaml |
| bloater_pop.wav | Stable Audio 3 Small SFX (local) | generated | Stability AI Community License | No | seed 12345 |
| title_theme.ogg | Pixabay Music | <artist> | Pixabay Content License | No | |
```
Anything CC-BY gets its credit line on an in-game **Credits** screen (Settings → Credits).

---

## 10. Definition of done
- [ ] With sound on, every warning, reward and weapon has a sound, and nothing feels repetitive after 10 minutes.
- [ ] With sound off, the game plays exactly the same.
- [ ] Shamblers are silent; special-enemy voices are rare and meaningful.
- [ ] Music muffles in breathers, opens up in events, hits harder in surges — and never cuts abruptly.
- [ ] XP gem pickup pitch-climb feels addictive.
- [ ] No clipping during the biggest explosions (limiter works); max 32 voices.
- [ ] Music / Effects / UI / Vibration settings work and persist.
- [ ] Every file is in `CREDITS.md` with a commercial-safe license.
- [ ] 60 fps on my phone with full audio.
