extends Control
# Tactical map uses the authoritative Outskirts grid and live gameplay state.
const TILE := 128.0
const DETECTION_RADIUS := 1050.0
var game: Node2D
var expanded := false
var small_position := Vector2(310, 12)
var small_size := Vector2(110, 112)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_toggle()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle()
		accept_event()

func _toggle() -> void:
	expanded = not expanded
	if expanded:
		position = Vector2(16, 155)
		size = Vector2(400, 510)
	else:
		position = small_position
		size = small_size

func _point(world: Vector2, area: Rect2, origin: Vector2, scale: float) -> Vector2:
	return area.position + (world - origin) * scale

func _draw() -> void:
	if game == null:
		return
	var area := Rect2(Vector2(7, 7), size - Vector2(14, 14))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.065, 0.08, 0.94))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#7b969c"), false, 2.0)
	draw_line(Vector2(size.x - 22, 9), Vector2(size.x - 9, 9), Color("#F2A23A"), 2.0)
	draw_line(Vector2(size.x - 9, 9), Vector2(size.x - 9, 22), Color("#F2A23A"), 2.0)
	draw_line(Vector2(size.x - 23, 23), Vector2(size.x - 10, 10), Color("#F2A23A"), 2.0)
	var scale := minf(area.size.x / 4096.0, area.size.y / 5120.0) if expanded else 0.075
	var origin: Vector2 = Vector2.ZERO if expanded else Vector2(game.player_pos) - area.size / (2.0 * scale)
	for y in range(40):
		for x in range(32):
			var p := Vector2(x * TILE, y * TILE)
			var rect := Rect2(_point(p, area, origin, scale), Vector2(TILE * scale, TILE * scale))
			if not rect.intersects(area):
				continue
			var ch: String = game.generated_map_rows[y].substr(x, 1)
			var color := Color("#3c474b")
			if ch in "BCTPbJF":
				color = Color("#151e24")
			elif ch == "o":
				color = Color("#655d48")
			elif ch == ":":
				color = Color("#514b41")
			elif ch == "x":
				color = Color("#595b60")
			draw_rect(rect.intersection(area), color)
	var objectives: Array = []
	if not game.generator_active:
		objectives.append([game.GENERATOR_POS, Color("#f4d15b")])
	for cache in game.supply_caches:
		if not bool(cache["collected"]):
			objectives.append([Vector2(cache["pos"]), Color("#57b7f7")])
	for nest in game.infestation_nests:
		if not bool(nest["destroyed"]):
			objectives.append([Vector2(nest["pos"]), Color("#c07bef")])
	if not game.puzzle_complete:
		objectives.append([game.PUZZLE_CENTER, Color("#5de4e4")])
	if game.district_cleared:
		objectives.append([game.NORTH_EXIT.get_center(), Color("#5df5a5")])
	for item in objectives:
		var p := _point(item[0], area, origin, scale)
		p = p.clamp(area.position + Vector2(5, 5), area.end - Vector2(5, 5))
		draw_circle(p, 4.0 if expanded else 3.0, item[1])
	for enemy in game.enemies:
		var pos: Vector2 = enemy["pos"]
		if pos.distance_to(game.player_pos) > DETECTION_RADIUS:
			continue
		var p := _point(pos, area, origin, scale)
		if area.has_point(p):
			var kind: String = str(enemy["kind"])
			draw_circle(p, 4.5 if kind == "trucker" else (2.5 if kind == "runner" else 1.6), Color("#ff9472") if kind == "runner" else Color("#ff4a49"))
	var player := _point(game.player_pos, area, origin, scale)
	if area.has_point(player):
		draw_circle(player, 5.0, Color("#68f5b3"))
		draw_arc(player, 7.0, 0.0, TAU, 16, Color("#68f5b3"), 1.0)
