extends "res://scripts/tuned_game.gd"
var audio_ready := false
var audio_snapshot: Dictionary = {}
var audio_sample_clock := 0.0
var hold_sound_clock := 0.0
var audio_settings_panel: CanvasLayer
var sound_observer: Node
class SoundObserver:
	extends Node
	var game: Node2D
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		game.update_audio(delta)

func _ready() -> void:
	super._ready()
	audio_ready = true
	SoundManager.listener = player_pos
	audio_settings_panel = preload("res://scripts/audio_settings.gd").new()
	audio_settings_panel.game = self
	add_child(audio_settings_panel)
	var observer := SoundObserver.new()
	observer.game = self
	add_child(observer)
	sound_observer = observer
	if phase_ui.main_menu_panel.visible: SoundManager.start_music("title_theme")
	else: SoundManager.start_music("outskirts_gameplay")
	run_log.emit("audio_ready",SoundManager.report())
	for button in phase_ui.card_buttons:
		button.mouse_entered.connect(func()->void: SoundManager.play("card_hover"))

func _setup_ui() -> void:
	super._setup_ui()
	var old_progression: Node = progression
	remove_child(old_progression)
	old_progression.queue_free()
	progression = preload("res://scripts/audio_progression.gd").new()
	progression.game = self
	add_child(progression)
	var old_ui: Control = phase_ui
	var ui_parent := old_ui.get_parent()
	ui_parent.remove_child(old_ui)
	old_ui.queue_free()
	phase_ui = preload("res://scripts/audio_ui.gd").new()
	phase_ui.game = self
	phase_ui.progression = progression
	ui_parent.add_child(phase_ui)

func _haptic_pulse(duration: int = 30) -> void:
	if bool(SoundManager.settings.vibration): super._haptic_pulse(duration)

func _update_bullets(delta: float) -> void:
	var smg := false
	var shotgun := false
	for bullet in bullets:
		if not bool(bullet.get("facing_bound",false)):
			if float(bullet.life)>1.0: smg = true
			else: shotgun = true
	if smg: SoundManager.play("smg_fire")
	if shotgun: SoundManager.play("shotgun_fire")
	if (smg or shotgun) and not progression.evolutions.is_empty(): SoundManager.play("evolution_fire_layer")
	super._update_bullets(delta)

func phase_b_damage_enemy(index: int, raw_damage: float, crit: bool, source: String) -> bool:
	if index>=0 and index<enemies.size() and raw_damage>0: SoundManager.play("zombie_hit",enemies[index].pos)
	return super.phase_b_damage_enemy(index,raw_damage,crit,source)

func _phase_a_kill_enemy(index: int) -> void:
	if index>=0 and index<enemies.size():
		SoundManager.play("zombie_death",enemies[index].pos)
		if str(enemies[index].kind)=="bloater": SoundManager.play("bloater_pop",enemies[index].pos)
	super._phase_a_kill_enemy(index)

func _warn_acid(enemy: Dictionary) -> void:
	super._warn_acid(enemy)
	SoundManager.play("spitter_spit",enemy.pos)

func add_hazard(kind: String, at: Vector2, radius: float, lifetime: float, source: String, owner_uid: int) -> void:
	super.add_hazard(kind,at,radius,lifetime,source,owner_uid)
	if kind=="acid": SoundManager.play("acid_land",at)

func _update_enemy(enemy: Dictionary, delta: float) -> void:
	var before := float(enemy.get("charge",0))
	super._update_enemy(enemy,delta)
	var after := float(enemy.get("charge",0))
	if str(enemy.kind)=="brute":
		if before>=0 and after<0: SoundManager.play("brute_roar",enemy.pos)
		if before>0 and after<=0: SoundManager.play("brute_slam",enemy.pos)
	elif str(enemy.kind)=="mech_miniboss" and before>=0 and after<0:
		SoundManager.play("mechanic_wrench",enemy.pos)

func _append_enemy(kind: String, at: Vector2) -> void:
	var before := enemies.size()
	super._append_enemy(kind,at)
	if enemies.size()>before:
		if kind=="runner": SoundManager.play("runner_pack_shriek",at)
		elif kind=="elite": SoundManager.play("elite_spawn",at)

func _detonate_pump(at: Vector2) -> void:
	var id := "pump_explode"
	for pump in pumps:
		if Vector2(pump.pos).is_equal_approx(at) and pump.kind=="barrel": id = "barrel_explode"
	super._detonate_pump(at)
	SoundManager.play(id,at)

