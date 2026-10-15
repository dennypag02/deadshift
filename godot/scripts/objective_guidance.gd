extends Node2D
## Stage 2 guidance only: one location list for map, briefing, card and ground route.
const AMBER := Color("#F2A23A")
const METRES_PER_TILE := 4.0
const BRIEFING_HOLD := 1.5
var game: Node2D
var target: Dictionary = {}
var route := PackedVector2Array()
var navigation := AStarGrid2D.new()
var refresh_clock := 0.0
var last_cell := Vector2i(-1, -1)
var pending_briefing := false
var briefing := false
var brief_age := 0.0
var camera_start := Vector2.ZERO
var old_smoothing := true
var briefing_layer: CanvasLayer
var brief_text: Label
var disabled_for_test := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	disabled_for_test = OS.get_cmdline_args().has("--script") or OS.get_cmdline_user_args().has("--no-briefing")
	z_index = 1
	navigation.region = Rect2i(0, 0, game.MAP_W, game.MAP_H)
	navigation.cell_size = Vector2.ONE * game.TILE
	navigation.offset = Vector2.ONE * game.TILE * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(game.MAP_H):
		for x in range(game.MAP_W):
			navigation.set_point_solid(Vector2i(x, y), game._circle_hits_blocker(Vector2(x + 0.5, y + 0.5) * game.TILE, game.PLAYER_RADIUS))
	briefing_layer = CanvasLayer.new()
	briefing_layer.layer = 140
	add_child(briefing_layer)
	brief_text = Label.new()
	brief_text.position = Vector2(16, 760)
	brief_text.size = Vector2(400, 150)
	brief_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_text.add_theme_font_size_override("font_size", 24)
	brief_text.add_theme_color_override("font_color", AMBER)
	brief_text.add_theme_color_override("font_outline_color", Color.BLACK)
	brief_text.add_theme_constant_override("outline_size", 5)
	brief_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	briefing_layer.add_child(brief_text)
	briefing_layer.hide()
	refresh_target()

func _entry(id: String, kind: String, label: String, pos: Vector2, done: bool, reward: String, reward_icon: String = "icon_pickup_scrap") -> Dictionary:
	return {"id": id, "kind": kind, "label": label, "pos": pos, "done": done,
		"reward": reward, "reward_icon": reward_icon}

func objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(_entry("generator", "bolt", "Generator - Mini-Mart", game.GENERATOR_POS, game.generator_active, "+500 score"))
	for i in range(game.supply_caches.size()):
		var cache: Dictionary = game.supply_caches[i]
		result.append(_entry("supply_%d" % i, "crate", "Supply crate - " + str(cache["name"]), cache["pos"], bool(cache["collected"]), "+350 score"))
	var names := ["West", "East", "Northwest", "Northeast"]
	for i in range(game.infestation_nests.size()):
		var nest: Dictionary = game.infestation_nests[i]
		result.append(_entry("nest_%d" % i, "skull", "Infestation nest - " + names[i], nest["pos"], bool(nest["destroyed"]), "+600 score / blast", "icon_arsenal_nest_down"))
	for color in ["RED", "BLUE", "YELLOW"]:
		result.append(_entry("relay_" + color, "relay", "Relay - " + color.capitalize(), game._relay_position(color), game.trap_finished.has(color), "Detonator core step", "icon_battery_pack"))
	result.append(_entry("core", "relay", "Detonator core", game.PUZZLE_CENTER, game.detonator_core, "Core secured", "icon_battery_pack"))
	result.append(_entry("exit", "exit", "North district exit", game.NORTH_EXIT.get_center(), false, "Next district", "icon_chest"))
	return result

