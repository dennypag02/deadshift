extends Node2D
signal level_up_requested

const DATA_PATH := "res://data/phase_a.json"
const FALLBACK_CONFIG := preload("res://scripts/gameplay_config_fallback.gd")

var game: Node2D
var config: Dictionary = {}
var record_pool = preload("res://scripts/record_pool.gd").new()
var level := 1
var xp := 0
var gems: Array[Dictionary] = []
var weapons: Dictionary = {}
var passives: Dictionary = {}
var evolutions: Dictionary = {}
const EVOLUTION_PARTNERS := {"scrap_smg": "ammo_belt", "boomstick": "muscle", "molotov": "fuel_tank", "buzzsaw": "ball_bearings", "lightning": "battery_pack", "rocket": "blast_radius", "drone": "trigger_finger", "chakram": "sharpened_edge"}
const EVOLUTION_NAMES := {"scrap_smg": "Lead Hurricane", "boomstick": "Dragon\u2019s Breath", "molotov": "Napalm Rain", "buzzsaw": "Meat Grinder", "lightning": "Thunderdome", "rocket": "Carpet Bomber", "drone": "Drone Swarm", "chakram": "Chrome Tornado"}
var weapon_steps: Dictionary = {}
var passive_steps: Dictionary = {}
var invulnerability := 0.0
var orbit_clock := 0.0
var pending_levels := 0
var choosing := false
var banished: Array[String] = []
var choice_rarities: Dictionary = {}
var rng := RandomNumberGenerator.new()

var rerolls_left := 2
var banishes_left := 1
var xp_dropped_total := 0
var xp_collected_total := 0
var xp_collected_raw := 0
var xp_credit_remainder := 0.0
var level_times: Array[Dictionary] = []

var weapon_clocks: Dictionary = {
	"molotov": 0.0,
	"lightning": 0.0,
	"rocket": 0.0,
	"drone": 0.0,
	"chakram": 0.0,
}
var molotov_pools: Array[Dictionary] = []
var rockets: Array[Dictionary] = []
var chakrams: Array[Dictionary] = []
var lightning_arcs: Array[Dictionary] = []
var drone_shots: Array[Dictionary] = []

func _ready() -> void:
	for kind in ["gems","molotov_pools","rockets","chakrams","lightning_arcs","drone_shots"]: record_pool.warm(kind,200 if kind=="gems" else 96)
	var batch=preload("res://scripts/gem_batch.gd").new()
	batch.progression=self
	add_child(batch)
	if OS.get_environment("DEADSHIFT_VALIDATION_SEED") != "":
		rng.seed = int(OS.get_environment("DEADSHIFT_VALIDATION_SEED"))+101
	elif OS.get_cmdline_user_args().has("--pacing-capture"):
		rng.seed = 20261014
	else:
		rng.randomize()
	config = _load_config_safe()
	_initialize_starting_weapon()
	rerolls_left = int(config.get("ui", {}).get("rerolls_per_run", 2))
	banishes_left = int(config.get("ui", {}).get("banishes_per_run", 1))
	z_index = 3

func _config_valid(candidate: Variant) -> bool:
	if not (candidate is Dictionary):
		return false
	var d: Dictionary = candidate
	for key in ["run", "xp", "pacing", "limits", "rarity", "fallbacks", "damage_numbers", "weapons", "passives", "enemy_xp", "ui"]:
		if not d.has(key) or not (d[key] is Dictionary):
			return false
	for weapon_id in ["scrap_smg", "boomstick", "molotov", "buzzsaw", "lightning", "rocket", "drone", "chakram"]:
		if not d["weapons"].has(weapon_id):
			return false
	var starting_weapon := str(d.get("run", {}).get("starting_weapon", ""))
	if starting_weapon == "" or not d["weapons"].has(starting_weapon):
		return false
	return true

func _initialize_starting_weapon() -> void:
	weapons.clear()
	weapon_steps.clear()
	var starting_weapon := str(config.get("run", {}).get("starting_weapon", "boomstick"))
	if not config.get("weapons", {}).has(starting_weapon):
		push_error("DEADSHIFT_STARTING_WEAPON_INVALID id=%s; falling back to boomstick" % starting_weapon)
		starting_weapon = "boomstick"
	weapons[starting_weapon] = 1
	weapon_steps[starting_weapon] = [1.0]
	print("DEADSHIFT_STARTING_WEAPON id=%s level=1" % starting_weapon)

