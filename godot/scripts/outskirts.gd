extends Node2D

const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const ObjectiveGuidance = preload("res://scripts/objective_guidance.gd")
var actors: Node2D
var guidance: Node2D
var tactical_map: Control
var telemetry: Node
var events: Node2D
var run_log: Node
var hud_overlay: Control
var terrain_batches: Node2D
var transient_pool = preload("res://scripts/record_pool.gd").new()
var enemy_grid: Dictionary = {}
var grid_dirty := true
var route_cells: Array[Vector2i] = []

const TILE := 128.0
const MAP_W := 32
const MAP_H := 40
const MAP_SIZE := Vector2(MAP_W * TILE, MAP_H * TILE)

const SURVIVOR_ART := preload("res://art/survivor_wasteland.svg")
const ZOMBIE_ART := preload("res://art/zombie_shambler.svg")
var curated_pickup_textures: Dictionary = {}
const CAR_SEDAN_ART := preload("res://art/cars/car_sedan.png")
const CAR_SUV_ART := preload("res://art/cars/car_suv.png")
const OUT_DINER_ART := preload("res://art/outskirts/out_diner.svg")
const OUT_MINIMART_ART := preload("res://art/outskirts/out_minimart.svg")
const OUT_MOTEL_N_ART := preload("res://art/outskirts/out_motel_north.svg")
const OUT_MOTEL_E_ART := preload("res://art/outskirts/out_motel_east.svg")
const OUT_AUTOSHOP_ART := preload("res://art/outskirts/out_autoshop.svg")
const OUT_CANOPY_ART := preload("res://art/outskirts/out_canopy.svg")
const OUT_SEMI_ART := preload("res://art/outskirts/out_semi_trailer.png")
const OUT_PUMP_ART := preload("res://art/outskirts/out_pump_island.png")
const OUT_BARRELS_ART := preload("res://art/outskirts/out_barrels.png")
const OUT_BARRIER_ART := preload("res://art/outskirts/out_barrier.svg")
const OUT_FENCE_ART := preload("res://art/outskirts/out_fence.png")
const OUT_TANKER_ART := preload("res://art/outskirts/out_tanker_wreck.png")
const TEX_FORECOURT := preload("res://art/outskirts/tex_forecourt.svg")
const TEX_ASPHALT := preload("res://art/outskirts/tex_asphalt.svg")
const TEX_HIGHWAY := preload("res://art/outskirts/tex_highway.svg")
const TEX_CRACKED := preload("res://art/outskirts/tex_cracked.svg")
const TEX_OIL := preload("res://art/outskirts/tex_oil.svg")
const TEX_GRAVEL := preload("res://art/outskirts/tex_gravel.svg")
const TEX_SCRUB := preload("res://art/outskirts/tex_scrub.svg")
const DECAL_CRACK_A := preload("res://art/decals/decal_crack_a.png")
const DECAL_CRACK_B := preload("res://art/decals/decal_crack_b.png")
const DECAL_GOO := preload("res://art/decals/decal_goo.png")
const DECAL_ACID := preload("res://art/decals/decal_acid.png")
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
var boomstick_fire_clock := 0.0
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
var objective_idle_clock := 0.0
var objective_hint_cooldown := 0.0
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
var android_diag_clock := 0.0
var player_hit_invulnerability := 0.0
var incoming_damage_window := 0.0
var incoming_damage_this_window := 0.0
var wave_damage_taken := 0
var wave_min_hp := 100
var elite_spawn_clock := 45.0
var powerups: Array[Dictionary] = []
var rage_clock := 0.0
var mega_clock := 0.0
var freeze_clock := 0.0
var spawn_group_index := 0
var run_clock := 0.0
var game_over_shown := false
var scrap_earned := 0
var capture_death_triggered := false

func _load_curated_art() -> void:
	var pickup_paths := {
		"Chest": "res://art/curated/icon_chest.png",
		"Medkit": "res://art/curated/icon_pickup_medkit.png",
		"Magnet": "res://art/curated/icon_pickup_magnet.png",
		"Rage": "res://art/curated/icon_pickup_rage.png",
		"Nuke": "res://art/curated/icon_pickup_nuke.png",
		"Freeze": "res://art/curated/icon_pickup_freeze.png",
	}
	for kind in pickup_paths:
		if ResourceLoader.exists(pickup_paths[kind]):
			curated_pickup_textures[kind] = load(pickup_paths[kind])

func _draw_curated_texture(texture: Texture2D, center: Vector2, footprint: Vector2, tint: Color = Color.WHITE) -> void:
	var dimensions := texture.get_size()
	if dimensions.x <= 0 or dimensions.y <= 0:
		return
	var size := dimensions * minf(footprint.x / dimensions.x, footprint.y / dimensions.y)
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, tint)

func _force_silent_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)
		AudioServer.set_bus_volume_db(master_bus, -80.0)

func _ready() -> void:
	_force_silent_audio()
	_load_curated_art()
	for kind in {"enemies":250,"bullets":400,"impact_marks":120,"stage1_hazards":64,"powerups":30}:
		transient_pool.warm(kind, {"enemies":250,"bullets":400,"impact_marks":120,"stage1_hazards":64,"powerups":30}[kind])
	capture_mode = OS.get_cmdline_user_args().has("--pacing-capture")
	if OS.get_environment("DEADSHIFT_VALIDATION_SEED") != "":
		rng.seed = int(OS.get_environment("DEADSHIFT_VALIDATION_SEED"))
	elif capture_mode:
		rng.seed = 20261014
	else:
		rng.randomize()
	_generate_outskirts_layout()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_pumps()
	_setup_objectives()
	_clear_objective_routes()
	terrain_batches = preload("res://scripts/terrain_batches.gd").new()
	terrain_batches.game = self
	add_child(terrain_batches)
	_setup_camera()
	_setup_ui()
	actors = ActorPresentation.new()
	actors.game = self
	add_child(actors)
	guidance = ObjectiveGuidance.new()
	guidance.game = self
	add_child(guidance)
	if capture_mode and phase_ui != null:
		phase_ui.god_mode = false
	run_log = preload("res://scripts/run_telemetry.gd").new()
	run_log.game = self
	add_child(run_log)
	events = preload("res://scripts/stage2_events.gd").new()
	events.game = self
	add_child(events)
	telemetry = preload("res://scripts/pacing_telemetry.gd").new()
	telemetry.game = self
	add_child(telemetry)
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

	tactical_map = Control.new()
	tactical_map.set_script(load("res://scripts/tactical_minimap.gd"))
	tactical_map.set("game", self)
	tactical_map.position = Vector2(310, 12)
	tactical_map.size = Vector2(110, 112)
	ui.add_child(tactical_map)

	var polish_hud := Control.new()
	hud_overlay = polish_hud
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
	RunState.wave_number = wave
	EventBus.wave_started.emit({"wave":wave})
	if telemetry != null: telemetry.event("wave_start",{"duration_s":_wave_duration(),"carried_enemies":enemies.size()})
	wave_damage_taken = 0
	wave_min_hp = player_hp
	stage1_damage_sources = {"contact": 0, "spitter": 0, "bloater": 0, "brute": 0, "explosion": 0}
	stage1_damage_dealt = 0.0
	stage1_wave_min_hp_pct = 100.0 * float(player_hp) / maxf(1.0, float(player_max_hp))
	stage1_enemy_integral = 0.0
	stage1_sample_seconds = 0.0
	stage1_enemy_max = 0
	stage1_surge_triggered = false
	elite_spawn_clock = 45.0
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
	if run_log != null: run_log.start_wave()
	if events != null: events.start_wave(wave)
	if progression != null:
		var pacing_cfg: Dictionary = progression.config.get("pacing", {})
		var start_groups := int(pacing_cfg.get("wave1_start_groups", 2)) if wave == 1 else int(pacing_cfg.get("later_wave_start_groups", 3))
		var start_group_size := roundi(float(pacing_cfg.get("wave_start_group_size", 10)) * (events.pressure_multiplier() if events != null else 1.0))
		for _group in range(start_groups):
			_spawn_pressure_group(start_group_size)
	if wave == 10:
		tanker_event = true
		fire_hazard = true
		banner.text = "FINAL STAND - 90 SECONDS\nSURVIVE WITH YOUR EARNED ARSENAL"
	elif events == null or events.active.is_empty():
		banner.text = "WAVE %d: THE HORDE IS HERE\nSURVIVE" % wave
	_update_hud()

