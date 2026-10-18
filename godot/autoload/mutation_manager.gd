extends Node

signal offer_ready(offers: Array)
signal offer_closed
signal slots_changed

const SLOTS := ["arms", "legs", "torso", "back", "head"]
const TAGS := ["acid", "fire", "shock", "bone", "swarm"]
const EFFECT_TYPES := ["projectile", "melee_arc", "aura", "trail", "on_hit", "summon", "dash", "passive_stat"]
const MAX_LEVEL := 3

var definitions: Dictionary = {}
var game: Node = null
var rng := RandomNumberGenerator.new()
var active := false
var offer_open := false
var current_offers: Array[String] = []
var clocks: Dictionary = {}
var hit_counters: Dictionary = {}
var move_charge: Dictionary = {}
var zones: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var crawlers: Array[Node] = []
var last_player_pos := Vector2.ZERO
var last_player_hp := 100
var damage_reaction_cooldowns: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if OS.get_environment("DEADSHIFT_VALIDATION_SEED") != "":
		rng.seed = int(OS.get_environment("DEADSHIFT_VALIDATION_SEED")) + 303
	else:
		rng.randomize()
	_load_definitions()
	EventBus.hit_landed.connect(_on_hit_landed)

func bind_game(value: Node) -> void:
	game = value
	active = game != null
	if game != null:
		last_player_pos = Vector2(game.player_pos)
		last_player_hp = int(game.player_hp)
		var overlay := preload("res://scripts/mutation_effect_overlay.gd").new()
		overlay.manager = self
		game.add_child(overlay)

func reset_run() -> void:
	RunState.held_mutations.clear()
	for tag in TAGS:
		RunState.tag_counts[tag] = 0
	clocks.clear()
	hit_counters.clear()
	move_charge.clear()
	damage_reaction_cooldowns.clear()
	zones.clear()
	flashes.clear()
	for crawler in crawlers:
		if is_instance_valid(crawler):
			crawler.queue_free()
	crawlers.clear()
	current_offers.clear()
	offer_open = false
	_recalculate_tags()
	slots_changed.emit()

func _load_definitions() -> void:
	definitions.clear()
	for path in DataRegistry.records:
		if not str(path).begins_with("res://data/mutations/") or not str(path).ends_with(".json"):
			continue
		var data: Variant = DataRegistry.records[path]
		if not _valid_definition(data, str(path)):
			continue
		var row: Dictionary = data
		definitions[str(row["id"])] = row.duplicate(true)
	if definitions.size() != 15:
		push_error("MUTATION_DATA_ERROR expected=15 loaded=%d" % definitions.size())
	else:
		print("MUTATION_DATA_READY count=15")

func _valid_definition(data: Variant, path: String) -> bool:
	if not (data is Dictionary):
		push_error("MUTATION_DATA_ERROR path=%s reason=root_not_object" % path)
		return false
	var row: Dictionary = data
	for key in ["id","name","slot","tags","effect_type","levels","visual","description"]:
		if not row.has(key):
			push_error("MUTATION_DATA_ERROR path=%s reason=missing_field field=%s" % [path,key])
			return false
	if str(row["slot"]) not in SLOTS:
		push_error("MUTATION_DATA_ERROR path=%s reason=invalid_slot" % path)
		return false
	if str(row["effect_type"]) not in EFFECT_TYPES:
		push_error("MUTATION_DATA_ERROR path=%s reason=invalid_effect_type" % path)
		return false
	var tags: Array = row["tags"]
	if tags.is_empty() or tags.size() > 2:
		push_error("MUTATION_DATA_ERROR path=%s reason=invalid_tag_count" % path)
		return false
	for tag in tags:
		if str(tag) not in TAGS:
			push_error("MUTATION_DATA_ERROR path=%s reason=invalid_tag tag=%s" % [path,str(tag)])
			return false
	var levels: Array = row["levels"]
	if levels.size() != MAX_LEVEL:
		push_error("MUTATION_DATA_ERROR path=%s reason=levels_must_equal_3" % path)
		return false
	return true