func _load_config_safe() -> Dictionary:
	var parsed: Variant = null
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("DEADSHIFT_CONFIG_MISSING path=%s error=%s; using built-in fallback" % [DATA_PATH, error_string(FileAccess.get_open_error())])
	else:
		parsed = JSON.parse_string(file.get_as_text())
		if not _config_valid(parsed):
			push_error("DEADSHIFT_CONFIG_INVALID path=%s; using built-in fallback" % DATA_PATH)
	if _config_valid(parsed):
		print("DEADSHIFT_CONFIG_LOADED path=%s" % DATA_PATH)
		return (parsed as Dictionary).duplicate(true)
	var fallback: Dictionary = FALLBACK_CONFIG.get_config()
	if _config_valid(fallback):
		push_warning("DEADSHIFT_CONFIG_FALLBACK_ACTIVE")
		return fallback
	push_error("DEADSHIFT_CONFIG_FATAL_FALLBACK_INVALID")
	return {
		"run":{"starting_weapon":"boomstick"},
		"xp":{"base":6,"linear":4,"quadratic":0.12,"pickup_radius_tiles":1.2,"merge_threshold":200,"vacuum_age_seconds":6.0,"pickup_speed":850.0,"vacuum_speed":1250.0,"pickup_distance":28.0},
		"pacing":{"wave1_duration_seconds":52.0,"break_seconds":8.0,"pressure_start":12,"pressure_at_60s":20,"spawn_group_min":4,"spawn_group_max":6,"spawn_interval_seconds":1.0,"spawn_distance":720.0,"spawn_directions_min":2,"spawn_directions_max":2,"final_surge_size":6,"wave_start_group_size":6,"wave1_start_groups":1,"later_wave_start_groups":1},
		"limits":{"weapons":6,"passives":6,"active_enemies":80,"projectiles":160,"damage_numbers":20},
		"rarity":{"common":{"chance":1.0,"step_multiplier":1.0},"rare":{"chance":0.0,"step_multiplier":1.0},"epic":{"chance":0.0,"step_multiplier":1.0},"legendary":{"chance":0.0,"step_multiplier":1.0,"bonus_heal_fraction":0.0},"luck_shift_per_level":0.0},
		"fallbacks":{"fallback_gold":{"name":"Scrap Cache","description":"+50 scrap","value":50},"fallback_heal":{"name":"Field Medkit","description":"Heal 30% max HP","heal_fraction":0.3}},
		"damage_numbers":{"enabled_default":false,"merge_window_seconds":0.15,"normal_color":"#FFFFFF","crit_color":"#F2C14E","normal_size":24,"crit_size":36,"lifetime_seconds":0.75},
		"weapons":{
			"scrap_smg":{"name":"Scrap SMG","max_level":5,"base_damage":1.0,"base_fire_period":0.30,"level_adds":[]},
			"boomstick":{"name":"Boomstick","max_level":5,"base_pellets":6,"base_damage":1.0,"base_knockback":55.0,"base_cone_step":0.105,"base_fire_period":0.9,"base_range_pixels":400.0,"aim_assist_degrees":45.0,"level_adds":[]},
			"molotov":{"name":"Molotov Lobber","max_level":5,"base_bottles":1,"base_cooldown":3.2,"base_pool_radius":120.0,"base_duration":3.0,"base_dps":3.0,"level_adds":[]},
			"buzzsaw":{"name":"Buzzsaw Orbit","max_level":5,"base_blades":1,"base_damage_per_second":4.0,"base_radius":125.0,"base_speed":3.2,"level_adds":[]},
			"lightning":{"name":"Lightning Rod","max_level":5,"base_damage":4.0,"base_cooldown":2.2,"base_chains":2,"level_adds":[]},
			"rocket":{"name":"Rocket Pod","max_level":5,"base_damage":6.0,"base_cooldown":3.0,"base_rockets":1,"base_radius":135.0,"rocket_speed":430.0,"level_adds":[]},
			"drone":{"name":"Attack Drone","max_level":5,"base_drones":1,"base_damage":1.5,"base_fire_period":0.8,"drone_radius":82.0,"mini_rocket_radius":90.0,"level_adds":[]},
			"chakram":{"name":"Hubcap Chakram","max_level":5,"base_hubcaps":1,"base_damage":3.0,"base_cooldown":2.5,"base_range":420.0,"travel_speed":520.0,"level_adds":[]}
		},
		"passives":{
			"muscle":{"name":"Muscle","max_level":5,"per_level":0.10,"level_adds":[]},"ammo_belt":{"name":"Ammo Belt","max_level":5,"level_adds":[]},"trigger_finger":{"name":"Trigger Finger","max_level":5,"per_level":0.08,"level_adds":[]},"battery_pack":{"name":"Battery Pack","max_level":5,"per_level":0.08,"level_adds":[]},"blast_radius":{"name":"Blast Radius","max_level":5,"per_level":0.12,"level_adds":[]},"fuel_tank":{"name":"Fuel Tank","max_level":5,"per_level":0.15,"level_adds":[]},"ball_bearings":{"name":"Ball Bearings","max_level":5,"per_level":0.12,"level_adds":[]},"magnet":{"name":"Magnet","max_level":5,"per_level":0.30,"level_adds":[]},"thick_hide":{"name":"Thick Hide","max_level":5,"hp_fraction_per_level":0.15,"armor_per_level":1,"level_adds":[]},"sharpened_edge":{"name":"Sharpened Edge","max_level":5,"per_level":0.06,"crit_multiplier":2.0,"level_adds":[]},"rabbit_foot":{"name":"Rabbit's Foot","max_level":5,"per_level":0.10,"level_adds":[]}
		},
		"enemy_xp":{"shambler":1,"runner":2,"trucker":25},
		"ui":{"card_count":3,"level_invulnerability":0.5,"rerolls_per_run":2,"banishes_per_run":1}
	}

func xp_required(n: int) -> int:
	var c: Dictionary = config.get("xp", {})
	var curve: Array=c.get("required_by_level",[])
	if n>=1 and n<=curve.size(): return int(curve[n-1])
	if not curve.is_empty() and n>curve.size():
		var excess := n-curve.size()
		return int(curve[-1])+roundi(float(c.get("tail_linear",24))*excess+float(c.get("tail_quadratic",2))*excess*excess)
	return roundi(float(c.get("base", 6)) + float(c.get("linear", 4)) * (n - 1) + float(c.get("quadratic", 0.12)) * pow(n - 1, 2))

