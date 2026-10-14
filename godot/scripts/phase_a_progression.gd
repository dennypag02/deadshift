extends Node2D
signal level_up_requested

const DATA_PATH := "res://data/phase_a.json"

var game: Node2D
var config: Dictionary = {}
var level := 1
var xp := 0
var gems: Array[Dictionary] = []
var weapons: Dictionary = {"scrap_smg": 1}
var passives: Dictionary = {}
var weapon_steps: Dictionary = {"scrap_smg": [1.0]}
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
	if OS.get_cmdline_user_args().has("--pacing-capture"):
		rng.seed = 20261014
	else:
		rng.randomize()
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		config = JSON.parse_string(file.get_as_text())
	rerolls_left = int(config.get("ui", {}).get("rerolls_per_run", 2))
	banishes_left = int(config.get("ui", {}).get("banishes_per_run", 1))
	z_index = 3

func xp_required(n: int) -> int:
	var c: Dictionary = config.get("xp", {})
	return roundi(float(c.get("base", 6)) + float(c.get("linear", 4)) * (n - 1) + float(c.get("quadratic", 0.12)) * pow(n - 1, 2))

func drop_xp(pos: Vector2, kind: String) -> void:
	var value := int(config.get("enemy_xp", {}).get(kind, 1))
	gems.append({"pos": pos, "value": value, "age": 0.0})
	xp_dropped_total += value
	var threshold := int(config.get("xp", {}).get("merge_threshold", 200))
	while gems.size() > threshold:
		var first: Dictionary = gems.pop_front()
		if not gems.is_empty():
			gems[0]["value"] = int(gems[0]["value"]) + int(first["value"])
	queue_redraw()

func vacuum_all_gems() -> void:
	for gem in gems:
		gem["age"] = float(config.get("xp", {}).get("vacuum_age_seconds", 6.0)) + 1.0

func _collect_xp(amount: int) -> void:
	xp_collected_total += amount
	add_xp(amount)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_required(level):
		xp -= xp_required(level)
		level += 1
		pending_levels += 1
		level_times.append({"level": level, "time": game.capture_clock if game != null and bool(game.capture_mode) else 0.0})
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

func choose(id: String) -> void:
	if id == "fallback_gold":
		if game != null:
			game.score += int(config.get("fallbacks", {}).get(id, {}).get("value", 50))
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
	var count := int(w.get("base_bottles", 1)) + ammo_bonus()
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
		var target := Vector2(game.enemies[idx]["pos"]) + Vector2.from_angle(TAU * float(n) / maxf(1.0, float(count))) * 35.0
		molotov_pools.append({"pos": target, "life": duration, "radius": radius, "dps": dps, "tick": 0.0})
		game.impact_marks.append({"pos": target, "life": 0.35, "blast": true})

func _fire_lightning() -> void:
	if not weapons.has("lightning") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["lightning"]
	var lv := int(weapons["lightning"])
	var chains := int(w.get("base_chains", 2)) + ammo_bonus()
	if lv >= 2:
		chains += maxi(1, roundi(weapon_step_mult("lightning", 2)))
	if lv >= 5:
		chains += maxi(1, roundi(2.0 * weapon_step_mult("lightning", 5)))
	var damage := float(w.get("base_damage", 4.0)) * damage_multiplier()
	if lv >= 3:
		damage *= 1.0 + 0.20 * weapon_step_mult("lightning", 3)
	var origin := game.player_pos
	var used: Array[int] = []
	for j in range(chains):
		var idx := _nearest_enemy_index(origin, used)
		if idx < 0:
			break
		var pos := Vector2(game.enemies[idx]["pos"])
		var crit := roll_crit()
		game.phase_b_damage_enemy(idx, damage, crit, "lightning")
		lightning_arcs.append({"a": origin, "b": pos, "life": 0.12})
		origin = pos
		used.append(idx)