func _wave_duration() -> float:
	if wave == 10 and events != null: return events.value("final_stand_seconds")
	var data: Dictionary = progression.config.get("pacing", {})
	return float(data.get("wave1_duration_seconds",60.0) if wave==1 else data.get("wave_duration_seconds",67.5))

func _tick_wave_clock(dt: float) -> void:
	if wave_active:
		wave_clock += dt
		if wave_clock >= _wave_duration():
			_finish_wave()
	elif break_clock > 0:
		break_clock = maxf(0,break_clock-dt)
		if break_clock<=0 and wave<10: _start_wave(wave+1)

func _finish_wave() -> void:
	if not wave_active: return
	wave_active = false
	if events != null and not events.active.is_empty(): events.resolve("missed", "wave_ended")
	if run_log != null: run_log.close_wave("completed")
	print("STAGE1_WAVE wave=%d min_hp_pct=%.1f damage=%s enemies_avg=%.1f enemies_max=%d dps=%.1f level=%d elapsed=%.1f" % [wave, stage1_wave_min_hp_pct, str(stage1_damage_sources), stage1_enemy_integral / maxf(0.01,stage1_sample_seconds), stage1_enemy_max, stage1_damage_dealt / maxf(0.01,wave_clock), progression.level, run_clock])
	if telemetry != null:
		telemetry.event("wave_end",{"duration_s":wave_clock,"remaining_enemies":enemies.size(),"level":progression.level})
	print("PACING_WAVE_END wave=%d t=%.2f duration=%.2f remaining=%d" % [wave,run_clock,wave_clock,enemies.size()])
	progression.vacuum_all_gems()
	if wave>=10:
		wave10_survived=true
		fire_hazard=false
		_try_unlock_district()
		if run_log != null: run_log.finish("final_stand_survived")
		return
	break_clock=0.0
	banner.text="WAVE %d CLEARED - CHOOSE A MUTATION" % wave
	MutationManager.begin_between_wave_offer(wave)