func drop_xp(pos: Vector2, kind: String) -> void:
	var xp_cfg: Dictionary = config.get("xp", {})
	var value := int(config.get("enemy_xp", {}).get(kind, 1))
	var guaranteed_until := int(xp_cfg.get("guaranteed_until_level", 1))
	var should_drop := level < guaranteed_until
	if not should_drop:
		var by_wave: Dictionary = xp_cfg.get("drop_multiplier_by_wave", {})
		var wave_key := str(game.wave) if game != null else "1"
		var chance := float(by_wave.get(wave_key, by_wave.get("default", 1.0)))
		var density := float(game._onscreen_enemy_count()) if game != null else 0.0
		var pressure := clampf(density / maxf(1.0, float(xp_cfg.get("density_full_pressure_count", 120))), 0.0, 1.0)
		chance *= lerpf(1.0, float(xp_cfg.get("density_drop_multiplier_floor", 0.65)), pressure)
		should_drop = rng.randf() < clampf(chance, 0.0, 1.0)
	if not should_drop:
		return
	record_pool.push(gems,"gems",{"pos": pos, "value": value, "age": 0.0},201)
	xp_dropped_total += value
	var threshold := int(xp_cfg.get("merge_threshold", 200))
	while gems.size() > threshold:
		var first: Dictionary = gems[0]
		record_pool.remove(gems,0,"gems")
		if not gems.is_empty():
			gems[0]["value"] = int(gems[0]["value"]) + int(first["value"])
	queue_redraw()

func vacuum_all_gems() -> void:
	for gem in gems:
		gem["age"] = float(config.get("xp", {}).get("vacuum_age_seconds", 6.0)) + 1.0

func _collect_xp(amount: int) -> void:
	xp_collected_raw += amount
	var bonus: Dictionary=config.get("xp",{}).get("collection_multiplier_by_level",{})
	var multiplier := float(bonus.get(str(level),bonus.get("default",config.get("xp",{}).get("collection_multiplier",.60))))
	xp_credit_remainder += amount * multiplier
	var credited := floori(xp_credit_remainder + 0.00001)
	xp_credit_remainder -= credited
	xp_collected_total += credited
	add_xp(credited)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_required(level):
		xp -= xp_required(level)
		level += 1
		pending_levels += 1
		var elapsed := float(game.run_clock) if game != null else 0.0
		level_times.append({"level": level, "time": elapsed})
		if game!=null and game.telemetry!=null: game.telemetry.event("level_up",{"level":level,"xp_required_next":xp_required(level)})
		print("STAGE1_LEVEL_UP level=%d t=%.2f" % [level, elapsed])
	if pending_levels > 0 and not choosing:
		choosing = true
		level_up_requested.emit()

func finish_choice() -> void:
	pending_levels = maxi(0, pending_levels - 1)
	choosing = false
	if pending_levels > 0:
		choosing = true
		level_up_requested.emit()

func resume_after_levelup() -> void:
	invulnerability = float(config.get("ui", {}).get("level_invulnerability", 0.5))
	if game != null:
		game.phase_a_resume_shockwave()

func _rarity_key() -> String:
	var rarity_cfg: Dictionary = config.get("rarity", {})
	var common := float(rarity_cfg.get("common", {}).get("chance", 0.70))
	var rare := float(rarity_cfg.get("rare", {}).get("chance", 0.22))
	var epic := float(rarity_cfg.get("epic", {}).get("chance", 0.07))
	var legendary := float(rarity_cfg.get("legendary", {}).get("chance", 0.01))
	var luck_shift := float(rarity_cfg.get("luck_shift_per_level", 0.02)) * passive_points("rabbit_foot")
	var shifted := minf(common - 0.05, luck_shift)
	common -= shifted
	rare += shifted * 0.65
	epic += shifted * 0.25
	legendary += shifted * 0.10
	var total := common + rare + epic + legendary
	var roll := rng.randf() * total
	if roll < common:
		return "COMMON"
	roll -= common
	if roll < rare:
		return "RARE"
	roll -= rare
	if roll < epic:
		return "EPIC"
	return "LEGENDARY"

func rarity_multiplier(rarity: String) -> float:
	return float(config.get("rarity", {}).get(rarity.to_lower(), {}).get("step_multiplier", 1.0))

func choice_rarity(id: String) -> String:
	return str(choice_rarities.get(id, "COMMON"))

func _eligible_options() -> Array[String]:
	var options: Array[String] = []
	var weapon_limit := int(config.get("limits", {}).get("weapons", 6))
	var passive_limit := int(config.get("limits", {}).get("passives", 6))
	for id in config.get("weapons", {}):
		if banished.has(str(id)):
			continue
		var data: Dictionary = config["weapons"][id]
		var max_level := int(data.get("max_level", 5))
		if weapons.has(id):
			if int(weapons[id]) < max_level:
				options.append(id)
		elif weapons.size() < weapon_limit:
			options.append(id)
	for id in config.get("passives", {}):
		if banished.has(str(id)):
			continue
		var data: Dictionary = config["passives"][id]
		var max_level := int(data.get("max_level", 5))
		if passives.has(id):
			if int(passives[id]) < max_level:
				options.append(id)
		elif passives.size() < passive_limit:
			options.append(id)
	return options

func available_choices() -> Array[String]:
	var options := _eligible_options()
	options.shuffle()
	var result: Array[String] = []
	for i in range(mini(3, options.size())):
		result.append(options[i])
	if result.is_empty():
		result = ["fallback_gold", "fallback_heal", "fallback_gold"]
	choice_rarities.clear()
	for id in result:
		choice_rarities[id] = _rarity_key() if not id.begins_with("fallback_") else "COMMON"
	return result

func use_reroll() -> bool:
	if rerolls_left <= 0:
		return false
	rerolls_left -= 1
	return true

func banish(id: String) -> bool:
	if banishes_left <= 0 or id.begins_with("fallback_"):
		return false
	if not banished.has(id):
		banished.append(id)
	banishes_left -= 1
	return true

func _append_step(store: Dictionary, id: String, mult: float) -> void:
	if not store.has(id):
		store[id] = []
	var arr: Array = store[id]
	arr.append(mult)
	store[id] = arr

func _step_mult(store: Dictionary, id: String, one_based_level: int) -> float:
	if not store.has(id):
		return 1.0
	var arr: Array = store[id]
	var idx := one_based_level - 1
	if idx >= 0 and idx < arr.size():
		return float(arr[idx])
	return 1.0

func weapon_step_mult(id: String, one_based_level: int) -> float:
	return _step_mult(weapon_steps, id, one_based_level)

