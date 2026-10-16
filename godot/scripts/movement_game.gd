extends "res://scripts/outskirts.gd"
## Stage 2 movement/fairness layer. The approved baseline remains unchanged.
var rules: Dictionary
var fairness: Node
var facing := Vector2.UP
var camp_origin := Vector2.ZERO
var camp_seconds := 0.0
var camp_active := false
var camp_target_clock := 0.0
var hazard_serial := 0
var step_profile: Dictionary = {}
var warming := false
var pressure_samples: Array[Dictionary] = []
var sample_clock := 0.0
var population_clock := 0.0

func _ready() -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/movement.json"))
	_load_curated_art()
	for kind in {"enemies":250,"bullets":400,"impact_marks":120,"stage1_hazards":64,"powerups":30}:
		transient_pool.warm(kind, {"enemies":250,"bullets":400,"impact_marks":120,"stage1_hazards":64,"powerups":30}[kind])
	capture_mode = OS.get_cmdline_user_args().has("--pacing-capture")
	if OS.get_environment("DEADSHIFT_VALIDATION_SEED") != "":
		rng.seed = int(OS.get_environment("DEADSHIFT_VALIDATION_SEED"))
	elif capture_mode:
		rng.seed = 20261014
	else:
		rng.randomize()
	_generate_outskirts_layout()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_pumps()
	_setup_objectives()
	_clear_objective_routes()
	terrain_batches = preload("res://scripts/terrain_batches.gd").new()
	terrain_batches.game = self
	add_child(terrain_batches)
	_setup_camera()
	_setup_ui()
	actors = ActorPresentation.new()
	actors.game = self
	add_child(actors)
	guidance = preload("res://scripts/movement_guidance.gd").new()
	guidance.game = self
	add_child(guidance)
	if capture_mode and phase_ui != null:
		phase_ui.god_mode = false
	run_log = preload("res://scripts/movement_telemetry.gd").new()
	run_log.game = self
	add_child(run_log)
	events = preload("res://scripts/movement_events.gd").new()
	events.game = self
	add_child(events)
	telemetry = preload("res://scripts/pacing_telemetry.gd").new()
	telemetry.game = self
	add_child(telemetry)
	fairness = preload("res://scripts/fair_damage.gd").new()
	fairness.game = self
	add_child(fairness)
	camp_origin = player_pos
	facing = Vector2(rules.weapons.initial_facing[0],rules.weapons.initial_facing[1])
	var hazard_view = preload("res://scripts/movement_hazards.gd").new()
	hazard_view.game = self
	add_child(hazard_view)
	_start_wave(1)
	call_deferred("_warmup")
	if capture_mode:
		print("PACING_CAPTURE_READY")

func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.04, 0.04, 0.0)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(432, 118)
	ui.add_child(bar)

	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 20)
	ui.add_child(hud)
	hud.visible = false

	banner = Label.new()
	banner.position = Vector2(18, 128)
	banner.size = Vector2(396, 84)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 18)
	ui.add_child(banner)
	banner.visible = false

	tactical_map = Control.new()
	tactical_map.set_script(load("res://scripts/tactical_minimap.gd"))
	tactical_map.set("game", self)
	tactical_map.position = Vector2(310, 12)
	tactical_map.size = Vector2(110, 112)
	ui.add_child(tactical_map)

	var polish_hud := Control.new()
	hud_overlay = polish_hud
	polish_hud.set_script(load("res://scripts/movement_hud.gd"))
	polish_hud.set("game", self)
	ui.add_child(polish_hud)
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/movement_fx.gd"))
	fx.set("game", self)
	add_child(fx)
	juice_fx = fx
	var prog := Node2D.new()
	prog.set_script(load("res://scripts/movement_progression.gd"))
	prog.set("game", self)
	add_child(prog)
	progression = prog
	var phase_overlay := Control.new()
	phase_overlay.set_script(load("res://scripts/movement_ui.gd"))
	phase_overlay.set("game", self)
	phase_overlay.set("progression", prog)
	ui.add_child(phase_overlay)
	phase_ui = phase_overlay


func metres(value: float) -> float:
	return value*TILE/float(rules.metres_per_tile)

func announce(title: String, detail: String = "") -> void:
	if hud_overlay!=null: hud_overlay.notify(title,detail)