func _unhandled_input(event: InputEvent) -> void:
	if events != null and events.aiming: return
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

	player_hit_invulnerability = maxf(0.0, player_hit_invulnerability - delta)
	incoming_damage_window += delta
	if incoming_damage_window >= 1.0:
		incoming_damage_window = fmod(incoming_damage_window, 1.0)
		incoming_damage_this_window = 0.0
	if OS.get_name() == "Android":
		android_diag_clock += delta
		if android_diag_clock >= 5.0:
			android_diag_clock = 0.0
			var gem_count: int = progression.gems.size() if progression != null else 0
			var effect_count: int = 0
			if progression != null:
				effect_count = progression.rockets.size() + progression.chakrams.size() + progression.molotov_pools.size() + progression.lightning_arcs.size() + progression.drone_shots.size()
			print("ANDROID_RUNTIME fps=%d enemies=%d bullets=%d gems=%d effects=%d level=%d" % [Engine.get_frames_per_second(), enemies.size(), bullets.size(), gem_count, effect_count, progression.level if progression != null else 1])
	if player_hp <= 0:
		if capture_mode and not capture_death_triggered:
			print("STAGE1_CAPTURE_DEATH wave=%d t=%.1f level=%d" % [wave, run_clock, progression.level if progression != null else 1])
		if player_hp <= 0 and not game_over_shown:
			print("STAGE1_RUN_END death_wave=%d elapsed=%.1f min_hp_pct=%.1f damage=%s" % [wave, run_clock, 100.0 * float(wave_min_hp) / maxf(1.0, float(player_max_hp)), str(stage1_damage_sources)])
			game_over_shown = true
			if run_log != null: run_log.finish("death")
			if phase_ui != null:
				phase_ui.show_game_over(run_clock, wave, progression.level if progression != null else 1, kills, score, scrap_earned)
		if player_hp <= 0:
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
		if capture_clock >= 180.0 and not capture_death_triggered:
			capture_death_triggered = true
			var avg_enemies := capture_enemy_integral / maxf(0.001, capture_enemy_sample_time)
			var xp_drop: int = progression.xp_dropped_total if progression != null else 0
			var xp_collect: int = progression.xp_collected_total if progression != null else 0
			print("PACING_SUMMARY enemies_avg=%.2f enemies_max=%d xp_dropped=%d xp_collected=%d" % [avg_enemies, capture_enemy_max, xp_drop, xp_collect])
			print("STAGE1_WAVE wave=%d partial=true min_hp_pct=%.1f damage=%s enemies_avg=%.1f enemies_max=%d dps=%.1f level=%d elapsed=%.1f" % [wave, 100.0 * float(wave_min_hp) / maxf(1.0, float(player_max_hp)), str(stage1_damage_sources), stage1_enemy_integral / maxf(0.01, stage1_sample_seconds), stage1_enemy_max, stage1_damage_dealt / maxf(0.01, wave_clock), progression.level if progression != null else 1, run_clock])
			print("PACING_DAMAGE wave=%d damage_taken=%d min_hp=%d max_hp=%d min_hp_pct=%.1f partial=true" % [wave, wave_damage_taken, wave_min_hp, player_max_hp, 100.0 * float(wave_min_hp) / maxf(1.0, float(player_max_hp))])
			print("PACING_CAPTURE_COMPLETE t=%.2f wave=%d level=%d kills=%d" % [capture_clock, wave, progression.level if progression != null else 1, kills])
			if phase_ui != null:
				phase_ui.god_mode = false
			player_hp = 0
			return


	var hazard := _hazard_at(player_pos)
	var speed_mult := float(hazard["speed_mult"])
	for h in stage1_hazards:
		if str(h["kind"]) == "goo" and player_pos.distance_to(Vector2(h["pos"])) < float(h["radius"]):
			speed_mult *= 0.55
	if events != null: speed_mult *= events.movement_multiplier()
	var desired_velocity := direction * player_speed * speed_mult * (1.5 if rage_clock > 0.0 else 1.0)
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
			transient_pool.remove(impact_marks,i,"impact_marks")

	if wave_active:

		stage1_enemy_integral += float(_onscreen_enemy_count()) * delta
		stage1_sample_seconds += delta
		stage1_enemy_max = maxi(stage1_enemy_max, _onscreen_enemy_count())
		var wave_duration := _wave_duration()
		if not stage1_surge_triggered and wave_clock >= wave_duration - float(progression.config.get("pacing", {}).get("surge_last_seconds", 10.0)):
			stage1_surge_triggered = true
			_stage1_spawn_surge()
		var pacing: Dictionary = progression.config.get("pacing", {}) if progression != null else {}
		var active_target := _active_horde_target()
		spawn_clock -= delta
		if wave_clock < wave_duration and spawn_clock <= 0.0 and _onscreen_enemy_count() < active_target and enemies.size() < int(progression.config.get("limits", {}).get("active_enemies", 250)):
			var pressure_room := maxi(0, active_target - _onscreen_enemy_count())
			if pressure_room > 0:
				var group_cap := mini(int(pacing.get("spawn_group_max", 10)), pressure_room)
				_spawn_pressure_group(group_cap)
			spawn_clock = float(pacing.get("spawn_interval_seconds", 0.75))
		

	fire_clock -= delta
	boomstick_fire_clock -= delta
	var objective_aim: Dictionary = events.aim_target() if events != null else {}
	var has_targets := not enemies.is_empty() or not objective_aim.is_empty()
	var ammo_bonus: int = progression.ammo_bonus() if progression != null else 0
	var trigger_bonus: float = progression.attack_speed_multiplier() if progression != null else 1.0
	var rage_mult := 2.0 if rage_clock > 0.0 else 1.0
	var mega_mult := 3.0 if mega_clock > 0.0 else 1.0

	if has_targets and progression != null and progression.weapons.has("scrap_smg") and fire_clock <= 0.0:
		var nearest := 0
		for i in range(1, enemies.size()):
			if player_pos.distance_squared_to(enemies[i]["pos"]) < player_pos.distance_squared_to(enemies[nearest]["pos"]):
				nearest = i
		var aim_at: Vector2 = objective_aim["pos"] if not objective_aim.is_empty() else enemies[nearest]["pos"]
		if not enemies.is_empty() and player_pos.distance_to(enemies[nearest]["pos"]) < 150.0:
			aim_at = enemies[nearest]["pos"]
		var heading := (aim_at - player_pos).normalized()
		var smg_level := int(progression.weapons["scrap_smg"])
		var smg_burst := 1
		if smg_level >= 2:
			smg_burst += maxi(1, roundi(progression.weapon_step_mult("scrap_smg", 2)))
		if smg_level >= 5:
			smg_burst += maxi(1, roundi(progression.weapon_step_mult("scrap_smg", 5)))
		var shot_count: int = (maxi(12, smg_burst) if progression.evolutions.has("scrap_smg") else smg_burst) + ammo_bonus
		var smg_hits := 1 + (maxi(1, roundi(progression.weapon_step_mult("scrap_smg", 4))) if smg_level >= 4 else 0)
		var smg_damage_mult: float = float(progression.config["weapons"]["scrap_smg"].get("base_damage",1.0)) * (1.0 + (0.25 * progression.weapon_step_mult("scrap_smg", 5) if smg_level >= 5 else 0.0))
		for shot in range(shot_count):
			var spread := (TAU * float(shot) / float(shot_count) + run_clock * 2.0) if progression.evolutions.has("scrap_smg") else (float(shot) - float(shot_count - 1) * 0.5) * 0.12
			if projectile_count() < int(progression.config.get("limits", {}).get("projectiles", 400)):
				transient_pool.push(bullets,"bullets",{"weapon":"scrap_smg","pos": player_pos, "dir": heading.rotated(spread), "life": 1.6, "hits_left": smg_hits, "damage_mult": smg_damage_mult, "knockback": 0.0},400)
		if juice_fx != null:
			juice_fx.call("shot", player_pos, heading)
		last_aim = heading
		var smg_rate_bonus: float = 1.0 + (0.20 * progression.weapon_step_mult("scrap_smg", 3) if smg_level >= 3 else 0.0)
		var smg_base_period := float(progression.config["weapons"]["scrap_smg"].get("base_fire_period", fire_period))
		fire_clock = smg_base_period / (trigger_bonus * smg_rate_bonus * rage_mult * mega_mult)

	if has_targets and progression != null and progression.weapons.has("boomstick") and boomstick_fire_clock <= 0.0:
		var boom_level := int(progression.weapons["boomstick"])
		var boom_data: Dictionary = progression.config["weapons"]["boomstick"]
		var heading := _boomstick_heading(float(boom_data.get("aim_assist_degrees",45.0)))
		var pellet_count: int = (12 if progression.evolutions.has("boomstick") else int(boom_data.get("base_pellets", 6))) + ammo_bonus
		if boom_level >= 2:
			pellet_count += maxi(1, roundi(2.0 * progression.weapon_step_mult("boomstick", 2)))
		if boom_level >= 5:
			pellet_count += maxi(1, roundi(2.0 * progression.weapon_step_mult("boomstick", 5)))
		var boom_damage_mult: float = float(boom_data.get("base_damage",1.0)) * ((2.0 if progression.evolutions.has("boomstick") else 1.0) + (0.20 * progression.weapon_step_mult("boomstick", 3) if boom_level >= 3 else 0.0))
		var cone_step := (0.085 if progression.evolutions.has("boomstick") else float(boom_data.get("base_cone_step", 0.105))) * (1.30 if boom_level >= 4 else 1.0)
		var boom_knockback := float(boom_data.get("base_knockback", 55.0)) * (2.0 if boom_level >= 5 else 1.0)
		var boom_life := float(boom_data.get("base_range_pixels",400.0)) / BULLET_SPEED
		for pellet in range(pellet_count):
			var angle := (float(pellet) - float(pellet_count-1)*0.5) * cone_step
			if projectile_count() < int(progression.config.get("limits", {}).get("projectiles", 400)):
				transient_pool.push(bullets,"bullets",{"weapon":"boomstick","facing_bound":true,"pos": player_pos, "dir": heading.rotated(angle), "life": boom_life, "hits_left": 1, "damage_mult": boom_damage_mult, "knockback": boom_knockback},400)
		if juice_fx != null:
			if juice_fx.has_method("shotgun_shot"):
				juice_fx.call("shotgun_shot", player_pos, heading)
			else:
				juice_fx.call("shot", player_pos, heading)
		recoil_vector = -heading * 5.0
		last_aim = heading
		var boom_period := float(boom_data.get("base_fire_period",0.9))
		boomstick_fire_clock = boom_period / (trigger_bonus * rage_mult * mega_mult)

	_update_phase_c(delta)
	_stage1_update_hazards(delta)
	_rebuild_enemy_grid()
	_update_bullets(delta)
	_update_enemies(delta)
	_update_health(delta)
	_update_objectives(delta)
	_update_puzzle(delta)
	_update_hud()
	queue_redraw()