func choose_target() -> Dictionary:
	var all := objectives()
	if not game.generator_active:
		return all[0]
	for kind in ["crate", "skull"]:
		var best: Dictionary = {}
		var distance := INF
		for objective in all:
			if objective["kind"] == kind and not objective["done"]:
				var d: float = Vector2(game.player_pos).distance_squared_to(objective["pos"])
				if d < distance:
					distance = d
					best = objective
		if not best.is_empty():
			# Retain a valid current target instead of switching constantly between nearby sites.
			for objective in all:
				if objective["id"] == target.get("id", "") and objective["kind"] == kind and not objective["done"]:
					return objective
			return best
	if not game.puzzle_complete:
		var color: String = game.PUZZLE_CODE[mini(game.puzzle_step, game.PUZZLE_CODE.size() - 1)]
		if game.trap_active and game.trap_color == "BLUE":
			if not game.blue_switch_a:
				return _entry("blue_switch_a", "relay", "Blue relay - switch 1", game.RELAY_BLUE + Vector2(-320, 0), false, "Complete Blue trap", "icon_battery_pack")
			if not game.blue_switch_b:
				return _entry("blue_switch_b", "relay", "Blue relay - switch 2", game.RELAY_BLUE + Vector2(0, 350), false, "Complete Blue trap", "icon_battery_pack")
		for objective in all:
			if objective["id"] == "relay_" + color:
				return objective
	if game.district_cleared:
		return all[all.size() - 1]
	return {}

func refresh_target() -> void:
	var next := choose_target()
	if str(next.get("id", "")) != str(target.get("id", "")):
		target = next
		pending_briefing = not target.is_empty()
		last_cell = Vector2i(-1, -1)
		print("OBJECTIVE_TARGET id=%s label=%s wave=%d t=%.2f" % [target.get("id", "none"), target.get("label", "Survive"), game.wave, game.run_clock])
	else:
		target = next

func label_text() -> String:
	return str(target.get("label", "Survive the current wave"))

func distance_metres() -> int:
	if target.is_empty():
		return 0
	return roundi(Vector2(game.player_pos).distance_to(target["pos"]) / game.TILE * METRES_PER_TILE)

func direction_vector() -> Vector2:
	if target.is_empty():
		return Vector2.ZERO
	return (Vector2(target["pos"]) - Vector2(game.player_pos)).normalized()

func _walkable_cell(pos: Vector2) -> Vector2i:
	var center := Vector2i(pos / game.TILE).clamp(Vector2i.ZERO, Vector2i(game.MAP_W - 1, game.MAP_H - 1))
	if not navigation.is_point_solid(center):
		return center
	var best := center
	var best_distance := INF
	for y in range(game.MAP_H):
		for x in range(game.MAP_W):
			var cell := Vector2i(x, y)
			if not navigation.is_point_solid(cell):
				var d: float = ((Vector2(cell) + Vector2.ONE * 0.5) * game.TILE).distance_squared_to(pos)
				if d < best_distance:
					best_distance = d
					best = cell
	return best

func rebuild_route() -> void:
	route.clear()
	if target.is_empty():
		return
	var from := _walkable_cell(game.player_pos)
	var to := _walkable_cell(target["pos"])
	route = navigation.get_point_path(from, to)
	if route.is_empty():
		return # Never draw a misleading straight line through buildings.
	route[0] = game.player_pos
	if not game._circle_hits_blocker(target["pos"], game.PLAYER_RADIUS):
		route.append(target["pos"])

func _process(delta: float) -> void:
	if game == null:
		return
	if briefing:
		brief_age += delta
		var location: Vector2 = target.get("pos", game.player_pos)
		if brief_age < 0.45:
			game.camera.position = camera_start.lerp(location, smoothstep(0.0, 0.45, brief_age))
		elif brief_age < 0.45 + BRIEFING_HOLD:
			game.camera.position = location
		elif brief_age < 0.90 + BRIEFING_HOLD:
			game.camera.position = location.lerp(game.player_pos, smoothstep(0.45 + BRIEFING_HOLD, 0.90 + BRIEFING_HOLD, brief_age))
		else:
			end_briefing()
	else:
		refresh_clock -= delta
		if refresh_clock <= 0.0:
			refresh_clock = 0.35
			refresh_target()
			var cell := Vector2i(Vector2(game.player_pos) / game.TILE)
			if cell != last_cell:
				last_cell = cell
				rebuild_route()
		if pending_briefing and not get_tree().paused and not disabled_for_test and game.player_hp > 0 and game.phase_ui.active_modal == "":
			begin_briefing()
	queue_redraw()

