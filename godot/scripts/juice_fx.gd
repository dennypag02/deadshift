extends Node2D
const J = preload("res://scripts/juice_config.gd")
var game: Node2D
var record_pool=preload("res://scripts/record_pool.gd").new()
var effects: Array[Dictionary] = []
var decals: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var damage_numbers: Array[Dictionary] = []
var shake_clock := 0.0
var shake_strength := 0.0
var zoom_clock := 0.0
var dust_clock := 0.0
var terrain_clock := 0.0
var last_wave := 0
var last_hp := 100
var last_wave_active := false
var clear_slow_clock := 0.0
var hitstop_clock := 0.0
var base_zoom := Vector2.ONE
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	for kind in {"effects":96,"decals":40,"popups":20,"damage_numbers":40}: record_pool.warm(kind,{"effects":96,"decals":40,"popups":20,"damage_numbers":40}[kind])
	if OS.get_environment("DEADSHIFT_VALIDATION_SEED") != "": rng.seed=int(OS.get_environment("DEADSHIFT_VALIDATION_SEED"))+202
	else: rng.randomize()
	if game != null:
		base_zoom = game.camera.zoom
		last_wave = game.wave
		last_hp = game.player_hp
		last_wave_active = game.wave_active
	z_index = 5

func emit(kind: String, position: Vector2, direction: Vector2, duration: float) -> void:
	if effects.size() >= 96:
		record_pool.remove(effects,0,"effects")
	record_pool.push(effects,"effects",{"kind":kind,"pos":position,"dir":direction,"life":duration,"total":duration},96)

func shot(position: Vector2, direction: Vector2) -> void:
	emit("muzzle",position+direction*34.0,direction,J.MUZZLE_LIFE)
	if effects.size() < 80:
		emit("casing",position+direction*20.0,direction.orthogonal(),J.CASING_LIFE)

func hit(position: Vector2, direction: Vector2) -> void:
	emit("hit",position,direction,J.HIT_FLASH_LIFE)
	for i in range(J.BLOOD_DROPLETS):
		emit("blood",position,direction.rotated(rng.randf_range(-PI,PI)),J.BLOOD_LIFE)

func kill(position: Vector2, value: int) -> void:
	emit("death",position,Vector2.ZERO,J.DEATH_LIFE)
	var blood_cfg: Dictionary = {}
	if game != null and game.progression != null:
		blood_cfg = game.progression.config.get("blood_decals", {})
	var life := float(blood_cfg.get("lifetime_seconds", 8.0))
	var scale_min := float(blood_cfg.get("scale_min", 0.5))
	var scale_max := float(blood_cfg.get("scale_max", 1.0))
	record_pool.push(decals,"decals",{"pos":position,"life":life,"total":life,"scorch":false,"variant":rng.randi_range(0,3),"scale":rng.randf_range(scale_min,scale_max),"rotation":rng.randf_range(0.0,TAU)},40)
	if game != null and game.progression != null:
		var decal_cap := int(game.progression.config.get("limits", {}).get("blood_decals", 40))
		while decals.size() > decal_cap:
			record_pool.remove(decals,0,"decals")
	if decals.size() > J.BLOOD_DECAL_CAP:
		record_pool.remove(decals,0,"decals")
	for popup in popups:
		if popup["pos"].distance_to(position) < 85.0 and popup["age"] < J.SCORE_POPUP_MERGE_WINDOW:
			popup["value"] += value
			popup["age"] = 0.0
			return
	record_pool.push(popups,"popups",{"pos":position,"value":value,"age":0.0},20)
	if popups.size() > J.SCORE_POPUP_CAP:
		record_pool.remove(popups,0,"popups")

func damage_number(uid: int, position: Vector2, amount: float, crit: bool) -> void:
	if game == null or game.progression == null:
		return
	var cfg: Dictionary = game.progression.config.get("damage_numbers", {})
	var merge_window := float(cfg.get("merge_window_seconds", 0.15))
	for number in damage_numbers:
		if int(number["uid"]) == uid and float(number["age"]) <= merge_window:
			number["amount"] = float(number["amount"]) + amount
			number["crit"] = bool(number["crit"]) or crit
			number["age"] = 0.0
			number["pos"] = position
			return
	var cap := int(game.progression.config.get("limits", {}).get("damage_numbers", 40))
	if damage_numbers.size() >= cap:
		record_pool.remove(damage_numbers,0,"damage_numbers")
	record_pool.push(damage_numbers,"damage_numbers",{"uid": uid, "pos": position, "amount": amount, "crit": crit, "age": 0.0},40)