func _load_curated_art() -> void:
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/icon_map.json"))["icons"]
	for key in mapping:
		if ResourceLoader.exists(mapping[key]): curated_pickup_textures[key] = load(mapping[key])

func _physics_process(delta: float) -> void:
	if warming: return
	var begin_usec := Time.get_ticks_usec()
	population_clock += delta/maxf(0.02,Engine.time_scale)
	if population_clock>=float(rules.pressure.population_maintenance_seconds):
		_maintain_population(population_clock)
		population_clock = 0.0
	var input := Vector2.ZERO
	if touch_active: input = (touch_position-touch_origin).limit_length(90.0)/90.0
	input += Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if input.length()>float(rules.weapons.facing_deadzone): facing = input.normalized()
	fairness.tick(delta/maxf(0.02,Engine.time_scale))
	_tick_camp(delta/maxf(0.02,Engine.time_scale))
	# Goo is a single non-stacking slow. Hide it only from the legacy 0.55-per-puddle calculation.
	var inside_goo := false
	for hazard in stage1_hazards:
		if hazard.kind=="goo":
			if player_pos.distance_to(hazard.pos)<float(hazard.radius): inside_goo = true
			hazard.kind = "goo_visual"
	var speed_before := player_speed
	if inside_goo: player_speed *= float(rules.goo.slow_multiplier)
	super._physics_process(delta)
	if camp_active: spawn_clock -= delta*(float(rules.camp.spawn_multiplier)-1.0)
	player_speed = speed_before
	for hazard in stage1_hazards:
		if hazard.kind=="goo_visual": hazard.kind = "goo"
	_enforce_goo_cap()
	last_aim = facing
	step_profile["physics_ms"] = (Time.get_ticks_usec()-begin_usec)/1000.0
	sample_clock += delta/maxf(0.02,Engine.time_scale)
	if sample_clock>=float(rules.performance.profile_sample_seconds):
		sample_clock = 0.0
		var row := {"active_s":snappedf(run_clock,0.001),"wave":wave,"phase":events.rhythm(),"onscreen":_onscreen_enemy_count(),"target":_active_horde_target(),"active_enemies":enemies.size(),"camping":camp_active,"level":progression.level,"hp":player_hp,"hazards":stage1_hazards.size(),"profile":step_profile.duplicate()}
		pressure_samples.append(row)
		run_log.emit("movement_sample",row)

func _tick_camp(dt: float) -> void:
	if not wave_active or wave<int(rules.camp.from_wave):
		camp_origin = player_pos
		camp_seconds = 0.0
		camp_active = false
		return
	if player_pos.distance_to(camp_origin)>metres(float(rules.camp.radius_metres)):
		if camp_active: run_log.emit("camp_reset")
		camp_origin = player_pos
		camp_seconds = 0.0
		camp_active = false
		camp_target_clock = 0.0
	else: camp_seconds += dt
	if camp_seconds>=float(rules.camp.seconds):
		if not camp_active:
			camp_active = true
			run_log.emit("camp_pressure_started",{"radius_m":rules.camp.radius_metres,"spawn_multiplier":rules.camp.spawn_multiplier})
		camp_target_clock -= dt
		if camp_target_clock<=0:
			camp_target_clock = float(rules.camp.target_refresh_seconds)
			var attacker: Dictionary = {}
			for enemy in enemies:
				if enemy.kind=="spitter": attacker = enemy; break
			if attacker.is_empty():
				var spot := _spawn_position_outside_view(facing.angle()+PI)
				var count := enemies.size()
				_append_enemy("spitter",spot)
				if enemies.size()>count: attacker = enemies[-1]
			if not attacker.is_empty():
				_warn_acid(attacker)
				attacker.attack_clock = float(rules.threats.spitter_attack_seconds)

func _stage1_damage(amount: int, source: String) -> void:
	fairness.apply(amount,"pump_explosion" if source=="explosion" else source)