func passive_step_mult(id: String, one_based_level: int) -> float:
	return _step_mult(passive_steps, id, one_based_level)

func passive_points(id: String) -> float:
	var current := int(passives.get(id, 0))
	if not passive_steps.has(id):
		return float(current)
	var total := 0.0
	var arr: Array = passive_steps[id]
	for v in arr:
		total += float(v)
	return total

func ammo_bonus() -> int:
	var count := 0
	var current := int(passives.get("ammo_belt", 0))
	for step_level in [1, 3, 5]:
		if current >= step_level:
			count += maxi(1, roundi(passive_step_mult("ammo_belt", step_level)))
	return count

func damage_multiplier() -> float:
	var per_level := float(config.get("passives", {}).get("muscle", {}).get("per_level", 0.10))
	return 1.0 + per_level * passive_points("muscle")

func attack_speed_multiplier() -> float:
	var per_level := float(config.get("passives", {}).get("trigger_finger", {}).get("per_level", 0.08))
	return 1.0 + per_level * passive_points("trigger_finger")

func cooldown_multiplier() -> float:
	var per_level := float(config.get("passives", {}).get("battery_pack", {}).get("per_level", 0.08))
	return maxf(0.20, 1.0 - per_level * passive_points("battery_pack"))

func area_multiplier() -> float:
	var per_level := float(config.get("passives", {}).get("blast_radius", {}).get("per_level", 0.12))
	return 1.0 + per_level * passive_points("blast_radius")

func duration_multiplier() -> float:
	var per_level := float(config.get("passives", {}).get("fuel_tank", {}).get("per_level", 0.15))
	return 1.0 + per_level * passive_points("fuel_tank")

func speed_multiplier() -> float:
	var per_level := float(config.get("passives", {}).get("ball_bearings", {}).get("per_level", 0.12))
	return 1.0 + per_level * passive_points("ball_bearings")

func crit_chance() -> float:
	var per_level := float(config.get("passives", {}).get("sharpened_edge", {}).get("per_level", 0.06))
	return clampf(per_level * passive_points("sharpened_edge"), 0.0, 0.95)

func roll_crit() -> bool:
	return rng.randf() < crit_chance()

func crit_multiplier() -> float:
	return float(config.get("passives", {}).get("sharpened_edge", {}).get("crit_multiplier", 2.0))

func debug_grant(id: String) -> void:
	if not config.get("weapons", {}).has(id) and not config.get("passives", {}).has(id):
		return
	choice_rarities[id] = "COMMON"
	pending_levels += 1
	choosing = true
	choose(id)

func choose(id: String) -> void:
	if id == "fallback_gold":
		if game != null:
			var scrap_value := int(config.get("fallbacks", {}).get(id, {}).get("value", 50))
			game.score += scrap_value
			game.scrap_earned += scrap_value
		finish_choice()
		return
	if id == "fallback_heal":
		if game != null:
			var heal_fraction := float(config.get("fallbacks", {}).get(id, {}).get("heal_fraction", 0.30))
			game.player_hp = mini(game.player_max_hp, game.player_hp + roundi(float(game.player_max_hp) * heal_fraction))
		finish_choice()
		return

	var rarity := choice_rarity(id)
	var mult := rarity_multiplier(rarity)
	if config.get("weapons", {}).has(id):
		var max_level := int(config["weapons"][id].get("max_level", 5))
		var before := int(weapons.get(id, 0))
		if before < max_level:
			weapons[id] = before + 1
			_append_step(weapon_steps, id, mult)
	elif config.get("passives", {}).has(id):
		var max_level := int(config["passives"][id].get("max_level", 5))
		var before := int(passives.get(id, 0))
		if before < max_level:
			passives[id] = before + 1
			_append_step(passive_steps, id, mult)
			if id == "thick_hide" and game != null:
				var hp_fraction := float(config["passives"][id].get("hp_fraction_per_level", 0.15))
				var armor_step := float(config["passives"][id].get("armor_per_level", 1))
				var hp_gain := roundi(100.0 * hp_fraction * mult)
				game.player_max_hp += hp_gain
				game.player_armor += maxi(1, roundi(armor_step * mult))
				game.player_hp = mini(game.player_max_hp, game.player_hp + hp_gain)

	if rarity == "LEGENDARY" and game != null:
		var heal_fraction := float(config.get("rarity", {}).get("legendary", {}).get("bonus_heal_fraction", 0.15))
		game.player_hp = mini(game.player_max_hp, game.player_hp + roundi(float(game.player_max_hp) * heal_fraction))
	finish_choice()

func chest_evolution() -> String:
	for weapon_id in EVOLUTION_PARTNERS:
		if evolutions.has(weapon_id):
			continue
		if int(weapons.get(weapon_id, 0)) >= 5 and int(passives.get(EVOLUTION_PARTNERS[weapon_id], 0)) >= 1:
			evolutions[weapon_id] = true
			print("PHASE_C_EVOLUTION weapon=%s name=%s" % [weapon_id, EVOLUTION_NAMES[weapon_id]])
			return str(EVOLUTION_NAMES[weapon_id])
	return ""

func _nearest_enemy_index(from: Vector2, excluded: Array[int] = []) -> int:
	if game == null:
		return -1
	var nearest := -1
	var best := INF
	for i in range(game.enemies.size()):
		if excluded.has(i):
			continue
		var d := from.distance_squared_to(Vector2(game.enemies[i]["pos"]))
		if d < best:
			best = d
			nearest = i
	return nearest