func _boomstick_heading(assist_degrees: float) -> Vector2:
	var facing_heading := last_aim.normalized()
	if facing_heading.length_squared() < 0.5:
		facing_heading = Vector2.RIGHT
	var chosen := facing_heading
	var best_distance := INF
	var max_angle := deg_to_rad(assist_degrees)
	for enemy in enemies:
		var offset := Vector2(enemy["pos"]) - player_pos
		if offset.length_squared() < 1.0:
			continue
		var candidate := offset.normalized()
		if absf(facing_heading.angle_to(candidate)) > max_angle:
			continue
		var distance := offset.length_squared()
		if distance < best_distance:
			best_distance = distance
			chosen = candidate
	return chosen


func _active_horde_target() -> int:
	if progression == null:
		return 20
	var pacing: Dictionary = progression.config.get("pacing", {})
	var targets: Array = pacing.get("pressure_by_wave", [])
	var target_row: Array = targets[mini(maxi(0, wave - 1), targets.size() - 1)] if not targets.is_empty() else [20, 40]
	var start_target := int(target_row[0])
	var end_target := int(target_row[1])
	var t := clampf(wave_clock / _wave_duration(), 0.0, 1.0)
	var target := roundi(lerpf(float(start_target), float(end_target), t))
	if events != null: target = roundi(float(target) * events.pressure_multiplier())
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
	var half:=_camera_half_extents()
	var view:=Rect2(player_pos-half,half*2)
	for enemy in enemies:
		if view.has_point(enemy["pos"]):
			count += 1
	return count

func _pressure_population_count() -> int:
	var half := _camera_half_extents()
	var pacing: Dictionary = progression.config.get("pacing", {}) if progression != null else {}
	var margin := float(pacing.get("spawn_margin", 180.0)) + float(pacing.get("spawn_jitter", 80.0)) + 80.0
	var count := 0
	for enemy in enemies:
		var offset := Vector2(enemy["pos"]) - player_pos
		if absf(offset.x) <= half.x + margin and absf(offset.y) <= half.y + margin:
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
	var difficulty: Dictionary = progression.config.get("difficulty", {}) if progression != null else {}
	var hp_scale := (1.0 + float(difficulty.get("enemy_hp_per_wave", 0.15)) * float(wave)) * (1.0 + float(difficulty.get("enemy_hp_per_player_level", 0.03)) * float(progression.level if progression != null else 1))
	var speed_scale := 1.0 + minf(float(difficulty.get("enemy_speed_bonus_cap", 0.20)), float(difficulty.get("enemy_speed_per_wave", 0.02)) * float(wave))
	var roster: Dictionary = difficulty.get("enemy_types", {})
	var base: Dictionary = roster.get(kind, {"hp": 30.0, "speed": 46.0, "radius": 34.0})
	return {"hp": float(base.get("hp", 1.0)) * hp_scale, "speed": float(base.get("speed", 108.0)) * speed_scale, "radius": ActorPresentation.radius_for(kind) if ActorPresentation.HEIGHT_RATIOS.has(kind) else float(base.get("radius", 18.0))}

func _append_enemy(kind: String, pos: Vector2) -> void:
	if enemies.size()>=250: return
	grid_dirty=true
	var stats := _enemy_stats(kind)
	if events != null and not events.spawn_allowed(pos, float(stats["radius"])): return
	transient_pool.push(enemies,"enemies",{
		"uid": _next_uid(),
		"pos": pos,
		"kind": kind,
		"hp": float(stats["hp"]),
		"speed": float(stats["speed"]),
		"radius": float(stats["radius"]),
		"elite": false,
		"charge": 0.0,
		"contact_cooldown": 0.0,
		"attack_clock": 0.0,
		"charge_target": Vector2.ZERO,
		"facing": Vector2.RIGHT,
	},250)

func _pressure_kind() -> String:
	if wave <= 1:
		return "shambler"
	var roll := rng.randf()
	if wave >= 6 and roll < 0.07:
		return "brute"
	if wave >= 5 and roll < 0.17:
		return "spitter"
	if wave >= 4 and roll < 0.28:
		return "bloater"
	if roll < 0.53:
		return "runner"
	return "shambler"

func _spawn_pressure_group(forced_size: int = -1) -> void:
	if progression == null:
		return
	var pacing: Dictionary = progression.config.get("pacing", {})
	var group_size := forced_size if forced_size > 0 else rng.randi_range(int(pacing.get("spawn_group_min", 4)), int(pacing.get("spawn_group_max", 10)))
	var dir_count := rng.randi_range(int(pacing.get("spawn_directions_min", 2)), int(pacing.get("spawn_directions_max", 3)))
	var step_radians := deg_to_rad(float(pacing.get("spawn_group_angle_step_degrees", 72.0)))
	var base_angle := fmod(float(spawn_group_index) * step_radians + rng.randf_range(-0.18, 0.18), TAU)
	spawn_group_index += 1
	var cap := int(progression.config.get("limits", {}).get("active_enemies", 250))
	var min_spawn_distance := float(pacing.get("min_spawn_distance_tiles", 1.5)) * TILE
	var runner_pack := wave >= 2 and rng.randf() < 0.35
	if runner_pack:
		group_size = mini(group_size, rng.randi_range(int(pacing.get("runner_pack_min", 4)), int(pacing.get("runner_pack_max", 8))))
	for n in range(group_size):
		if enemies.size() >= cap:
			break
		if wave_clock >= float(pacing.get("wave_duration_seconds", 75.0)):
			break
		var lane := n % maxi(1, dir_count)
		var angle := base_angle + TAU * float(lane) / float(maxi(1, dir_count)) + rng.randf_range(-0.20, 0.20)
		var pos := _spawn_position_outside_view(angle)
		if pos.distance_to(player_pos) < min_spawn_distance:
			pos = player_pos + Vector2.from_angle(angle) * min_spawn_distance
		pos = _nearest_walkable_position(pos, 18.0)
		var before := enemies.size()
		_append_enemy("runner" if runner_pack else _pressure_kind(), pos)
		wave_spawned += enemies.size() - before

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
		transient_pool.remove(impact_marks,0,"impact_marks")

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		bullet["pos"] += bullet["dir"] * BULLET_SPEED * delta
		bullet["life"] -= delta
		var consumed := false
		var event_damage: float = float(bullet_damage) * float(bullet.get("damage_mult", 1.0)) * (progression.damage_multiplier() if progression != null else 1.0)
		if events != null and events.hit_bullet(bullet["pos"], event_damage):
			transient_pool.remove(bullets, i, "bullets")
			continue

		var bullet_tile := _char_at_world(Vector2(bullet["pos"]))
		if _bullet_blocked_by(bullet_tile):
			transient_pool.remove(bullets,i,"bullets")
			continue

		for pump in pumps:
			if bool(pump["alive"]) and bullet["pos"].distance_to(pump["pos"]) <= PUMP_RADIUS + BULLET_RADIUS:
				_explode_pump(pump)
				consumed = true
				break
		if consumed:
			transient_pool.remove(bullets,i,"bullets")
			continue

		for j in enemy_indices_near(Vector2(bullet["pos"]), 75.0):
			if j >= enemies.size(): continue
			var enemy: Dictionary = enemies[j]
			if bullet["pos"].distance_to(enemy["pos"]) <= float(enemy["radius"]) + BULLET_RADIUS:
				var bullet_mult := float(bullet.get("damage_mult", 1.0))
				var raw_damage: float = float(bullet_damage) * bullet_mult * (progression.damage_multiplier() if progression != null else 1.0)
				var crit: bool = progression.roll_crit() if progression != null else false
				var hit_position := Vector2(enemy["pos"])
				var killed := phase_b_damage_enemy(j, raw_damage, crit, "bullet")
				EventBus.hit_landed.emit({"source":"base_weapon","tags":[],"position":hit_position,"damage":raw_damage,"crit":crit})
				if not killed and j < enemies.size() and str(enemies[j]["kind"]) == "trucker":
					enemies[j]["charge"] = 1.1
				var knockback := float(bullet.get("knockback", 0.0))
				if not killed and j < enemies.size():
					var live_enemy: Dictionary = enemies[j]
					if knockback > 0.0:
						var pushed := Vector2(live_enemy["pos"]) + Vector2(bullet["dir"]).normalized() * knockback
						grid_dirty = true
						live_enemy["pos"] = _move_with_blockers(Vector2(live_enemy["pos"]), pushed - Vector2(live_enemy["pos"]), float(live_enemy["radius"]))
					transient_pool.push(impact_marks,"impact_marks",{"pos": live_enemy["pos"], "life": 0.22},120)
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
			transient_pool.remove(bullets,i,"bullets")