func _apply_player_contact_damage(enemy: Dictionary) -> void:
	if player_hit_invulnerability>0 or float(enemy.get("contact_cooldown",0))>0: return
	var kind: String = enemy.kind
	var raw := float(_enemy_contact_damage(kind))
	if kind=="brute" and wave<=int(rules.threats.early_brute_until_wave): raw *= float(rules.threats.early_brute_damage_multiplier)
	var source := "mechanic" if kind=="mech_miniboss" else kind
	if kind=="brute" and float(enemy.get("charge",0))>0: source = "brute_charge"
	if kind=="spitter": source = "spitter_contact"
	var dealt: int = fairness.apply(maxf(1.0,raw-player_armor),source,int(enemy.uid))
	enemy.contact_cooldown = float(progression.config.difficulty.enemy_contact_cooldown_seconds)
	if dealt>0:
		player_hit_invulnerability = float(progression.config.difficulty.player_hit_invulnerability_seconds)
		_knockback_nearby_enemies()
		_haptic_pulse(20)

func _explode_pump(pump: Dictionary) -> void:
	if not bool(pump.alive): return
	pump.alive = false
	add_hazard("pump_warning",pump.pos,float(rules.fairness.pump_radius),float(rules.fairness.pump_warning_seconds),"pump_explosion",-1)
	run_log.emit("pump_warning",{"x":pump.pos.x,"y":pump.pos.y,"warning_seconds":rules.fairness.pump_warning_seconds})

func _detonate_pump(at: Vector2) -> void:
	var killed := 0
	var indices := enemy_indices_near(at,float(rules.fairness.pump_radius))
	indices.sort()
	indices.reverse()
	for index in indices:
		if index<enemies.size() and Vector2(enemies[index].pos).distance_to(at)<=float(rules.fairness.pump_radius):
			if phase_b_damage_enemy(index,float(rules.fairness.pump_enemy_damage),false,"pump"): killed += 1
	if player_pos.distance_to(at)<=float(rules.fairness.pump_radius): fairness.apply(float(rules.fairness.pump_damage),"pump_explosion")
	juice_fx.explosion(at,killed)
	announce("PUMP DETONATED!","Move clear of marked hazards")
	events.pump_exploded(at)

func add_hazard(kind: String, at: Vector2, radius: float, lifetime: float, source: String, owner_uid: int) -> void:
	if stage1_hazards.size()>=int(rules.threats.hazard_limit): return
	hazard_serial += 1
	transient_pool.push(stage1_hazards,"stage1_hazards",{"id":hazard_serial,"kind":kind,"pos":at,"radius":radius,"life":lifetime,"total":lifetime,"tick":0.0,"source":source,"owner_uid":owner_uid},int(rules.threats.hazard_limit))

func _warn_acid(enemy: Dictionary) -> void:
	# Lock the current position ONCE; never lead movement or track the player during the warning.
	add_hazard("acid_warning",player_pos,float(rules.threats.acid_radius),float(rules.threats.warning_seconds),"spitter",int(enemy.uid))

func _stage1_update_hazards(delta: float) -> void:
	var profile_start := Time.get_ticks_usec()
	var transitions: Array[Dictionary] = []
	for index in range(stage1_hazards.size()-1,-1,-1):
		var h: Dictionary = stage1_hazards[index]
		h.life = float(h.life)-delta
		h.tick = float(h.get("tick",0))-delta
		if float(h.life)<=0:
			if h.kind in ["acid_warning","pump_warning"]: transitions.append(h.duplicate())
			transient_pool.remove(stage1_hazards,index,"stage1_hazards")
			continue
		if h.kind in ["acid","fire"] and player_pos.distance_to(h.pos)<float(h.radius) and float(h.tick)<=0:
			var damage: float = rules.threats.early_acid_damage if wave<=int(rules.threats.early_spitter_until_wave) else rules.threats.acid_damage
			fairness.apply(damage,str(h.get("source",h.kind)),int(h.get("owner_uid",-1)))
			h.tick = float(rules.threats.acid_tick_seconds)
	for h in transitions:
		if h.kind=="pump_warning": _detonate_pump(h.pos)
		else: add_hazard("acid",h.pos,float(h.radius),float(rules.threats.acid_seconds),"spitter",int(h.owner_uid))

	step_profile["hazards_ms"] = (Time.get_ticks_usec()-profile_start)/1000.0

