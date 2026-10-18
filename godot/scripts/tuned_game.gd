extends "res://scripts/movement_game.gd"
var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/early_tuning.json"))
var pump_contact_clock := 0.0
var firing_source := "facing_weapon"

func _ready() -> void:
	super._ready()
	MutationManager.reset_run()
	MutationManager.bind_game(self)
	rules.fairness.pump_warning_seconds = float(tuning.pumps.warning_seconds)
	rules.source_labels["player_pump_explosion"] = "Pump explosion"
	rules.source_labels["player_barrel_explosion"] = "Barrel explosion"
	rules.source_labels["barrel_explosion"] = "Barrel explosion"
	var old_events: Node = events
	remove_child(old_events)
	old_events.queue_free()
	events = preload("res://scripts/tuned_events.gd").new()
	events.game = self
	add_child(events)
	events.start_wave(wave)
	var old_fairness: Node = fairness
	remove_child(old_fairness)
	old_fairness.queue_free()
	fairness = preload("res://scripts/tuned_damage.gd").new()
	fairness.game = self
	add_child(fairness)
	var feedback := preload("res://scripts/pump_feedback.gd").new()
	feedback.game = self
	add_child(feedback)
	if bool(tuning.remove_decorative_asphalt_speckles):
		# Load OUTSIDE assert(): release exports strip assert() lines entirely, so the
		# old assert-wrapped load never ran and the asphalt drew as blank white quads.
		var image := Image.new()
		var svg_err := image.load_svg_from_string(str(tuning.asphalt_without_speckles))
		if svg_err == OK:
			var clean := ImageTexture.create_from_image(image)
			for batch in terrain_batches.batches:
				if batch.texture==TEX_ASPHALT: batch.texture = clean
		else:
			push_error("asphalt_without_speckles SVG failed to load: %d" % svg_err)
	run_log.emit("early_tuning",{"pressure_multipliers":tuning.pressure_by_wave,"enemy_damage_multipliers":tuning.enemy_damage_by_wave,"pump_hits":tuning.pumps.hits_required,"pump_warning_s":tuning.pumps.warning_seconds,"anti_camp_unchanged":true})

func wave_multiplier(key: String) -> float:
	var values: Array = tuning[key]
	return float(values[mini(maxi(wave-1,0),values.size()-1)])

func _active_horde_target() -> int:
	return roundi(super._active_horde_target()*wave_multiplier("pressure_by_wave"))

func _enemy_contact_damage(kind: String) -> int:
	return maxi(1,roundi(super._enemy_contact_damage(kind)*wave_multiplier("enemy_damage_by_wave")))

func _stage1_update_hazards(delta: float) -> void:
	var normal: float = rules.threats.acid_damage
	var early: float = rules.threats.early_acid_damage
	rules.threats.acid_damage = maxi(1,roundi(normal*wave_multiplier("enemy_damage_by_wave")))
	rules.threats.early_acid_damage = maxi(1,roundi(early*wave_multiplier("enemy_damage_by_wave")))
	super._stage1_update_hazards(delta)
	rules.threats.acid_damage = normal
	rules.threats.early_acid_damage = early

func _stage1_spawn_surge() -> void:
	var count: int = rules.pressure.surge_ring_count
	rules.pressure.surge_ring_count = roundi(count*wave_multiplier("pressure_by_wave"))
	super._stage1_spawn_surge()
	rules.pressure.surge_ring_count = count

func _setup_pumps() -> void:
	pumps.clear()
	for y in range(MAP_H):
		for x in range(MAP_W):
			if _tile_char(x,y) in ["P","b"]:
				pumps.append({"pos":_tile_center(x,y),"alive":true,"hits":0,"last_hit_s":-100.0,"player_caused":false,"kind":"barrel" if _tile_char(x,y)=="b" else "pump"})

func _reset_pumps() -> void:
	# Exploded pumps stay spent for this run; a new run constructs fresh dictionaries.
	if bool(tuning.pumps.reset_each_wave):
		for pump in pumps:
			pump.alive = true
			pump.hits = 0
			pump.player_caused = false

func _bullet_blocked_by(ch: String) -> bool:
	if ch=="b": return false
	return super._bullet_blocked_by(ch)

func _explode_pump(pump: Dictionary) -> void:
	# Called by the facing-projectile collision path, not by auto-target selection.
	heat_explosive(pump,firing_source,true)

