from pathlib import Path
import json, re
root=Path(__file__).resolve().parents[1]
p=root/'godot/scripts/outskirts.gd'; s=p.read_text()
s=s.replace('const TILE := 128.0','const ActorPresentation = preload("res://scripts/actor_presentation.gd")\nconst ObjectiveGuidance = preload("res://scripts/objective_guidance.gd")\nvar actors: Node2D\nvar guidance: Node2D\nvar tactical_map: Control\n\nconst TILE := 128.0',1)
s=s.replace('\t"trucker": "res://art/curated/zombie_elite.png",','')
s=s.replace('var curated_enemy_textures: Dictionary = {}','var curated_enemy_textures: Dictionary = {}')
s=s.replace('\t_setup_ui()\n','\t_setup_ui()\n\tactors = ActorPresentation.new()\n\tactors.game = self\n\tadd_child(actors)\n\tguidance = ObjectiveGuidance.new()\n\tguidance.game = self\n\tadd_child(guidance)\n',1)
s=s.replace('\tvar tactical_map := Control.new()','\ttactical_map = Control.new()',1)
s=s.replace('banner.text = "WAVE 1: THE HORDE IS HERE\\nPOWER THE MINI-MART GENERATOR"','banner.text = "WAVE %d: THE HORDE IS HERE\\n%s" % [wave, guidance.label_text().to_upper() if guidance != null else "POWER THE MINI-MART GENERATOR"]')
s=s.replace('banner.text = "WAVE 2: PRESSURE RISING"','banner.text = "WAVE %d: PRESSURE RISING\\n%s" % [wave, guidance.label_text().to_upper() if guidance != null else "FIND THE OBJECTIVE"]')
s=s.replace('"radius": float(base.get("radius", 18.0))}', '"radius": ActorPresentation.radius_for(kind) if ActorPresentation.HEIGHT_RATIOS.has(kind) else float(base.get("radius", 18.0))}')
s=s.replace('elite["radius"] = float(elite["radius"]) * 1.35','elite["radius"] = ActorPresentation.radius_for(str(elite["kind"]), true)')
# Enemy artwork is entirely handled by the pooled renderer; retain the boss and telegraphs.
a=s.index('\t\tif curated_enemy_textures.has(kind):', s.index('func _draw_combat()'))
b=s.index('\t\tif bool(enemy.get("elite", false)):',a)
s=s[:a]+'''\t\tif kind == "trucker":
\t\t\tdraw_circle(p, radius, Color("#7e392f")) # Deferred boss placeholder, unchanged.
\t\tif kind == "brute" and float(enemy.get("charge", 0.0)) < 0.0:
\t\t\tdraw_line(p, p + Vector2(enemy.get("charge_target", Vector2.RIGHT)) * 450.0, Color.ORANGE, 12.0)
'''+s[b:]
s=s.replace('\tdraw_circle(player_pos + Vector2(6,14), 35, Color(0.02,0.02,0.02,0.58))','\t# Shared actor renderer supplies foot-anchored survivor shadow and texture.')
s=s.replace('\tdraw_texture_rect(SURVIVOR_ART, Rect2(player_pos + recoil_vector - Vector2(48,48) * visual_scale, Vector2(96,96) * visual_scale), false, survivor_tint)','\t# Survivor art is rendered in the same Y-sorted actor layer as enemies.')
# Capture never revives or fakes survival. Do not stop a title-to-play capture at an arbitrary death.
s=s.replace('if capture_mode and not capture_death_triggered:\n\t\t\tprint("STAGE1_CAPTURE_DEATH wave=%d t=%.1f level=%d" % [wave, run_clock, progression.level if progression != null else 1])\n\t\t\tplayer_hp = player_max_hp\n\t\t\tplayer_hit_invulnerability = 1.0','if capture_mode and not capture_death_triggered:\n\t\t\tprint("STAGE1_CAPTURE_DEATH wave=%d t=%.1f level=%d" % [wave, run_clock, progression.level if progression != null else 1])')
p.write_text(s)
# Strengthen live objective text and discard stale wave banners across transitions.
p=root/'godot/scripts/polish_hud.gd'; s=p.read_text()
s=s.replace('var edge_arrow_timer := 0.0','var edge_arrow_timer := 0.0\nvar direction_label: Label\nvar previous_wave := 0')
s=s.replace('Rect2(8, 158, 298, 128)','Rect2(8, 148, 400, 130)')
s=s.replace('Vector2(270, 114)','Vector2(370, 114)').replace('Vector2(194, 114)','Vector2(306, 114)')
s=s.replace('Vector2(194, 70)','Vector2(306, 58)')
s=s.replace('objective_label = _label("POWER THE MINI-MART GENERATOR", 30, stack)','objective_label = _label("POWER THE MINI-MART GENERATOR", 28, stack)')
s=s.replace('supplies_label.custom_minimum_size = Vector2(115, 34)','supplies_label.custom_minimum_size = Vector2(115, 26)\n\tdirection_label = _label("", 22, stack)\n\tdirection_label.add_theme_color_override("font_color", AMBER)')
a=s.index('\tif not game.generator_active:', s.index('func _process')); b=s.index('\tvar message: String = game.banner.text',a)
s=s[:a]+'''\tif game.guidance != null:
\t\tobjective_label.text = game.guidance.label_text().to_upper()
\t\tvar kind: String = game.guidance.target.get("kind", "exit")
\t\tobjective_icon.text = {"crate": "\u25a3", "bolt": "\u26a1", "skull": "\u2620", "relay": "\u25c7"}.get(kind, "\u25c6")
\t\tvar direction: Vector2 = game.guidance.direction_vector()
\t\tvar arrows := ["\u2192", "\u2198", "\u2193", "\u2199", "\u2190", "\u2196", "\u2191", "\u2197"]
\t\tvar direction_index := posmod(roundi(direction.angle() / (PI / 4.0)), 8)
\t\tdirection_label.text = "%d m %s  |  TAP MAP" % [game.guidance.distance_metres(), arrows[direction_index]] if not game.guidance.target.is_empty() else "SURVIVE THE HORDE"
\tif previous_wave != game.wave:
\t\tprevious_wave = game.wave
\t\tbanner_queue.clear()
\t\tevent_time = 0.0
\t\tprevious_event = ""
'''+s[b:]
# Old queued wave headlines are formatted from live wave/objective, never copied stale.
s=s.replace('\t\tvar headline: String = parts[0]', '\t\tvar headline: String = parts[0]')
s=s.replace('\t\tvar detail: String = parts[1] if parts.size() > 1 else ""', '''\t\tvar detail: String = parts[1] if parts.size() > 1 else ""
\t\tif headline.begins_with("WAVE ") and not "CLEARED" in headline:
\t\t\theadline = "WAVE %d: THE HORDE IS HERE" % game.wave
\t\t\tdetail = game.guidance.label_text() if game.guidance != null else detail''')
a=s.index('\tvar target: Vector2 = game.GENERATOR_POS', s.index('func _draw()')); b=s.index('\tvar runner_arrows := 0',a)
s=s[:a]+'''\tif game.guidance != null and not game.guidance.target.is_empty():
\t\t_draw_edge_arrow(game.guidance.target["pos"], AMBER, "!", safe_rect, center, game.camera.zoom)
'''+s[b:]
p.write_text(s)
# Fractional XP keeps every drop's credit deterministic; first six XP retain the initial level-up.
p=root/'godot/scripts/phase_a_progression.gd'; s=p.read_text()
s=s.replace('var xp_collected_total := 0','var xp_collected_total := 0\nvar xp_collected_raw := 0\nvar xp_credit_remainder := 0.0')
s=s.replace('func _collect_xp(amount: int) -> void:\n\txp_collected_total += amount\n\tadd_xp(amount)', '''func _collect_xp(amount: int) -> void:
\txp_collected_raw += amount
\tvar multiplier := 1.0 if level < 2 else float(config.get("xp", {}).get("collection_multiplier", 0.60))
\txp_credit_remainder += amount * multiplier
\tvar credited := floori(xp_credit_remainder + 0.00001)
\txp_credit_remainder -= credited
\txp_collected_total += credited
\tadd_xp(credited)''')
p.write_text(s)
p=root/'godot/data/phase_a.json'; cfg=json.loads(p.read_text()); cfg['xp']['collection_multiplier']=0.60; p.write_text(json.dumps(cfg,indent=2,ensure_ascii=False)+'\n')
# Keep fallback identical to shipping config rather than carrying older difficulty values.
fallback='extends RefCounted\n\nstatic func get_config() -> Dictionary:\n\tvar parsed = JSON.parse_string('+json.dumps(p.read_text())+')\n\tif parsed is Dictionary:\n\t\treturn (parsed as Dictionary).duplicate(true)\n\treturn {}\n'
(root/'godot/scripts/gameplay_config_fallback.gd').write_text(fallback)
# Real title/start screen for both the APK and the capture; no synthetic capture-only splash.
p=root/'godot/scripts/phase_a_ui.gd'; s=p.read_text()
s=s.replace('if capture_mode:\n\t\t_start_capture_title()', '''if capture_mode:
\t\t_start_capture_title()
\telif not get_tree().has_meta("deadshift_run_started") and not OS.get_cmdline_user_args().has("--no-title"):
\t\t_show_main_menu()''',1)
a=s.index('func _start_capture_title()'); b=s.index('func _capture_elapsed()',a)
s=s[:a]+'''func _start_capture_title() -> void:
\t_show_main_menu()
\t_finish_capture_title()

func _finish_capture_title() -> void:
\tawait get_tree().create_timer(3.0, true, false, true).timeout
\t_start_from_title()
\tcapture_start_msec = Time.get_ticks_msec()
\tprint("PACING_CAPTURE_GAMEPLAY_START")

func _start_from_title() -> void:
\tmain_menu_panel.visible = false
\tget_tree().set_meta("deadshift_run_started", true)
\tget_tree().paused = false

'''+s[b:]
s=s.replace('start.pressed.connect(_retry_run)','start.pressed.connect(_start_from_title)')
s=s.replace('func _retry_run() -> void:\n\tget_tree().paused = false','func _retry_run() -> void:\n\tget_tree().set_meta("deadshift_run_started", true)\n\tget_tree().paused = false')
# Recorded game over stays on screen; frame-limited capture exits normally after 3 minutes.
s=s.replace('if capture_mode:\n\t\t_capture_finish_after_game_over()', 'if capture_mode:\n\t\tprint("PACING_GAME_OVER_VISIBLE")')
s=s.replace('if active_modal != "" or modal_queue.is_empty():', 'if active_modal != "" or modal_queue.is_empty():')
p.write_text(s)