func _enemy_stats(kind: String) -> Dictionary:
	var stats := super._enemy_stats(kind)
	if kind=="spitter" and wave<=int(rules.threats.early_spitter_until_wave): stats.hp *= float(rules.threats.early_spitter_hp_multiplier)
	if kind=="brute" and wave<=int(rules.threats.early_brute_until_wave): stats.hp *= float(rules.threats.early_brute_hp_multiplier)
	return stats

func _pressure_kind() -> String:
	var cfg: Dictionary = rules.threats
	var roll := rng.randf()
	var weight := 0.0
	for kind in ["brute","spitter","bloater","runner"]:
		var first := 2 if kind=="runner" else int(cfg[kind+"_from_wave"])
		if wave<first: continue
		var share := float(cfg[kind+"_weight"])
		if kind=="runner" and wave<=int(cfg.early_runner_until_wave): share = float(cfg.early_runner_weight)
		weight += share
		if roll<weight:
			if kind in ["spitter","brute"] and wave<=int(cfg["early_"+kind+"_until_wave"]):
				var alive := 0
				for enemy in enemies:
					if enemy.kind==kind: alive += 1
				if alive>=int(cfg["early_"+kind+"_max"]): return "shambler"
			return kind
	return "shambler"

func _update_enemy(enemy: Dictionary, delta: float) -> void:
	if enemy.has("surge_anchor"):
		var offset: Vector2 = Vector2(enemy.surge_anchor)-Vector2(enemy.pos)
		if offset.length()<=float(rules.pressure.surge_anchor_release_radius):
			enemy.erase("surge_anchor")
		elif freeze_clock<=0:
			enemy.contact_cooldown = maxf(0.0,float(enemy.get("contact_cooldown",0))-delta)
			enemy.visual_hit = maxf(0.0,float(enemy.get("visual_hit",0))-delta)
			var step := offset.normalized()*float(enemy.speed)*delta
			var subdivisions := maxi(1,ceili(step.length()/12.0))
			for i in range(subdivisions): enemy.pos = _move_with_blockers(enemy.pos,step/subdivisions,float(enemy.radius))
			if player_pos.distance_to(enemy.pos)<PLAYER_RADIUS+float(enemy.radius): _apply_player_contact_damage(enemy)
			return
	var kind: String = enemy.kind
	if kind not in ["spitter","brute"]:
		super._update_enemy(enemy,delta)
		return
	enemy.visual_hit = maxf(0.0,float(enemy.get("visual_hit",0.0))-delta)
	enemy.contact_cooldown = maxf(0.0,float(enemy.get("contact_cooldown",0.0))-delta)
	if freeze_clock>0: return
	var to_player: Vector2 = player_pos-Vector2(enemy.pos)
	var cfg: Dictionary = rules.threats
	var movement: Vector2 = to_player.normalized()*float(enemy.speed)
	enemy.attack_clock = float(enemy.attack_clock)-delta
	if kind=="spitter":
		if enemy.attack_clock<=0 and to_player.length()<float(cfg.spitter_range):
			enemy.attack_clock = float(cfg.spitter_attack_seconds)
			_warn_acid(enemy)
		if to_player.length()<float(cfg.spitter_standoff): movement *= -float(cfg.spitter_retreat_multiplier)
	else:
		if enemy.attack_clock<=0 and to_player.length()<float(cfg.brute_range):
			enemy.attack_clock = float(cfg.brute_attack_seconds)
			enemy.charge = -float(cfg.brute_warning_seconds)
			enemy.charge_target = to_player.normalized()
			enemy.charge_origin = enemy.pos
			enemy.facing = enemy.charge_target
		if float(enemy.charge)<0:
			movement = Vector2.ZERO
			enemy.charge = minf(0.0,float(enemy.charge)+delta)
			if enemy.charge>=0: enemy.charge = float(cfg.brute_charge_seconds)
		elif float(enemy.charge)>0:
			var speed: float = cfg.early_brute_charge_speed if wave<=int(cfg.early_brute_until_wave) else cfg.brute_charge_speed
			movement = Vector2(enemy.charge_target)*speed
			enemy.charge = maxf(0.0,float(enemy.charge)-delta)
		else: enemy.facing = to_player.normalized()
	var move := movement*delta
	var steps := maxi(1,ceili(move.length()/12.0))
	for i in range(steps):
		if kind=="brute" and float(enemy.charge)>0 and _circle_hits_blocker(Vector2(enemy.pos)+move/steps,float(enemy.radius)):
			enemy.charge = 0.0
			break
		enemy.pos = _move_with_blockers(enemy.pos,move/steps,float(enemy.radius))
	if player_pos.distance_to(enemy.pos)<PLAYER_RADIUS+float(enemy.radius): _apply_player_contact_damage(enemy)