func _collect_phase_c_powerup(kind: String) -> void:
	super._collect_phase_c_powerup(kind)
	var id := "pickup_"+kind.to_lower().replace(" ","_")
	if kind in ["Chest","Upgrade crate"]: id = "chest_open"
	SoundManager.play(id)

func _finish_wave() -> void:
	var was_active := wave_active
	super._finish_wave()
	if was_active: SoundManager.play("wave_cleared")

func _try_unlock_district() -> void:
	var before := district_cleared
	super._try_unlock_district()
	if district_cleared and not before:
		SoundManager.play("boss_victory")
		SoundManager.start_music("victory_music")

func update_audio(delta: float) -> void:
	if not audio_ready: return
	SoundManager.listener = player_pos
	vibration_enabled = bool(SoundManager.settings.vibration)
	hud_overlay.vibration_enabled = bool(SoundManager.settings.vibration)
	var dt := delta/maxf(0.02,Engine.time_scale)
	var levelup: bool = phase_ui.panel.visible
	var paused_now: bool = get_tree().paused and not phase_ui.main_menu_panel.visible
	var alive := player_hp>0
	var active := alive and not get_tree().paused
	var now_phase: String = events.rhythm()
	if levelup: now_phase = "levelup"
	elif paused_now: now_phase = "pause"
	elif alive and float(player_hp)/player_max_hp<float(SoundManager.config.low_hp_threshold): now_phase = "low_hp"
	SoundManager.set_phase(now_phase)
	SoundManager.duck("banner",hud_overlay.backdrop.visible)
	SoundManager.duck("levelup",levelup)
	SoundManager.duck("reveal",guidance.briefing)
	SoundManager.loop_sound("buzzsaw_loop",active and progression.weapons.has("buzzsaw"))
	SoundManager.loop_sound("low_hp_heartbeat",alive and not phase_ui.main_menu_panel.visible and float(player_hp)/player_max_hp<float(SoundManager.config.low_hp_threshold))
	SoundManager.loop_sound("ambience_outskirts",active)
	var fire_point := Vector2.INF
	if active and not progression.molotov_pools.is_empty(): fire_point = progression.molotov_pools[0].pos
	SoundManager.loop_sound("fire_loop",fire_point!=Vector2.INF,fire_point)
	if player_hp<int(audio_snapshot.get("hp",player_hp)): SoundManager.play("player_hurt")
	var rows: int = run_log.rows.size()
	if rows>int(audio_snapshot.get("offered",0)): SoundManager.play("event_announce")
	var status_now: String = str(run_log.rows[-1].status) if rows>0 else "none"
	var summary: Dictionary = run_log.summary() if rows!=int(audio_snapshot.get("offered",0)) or status_now!=str(audio_snapshot.get("status","none")) else {}
	audio_snapshot.status = status_now
	if not summary.is_empty():
		if int(summary.events_completed)>int(audio_snapshot.get("completed",0)):
			SoundManager.play("event_complete")
			if rows>0 and run_log.rows[-1].kind=="oil": SoundManager.play("oil_ignite")
		if int(summary.events_missed)>int(audio_snapshot.get("missed",0)): SoundManager.play("event_failed")
		audio_snapshot.completed = summary.events_completed
		audio_snapshot.missed = summary.events_missed
	if active and not events.active.is_empty() and events.active.verb=="HOLD" and float(events.active.charge)>0:
		hold_sound_clock -= dt
		if hold_sound_clock<=0:
			hold_sound_clock = float(SoundManager.config.hold_tick_seconds)
			SoundManager.play("event_progress",Vector2.INF,1+events.progress_ratio()*0.5)
	if float(events.shot_left)>float(audio_snapshot.get("turret_shot",0)): SoundManager.play("turret_fire")
	if paused_now!=bool(audio_snapshot.get("paused",false)): SoundManager.play("pause_open" if paused_now else "pause_close")
	if bool(audio_snapshot.get("airstrike_owned",false)) and not events.earned.has("airstrike"): SoundManager.play("airstrike")
	audio_snapshot.airstrike_owned = events.earned.has("airstrike")
	audio_snapshot.merge({"hp":player_hp,"offered":rows,"paused":paused_now,"turret_shot":events.shot_left},true)
	audio_sample_clock += dt
	if audio_sample_clock>=float(SoundManager.config.audio_log_seconds):
		audio_sample_clock = 0
		run_log.emit("audio_sample",SoundManager.report())
