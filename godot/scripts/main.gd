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
const HIT_FLASH_SECONDS := 0.16
const MUZZLE_FLASH_SECONDS := 0.07

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
var game_over_label: Label
var hit_flash_clock := 0.0
var muzzle_flash_clock := 0.0
var last_shot_direction := Vector2.RIGHT
var impact_marks: Array[Dictionary] = []

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
	game_over_label = Label.new()
	game_over_label.position = Vector2(34, 410)
	game_over_label.add_theme_font_size_override("font_size", 26)
	game_over_label.visible = false
	ui.add_child(game_over_label)
	_update_hud()

func _reset_game() -> void:
	player_pos = Vector2.ZERO
	player_hp = 100
	score = 0
	kills = 0
	wave = 1
	elapsed = 0.0
	fire_clock = 0.0
	spawn_clock = 0.0
	hit_flash_clock = 0.0
	muzzle_flash_clock = 0.0
	impact_marks.clear()
	touch_active = false
	enemies.clear()
	bullets.clear()
	camera.position = player_pos
	game_over_label.visible = false
	_update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if player_hp <= 0:
		if event is InputEventScreenTouch and event.pressed:
			_reset_game()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_reset_game()
		elif event is InputEventKey and event.pressed and not event.echo:
			_reset_game()
		return
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
	hit_flash_clock = maxf(0.0, hit_flash_clock - delta)
	muzzle_flash_clock = maxf(0.0, muzzle_flash_clock - delta)
	for i in range(impact_marks.size() - 1, -1, -1):
		impact_marks[i]["life"] -= delta
		if impact_marks[i]["life"] <= 0.0:
			impact_marks.remove_at(i)
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
		last_shot_direction = heading
		muzzle_flash_clock = MUZZLE_FLASH_SECONDS
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
				impact_marks.append({"pos": enemies[j]["pos"], "life": 0.22})
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
			hit_flash_clock = HIT_FLASH_SECONDS
			enemies.remove_at(i)
	if player_hp <= 0:
		game_over_label.text = "GAME OVER\nWave %d  |  Kills %d\nTap to restart" % [wave, kills]
		game_over_label.visible = true
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
	for mark in impact_marks:
		var alpha: float = clampf(mark["life"] / 0.22, 0.0, 1.0)
		draw_circle(mark["pos"], 12.0 * (1.0 - alpha) + 4.0, Color(0.9, 0.19, 0.12, alpha * 0.8))
	for b in bullets:
		draw_line(b["pos"] - b["dir"] * 15.0, b["pos"], Color("#ffcb65"), 3.0)
		draw_circle(b["pos"], BULLET_RADIUS, Color("#fff2b8"))
	if muzzle_flash_clock > 0.0:
		var muzzle := player_pos + last_shot_direction * 39.0
		draw_circle(muzzle, 9.0, Color(1.0, 0.72, 0.21, muzzle_flash_clock / MUZZLE_FLASH_SECONDS))
	draw_circle(player_pos + Vector2(5, 12), 32, Color(0.02, 0.02, 0.02, 0.6))
	draw_texture_rect(SURVIVOR_ART, Rect2(player_pos - Vector2(44, 44), Vector2(88, 88)), false)
	if hit_flash_clock > 0.0:
		draw_arc(player_pos, 37.0, 0.0, TAU, 32, Color(1.0, 0.22, 0.17, hit_flash_clock / HIT_FLASH_SECONDS), 5.0)

