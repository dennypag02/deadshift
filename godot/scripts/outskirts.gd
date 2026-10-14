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
const RELAY_RED := Vector2(10.5 * TILE, 16.5 * TILE)
const RELAY_YELLOW := Vector2(12.5 * TILE, 31.5 * TILE)
const RELAY_BLUE := Vector2(26.5 * TILE, 18.5 * TILE)
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
var player_max_hp := 100
var player_armor := 0
var score := 0
var kills := 0
var wave := 1
var fire_period := BASE_FIRE_PERIOD
var player_speed := BASE_PLAYER_SPEED
var bullet_damage := 1
var juice_fx: Node2D
var progression: Node2D
var phase_ui: Control
var shake_enabled := true
var vibration_enabled := true
var recoil_vector := Vector2.ZERO
var last_aim := Vector2.RIGHT
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
var trap_active := false
var trap_color := ""
var trap_clock := 0.0
var trap_switches := 0
var trap_guard_kills := 0
var trap_required_kills := 0
var blue_switch_a := false
var blue_switch_b := false
var trap_finished: Array[String] = []

var camera: Camera2D
var hud: Label
var banner: Label
var upgrade_panel: Panel
var upgrade_title: Label
var rng := RandomNumberGenerator.new()
var generated_map_rows: Array[String] = []
var generated_cars: Array[Dictionary] = []
var capture_mode := false
var capture_clock := 0.0
var opening_spawn_remaining := 0
var opening_spawn_clock := 0.0
var wave_clock := 0.0
var break_clock := 0.0
var final_surge_started := false
var next_enemy_uid := 1
var damage_numbers_enabled := true
var capture_enemy_integral := 0.0
var capture_enemy_sample_time := 0.0
var capture_enemy_max := 0

func _ready() -> void:
	capture_mode = OS.get_cmdline_user_args().has("--pacing-capture")
	if capture_mode:
		rng.seed = 20261014
	else:
		rng.randomize()
	_generate_outskirts_layout()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_pumps()
	_setup_objectives()
	_setup_camera()
	_setup_ui()
	if capture_mode and phase_ui != null:
		phase_ui.god_mode = true
	_start_wave(1)
	if capture_mode:
		print("PACING_CAPTURE_READY")

func _generate_outskirts_layout() -> void:
	generated_map_rows = MAP_ROWS.duplicate()
	generated_cars.clear()
	var car_sites: Array[Vector2i] = [Vector2i(19,6), Vector2i(1,14), Vector2i(4,14), Vector2i(21,17), Vector2i(11,23), Vector2i(17,25), Vector2i(1,27), Vector2i(6,27), Vector2i(12,28), Vector2i(6,34), Vector2i(27,34), Vector2i(9,36), Vector2i(24,37)]
	for site in car_sites:
		for dx in range(2):
			_set_generated_tile(site.x + dx, site.y, ".")
	for site in car_sites:
		var candidates: Array[Vector2i] = []
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var candidate: Vector2i = site + Vector2i(dx, dy)
				if _can_place_generated_car(candidate):
					candidates.append(candidate)
		var chosen: Vector2i = site
		if not candidates.is_empty():
			chosen = candidates[rng.randi_range(0, candidates.size() - 1)]
		_set_generated_tile(chosen.x, chosen.y, "C")
		_set_generated_tile(chosen.x + 1, chosen.y, "C")
		generated_cars.append({"tile": chosen, "suv": rng.randf() < 0.5})
	for i in range(175):
		var x := rng.randi_range(1, MAP_W - 2)
		var y := rng.randi_range(4, MAP_H - 5)
		var at := Vector2(float(x) + 0.5, float(y) + 0.5) * TILE
		if at.distance_to(PLAYER_START) < 350.0 or at.distance_to(PUZZLE_CENTER) < 430.0 or at.distance_to(GENERATOR_POS) < 250.0:
			continue
		var ch := _tile_char(x, y)
		if ch == "." or ch == "x" or ch == "o" or ch == ":":
			var roll := rng.randf()
			_set_generated_tile(x, y, "x" if roll < 0.42 else ("o" if roll < 0.65 else ("." if roll < 0.85 else ":")))

func _set_generated_tile(x: int, y: int, ch: String) -> void:
	if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H:
		return
	var line := generated_map_rows[y]
	generated_map_rows[y] = line.substr(0, x) + ch + line.substr(x + 1)

