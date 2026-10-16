extends Node2D
## One optional event per wave. Timers use the same pause-aware active clock as waves.
const AMBER := Color("#F2A23A")
const GUIDE = preload("res://scripts/objective_guidance.gd")
const OBJ_GENERATOR = preload("res://art/objectives/obj_generator.png")
const OBJ_SUPPLY_CRATE = preload("res://art/objectives/obj_supply_crate.png")
const OBJ_GAS_CAN = preload("res://art/objectives/obj_gas_can.png")
const OBJ_FUEL_CACHE = preload("res://art/objectives/obj_fuel_cache.png")
const OBJ_RELAY_PAD = preload("res://art/objectives/obj_relay_pad.png")
const OBJ_SWITCH_BOX = preload("res://art/objectives/obj_switch_box.png")
const OBJ_ZOMBIE_NEST = preload("res://art/objectives/obj_zombie_nest.png")
const OBJ_FLAME_TRAP = preload("res://art/objectives/obj_flame_trap.png")
const OBJ_FLOODLIGHT = preload("res://art/objectives/obj_floodlight.png")
var game: Node2D
var config: Dictionary = {}
var active: Dictionary = {}
var offered_waves: Dictionary = {}
var earned: Dictionary = {}
var toast_text := ""
var toast_left := 0.0
var rejected_spawns := 0
var turret_clock := 0.0
var flame_clock := 0.0
var shot_left := 0.0
var shot_to := Vector2.ZERO
var aiming := false
var old_time_scale := 1.0

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stage2_events.json"))
	assert(not config.is_empty(), "Stage 2 event configuration is required")
	for row in config["schedule"]:
		assert(float(row["seconds"]) >= 30.0 and float(row["seconds"]) <= 60.0)

func value(key: String) -> float:
	return float(config[key])

func _draw_prop(texture: Texture2D, center: Vector2, tint: Color = Color.WHITE) -> void:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, tint)

func kind() -> String:
	return str(active.get("kind", ""))

func _walk(pos: Vector2) -> Vector2:
	return game._nearest_walkable_position(pos, game.PLAYER_RADIUS)

func _points(event_kind: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	match event_kind:
		"generator": points.append(game.GENERATOR_POS)
		"supplies":
			for cache in game.supply_caches: points.append(cache["pos"])
		"nest":
			var nearest: Vector2 = game.NEST_WEST
			var distance := INF
			for nest in game.infestation_nests:
				var d: float = game.player_pos.distance_to(nest["pos"])
				if d < distance:
					nearest = nest["pos"]
					distance = d
			points.append(nearest)
		"relay": points.assign([game.RELAY_RED, game.RELAY_BLUE, game.RELAY_YELLOW])
		"chain":
			for pump in game.pumps:
				if points.size() < 3: points.append(pump["pos"])
		"fuel": points.assign([_walk(game.SUPPLY_AUTOSHOP), _walk(Vector2(16.0, 35.0) * game.TILE)])
		"lockdown": points.assign([_walk(game.MOTEL_A), _walk(game.MOTEL_B)])
		"mechanic": points.append(_walk(game.SUPPLY_AUTOSHOP + Vector2(240, -200)))
		"oil":
			var found := false
			for y in range(game.MAP_H):
				for x in range(game.MAP_W):
					if not found and game._tile_char(x, y) == "o":
						points.append(Vector2(x + 0.5, y + 0.5) * game.TILE)
						found = true
	return points

func start_wave(number: int) -> void:
	if offered_waves.has(number): return
	if not active.is_empty(): resolve("missed", "wave_ended")
	offered_waves[number] = true
	if number == 10:
		game.run_log.emit("final_stand_started", {"arsenal":earned.keys()})
		return
	for definition in config["schedule"]:
		if int(definition["wave"]) != number: continue
		active = definition.duplicate(true)
		active.merge({"elapsed":0.0,"charge":0.0,"step":0,"hp":value("nest_hp"),"carrying":false,"switch_elapsed":0.0,"mechanic_uid":-1,"status":"active","points":_points(str(definition["kind"]))})
		assert(not active["points"].is_empty(), "Event has no valid location")
		active["row"] = {"id":active["id"],"kind":kind(),"wave":number,"offered_s":game.run_clock,"deadline_s":game.run_clock + float(active["seconds"]),"status":"active","time_to_complete_s":null,"rewards":active["rewards"].duplicate()}
		game.run_log.rows.append(active["row"])
		if kind() == "supplies":
			for cache in game.supply_caches: cache["collected"] = false
		if kind() == "mechanic": _spawn_mechanic()
		game.run_log.emit("event_offered", {"id":active["id"],"kind":kind(),"duration_s":active["seconds"],"reward":active["reward"],"tutorial_pressure_multiplier":pressure_multiplier()})
		game.run_log.checkpoint()
		game.banner.text = "EVENT: " + str(active["title"]) + "\n%.0f s -> %s" % [float(active["seconds"]), str(active["reward"])]
		if game.guidance != null:
			game.guidance.refresh_target()
			game.guidance.rebuild_route()
		queue_redraw()
		return

func is_tutorial() -> bool:
	return not active.is_empty() and active["id"] == "generator" and int(active["wave"]) == 1

func pressure_multiplier() -> float:
	var mult := value("tutorial_pressure_multiplier") if is_tutorial() else 1.0
	if earned.has("fewer_spawns"): mult *= value("nest_spawn_multiplier")
	return mult

func spawn_allowed(pos: Vector2, radius: float = 24.0) -> bool:
	if earned.has("motel_lockdown") and Rect2(Vector2(22, 7) * game.TILE, Vector2(9, 11) * game.TILE).has_point(pos):
		return false
	if not is_tutorial(): return true
	var target_pos: Vector2 = active["points"][0]
	var width := value("tutorial_corridor_half_width") + radius
	var closest := Geometry2D.get_closest_point_to_segment(pos, game.player_pos, target_pos)
	if pos.distance_to(closest) < width:
		rejected_spawns += 1
		return false
	# Also protect the obstacle-aware route, not only a straight line through buildings.
	if game.guidance != null:
		var path: PackedVector2Array = game.guidance.route
		for i in range(1, path.size()):
			var first: Vector2 = game.player_pos if i == 1 else path[i - 1]
			if pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, first, path[i])) < width:
				rejected_spawns += 1
				return false
	return true