func _explode_pump(pump: Dictionary) -> void:
	pump["alive"] = false
	transient_pool.push(impact_marks,"impact_marks",{"pos": pump["pos"], "life": 0.55, "blast": true},120)
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
	if player_pos.distance_to(Vector2(pump["pos"])) <= PUMP_BLAST_RADIUS:
		_stage1_damage(12, "explosion")
	if juice_fx != null:
		juice_fx.call("explosion", Vector2(pump["pos"]), blast_kills)
	_haptic_pulse(45)
	banner.text = "PUMP DETONATED!"
	if events != null: events.pump_exploded(pump["pos"])

func _enemy_contact_damage(kind: String) -> int:
	var difficulty: Dictionary = progression.config.get("difficulty", {}) if progression != null else {}
	var contact: Dictionary = difficulty.get("contact_damage", {})
	var base_damage := float(contact.get("shambler_base", 5.66))
	if kind == "runner":
		base_damage = float(contact.get("runner_base", 8.0))
	elif kind == "bloater":
		base_damage = float(contact.get("bloater_base", 11.0))
	elif kind == "spitter":
		base_damage = float(contact.get("spitter_base", 6.0))
	elif kind == "brute":
		base_damage = float(contact.get("brute_base", 17.0))
	elif kind == "trucker":
		base_damage = float(contact.get("trucker_base", 18.0))
	var scale := 1.0 + float(difficulty.get("enemy_damage_per_wave", 0.06)) * float(wave)
	return maxi(1, roundi(base_damage * scale))

func _knockback_nearby_enemies() -> void:
	if progression == null:
		return
	var difficulty: Dictionary = progression.config.get("difficulty", {})
	var radius := float(difficulty.get("hit_knockback_radius", 230.0))
	var distance := float(difficulty.get("hit_knockback_distance", 125.0))
	for enemy in enemies:
		var pos := Vector2(enemy["pos"])
		var offset := pos - player_pos
		if offset.length() <= radius:
			var dir := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
			var pushed := pos + dir * distance
			enemy["pos"] = _move_with_blockers(pos, pushed - pos, float(enemy["radius"]))

func _apply_player_contact_damage(enemy: Dictionary) -> void:
	var god_mode := phase_ui != null and bool(phase_ui.god_mode)
	if god_mode:
		return
	if progression != null and progression.invulnerability > 0.0:
		return
	if player_hit_invulnerability > 0.0:
		return
	if float(enemy.get("contact_cooldown", 0.0)) > 0.0:
		return
	var kind := str(enemy["kind"])
	var damage := _enemy_contact_damage(kind)
	var effective_damage := maxi(1, damage - player_armor)
	var is_boss := kind == "trucker" and wave >= 10
	if not is_boss:
		var difficulty: Dictionary = progression.config.get("difficulty", {}) if progression != null else {}
		var cap_fraction := float(difficulty.get("incoming_damage_cap_fraction_per_second", 0.35))
		var remaining_budget := maxf(0.0, float(player_max_hp) * cap_fraction - incoming_damage_this_window)
		effective_damage = mini(effective_damage, floori(remaining_budget))
		if effective_damage <= 0:
			return
		incoming_damage_this_window += effective_damage
	player_hp = maxi(0, player_hp - effective_damage)
	wave_damage_taken += effective_damage
	wave_min_hp = mini(wave_min_hp, player_hp)
	stage1_wave_min_hp_pct = minf(stage1_wave_min_hp_pct, 100.0 * float(player_hp) / maxf(1.0, float(player_max_hp)))
	var damage_source := kind if kind == "brute" or kind == "bloater" else "contact"
	stage1_damage_sources[damage_source] = int(stage1_damage_sources.get(damage_source, 0)) + effective_damage
	if run_log != null: run_log.sample_hp(damage_source, effective_damage)
	if events != null: events.player_damaged()
	var difficulty: Dictionary = progression.config.get("difficulty", {}) if progression != null else {}
	player_hit_invulnerability = float(difficulty.get("player_hit_invulnerability_seconds", 0.5))
	enemy["contact_cooldown"] = float(difficulty.get("enemy_contact_cooldown_seconds", 0.8))
	_knockback_nearby_enemies()
	_haptic_pulse(20)

var stage1_hazards: Array[Dictionary] = []
var stage1_damage_sources: Dictionary = {"contact": 0, "spitter": 0, "bloater": 0, "brute": 0, "explosion": 0}
var stage1_wave_min_hp_pct := 100.0
var stage1_damage_dealt := 0.0
var stage1_enemy_integral := 0.0
var stage1_sample_seconds := 0.0
var stage1_enemy_max := 0
var stage1_surge_triggered := false

func _stage1_damage(amount: int, source: String) -> void:
	if player_hp <= 0 or (phase_ui != null and bool(phase_ui.god_mode)):
		return
	var dealt := mini(player_hp, maxi(0, amount))
	player_hp -= dealt
	wave_damage_taken += dealt
	wave_min_hp = mini(wave_min_hp, player_hp)
	stage1_damage_sources[source] = int(stage1_damage_sources.get(source, 0)) + dealt
	stage1_wave_min_hp_pct = minf(stage1_wave_min_hp_pct, 100.0 * float(player_hp) / maxf(1.0, float(player_max_hp)))
	if run_log != null: run_log.sample_hp(source, dealt)
	if events != null and dealt > 0: events.player_damaged()

func _stage1_update_hazards(delta: float) -> void:
	for i in range(stage1_hazards.size() - 1, -1, -1):
		var h: Dictionary = stage1_hazards[i]
		h["life"] = float(h["life"]) - delta
		h["tick"] = float(h.get("tick", 0.0)) - delta
		if float(h["life"]) <= 0.0:
			if str(h["kind"]) == "acid_warning":
				var diff: Dictionary = progression.config.get("difficulty", {})
				transient_pool.push(stage1_hazards,"stage1_hazards",{"kind": "acid", "pos": Vector2(h["pos"]), "radius": float(h["radius"]), "life": float(diff.get("spitter_puddle_seconds", 4.0)), "tick": 0.0},64)
			transient_pool.remove(stage1_hazards,i,"stage1_hazards")
			continue
		if str(h["kind"]) == "acid" and player_pos.distance_to(Vector2(h["pos"])) < float(h["radius"]) and float(h["tick"]) <= 0.0:
			var diff: Dictionary = progression.config.get("difficulty", {})
			_stage1_damage(int(diff.get("acid_damage_per_tick", 4)), "spitter")
			h["tick"] = float(diff.get("acid_tick_seconds", 0.8))

