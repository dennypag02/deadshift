extends Node2D

const TILE := 128.0
const MAP_W := 32
const MAP_H := 40
const MAP_SIZE := Vector2(MAP_W * TILE, MAP_H * TILE)

const SURVIVOR_ART := preload("res://art/survivor_wasteland.svg")
const ZOMBIE_ART := preload("res://art/zombie_shambler.svg")
const CAR_SUV_ART := preload("res://art/cars/car_suv.png")
const CAR_SEDAN_ART := preload("res://art/cars/car_sedan.png")
const OUT_MINIMART_ART := preload("res://art/outskirts/out_minimart.svg")
const OUT_DINER_ART := preload("res://art/outskirts/out_diner.svg")
const OUT_MOTEL_ART := preload("res://art/outskirts/out_motel.svg")
const OUT_AUTOSHOP_ART := preload("res://art/outskirts/out_autoshop.svg")
const OUT_CANOPY_ART := preload("res://art/outskirts/out_canopy.svg")
const OUT_SEMI_ART := preload("res://art/outskirts/out_semi_trailer.svg")
const OUT_TANKER_ART := preload("res://art/outskirts/out_tanker.svg")
const OUT_GAS_PUMP_ART := preload("res://art/outskirts/out_gas_pump.svg")
const OUT_BARRIER_ART := preload("res://art/outskirts/out_barrier.svg")
const OUT_FENCE_ART := preload("res://art/outskirts/out_fence.svg")
const OUT_TIRES_ART := preload("res://art/outskirts/out_tires.svg")
const OUT_SCRUB_ART := preload("res://art/outskirts/out_scrub.svg")
const OUT_SIGN_ART := preload("res://art/outskirts/out_sign_down.svg")
const GROUND_SCRUB_ART := preload("res://art/outskirts/ground_scrub_dirt.svg")
const GROUND_GRAVEL_ART := preload("res://art/outskirts/ground_gravel.svg")

const PLAYER_RADIUS := 22.0
const BULLET_RADIUS := 5.0
const BASE_PLAYER_SPEED := 285.0
const BASE_FIRE_PERIOD := 0.30
const BULLET_SPEED := 680.0
const PUMP_RADIUS := 34.0
const PUMP_BLAST_RADIUS := 275.0

const HIGHWAY_WEST := Vector2(80, 38.0 * TILE)
const HIGHWAY_EAST := Vector2(MAP_SIZE.x - 80, 38.0 * TILE)
const SCRUB_WEST := Vector2(7.0 * TILE, 80)
const SCRUB_EAST := Vector2(24.0 * TILE, 80)
const MOTEL_A := Vector2(24.0 * TILE, 15.0 * TILE)
const MOTEL_B := Vector2(28.0 * TILE, 15.0 * TILE)
const WEST_MID := Vector2(80, 21.0 * TILE)
const EAST_MID := Vector2(MAP_SIZE.x - 80, 21.0 * TILE)
const NORTH_WEST := Vector2(3.5 * TILE, 80)
const NORTH_EAST := Vector2(28.5 * TILE, 80)
const SOUTH_CENTER := Vector2(16.0 * TILE, MAP_SIZE.y - 80)
const PLAYER_START := Vector2(16.0 * TILE, 22.0 * TILE)
const DINER_HEALTH_POS := Vector2(6.0 * TILE, 14.0 * TILE)
const NORTH_EXIT := Rect2(14.0 * TILE, 0, 3.0 * TILE, 5.0 * TILE)
const GENERATOR_POS := Vector2(15.5 * TILE, 13.2 * TILE)
const SUPPLY_DINER := Vector2(6.0 * TILE, 11.0 * TILE)
const SUPPLY_AUTOSHOP := Vector2(5.0 * TILE, 28.0 * TILE)
const SUPPLY_MOTEL := Vector2(27.0 * TILE, 11.0 * TILE)
const NEST_WEST := Vector2(1.5 * TILE, 20.0 * TILE)
const NEST_EAST := Vector2(30.5 * TILE, 20.0 * TILE)
const NEST_NW := Vector2(5.0 * TILE, 3.2 * TILE)
const NEST_NE := Vector2(27.0 * TILE, 3.2 * TILE)