func begin_between_wave_offer(wave_number: int) -> void:
	if offer_open:
		return
	RunState.wave_number = wave_number
	current_offers = _generate_offers()
	offer_open = true
	EventBus.wave_ended.emit({"wave":wave_number,"mutation_offer":current_offers.duplicate()})
	offer_ready.emit(current_offers.duplicate())

func _generate_offers() -> Array[String]:
	var eligible: Array[String] = []
	for id in definitions:
		var row: Dictionary = definitions[id]
		var slot := str(row["slot"])
		var held: Dictionary = RunState.held_mutations.get(slot,{})
		if not held.is_empty() and str(held.get("id","")) == str(id) and int(held.get("level",0)) >= MAX_LEVEL:
			continue
		eligible.append(str(id))
	eligible.shuffle()
	var out: Array[String] = []
	for i in range(mini(3,eligible.size())):
		out.append(eligible[i])
	return out

func complete_offer() -> void:
	if not offer_open:
		return
	offer_open = false
	current_offers.clear()
	offer_closed.emit()
	if game != null:
		game.break_clock = 1.0
		game.banner.text = "MUTATION LOCKED - NEXT WAVE"
		get_tree().paused = false

func skip_offer() -> void:
	complete_offer()

func take_mutation(id: String) -> Dictionary:
	if not definitions.has(id):
		return {"ok":false,"reason":"unknown_mutation"}
	var row: Dictionary = definitions[id]
	var slot := str(row["slot"])
	var held: Dictionary = RunState.held_mutations.get(slot,{})
	var replaced := ""
	var new_level := 1
	if not held.is_empty() and str(held.get("id","")) == id:
		var old_level := int(held.get("level",1))
		if old_level >= MAX_LEVEL:
			return {"ok":false,"reason":"max_level"}
		new_level = old_level + 1
	elif not held.is_empty():
		replaced = str(held.get("id",""))
	RunState.held_mutations[slot] = {"id":id,"level":new_level}
	clocks[id] = 0.0
	hit_counters[id] = 0
	move_charge[id] = 0.0
	_recalculate_tags()
	EventBus.mutation_taken.emit({"id":id,"slot":slot,"level":new_level,"replaced":replaced,"tags":row["tags"]})
	slots_changed.emit()
	if game != null and game.telemetry != null:
		game.telemetry.event("mutation_taken",{"id":id,"slot":slot,"level":new_level,"replaced":replaced,"tags":row["tags"]})
	return {"ok":true,"id":id,"slot":slot,"level":new_level,"replaced":replaced}

func mutation_name(id: String) -> String:
	return str(definitions.get(id,{}).get("name",id))

func held_level(id: String) -> int:
	for slot in RunState.held_mutations:
		var held: Dictionary = RunState.held_mutations[slot]
		if str(held.get("id","")) == id:
			return int(held.get("level",0))
	return 0

func replacement_for(id: String) -> String:
	if not definitions.has(id):
		return ""
	var slot := str(definitions[id]["slot"])
	var held: Dictionary = RunState.held_mutations.get(slot,{})
	if held.is_empty() or str(held.get("id","")) == id:
		return ""
	return str(held.get("id",""))

func _recalculate_tags() -> void:
	for tag in TAGS:
		RunState.tag_counts[tag] = 0
	for slot in RunState.held_mutations:
		var held: Dictionary = RunState.held_mutations[slot]
		var row: Dictionary = definitions.get(str(held.get("id","")), {})
		for tag in row.get("tags",[]):
			RunState.tag_counts[str(tag)] = int(RunState.tag_counts.get(str(tag),0)) + 1

func _level_params(id: String) -> Dictionary:
	var level := held_level(id)
	if level <= 0 or not definitions.has(id):
		return {}
	var rows: Array = definitions[id]["levels"]
	return (rows[level-1] as Dictionary).duplicate(true)