func remaining() -> float:
	return maxf(0.0, float(active.get("seconds", 0)) - float(active.get("elapsed", 0)))

func _mechanic_index() -> int:
	var uid := int(active.get("mechanic_uid", -1))
	for i in range(game.enemies.size()):
		if int(game.enemies[i].get("uid", -2)) == uid: return i
	return -1

func _spawn_mechanic() -> void:
	if game.enemies.size() >= 250: return
	var before: int = game.enemies.size()
	game._append_enemy("mech_miniboss", active["points"][0])
	if game.enemies.size() == before: return
	var enemy: Dictionary = game.enemies[-1]
	enemy["hp"] = value("mechanic_hp")
	enemy["speed"] = value("mechanic_speed")
	enemy["stage2_mechanic"] = true
	active["mechanic_uid"] = enemy["uid"]
	active["hp"] = enemy["hp"]

func target() -> Dictionary:
	if active.is_empty(): return {}
	var step := int(active["step"])
	var points: Array = active["points"]
	var point: Vector2 = points[mini(step, points.size() - 1)]
	if kind() == "supplies":
		var best := INF
		for cache in game.supply_caches:
			if cache["collected"]: continue
			var distance: float = game.player_pos.distance_to(cache["pos"])
			if distance < best:
				best = distance
				point = cache["pos"]
	if kind() == "mechanic":
		var index := _mechanic_index()
		if index >= 0: point = game.enemies[index]["pos"]
	var icon := str({"generator":"bolt","supplies":"crate","nest":"skull","relay":"relay"}.get(kind(), "relay"))
	return {"id":str(active["id"]) + ("_step_%d" % step if step > 0 else ""),"kind":icon,"label":active["title"],"pos":point,"done":false,"reward":active["reward"],"reward_icon":active["reward_icon"]}

func map_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in config.get("schedule", []):
		var points := _points(str(definition["kind"]))
		if points.is_empty(): continue
		var done := false
		for row in game.run_log.rows:
			if row["id"] == definition["id"]: done = row["status"] != "active"
		var entry := {"id":definition["id"],"kind":str({"generator":"bolt","supplies":"crate","nest":"skull"}.get(definition["kind"], "relay")),"label":"W%d %s" % [definition["wave"],definition["title"]],"pos":points[0],"done":done,"reward":definition["reward"],"reward_icon":definition["reward_icon"]}
		if not active.is_empty() and active["id"] == definition["id"]: entry = target()
		result.append(entry)
	return result

