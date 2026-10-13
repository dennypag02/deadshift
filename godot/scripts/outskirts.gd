extends Node2D

const TILE := 128.0
const MAP_W := 32
const MAP_H := 40
const MAP_SIZE := Vector2(MAP_W * TILE, MAP_H * TILE)

const SURVIVOR_ART := preload("res://art/survivor_wasteland.svg")
const ZOMBIE_ART := preload("res://art/zombie_shambler.svg")
const CAR_SEDAN_ART := preload("res://art/cars/car_sedan.png")
const CAR_SUV_ART := preload("res://art/cars/car_suv.png")
const OUT_DINER_ART := preload("res://art/outskirts/out_diner.svg")
const OUT_MINIMART_ART := preload("res://art/outskirts/out_minimart.svg")
const OUT_MOTEL_N_ART := preload("res://art/outskirts/out_motel_north.svg")
const OUT_MOTEL_E_ART := preload("res://art/outskirts/out_motel_east.svg")
const OUT_AUTOSHOP_ART := preload("res://art/outskirts/out_autoshop.svg")
const OUT_CANOPY_ART := preload("res://art/outskirts/out_canopy.svg")
const OUT_SEMI_ART := preload("res://art/outskirts/out_semi_trailer.svg")
const OUT_PUMP_ART := preload("res://art/outskirts/out_pump_island.svg")
const OUT_BARRELS_ART := preload("res://art/outskirts/out_barrels.svg")
const OUT_BARRIER_ART := preload("res://art/outskirts/out_barrier.svg")
const OUT_FENCE_ART := preload("res://art/outskirts/out_fence.svg")
const OUT_TANKER_ART := preload("res://art/outskirts/out_tanker.svg")
const TEX_FORECOURT := preload("res://art/outskirts/tex_forecourt.svg")
const TEX_ASPHALT := preload("res://art/outskirts/tex_asphalt.svg")
const TEX_HIGHWAY := preload("res://art/outskirts/tex_highway.svg")
const TEX_CRACKED := preload("res://art/outskirts/tex_cracked.svg")
const TEX_OIL := preload("res://art/outskirts/tex_oil.svg")
const TEX_GRAVEL := preload("res://art/outskirts/tex_gravel.svg")
const TEX_SCRUB := preload("res://art/outskirts/tex_scrub.svg")
const MAP_ROWS: Array[String] = [
	",,,,,,,,,,,,,,GGG,,,,,,,,,,,,,,,",
	",,,,,S,,,,,,,,...,,,,,,,,,S,,,,,",
	",,,FFFFFF,,,,,...,,,,,FFFFFF,,,,",
	",,,,,,,,,,,,,,...,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,...,,,,,,,,,,,,,,,",
	"......xxx...............xx......",
	"...................CC...........",
	".......................BBBBBBBB.",
	".BBBBBBB....BBBBBBBB...BBBBBBBB.",
	".BBBBBBB.+..BBBBBBBB...BBBBBBBB.",
	".BBBBBBB....BBBBBBBB......S.BBB.",
	".BBBBBBB....BBBBBBBB........BBB.",
	".BBBBBBB.......U............BBB.",
	".BBBBBBB.............bb.....BBB.",
	".CC.CC.....==========.......BBB.",
	"...........==========......SBBB.",
	"...........==PP==PP==.......BBB.",
	"...........==========.CC........",
	"...........==========...JJ......",
	"...........==PP==PP==...........",
	".BBBBBBBooo==========.:::::::::.",
	".BBBBBBBooo==========.:TT::::::.",
	".BBBBBBBoo............:TT:::TT:.",
	".BBBBBBBo..CC.........:TT:::TT:.",
	".BBBBBBB..............:TT:o:TT:.",
	".BBBBBBB.........CC...:TT:::TT:.",
	"..ooooo...............:TT:::TT:.",
	".CCoooCC..............:TT:::TT:.",
	"...oo.......CC........::::::TT:.",
	"......................::::bb:::.",
	"................JJJ...:::::::::.",
	"......................JJJ..JJJ..",
	"................................",
	"JJJJxxxxJJJJ.......JJJJxxxxJJJJJ",
	"S-----CC-----KKKKKKK----xxxCC---",
	"---xxx-------KKKKKKK------------",
	"---------CC--KKKKKKK--xxxx-----S",
	"-----xxx-------------CC---------",
	"..........xxxx..............xxxx",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
]