func _spawn_molotovs() -> void:
	if not weapons.has("molotov") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["molotov"]
	var lv := int(weapons["molotov"])
	var count := (12 if evolutions.has("molotov") else int(w.get("base_bottles", 1))) + ammo_bonus()
	if lv >= 2:
		count += maxi(1, roundi(weapon_step_mult("molotov", 2)))
	if lv >= 5:
		count += maxi(1, roundi(weapon_step_mult("molotov", 5)))
	var radius := float(w.get("base_pool_radius", 120.0)) * area_multiplier()
	if lv >= 3:
		radius *= 1.0 + 0.30 * weapon_step_mult("molotov", 3)
	var duration := float(w.get("base_duration", 3.0)) * duration_multiplier()
	if lv >= 4:
		duration += 1.0 * weapon_step_mult("molotov", 4)
	var dps := float(w.get("base_dps", 3.0)) * damage_multiplier()
	for n in range(count):
		var idx := _nearest_enemy_index(game.player_pos)
		if idx < 0:
			break
		var target: Vector2 = (game.player_pos + Vector2.from_angle(TAU * float(n) / maxf(1.0, float(count))) * 360.0) if evolutions.has("molotov") else (Vector2(game.enemies[idx]["pos"]) + Vector2.from_angle(TAU * float(n) / maxf(1.0, float(count))) * 35.0)
		record_pool.push(molotov_pools,"molotov_pools",{"pos": target, "life": duration, "radius": radius, "dps": dps, "tick": 0.0},96)
		game.transient_pool.push(game.impact_marks,"impact_marks",{"pos": target, "life": 0.35, "blast": true},120)

func _fire_lightning() -> void:
	if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): return
	if not weapons.has("lightning") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["lightning"]
	var lv := int(weapons["lightning"])
	var chains := (8 if evolutions.has("lightning") else int(w.get("base_chains", 2))) + ammo_bonus()
	if lv >= 2:
		chains += maxi(1, roundi(weapon_step_mult("lightning", 2)))
	if lv >= 5:
		chains += maxi(1, roundi(2.0 * weapon_step_mult("lightning", 5)))
	var damage := float(w.get("base_damage", 4.0)) * damage_multiplier()
	if lv >= 3:
		damage *= 1.0 + 0.20 * weapon_step_mult("lightning", 3)
	var origin: Vector2 = game.player_pos
	var used: Array[int] = []
	for j in range(chains):
		var idx := _nearest_enemy_index(origin, used)
		if idx < 0:
			break
		var pos := Vector2(game.enemies[idx]["pos"])
		var crit := roll_crit()
		game.phase_b_damage_enemy(idx, damage, crit, "lightning")
		if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): break
		record_pool.push(lightning_arcs,"lightning_arcs",{"a": origin, "b": pos, "life": 0.12},96)
		origin = pos
		used.append(idx)

func _spawn_rockets() -> void:
	if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): return
	if not weapons.has("rocket") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["rocket"]
	var lv := int(weapons["rocket"])
	var count := (10 if evolutions.has("rocket") else int(w.get("base_rockets", 1))) + ammo_bonus()
	if lv >= 2:
		count += maxi(1, roundi(weapon_step_mult("rocket", 2)))
	if lv >= 5:
		count += maxi(1, roundi(weapon_step_mult("rocket", 5)))
	for n in range(count):
		if evolutions.has("rocket"):
			var strike: Vector2 = game.player_pos + Vector2(-450.0 + float(n % 5) * 225.0, -220.0 + float(n / 5) * 320.0)
			_damage_area(strike, 155.0 * area_multiplier(), 7.0 * damage_multiplier(), "carpet_bomber")
			game.transient_pool.push(game.impact_marks,"impact_marks",{"pos": strike, "life": 0.55, "blast": true},120)
		var angle := -0.12 * float(count - 1) * 0.5 + 0.12 * float(n)
		if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): break
		record_pool.push(rockets,"rockets",{"pos": game.player_pos, "dir": game.last_aim.rotated(angle), "life": 3.0},96)

func _fire_drones() -> void:
	if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): return
	if not weapons.has("drone") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["drone"]
	var lv := int(weapons["drone"])
	var count := 8 if evolutions.has("drone") else int(w.get("base_drones", 1))
	if lv >= 2:
		count += maxi(1, roundi(weapon_step_mult("drone", 2)))
	if lv >= 5:
		count += maxi(1, roundi(weapon_step_mult("drone", 5)))
	var damage := float(w.get("base_damage", 1.5)) * damage_multiplier()
	var hits := 2 if lv >= 4 else 1
	for n in range(count + ammo_bonus()):
		var idx := _nearest_enemy_index(game.player_pos)
		if idx < 0:
			break
		var target := Vector2(game.enemies[idx]["pos"])
		var crit := roll_crit()
		game.phase_b_damage_enemy(idx, damage, crit, "drone")
		if hits > 1 and idx < game.enemies.size():
			var idx2 := _nearest_enemy_index(target, [idx])
			if idx2 >= 0:
				game.phase_b_damage_enemy(idx2, damage * 0.65, roll_crit(), "drone")
		if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): break
		record_pool.push(drone_shots,"drone_shots",{"a": game.player_pos, "b": target, "life": 0.10},96)
		if lv >= 5:
			_damage_area(target, float(w.get("mini_rocket_radius", 90.0)) * area_multiplier(), damage * 0.75, "drone_rocket")

func _spawn_chakrams() -> void:
	if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): return
	if not weapons.has("chakram") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["chakram"]
	var lv := int(weapons["chakram"])
	var count := (6 if evolutions.has("chakram") else int(w.get("base_hubcaps", 1))) + ammo_bonus()
	if lv >= 2:
		count += maxi(1, roundi(weapon_step_mult("chakram", 2)))
	if lv >= 5:
		count += maxi(1, roundi(weapon_step_mult("chakram", 5)))
	var range := 850.0 if evolutions.has("chakram") else float(w.get("base_range", 420.0))
	if lv >= 4:
		range *= 1.0 + 0.30 * weapon_step_mult("chakram", 4)
	for n in range(count):
		var spread := (float(n) - float(count - 1) * 0.5) * 0.20
		if game.projectile_count()>=int(config.get("limits",{}).get("projectiles",400)): break
		record_pool.push(chakrams,"chakrams",{
			"pos": game.player_pos,
			"dir": game.last_aim.rotated(spread).normalized(),
			"origin": game.player_pos,
			"range": range,
			"returning": false,
			"hit": {},
			"bounces": 1 if lv >= 5 else 0,
			"orbit_angle": TAU * float(n) / float(count),
			"orbit_age": 0.0,
			"hit_reset": 0.0,
		},96)