func _can_place_generated_car(tile: Vector2i) -> bool:
	if tile.x < 1 or tile.x + 1 >= MAP_W - 1 or tile.y < 4 or tile.y >= MAP_H - 3:
		return false
	for dx in range(2):
		var ch := _tile_char(tile.x + dx, tile.y)
		if ch != "." and ch != "x" and ch != "o" and ch != ":":
			return false
		var pos := _tile_center(tile.x + dx, tile.y)
		for objective in [PLAYER_START, GENERATOR_POS, SUPPLY_DINER, SUPPLY_AUTOSHOP, SUPPLY_MOTEL, NEST_WEST, NEST_EAST, NEST_NW, NEST_NE, PUZZLE_CENTER, RELAY_RED, RELAY_BLUE, RELAY_YELLOW]:
			if pos.distance_to(objective) < 200.0:
				return false
	return true

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
	bar.color = Color(0.04, 0.04, 0.04, 0.0)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(432, 118)
	ui.add_child(bar)

	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 20)
	ui.add_child(hud)
	hud.visible = false

	banner = Label.new()
	banner.position = Vector2(18, 128)
	banner.size = Vector2(396, 84)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 18)
	ui.add_child(banner)
	banner.visible = false

	var tactical_map := Control.new()
	tactical_map.set_script(load("res://scripts/tactical_minimap.gd"))
	tactical_map.set("game", self)
	tactical_map.position = Vector2(310, 12)
	tactical_map.size = Vector2(110, 112)
	ui.add_child(tactical_map)

	var polish_hud := Control.new()
	polish_hud.set_script(load("res://scripts/polish_hud.gd"))
	polish_hud.set("game", self)
	ui.add_child(polish_hud)
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/juice_fx.gd"))
	fx.set("game", self)
	add_child(fx)
	juice_fx = fx
	var prog := Node2D.new()
	prog.set_script(load("res://scripts/phase_a_progression.gd"))
	prog.set("game", self)
	add_child(prog)
	progression = prog
	var phase_overlay := Control.new()
	phase_overlay.set_script(load("res://scripts/phase_a_ui.gd"))
	phase_overlay.set("game", self)
	phase_overlay.set("progression", prog)
	ui.add_child(phase_overlay)
	phase_ui = phase_overlay

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
	if capture_mode:
		print("PACING_WAVE wave=%d t=%.2f" % [wave, capture_clock])
	if wave > 10:
		return
	wave_active = true
	wave_clock = 0.0
	break_clock = 0.0
	final_surge_started = false
	wave_spawned = 0
	runners_spawned = 0
	trucker_spawned = false
	var plan: Dictionary = wave_plan[wave]
	wave_total = int(plan["shamblers"]) + int(plan["runners"]) + int(plan["trucker"])
	spawn_clock = 0.0
	_reset_pumps()
	if progression != null:
		var pacing_cfg: Dictionary = progression.config.get("pacing", {})
		var start_groups := int(pacing_cfg.get("wave1_start_groups", 2)) if wave == 1 else int(pacing_cfg.get("later_wave_start_groups", 3))
		var start_group_size := int(pacing_cfg.get("wave_start_group_size", 10))
		for _group in range(start_groups):
			_spawn_pressure_group(start_group_size)
	if wave == 10:
		tanker_event = true
		fire_hazard = true
		banner.text = "WAVE 10: TANKER DOWN!\nTRUCKER INCOMING - SURVIVE!"
	elif wave == 2:
		banner.text = "WAVE 2: PRESSURE RISING"
	else:
		banner.text = "WAVE 1: THE HORDE IS HERE\nPOWER THE MINI-MART GENERATOR"
	_update_hud()