func progress_text() -> String:
	if active.is_empty(): return "NEXT EVENT NEXT WAVE" if game.wave < 9 else "SURVIVE"
	match kind():
		"generator": return "CHARGE %d%%" % roundi(float(active["charge"]) / value("generator_charge_seconds") * 100.0)
		"supplies": return "SUPPLIES %d/3" % int(active["step"])
		"nest": return "NEST HP %d/%d" % [ceili(float(active["hp"])),int(value("nest_hp"))]
		"relay": return "PADS %d/3" % int(active["step"])
		"chain": return "PUMPS %d/%d - SHOOT IN ORDER" % [active["step"], active["points"].size()]
		"fuel": return "DELIVER CAN - 80% SPEED" if active["carrying"] else "COLLECT THE GAS CAN"
		"mechanic": return "HP %d - SHOOT BACK ON WINDUP" % ceili(float(active["hp"]))
		"lockdown": return "SWITCHES %d/2%s" % [active["step"], " - %.1f s" % maxf(0.0,value("lockdown_switch_window")-float(active["switch_elapsed"])) if int(active["step"]) == 1 else ""]
		"oil": return "LURE %d/%d - SHOOT BARREL" % [mini(_oil_count(),int(value("oil_lure_count"))),int(value("oil_lure_count"))]
	return ""

func progress_ratio() -> float:
	if active.is_empty(): return 0.0
	match kind():
		"generator": return float(active["charge"]) / value("generator_charge_seconds")
		"nest": return float(active["hp"]) / value("nest_hp")
		"relay": return (float(active["step"]) + float(active["charge"]) / value("relay_charge_seconds")) / 3.0
	return 0.0

func player_damaged() -> void:
	if kind() == "generator" and float(active["charge"]) > 0.0:
		active["charge"] = 0.0
		game.run_log.emit("generator_charge_interrupted", {"id":active["id"]})

func movement_multiplier() -> float:
	return value("fuel_speed_multiplier") if kind() == "fuel" and active["carrying"] else 1.0

func tick(dt: float) -> void:
	toast_left = maxf(0.0, toast_left - dt)
	shot_left = maxf(0.0, shot_left - dt)
	_tick_rewards(dt)
	if active.is_empty():
		queue_redraw()
		return
	active["elapsed"] = float(active["elapsed"]) + dt
	# At the deadline, expiry wins. Pause and hit-stop cannot create extra time.
	if remaining() <= 0.00001:
		resolve("missed", "timeout")
		return
	var point: Vector2 = target()["pos"]
	var inside: bool = game.player_pos.distance_to(point) < value("interact_radius")
	match kind():
		"generator", "relay":
			active["charge"] = float(active["charge"]) + dt if inside else 0.0
			var needed := value("generator_charge_seconds") if kind() == "generator" else value("relay_charge_seconds")
			if float(active["charge"]) >= needed:
				if kind() == "generator":
					game.generator_active = true
					resolve("completed", "charged")
				else:
					active["step"] = int(active["step"]) + 1
					active["charge"] = 0.0
					if int(active["step"]) == 3:
						game.puzzle_complete = true
						resolve("completed", "pads_complete")
		"supplies":
			for cache in game.supply_caches:
				if not cache["collected"] and game.player_pos.distance_to(cache["pos"]) < value("interact_radius"):
					cache["collected"] = true
					active["step"] = int(active["step"]) + 1
					game.run_log.emit("supply_collected", {"site":cache["name"],"count":active["step"]})
			if int(active["step"]) == 3: resolve("completed", "crates_collected")
		"fuel":
			if inside:
				if not active["carrying"]:
					active["carrying"] = true
					active["step"] = 1
				else: resolve("completed", "fuel_delivered")
		"lockdown":
			if int(active["step"]) == 1:
				active["switch_elapsed"] = float(active["switch_elapsed"]) + dt
				if float(active["switch_elapsed"]) > value("lockdown_switch_window"):
					active["step"] = 0
					active["switch_elapsed"] = 0.0
					inside = game.player_pos.distance_to(active["points"][0]) < value("interact_radius")
			if inside:
				active["step"] = int(active["step"]) + 1
				if int(active["step"]) == 2: resolve("completed", "switches_complete")
		"mechanic":
			if int(active["mechanic_uid"]) < 0: _spawn_mechanic()
			var index := _mechanic_index()
			if index >= 0:
				var enemy: Dictionary = game.enemies[index]
				active["hp"] = enemy["hp"]
				var winding: bool = fmod(float(active["elapsed"]),value("mechanic_cycle_seconds")) < value("mechanic_windup_seconds")
				enemy["speed"] = 0.0 if winding else value("mechanic_speed")
				enemy["tank_exposed"] = winding
			elif int(active["mechanic_uid"]) >= 0: resolve("completed", "mechanic_defeated")
	queue_redraw()

