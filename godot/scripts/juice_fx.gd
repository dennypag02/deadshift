extends Node2D
const J = preload("res://scripts/juice_config.gd")
var game: Node2D
var effects: Array[Dictionary] = []
var decals: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var shake_clock := 0.0
var shake_strength := 0.0
var zoom_clock := 0.0
var dust_clock := 0.0
var last_wave := 0
var last_hp := 100
var base_zoom := Vector2.ONE
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if game != null:
		base_zoom = game.camera.zoom
		last_wave = game.wave
		last_hp = game.player_hp
	z_index = 5

func emit(kind: String, position: Vector2, direction: Vector2, duration: float) -> void:
	if effects.size() >= 120:
		effects.pop_front()
	effects.append({"kind":kind,"pos":position,"dir":direction,"life":duration,"total":duration})

func shot(position: Vector2, direction: Vector2) -> void:
	emit("muzzle",position+direction*34.0,direction,J.MUZZLE_LIFE)
	if effects.size() < 100:
		emit("casing",position+direction*20.0,direction.orthogonal(),J.CASING_LIFE)

func hit(position: Vector2, direction: Vector2) -> void:
	emit("hit",position,direction,J.HIT_FLASH_LIFE)
	for i in range(J.BLOOD_DROPLETS):
		emit("blood",position,direction.rotated(rng.randf_range(-PI,PI)),J.BLOOD_LIFE)

func kill(position: Vector2, value: int) -> void:
	emit("death",position,Vector2.ZERO,J.DEATH_LIFE)
	decals.append({"pos":position,"life":J.BLOOD_DECAL_LIFE,"scorch":false})
	if decals.size() > J.BLOOD_DECAL_CAP:
		decals.pop_front()
	for popup in popups:
		if popup["pos"].distance_to(position) < 85.0 and popup["age"] < J.SCORE_POPUP_MERGE_WINDOW:
			popup["value"] += value
			popup["age"] = 0.0
			return
	popups.append({"pos":position,"value":value,"age":0.0})
	if popups.size() > J.SCORE_POPUP_CAP:
		popups.pop_front()

func explosion(position: Vector2, count: int) -> void:
	emit("blast",position,Vector2.ZERO,0.55)
	for i in range(14):
		emit("debris",position,Vector2.RIGHT.rotated(TAU*float(i)/14.0),0.5)
	decals.append({"pos":position,"life":1200.0,"scorch":true})
	if decals.size() > J.BLOOD_DECAL_CAP:
		decals.pop_front()
	shake_clock = J.EXPLOSION_SHAKE_LIFE
	shake_strength = J.EXPLOSION_SHAKE_PX
	if count >= J.HITSTOP_MIN_KILLS:
		emit("hitstop",position,Vector2.ZERO,J.HITSTOP_LIFE)

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
			effects.remove_at(i)
	for i in range(decals.size()-1,-1,-1):
		decals[i]["life"] -= delta
		if decals[i]["life"] <= 0.0:
			decals.remove_at(i)
	for i in range(popups.size()-1,-1,-1):
		popups[i]["age"] += delta
		if popups[i]["age"] >= J.SCORE_POPUP_LIFE:
			popups.remove_at(i)
	if game.player_hp < last_hp:
		hurt()
	last_hp = game.player_hp
	if game.wave != last_wave:
		last_wave = game.wave
		zoom_clock = J.WAVE_ZOOM_LIFE
	zoom_clock = maxf(0.0,zoom_clock-delta)
	game.camera.zoom = base_zoom*(1.0+J.WAVE_ZOOM_PCT*zoom_clock/J.WAVE_ZOOM_LIFE)
	shake_clock = maxf(0.0,shake_clock-delta)
	var velocity: Vector2 = game.player_velocity
	var lookahead := velocity.normalized()*J.CAMERA_LOOKAHEAD_PX
	game.camera.offset = game.camera.offset.lerp(lookahead,minf(1.0,delta*J.CAMERA_SMOOTHING))
	if shake_clock > 0.0 and game.get("shake_enabled") == true:
		game.camera.offset += Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*shake_strength*shake_clock/J.EXPLOSION_SHAKE_LIFE
	dust_clock -= delta
	if velocity.length() > 40.0 and dust_clock <= 0.0:
		dust_clock = J.FOOTSTEP_LIFE
		emit("dust",game.player_pos+Vector2(0,35),-velocity.normalized(),0.4)
	queue_redraw()