func _damage_area(center: Vector2, radius: float, damage: float, source: String) -> void:
	if game == null:
		return
	for i in game.enemy_indices_near(center,radius):
		if i >= game.enemies.size():
			continue
		if center.distance_to(Vector2(game.enemies[i]["pos"])) <= radius:
			game.phase_b_damage_enemy(i, damage, roll_crit(), source)

func _trim_effect_array(items: Array, cap: int) -> void:
	while items.size() > cap:
		items.pop_front()

func _enforce_weapon_effect_caps() -> void:
	var cap := int(config.get("limits", {}).get("weapon_effects", 160))
	_trim_effect_array(molotov_pools, cap)
	_trim_effect_array(rockets, cap)
	_trim_effect_array(chakrams, cap)
	_trim_effect_array(lightning_arcs, cap)
	_trim_effect_array(drone_shots, cap)
	var remaining: int=int(config.get("limits",{}).get("projectiles",400))-game.bullets.size()
	for key in ["rockets","chakrams","lightning_arcs","drone_shots"]:
		var items:Array=get(key)
		while items.size()>maxi(0,remaining): record_pool.remove(items,items.size()-1,key)
		remaining-=items.size()

func _update_weapon_effects(delta: float) -> void:
	if game == null:
		return
	for key in weapon_clocks.keys():
		weapon_clocks[key] = maxf(0.0, float(weapon_clocks[key]) - delta)

	if weapons.has("molotov") and float(weapon_clocks["molotov"]) <= 0.0:
		_spawn_molotovs()
		weapon_clocks["molotov"] = float(config["weapons"]["molotov"].get("base_cooldown", 3.2)) * cooldown_multiplier() / attack_speed_multiplier()
	if weapons.has("lightning") and float(weapon_clocks["lightning"]) <= 0.0:
		_fire_lightning()
		var cd := float(config["weapons"]["lightning"].get("base_cooldown", 2.2))
		if int(weapons["lightning"]) >= 4:
			cd *= 1.0 - 0.15 * weapon_step_mult("lightning", 4)
		weapon_clocks["lightning"] = (0.4 if evolutions.has("lightning") else cd * cooldown_multiplier() / attack_speed_multiplier())
	if weapons.has("rocket") and float(weapon_clocks["rocket"]) <= 0.0:
		_spawn_rockets()
		weapon_clocks["rocket"] = float(config["weapons"]["rocket"].get("base_cooldown", 3.0)) * cooldown_multiplier() / attack_speed_multiplier()
	if weapons.has("drone") and float(weapon_clocks["drone"]) <= 0.0:
		_fire_drones()
		var period := float(config["weapons"]["drone"].get("base_fire_period", 0.80))
		if int(weapons["drone"]) >= 3:
			period /= 1.0 + 0.20 * weapon_step_mult("drone", 3)
		weapon_clocks["drone"] = period / attack_speed_multiplier()
	if weapons.has("chakram") and float(weapon_clocks["chakram"]) <= 0.0:
		_spawn_chakrams()
		weapon_clocks["chakram"] = float(config["weapons"]["chakram"].get("base_cooldown", 2.5)) * cooldown_multiplier() / attack_speed_multiplier()

	for i in range(molotov_pools.size() - 1, -1, -1):
		var pool: Dictionary = molotov_pools[i]
		pool["life"] = float(pool["life"]) - delta
		pool["tick"] = float(pool["tick"]) - delta
		if float(pool["tick"]) <= 0.0:
			pool["tick"] = 0.25
			_damage_area(Vector2(pool["pos"]), float(pool["radius"]), float(pool["dps"]) * 0.25, "molotov")
		if float(pool["life"]) <= 0.0:
			record_pool.remove(molotov_pools,i,"molotov_pools")

	for i in range(rockets.size() - 1, -1, -1):
		if game.enemies.is_empty():
			record_pool.remove(rockets,i,"rockets")
			continue
		var rocket: Dictionary = rockets[i]
		var idx := _nearest_enemy_index(Vector2(rocket["pos"]))
		if idx < 0:
			record_pool.remove(rockets,i,"rockets")
			continue
		var target := Vector2(game.enemies[idx]["pos"])
		var desired := (target - Vector2(rocket["pos"])).normalized()
		rocket["dir"] = Vector2(rocket["dir"]).lerp(desired, minf(1.0, delta * 5.0)).normalized()
		var speed := float(config["weapons"]["rocket"].get("rocket_speed", 430.0)) * speed_multiplier()
		rocket["pos"] = Vector2(rocket["pos"]) + Vector2(rocket["dir"]) * speed * delta
		rocket["life"] = float(rocket["life"]) - delta
		if Vector2(rocket["pos"]).distance_to(target) < 28.0 or float(rocket["life"]) <= 0.0:
			var lv := int(weapons["rocket"])
			var damage := float(config["weapons"]["rocket"].get("base_damage", 6.0)) * damage_multiplier()
			if lv >= 4:
				damage *= 1.0 + 0.20 * weapon_step_mult("rocket", 4)
			var radius := float(config["weapons"]["rocket"].get("base_radius", 135.0)) * area_multiplier()
			if lv >= 3:
				radius *= 1.0 + 0.25 * weapon_step_mult("rocket", 3)
			_damage_area(Vector2(rocket["pos"]), radius, damage, "rocket")
			game.transient_pool.push(game.impact_marks,"impact_marks",{"pos": rocket["pos"], "life": 0.55, "blast": true},120)
			record_pool.remove(rockets,i,"rockets")

	for i in range(chakrams.size() - 1, -1, -1):
		var ch: Dictionary = chakrams[i]
		var speed := float(config["weapons"]["chakram"].get("travel_speed", 520.0)) * speed_multiplier()
		if evolutions.has("chakram"):
			ch["orbit_age"] = float(ch["orbit_age"]) + delta
			ch["hit_reset"] = float(ch["hit_reset"]) + delta
			ch["pos"] = game.player_pos + Vector2.from_angle(float(ch["orbit_angle"]) + float(ch["orbit_age"]) * 3.2) * 410.0
			if float(ch["hit_reset"]) >= 0.45:
				ch["hit"] = {}
				ch["hit_reset"] = 0.0
			if float(ch["orbit_age"]) > 8.0:
				record_pool.remove(chakrams,i,"chakrams")
				continue
		elif bool(ch["returning"]):
			var to_player: Vector2 = game.player_pos - Vector2(ch["pos"])
			ch["dir"] = to_player.normalized()
			ch["pos"] = Vector2(ch["pos"]) + Vector2(ch["dir"]) * speed * delta
			if to_player.length() < 28.0:
				record_pool.remove(chakrams,i,"chakrams")
				continue
		else:
			var next_pos := Vector2(ch["pos"]) + Vector2(ch["dir"]) * speed * delta
			if game._circle_hits_blocker(next_pos, 18.0) and int(ch.get("bounces", 0)) > 0:
				ch["dir"] = -Vector2(ch["dir"])
				ch["bounces"] = int(ch["bounces"]) - 1
			else:
				ch["pos"] = next_pos
			if Vector2(ch["pos"]).distance_to(Vector2(ch["origin"])) >= float(ch["range"]):
				ch["returning"] = true
		for e in game.enemy_indices_near(Vector2(ch["pos"]),32.0):
			if e >= game.enemies.size():
				continue
			var enemy: Dictionary = game.enemies[e]
			var uid := int(enemy.get("uid", e))
			var hit_map: Dictionary = ch["hit"]
			if hit_map.has(uid):
				continue
			if Vector2(ch["pos"]).distance_to(Vector2(enemy["pos"])) < 32.0:
				var damage := float(config["weapons"]["chakram"].get("base_damage", 3.0)) * damage_multiplier()
				if int(weapons["chakram"]) >= 3:
					damage *= 1.0 + 0.20 * weapon_step_mult("chakram", 3)
				game.phase_b_damage_enemy(e, damage, true if evolutions.has("chakram") else roll_crit(), "chakram")
				hit_map[uid] = true
				ch["hit"] = hit_map

	for i in range(lightning_arcs.size() - 1, -1, -1):
		lightning_arcs[i]["life"] = float(lightning_arcs[i]["life"]) - delta
		if float(lightning_arcs[i]["life"]) <= 0.0:
			record_pool.remove(lightning_arcs,i,"lightning_arcs")
	_enforce_weapon_effect_caps()
	for i in range(drone_shots.size() - 1, -1, -1):
		drone_shots[i]["life"] = float(drone_shots[i]["life"]) - delta
		if float(drone_shots[i]["life"]) <= 0.0:
			record_pool.remove(drone_shots,i,"drone_shots")