func _finish_wave() -> void:
	wave_active = false
	if progression != null:
		progression.vacuum_all_gems()
	if wave == 1:
		break_clock = float(progression.config.get("pacing", {}).get("break_seconds", 8.0)) if progression != null else 8.0
		banner.text = "WAVE 1 CLEARED - NEXT WAVE IN %.0f" % break_clock
		if capture_mode:
			print("PACING_WAVE_END wave=1 t=%.2f remaining=%d" % [capture_clock, enemies.size()])
		return
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
	if capture_mode:
		capture_clock += delta
		direction = Vector2(cos(capture_clock * 0.31), sin(capture_clock * 0.47)).normalized()
	elif touch_active:
		direction = (touch_position - touch_origin).limit_length(90.0) / 90.0
	if not capture_mode:
		direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction = direction.limit_length(1.0)
	if capture_mode:
		var on_screen := _onscreen_enemy_count()
		if wave_active:
			capture_enemy_integral += float(on_screen) * delta
			capture_enemy_sample_time += delta
		capture_enemy_max = maxi(capture_enemy_max, on_screen)
		if capture_clock >= 120.0:
			var avg_enemies := capture_enemy_integral / maxf(0.001, capture_enemy_sample_time)
			var xp_drop: int = progression.xp_dropped_total if progression != null else 0
			var xp_collect: int = progression.xp_collected_total if progression != null else 0
			print("PACING_SUMMARY enemies_avg=%.2f enemies_max=%d xp_dropped=%d xp_collected=%d" % [avg_enemies, capture_enemy_max, xp_drop, xp_collect])
			print("PACING_CAPTURE_COMPLETE t=%.2f wave=%d level=%d kills=%d" % [capture_clock, wave, progression.level if progression != null else 1, kills])
			get_tree().quit()
			return

	if not wave_active and break_clock > 0.0:
		break_clock = maxf(0.0, break_clock - delta)
		if progression != null:
			progression.vacuum_all_gems()
		if break_clock <= 0.0 and wave == 1:
			_start_wave(2)

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
		wave_clock += delta
		var pacing: Dictionary = progression.config.get("pacing", {}) if progression != null else {}
		var active_target := _active_horde_target()
		spawn_clock -= delta
		if wave == 1 and wave_clock >= float(pacing.get("wave1_duration_seconds", 60.0)):
			if not final_surge_started:
				final_surge_started = true
				_spawn_pressure_group(int(pacing.get("final_surge_size", 10)))
			elif enemies.is_empty():
				_finish_wave()
		elif spawn_clock <= 0.0 and _onscreen_enemy_count() < active_target and enemies.size() < int(progression.config.get("limits", {}).get("active_enemies", 250)):
			_spawn_pressure_group()
			spawn_clock = float(pacing.get("spawn_interval_seconds", 0.75))
		elif wave > 1 and wave_spawned >= wave_total and enemies.is_empty():
			_finish_wave()

	fire_clock -= delta
	if fire_clock <= 0.0 and not enemies.is_empty():
		var nearest := 0
		for i in range(1, enemies.size()):
			if player_pos.distance_squared_to(enemies[i]["pos"]) < player_pos.distance_squared_to(enemies[nearest]["pos"]):
				nearest = i
		var heading: Vector2 = (enemies[nearest]["pos"] - player_pos).normalized()
		var smg_level := int(progression.weapons.get("scrap_smg", 1)) if progression != null else 1
		var ammo_bonus: int = progression.ammo_bonus() if progression != null else 0
		var smg_burst := 1
		if smg_level >= 2:
			smg_burst += maxi(1, roundi(progression.weapon_step_mult("scrap_smg", 2)))
		if smg_level >= 5:
			smg_burst += maxi(1, roundi(progression.weapon_step_mult("scrap_smg", 5)))
		var shot_count: int = smg_burst + ammo_bonus
		var smg_hits := 1 + (maxi(1, roundi(progression.weapon_step_mult("scrap_smg", 4))) if smg_level >= 4 else 0)
		var smg_damage_mult: float = 1.0 + (0.25 * progression.weapon_step_mult("scrap_smg", 5) if smg_level >= 5 else 0.0)
		for shot in range(shot_count):
			var spread := (float(shot) - float(shot_count - 1) * 0.5) * 0.12
			if progression == null or bullets.size() < int(progression.config.get("limits", {}).get("projectiles", 400)):
				bullets.append({"pos": player_pos, "dir": heading.rotated(spread), "life": 1.6, "hits_left": smg_hits, "damage_mult": smg_damage_mult, "knockback": 0.0})
		if progression != null and progression.weapons.has("boomstick"):
			var boom_level := int(progression.weapons["boomstick"])
			var boom_data: Dictionary = progression.config["weapons"]["boomstick"]
			var pellet_count: int = int(boom_data.get("base_pellets", 3)) + ammo_bonus
			if boom_level >= 2:
				pellet_count += maxi(1, roundi(2.0 * progression.weapon_step_mult("boomstick", 2)))
			if boom_level >= 5:
				pellet_count += maxi(1, roundi(2.0 * progression.weapon_step_mult("boomstick", 5)))
			var boom_damage_mult: float = 1.0 + (0.20 * progression.weapon_step_mult("boomstick", 3) if boom_level >= 3 else 0.0)
			var cone_step := float(boom_data.get("base_cone_step", 0.14)) * (1.30 if boom_level >= 4 else 1.0)
			var boom_knockback := float(boom_data.get("base_knockback", 36.0)) * (2.0 if boom_level >= 5 else 1.0)
			for pellet in range(pellet_count):
				var angle := (float(pellet) - float(pellet_count-1)*0.5) * cone_step
				if progression == null or bullets.size() < int(progression.config.get("limits", {}).get("projectiles", 400)):
					bullets.append({"pos": player_pos, "dir": heading.rotated(angle), "life": 0.48, "hits_left": 1, "damage_mult": boom_damage_mult, "knockback": boom_knockback})
		if juice_fx != null:
			juice_fx.call("shot", player_pos, heading)
			recoil_vector = -heading * 3.0
			last_aim = heading
		var trigger_bonus: float = progression.attack_speed_multiplier() if progression != null else 1.0
		var smg_rate_bonus: float = 1.0 + (0.20 * progression.weapon_step_mult("scrap_smg", 3) if smg_level >= 3 else 0.0)
		var smg_base_period := float(progression.config["weapons"]["scrap_smg"].get("base_fire_period", fire_period)) if progression != null else fire_period
		fire_clock = smg_base_period / (trigger_bonus * smg_rate_bonus)

	_update_bullets(delta)
	_update_enemies(delta)
	_update_health(delta)
	_update_objectives(delta)
	_update_puzzle(delta)
	_update_hud()
	queue_redraw()