var wave_plan := {
	1: {"shamblers": 180, "runners": 0, "trucker": 0},
	2: {"shamblers": 230, "runners": 0, "trucker": 0},
	3: {"shamblers": 280, "runners": 0, "trucker": 0},
	4: {"shamblers": 330, "runners": 0, "trucker": 0},
	5: {"shamblers": 320, "runners": 40, "trucker": 0},
	6: {"shamblers": 370, "runners": 50, "trucker": 0},
	7: {"shamblers": 420, "runners": 65, "trucker": 0},
	8: {"shamblers": 480, "runners": 80, "trucker": 0},
	9: {"shamblers": 540, "runners": 95, "trucker": 0},
	10: {"shamblers": 600, "runners": 110, "trucker": 1},
}

var player_pos := PLAYER_START
var player_hp := 100
var score := 0
var kills := 0
var wave := 1
var fire_period := BASE_FIRE_PERIOD
var player_speed := BASE_PLAYER_SPEED
var bullet_damage := 1
var wave_active := true
var wave_spawned := 0
var wave_total := 0
var runners_spawned := 0
var trucker_spawned := false
var spawn_clock := 0.0
var fire_clock := 0.0
var health_spawn_clock := 18.0
var health_available := false
var district_cleared := false
var tanker_event := false
var fire_hazard := false
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var touch_active := false

var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pumps: Array[Dictionary] = []
var impact_marks: Array[Dictionary] = []
var supply_caches: Array[Dictionary] = []
var infestation_nests: Array[Dictionary] = []
var generator_active := false
var wave10_survived := false
var objective_flash_clock := 0.0

var camera: Camera2D
var hud: Label
var banner: Label
var upgrade_panel: Panel
var upgrade_title: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 20261012
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_pumps()
	_setup_objectives()
	_setup_camera()
	_setup_ui()
	_start_wave(1)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(0.68, 0.68)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.position = player_pos

func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.04, 0.04, 0.82)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(432, 118)
	ui.add_child(bar)

	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 20)
	ui.add_child(hud)

	banner = Label.new()
	banner.position = Vector2(18, 128)
	banner.size = Vector2(396, 84)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 18)
	ui.add_child(banner)

	upgrade_panel = Panel.new()
	upgrade_panel.position = Vector2(24, 570)
	upgrade_panel.size = Vector2(384, 310)
	upgrade_panel.visible = false
	ui.add_child(upgrade_panel)

	upgrade_title = Label.new()
	upgrade_title.position = Vector2(18, 18)
	upgrade_title.size = Vector2(348, 50)
	upgrade_title.text = "MINI-MART UPGRADE CRATE\nChoose 1 upgrade"
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 18)
	upgrade_panel.add_child(upgrade_title)

	var rapid := Button.new()
	rapid.position = Vector2(32, 88)
	rapid.size = Vector2(320, 52)
	rapid.text = "Rapid Fire  -  fire 12% faster"
	rapid.pressed.connect(_choose_rapid_fire)
	upgrade_panel.add_child(rapid)

	var heavy := Button.new()
	heavy.position = Vector2(32, 154)
	heavy.size = Vector2(320, 52)
	heavy.text = "Heavy Rounds  -  +1 damage"
	heavy.pressed.connect(_choose_heavy_rounds)
	upgrade_panel.add_child(heavy)

	var fleet := Button.new()
	fleet.position = Vector2(32, 220)
	fleet.size = Vector2(320, 52)
	fleet.text = "Fleet Feet  -  move 10% faster"
	fleet.pressed.connect(_choose_fleet_feet)
	upgrade_panel.add_child(fleet)

func _setup_pumps() -> void:
	var positions := [
		Vector2(14.5 * TILE, 18.0 * TILE),
		Vector2(15.5 * TILE, 18.0 * TILE),
		Vector2(16.5 * TILE, 18.0 * TILE),
		Vector2(17.5 * TILE, 18.0 * TILE),
	]
	for p in positions:
		pumps.append({"pos": p, "alive": true})

func _reset_pumps() -> void:
	for pump in pumps:
		pump["alive"] = true