func _spawn_rockets() -> void:
	if not weapons.has("rocket") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["rocket"]
	var lv := int(weapons["rocket"])
	var count := int(w.get("base_rockets", 1)) + ammo_bonus()
	if lv >= 2:
		count += maxi(1, roundi(weapon_step_mult("rocket", 2)))
	if lv >= 5:
		count += maxi(1, roundi(weapon_step_mult("rocket", 5)))
	for n in range(count):
		var angle := -0.12 * float(count - 1) * 0.5 + 0.12 * float(n)
		rockets.append({"pos": game.player_pos, "dir": game.last_aim.rotated(angle), "life": 3.0})

func _fire_drones() -> void:
	if not weapons.has("drone") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["drone"]
	var lv := int(weapons["drone"])
	var count := int(w.get("base_drones", 1))
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
		drone_shots.append({"a": game.player_pos, "b": target, "life": 0.10})
		if lv >= 5:
			_damage_area(target, float(w.get("mini_rocket_radius", 90.0)) * area_multiplier(), damage * 0.75, "drone_rocket")

func _spawn_chakrams() -> void:
	if not weapons.has("chakram") or game.enemies.is_empty():
		return
	var w: Dictionary = config["weapons"]["chakram"]
	var lv := int(weapons["chakram"])
	var count := int(w.get("base_hubcaps", 1)) + ammo_bonus()
	if lv >= 2:
		count += maxi(1, roundi(weapon_step_mult("chakram", 2)))
	if lv >= 5:
		count += maxi(1, roundi(weapon_step_mult("chakram", 5)))
	var range := float(w.get("base_range", 420.0))
	if lv >= 4:
		range *= 1.0 + 0.30 * weapon_step_mult("chakram", 4)
	for n in range(count):
		var spread := (float(n) - float(count - 1) * 0.5) * 0.20
		chakrams.append({
			"pos": game.player_pos,
			"dir": game.last_aim.rotated(spread).normalized(),
			"origin": game.player_pos,
			"range": range,
			"returning": false,
			"hit": {},
			"bounces": 1 if lv >= 5 else 0,
		})

func _damage_area(center: Vector2, radius: float, damage: float, source: String) -> void:
	if game == null:
		return
	for i in range(game.enemies.size() - 1, -1, -1):
		if i >= game.enemies.size():
			continue
		if center.distance_to(Vector2(game.enemies[i]["pos"])) <= radius:
			game.phase_b_damage_enemy(i, damage, roll_crit(), source)

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
		weapon_clocks["lightning"] = cd * cooldown_multiplier() / attack_speed_multiplier()
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
			molotov_pools.remove_at(i)

	for i in range(rockets.size() - 1, -1, -1):
		if game.enemies.is_empty():
			rockets.remove_at(i)
			continue
		var rocket: Dictionary = rockets[i]
		var idx := _nearest_enemy_index(Vector2(rocket["pos"]))
		if idx < 0:
			rockets.remove_at(i)
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
			game.impact_marks.append({"pos": rocket["pos"], "life": 0.55, "blast": true})
			rockets.remove_at(i)

	for i in range(chakrams.size() - 1, -1, -1):
		var ch: Dictionary = chakrams[i]
		var speed := float(config["weapons"]["chakram"].get("travel_speed", 520.0)) * speed_multiplier()
		if bool(ch["returning"]):
			var to_player := game.player_pos - Vector2(ch["pos"])
			ch["dir"] = to_player.normalized()
			ch["pos"] = Vector2(ch["pos"]) + Vector2(ch["dir"]) * speed * delta
			if to_player.length() < 28.0:
				chakrams.remove_at(i)
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
		for e in range(game.enemies.size() - 1, -1, -1):
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
				game.phase_b_damage_enemy(e, damage, roll_crit(), "chakram")
				hit_map[uid] = true
				ch["hit"] = hit_map

	for i in range(lightning_arcs.size() - 1, -1, -1):
		lightning_arcs[i]["life"] = float(lightning_arcs[i]["life"]) - delta
		if float(lightning_arcs[i]["life"]) <= 0.0:
			lightning_arcs.remove_at(i)
	for i in range(drone_shots.size() - 1, -1, -1):
		drone_shots[i]["life"] = float(drone_shots[i]["life"]) - delta
		if float(drone_shots[i]["life"]) <= 0.0:
			drone_shots.remove_at(i)