func _physics_process(delta: float) -> void:
	if game == null or config.is_empty() or choosing:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	var xp_cfg: Dictionary = config.get("xp", {})
	var radius: float = float(xp_cfg.get("pickup_radius_tiles", 1.2)) * game.TILE * (1.0 + float(config.get("passives", {}).get("magnet", {}).get("per_level", 0.30)) * passive_points("magnet"))
	var ages: Dictionary=xp_cfg.get("vacuum_age_seconds_by_level",{})
	var vacuum_age := float(ages.get(str(level),ages.get("default",xp_cfg.get("vacuum_age_seconds",8.0))))
	var pickup_speed := float(xp_cfg.get("pickup_speed", 850.0))
	var vacuum_speed := float(xp_cfg.get("vacuum_speed", 1250.0))
	var pickup_distance := float(xp_cfg.get("pickup_distance", 28.0))
	var wave_break := not bool(game.wave_active)

	for i in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[i]
		gem["age"] = float(gem.get("age", 0.0)) + delta
		var pos := Vector2(gem["pos"])
		var dist := pos.distance_to(game.player_pos)
		var forced := wave_break or float(gem["age"]) >= vacuum_age
		if dist < radius or forced:
			var speed := vacuum_speed if forced else pickup_speed
			var next_pos := pos.move_toward(game.player_pos, delta * speed)
			gem["pos"] = next_pos
			if next_pos.distance_to(game.player_pos) < pickup_distance:
				_collect_xp(int(gem["value"]))
				record_pool.remove(gems,i,"gems")

	orbit_clock += delta * speed_multiplier()
	if weapons.has("buzzsaw"):
		var w: Dictionary = config["weapons"]["buzzsaw"]
		var saw_level := int(weapons["buzzsaw"])
		var count := 16 if evolutions.has("buzzsaw") else int(w.get("base_blades", 1))
		if saw_level >= 2:
			count += maxi(1, roundi(weapon_step_mult("buzzsaw", 2)))
		if saw_level >= 5:
			count += maxi(1, roundi(weapon_step_mult("buzzsaw", 5)))
		var orbit_radius := float(w.get("base_radius", 125.0)) * area_multiplier()
		if saw_level >= 4:
			orbit_radius *= 1.0 + 0.25 * weapon_step_mult("buzzsaw", 4)
		var orbit_speed := float(w.get("base_speed", 3.2)) * speed_multiplier()
		if saw_level >= 5:
			orbit_speed *= 1.0 + 0.30 * weapon_step_mult("buzzsaw", 5)
		var saw_damage := float(w.get("base_damage_per_second", 4.0)) * damage_multiplier()
		if saw_level >= 3:
			saw_damage *= 1.0 + 0.20 * weapon_step_mult("buzzsaw", 3)
		for blade in range(count):
			var theta := orbit_clock * orbit_speed * (-1.0 if evolutions.has("buzzsaw") and blade % 2 == 1 else 1.0) + TAU * float(blade) / float(count)
			var blade_pos: Vector2 = game.player_pos + Vector2.from_angle(theta) * (orbit_radius * (0.70 if evolutions.has("buzzsaw") and blade % 2 == 1 else 1.0))
			for i in game.enemy_indices_near(blade_pos,30.0):
				if i >= game.enemies.size():
					continue
				if blade_pos.distance_to(Vector2(game.enemies[i]["pos"])) < 30.0:
					game.phase_b_damage_enemy(i, saw_damage * delta, roll_crit(), "buzzsaw")
	_update_weapon_effects(delta)
	queue_redraw()