func _stage1_spawn_surge() -> void:
	var pacing: Dictionary = progression.config.get("pacing", {})
	var count := roundi(float(pacing.get("surge_ring_count", 12)) * (events.pressure_multiplier() if events != null else 1.0))
	for i in range(count):
		if enemies.size() >= int(progression.config.get("limits", {}).get("active_enemies", 250)):
			break
		var angle := TAU * float(i) / float(count)
		_append_enemy(_pressure_kind(), _nearest_walkable_position(_spawn_position_outside_view(angle), 18.0))
	print("STAGE1_SURGE wave=%d t=%.1f count=%d" % [wave, run_clock, count])

func _update_enemies(delta: float) -> void:
	var half:=_camera_half_extents()+Vector2(80,80)
	var view:=Rect2(player_pos-half,half*2)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var step_dt := delta
		if not view.has_point(enemy["pos"]) and player_pos.distance_squared_to(enemy["pos"])>640.0*640.0:
			enemy["ai_accum"] = float(enemy.get("ai_accum",0.0))+delta
			if float(enemy["ai_accum"])<1.0/float(progression.config.get("performance",{}).get("offscreen_ai_hz",15)): continue
			step_dt = float(enemy["ai_accum"])
			enemy["ai_accum"]=0.0
		else:
			step_dt += float(enemy.get("ai_accum",0.0))
			enemy["ai_accum"]=0.0
		_update_enemy(enemy,step_dt)
	grid_dirty=true

func _update_enemy(enemy: Dictionary, delta: float) -> void:
	enemy["visual_hit"] = maxf(0.0, float(enemy.get("visual_hit", 0.0)) - delta)
	enemy["contact_cooldown"] = maxf(0.0, float(enemy.get("contact_cooldown", 0.0)) - delta)
	var to_player: Vector2 = player_pos - enemy["pos"]
	if str(enemy["kind"]) == "brute" and float(enemy.get("charge", 0.0)) == 0.0 and to_player.length() > 1.0:
		if not bool(enemy.get("stage2_mechanic", false)) or not bool(enemy.get("tank_exposed", false)):
			enemy["facing"] = to_player.normalized()
	var speed := 0.0 if freeze_clock > 0.0 else float(enemy["speed"])
	var kind: String = str(enemy["kind"])
	var diff: Dictionary = progression.config.get("difficulty", {})
	if kind == "spitter" and freeze_clock <= 0.0:
		enemy["attack_clock"] = float(enemy.get("attack_clock", 0.0)) - delta
		if float(enemy["attack_clock"]) <= 0.0 and to_player.length() < 600.0:
			enemy["attack_clock"] = 3.2
			transient_pool.push(stage1_hazards,"stage1_hazards",{"kind": "acid_warning", "pos": player_pos + player_velocity * 0.5, "radius": 80.0, "life": float(diff.get("spitter_telegraph_seconds", 0.8)), "tick": 0.0},64)
		if to_player.length() < 360.0:
			speed = -speed * 0.6
	elif kind == "brute" and freeze_clock <= 0.0:
		enemy["attack_clock"] = float(enemy.get("attack_clock", 0.0)) - delta
		if float(enemy["attack_clock"]) <= 0.0 and to_player.length() < 440.0:
			enemy["attack_clock"] = 4.5
			enemy["charge"] = -float(diff.get("brute_charge_telegraph_seconds", 0.9))
			enemy["charge_target"] = to_player.normalized()
		if float(enemy["charge"]) < 0.0:
			enemy["charge"] = minf(0.0, float(enemy["charge"]) + delta)
			speed = 0.0
			if float(enemy["charge"]) >= 0.0:
				enemy["charge"] = float(diff.get("brute_charge_seconds", 0.55))
		elif float(enemy["charge"]) > 0.0:
			enemy["charge"] = maxf(0.0, float(enemy["charge"]) - delta)
			enemy["pos"] = _move_with_blockers(Vector2(enemy["pos"]), Vector2(enemy["charge_target"]) * float(diff.get("brute_charge_speed", 390.0)) * delta, float(enemy["radius"]))
			speed = 0.0
	if str(enemy["kind"]) == "trucker" and float(enemy["charge"]) > 0.0:
		enemy["charge"] = maxf(0.0, float(enemy["charge"]) - delta)
		speed = 165.0
	speed *= _speed_mult_for_char(_char_at_world(enemy["pos"]))
	var enemy_step := to_player.normalized() * speed * delta
	var substeps:=maxi(1,ceili(enemy_step.length()/12.0))
	for sub in range(substeps):
		enemy["pos"] = _move_with_blockers(Vector2(enemy["pos"]), enemy_step/substeps, float(enemy["radius"]))
	if to_player.length() < PLAYER_RADIUS + float(enemy["radius"]):
		_apply_player_contact_damage(enemy)

func _haptic_pulse(duration_ms: int = 30) -> void:
	if not vibration_enabled:
		return
	if OS.get_name() != "Android":
		return
	Input.vibrate_handheld(maxi(1, duration_ms))

func _update_phase_c(delta: float) -> void:
	rage_clock = maxf(0.0, rage_clock - delta)
	mega_clock = maxf(0.0, mega_clock - delta)
	freeze_clock = maxf(0.0, freeze_clock - delta)
	if wave >= 3 and wave_active:
		elite_spawn_clock -= delta
		if elite_spawn_clock <= 0.0 and enemies.size() < 240:
			elite_spawn_clock = 45.0
			var spawn_at := _spawn_position_outside_view(rng.randf_range(0.0, TAU))
			var before := enemies.size()
			_append_enemy(_pressure_kind(), spawn_at)
			if enemies.size() == before: return
			var elite: Dictionary = enemies[enemies.size() - 1]
			elite["elite"] = true
			elite["hp"] = float(elite["hp"]) * 4.0
			elite["radius"] = ActorPresentation.radius_for(str(elite["kind"]), true)
			print("PHASE_C_ELITE wave=%d t=%.1f" % [wave, run_clock])
	for i in range(powerups.size() - 1, -1, -1):
		var pickup: Dictionary = powerups[i]
		pickup["age"] = float(pickup["age"]) + delta
		if player_pos.distance_to(Vector2(pickup["pos"])) < 65.0:
			_collect_phase_c_powerup(str(pickup["kind"]))
			transient_pool.remove(powerups,i,"powerups")
		elif float(pickup["age"]) > 35.0:
			transient_pool.remove(powerups,i,"powerups")
	if powerups.size() > 30:
		transient_pool.remove(powerups,0,"powerups")

