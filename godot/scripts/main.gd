extends Node2D
## V3 acceptance vertical slice: scrolling world, camera-follow, enemies, combat and touch steering.
## Deterministic gameplay loop, without external art dependencies. Original detailed sprite assets follow V3A approval.

const CHUNK := 512.0
const SURVIVOR_ART := preload("res://art/survivor_wasteland.svg")
const ZOMBIE_ART := preload("res://art/zombie_shambler.svg")
const CAR_ART := preload("res://art/wrecked_car.svg")
const PLAYER_SPEED := 245.0
const FIRE_PERIOD := 0.28
const BULLET_SPEED := 570.0
const ZOMBIE_SPEED := 73.0
const PLAYER_RADIUS := 17.0
const ENEMY_RADIUS := 17.0
const BULLET_RADIUS := 4.0

var player_pos := Vector2.ZERO
var player_hp := 100
var score := 0
var kills := 0
var wave := 1
var elapsed := 0.0
var fire_clock := 0.0
var spawn_clock := 0.0
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var touch_active := false
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var camera: Camera2D
var hud: Label
var instructions: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 20261008
	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(16, 20)
	hud.add_theme_font_size_override("font_size", 24)
	ui.add_child(hud)
	instructions = Label.new()
	instructions.position = Vector2(16, 914)
	instructions.text = "Drag to run  |  Auto-fire  |  V3 prototype"
	instructions.add_theme_font_size_override("font_size", 16)
	ui.add_child(instructions)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_origin = event.position
			touch_position = event.position
			touch_active = true
		else:
			touch_active = false
	elif event is InputEventScreenDrag:
		touch_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_origin = event.position
			touch_position = event.position
			touch_active = true
		else:
			touch_active = false
	elif event is InputEventMouseMotion and touch_active:
		touch_position = event.position

func _physics_process(delta: float) -> void:
	if player_hp <= 0:
		return
	elapsed += delta
	wave = 1 + int(elapsed / 30.0)
	var direction := Vector2.ZERO
	if touch_active:
		direction = (touch_position - touch_origin).limit_length(80.0) / 80.0
	direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player_pos += direction.limit_length(1.0) * PLAYER_SPEED * delta
	camera.position = player_pos
	spawn_clock -= delta
	if spawn_clock <= 0.0:
		spawn_clock = maxf(0.22, 1.0 - wave * 0.08)
		_spawn_enemy()
	fire_clock -= delta
	if fire_clock <= 0.0 and not enemies.is_empty():
		var nearest := 0
		for i in range(1, enemies.size()):
			if player_pos.distance_squared_to(enemies[i]["pos"]) < player_pos.distance_squared_to(enemies[nearest]["pos"]):
				nearest = i
		var heading: Vector2 = (enemies[nearest]["pos"] - player_pos).normalized()
		bullets.append({"pos": player_pos, "dir": heading, "life": 1.3})
		fire_clock = FIRE_PERIOD
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] += b["dir"] * BULLET_SPEED * delta
		b["life"] -= delta
		if b["life"] <= 0:
			bullets.remove_at(i)
			continue
		var hit := false
		for j in range(enemies.size() - 1, -1, -1):
			if b["pos"].distance_squared_to(enemies[j]["pos"]) < pow(ENEMY_RADIUS + BULLET_RADIUS, 2):
				enemies.remove_at(j)
				kills += 1
				score += 100
				hit = true
				break
		if hit:
			bullets.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		var to_player: Vector2 = player_pos - e["pos"]
		e["pos"] += to_player.normalized() * ZOMBIE_SPEED * delta
		if to_player.length() < PLAYER_RADIUS + ENEMY_RADIUS:
			player_hp = maxi(0, player_hp - 1)
			enemies.remove_at(i)
	_update_hud()
	queue_redraw()

func _spawn_enemy() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(480.0, 650.0)
	enemies.append({"pos": player_pos + Vector2.RIGHT.rotated(angle) * distance})

func _update_hud() -> void:
	hud.text = "DEADSHIFT V3    Wave %d    HP %d    Score %d" % [wave, player_hp, score]

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var bounds := Rect2(player_pos - viewport_size * 0.75, viewport_size * 1.5)
	var start_x := int(floor(bounds.position.x / CHUNK)) - 1
	var end_x := int(ceil(bounds.end.x / CHUNK)) + 1
	var start_y := int(floor(bounds.position.y / CHUNK)) - 1
	var end_y := int(ceil(bounds.end.y / CHUNK)) + 1
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			_draw_chunk(Vector2i(x, y))
	for e in enemies:
		var p: Vector2 = e["pos"]
		draw_texture_rect(ZOMBIE_ART, Rect2(p - Vector2(25, 25), Vector2(50, 50)), false)
	for b in bullets:
		draw_circle(b["pos"], BULLET_RADIUS, Color("#ffd47d"))
	draw_circle(player_pos + Vector2(5, 12), 32, Color(0.02, 0.02, 0.02, 0.6))
	draw_texture_rect(SURVIVOR_ART, Rect2(player_pos - Vector2(44, 44), Vector2(88, 88)), false)

func _draw_chunk(chunk: Vector2i) -> void:
	var base := Vector2(chunk) * CHUNK
	var tile := Rect2(base, Vector2.ONE * CHUNK)
	var tone := 0.11 if posmod(chunk.x + chunk.y, 2) == 0 else 0.13
	draw_rect(tile, Color(tone, tone + 0.01, tone + 0.01))
	draw_rect(Rect2(base + Vector2(155, 0), Vector2(210, CHUNK)), Color("#2a2c2b"))
	for i in range(4):
		draw_rect(Rect2(base + Vector2(256, i * 135 + 25), Vector2(8, 55)), Color("#766d4c"))
	var seed_value := absi(chunk.x * 73856093 ^ chunk.y * 19349663)
	if posmod(chunk.x * 7 + chunk.y * 11, 4) == 0:
		draw_texture_rect(CAR_ART, Rect2(base + Vector2(25, 220), Vector2(145, 91)), false)
	for i in range(8):
		var xx := float(posmod(seed_value + i * 173, 450)) + 24.0
		var yy := float(posmod(seed_value / (i + 1) + i * 97, 440)) + 30.0
		var p := base + Vector2(xx, yy)
		if xx < 140 or xx > 380:
			draw_rect(Rect2(p, Vector2(24 + i % 3 * 8, 14)), Color("#594a40"))
			draw_line(p, p + Vector2(19, 12), Color("#7c5941"), 2.0)