func _draw() -> void:

	for pool in molotov_pools:
		var life_alpha := clampf(float(pool["life"]) / 1.0, 0.15, 0.75)
		draw_circle(Vector2(pool["pos"]), float(pool["radius"]), Color(0.94, 0.28, 0.05, 0.13 * life_alpha))
		draw_arc(Vector2(pool["pos"]), float(pool["radius"]) * 0.85, 0.0, TAU, 24, Color(1.0, 0.58, 0.10, 0.70), 5.0)

	for rocket in rockets:
		var p: Vector2 = Vector2(rocket["pos"])
		var d := Vector2(rocket["dir"])
		draw_line(p - d * 30.0, p, Color(0.55,0.55,0.55,0.7), 6.0)
		draw_circle(p, 8.0, Color("#F2A23A"))

	for arc in lightning_arcs:
		draw_line(Vector2(arc["a"]), Vector2(arc["b"]), Color("#CFFBFF"), 5.0)
		draw_line(Vector2(arc["a"]), Vector2(arc["b"]), Color("#3FD0E0"), 2.0)

	for shot in drone_shots:
		draw_line(Vector2(shot["a"]), Vector2(shot["b"]), Color("#9CF7FF"), 3.0)

	if weapons.has("drone") and game != null:
		var w: Dictionary = config["weapons"]["drone"]
		var count := 8 if evolutions.has("drone") else int(w.get("base_drones", 1))
		var lv := int(weapons["drone"])
		if lv >= 2:
			count += maxi(1, roundi(weapon_step_mult("drone", 2)))
		if lv >= 5:
			count += maxi(1, roundi(weapon_step_mult("drone", 5)))
		for i in range(count):
			var theta := orbit_clock * 1.7 + TAU * float(i) / float(count)
			var p: Vector2 = game.player_pos + Vector2.from_angle(theta) * float(w.get("drone_radius", 82.0))
			draw_circle(p, 14.0, Color("#48555B"))
			draw_rect(Rect2(p - Vector2(10,3), Vector2(20,6)), Color("#9CF7FF"))

	if weapons.has("buzzsaw") and game != null:
		var w: Dictionary = config["weapons"]["buzzsaw"]
		var saw_level := int(weapons["buzzsaw"])
		var count := 8 if evolutions.has("buzzsaw") else int(w.get("base_blades", 1))
		if saw_level >= 2:
			count += maxi(1, roundi(weapon_step_mult("buzzsaw", 2)))
		if saw_level >= 5:
			count += maxi(1, roundi(weapon_step_mult("buzzsaw", 5)))
		var orbit_radius := float(w.get("base_radius", 125.0)) * area_multiplier()
		if saw_level >= 4:
			orbit_radius *= 1.0 + 0.25 * weapon_step_mult("buzzsaw", 4)
		var orbit_speed := float(w.get("base_speed", 3.2)) * speed_multiplier()
		for blade in range(count):
			var theta := orbit_clock * orbit_speed * (-1.0 if evolutions.has("buzzsaw") and blade % 2 == 1 else 1.0) + TAU * float(blade) / float(count)
			var p: Vector2 = game.player_pos + Vector2.from_angle(theta) * (orbit_radius * (0.70 if evolutions.has("buzzsaw") and blade % 2 == 1 else 1.0))
			draw_set_transform(p, orbit_clock * 9.0, Vector2.ONE)
			var teeth := PackedVector2Array()
			for tooth in range(16):
				var a := TAU * float(tooth) / 16.0
				var r := 26.0 if tooth % 2 == 0 else 20.0
				teeth.append(Vector2.from_angle(a) * r)
			draw_colored_polygon(teeth, Color("#B9C1C5"))
			draw_circle(Vector2.ZERO, 12.0, Color("#596267"))
			draw_circle(Vector2.ZERO, 4.0, Color("#2A3033"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for ch in chakrams:
		var p: Vector2 = Vector2(ch["pos"])
		var spin := orbit_clock * 12.0
		draw_set_transform(p, spin, Vector2.ONE)
		draw_circle(Vector2.ZERO, 22.0, Color("#4D555A"))
		draw_circle(Vector2.ZERO, 18.0, Color("#AEB8BD"))
		draw_circle(Vector2.ZERO, 13.0, Color("#6F797E"))
		for spoke in range(6):
			var a := TAU * float(spoke) / 6.0
			draw_line(Vector2.from_angle(a) * 5.0, Vector2.from_angle(a) * 14.0, Color("#D9E0E3"), 3.0)
		draw_arc(Vector2.ZERO, 17.0, -2.4, -0.5, 12, Color.WHITE, 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