const BLOCKING_CHARS := "BCTPbJF"
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
const SUPPLY_DINER := Vector2(9.5 * TILE, 10.5 * TILE)
const SUPPLY_AUTOSHOP := Vector2(5.0 * TILE, 28.0 * TILE)
const SUPPLY_MOTEL := Vector2(27.0 * TILE, 11.0 * TILE)
const NEST_WEST := Vector2(9.5 * TILE, 21.5 * TILE)
const NEST_EAST := Vector2(30.5 * TILE, 20.0 * TILE)
const NEST_NW := Vector2(5.0 * TILE, 3.2 * TILE)
const NEST_NE := Vector2(27.0 * TILE, 3.2 * TILE)
const PUZZLE_CENTER := Vector2(26.5 * TILE, 27.5 * TILE)
const RELAY_RED := Vector2(25.5 * TILE, 23.5 * TILE)
const RELAY_YELLOW := Vector2(25.5 * TILE, 30.5 * TILE)
const RELAY_BLUE := Vector2(27.5 * TILE, 27.5 * TILE)
const PUZZLE_GUARD_RADIUS := 560.0
const PUZZLE_CODE := ["RED", "BLUE", "YELLOW", "RED"]

var wave_plan := {
	1: {"shamblers": 180, "runners": 12, "trucker": 0},
	2: {"shamblers": 240, "runners": 20, "trucker": 0},
	3: {"shamblers": 300, "runners": 30, "trucker": 0},
	4: {"shamblers": 360, "runners": 42, "trucker": 0},
	5: {"shamblers": 420, "runners": 58, "trucker": 0},
	6: {"shamblers": 480, "runners": 72, "trucker": 0},
	7: {"shamblers": 540, "runners": 88, "trucker": 0},
	8: {"shamblers": 610, "runners": 108, "trucker": 0},
	9: {"shamblers": 680, "runners": 130, "trucker": 0},
	10: {"shamblers": 760, "runners": 155, "trucker": 1},
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
var player_velocity := Vector2.ZERO
var hazard_debug := false
var puzzle_started := false
var puzzle_complete := false
var puzzle_step := 0
var puzzle_guard_wave := 0
var puzzle_pad_lock := 0.0
var detonator_core := false

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
	pumps.clear()
	for y in range(MAP_H):
		for x in range(MAP_W):
			if _tile_char(x, y) == "P":
				pumps.append({"pos": _tile_center(x, y), "alive": true})

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		hazard_debug = not hazard_debug
		queue_redraw()
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
	direction = direction.limit_length(1.0)

	var hazard := _hazard_at(player_pos)
	var speed_mult := float(hazard["speed_mult"])
	var desired_velocity := direction * player_speed * speed_mult
	if bool(hazard["slippery"]):
		player_velocity = player_velocity.move_toward(desired_velocity, player_speed * delta / 0.35)
	else:
		player_velocity = desired_velocity

	player_pos = _move_with_blockers(player_pos, player_velocity * delta, PLAYER_RADIUS)
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
			var burst_size := mini(mini(26 + wave * 3, room), wave_total - wave_spawned)
			for _n in range(burst_size):
				_spawn_next_enemy()
			spawn_clock = maxf(0.14, 0.22 - float(wave) * 0.006)
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
	_update_puzzle(delta)
	_update_hud()
	queue_redraw()

func _active_horde_target() -> int:
	return mini(170, 90 + wave * 8)

func _spawn_next_enemy() -> void:
	var plan: Dictionary = wave_plan[wave]
	var kind := "shambler"
	if wave == 10 and int(plan["trucker"]) > 0 and not trucker_spawned and wave_spawned >= wave_total / 2:
		kind = "trucker"
		trucker_spawned = true
	elif runners_spawned < int(plan["runners"]) and (wave_spawned % 4 == 1 or wave_spawned >= int(plan["shamblers"])):
		kind = "runner"
		runners_spawned += 1

	var spawn := _pick_spawn_point()
	var hp := 1
	var speed := 108.0
	var radius := 18.0
	if kind == "runner":
		speed = 195.0
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

		var bullet_tile := _char_at_world(Vector2(bullet["pos"]))
		if _bullet_blocked_by(bullet_tile):
			bullets.remove_at(i)
			continue

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
		var enemy_hazard := _hazard_at(Vector2(enemy["pos"]))
		speed *= float(enemy_hazard["speed_mult"])
		var enemy_step := to_player.normalized() * speed * delta
		enemy["pos"] = _move_with_blockers(Vector2(enemy["pos"]), enemy_step, float(enemy["radius"]))
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

func _update_puzzle(delta: float) -> void:
	puzzle_pad_lock = maxf(0.0, puzzle_pad_lock - delta)

	if not puzzle_started and player_pos.distance_to(PUZZLE_CENTER) < PUZZLE_GUARD_RADIUS:
		puzzle_started = true
		puzzle_guard_wave = 1
		_spawn_puzzle_guard_surge(28, 14)
		banner.text = "FORTIFIED RELAY SITE\nCODE: RED > BLUE > YELLOW > RED"

	if not puzzle_started or puzzle_complete or puzzle_pad_lock > 0.0:
		return

	var touched := ""
	if player_pos.distance_to(RELAY_RED) < 70.0:
		touched = "RED"
	elif player_pos.distance_to(RELAY_BLUE) < 70.0:
		touched = "BLUE"
	elif player_pos.distance_to(RELAY_YELLOW) < 70.0:
		touched = "YELLOW"

	if touched == "":
		return

	puzzle_pad_lock = 0.75
	var expected := str(PUZZLE_CODE[puzzle_step])
	if touched == expected:
		puzzle_step += 1
		score += 250
		if puzzle_step >= PUZZLE_CODE.size():
			puzzle_complete = true
			detonator_core = true
			score += 2500
			banner.text = "RELAY PUZZLE SOLVED!\nDETONATOR CORE ACQUIRED"
			impact_marks.append({"pos": PUZZLE_CENTER, "life": 0.75, "blast": true})
			_try_unlock_district()
		else:
			banner.text = "RELAY %d/4 CORRECT - KEEP MOVING!" % puzzle_step
	else:
		puzzle_step = 0
		puzzle_guard_wave += 1
		_spawn_puzzle_guard_surge(18 + puzzle_guard_wave * 4, 10 + puzzle_guard_wave * 3)
		banner.text = "WRONG RELAY! CODE RESET\nREINFORCEMENTS INBOUND"

func _spawn_puzzle_guard_surge(shamblers: int, runners: int) -> void:
	var guard_points := [
		PUZZLE_CENTER + Vector2(-420, -260),
		PUZZLE_CENTER + Vector2(410, -230),
		PUZZLE_CENTER + Vector2(-390, 300),
		PUZZLE_CENTER + Vector2(390, 320),
		PUZZLE_CENTER + Vector2(0, -430),
	]
	for i in range(shamblers + runners):
		var base: Vector2 = guard_points[i % guard_points.size()]
		var spawn := base + Vector2(rng.randf_range(-100.0, 100.0), rng.randf_range(-100.0, 100.0))
		spawn.x = clampf(spawn.x, 45.0, MAP_SIZE.x - 45.0)
		spawn.y = clampf(spawn.y, 45.0, MAP_SIZE.y - 45.0)
		var is_runner := i >= shamblers
		var spawn_radius := 15.0 if is_runner else 18.0
		spawn = _nearest_walkable_position(spawn, spawn_radius)
		enemies.append({
			"pos": spawn,
			"kind": "runner" if is_runner else "shambler",
			"hp": 1,
			"speed": 205.0 if is_runner else 112.0,
			"radius": spawn_radius,
			"charge": 0.0,
		})

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
	return generator_active and int(counts["supplies"]) == 3 and int(counts["nests"]) == 4 and detonator_core

func _try_unlock_district() -> void:
	if wave10_survived and _objectives_complete():
		district_cleared = true
		banner.text = "OUTSKIRTS CLEARED!\nROAD NORTH TO DOWNTOWN UNLOCKED"

func _update_hud() -> void:
	var remaining := enemies.size() + maxi(0, wave_total - wave_spawned)
	var state := "CLEAR" if district_cleared else ("FIGHT" if wave_active else "UPGRADE")
	var counts := _objective_counts()
	var gen_mark := "ON" if generator_active else "OFF"
	var core_mark := "YES" if detonator_core else "NO"
	hud.text = "OUTSKIRTS  W%d/10  HP %d  Score %d  %s\nThreats %d | Gen %s | Supplies %d/3 | Nests %d/4 | Core %s" % [
		wave, player_hp, score, state, remaining, gen_mark, int(counts["supplies"]), int(counts["nests"]), core_mark
	]

func _draw() -> void:
	_draw_grid_map()
	_draw_map_art()
	_draw_objectives()
	_draw_spawn_markers()
	_draw_combat()
	_draw_dusk()

func _draw_grid_map() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			var ch := _tile_char(x, y)
			var rect := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
			_draw_grid_tile(rect, ch)
	if hazard_debug:
		_draw_hazard_debug()

func _draw_grid_tile(rect: Rect2, ch: String) -> void:
	var ground_texture: Texture2D = TEX_ASPHALT
	match ch:
		",": ground_texture = TEX_SCRUB
		"-": ground_texture = TEX_HIGHWAY
		"=": ground_texture = TEX_FORECOURT
		":": ground_texture = TEX_GRAVEL
		"x": ground_texture = TEX_CRACKED
		"o": ground_texture = TEX_OIL
		_:
			ground_texture = TEX_ASPHALT
	draw_texture_rect(ground_texture, rect, false)

	# Gray-box blocker fill remains underneath final art so collision footprints stay obvious.
	match ch:
		"B": draw_rect(rect, Color("#555555"))
		"C": pass # collision-only car footprint; pavement remains visible beneath transparent sprite
		"T": draw_rect(rect, Color("#9a9a9a"))
		"P": draw_rect(rect, Color("#c0392b"))
		"b": draw_rect(rect, Color("#e67e22"))
		"J": draw_rect(rect, Color("#bbbbbb"))
		"F":
			draw_line(rect.position + Vector2(0, TILE * 0.35), rect.position + Vector2(TILE, TILE * 0.35), Color("#777777"), 10.0)
			draw_line(rect.position + Vector2(0, TILE * 0.65), rect.position + Vector2(TILE, TILE * 0.65), Color("#777777"), 10.0)
		"K": draw_rect(rect.grow(-4.0), Color("#c0392b"), false, 5.0)
		"G": draw_rect(rect, Color("#8e44ad") if not district_cleared else Color("#4d9d55"))
		"S": draw_circle(rect.get_center(), 12.0, Color("#ff25c6"))
		"U": draw_rect(Rect2(rect.get_center() - Vector2(16,16), Vector2(32,32)), Color("#f1c40f"))
		"+": draw_rect(Rect2(rect.get_center() - Vector2(15,15), Vector2(30,30)), Color("#2ecc71"))

func _draw_map_art() -> void:
	# Buildings follow the exact locked gray-box footprints.
	_draw_art_rect(OUT_DINER_ART, _tiles_rect(1, 8, 7, 6))
	_draw_art_rect(OUT_MINIMART_ART, _tiles_rect(12, 8, 8, 4))
	_draw_art_rect(OUT_MOTEL_N_ART, _tiles_rect(23, 7, 8, 3))
	_draw_art_rect(OUT_MOTEL_E_ART, _tiles_rect(28, 10, 3, 7))
	_draw_art_rect(OUT_AUTOSHOP_ART, _tiles_rect(1, 20, 7, 6))
	_draw_art_rect(OUT_CANOPY_ART, _tiles_rect(11, 14, 10, 8), Color(1,1,1,0.90))

	# Two 2x7 truck-stop trailers.
	_draw_art_rect(OUT_SEMI_ART, _tiles_rect(23, 21, 2, 7))
	_draw_art_rect(OUT_SEMI_ART, _tiles_rect(27, 22, 2, 7))

	# Four 2x1 pump islands.
	for p in [Vector2i(13,16), Vector2i(17,16), Vector2i(13,19), Vector2i(17,19)]:
		_draw_art_rect(OUT_PUMP_ART, _tiles_rect(p.x, p.y, 2, 1))

	# Two disposable barrel clusters.
	_draw_art_rect(OUT_BARRELS_ART, _tiles_rect(21,13,2,1))
	_draw_art_rect(OUT_BARRELS_ART, _tiles_rect(26,29,2,1))

	# Fences are long 6x1 art pieces but still use the grid collision.
	_draw_art_rect(OUT_FENCE_ART, _tiles_rect(3,2,6,1))
	_draw_art_rect(OUT_FENCE_ART, _tiles_rect(23,2,6,1))

	# Cars occupy every 2-tile C run in the design sheet.
	var cars := [
		[19,6, CAR_SEDAN_ART], [1,14, CAR_SUV_ART], [4,14, CAR_SEDAN_ART],
		[21,17, CAR_SUV_ART], [11,23, CAR_SEDAN_ART], [17,25, CAR_SUV_ART],
		[1,27, CAR_SEDAN_ART], [6,27, CAR_SUV_ART], [12,28, CAR_SEDAN_ART],
		[6,34, CAR_SUV_ART], [27,34, CAR_SEDAN_ART], [9,36, CAR_SUV_ART],
		[24,37, CAR_SEDAN_ART]
	]
	for car in cars:
		_draw_art_rect(car[2], _tiles_rect(int(car[0]), int(car[1]), 2, 1))

	# Jersey barriers use one tile each.
	for p in [Vector2i(24,18), Vector2i(25,18), Vector2i(16,30), Vector2i(17,30), Vector2i(18,30),
		Vector2i(22,31), Vector2i(23,31), Vector2i(24,31), Vector2i(27,31), Vector2i(28,31), Vector2i(29,31)]:
		_draw_art_rect(OUT_BARRIER_ART, _tiles_rect(p.x,p.y,1,1))

	# Wave 10 art replaces the red K outline with the tanker wreck.
	if tanker_event:
		_draw_art_rect(OUT_TANKER_ART, _tiles_rect(13,34,7,3))

func _tiles_rect(x: int, y: int, w: int, h: int) -> Rect2:
	return Rect2(Vector2(float(x),float(y))*TILE, Vector2(float(w),float(h))*TILE)

func _draw_art_rect(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, rect, false, tint)

func _draw_hazard_debug() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			var ch := _tile_char(x, y)
			var mult := _speed_mult_for_char(ch)
			if mult < 1.0:
				var center := _tile_center(x, y)
				_label(center + Vector2(-34, 7), "%.2fx" % mult, 18, Color.WHITE)

func _tile_char(x: int, y: int) -> String:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H:
		return "B"
	return MAP_ROWS[y].substr(x, 1)

func _char_at_world(pos: Vector2) -> String:
	return _tile_char(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))