func _active_horde_target() -> int:
	if progression == null:
		return 20
	var pacing: Dictionary = progression.config.get("pacing", {})
	var start_target := int(pacing.get("pressure_start", 20))
	var end_target := int(pacing.get("pressure_at_60s", 40))
	var later_bonus := int(pacing.get("pressure_per_later_wave", 6)) * maxi(0, wave - 1)
	var t := clampf(wave_clock / 60.0, 0.0, 1.0)
	var target := roundi(lerpf(float(start_target), float(end_target), t)) + later_bonus
	return mini(int(progression.config.get("limits", {}).get("active_enemies", 250)), target)

func _camera_half_extents() -> Vector2:
	var view := get_viewport_rect().size
	var zoom := camera.zoom if camera != null else Vector2.ONE
	return Vector2(view.x / maxf(0.01, 2.0 * zoom.x), view.y / maxf(0.01, 2.0 * zoom.y))

func _is_position_on_screen(pos: Vector2) -> bool:
	var half := _camera_half_extents()
	var offset := pos - player_pos
	return absf(offset.x) <= half.x and absf(offset.y) <= half.y

func _onscreen_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if _is_position_on_screen(Vector2(enemy["pos"])):
			count += 1
	return count

func _spawn_position_outside_view(angle: float) -> Vector2:
	var pacing: Dictionary = progression.config.get("pacing", {}) if progression != null else {}
	var half := _camera_half_extents()
	var direction := Vector2.from_angle(angle)
	var x_edge := half.x / maxf(0.001, absf(direction.x))
	var y_edge := half.y / maxf(0.001, absf(direction.y))
	var edge_distance := minf(x_edge, y_edge)
	var margin := float(pacing.get("spawn_margin", 180.0))
	var jitter := float(pacing.get("spawn_jitter", 80.0))
	var distance := edge_distance + margin + rng.randf_range(0.0, jitter)
	var pos := player_pos + direction * distance
	return Vector2(
		clampf(pos.x, 45.0, MAP_SIZE.x - 45.0),
		clampf(pos.y, 45.0, MAP_SIZE.y - 45.0)
	)

func _next_uid() -> int:
	var value := next_enemy_uid
	next_enemy_uid += 1
	return value

func _enemy_stats(kind: String) -> Dictionary:
	var hp_scale := 1.0
	if progression != null:
		var hp_per_wave := float(progression.config.get("difficulty", {}).get("enemy_hp_per_wave", 0.12))
		hp_scale += hp_per_wave * float(wave)
	if kind == "runner":
		return {"hp": 2.0 * hp_scale, "speed": 195.0, "radius": 15.0}
	if kind == "trucker":
		return {"hp": 30.0 * hp_scale, "speed": 46.0, "radius": 34.0}
	return {"hp": 1.0 * hp_scale, "speed": 108.0, "radius": 18.0}

func _append_enemy(kind: String, pos: Vector2) -> void:
	var stats := _enemy_stats(kind)
	enemies.append({
		"uid": _next_uid(),
		"pos": pos,
		"kind": kind,
		"hp": float(stats["hp"]),
		"speed": float(stats["speed"]),
		"radius": float(stats["radius"]),
		"charge": 0.0,
	})

func _pressure_kind() -> String:
	if wave == 1:
		return "runner" if rng.randf() < 0.08 else "shambler"
	if wave >= 2 and rng.randf() < minf(0.30, 0.10 + float(wave) * 0.025):
		return "runner"
	return "shambler"