func heat_explosive(pump: Dictionary, source: String, caused_by_player: bool) -> void:
	if not bool(pump.alive): return
	if source not in ["facing_weapon","molotov","rocket","carpet_bomber","enemy_contact","boss_contact","fire"]: return
	var cooldown: float = tuning.pumps.fire_hit_cooldown_seconds if source in ["molotov","fire"] else tuning.pumps.hit_cooldown_seconds
	if run_clock-float(pump.last_hit_s)<cooldown: return
	pump.last_hit_s = run_clock
	pump.hits = int(pump.hits)+1
	pump.player_caused = bool(pump.player_caused) or caused_by_player
	run_log.emit("explosive_hit",{"kind":pump.kind,"hits":pump.hits,"source":source,"player_caused":pump.player_caused,"x":pump.pos.x,"y":pump.pos.y})
	if int(pump.hits)<int(tuning.pumps.hits_required): return
	pump.alive = false
	add_hazard("pump_warning",pump.pos,float(rules.fairness.pump_radius),float(tuning.pumps.warning_seconds),"player_"+str(pump.kind)+"_explosion" if pump.player_caused else str(pump.kind)+"_explosion",-1)
	run_log.emit("pump_warning",{"kind":pump.kind,"player_caused":pump.player_caused,"warning_seconds":tuning.pumps.warning_seconds})

func heat_explosives_in_area(center: Vector2, radius: float, source: String, player_caused: bool = true) -> void:
	for pump in pumps:
		if Vector2(pump.pos).distance_to(center)<=radius: heat_explosive(pump,source,player_caused)

func _detonate_pump(at: Vector2) -> void:
	var cause := "pump_explosion"
	for pump in pumps:
		if Vector2(pump.pos).is_equal_approx(at):
			cause = ("player_" if bool(pump.player_caused) else "")+str(pump.kind)+"_explosion"
			break
	var indices := enemy_indices_near(at,float(rules.fairness.pump_radius))
	indices.sort()
	indices.reverse()
	var killed := 0
	for index in indices:
		if index<enemies.size() and Vector2(enemies[index].pos).distance_to(at)<=float(rules.fairness.pump_radius):
			if phase_b_damage_enemy(index,float(rules.fairness.pump_enemy_damage),false,"pump"): killed += 1
	if player_pos.distance_to(at)<=float(rules.fairness.pump_radius): fairness.apply(float(rules.fairness.pump_damage),cause)
	juice_fx.explosion(at,killed)
	announce("BARREL DETONATED!" if cause.contains("barrel") else "PUMP DETONATED!","Move clear of marked hazards")
	events.pump_exploded(at)
	run_log.emit("explosive_detonated",{"source":cause,"x":at.x,"y":at.y,"damage_cap_fraction":tuning.pumps.player_explosion_cap if cause.begins_with("player_") else tuning.pumps.enemy_explosion_cap})

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if warming or player_hp<=0: return
	pump_contact_clock -= delta
	if pump_contact_clock>0: return
	pump_contact_clock = float(tuning.pumps.contact_interval_seconds)
	for hazard in stage1_hazards:
		if hazard.kind=="fire": heat_explosives_in_area(hazard.pos,float(hazard.radius),"fire",bool(hazard.get("player_caused",false)))
	for pump in pumps:
		if not bool(pump.alive): continue
		var rect := Rect2(Vector2(pump.pos)-Vector2.ONE*TILE*0.5,Vector2.ONE*TILE)
		for index in enemy_indices_near(pump.pos,TILE*1.5):
			if index>=enemies.size(): continue
			var enemy: Dictionary = enemies[index]
			var point: Vector2 = enemy.pos
			var closest := point.clamp(rect.position,rect.end)
			if point.distance_to(closest)<=float(enemy.radius)+float(tuning.pumps.contact_slop):
				heat_explosive(pump,"boss_contact" if enemy.kind in ["mech_miniboss","trucker"] else "enemy_contact",false)
				break

func _setup_ui() -> void:
	super._setup_ui()
	# Keep XP/level telemetry and the base SMG, but remove the old weapon/passive
	# selection loop. Mutation choices are owned by MutationManager between waves.
	var old: Node = progression
	remove_child(old)
	old.queue_free()
	progression = preload("res://scripts/mutation_progression.gd").new()
	progression.game = self
	add_child(progression)
	phase_ui.progression = progression
	progression.level_up_requested.connect(phase_ui._show_choices)

	var mutation_layer := CanvasLayer.new()
	mutation_layer.layer = 20
	add_child(mutation_layer)

	var tag_hud := Control.new()
	tag_hud.set_script(load("res://scripts/mutation_hud.gd"))
	mutation_layer.add_child(tag_hud)

	var picker := Control.new()
	picker.set_script(load("res://scripts/mutation_picker.gd"))
	picker.set("game", self)
	mutation_layer.add_child(picker)