func _setup_objectives() -> void:
	supply_caches = [
		{"pos": SUPPLY_DINER, "name": "Diner", "collected": false},
		{"pos": SUPPLY_AUTOSHOP, "name": "Auto Shop", "collected": false},
		{"pos": SUPPLY_MOTEL, "name": "Motel", "collected": false},
	]
	infestation_nests = [
		{"pos": NEST_WEST, "destroyed": false},
		{"pos": NEST_EAST, "destroyed": false},
		{"pos": NEST_NW, "destroyed": false},
		{"pos": NEST_NE, "destroyed": false},
	]

func _start_wave(next_wave: int) -> void:
	wave = next_wave
	if wave > 10:
		return
	wave_active = true
	wave_spawned = 0
	runners_spawned = 0
	trucker_spawned = false
	var plan: Dictionary = wave_plan[wave]
	wave_total = int(plan["shamblers"]) + int(plan["runners"]) + int(plan["trucker"])
	spawn_clock = 0.12
	_reset_pumps()
	if wave == 10:
		tanker_event = true
		fire_hazard = true
		banner.text = "WAVE 10: TANKER DOWN!\nTRUCKER INCOMING - SURVIVE!"
	elif wave == 6:
		banner.text = "WAVE 6: MOTEL DOORS ARE NOT SAFE"
	elif wave == 5:
		banner.text = "WAVE 5: RUNNERS - PRIORITIZE FAST TARGETS"
	elif wave == 4:
		banner.text = "WAVE 4: CHECK BEHIND YOU - SCRUBLAND ACTIVE"
	elif wave == 3:
		banner.text = "WAVE 3: SHOOT A GAS PUMP WHEN THEY CROWD IT"
	elif wave == 2:
		banner.text = "WAVE 2: WATCH BOTH HIGHWAY ENDS"
	else:
		banner.text = "WAVE 1: THE HORDE IS HERE\nPOWER THE MINI-MART GENERATOR"
	_update_hud()

func _finish_wave() -> void:
	wave_active = false
	if wave == 10:
		wave10_survived = true
		fire_hazard = false
		_try_unlock_district()
		if not district_cleared:
			banner.text = "HORDE BROKEN - FINISH DISTRICT OBJECTIVES"
		_update_hud()
		return
	banner.text = "WAVE %d CLEARED - RETURN TO THE MINI-MART" % wave
	upgrade_panel.visible = true

func _choose_rapid_fire() -> void:
	fire_period = maxf(0.14, fire_period * 0.88)
	_continue_after_upgrade("Rapid Fire")

func _choose_heavy_rounds() -> void:
	bullet_damage += 1
	_continue_after_upgrade("Heavy Rounds")

func _choose_fleet_feet() -> void:
	player_speed *= 1.10
	_continue_after_upgrade("Fleet Feet")

func _continue_after_upgrade(choice: String) -> void:
	upgrade_panel.visible = false
	banner.text = "%s equipped" % choice
	_start_wave(wave + 1)

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
		banner.text = "YOU DIED - RESTART THE APP TO RETRY"
		return

	var direction := Vector2.ZERO
	if touch_active:
		direction = (touch_position - touch_origin).limit_length(90.0) / 90.0
	direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player_pos += direction.limit_length(1.0) * player_speed * delta
	player_pos.x = clampf(player_pos.x, 40.0, MAP_SIZE.x - 40.0)
	player_pos.y = clampf(player_pos.y, 40.0, MAP_SIZE.y - 40.0)
	if not district_cleared and NORTH_EXIT.has_point(player_pos):
		player_pos.y = 5.0 * TILE + 42.0
	camera.position = player_pos

	for i in range(impact_marks.size() - 1, -1, -1):
		impact_marks[i]["life"] -= delta
		if impact_marks[i]["life"] <= 0.0:
			impact_marks.remove_at(i)

	if wave_active:
		spawn_clock -= delta
		var active_target := _active_horde_target()
		if spawn_clock <= 0.0 and wave_spawned < wave_total and enemies.size() < active_target:
			var room := active_target - enemies.size()
			var burst_size := mini(mini(18 + wave * 2, room), wave_total - wave_spawned)
			for _n in range(burst_size):
				_spawn_next_enemy()
			spawn_clock = maxf(0.22, 0.32 - float(wave) * 0.008)
		if wave_spawned >= wave_total and enemies.is_empty():
			_finish_wave()

	fire_clock -= delta
	if fire_clock <= 0.0 and not enemies.is_empty():
		var nearest := 0
		for i in range(1, enemies.size()):
			if player_pos.distance_squared_to(enemies[i]["pos"]) < player_pos.distance_squared_to(enemies[nearest]["pos"]):
				nearest = i
		var heading: Vector2 = (enemies[nearest]["pos"] - player_pos).normalized()
		bullets.append({"pos": player_pos, "dir": heading, "life": 1.6})
		fire_clock = fire_period

	_update_bullets(delta)
	_update_enemies(delta)
	_update_health(delta)
	_update_objectives(delta)
	_update_hud()
	queue_redraw()

