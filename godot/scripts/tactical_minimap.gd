extends Control
## The same objective registry feeds both map sizes and the live objective card.
const GUIDE = preload("res://scripts/objective_guidance.gd")
const AMBER := Color("#F2A23A")
var game: Node2D
var pulse_clock := 0.0
var expanded := false
var small_position := Vector2(310, 12)
var small_size := Vector2(110, 112)
var overlay: CanvasLayer
var full_canvas: Control
var last_toggle := -1000
var reward_textures: Dictionary = {}
var terrain_texture: ImageTexture
var enemy_points:=PackedVector2Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	gui_input.connect(_on_input)

func _process(delta: float) -> void:
	pulse_clock += delta # frame delta, so fixed-FPS captures replay identically
	queue_redraw()
	if expanded and is_instance_valid(full_canvas):
		full_canvas.queue_redraw()

func _on_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_toggle()
		accept_event()

func _toggle() -> void:
	if Time.get_ticks_msec() - last_toggle < 180:
		return
	last_toggle = Time.get_ticks_msec()
	if expanded:
		close_map()
		return
	if get_tree().paused or game.phase_ui.active_modal != "":
		return
	expanded = true
	game.touch_active = false
	get_tree().paused = true
	overlay = CanvasLayer.new()
	overlay.layer = 150
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var background := ColorRect.new()
	background.size = Vector2(432, 960)
	background.color = Color("#0C1218", 0.99)
	overlay.add_child(background)
	var title := Label.new()
	title.text = "OUTSKIRTS - OBJECTIVES"
	title.position = Vector2(16, 18)
	title.add_theme_font_size_override("font_size", 22)
	background.add_child(title)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(335, 10)
	close.size = Vector2(80, 42)
	close.pressed.connect(close_map)
	background.add_child(close)
	full_canvas = Control.new()
	full_canvas.position = Vector2(16, 64)
	full_canvas.size = Vector2(400, 510)
	full_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_canvas.draw.connect(_draw_map.bind(full_canvas, full_canvas.size, true))
	background.add_child(full_canvas)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 586)
	scroll.size = Vector2(400, 350)
	background.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var objectives: Array = game.guidance.objectives()
	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 52
		list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _reward(str(objective["reward_icon"]))
		row.add_child(icon)
		var label := Label.new()
		label.text = "%d. %s%s\nReward: %s" % [i + 1, objective["label"], " [DONE]" if objective["done"] else "", objective["reward"]]
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", AMBER if objective["id"] == game.guidance.target.get("id", "") else Color("#E4E8E8"))
		row.add_child(label)
	print("OBJECTIVE_MAP_OPEN locations=%d" % objectives.size())

func close_map() -> void:
	expanded = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	game.touch_active = false
	get_tree().paused = false
	print("OBJECTIVE_MAP_CLOSED")

func _input(event: InputEvent) -> void:
	if expanded and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_map()
		get_viewport().set_input_as_handled()

func _reward(id: String) -> Texture2D:
	if not reward_textures.has(id):
		var path := "res://art/curated/%s.png" % id
		reward_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return reward_textures[id]

func _draw() -> void:
	if game == null or game.guidance == null:
		return
	_draw_map(self, size, false)

func _draw_map(canvas: Control, dimensions: Vector2, full: bool) -> void:
	var area := Rect2(Vector2(7, 7), dimensions - Vector2(14, 14))
	canvas.draw_rect(Rect2(Vector2.ZERO, dimensions), Color("#102028", 0.96))
	canvas.draw_rect(Rect2(Vector2.ZERO, dimensions), AMBER, false, 1.5)
	var factor := minf(area.size.x / game.MAP_SIZE.x, area.size.y / game.MAP_SIZE.y)
	var origin: Vector2 = area.position + (area.size - game.MAP_SIZE * factor) * 0.5
	if terrain_texture == null:
		var terrain := Image.create(game.MAP_W, game.MAP_H, false, Image.FORMAT_RGBA8)
		for y in range(game.MAP_H):
			for x in range(game.MAP_W):
				var ch: String = game.generated_map_rows[y].substr(x, 1)
				var tint := Color("#3C474B")
				if ch in "BCTPbJF":
					tint = Color("#10171B")
				elif ch in "ox":
					tint = Color("#635A40")
				terrain.set_pixel(x, y, tint)
		terrain_texture = ImageTexture.create_from_image(terrain)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect(terrain_texture, Rect2(origin, game.MAP_SIZE * factor), false)
	var objectives: Array = game.guidance.objectives()
	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		var point: Vector2 = origin + Vector2(objective["pos"]) * factor
		point = point.clamp(area.position + Vector2(7, 7), area.end - Vector2(7, 7))
		var current: bool = objective["id"] == game.guidance.target.get("id", "")
		var tint := Color("#698481") if objective["done"] else Color("#B2D5D3")
		if current:
			tint = AMBER
			canvas.draw_arc(point, (12.0 if full else 6.0) + 2.0 * sin(pulse_clock * 5.0), 0, TAU, 20, AMBER, 2.5)
		GUIDE.draw_icon(canvas, point, objective["kind"], 8.0 if full else 3.5, tint)
		if full:
			var text_pos := (point + Vector2(10, -6)).clamp(area.position + Vector2(4, 15), area.end - Vector2(120, 16))
			var short_name := str(objective["label"]).replace("Supply crate - ", "").replace("Infestation nest - ", "Nest ").replace("Generator - ", "").replace("Relay - ", "Relay ")
			var text := "%d %s" % [i + 1, short_name]
			canvas.draw_string_outline(ThemeDB.fallback_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, 120, 12, 3, Color.BLACK)
			canvas.draw_string(ThemeDB.fallback_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, 120, 12, tint)
			var texture := _reward(objective["reward_icon"])
			if texture != null:
				var icon_size := texture.get_size() * (14.0 / maxf(texture.get_width(), texture.get_height()))
				canvas.draw_texture_rect(texture, Rect2(point + Vector2(10, 2) + (Vector2(14, 14) - icon_size) * 0.5, icon_size), false)
	enemy_points.resize(game.enemies.size()*2)
	var ni:=0
	for enemy in game.enemies:
		var point: Vector2=origin+Vector2(enemy["pos"])*factor
		if area.has_point(point):
			enemy_points[ni]=point-Vector2(.3,0)
			enemy_points[ni+1]=point+Vector2(.3,0)
			ni+=2
	enemy_points.resize(ni)
	if ni>0: canvas.draw_multiline(enemy_points,Color("#E69A57"),2.8 if full else 1.3)

	var player: Vector2 = origin + Vector2(game.player_pos) * factor
	canvas.draw_circle(player, 4.0 if full else 3.0, Color("#5CF7AB"))
	canvas.draw_arc(player, 6.0 if full else 4.0, 0, TAU, 16, Color("#5CF7AB"), 1)