func begin_briefing() -> void:
	if target.is_empty():
		return
	pending_briefing = false
	briefing = true
	brief_age = 0.0
	camera_start = game.camera.position
	old_smoothing = game.camera.position_smoothing_enabled
	game.camera.position_smoothing_enabled = false
	game.touch_active = false
	brief_text.text = "HERE\n%s\nTap anywhere to skip" % label_text()
	briefing_layer.show()
	get_tree().paused = true
	print("OBJECTIVE_BRIEFING_START id=%s" % target["id"])

func end_briefing() -> void:
	briefing = false
	game.camera.position = game.player_pos
	game.camera.position_smoothing_enabled = old_smoothing
	game.camera.reset_smoothing()
	briefing_layer.hide()
	game.touch_active = false
	get_tree().paused = false
	print("OBJECTIVE_BRIEFING_END")

func _input(event: InputEvent) -> void:
	if briefing and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		end_briefing()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if target.is_empty() or game == null:
		return
	var half: Vector2 = game._camera_half_extents() + Vector2(90, 90)
	var view := Rect2(Vector2(game.camera.position) - half, half * 2.0)
	var path := route.duplicate()
	if not path.is_empty():
		path[0] = game.player_pos
	var dots := 0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var length := a.distance_to(b)
		for step in range(0, ceili(length), 28):
			var point := a.lerp(b, float(step) / maxf(1.0, length))
			if view.has_point(point) and dots < 100:
				draw_circle(point, 3.5, Color(AMBER, 0.70))
				dots += 1
	var p: Vector2 = target["pos"]
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.004)
	# A tall world beacon; the HUD edge arrow remains visible when this column is off-screen.
	for band in range(16):
		var alpha := 0.18 * (1.0 - float(band) / 16.0)
		draw_rect(Rect2(p + Vector2(-19, -float(band + 1) * 64.0), Vector2(38, 64)), Color(AMBER, alpha))
	draw_line(p, p - Vector2(0, 1000), Color(AMBER, 0.42), 3.0)
	draw_arc(p, 45.0 + pulse * 8.0, 0, TAU, 24, Color(AMBER, 0.75), 4.0, true)
	draw_string(ThemeDB.fallback_font, p + Vector2(-30, -80), "HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, AMBER)

static func draw_icon(canvas: CanvasItem, p: Vector2, kind: String, radius: float, tint: Color) -> void:
	canvas.draw_circle(p, radius + 2, Color("#14191C"))
	match kind:
		"crate":
			canvas.draw_rect(Rect2(p - Vector2.ONE * radius * 0.65, Vector2.ONE * radius * 1.3), tint, false, 2.0)
			canvas.draw_line(p - Vector2.ONE * radius * 0.5, p + Vector2.ONE * radius * 0.5, tint, 1.5)
			canvas.draw_line(p + Vector2(-1, 1) * radius * 0.5, p + Vector2(1, -1) * radius * 0.5, tint, 1.5)
		"bolt":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0.1, -1) * radius, p + Vector2(-0.7, 0.15) * radius, p + Vector2(0.1, 0.15) * radius, p + Vector2(-0.1, 1) * radius, p + Vector2(0.7, -0.15) * radius, p + Vector2(-0.1, -0.15) * radius]), tint)
		"skull":
			canvas.draw_circle(p - Vector2(0, radius * 0.15), radius * 0.65, tint)
			canvas.draw_rect(Rect2(p + Vector2(-0.35, 0.15) * radius, Vector2(0.7, 0.65) * radius), tint)
			canvas.draw_circle(p + Vector2(-0.25, -0.2) * radius, radius * 0.15, Color.BLACK)
			canvas.draw_circle(p + Vector2(0.25, -0.2) * radius, radius * 0.15, Color.BLACK)
		_:
			canvas.draw_arc(p, radius * 0.7, 0, TAU, 12, tint, 2.0, true)
			canvas.draw_line(p - Vector2(radius, 0), p + Vector2(radius, 0), tint, 2)
			canvas.draw_line(p - Vector2(0, radius), p + Vector2(0, radius), tint, 2)