func _spawn_pressure_group(forced_size: int = -1) -> void:
	if progression == null:
		return
	var pacing: Dictionary = progression.config.get("pacing", {})
	var group_size := forced_size if forced_size > 0 else rng.randi_range(int(pacing.get("spawn_group_min", 4)), int(pacing.get("spawn_group_max", 10)))
	var dir_count := rng.randi_range(int(pacing.get("spawn_directions_min", 2)), int(pacing.get("spawn_directions_max", 3)))
	var base_angle := rng.randf_range(0.0, TAU)
	var cap := int(progression.config.get("limits", {}).get("active_enemies", 250))
	for n in range(group_size):
		if enemies.size() >= cap:
			break
		if wave > 1 and wave_spawned >= wave_total:
			break
		var lane := n % maxi(1, dir_count)
		var angle := base_angle + TAU * float(lane) / float(maxi(1, dir_count)) + rng.randf_range(-0.20, 0.20)
		var pos := _spawn_position_outside_view(angle)
		pos = _nearest_walkable_position(pos, 18.0)
		_append_enemy(_pressure_kind(), pos)
		wave_spawned += 1

func _spawn_opening_shambler() -> void:
	_append_enemy("shambler", _nearest_walkable_position(player_pos + Vector2.RIGHT * 80.0, 18.0))
	wave_spawned += 1

func _spawn_next_enemy() -> void:
	var spawn := _nearest_walkable_position(_pick_spawn_point(), 18.0)
	_append_enemy(_pressure_kind(), spawn)
	wave_spawned += 1

func _pick_spawn_point() -> Vector2:
	if progression == null:
		return player_pos + Vector2.RIGHT * 720.0
	return _spawn_position_outside_view(rng.randf_range(0.0, TAU))

func _cap_impact_marks() -> void:
	if progression == null:
		return
	var cap := int(progression.config.get("limits", {}).get("impact_marks", 120))
	while impact_marks.size() > cap:
		impact_marks.pop_front()

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
				var bullet_mult := float(bullet.get("damage_mult", 1.0))
				var raw_damage: float = float(bullet_damage) * bullet_mult * (progression.damage_multiplier() if progression != null else 1.0)
				var crit: bool = progression.roll_crit() if progression != null else false
				var killed := phase_b_damage_enemy(j, raw_damage, crit, "bullet")
				if not killed and j < enemies.size() and str(enemies[j]["kind"]) == "trucker":
					enemies[j]["charge"] = 1.1
				var knockback := float(bullet.get("knockback", 0.0))
				if not killed and j < enemies.size():
					var live_enemy: Dictionary = enemies[j]
					if knockback > 0.0:
						var pushed := Vector2(live_enemy["pos"]) + Vector2(bullet["dir"]).normalized() * knockback
						live_enemy["pos"] = _move_with_blockers(Vector2(live_enemy["pos"]), pushed - Vector2(live_enemy["pos"]), float(live_enemy["radius"]))
					impact_marks.append({"pos": live_enemy["pos"], "life": 0.22})
					_cap_impact_marks()
					live_enemy["visual_hit"] = 0.06
					live_enemy["visual_dir"] = Vector2(bullet["dir"])
					if juice_fx != null:
						juice_fx.call("hit", Vector2(live_enemy["pos"]), Vector2(bullet["dir"]))
				var hits_left := int(bullet.get("hits_left", 1)) - 1
				bullet["hits_left"] = hits_left
				if hits_left <= 0:
					consumed = true
				else:
					bullet["pos"] += Vector2(bullet["dir"]).normalized() * (float(enemy["radius"]) * 2.0 + 18.0)
				break
		if consumed or float(bullet["life"]) <= 0.0:
			bullets.remove_at(i)

func _explode_pump(pump: Dictionary) -> void:
	pump["alive"] = false
	impact_marks.append({"pos": pump["pos"], "life": 0.55, "blast": true})
	_cap_impact_marks()
	var blast_kills := 0
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var distance: float = Vector2(enemy["pos"]).distance_to(Vector2(pump["pos"]))
		if distance <= PUMP_BLAST_RADIUS:
			var damage := 10 if str(enemy["kind"]) == "trucker" else 99
			enemy["hp"] = int(enemy["hp"]) - damage
			if int(enemy["hp"]) <= 0:
				blast_kills += 1
				_phase_a_kill_enemy(i)
	if juice_fx != null:
		juice_fx.call("explosion", Vector2(pump["pos"]), blast_kills)
	banner.text = "PUMP DETONATED!"

func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		enemy["visual_hit"] = maxf(0.0, float(enemy.get("visual_hit", 0.0)) - delta)
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
			var god_mode := phase_ui != null and bool(phase_ui.god_mode)
			if not god_mode and (progression == null or progression.invulnerability <= 0.0):
				var effective_damage := maxi(1, damage - player_armor)
				player_hp = maxi(0, player_hp - effective_damage)
			if vibration_enabled:
				Input.vibrate_handheld(30)
			enemies.remove_at(i)