func _collect_phase_c_powerup(kind: String) -> void:
	match kind:
		"Rage":
			rage_clock = 10.0
		"Mega Gun":
			mega_clock = 8.0
		"Nuke":
			for i in range(enemies.size() - 1, -1, -1):
				if bool(enemies[i].get("elite", false)):
					enemies[i]["hp"] = float(enemies[i]["hp"]) * 0.5
				elif str(enemies[i]["kind"]) != "trucker":
					_phase_a_kill_enemy(i)
		"Magnet":
			if progression != null:
				progression.vacuum_all_gems()
		"Freeze":
			freeze_clock = 5.0
		"Medkit":
			player_hp = mini(player_max_hp, player_hp + roundi(float(player_max_hp) * float(progression.config.get("difficulty", {}).get("medkit_heal_fraction", 0.20))))
		"Chest":
			var chest_reward := "50 SCRAP + 30 XP"
			score += 250
			scrap_earned += 50
			if progression != null:
				var evolved: String = progression.chest_evolution()
				if evolved != "":
					kind = "EVOLVED: " + evolved
					chest_reward = evolved
				else:
					progression.add_xp(30)
			if phase_ui != null:
				phase_ui.show_chest_reveal(chest_reward)
	banner.text = "POWER-UP: %s!" % kind
	banner.visible = true
	transient_pool.push(impact_marks,"impact_marks",{"pos": player_pos, "life": 0.55, "blast": true},120)
	_cap_impact_marks()
	print("PHASE_C_PICKUP kind=%s t=%.1f" % [kind, run_clock])

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

func _update_objectives(_delta: float) -> void:
	# The pause-aware event manager owns interaction. No proximity auto-completion.
	pass

func _update_puzzle(_delta: float) -> void:
	# The relay is now an optional three-pad event, not a color-code gate.
	pass

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
		var spawn := _nearest_walkable_position(candidate, ActorPresentation.radius_for("runner" if is_runner else "shambler"))
		transient_pool.push(enemies,"enemies",{"uid": _next_uid(), "pos": spawn, "kind": "runner" if is_runner else "shambler", "hp": 2 if is_runner else 1, "speed": 205.0 if is_runner else 108.0, "radius": ActorPresentation.radius_for("runner" if is_runner else "shambler"), "charge": 0.0, "trap_guard": color},250)
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
		transient_pool.push(impact_marks,"impact_marks",{"pos": PUZZLE_CENTER, "life": 0.75, "blast": true},120)
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
		var spawn_radius := ActorPresentation.radius_for("runner" if is_runner else "shambler")
		spawn = _nearest_walkable_position(spawn, spawn_radius)
		transient_pool.push(enemies,"enemies",{
			"uid": _next_uid(),
			"pos": spawn,
			"kind": "runner" if is_runner else "shambler",
			"hp": 1,
			"speed": 205.0 if is_runner else 112.0,
			"radius": spawn_radius,
			"charge": 0.0,
		},250)

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
	if wave10_survived:
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
	if hazard_debug: _draw_hazard_debug()
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

	# Curated crack decals overlay existing cracked-ground hazard zones only.
	# Tinted down to the ground's value range so they read as damage, not pasted patches.
	for decal in [[DECAL_CRACK_A, Vector2(7.5, 5.5)], [DECAL_CRACK_B, Vector2(9.5, 33.5)], [DECAL_CRACK_A, Vector2(24.5, 33.5)], [DECAL_CRACK_B, Vector2(4.5, 38.5)]]:
		_draw_curated_texture(decal[0], decal[1] * TILE, Vector2(512, 512), Color(0.42, 0.40, 0.38, 0.85))

func _tiles_rect(x: int, y: int, w: int, h: int) -> Rect2:
	return Rect2(Vector2(float(x),float(y))*TILE, Vector2(float(w),float(h))*TILE)

const SHADOW_OFFSET := Vector2(14, 20)      # light from the upper left
const SHADOW_COLOR := Color(0.0, 0.0, 0.03, 0.42)