func explosion(position: Vector2, count: int) -> void:
	emit("blast",position,Vector2.ZERO,0.55)
	for i in range(14):
		emit("debris",position,Vector2.RIGHT.rotated(TAU*float(i)/14.0),0.5)
	record_pool.push(decals,"decals",{"pos":position,"life":1200.0,"total":1200.0,"scorch":true,"variant":0,"scale":1.0,"rotation":0.0},40)
	if decals.size() > J.BLOOD_DECAL_CAP:
		record_pool.remove(decals,0,"decals")
	shake_clock = J.EXPLOSION_SHAKE_LIFE
	shake_strength = J.EXPLOSION_SHAKE_PX
	if count >= J.HITSTOP_MIN_KILLS:
		hitstop_clock = J.HITSTOP_LIFE

func hurt() -> void:
	shake_clock = J.HURT_SHAKE_LIFE
	shake_strength = J.HURT_SHAKE_PX
	emit("hurt",game.player_pos,Vector2.ZERO,J.HURT_FLASH_LIFE)

func _process(delta: float) -> void:
	if game == null:
		return
	for i in range(effects.size()-1,-1,-1):
		effects[i]["life"] -= delta
		if effects[i]["life"] <= 0.0:
			record_pool.remove(effects,i,"effects")
	for i in range(decals.size()-1,-1,-1):
		decals[i]["life"] -= delta
		if decals[i]["life"] <= 0.0:
			record_pool.remove(decals,i,"decals")
	for i in range(popups.size()-1,-1,-1):
		popups[i]["age"] += delta
		if popups[i]["age"] >= J.SCORE_POPUP_LIFE:
			record_pool.remove(popups,i,"popups")
	if game.progression != null:
		var number_life := float(game.progression.config.get("damage_numbers", {}).get("lifetime_seconds", 0.75))
		for i in range(damage_numbers.size()-1,-1,-1):
			damage_numbers[i]["age"] = float(damage_numbers[i]["age"]) + delta
			if float(damage_numbers[i]["age"]) >= number_life:
				record_pool.remove(damage_numbers,i,"damage_numbers")
	if game.player_hp < last_hp:
		hurt()
	last_hp = game.player_hp
	if last_wave_active and not game.wave_active:
		clear_slow_clock = J.WAVE_CLEAR_SLOW_LIFE
	last_wave_active = game.wave_active
	if game.wave != last_wave:
		last_wave = game.wave
		zoom_clock = J.WAVE_ZOOM_LIFE
	zoom_clock = maxf(0.0,zoom_clock-delta)
	var real_delta := delta / maxf(0.02, Engine.time_scale)
	clear_slow_clock = maxf(0.0,clear_slow_clock-real_delta)
	hitstop_clock = maxf(0.0,hitstop_clock-real_delta)
	Engine.time_scale = 0.02 if hitstop_clock > 0.0 else (0.5 if clear_slow_clock > 0.0 else 1.0)
	game.camera.zoom = base_zoom*(1.0+J.WAVE_ZOOM_PCT*zoom_clock/J.WAVE_ZOOM_LIFE)
	shake_clock = maxf(0.0,shake_clock-delta)
	var velocity: Vector2 = game.player_velocity
	var lookahead := velocity.normalized()*J.CAMERA_LOOKAHEAD_PX
	game.camera.offset = game.camera.offset.lerp(lookahead,minf(1.0,delta*J.CAMERA_SMOOTHING))
	if shake_clock > 0.0 and game.get("shake_enabled") == true:
		game.camera.offset += Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*shake_strength*shake_clock/J.EXPLOSION_SHAKE_LIFE
	dust_clock -= delta
	terrain_clock -= delta
	if velocity.length() > 40.0 and terrain_clock <= 0.0:
		var terrain: Dictionary = game._hazard_at(game.player_pos)
		if bool(terrain.get("slippery", false)):
			emit("dust", game.player_pos + Vector2(0,35), -velocity.normalized(), 0.3)
			terrain_clock = 0.15
	if velocity.length() > 40.0 and dust_clock <= 0.0:
		dust_clock = J.FOOTSTEP_LIFE
		emit("dust",game.player_pos+Vector2(0,35),-velocity.normalized(),0.4)
	queue_redraw()