func _tile_center(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * TILE, (float(y) + 0.5) * TILE)

func _speed_mult_for_char(ch: String) -> float:
	match ch:
		":": return 0.90
		"x": return 0.80
		"o": return 0.70
	return 1.0

func _hazard_at(pos: Vector2) -> Dictionary:
	var ch := _char_at_world(pos)
	return {"speed_mult": _speed_mult_for_char(ch), "slippery": ch == "o", "char": ch}

func _is_blocking_char(ch: String) -> bool:
	if ch == "G":
		return not district_cleared
	return BLOCKING_CHARS.contains(ch)

func _bullet_blocked_by(ch: String) -> bool:
	# Chain-link fences block movement but bullets pass through.
	if ch == "F":
		return false
	# Pumps remain handled by their explosion hit-test.
	if ch == "P":
		return false
	return ch in ["B", "C", "T", "b", "J"]

func _circle_hits_blocker(pos: Vector2, radius: float) -> bool:
	var min_x := int(floor((pos.x - radius) / TILE))
	var max_x := int(floor((pos.x + radius) / TILE))
	var min_y := int(floor((pos.y - radius) / TILE))
	var max_y := int(floor((pos.y + radius) / TILE))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var ch := _tile_char(x, y)
			if not _is_blocking_char(ch):
				continue
			var rect := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
			var closest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
			if closest.distance_squared_to(pos) < radius * radius:
				return true
	return false