func _update_health(delta: float) -> void:
	if health_available:
		if player_pos.distance_to(DINER_HEALTH_POS) < 58.0:
			player_hp = mini(player_max_hp, player_hp + 35)
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
	if trap_active:
		trap_clock = maxf(0.0, trap_clock - delta)
		if trap_color == "RED":
			if trap_clock <= 0.0:
				_finish_trap()
		elif trap_color == "BLUE":
			if not blue_switch_a and player_pos.distance_to(RELAY_BLUE + Vector2(-320, 0)) < 95.0:
				blue_switch_a = true
				trap_switches += 1
				banner.text = "BLUE SWITCH 1/2 ACTIVATED"
			if not blue_switch_b and player_pos.distance_to(RELAY_BLUE + Vector2(0, 350)) < 95.0:
				blue_switch_b = true
				trap_switches += 1
				banner.text = "BLUE SWITCH 2/2 ACTIVATED"
			if trap_clock <= 0.0 and trap_switches >= 2:
				_finish_trap()
		elif trap_color == "YELLOW":
			if trap_guard_kills >= trap_required_kills:
				_finish_trap()
		return
	if puzzle_complete or puzzle_pad_lock > 0.0:
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
	puzzle_pad_lock = 1.2
	var expected := str(PUZZLE_CODE[puzzle_step])
	if touched != expected:
		banner.text = "RELAY ORDER: RED > BLUE > YELLOW > RED"
		return
	if trap_finished.has(touched):
		_complete_relay_step()
		return
	_start_trap(touched)

func _start_trap(color: String) -> void:
	trap_active = true
	trap_color = color
	trap_clock = 16.0 if color == "RED" else (12.0 if color == "BLUE" else 0.0)
	trap_switches = 0
	blue_switch_a = false
	blue_switch_b = false
	trap_guard_kills = 0
	trap_required_kills = 12 if color == "YELLOW" else 0
	var center := _relay_position(color)
	var shambler_count := 20 if color == "RED" else (8 if color == "BLUE" else 12)
	var runner_count := 12 if color == "RED" else (16 if color == "BLUE" else 8)
	for i in range(shambler_count + runner_count):
		var angle := TAU * float(i) / float(shambler_count + runner_count)
		var candidate := center + Vector2.RIGHT.rotated(angle) * rng.randf_range(290.0, 460.0)
		var is_runner := i >= shambler_count
		var spawn := _nearest_walkable_position(candidate, 15.0 if is_runner else 18.0)
		enemies.append({"pos": spawn, "kind": "runner" if is_runner else "shambler", "hp": 2 if is_runner else 1, "speed": 205.0 if is_runner else 108.0, "radius": 15.0 if is_runner else 18.0, "charge": 0.0, "trap_guard": color})
	if color == "RED":
		banner.text = "RED AMBUSH! SURVIVE 16 SECONDS"
	elif color == "BLUE":
		banner.text = "BLUE LOCKDOWN! ACTIVATE 2 SWITCHES"
	else:
		banner.text = "YELLOW GUARDIAN! ELIMINATE 12 GUARDS"

func _relay_position(color: String) -> Vector2:
	if color == "RED":
		return RELAY_RED
	if color == "BLUE":
		return RELAY_BLUE
	return RELAY_YELLOW

func _finish_trap() -> void:
	trap_active = false
	if not trap_finished.has(trap_color):
		trap_finished.append(trap_color)
	player_hp = mini(100, player_hp + 12)
	score += 600
	banner.text = "%s TRAP CLEARED! +12 HP" % trap_color
	_complete_relay_step()