func _draw() -> void:
	for decal in decals:
		if bool(decal["scorch"]):
			draw_circle(decal["pos"], 42.0, Color(0.08, 0.05, 0.04, 0.35))
			continue
		var life_ratio := clampf(float(decal["life"]) / maxf(0.01, float(decal.get("total", 8.0))), 0.0, 1.0)
		var blood_opacity := 0.50
		if game != null and game.progression != null:
			blood_opacity = float(game.progression.config.get("blood_decals", {}).get("opacity", 0.50))
		var tint := Color(0.30, 0.018, 0.028, blood_opacity * life_ratio)
		var variant := int(decal.get("variant", 0))
		var splat_scale := float(decal.get("scale", 1.0))
		var rotation := float(decal.get("rotation", 0.0))
		draw_set_transform(Vector2(decal["pos"]), rotation, Vector2.ONE * splat_scale)
		var points := PackedVector2Array()
		match variant:
			0:
				points = PackedVector2Array([Vector2(-26,-7),Vector2(-13,-18),Vector2(-4,-12),Vector2(6,-25),Vector2(11,-10),Vector2(27,-3),Vector2(16,7),Vector2(22,20),Vector2(6,15),Vector2(-2,27),Vector2(-10,14),Vector2(-28,17),Vector2(-18,3)])
			1:
				points = PackedVector2Array([Vector2(-30,-3),Vector2(-17,-12),Vector2(-12,-24),Vector2(1,-14),Vector2(14,-23),Vector2(15,-8),Vector2(31,2),Vector2(17,10),Vector2(20,24),Vector2(5,18),Vector2(-7,28),Vector2(-10,13),Vector2(-24,11)])
			2:
				points = PackedVector2Array([Vector2(-24,-18),Vector2(-9,-14),Vector2(-2,-29),Vector2(8,-13),Vector2(24,-17),Vector2(19,-2),Vector2(31,10),Vector2(14,13),Vector2(9,28),Vector2(-3,17),Vector2(-18,25),Vector2(-16,8),Vector2(-31,2)])
			_:
				points = PackedVector2Array([Vector2(-29,-10),Vector2(-12,-9),Vector2(-5,-26),Vector2(7,-15),Vector2(21,-25),Vector2(18,-6),Vector2(30,5),Vector2(12,9),Vector2(17,26),Vector2(1,18),Vector2(-13,29),Vector2(-15,12),Vector2(-30,13)])
		draw_colored_polygon(points, tint)
		draw_circle(Vector2(26,-18), 4.0, Color(tint.r,tint.g,tint.b,tint.a*0.8))
		draw_circle(Vector2(-23,23), 3.0, Color(tint.r,tint.g,tint.b,tint.a*0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for fx in effects:
		var p: Vector2 = fx["pos"]
		var d: Vector2 = fx["dir"]
		var t: float = fx["life"]/fx["total"]
		match fx["kind"]:
			"muzzle":
				draw_colored_polygon(PackedVector2Array([p+d*26,p+d.rotated(0.7)*12,p-d*7,p+d.rotated(-0.7)*12]),Color(1,0.86,0.3,t))
			"casing":
				draw_rect(Rect2(p+d*30.0*(1.0-t),Vector2(7,3)),Color(0.92,0.7,0.25,t))
			"hit":
				draw_circle(p,19.0,Color(1,1,1,t*0.8))
			"blood":
				draw_circle(p+d*42.0*(1.0-t),3.5,Color(0.38,0.02,0.04,t))
			"death":
				draw_circle(p,20.0,Color(0.36,0.04,0.04,t*0.7))
			"blast":
				draw_arc(p,10.0+145.0*(1.0-t),0.0,TAU,48,Color(1,0.62,0.22,t),9.0)
			"debris":
				draw_circle(p+d*155.0*(1.0-t),5.0,Color(0.38,0.25,0.15,t))
			"dust":
				draw_circle(p+d*20.0*(1.0-t),11.0,Color(0.57,0.48,0.36,t*0.25))
			"hurt":
				draw_circle(p,56.0,Color(0.9,0.08,0.04,t*0.2))
	for popup in popups:
		var t := float(popup["age"])/J.SCORE_POPUP_LIFE
		draw_string(ThemeDB.fallback_font,popup["pos"]+Vector2(-20,-60.0*t),"+%d"%popup["value"],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(1.0,0.63,0.2,1.0-t))
	if game.progression != null:
		var cfg: Dictionary = game.progression.config.get("damage_numbers", {})
		var life := float(cfg.get("lifetime_seconds", 0.75))
		for number in damage_numbers:
			var t := clampf(float(number["age"]) / maxf(0.01, life), 0.0, 1.0)
			var is_crit := bool(number["crit"])
			var color := Color(str(cfg.get("crit_color", "#F2C14E"))) if is_crit else Color(str(cfg.get("normal_color", "#FFFFFF")))
			color.a = 1.0 - t
			var size := int(cfg.get("crit_size", 36)) if is_crit else int(cfg.get("normal_size", 24))
			var prefix := "!" if is_crit else ""
			var label := "%s%d" % [prefix, maxi(1, roundi(float(number["amount"])))]
			draw_string(ThemeDB.fallback_font, Vector2(number["pos"]) + Vector2(-16,-36.0-28.0*t), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
