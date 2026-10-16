# Part 1 - early tuning (audio cannot block delivery)

Baseline: playable 0.1.232 / c43b6c29ebdb40f766a753ea04fb09808427634e. Preserve the accepted movement, icons, two-line cards, wave rhythm, top banners and killer labels.

Data: godot/data/early_tuning.json sets waves 1-3 pressure and enemy damage to 75%, wave 4 to 87.5%, wave 5 onward to 100%. Anti-camp timing/radius/rate multipliers are unchanged. Existing per-wave min-HP telemetry remains active. The target of most human deaths in waves 5-9 is a playtest goal, not a claim established by scripted trials.

Pumps and barrels never enter auto-target selection. Facing-projectile hits, molotov/rocket splash, enemy/boss contact or fire can heat them. Three separated hits arm a one-second warning. The first and second hits show an amber/hot glow. A spent explosive stays spent for the run. Provenance marks any player-triggered explosive, capped at 15% maximum HP; enemy/world explosions retain a 30% cap and the shared rolling damage budget remains. Debug/runtime tests cover unauthorized sources, hit counting, warning duration, caps and persistence.

Every GRAB crate and relay pad is checked individually for a 20-40m initial distance and a walkable path no longer than 40m. No teleports to chase the player; distances can grow after the player moves away. Tests cover multiple map locations.

The repeatable light-grey circular decoration found in the map source is the four asphalt stipple circles in tex_asphalt.svg, not loot. The renderer omits that decoration without overwriting approved artwork. Actual XP remains colored diamonds; promoted pickup icons remain. No recording was attached to this request, so this identifies the source found in code, not every possible dot in unseen footage.

Local validation uses the exact 0.1.232 exported GDScript dependencies recovered from the signed APK, with matching original sources restored where available, plus the new source overlay. GitHub CI compiles and validates the complete repository source before delivery. The existing seven regression suites are retained; the Stage 2 entry also runs the new 100-assertion tuning contract in addition to the previous 234 assertions. No CI workflow or ChatGPT permissions changes.

Status: RUNNING until signed APK, checksums and matching logs are delivered. Part 2 is a separate continuation after this checkpoint.