func _active_horde_target() -> int:
	return mini(115, 50 + wave * 6)

func _spawn_next_enemy() -> void:
	var plan: Dictionary = wave_plan[wave]
	var kind := "shambler"
	if wave == 10 and int(plan["trucker"]) > 0 and not trucker_spawned and wave_spawned >= wave_total / 2:
		kind = "trucker"
		trucker_spawned = true
	elif runners_spawned < int(plan["runners"]) and (wave_spawned % 3 == 1 or wave_spawned >= int(plan["shamblers"])):
		kind = "runner"
		runners_spawned += 1

	var spawn := _pick_spawn_point()
	var hp := 1
	var speed := 86.0
	var radius := 18.0
	if kind == "runner":
		speed = 155.0
		radius = 15.0
	elif kind == "trucker":
		hp = 30
		speed = 46.0
		radius = 34.0
	enemies.append({
		"pos": spawn,
		"kind": kind,
		"hp": hp,
		"speed": speed,
		"radius": radius,
		"charge": 0.0,
	})
	wave_spawned += 1

func _pick_spawn_point() -> Vector2:
	var points: Array[Vector2] = []

	# Wave 1 teaches movement under pressure: slow enemies, but from five readable approach lanes.
	if wave == 1:
		points = [HIGHWAY_WEST, HIGHWAY_EAST, SOUTH_CENTER, WEST_MID, EAST_MID]
	else:
		points = [HIGHWAY_WEST, HIGHWAY_EAST, SOUTH_CENTER, WEST_MID, EAST_MID]

	# From wave 3 onward the open northern scrub becomes an active threat.
	if wave >= 3:
		points.append(SCRUB_WEST)
		points.append(SCRUB_EAST)
		points.append(NORTH_WEST)
		points.append(NORTH_EAST)

	# Motel pressure starts on wave 6 and is always part of the active pool.
	if wave >= 6:
		points.append(MOTEL_A)
		points.append(MOTEL_B)

	var base := points[rng.randi_range(0, points.size() - 1)]
	# Scatter each spawn so zombies arrive as a loose group rather than a single-file line.
	var jitter := Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
	return Vector2(
		clampf(base.x + jitter.x, 45.0, MAP_SIZE.x - 45.0),
		clampf(base.y + jitter.y, 45.0, MAP_SIZE.y - 45.0)
	)

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		bullet["pos"] += bullet["dir"] * BULLET_SPEED * delta
		bullet["life"] -= delta
		var consumed := false

		for pump in pumps:
			if bool(pump["alive"]) and bullet["pos"].distance_to(pump["pos"]) <= PUMP_RADIUS + BULLET_RADIUS:
				_explode_pump(pump)
				consumed = true
				break
		if consumed:
			bullets.remove_at(i)
			continue

		for j in range(enemies.size() - 1, -1, -1):
			var enemy: Dictionary = enemies[j]
			if bullet["pos"].distance_to(enemy["pos"]) <= float(enemy["radius"]) + BULLET_RADIUS:
				enemy["hp"] = int(enemy["hp"]) - bullet_damage
				if str(enemy["kind"]) == "trucker":
					enemy["charge"] = 1.1
				impact_marks.append({"pos": enemy["pos"], "life": 0.22})
				if int(enemy["hp"]) <= 0:
					kills += 1
					score += 500 if str(enemy["kind"]) == "trucker" else 100
					enemies.remove_at(j)
				consumed = true
				break
		if consumed or float(bullet["life"]) <= 0.0:
			bullets.remove_at(i)