func _draw_art_rect(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	# Drop shadow from the art's own silhouette so buildings and props sit on the ground.
	draw_texture_rect(texture, Rect2(rect.position + SHADOW_OFFSET, rect.size), false, SHADOW_COLOR)
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
	# Stage2Events draws only the active offer and earned world tools.
	pass

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
			draw_circle(p, radius, Color("#7e392f")) # Deferred boss placeholder, unchanged.
		if kind == "brute" and float(enemy.get("charge", 0.0)) < 0.0:
			draw_line(p, p + Vector2(enemy.get("charge_target", Vector2.RIGHT)) * 450.0, Color.ORANGE, 12.0)
		if bool(enemy.get("elite", false)):
			var aura := 0.55 + 0.25 * sin(run_clock * 7.0)
			draw_arc(p, radius + 12.0, 0.0, TAU, 32, Color(1.0, 0.74, 0.12, aura), 7.0, true)
		if flash_clock > 0.0:
			draw_circle(p, radius + 5.0, Color(1,1,1,0.7 * flash_clock / 0.06))

	for h in stage1_hazards:
		var hpos: Vector2 = h["pos"]
		var radius := float(h["radius"])
		var is_goo := str(h["kind"]) == "goo"
		var hc := Color(0.28, 0.7, 0.23, 0.30) if is_goo else Color(0.95, 0.38, 0.08, 0.30)
		draw_circle(hpos, radius, hc)
		_draw_curated_texture(DECAL_GOO if is_goo else DECAL_ACID, hpos, Vector2(radius * 2.0, radius * 2.0))
	for pickup in powerups:
		var ppos: Vector2 = pickup["pos"]
		var bob := sin(float(pickup["age"]) * 5.0) * 8.0
		var tint := Color("#F2C14E") if str(pickup["kind"]) == "Chest" else Color("#3D8BFF")
		draw_circle(ppos + Vector2(0, bob), 23.0, tint * Color(1, 1, 1, 0.55))
		draw_arc(ppos + Vector2(0, bob), 30.0, 0.0, TAU, 24, tint, 4.0)
		var pickup_kind := str(pickup["kind"])
		if curated_pickup_textures.has(pickup_kind):
			_draw_curated_texture(curated_pickup_textures[pickup_kind], ppos + Vector2(0, bob), Vector2(42, 42))
	for bullet in bullets:
		draw_line(bullet["pos"] - bullet["dir"] * 22.0, bullet["pos"], Color("#F2A23A", 0.45), 7.0)
		draw_line(bullet["pos"] - bullet["dir"] * 22.0, bullet["pos"], Color("#fff2b8"), 4.0)
		draw_circle(bullet["pos"], BULLET_RADIUS, Color("#fff2b8"))

	for mark in impact_marks:
		var life := float(mark["life"])
		var is_blast := bool(mark.get("blast", false))
		var radius := 28.0 if not is_blast else 115.0 * clampf(life / 0.55, 0.2, 1.0)
		draw_circle(mark["pos"], radius, Color(1.0,0.35,0.08,0.42 if is_blast else 0.55))

	# Shared actor renderer supplies foot-anchored survivor shadow and texture.
	recoil_vector = recoil_vector.move_toward(Vector2.ZERO, 120.0 * get_physics_process_delta_time())
	var bounce := sin(float(Time.get_ticks_msec()) * TAU / 250.0) * 0.05 if player_velocity.length() > 40.0 else 0.0
	var visual_scale := Vector2(1.0, 0.99 + bounce)
	var survivor_tint := Color.WHITE
	if player_hit_invulnerability > 0.0:
		var flicker_on := int(Time.get_ticks_msec() / 70) % 2 == 0
		survivor_tint.a = 0.30 if flicker_on else 1.0
	# Survivor art is rendered in the same Y-sorted actor layer as enemies.

func _draw_dusk() -> void:
	if events != null and events.earned.has("floodlights"): return
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
	if str(enemy["kind"]) == "brute" and Vector2(enemy["pos"]).distance_to(player_pos) > 0.0:
		var facing: Vector2 = (player_pos - Vector2(enemy["pos"])).normalized()
		var shot_from_front := Vector2(enemy.get("facing", facing)).dot(facing) > 0.0
		if shot_from_front:
			actual *= float(progression.config.get("difficulty", {}).get("brute_front_damage_multiplier", 0.5))
	if events != null: actual *= events.mechanic_damage_multiplier(enemy)
	if actual <= 0.0: return false
	stage1_damage_dealt += actual
	enemy["hp"] = float(enemy["hp"]) - actual
	if juice_fx != null and damage_numbers_enabled:
		juice_fx.call("damage_number", int(enemy["uid"]), Vector2(enemy["pos"]), actual, crit)
	if float(enemy["hp"]) <= 0.0:
		_phase_a_kill_enemy(index)
		return true
	return false

func _phase_a_kill_enemy(index: int) -> void:
	grid_dirty=true
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var kind := str(enemy["kind"])
	EventBus.zombie_killed.emit({"uid":int(enemy.get("uid",-1)),"kind":kind,"position":Vector2(enemy["pos"]),"elite":bool(enemy.get("elite",false))})
	if bool(enemy.get("elite", false)):
		transient_pool.push(powerups,"powerups",{"pos": Vector2(enemy["pos"]), "kind": "Chest", "age": 0.0},30)
		if progression != null:
			progression.add_xp(25)
	elif rng.randf() < float(progression.config.get("difficulty", {}).get("normal_powerup_drop_chance", 0.004)):
		var kinds := ["Rage", "Mega Gun", "Nuke", "Magnet", "Freeze", "Medkit"]
		var chosen: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		if chosen != "Medkit" or rng.randf() < float(progression.config.get("difficulty", {}).get("medkit_drop_weight", 0.5)):
			transient_pool.push(powerups,"powerups",{"pos": Vector2(enemy["pos"]), "kind": chosen, "age": 0.0},30)
	if progression != null:
		progression.drop_xp(Vector2(enemy["pos"]), kind)
	kills += 1
	if trap_active and str(enemy.get("trap_guard", "")) == "YELLOW":
		trap_guard_kills += 1
	var points := 500 if kind == "trucker" else 100
	score += points
	if juice_fx != null:
		juice_fx.call("kill", Vector2(enemy["pos"]), points)
	if kind == "bloater":
		var diff: Dictionary = progression.config.get("difficulty", {})
		transient_pool.push(stage1_hazards,"stage1_hazards",{"kind": "goo", "pos": Vector2(enemy["pos"]), "radius": 115.0, "life": float(diff.get("bloater_goo_seconds", 5.0)), "tick": 0.0},64)
	transient_pool.remove(enemies,index,"enemies")

func phase_a_resume_shockwave() -> void:
	var radius := 260.0
	var push := 145.0
	transient_pool.push(impact_marks,"impact_marks",{"pos": player_pos, "life": 0.45, "blast": true},120)
	_cap_impact_marks()
	for enemy in enemies:
		var enemy_pos := Vector2(enemy["pos"])
		var offset := enemy_pos - player_pos
		if offset.length() <= radius:
			var direction := offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT
			enemy["pos"] = _move_with_blockers(enemy_pos, direction * push, float(enemy["radius"]))
	queue_redraw()

func phase_a_debug_six_shambler_kills(count: int = 6) -> void:
	if progression == null:
		return
	progression.level = 1
	progression.xp = 0
	progression.pending_levels = 0
	progression.choosing = false
	progression.gems.clear()
	for i in range(count):
		transient_pool.push(enemies,"enemies",{"pos": player_pos + Vector2(10.0 * float(i % 3), 10.0 * float(i / 3)), "kind":"shambler", "hp":1, "speed":0.0, "radius":18.0, "charge":0.0},250)
		_phase_a_kill_enemy(enemies.size() - 1)

func projectile_count() -> int:
	return bullets.size()+(progression.rockets.size()+progression.chakrams.size()+progression.lightning_arcs.size()+progression.drone_shots.size() if progression!=null else 0)

func _rebuild_enemy_grid() -> void:
	for cell in enemy_grid: enemy_grid[cell].clear()
	for i in range(enemies.size()):
		var e: Dictionary=enemies[i]
		e["grid_index"]=i
		var cell:=Vector2i(Vector2(e["pos"])/128.0)
		if not enemy_grid.has(cell): enemy_grid[cell]=[]
		enemy_grid[cell].append(e)
	grid_dirty=false

func enemy_indices_near(center: Vector2, radius: float) -> Array[int]:
	if grid_dirty: _rebuild_enemy_grid()
	var found: Array[int]=[]
	var lo:=Vector2i((center-Vector2.ONE*radius)/128.0)
	var hi:=Vector2i((center+Vector2.ONE*radius)/128.0)
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			for e in enemy_grid.get(Vector2i(x,y),[]):
				found.append(int(e["grid_index"]))
	found.sort()
	found.reverse()
	return found

func _clear_objective_routes() -> void:
	# Clear only reachable corridors. Never move/remove a blocker or flatten all hazards.
	var nav:=AStarGrid2D.new()
	nav.region=Rect2i(0,0,MAP_W,MAP_H)
	nav.cell_size=Vector2.ONE*TILE
	nav.offset=Vector2.ONE*TILE*.5
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	for y in range(MAP_H):
		for x in range(MAP_W): nav.set_point_solid(Vector2i(x,y),_circle_hits_blocker(_tile_center(x,y),PLAYER_RADIUS))
	var hub:=Vector2i(PLAYER_START/TILE)
	var targets: Array[Vector2]=[GENERATOR_POS,SUPPLY_DINER,SUPPLY_AUTOSHOP,SUPPLY_MOTEL,NEST_WEST,NEST_EAST,NEST_NW,NEST_NE,PUZZLE_CENTER,RELAY_RED,RELAY_BLUE,RELAY_YELLOW]
	route_cells.clear()
	for pos in targets:
		var to:=Vector2i(pos/TILE)
		if nav.is_point_solid(to):
			var best:=INF
			for y in range(MAP_H):
				for x in range(MAP_W):
					if not nav.is_point_solid(Vector2i(x,y)) and _tile_center(x,y).distance_squared_to(pos)<best:
						best=_tile_center(x,y).distance_squared_to(pos)
						to=Vector2i(x,y)
		for cell in nav.get_id_path(hub,to):
			if not route_cells.has(cell): route_cells.append(cell)
			for dy in range(-1,2):
				for dx in range(-1,2):
					if abs(dx)+abs(dy)>1: continue
					var at:=cell+Vector2i(dx,dy)
					if _tile_char(at.x,at.y) in ["x",":","o"]: _set_generated_tile(at.x,at.y,".")
	print("PACING_ROUTE corridors=%d blockers_unchanged=true" % route_cells.size())