func _spawn_position_outside_view(angle: float) -> Vector2:
	var half := _camera_half_extents()
	var direction := Vector2.from_angle(angle)
	var edge := minf(half.x/maxf(0.001,absf(direction.x)),half.y/maxf(0.001,absf(direction.y)))
	return player_pos+direction*(edge+float(rules.pressure.spawn_margin)+rng.randf()*float(rules.pressure.spawn_jitter))

func _safe_spawn(side: int) -> Vector2:
	var half := _camera_half_extents()
	var margin := float(rules.pressure.spawn_margin)
	for attempt in range(int(rules.pressure.spawn_probe_count)):
		var jitter: float = rng.randf_range(-1.0,1.0)*float(rules.pressure.side_jitter)
		var at := player_pos
		match side:
			0: at += Vector2(half.x+margin,half.y*jitter)
			1: at += Vector2(half.x*jitter,half.y+margin)
			2: at += Vector2(-half.x-margin,half.y*jitter)
			3: at += Vector2(half.x*jitter,-half.y-margin)
		if not Rect2(Vector2.ONE*PLAYER_RADIUS,MAP_SIZE-Vector2.ONE*PLAYER_RADIUS*2).has_point(at): continue
		if _is_position_on_screen(at) or _circle_hits_blocker(at,30.0): continue
		var inward := at.move_toward(player_pos,float(rules.pressure.inbound_clearance))
		if _circle_hits_blocker(inward,30.0) or _circle_hits_blocker((at+inward)*0.5,30.0): continue
		if events!=null and not events.spawn_allowed(at,30.0): continue
		return at
	return Vector2.INF

func _spawn_pressure_group(forced_size: int = -1) -> void:
	if progression==null: return
	if wave_clock<float(rules.objectives.breather_seconds): return
	# Release only off-screen actors far outside the local engagement. Never teleport a visible enemy.
	var recycled := 0
	var far := _camera_half_extents().length()*float(rules.pressure.stale_distance_multiplier)
	for index in range(enemies.size()-1,-1,-1):
		if recycled>=int(rules.pressure.recycle_budget): break
		if player_pos.distance_to(enemies[index].pos)>far and not _is_position_on_screen(enemies[index].pos):
			transient_pool.remove(enemies,index,"enemies")
			grid_dirty = true
			recycled += 1
	var desired := maxi(0,_active_horde_target()+int(rules.pressure.inbound_buffer)-_pressure_population_count())
	var budget := mini(int(rules.pressure.spawn_group_max),forced_size if forced_size>0 else desired)
	budget = mini(desired,budget) # Rate, not enemy health or speed, gets the +50% camp multiplier.
	for n in range(budget):
		if enemies.size()>=int(progression.config.limits.active_enemies): break
		var total := 0.0
		var weights: Array[float] = []
		for side in range(4):
			var dot := Vector2.from_angle(side*PI/2).dot(facing) if player_velocity.length()>1.0 else 0.0
			var weight: float = rules.pressure.forward_weight if dot>0.5 else (rules.pressure.rear_weight if dot< -0.5 else rules.pressure.side_weight)
			weights.append(weight)
			total += weight
		var roll := rng.randf()*total
		var side := 0
		while side<3 and roll>weights[side]:
			roll -= weights[side]
			side += 1
		var at := _safe_spawn(side)
		if at==Vector2.INF: continue
		var before := enemies.size()
		_append_enemy(_pressure_kind(),at)
		wave_spawned += enemies.size()-before

func _pressure_population_count() -> int:
	var half := _camera_half_extents()+Vector2.ONE*(float(rules.pressure.spawn_margin)+float(rules.pressure.spawn_jitter))
	var view := Rect2(player_pos-half,half*2)
	var count := 0
	for enemy in enemies:
		if view.has_point(enemy.pos): count += 1
	return count