func _explode_pump(pump: Dictionary) -> void:
	pump["alive"] = false
	impact_marks.append({"pos": pump["pos"], "life": 0.55, "blast": true})
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var distance: float = Vector2(enemy["pos"]).distance_to(Vector2(pump["pos"]))
		if distance <= PUMP_BLAST_RADIUS:
			var damage := 10 if str(enemy["kind"]) == "trucker" else 99
			enemy["hp"] = int(enemy["hp"]) - damage
			if int(enemy["hp"]) <= 0:
				kills += 1
				score += 500 if str(enemy["kind"]) == "trucker" else 100
				enemies.remove_at(i)
	banner.text = "PUMP DETONATED!"

func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var to_player: Vector2 = player_pos - enemy["pos"]
		var speed := float(enemy["speed"])
		if str(enemy["kind"]) == "trucker" and float(enemy["charge"]) > 0.0:
			enemy["charge"] = maxf(0.0, float(enemy["charge"]) - delta)
			speed = 165.0
		enemy["pos"] += to_player.normalized() * speed * delta
		if to_player.length() < PLAYER_RADIUS + float(enemy["radius"]):
			var damage := 18 if str(enemy["kind"]) == "trucker" else 7
			player_hp = maxi(0, player_hp - damage)
			enemies.remove_at(i)

func _update_health(delta: float) -> void:
	if health_available:
		if player_pos.distance_to(DINER_HEALTH_POS) < 58.0:
			player_hp = mini(100, player_hp + 35)
			health_available = false
			health_spawn_clock = 28.0
			banner.text = "DINER MEDKIT: +35 HP"
	else:
		health_spawn_clock -= delta
		if health_spawn_clock <= 0.0:
			health_available = true

func _update_objectives(delta: float) -> void:
	objective_flash_clock = maxf(0.0, objective_flash_clock - delta)

	if not generator_active and player_pos.distance_to(GENERATOR_POS) < 105.0:
		generator_active = true
		score += 500
		objective_flash_clock = 2.5
		banner.text = "GENERATOR ONLINE!\nMINI-MART POWER RESTORED"
		_try_unlock_district()

	for cache in supply_caches:
		if not bool(cache["collected"]) and player_pos.distance_to(Vector2(cache["pos"])) < 95.0:
			cache["collected"] = true
			score += 350
			objective_flash_clock = 2.5
			banner.text = "SUPPLIES RECOVERED: %s" % str(cache["name"])
			_try_unlock_district()

	for nest in infestation_nests:
		if not bool(nest["destroyed"]) and player_pos.distance_to(Vector2(nest["pos"])) < 105.0:
			nest["destroyed"] = true
			score += 600
			objective_flash_clock = 2.5
			impact_marks.append({"pos": nest["pos"], "life": 0.55, "blast": true})
			_kill_enemies_near(Vector2(nest["pos"]), 240.0)
			banner.text = "INFESTATION NEST DESTROYED!"
			_try_unlock_district()