func _draw_chunk(chunk: Vector2i) -> void:
	# A reproducible downtown block: roads connect across chunk boundaries.
	# Facades and debris use local seeded RNG so camera movement cannot rearrange the city.
	var base := Vector2(chunk) * CHUNK
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = absi(chunk.x * 73856093 ^ chunk.y * 19349663) + 41
	draw_rect(Rect2(base, Vector2.ONE * CHUNK), Color("#3b3935"))
	# Continuous north/south road, gutters and sidewalks.
	draw_rect(Rect2(base + Vector2(137, 0), Vector2(238, CHUNK)), Color("#202326"))
	draw_rect(Rect2(base + Vector2(130, 0), Vector2(7, CHUNK)), Color("#6b6659"))
	draw_rect(Rect2(base + Vector2(375, 0), Vector2(7, CHUNK)), Color("#6b6659"))
	draw_rect(Rect2(base + Vector2(116, 0), Vector2(14, CHUNK)), Color("#858071"))
	draw_rect(Rect2(base + Vector2(382, 0), Vector2(14, CHUNK)), Color("#858071"))
	for lane in range(4):
		draw_rect(Rect2(base + Vector2(252, lane * 135 + 22), Vector2(7, 65)), Color("#9e9064"))
	# Each block is a deliberate mix of commercial and residential rooftops.
	for side in range(2):
		var left := 8.0 if side == 0 else 400.0
		for lot in range(3):
			var top := float(lot * 171 + 6)
			var roof := Rect2(base + Vector2(left, top), Vector2(105, 150))
			var facade := Color("#4b4c49") if (lot + side + chunk.x) % 3 == 0 else Color("#60584e")
			draw_rect(roof.grow(5.0), Color("#222322"))
			draw_rect(roof, facade)
			draw_rect(roof.grow(-7.0), facade.darkened(0.14), false, 3.0)
			# Rooftop equipment and skylights make buildings readable from above.
			draw_rect(Rect2(roof.position + Vector2(14, 17), Vector2(31, 24)), Color("#262b2b"))
			draw_rect(Rect2(roof.position + Vector2(57, 69), Vector2(35, 42)), Color("#77776d"))
			draw_line(roof.position + Vector2(12, 128), roof.position + Vector2(91, 128), Color("#292d2c"), 4.0)
			if (lot + side + chunk.y) % 2 == 0:
				draw_rect(Rect2(roof.position + Vector2(48, 18), Vector2(42, 9)), Color("#9b704e"))
	# Deterministic damage: cracks, rubble, scorch marks and neglected weeds.
	for i in range(17):
		var px := local_rng.randf_range(143.0, 368.0)
		var py := local_rng.randf_range(4.0, CHUNK - 4.0)
		var p := base + Vector2(px, py)
		var length := local_rng.randf_range(8.0, 34.0)
		draw_line(p, p + Vector2(length, local_rng.randf_range(-15.0, 16.0)), Color("#11191a"), 2.0)
	for i in range(26):
		var px := local_rng.randf_range(110.0, 401.0)
		var py := local_rng.randf_range(0.0, CHUNK)
		var p := base + Vector2(px, py)
		if i % 4 == 0:
			draw_circle(p, local_rng.randf_range(5.0, 12.0), Color("#292825"))
		else:
			draw_rect(Rect2(p, Vector2(local_rng.randf_range(3.0, 10.0), local_rng.randf_range(3.0, 9.0))), Color("#777063"))
	for i in range(13):
		var side_x := 122.0 if i % 2 == 0 else 389.0
		var weed := base + Vector2(side_x + local_rng.randf_range(-9.0, 9.0), local_rng.randf_range(0.0, CHUNK))
		draw_line(weed, weed + Vector2(-4, -8), Color("#596344"), 2.0)
		draw_line(weed, weed + Vector2(5, -7), Color("#596344"), 2.0)
	# A recognizable abandoned car, with a shadow and oil stain.
	if posmod(chunk.x * 7 + chunk.y * 11, 3) == 0:
		var car_pos := base + Vector2(173, 235)
		draw_circle(car_pos + Vector2(43, 56), 55.0, Color(0.06, 0.07, 0.07, 0.65))
		draw_texture_rect(CAR_ART, Rect2(car_pos, Vector2(128, 80)), false)
	# Intersections and evacuation crossings every third block.
	if posmod(chunk.y, 3) == 0:
		draw_rect(Rect2(base + Vector2(130, 432), Vector2(252, 80)), Color("#26292a"))
		for stripe in range(5):
			draw_rect(Rect2(base + Vector2(151 + stripe * 47, 443), Vector2(26, 10)), Color("#7e7c6e"))