# Final validated collision IDs, layout and capture guards.
p=root/'godot/scripts/outskirts.gd'; s=p.read_text()
a=s.index('const CURATED_ZOMBIE_ART'); b=s.index('var curated_pickup_textures',a); s=s[:a]+s[b:]
a=s.index('\tfor kind in CURATED_ZOMBIE_ART:'); b=s.index('\tvar pickup_paths :=',a); s=s[:a]+s[b:]
s=s.replace('var spawn := _nearest_walkable_position(candidate, 15.0 if is_runner else 18.0)','var spawn := _nearest_walkable_position(candidate, ActorPresentation.radius_for("runner" if is_runner else "shambler"))')
s=s.replace('enemies.append({"pos": spawn, "kind": "runner" if is_runner else "shambler"', 'enemies.append({"uid": _next_uid(), "pos": spawn, "kind": "runner" if is_runner else "shambler"')
s=s.replace('"radius": 15.0 if is_runner else 18.0, "charge": 0.0, "trap_guard": color','"radius": ActorPresentation.radius_for("runner" if is_runner else "shambler"), "charge": 0.0, "trap_guard": color')
s=s.replace('var spawn_radius := 15.0 if is_runner else 18.0','var spawn_radius := ActorPresentation.radius_for("runner" if is_runner else "shambler")')
s=s.replace('enemies.append({\n\t\t\t"pos": spawn,','enemies.append({\n\t\t\t"uid": _next_uid(),\n\t\t\t"pos": spawn,')
p.write_text(s)
p=root/'godot/scripts/polish_hud.gd'; s=p.read_text()
s=s.replace('_label("POWER THE MINI-MART GENERATOR", 28, stack)','_label("POWER THE MINI-MART GENERATOR", 24, stack)').replace('objective_label.custom_minimum_size = Vector2(306, 58)','objective_label.custom_minimum_size = Vector2(306, 32)').replace('supplies_label = _label("SUPPLIES 0/3", 26, crates)','supplies_label = _label("SUPPLIES 0/3", 22, crates)').replace('direction_label = _label("", 22, stack)','direction_label = _label("", 20, stack)')
s=s.replace('\tvar message: String = game.banner.text','\tif event_time > 0.0 and banner_title.text.begins_with("WAVE ") and not "CLEARED" in banner_title.text and game.guidance != null:\n\t\tbanner_subtitle.text = game.guidance.label_text()\n\tvar message: String = game.banner.text')
p.write_text(s)
p=root/'godot/scripts/phase_a_ui.gd'; s=p.read_text()
s=s.replace('and not OS.get_cmdline_user_args().has("--no-title"):', 'and not OS.get_cmdline_user_args().has("--no-title") and not OS.get_cmdline_args().has("--script"):')
s=s.replace('func _start_from_title() -> void:\n\tmain_menu_panel.visible = false','func _start_from_title() -> void:\n\tif game.player_hp <= 0:\n\t\t_retry_run()\n\t\treturn\n\tmain_menu_panel.visible = false')
p.write_text(s)
