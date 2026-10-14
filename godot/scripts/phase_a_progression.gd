extends Node2D
signal level_up_requested
const DATA_PATH := "res://data/phase_a.json"
var game: Node2D
var config: Dictionary = {}
var level := 1
var xp := 0
var gems: Array[Dictionary] = []
var weapons: Dictionary = {"scrap_smg":1}
var passives: Dictionary = {}
var invulnerability := 0.0
var orbit_clock := 0.0
var boom_clock := 0.0
var pending_levels := 0
var choosing := false
var banished: Array[String] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		config = JSON.parse_string(file.get_as_text())
	z_index = 3

func xp_required(n: int) -> int:
	var c: Dictionary = config.get("xp", {})
	return roundi(float(c.get("base", 6)) + float(c.get("linear", 4)) * (n-1) + float(c.get("quadratic", 0.12)) * pow(n-1, 2))

func drop_xp(pos: Vector2, kind: String) -> void:
	var value := int(config.get("enemy_xp", {}).get(kind, 1))
	gems.append({"pos":pos,"value":value})
	var threshold := int(config.get("xp", {}).get("merge_threshold", 200))
	while gems.size() > threshold:
		var first: Dictionary = gems.pop_front()
		if not gems.is_empty():
			gems[0]["value"] += int(first["value"])
	queue_redraw()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_required(level):
		xp -= xp_required(level)
		level += 1
		pending_levels += 1
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

func banish(id: String) -> void:
	if not banished.has(id):
		banished.append(id)

func available_choices() -> Array[String]:
	var options: Array[String] = []
	for id in config.get("weapons", {}):
		if banished.has(str(id)):
			continue
		var weapon_data: Dictionary = config.get("weapons", {}).get(id, {})
		var weapon_max := int(weapon_data.get("max_level", 5))
		if weapons.has(id):
			if int(weapons[id]) < weapon_max:
				options.append(id)
		elif weapons.size() < int(config.get("limits", {}).get("weapons", 6)):
			options.append(id)
	for id in config.get("passives", {}):
		if banished.has(str(id)):
			continue
		var passive_data: Dictionary = config.get("passives", {}).get(id, {})
		var passive_max := int(passive_data.get("max_level", 5))
		if passives.has(id):
			if int(passives[id]) < passive_max:
				options.append(id)
		elif passives.size() < int(config.get("limits", {}).get("passives", 6)):
			options.append(id)
	options.shuffle()
	return options.slice(0, mini(3, options.size()))

func choose(id: String) -> void:
	if config.get("weapons", {}).has(id):
		var weapon_data: Dictionary = config.get("weapons", {}).get(id, {})
		var weapon_max := int(weapon_data.get("max_level", 5))
		weapons[id] = mini(weapon_max, int(weapons.get(id, 0)) + 1)
	elif config.get("passives", {}).has(id):
		var passive_data: Dictionary = config.get("passives", {}).get(id, {})
		var passive_max := int(passive_data.get("max_level", 5))
		passives[id] = mini(passive_max, int(passives.get(id, 0)) + 1)
		if id == "thick_hide" and game != null:
			game.player_max_hp += 15
			game.player_armor += 1
			game.player_hp = mini(game.player_max_hp, game.player_hp + 15)
	finish_choice()

func damage_multiplier() -> float:
	return 1.0 + 0.1 * int(passives.get("muscle", 0))

func _physics_process(delta: float) -> void:
	if game == null or config.is_empty() or choosing:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	var radius: float = float(config["xp"]["pickup_radius_tiles"]) * game.TILE * pow(1.3, int(passives.get("magnet", 0)))
	for i in range(gems.size()-1, -1, -1):
		var pos: Vector2 = gems[i]["pos"]
		var dist := pos.distance_to(game.player_pos)
		if dist < radius:
			var next_pos := pos.move_toward(game.player_pos, delta * 850.0)
			gems[i]["pos"] = next_pos
			if next_pos.distance_to(game.player_pos) < 28.0:
				add_xp(int(gems[i]["value"]))
				gems.remove_at(i)
	orbit_clock += delta
	if weapons.has("buzzsaw"):
		var saw_level := int(weapons["buzzsaw"])
		var count := 1 + (1 if saw_level >= 2 else 0) + (1 if saw_level >= 5 else 0)
		var orbit_radius := 125.0 * (1.25 if saw_level >= 4 else 1.0)
		var orbit_speed := 3.2 * (1.30 if saw_level >= 5 else 1.0)
		var saw_damage := 4.0 * (1.20 if saw_level >= 3 else 1.0) * damage_multiplier()
		for blade in range(count):
			var theta := orbit_clock * orbit_speed + TAU * float(blade) / float(count)
			var blade_pos: Vector2 = game.player_pos + Vector2.from_angle(theta) * orbit_radius
			for i in range(game.enemies.size()-1,-1,-1):
				if blade_pos.distance_to(game.enemies[i]["pos"]) < 30.0:
					game.enemies[i]["hp"] -= delta * saw_damage
					if game.enemies[i]["hp"] <= 0:
						game._phase_a_kill_enemy(i)
	queue_redraw()

func _draw() -> void:
	for gem in gems:
		var p: Vector2 = gem["pos"]
		var v: int = gem["value"]
		var tint := Color("#9c6cff") if v >= 10 else (Color("#6FBF4A") if v >= 2 else Color("#5bceff"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(7,0),p+Vector2(0,9),p+Vector2(-7,0)]),tint)
	if weapons.has("buzzsaw") and game != null:
		var saw_level := int(weapons["buzzsaw"])
		var count := 1 + (1 if saw_level >= 2 else 0) + (1 if saw_level >= 5 else 0)
		var orbit_radius := 125.0 * (1.25 if saw_level >= 4 else 1.0)
		var orbit_speed := 3.2 * (1.30 if saw_level >= 5 else 1.0)
		for blade in range(count):
			var theta := orbit_clock * orbit_speed + TAU * float(blade) / float(count)
			for trail_step in range(3, 0, -1):
				var trail_theta := theta - float(trail_step) * 0.07
				var trail_pos := game.player_pos + Vector2.from_angle(trail_theta) * orbit_radius
				var trail_alpha := 0.05 + 0.045 * float(4 - trail_step)
				draw_circle(trail_pos, 17.0 - float(trail_step) * 2.0, Color(0.78, 0.86, 0.90, trail_alpha))
			var p: Vector2 = game.player_pos + Vector2.from_angle(theta) * orbit_radius
			var spin := orbit_clock * 11.0 + float(blade) * 1.7
			draw_set_transform(p, spin, Vector2.ONE)
			draw_circle(Vector2.ZERO, 24.0, Color("#4D555A"))
			draw_circle(Vector2.ZERO, 20.0, Color("#AEB8BD"))
			draw_circle(Vector2.ZERO, 15.5, Color("#6F797E"))
			for spoke in range(6):
				var angle := TAU * float(spoke) / 6.0
				var inner := Vector2.from_angle(angle) * 5.0
				var outer := Vector2.from_angle(angle) * 15.0
				draw_line(inner, outer, Color("#D9E0E3"), 3.2)
			draw_circle(Vector2.ZERO, 5.0, Color("#343A3E"))
			draw_arc(Vector2.ZERO, 18.0, -2.5, -0.55, 16, Color(1.0, 1.0, 1.0, 0.95), 3.5)
			draw_arc(Vector2.ZERO, 22.0, 0.65, 1.65, 10, Color(0.55, 0.62, 0.66, 0.8), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