func _physics_process(delta: float) -> void:
	if game == null or config.is_empty() or choosing:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	var xp_cfg: Dictionary = config.get("xp", {})
	var radius := float(xp_cfg.get("pickup_radius_tiles", 1.2)) * game.TILE * (1.0 + float(config.get("passives", {}).get("magnet", {}).get("per_level", 0.30)) * passive_points("magnet"))
	var vacuum_age := float(xp_cfg.get("vacuum_age_seconds", 6.0))
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
				gems.remove_at(i)

	orbit_clock += delta * speed_multiplier()
	if weapons.has("buzzsaw"):
		var w: Dictionary = config["weapons"]["buzzsaw"]
		var saw_level := int(weapons["buzzsaw"])
		var count := int(w.get("base_blades", 1))
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
			var theta := orbit_clock * orbit_speed + TAU * float(blade) / float(count)
			var blade_pos := game.player_pos + Vector2.from_angle(theta) * orbit_radius
			for i in range(game.enemies.size() - 1, -1, -1):
				if i >= game.enemies.size():
					continue
				if blade_pos.distance_to(Vector2(game.enemies[i]["pos"])) < 30.0:
					game.phase_b_damage_enemy(i, saw_damage * delta, roll_crit(), "buzzsaw")
	_update_weapon_effects(delta)
	queue_redraw()

func _draw() -> void:
	for gem in gems:
		var p: Vector2 = gem["pos"]
		var v := int(gem["value"])
		var tint := Color("#9c6cff") if v >= 10 else (Color("#6FBF4A") if v >= 2 else Color("#5bceff"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0,-9), p + Vector2(7,0), p + Vector2(0,9), p + Vector2(-7,0)]), tint)

	for pool in molotov_pools:
		var life_alpha := clampf(float(pool["life"]) / 1.0, 0.15, 0.75)
		draw_circle(Vector2(pool["pos"]), float(pool["radius"]), Color(0.94, 0.28, 0.05, 0.13 * life_alpha))
		draw_arc(Vector2(pool["pos"]), float(pool["radius"]) * 0.85, 0.0, TAU, 24, Color(1.0, 0.58, 0.10, 0.70), 5.0)

	for rocket in rockets:
		var p := Vector2(rocket["pos"])
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
		var count := int(w.get("base_drones", 1))
		var lv := int(weapons["drone"])
		if lv >= 2:
			count += maxi(1, roundi(weapon_step_mult("drone", 2)))
		if lv >= 5:
			count += maxi(1, roundi(weapon_step_mult("drone", 5)))
		for i in range(count):
			var theta := orbit_clock * 1.7 + TAU * float(i) / float(count)
			var p := game.player_pos + Vector2.from_angle(theta) * float(w.get("drone_radius", 82.0))
			draw_circle(p, 14.0, Color("#48555B"))
			draw_rect(Rect2(p - Vector2(10,3), Vector2(20,6)), Color("#9CF7FF"))

	if weapons.has("buzzsaw") and game != null:
		var w: Dictionary = config["weapons"]["buzzsaw"]
		var saw_level := int(weapons["buzzsaw"])
		var count := int(w.get("base_blades", 1))
		if saw_level >= 2:
			count += maxi(1, roundi(weapon_step_mult("buzzsaw", 2)))
		if saw_level >= 5:
			count += maxi(1, roundi(weapon_step_mult("buzzsaw", 5)))
		var orbit_radius := float(w.get("base_radius", 125.0)) * area_multiplier()
		if saw_level >= 4:
			orbit_radius *= 1.0 + 0.25 * weapon_step_mult("buzzsaw", 4)
		var orbit_speed := float(w.get("base_speed", 3.2)) * speed_multiplier()
		for blade in range(count):
			var theta := orbit_clock * orbit_speed + TAU * float(blade) / float(count)
			var p := game.player_pos + Vector2.from_angle(theta) * orbit_radius
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
		var p := Vector2(ch["pos"])
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