func _held_ids() -> Array[String]:
	var out: Array[String] = []
	for slot in SLOTS:
		var held: Dictionary = RunState.held_mutations.get(slot,{})
		if not held.is_empty():
			out.append(str(held["id"]))
	return out

func _process(delta: float) -> void:
	if not active or game == null or int(game.player_hp) <= 0 or offer_open:
		return
	var current_pos := Vector2(game.player_pos)
	var moved := current_pos.distance_to(last_player_pos)
	var hp_now := int(game.player_hp)
	var took_damage := hp_now < last_player_hp
	for id in _held_ids():
		var row: Dictionary = definitions[id]
		var params := _level_params(id)
		match str(row["effect_type"]):
			"projectile": _tick_projectile(id,row,params,delta)
			"melee_arc": _tick_melee(id,row,params,delta)
			"aura": _tick_aura(id,row,params,delta)
			"trail": _tick_trail(id,row,params,delta,moved)
			"on_hit":
				if str(params.get("trigger","")) == "player_damaged" and took_damage:
					_trigger_player_damage_effect(id,row,params)
			"summon": _tick_summon(id,row,params,delta)
			"dash": _tick_dash(id,row,params,delta,moved)
			"passive_stat": _tick_passive(id,row,params,moved)
	_tick_zones(delta)
	_tick_flashes(delta)
	last_player_pos = Vector2(game.player_pos)
	last_player_hp = int(game.player_hp)

func _clock_ready(id: String, delta: float, cooldown: float) -> bool:
	clocks[id] = float(clocks.get(id,0.0)) - delta
	if float(clocks[id]) > 0.0:
		return false
	clocks[id] = maxf(0.05,cooldown)
	return true

func _tick_projectile(id: String,row: Dictionary,p: Dictionary,delta: float) -> void:
	if not _clock_ready(id,delta,float(p.get("cooldown",1.0))):
		return
	var targets := _nearest_targets(Vector2(game.player_pos),float(p.get("range",600.0)),int(p.get("count",1)))
	for index in targets:
		if index >= game.enemies.size():
			continue
		var at := Vector2(game.enemies[index]["pos"])
		_damage_enemy(index,float(p.get("damage",1.0)),id,row["tags"])
		flashes.append({"kind":"line","a":Vector2(game.player_pos),"b":at,"life":0.12,"tags":row["tags"]})
		if float(p.get("pool_radius",0.0)) > 0.0:
			_add_zone(at,float(p["pool_radius"]),float(p.get("pool_duration",2.5)),float(p.get("damage",1.0))*0.25,id,row["tags"])

func _tick_melee(id: String,row: Dictionary,p: Dictionary,delta: float) -> void:
	if not _clock_ready(id,delta,float(p.get("cooldown",1.0))):
		return
	var radius := float(p.get("radius",150.0))
	var half_angle := deg_to_rad(float(p.get("arc_degrees",120.0))*0.5)
	var facing := Vector2(game.facing)
	var indices: Array[int] = game.enemy_indices_near(Vector2(game.player_pos),radius)
	indices.sort()
	indices.reverse()
	for index in indices:
		if index >= game.enemies.size():
			continue
		var to_enemy := (Vector2(game.enemies[index]["pos"]) - Vector2(game.player_pos)).normalized()
		if absf(facing.angle_to(to_enemy)) <= half_angle:
			_damage_enemy(index,float(p.get("damage",1.0)),id,row["tags"])
	flashes.append({"kind":"ring","a":Vector2(game.player_pos),"radius":radius,"life":0.12,"tags":row["tags"]})

func _tick_aura(id: String,row: Dictionary,p: Dictionary,delta: float) -> void:
	if not _clock_ready(id,delta,float(p.get("cooldown",1.0))):
		return
	var radius := float(p.get("radius",130.0))
	var indices: Array[int] = game.enemy_indices_near(Vector2(game.player_pos),radius)
	indices.sort()
	indices.reverse()
	var cone := float(p.get("cone_degrees",360.0))
	var facing := Vector2(game.facing)
	for index in indices:
		if index >= game.enemies.size():
			continue
		if cone < 359.0:
			var dir := (Vector2(game.enemies[index]["pos"]) - Vector2(game.player_pos)).normalized()
			if absf(facing.angle_to(dir)) > deg_to_rad(cone*0.5):
				continue
		_damage_enemy(index,float(p.get("damage",1.0)),id,row["tags"])
	flashes.append({"kind":"ring","a":Vector2(game.player_pos),"radius":radius,"life":0.15,"tags":row["tags"]})