func mechanic_damage_multiplier(enemy: Dictionary) -> float:
	if not bool(enemy.get("stage2_mechanic", false)): return 1.0
	var from: Vector2 = (game.player_pos - Vector2(enemy["pos"])).normalized()
	return 1.0 if bool(enemy.get("tank_exposed",false)) and Vector2(enemy.get("facing",Vector2.RIGHT)).dot(from) < -0.15 else 0.0

func _oil_count() -> int:
	if kind() != "oil": return 0
	var count := 0
	for enemy in game.enemies:
		if Vector2(enemy["pos"]).distance_to(active["points"][0]) < value("oil_lure_radius"): count += 1
	return count

func aim_target() -> Dictionary:
	if kind() not in ["nest", "chain", "oil"]: return {}
	var entry := target()
	if game.player_pos.distance_to(entry["pos"]) > value("objective_aim_range"): return {}
	return entry

func hit_bullet(pos: Vector2, damage: float) -> bool:
	if kind() not in ["nest", "oil"]: return false
	if pos.distance_to(target()["pos"]) > value("shoot_radius"): return false
	if kind() == "oil":
		if _oil_count() >= int(value("oil_lure_count")):
			game._kill_enemies_near(target()["pos"], value("oil_lure_radius"))
			resolve("completed", "horde_ignited")
		return true
	active["hp"] = maxf(0.0, float(active["hp"]) - damage)
	if float(active["hp"]) <= 0.0:
		for nest in game.infestation_nests:
			if Vector2(nest["pos"]).distance_to(active["points"][0]) < 1.0: nest["destroyed"] = true
		resolve("completed", "nest_destroyed")
	return true

func pump_exploded(pos: Vector2) -> void:
	if kind() != "chain": return
	if pos.distance_to(target()["pos"]) < 1.0:
		active["step"] = int(active["step"]) + 1
		if int(active["step"]) >= active["points"].size(): resolve("completed", "chain_complete")
	else: resolve("missed", "wrong_pump_order")

func resolve(status: String, reason: String) -> void:
	if active.is_empty(): return
	var row: Dictionary = active["row"]
	row["status"] = status
	row["resolved_s"] = game.run_clock
	row["elapsed_s"] = snappedf(float(active["elapsed"]),0.001)
	row["time_to_complete_s"] = row["elapsed_s"] if status == "completed" else null
	row["reason"] = reason
	row["tutorial_spawn_rejections"] = rejected_spawns if is_tutorial() else 0
	var rewards: Array = active["rewards"].duplicate()
	var title := str(active["title"])
	var reward_text := str(active["reward"])
	var npc := _mechanic_index() if kind() == "mechanic" else -1
	game.run_log.emit("event_" + status, row)
	active.clear() # Idempotency: callbacks/rewards cannot resolve this event twice.
	if npc >= 0 and status != "completed":
		game.transient_pool.remove(game.enemies,npc,"enemies")
		game.grid_dirty = true
	if status == "completed":
		for reward in rewards: _grant(str(reward))
		game.banner.text = title + " COMPLETE\n" + reward_text
	else:
		toast_text = "MISSED" if status == "missed" else ""
		toast_left = value("missed_toast_seconds") if status == "missed" else 0.0
	if game.guidance != null:
		game.guidance.refresh_target()
		game.guidance.route.clear()
	game.run_log.checkpoint()
	queue_redraw()

func interrupt(reason: String) -> void:
	if aiming:
		Engine.time_scale = old_time_scale
		aiming = false
	if not active.is_empty(): resolve("interrupted", reason)

func _grant(reward: String) -> void:
	earned[reward] = true
	game.run_log.emit("reward_earned", {"reward":reward})
	match reward:
		"chest", "big_chest": game._collect_phase_c_powerup("Chest")
		"nuke": game.transient_pool.push(game.powerups,"powerups",{"pos":game.player_pos+Vector2(65,0),"kind":"Nuke","age":0.0},30)
		"xp_shower":
			for i in range(int(value("xp_shower_gems"))):
				game.progression.drop_xp(game.player_pos + Vector2.from_angle(float(i) * TAU / value("xp_shower_gems")) * 120.0,"runner")