func _move_with_blockers(pos: Vector2, delta_pos: Vector2, radius: float) -> Vector2:
	var result := pos
	var try_x := Vector2(pos.x + delta_pos.x, pos.y)
	if not _circle_hits_blocker(try_x, radius):
		result.x = try_x.x
	var try_y := Vector2(result.x, pos.y + delta_pos.y)
	if not _circle_hits_blocker(try_y, radius):
		result.y = try_y.y
	return result
func _nearest_walkable_position(pos: Vector2, radius: float) -> Vector2:
	var origin_x := int(floor(pos.x / TILE))
	var origin_y := int(floor(pos.y / TILE))
	for ring in range(0, 6):
		for y in range(origin_y - ring, origin_y + ring + 1):
			for x in range(origin_x - ring, origin_x + ring + 1):
				if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H:
					continue
				if ring > 0 and x > origin_x - ring and x < origin_x + ring and y > origin_y - ring and y < origin_y + ring:
					continue
				var candidate := _tile_center(x, y)
				if not _circle_hits_blocker(candidate, radius):
					return candidate
	return Vector2(16.0 * TILE, 32.0 * TILE)


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

	# Fortified relay puzzle and boss-progression reward.
	if not puzzle_complete:
		draw_circle(PUZZLE_CENTER, 150, Color(0.18, 0.18, 0.20, 0.28))
		draw_circle(PUZZLE_CENTER, 58, Color("#343943"))
		draw_circle(RELAY_RED, 38, Color("#b83a32"))
		draw_circle(RELAY_BLUE, 38, Color("#3f6fa6"))
		draw_circle(RELAY_YELLOW, 38, Color("#d7ae35"))
		_label(PUZZLE_CENTER + Vector2(-130,-95), "FORTIFIED RELAY", 22, Color("#fff0c5"))
		_label(PUZZLE_CENTER + Vector2(-160,-65), "R > B > Y > R", 22, Color("#f3df9f"))
		if puzzle_started:
			_label(PUZZLE_CENTER + Vector2(-130,105), "STEP %d / 4" % puzzle_step, 20, Color.WHITE)
	else:
		draw_circle(PUZZLE_CENTER, 54, Color(0.20, 0.75, 0.42, 0.45))
		_label(PUZZLE_CENTER + Vector2(-122,-72), "CORE RECOVERED", 22, Color("#d8ffdf"))

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
