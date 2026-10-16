extends "res://scripts/phase_a_progression.gd"
var magnet_left := 0.0

func _ready() -> void:
	super._ready()
	config["limits"]["damage_numbers"] = int(game.rules.performance.damage_numbers)
	config["damage_numbers"]["merge_window_seconds"] = float(game.rules.performance.number_merge_seconds)
	config["pacing"]["spawn_interval_seconds"] = float(game.rules.pressure.spawn_interval_seconds)
	config["pacing"]["spawn_group_max"] = int(game.rules.pressure.spawn_group_max)
	config["pacing"]["pressure_by_wave"] = game.rules.pressure.minimums
	config["pacing"]["surge_last_seconds"] = float(game.rules.pressure.surge_seconds)
	config["pacing"]["surge_ring_count"] = int(game.rules.pressure.surge_ring_count)
	for id in game.rules.weapons.facing_descriptions:
		var text: Dictionary = game.rules.weapons.facing_descriptions[id]
		config.weapons[id].description = text.description
		config.weapons[id].level_adds[0] = text.first_level

func vacuum_all_gems() -> void:
	# Wave breaks no longer vacuum XP. Magnet is an explicit earned pickup.
	pass

func activate_magnet() -> void:
	magnet_left = float(game.rules.rewards.magnet_seconds)

func _physics_process(delta: float) -> void:
	if game == null or config.is_empty() or choosing:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	var xp_cfg: Dictionary = config.get("xp", {})
	magnet_left = maxf(0.0,magnet_left-delta)
	var radius: float = float(game.rules.rewards.pickup_radius_tiles) * game.TILE * (1.0 + float(config.get("passives", {}).get("magnet", {}).get("per_level", 0.30)) * passive_points("magnet"))
	var pickup_speed := float(xp_cfg.get("pickup_speed", 850.0))
	var vacuum_speed := float(xp_cfg.get("vacuum_speed", 1250.0))
	var pickup_distance := float(xp_cfg.get("pickup_distance", 28.0))
	if magnet_left > 0.0: radius = maxf(radius,float(game.rules.rewards.magnet_radius_tiles)*game.TILE)

	for i in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[i]
		gem["age"] = float(gem.get("age", 0.0)) + delta
		var pos := Vector2(gem["pos"])
		var dist := pos.distance_to(game.player_pos)
		if float(gem["age"]) >= float(game.rules.rewards.gem_lifetime_seconds):
			record_pool.remove(gems,i,"gems")
			continue
		var forced := magnet_left > 0.0
		if dist < radius:
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

func _process(_delta: float) -> void:
	# Run after the batch updates so fading changes alpha without allocating nodes.
	process_priority = 100
	var batch: MultiMeshInstance2D = get_child(0) as MultiMeshInstance2D
	if batch==null or batch.multimesh==null: return
	for i in range(mini(gems.size(),batch.multimesh.instance_count)):
		var color := batch.multimesh.get_instance_color(i)
		color.a = clampf((float(game.rules.rewards.gem_lifetime_seconds)-float(gems[i].age))/float(game.rules.rewards.gem_fade_seconds),0.0,1.0)
		batch.multimesh.set_instance_color(i,color)