func _stage1_spawn_surge() -> void:
	var anchor := player_pos
	var count := roundi(float(rules.pressure.surge_ring_count)*events.pressure_multiplier())
	var spawned := 0
	for i in range(count):
		var at := _safe_spawn(i%4)
		if at==Vector2.INF: continue
		var before := enemies.size()
		_append_enemy(_pressure_kind(),at)
		if enemies.size()>before:
			enemies[-1]["surge_anchor"] = anchor
			spawned += 1
	run_log.emit("surge_ring",{"center_x":anchor.x,"center_y":anchor.y,"requested":count,"count":spawned})
	announce("SURGE - KEEP MOVING")

func _start_wave(number: int) -> void:
	super._start_wave(number)
	banner.text = ""
	announce("WAVE %d" % number,"BREATHER - gather XP, choose your route")

func _update_bullets(delta: float) -> void:
	var profile_start := Time.get_ticks_usec()
	# Bind each freshly emitted projectile once, including the evolved facing guns.
	var groups: Dictionary = {"smg":[],"boomstick":[]}
	for bullet in bullets:
		if not bullet.get("facing_bound",false): groups["smg" if float(bullet.life)>1.0 else "boomstick"].append(bullet)
	for kind in groups:
		var group: Array = groups[kind]
		var half_angle: float = rules.weapons.smg_max_half_angle if kind=="smg" else rules.weapons.boomstick_max_half_angle
		var step: float = rules.weapons.smg_spread if kind=="smg" else progression.config.weapons.boomstick.base_cone_step
		step = minf(step,2*half_angle/maxf(1,group.size()-1))
		for i in range(group.size()):
			group[i].dir = facing.rotated((i-(group.size()-1)*0.5)*step)
			group[i].facing_bound = true
	if not groups.smg.is_empty() or not groups.boomstick.is_empty(): recoil_vector = -facing*3.0
	super._update_bullets(delta)
	step_profile["bullets_ms"] = (Time.get_ticks_usec()-profile_start)/1000.0

func reward_position(from: Vector2) -> Vector2:
	var lo := metres(float(rules.rewards.minimum_metres))
	var hi := metres(float(rules.rewards.maximum_metres))
	for attempt in range(int(rules.pressure.spawn_probe_count)):
		var angle := rng.randf()*TAU
		var at := _nearest_walkable_position(player_pos+Vector2.from_angle(angle)*rng.randf_range(lo,hi),PLAYER_RADIUS)
		var distance := at.distance_to(player_pos)
		if distance>=lo and distance<=hi and not NORTH_EXIT.has_point(at): return at
	# Deterministic exhaustive fallback; never drop on the survivor.
	for y in range(MAP_H):
		for x in range(MAP_W):
			var at := _tile_center(x,y)
			if at.distance_to(player_pos)>=lo and at.distance_to(player_pos)<=hi and not _circle_hits_blocker(at,PLAYER_RADIUS): return at
	return from

func drop_reward(kind: String, from: Vector2) -> void:
	var at := reward_position(from)
	transient_pool.push(powerups,"powerups",{"pos":at,"kind":kind,"age":0.0},30)
	run_log.emit("reward_drop",{"kind":kind,"distance_m":player_pos.distance_to(at)/metres(1.0)})

func _phase_a_kill_enemy(index: int) -> void:
	var before_rewards := powerups.size()
	var before_hazards := stage1_hazards.size()
	super._phase_a_kill_enemy(index)
	for i in range(before_rewards,powerups.size()): powerups[i].pos = reward_position(powerups[i].pos)
	for i in range(before_hazards,stage1_hazards.size()):
		if stage1_hazards[i].kind=="goo":
			stage1_hazards[i].radius = float(rules.goo.radius)
			stage1_hazards[i].life = float(rules.goo.seconds)
	_enforce_goo_cap()

func _enforce_goo_cap() -> void:
	var visible_count := 0
	var all_count := 0
	for i in range(stage1_hazards.size()-1,-1,-1):
		var h: Dictionary = stage1_hazards[i]
		if h.kind not in ["goo","goo_visual"]: continue
		all_count += 1
		var visible_goo := Rect2(player_pos-_camera_half_extents(),_camera_half_extents()*2).grow(float(h.radius)).has_point(h.pos)
		if visible_goo: visible_count += 1
		if all_count>int(rules.goo.maximum_total) or (visible_goo and visible_count>int(rules.goo.maximum_visible)):
			transient_pool.remove(stage1_hazards,i,"stage1_hazards")