func _tick_trail(id: String,row: Dictionary,p: Dictionary,delta: float,moved: float) -> void:
	if moved < 2.0 or not _clock_ready(id,delta,float(p.get("interval",0.4))):
		return
	_add_zone(Vector2(game.player_pos),float(p.get("radius",60.0)),float(p.get("duration",2.0)),float(p.get("damage",2.0)),id,row["tags"])

func _tick_summon(id: String,row: Dictionary,p: Dictionary,delta: float) -> void:
	if not _clock_ready(id,delta,float(p.get("cooldown",6.0))):
		return
	_cleanup_crawlers()
	var cap := int(p.get("max_crawlers",3)) + _hive_bonus("max_crawlers_bonus")
	for _i in range(int(p.get("count",1))):
		if crawlers.size() >= cap:
			break
		var crawler := preload("res://scripts/crawler.gd").new()
		crawler.game = game
		crawler.damage = float(p.get("crawler_damage",2.0))
		crawler.speed = float(p.get("crawler_speed",150.0)) * _hive_multiplier()
		crawler.life = float(p.get("crawler_lifetime",12.0))
		crawler.tags = (row["tags"] as Array).duplicate()
		crawler.position = Vector2(game.player_pos) + Vector2.from_angle(rng.randf_range(0.0,TAU))*30.0
		game.add_child(crawler)
		crawlers.append(crawler)

func _tick_dash(id: String,row: Dictionary,p: Dictionary,delta: float,moved: float) -> void:
	if moved < 1.0 or not _clock_ready(id,delta,float(p.get("cooldown",4.0))):
		return
	var target := Vector2(game.player_pos) + Vector2(game.facing).normalized()*float(p.get("dash_distance",160.0))
	game.player_pos = game._nearest_walkable_position(target,float(game.PLAYER_RADIUS))
	var radius := float(p.get("landing_radius",120.0))
	_damage_area(Vector2(game.player_pos),radius,float(p.get("damage",4.0)),id,row["tags"])
	flashes.append({"kind":"ring","a":Vector2(game.player_pos),"radius":radius,"life":0.18,"tags":row["tags"]})

func _tick_passive(id: String,row: Dictionary,p: Dictionary,moved: float) -> void:
	if not p.has("charge_distance"):
		return
	move_charge[id] = float(move_charge.get(id,0.0)) + moved
	if float(move_charge[id]) < float(p["charge_distance"]):
		return
	move_charge[id] = 0.0
	var radius := float(p.get("pulse_radius",180.0))
	_damage_area(Vector2(game.player_pos),radius,float(p.get("pulse_damage",4.0)),id,row["tags"])
	flashes.append({"kind":"ring","a":Vector2(game.player_pos),"radius":radius,"life":0.18,"tags":row["tags"]})

func _trigger_player_damage_effect(id: String,row: Dictionary,p: Dictionary) -> void:
	# Game time, not wall-clock: the cooldown must not run down while paused, and
	# fixed-FPS captures must replay identically.
	var now := float(game.run_clock)
	if now < float(damage_reaction_cooldowns.get(id,0.0)):
		return
	damage_reaction_cooldowns[id] = now + float(p.get("cooldown",2.5))
	var radius := float(p.get("radius",160.0))
	_damage_area(Vector2(game.player_pos),radius,float(p.get("damage",4.0)),id,row["tags"])
	flashes.append({"kind":"ring","a":Vector2(game.player_pos),"radius":radius,"life":0.18,"tags":row["tags"]})