func _complete_relay_step() -> void:
	puzzle_step += 1
	score += 250
	puzzle_pad_lock = 2.0
	if puzzle_step >= PUZZLE_CODE.size():
		puzzle_complete = true
		detonator_core = true
		score += 2500
		impact_marks.append({"pos": PUZZLE_CENTER, "life": 0.75, "blast": true})
		banner.text = "DETONATOR CORE SECURED! BOSS KEY ACQUIRED"
		_try_unlock_district()
	else:
		banner.text = "RELAY %d/4 CLEARED - FIND NEXT SIGNAL" % puzzle_step

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
			_phase_a_kill_enemy(i)

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

	# Approved wreck art follows procedurally placed collision footprints.
	for car in generated_cars:
		var tile: Vector2i = car["tile"]
		_draw_art_rect(CAR_SUV_ART if car["suv"] else CAR_SEDAN_ART, _tiles_rect(tile.x, tile.y, 2, 1))

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
	return generated_map_rows[y].substr(x, 1) if not generated_map_rows.is_empty() else MAP_ROWS[y].substr(x, 1)

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
		_marker_icon(GENERATOR_POS, "bolt", Color("#F2A23A"))

	# Supply caches.
	for cache in supply_caches:
		if not bool(cache["collected"]):
			var p := Vector2(cache["pos"])
			draw_rect(Rect2(p - Vector2(24, 18), Vector2(48, 36)), Color("#4b8f61"))
			draw_rect(Rect2(p - Vector2(30, 24), Vector2(60, 48)), Color(0.6, 1.0, 0.7, 0.25), false, 5.0)
			_marker_icon(p, "crate", Color("#6FBF4A"))

	# Infestation nests: dangerous red targets at the perimeter.
	for nest in infestation_nests:
		if not bool(nest["destroyed"]):
			var p := Vector2(nest["pos"])
			draw_circle(p, 42, Color(0.55, 0.08, 0.05, 0.55))
			draw_circle(p, 24, Color("#7f1d18"))
			for a in range(0, 8):
				var angle := float(a) * TAU / 8.0
				draw_line(p + Vector2.RIGHT.rotated(angle) * 22.0, p + Vector2.RIGHT.rotated(angle) * 54.0, Color("#a83a2f"), 7.0)
			_marker_icon(p, "nest", Color("#B1375E"))

	# Three distant ambush sites. All markers use the original relay colors.
	if not puzzle_complete:
		for color in ["RED", "BLUE", "YELLOW"]:
			var pos := _relay_position(color)
			var tint := Color("#b83a32") if color == "RED" else (Color("#3f6fa6") if color == "BLUE" else Color("#d7ae35"))
			draw_circle(pos, 72, Color(tint.r, tint.g, tint.b, 0.20))
			draw_circle(pos, 38, tint)
			_marker_icon(pos, "trap", tint)
			if trap_finished.has(color):
				draw_arc(pos, 52.0, 0.0, TAU, 24, Color("#6FBF4A"), 6.0)
		if trap_active and trap_color == "BLUE":
			for switch_pos in [RELAY_BLUE + Vector2(-320, 0), RELAY_BLUE + Vector2(0, 350)]:
				draw_circle(switch_pos, 32, Color("#6cefff"))
		if trap_active:
			_draw_trap_countdown(_relay_position(trap_color))
		_marker_icon(PUZZLE_CENTER, "core", Color("#F2A23A"))
		
	else:
		draw_circle(PUZZLE_CENTER, 54, Color(0.20, 0.75, 0.42, 0.45))
		_marker_icon(PUZZLE_CENTER, "core", Color("#6FBF4A"))

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
		var flash_clock: float = float(enemy.get("visual_hit", 0.0))
		if flash_clock > 0.0:
			p += Vector2(enemy.get("visual_dir", Vector2.ZERO)) * 25.0 * (flash_clock / 0.06)
		var kind := str(enemy["kind"])
		var radius := float(enemy["radius"])
		if kind == "trucker":
			draw_circle(p + Vector2(6,12), radius + 10, Color(0.05,0.05,0.05,0.55))
			draw_circle(p, radius, Color("#7e392f"))
			
		elif kind == "runner":
			draw_circle(p, radius + 3, Color("#c98744"))
			draw_texture_rect(ZOMBIE_ART, Rect2(p - Vector2(23,23), Vector2(46,46)), false)
		else:
			draw_texture_rect(ZOMBIE_ART, Rect2(p - Vector2(25,25), Vector2(50,50)), false)
		if flash_clock > 0.0:
			draw_circle(p, radius + 5.0, Color(1,1,1,0.7 * flash_clock / 0.06))

	for bullet in bullets:
		draw_line(bullet["pos"] - bullet["dir"] * 22.0, bullet["pos"], Color("#F2A23A", 0.45), 7.0)
		draw_line(bullet["pos"] - bullet["dir"] * 22.0, bullet["pos"], Color("#fff2b8"), 4.0)
		draw_circle(bullet["pos"], BULLET_RADIUS, Color("#fff2b8"))

	for mark in impact_marks:
		var life := float(mark["life"])
		var is_blast := bool(mark.get("blast", false))
		var radius := 28.0 if not is_blast else 115.0 * clampf(life / 0.55, 0.2, 1.0)
		draw_circle(mark["pos"], radius, Color(1.0,0.35,0.08,0.42 if is_blast else 0.55))

	draw_circle(player_pos + Vector2(6,14), 35, Color(0.02,0.02,0.02,0.58))
	recoil_vector = recoil_vector.move_toward(Vector2.ZERO, 120.0 * get_physics_process_delta_time())
	var bounce := sin(float(Time.get_ticks_msec()) * TAU / 250.0) * 0.05 if player_velocity.length() > 40.0 else 0.0
	var visual_scale := Vector2(1.0, 0.99 + bounce)
	draw_texture_rect(SURVIVOR_ART, Rect2(player_pos + recoil_vector - Vector2(48,48) * visual_scale, Vector2(96,96) * visual_scale), false, Color.WHITE)