func _tick_rewards(dt: float) -> void:
	if earned.has("auto_turret"):
		turret_clock -= dt
		if turret_clock <= 0.0:
			turret_clock = value("turret_interval")
			var best := -1
			var distance := value("turret_range")
			for i in game.enemy_indices_near(game.GENERATOR_POS,value("turret_range")):
				var d: float = Vector2(game.enemies[i]["pos"]).distance_to(game.GENERATOR_POS)
				if d < distance:
					distance = d
					best = i
			if best >= 0:
				shot_to = game.enemies[best]["pos"]
				shot_left = 0.08
				game.phase_b_damage_enemy(best,value("turret_damage"),false,"auto_turret")
	if earned.has("flamethrower"):
		flame_clock -= dt
		if flame_clock <= 0.0:
			flame_clock = value("flame_interval")
			var point := _walk(Vector2(16.0,35.0)*game.TILE)
			var indices: Array = game.enemy_indices_near(point,value("flame_radius"))
			indices.sort()
			indices.reverse()
			for i in indices:
				if Vector2(game.enemies[i]["pos"]).distance_to(point) < value("flame_radius"):
					game.phase_b_damage_enemy(i,value("flame_damage"),false,"flamethrower")

func arm_airstrike() -> void:
	if game.wave != 10 or not earned.has("airstrike") or aiming or get_tree().paused: return
	old_time_scale = Engine.time_scale
	Engine.time_scale = value("airstrike_aim_scale")
	aiming = true
	game.touch_active = false

func _unhandled_input(event: InputEvent) -> void:
	if not aiming: return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var at: Vector2 = get_global_mouse_position()
		if event is InputEventScreenTouch:
			at = get_canvas_transform().affine_inverse() * event.position
		game._kill_enemies_near(at,value("airstrike_radius"))
		earned.erase("airstrike")
		aiming = false
		Engine.time_scale = old_time_scale
		game.run_log.emit("reward_used",{"reward":"airstrike","x":at.x,"y":at.y})
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if game == null: return
	if earned.has("auto_turret"):
		_draw_prop(OBJ_GENERATOR, game.GENERATOR_POS)
		GUIDE.draw_icon(self,game.GENERATOR_POS,"relay",20.0,AMBER)
		if shot_left > 0.0: draw_line(game.GENERATOR_POS,shot_to,AMBER,3.0)
	if earned.has("floodlights"):
		_draw_prop(OBJ_FLOODLIGHT, _walk(game.GENERATOR_POS + Vector2(180, -80)))
	if earned.has("flamethrower"):
		var flame_point := _walk(Vector2(16,35)*game.TILE)
		_draw_prop(OBJ_FLAME_TRAP, flame_point)
		draw_arc(flame_point,value("flame_radius"),0,TAU,24,Color(AMBER,0.3),5.0)
	if active.is_empty(): return
	var point: Vector2 = target()["pos"]
	match kind():
		"generator":
			_draw_prop(OBJ_GENERATOR, point)
		"supplies":
			for cache in game.supply_caches:
				if not cache["collected"]:
					_draw_prop(OBJ_SUPPLY_CRATE, cache["pos"])
					GUIDE.draw_icon(self,cache["pos"],"crate",25.0,AMBER)
		"nest":
			_draw_prop(OBJ_ZOMBIE_NEST, point)
		"relay":
			for relay_point in active["points"]:
				_draw_prop(OBJ_RELAY_PAD, relay_point)
		"fuel":
			if bool(active["carrying"]):
				_draw_prop(OBJ_GAS_CAN, game.player_pos + Vector2(0,-48))
				_draw_prop(OBJ_FUEL_CACHE, active["points"][1])
			else:
				_draw_prop(OBJ_GAS_CAN, active["points"][0])
				_draw_prop(OBJ_FUEL_CACHE, active["points"][1])
		"lockdown":
			for switch_point in active["points"]:
				_draw_prop(OBJ_SWITCH_BOX, switch_point)
		_:
			pass
	if kind() != "supplies":
		GUIDE.draw_icon(self,point,str(target()["kind"]),25.0,AMBER)
	if kind() in ["generator","relay"]:
		draw_arc(point,value("interact_radius"),0,TAU,32,Color(AMBER,0.25),4.0)
		var duration := value("generator_charge_seconds") if kind() == "generator" else value("relay_charge_seconds")
		draw_arc(point,value("interact_radius"),-PI/2,-PI/2+TAU*clampf(float(active["charge"])/duration,0,1),32,AMBER,7.0)
	if kind() in ["nest","chain","oil","mechanic"]:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(point+direction*35.0,point+direction*55.0,AMBER,4.0)