func _on_hit_landed(payload: Dictionary) -> void:
	if not active or game == null or str(payload.get("source","")).begins_with("mutation:"):
		return
	for id in _held_ids():
		var row: Dictionary = definitions[id]
		if str(row["effect_type"]) != "on_hit":
			continue
		var p := _level_params(id)
		if str(p.get("trigger","")) == "player_damaged":
			continue
		hit_counters[id] = int(hit_counters.get(id,0)) + 1
		if int(hit_counters[id]) < int(p.get("trigger_every",4)):
			continue
		hit_counters[id] = 0
		var origin := Vector2(payload.get("position",game.player_pos))
		for index in _nearest_targets(origin,float(p.get("chain_range",230.0)),int(p.get("chains",3))):
			if index < game.enemies.size():
				var at := Vector2(game.enemies[index]["pos"])
				_damage_enemy(index,float(p.get("damage",4.0)),id,row["tags"])
				flashes.append({"kind":"line","a":origin,"b":at,"life":0.12,"tags":row["tags"]})

func _add_zone(at: Vector2,radius: float,duration: float,damage: float,id: String,tags: Array) -> void:
	zones.append({"pos":at,"radius":radius,"life":duration,"tick":0.0,"damage":damage,"id":id,"tags":tags.duplicate()})

func _tick_zones(delta: float) -> void:
	for i in range(zones.size()-1,-1,-1):
		var zone: Dictionary = zones[i]
		zone["life"] = float(zone["life"]) - delta
		zone["tick"] = float(zone["tick"]) - delta
		if float(zone["life"]) <= 0.0:
			zones.remove_at(i)
			continue
		if float(zone["tick"]) <= 0.0:
			zone["tick"] = 0.5
			_damage_area(Vector2(zone["pos"]),float(zone["radius"]),float(zone["damage"]),str(zone["id"]),zone["tags"])

func _tick_flashes(delta: float) -> void:
	for i in range(flashes.size()-1,-1,-1):
		flashes[i]["life"] = float(flashes[i]["life"]) - delta
		if float(flashes[i]["life"]) <= 0.0:
			flashes.remove_at(i)

func _damage_area(center: Vector2,radius: float,damage: float,id: String,tags: Array) -> void:
	var indices: Array[int] = game.enemy_indices_near(center,radius)
	indices.sort()
	indices.reverse()
	for index in indices:
		if index < game.enemies.size():
			_damage_enemy(index,damage,id,tags)

func _damage_enemy(index: int,damage: float,id: String,tags: Array) -> void:
	if index < 0 or index >= game.enemies.size():
		return
	var pos := Vector2(game.enemies[index]["pos"])
	game.phase_b_damage_enemy(index,damage,false,"mutation:"+id)
	EventBus.hit_landed.emit({"source":"mutation:"+id,"mutation_id":id,"tags":tags.duplicate(),"position":pos,"damage":damage})

func _nearest_targets(center: Vector2,max_range: float,count: int) -> Array[int]:
	var scored: Array = []
	for i in range(game.enemies.size()):
		var d := center.distance_squared_to(Vector2(game.enemies[i]["pos"]))
		if d <= max_range*max_range:
			scored.append({"index":i,"d":d})
	scored.sort_custom(func(a,b): return float(a["d"]) < float(b["d"]))
	var out: Array[int] = []
	for i in range(mini(count,scored.size())):
		out.append(int(scored[i]["index"]))
	out.sort()
	out.reverse()
	return out

func _hive_bonus(key: String) -> int:
	if held_level("hive_mind") <= 0:
		return 0
	return int(_level_params("hive_mind").get(key,0))

func _hive_multiplier() -> float:
	if held_level("hive_mind") <= 0:
		return 1.0
	return float(_level_params("hive_mind").get("crawler_speed_multiplier",1.0))

func _cleanup_crawlers() -> void:
	for i in range(crawlers.size()-1,-1,-1):
		if not is_instance_valid(crawlers[i]) or crawlers[i].is_queued_for_deletion():
			crawlers.remove_at(i)