func _draw_dusk() -> void:
	if wave < 7:
		return
	var dusk := clampf(float(wave - 6) / 4.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.12,0.10,0.22,0.10 + dusk * 0.24))

func _label(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _marker_icon(p: Vector2, kind: String, tint: Color) -> void:
	draw_circle(p, 52.0, Color(tint.r, tint.g, tint.b, 0.16))
	draw_arc(p, 43.0, 0.0, TAU, 28, tint, 5.0)
	if kind == "bolt":
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6,-28), p + Vector2(12,-28), p + Vector2(0,-5), p + Vector2(16,-5), p + Vector2(-12,30), p + Vector2(-4,4), p + Vector2(-18,4)]), tint)
	elif kind == "crate":
		draw_rect(Rect2(p - Vector2(19,15), Vector2(38,30)), tint)
		draw_line(p + Vector2(-19,-15), p + Vector2(19,15), Color("#14110F"), 4.0)
		draw_line(p + Vector2(19,-15), p + Vector2(-19,15), Color("#14110F"), 4.0)
	elif kind == "nest":
		draw_circle(p, 23.0, Color("#5E1B40"))
		draw_circle(p + Vector2(-9,-5), 5.0, Color("#F2E8D8"))
		draw_circle(p + Vector2(9,-5), 5.0, Color("#F2E8D8"))
		draw_line(p + Vector2(-10,12), p + Vector2(10,12), Color("#F2E8D8"), 5.0)
	elif kind == "trap":
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			draw_arc(p, 58.0, angle, angle + 0.34, 5, Color("#14110F"), 10.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0,-21), p + Vector2(22,19), p + Vector2(-22,19)]), tint)
		draw_circle(p + Vector2(0,6), 3.0, Color("#14110F"))
	else:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0,-24), p + Vector2(23,0), p + Vector2(0,24), p + Vector2(-23,0)]), tint)

func _draw_trap_countdown(p: Vector2) -> void:
	var remaining := maxf(0.0, trap_clock)
	var total := 16.0 if trap_color == "RED" else 12.0
	if trap_color == "YELLOW":
		total = float(maxi(1, trap_required_kills))
		remaining = float(maxi(0, trap_required_kills - trap_guard_kills))
	draw_arc(p, 72.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(remaining / total, 0.0, 1.0), 40, Color("#F2A23A"), 8.0)
	_label(p + Vector2(-15, 8), str(ceili(remaining)), 26, Color("#F2E8D8"))

func phase_b_damage_enemy(index: int, raw_damage: float, crit: bool, source: String) -> bool:
	if index < 0 or index >= enemies.size():
		return false
	var enemy: Dictionary = enemies[index]
	if not enemy.has("uid"):
		enemy["uid"] = _next_uid()
	var actual: float = raw_damage * (progression.crit_multiplier() if crit and progression != null else 1.0)
	enemy["hp"] = float(enemy["hp"]) - actual
	if juice_fx != null and damage_numbers_enabled:
		juice_fx.call("damage_number", int(enemy["uid"]), Vector2(enemy["pos"]), actual, crit)
	if float(enemy["hp"]) <= 0.0:
		_phase_a_kill_enemy(index)
		return true
	return false

func _phase_a_kill_enemy(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var kind := str(enemy["kind"])
	if progression != null:
		progression.drop_xp(Vector2(enemy["pos"]), kind)
	kills += 1
	if trap_active and str(enemy.get("trap_guard", "")) == "YELLOW":
		trap_guard_kills += 1
	var points := 500 if kind == "trucker" else 100
	score += points
	if juice_fx != null:
		juice_fx.call("kill", Vector2(enemy["pos"]), points)
	enemies.remove_at(index)

func phase_a_resume_shockwave() -> void:
	var radius := 260.0
	var push := 145.0
	impact_marks.append({"pos": player_pos, "life": 0.45, "blast": true})
	_cap_impact_marks()
	for enemy in enemies:
		var enemy_pos := Vector2(enemy["pos"])
		var offset := enemy_pos - player_pos
		if offset.length() <= radius:
			var direction := offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT
			enemy["pos"] = _move_with_blockers(enemy_pos, direction * push, float(enemy["radius"]))
	queue_redraw()

func phase_a_debug_six_shambler_kills() -> void:
	if progression == null:
		return
	progression.level = 1
	progression.xp = 0
	progression.pending_levels = 0
	progression.choosing = false
	progression.gems.clear()
	for i in range(6):
		enemies.append({"pos": player_pos + Vector2(10.0 * float(i % 3), 10.0 * float(i / 3)), "kind":"shambler", "hp":1, "speed":0.0, "radius":18.0, "charge":0.0})
		_phase_a_kill_enemy(enemies.size() - 1)