func _kill_enemies_near(center: Vector2, radius: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if Vector2(enemies[i]["pos"]).distance_to(center) <= radius:
			kills += 1
			score += 100
			enemies.remove_at(i)

func _objective_counts() -> Dictionary:
	var supplies := 0
	for cache in supply_caches:
		if bool(cache["collected"]):
			supplies += 1
	var nests := 0
	for nest in infestation_nests:
		if bool(nest["destroyed"]):
			nests += 1
	return {"supplies": supplies, "nests": nests}

func _objectives_complete() -> bool:
	var counts := _objective_counts()
	return generator_active and int(counts["supplies"]) == 3 and int(counts["nests"]) == 4

func _try_unlock_district() -> void:
	if wave10_survived and _objectives_complete():
		district_cleared = true
		banner.text = "OUTSKIRTS CLEARED!\nROAD NORTH TO DOWNTOWN UNLOCKED"

func _update_hud() -> void:
	var remaining := enemies.size() + maxi(0, wave_total - wave_spawned)
	var state := "CLEAR" if district_cleared else ("FIGHT" if wave_active else "UPGRADE")
	var counts := _objective_counts()
	var gen_mark := "ON" if generator_active else "OFF"
	hud.text = "OUTSKIRTS  W%d/10  HP %d  Score %d  %s\nThreats %d | Generator %s | Supplies %d/3 | Nests %d/4" % [
		wave, player_hp, score, state, remaining, gen_mark, int(counts["supplies"]), int(counts["nests"])
	]

func _draw() -> void:
	_draw_ground()
	_draw_structures()
	_draw_props()
	_draw_objectives()
	_draw_spawn_markers()
	_draw_combat()
	_draw_dusk()

func _draw_ground() -> void:
	# Warm cracked dirt is the district's dominant ground treatment.
	draw_texture_rect(GROUND_SCRUB_ART, Rect2(Vector2.ZERO, MAP_SIZE), false, Color("#d7b779"))
	# Scrub edge is darker and rougher.
	draw_texture_rect(GROUND_SCRUB_ART, Rect2(0, 0, MAP_SIZE.x, 5.0 * TILE), false, Color("#9e8759"))
	# Road north and bottom highway remain high-contrast navigation anchors.
	draw_rect(Rect2(14.0 * TILE, 0, 3.0 * TILE, 11.0 * TILE), Color("#4b4942"))
	draw_rect(Rect2(0, 36.0 * TILE, MAP_SIZE.x, 4.0 * TILE), Color("#2b2d2f"))
	# Truck-stop lot gets a distinct gravel surface.
	draw_texture_rect(GROUND_GRAVEL_ART, Rect2(22.0 * TILE, 24.0 * TILE, 9.0 * TILE, 10.0 * TILE), false, Color("#999283"))
	for lane in range(1, 32):
		var x := float(lane) * TILE
		draw_line(Vector2(x, 36.0 * TILE), Vector2(x, MAP_SIZE.y), Color(0.12,0.12,0.12,0.18), 1.0)
	for stripe in range(0, 32, 2):
		draw_rect(Rect2(stripe * TILE, 37.85 * TILE, TILE * 0.65, 10), Color("#d0b76f"))

func _draw_structures() -> void:
	_draw_asset_rect(OUT_MINIMART_ART, Rect2(12.0 * TILE, 11.0 * TILE, 7.0 * TILE, 4.0 * TILE))
	_draw_asset_rect(OUT_DINER_ART, Rect2(3.0 * TILE, 8.0 * TILE, 6.0 * TILE, 5.0 * TILE))
	_draw_asset_rect(OUT_AUTOSHOP_ART, Rect2(2.0 * TILE, 25.0 * TILE, 7.0 * TILE, 6.0 * TILE))
	_draw_asset_rect(OUT_MOTEL_ART, Rect2(22.0 * TILE, 7.0 * TILE, 9.0 * TILE, 8.0 * TILE))
	_draw_asset_rect(OUT_CANOPY_ART, Rect2(13.0 * TILE, 16.0 * TILE, 6.0 * TILE, 5.0 * TILE))
	_label(Vector2(12.2 * TILE, 10.8 * TILE), "MINI-MART / UPGRADES", 24, Color("#2a211b"))
	_label(Vector2(3.2 * TILE, 7.8 * TILE), "DINER / HEALTH", 24, Color("#2a211b"))
	_label(Vector2(13.2 * TILE, 15.7 * TILE), "GAS STATION HUB", 28, Color("#2a211b"))

	if not district_cleared:
		draw_rect(Rect2(14.0 * TILE, 0, 3.0 * TILE, 18), Color("#a83232"))
		_label(Vector2(14.05 * TILE, 40), "DOWNTOWN LOCKED", 24, Color("#f0d8c0"))
	else:
		draw_rect(Rect2(14.0 * TILE, 0, 3.0 * TILE, 18), Color("#4d9d55"))
		_label(Vector2(14.05 * TILE, 40), "DOWNTOWN OPEN", 24, Color("#e5f5d9"))

func _draw_building(rect: Rect2, color: Color, title: String) -> void:
	draw_rect(rect.grow(12.0), Color(0.08,0.08,0.08,0.55))
	draw_rect(rect, color)
	draw_rect(rect.grow(-18.0), color.darkened(0.15), false, 6.0)
	_label(rect.position + Vector2(16, 42), title, 24, Color("#1b1b1b"))

func _draw_props() -> void:
	for pump in pumps:
		var p: Vector2 = pump["pos"]
		if bool(pump["alive"]):
			_draw_asset_centered(OUT_GAS_PUMP_ART, p, Vector2(92, 118))
		else:
			draw_circle(p, 30, Color("#25211d"))

	# Truck-stop trailer cover.
	_draw_asset_rect(OUT_SEMI_ART, Rect2(23.0 * TILE, 25.8 * TILE, 1.8 * TILE, 5.5 * TILE))
	_draw_asset_rect(OUT_SEMI_ART, Rect2(26.7 * TILE, 27.4 * TILE, 1.8 * TILE, 5.5 * TILE))

	# Existing approved vehicle art remains part of the district language.
	_draw_car(CAR_SUV_ART, Vector2(10.0 * TILE, 23.0 * TILE), -0.18, Color(0.93,0.90,0.82))
	_draw_car(CAR_SEDAN_ART, Vector2(21.0 * TILE, 19.5 * TILE), 0.16, Color(0.82,0.88,0.92))
	_draw_car(CAR_SUV_ART, Vector2(7.5 * TILE, 34.0 * TILE), 0.08, Color(0.84,0.90,0.80))
	_draw_car(CAR_SEDAN_ART, Vector2(26.0 * TILE, 35.0 * TILE), -0.12, Color(0.92,0.82,0.78))

	# Boundary dressing turns the map edge into readable physical space.
	for x in range(1, 31, 3):
		_draw_asset_centered(OUT_SCRUB_ART, Vector2(float(x) * TILE, 3.5 * TILE), Vector2(150, 120))
	for y in range(6, 35, 5):
		_draw_asset_centered(OUT_FENCE_ART, Vector2(70, float(y) * TILE), Vector2(105, 150))
		_draw_asset_centered(OUT_FENCE_ART, Vector2(MAP_SIZE.x - 70, float(y) * TILE), Vector2(105, 150))
	for x in range(2, 31, 5):
		_draw_asset_centered(OUT_BARRIER_ART, Vector2(float(x) * TILE, 35.6 * TILE), Vector2(120, 72))
	_draw_asset_centered(OUT_TIRES_ART, Vector2(8.3 * TILE, 30.5 * TILE), Vector2(150, 150))
	_draw_asset_centered(OUT_SIGN_ART, Vector2(19.8 * TILE, 34.5 * TILE), Vector2(160, 145))

	if health_available:
		draw_circle(DINER_HEALTH_POS, 30, Color("#d85454"))
		draw_rect(Rect2(DINER_HEALTH_POS - Vector2(7, 23), Vector2(14, 46)), Color.WHITE)
		draw_rect(Rect2(DINER_HEALTH_POS - Vector2(23, 7), Vector2(46, 14)), Color.WHITE)

	if tanker_event:
		_draw_asset_rect(OUT_TANKER_ART, Rect2(8.5 * TILE, 35.9 * TILE, 15.0 * TILE, 2.4 * TILE))
	if fire_hazard:
		for i in range(10):
			var fire_pos := Vector2((7.0 + i * 1.8) * TILE, 36.8 * TILE)
			draw_circle(fire_pos, 38, Color(1.0, 0.35, 0.08, 0.78))
			draw_circle(fire_pos + Vector2(8,-16), 22, Color(1.0, 0.75, 0.15, 0.85))

func _draw_asset_rect(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, rect, false, tint)

func _draw_asset_centered(texture: Texture2D, center: Vector2, size: Vector2, rotation: float = 0.0, tint: Color = Color.WHITE) -> void:
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_car(texture: Texture2D, center: Vector2, rotation: float, tint: Color) -> void:
	var texture_size := Vector2(texture.get_size())
	var scale_factor := 285.0 / maxf(texture_size.x, texture_size.y)
	var draw_size := texture_size * scale_factor
	draw_circle(center + Vector2(10,18), 102, Color(0.05,0.05,0.05,0.38))
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_objectives() -> void:
	# Generator objective.
	if not generator_active:
		draw_circle(GENERATOR_POS, 42, Color(0.95, 0.80, 0.20, 0.28))
		draw_circle(GENERATOR_POS, 22, Color("#e6c04d"))
		_label(GENERATOR_POS + Vector2(-76, -55), "GENERATOR", 20, Color("#fff0a8"))

	# Supply caches.
	for cache in supply_caches:
		if not bool(cache["collected"]):
			var p := Vector2(cache["pos"])
			draw_rect(Rect2(p - Vector2(24, 18), Vector2(48, 36)), Color("#4b8f61"))
			draw_rect(Rect2(p - Vector2(30, 24), Vector2(60, 48)), Color(0.6, 1.0, 0.7, 0.25), false, 5.0)
			_label(p + Vector2(-52, -38), "SUPPLIES", 18, Color("#d8ffdf"))

	# Infestation nests: dangerous red targets at the perimeter.
	for nest in infestation_nests:
		if not bool(nest["destroyed"]):
			var p := Vector2(nest["pos"])
			draw_circle(p, 42, Color(0.55, 0.08, 0.05, 0.55))
			draw_circle(p, 24, Color("#7f1d18"))
			for a in range(0, 8):
				var angle := float(a) * TAU / 8.0
				draw_line(p + Vector2.RIGHT.rotated(angle) * 22.0, p + Vector2.RIGHT.rotated(angle) * 54.0, Color("#a83a2f"), 7.0)
			_label(p + Vector2(-34, -62), "NEST", 18, Color("#ffd0c4"))

func _draw_spawn_markers() -> void:
	_spawn_marker(HIGHWAY_WEST, Color("#e6c04d"))
	_spawn_marker(HIGHWAY_EAST, Color("#e6c04d"))
	_spawn_marker(SOUTH_CENTER, Color("#e6c04d"))
	if wave >= 2:
		_spawn_marker(WEST_MID, Color("#d98c4d"))
		_spawn_marker(EAST_MID, Color("#d98c4d"))
	if wave >= 3:
		_spawn_marker(SCRUB_WEST, Color("#6ca45a"))
		_spawn_marker(SCRUB_EAST, Color("#6ca45a"))
		_spawn_marker(NORTH_WEST, Color("#6ca45a"))
		_spawn_marker(NORTH_EAST, Color("#6ca45a"))
	if wave >= 6:
		_spawn_marker(MOTEL_A, Color("#c84f4f"))
		_spawn_marker(MOTEL_B, Color("#c84f4f"))

func _spawn_marker(pos: Vector2, color: Color) -> void:
	draw_circle(pos, 22, color)
	draw_circle(pos, 35, Color(color.r, color.g, color.b, 0.25))

func _draw_combat() -> void:
	for enemy in enemies:
		var p: Vector2 = enemy["pos"]
		var kind := str(enemy["kind"])
		var radius := float(enemy["radius"])
		if kind == "trucker":
			draw_circle(p + Vector2(6,12), radius + 10, Color(0.05,0.05,0.05,0.55))
			draw_circle(p, radius, Color("#7e392f"))
			_label(p + Vector2(-42,-52), "TRUCKER", 20, Color("#ffdfbd"))
		elif kind == "runner":
			draw_circle(p, radius + 3, Color("#c98744"))
			draw_texture_rect(ZOMBIE_ART, Rect2(p - Vector2(23,23), Vector2(46,46)), false)
		else:
			draw_texture_rect(ZOMBIE_ART, Rect2(p - Vector2(25,25), Vector2(50,50)), false)

	for bullet in bullets:
		draw_line(bullet["pos"] - bullet["dir"] * 12.0, bullet["pos"], Color("#ffcb65"), 4.0)
		draw_circle(bullet["pos"], BULLET_RADIUS, Color("#fff2b8"))

	for mark in impact_marks:
		var life := float(mark["life"])
		var is_blast := bool(mark.get("blast", false))
		var radius := 28.0 if not is_blast else 115.0 * clampf(life / 0.55, 0.2, 1.0)
		draw_circle(mark["pos"], radius, Color(1.0,0.35,0.08,0.42 if is_blast else 0.55))

	draw_circle(player_pos + Vector2(6,14), 35, Color(0.02,0.02,0.02,0.58))
	draw_texture_rect(SURVIVOR_ART, Rect2(player_pos - Vector2(48,48), Vector2(96,96)), false)

func _draw_dusk() -> void:
	if wave < 7:
		return
	var dusk := clampf(float(wave - 6) / 4.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.12,0.10,0.22,0.10 + dusk * 0.24))

func _label(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