func _collect_phase_c_powerup(kind: String) -> void:
	if kind=="Upgrade crate":
		phase_ui.queue_upgrade_crate()
		return
	if kind=="Magnet":
		progression.activate_magnet()
		announce("MAGNET","Pickup radius expanded")
		return
	super._collect_phase_c_powerup(kind)

func nearby_objective_position() -> Vector2:
	var cfg: Dictionary = rules.objectives
	var best := Vector2.INF
	var best_score := INF
	var lo := metres(float(cfg.minimum_metres))
	var hi := metres(float(cfg.maximum_metres))
	var from: Vector2i = guidance._walkable_cell(player_pos)
	for y in range(MAP_H):
		for x in range(MAP_W):
			var at := _tile_center(x,y)
			var distance := at.distance_to(player_pos)
			if distance<lo or distance>hi or _circle_hits_blocker(at,PLAYER_RADIUS) or NORTH_EXIT.has_point(at): continue
			var score := absf(distance-metres(float(cfg.preferred_metres)))
			if score>=best_score: continue
			var path: PackedVector2Array = guidance.navigation.get_point_path(from,Vector2i(x,y))
			if path.is_empty(): continue
			var length := player_pos.distance_to(path[0])
			for i in range(1,path.size()): length += path[i-1].distance_to(path[i])
			if length>hi: continue
			best_score = score
			best = at
	assert(best!=Vector2.INF,"No 20-40m reachable objective site")
	return best

func _draw_combat() -> void:
	var hazards := stage1_hazards
	stage1_hazards = []
	super._draw_combat()
	stage1_hazards = hazards

func _warmup() -> void:
	if DisplayServer.get_name()=="headless": return
	warming = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	var start := Time.get_ticks_usec()
	var fixture = preload("res://scripts/movement_warmup.gd").new()
	fixture.game = self
	add_child(fixture)
	for i in range(int(rules.performance.warmup_frames)): await RenderingServer.frame_post_draw
	fixture.queue_free()
	warming = false
	get_tree().paused = was_paused
	run_log.emit("shader_warmup_complete",{"milliseconds":(Time.get_ticks_usec()-start)/1000.0,"frames":rules.performance.warmup_frames,"rendered_offscreen_viewport":true})

func _maintain_population(dt: float) -> void:
	# Stale off-screen actors cannot consume the whole pool and starve visible pressure.
	var removed := 0
	for index in range(enemies.size()-1,-1,-1):
		var enemy: Dictionary = enemies[index]
		var previous: Vector2 = enemy.get("sample_position",enemy.pos)
		var travelled := previous.distance_to(enemy.pos)
		enemy["sample_position"] = enemy.pos
		enemy["stuck_seconds"] = float(enemy.get("stuck_seconds",0))+dt if travelled<float(rules.pressure.stuck_min_progress) else 0.0
		if _is_position_on_screen(enemy.pos) or bool(enemy.get("stage2_mechanic",false)): continue
		var too_far := player_pos.distance_to(enemy.pos)>_camera_half_extents().length()*float(rules.pressure.stale_distance_multiplier)
		if (too_far or float(enemy.stuck_seconds)>=float(rules.pressure.stuck_seconds)) and removed<int(rules.pressure.recycle_budget):
			transient_pool.remove(enemies,index,"enemies")
			grid_dirty = true
			removed += 1
	if removed>0: run_log.emit("offscreen_stale_recycled",{"count":removed})

func _finish_wave() -> void:
	# Keep timing/logging but move the automatic crate reward into the world.
	var actual_ui: Control = phase_ui
	phase_ui = null
	var was_active := wave_active
	super._finish_wave()
	phase_ui = actual_ui
	if was_active and wave>=2 and wave<10: drop_reward("Upgrade crate",player_pos)

func _update_enemies(delta: float) -> void:
	var profile_start := Time.get_ticks_usec()
	super._update_enemies(delta)
	step_profile["enemies_ms"] = (Time.get_ticks_usec()-profile_start)/1000.0
