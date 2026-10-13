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
