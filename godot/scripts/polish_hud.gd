extends Control
# Presentation-only overlay: gameplay values are read, never modified.
var game: Node2D
var health_label: Label
var hp_fill: ColorRect
var hp_ghost: ColorRect
var hp_flash: ColorRect
var previous_hp := 100
var ghost_hp := 100.0
var damage_flash := 0.0
var crate_slots: Array[Label] = []
var banner_queue: Array[String] = []
var banner_age := 0.0
var banner_title: Label
var banner_subtitle: Label
var wave_label: Label
var score_label: Label
var score_title: Label
var objective_label: Label
var event_label: Label
var event_time := 0.0
var previous_event := ""
var score_display := 0.0
var backdrop: PanelContainer
var pause_menu: PanelContainer
var shake_enabled := true
const AMBER := Color("#F2A23A")
const PANEL := Color(0.08, 0.07, 0.06, 0.82)
var vibration_enabled := true
var edge_arrow_timer := 0.0

func _label(text: String, size_px: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color("#F2E8D8"))
	label.add_theme_color_override("font_outline_color", Color("#0A0806"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _panel(parent: Node, rect: Rect2, color: Color = Color(0.08, 0.07, 0.06, 0.86)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#3A322B")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := DisplayServer.get_display_safe_area()
	var screen := get_viewport_rect().size
	var left := maxf(10.0, float(safe.position.x) * screen.x / maxf(1.0, float(DisplayServer.screen_get_size().x)))
	var top := maxf(10.0, float(safe.position.y) * screen.y / maxf(1.0, float(DisplayServer.screen_get_size().y)))
	var scale_factor := screen.x / 432.0
	var root := Control.new()
	root.position = Vector2(left, top)
	root.scale = Vector2.ONE * scale_factor
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(10, 12)
	pause.size = Vector2(43, 43)
	pause.pressed.connect(_toggle_pause)
	root.add_child(pause)
	var hp_panel := _panel(root, Rect2(58, 12, 155, 44))
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(28, 12)
	hp_bg.size = Vector2(118, 20)
	hp_bg.color = Color("#3A322B")
	hp_panel.add_child(hp_bg)
	hp_ghost = ColorRect.new()
	hp_ghost.color = Color("#F2A23A")
	hp_ghost.position = hp_bg.position
	hp_ghost.size = hp_bg.size
	hp_panel.add_child(hp_ghost)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("#D93A2E")
	hp_fill.position = hp_bg.position
	hp_fill.size = hp_bg.size
	hp_panel.add_child(hp_fill)
	hp_flash = ColorRect.new()
	hp_flash.color = Color(1,1,1,0)
	hp_flash.position = hp_bg.position
	hp_flash.size = hp_bg.size
	hp_panel.add_child(hp_flash)
	health_label = _label("100 / 100", 16, hp_panel)
	health_label.position = Vector2(38, 11)
	var heart := _label("♥", 22, hp_panel)
	heart.position = Vector2(3, 7)
	heart.add_theme_color_override("font_color", Color("#D93A2E"))
	var wave_panel := _panel(root, Rect2(58, 61, 155, 34))
	wave_label = _label("WAVE 1/10", 17, wave_panel)
	wave_label.add_theme_color_override("font_color", AMBER)
	var score_panel := _panel(root, Rect2(216, 12, 90, 84), Color(0.08,0.07,0.06,0.35))
	score_title = _label("SCORE", 12, score_panel)
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_title.position = Vector2(4, 3)
	score_title.size = Vector2(82, 19)
	score_label = _label("0", 25, score_panel)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.position = Vector2(0, 25)
	score_label.size = Vector2(90, 43)
	var objective_panel := _panel(root, Rect2(12, 110, 286, 77))
	var stripe := ColorRect.new()
	stripe.color = AMBER
	stripe.position = Vector2(0, 3)
	stripe.size = Vector2(5, 71)
	objective_panel.add_child(stripe)
	var bolt := _label("⚡", 29, objective_panel)
	bolt.position = Vector2(12, 10)
	objective_label = _label("POWER THE MINI-MART GENERATOR", 15, objective_panel)
	objective_label.position = Vector2(50, 8)
	objective_label.size = Vector2(225, 40)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(3):
		var slot := _label("▣", 22, objective_panel)
		slot.position = Vector2(53 + i * 32, 47)
		crate_slots.append(slot)
	var event_panel := _panel(root, Rect2(0, 200, 432, 82), Color(0.08,0.07,0.06,0.93))
	var upper := ColorRect.new()
	upper.color = AMBER
	upper.size = Vector2(432, 3)
	event_panel.add_child(upper)
	var lower := ColorRect.new()
	lower.color = AMBER
	lower.position = Vector2(0, 79)
	lower.size = Vector2(432, 3)
	event_panel.add_child(lower)
	banner_title = _label("", 27, event_panel)
	banner_title.position = Vector2(8, 5)
	banner_title.size = Vector2(416, 43)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_color_override("font_color", AMBER)
	banner_subtitle = _label("", 15, event_panel)
	banner_subtitle.position = Vector2(8, 49)
	banner_subtitle.size = Vector2(416, 26)
	banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label = banner_title
	event_panel.visible = false
	backdrop = event_panel
	pause_menu = _panel(root, Rect2(68, 290, 296, 280))
	pause_menu.visible = false
	var menu := VBoxContainer.new()
	pause_menu.add_child(menu)
	menu.add_child(_label("PAUSED", 30, menu))
	var resume := Button.new()
	resume.text = "RESUME"
	resume.pressed.connect(_toggle_pause)
	menu.add_child(resume)
	var shake := CheckButton.new()
	shake.text = "Screen shake"
	shake.button_pressed = true
	shake.toggled.connect(func(value: bool) -> void: shake_enabled = value)
	menu.add_child(shake)
	var vibration := CheckButton.new()
	vibration.text = "Vibration"
	vibration.button_pressed = true
	vibration.toggled.connect(func(value: bool) -> void: vibration_enabled = value)
	menu.add_child(vibration)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(quit)

func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible
	process_mode = Node.PROCESS_MODE_ALWAYS

func _comma(value: int) -> String:
	var digits := str(value)
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result

func _process(delta: float) -> void:
	if game == null:
		return
	var hp: int = game.player_hp
	if hp != previous_hp:
		if hp < previous_hp:
			damage_flash = 0.1
		else:
			ghost_hp = float(hp)
		previous_hp = hp
	ghost_hp = move_toward(ghost_hp, float(hp), 120.0 * delta)
	hp_fill.size.x = 118.0 * clampf(float(hp) / 100.0, 0.0, 1.0)
	hp_ghost.size.x = 118.0 * clampf(ghost_hp / 100.0, 0.0, 1.0)
	damage_flash = maxf(0.0, damage_flash - delta)
	hp_flash.color.a = 0.65 if damage_flash > 0.0 else 0.0
	health_label.text = "%d / 100" % hp
	var remaining: int = game.enemies.size() + maxi(0, game.wave_total - game.wave_spawned)
	wave_label.text = "WAVE %d/10  ☠ %d" % [game.wave, remaining]
	score_display = move_toward(score_display, float(game.score), maxf(1.0, absf(float(game.score) - score_display) * delta / 0.3))
	score_label.text = _comma(int(score_display))
	var supplies := 0
	for cache in game.supply_caches:
		if bool(cache["collected"]):
			supplies += 1
	for i in range(crate_slots.size()):
		crate_slots[i].add_theme_color_override("font_color", Color("#6FBF4A") if i < supplies else Color("#71695E"))
	if not game.generator_active:
		objective_label.text = "POWER THE MINI-MART GENERATOR"
	elif supplies < 3:
		objective_label.text = "RECOVER THE SUPPLY CRATES"
	elif not game.puzzle_complete:
		objective_label.text = "SURVIVE THE RELAY TRAPS"
	else:
		objective_label.text = "DETONATOR CORE SECURED"
	var message: String = game.banner.text
	if message != previous_event:
		previous_event = message
		if message != "":
			banner_queue.append(message)
	if event_time <= 0.0 and not banner_queue.is_empty():
		var next: String = banner_queue.pop_front()
		var parts := next.split("\n", false, 1)
		banner_title.text = parts[0]
		banner_subtitle.text = parts[1] if parts.size() > 1 else ""
		event_time = 2.1
		banner_age = 0.0
	if event_time > 0.0:
		event_time -= delta
		banner_age += delta
		backdrop.visible = true
		backdrop.modulate.a = clampf(minf(banner_age / 0.2, event_time / 0.3), 0.0, 1.0)
	else:
		backdrop.visible = false
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var view := get_viewport_rect().size
	var scale_factor := view.x / 432.0
	var center := view * 0.5
	var targets: Array[Vector2] = []
	if not game.generator_active:
		targets.append(game.GENERATOR_POS)
	for cache in game.supply_caches:
		if not bool(cache["collected"]):
			targets.append(Vector2(cache["pos"]))
	if not game.puzzle_complete:
		for color in ["RED", "BLUE", "YELLOW"]:
			if not game.trap_finished.has(color):
				targets.append(game._relay_position(color))
	for nest in game.infestation_nests:
		if not bool(nest["destroyed"]):
			targets.append(Vector2(nest["pos"]))
	if game.district_cleared:
		targets.append(game.NORTH_EXIT.get_center())
	for target in targets:
		var offset: Vector2 = (target - game.player_pos) * game.camera.zoom
		var screen_pos := center + offset
		var margin := 32.0 * scale_factor
		var safe_rect := Rect2(Vector2(margin, 300.0 * scale_factor), view - Vector2(margin * 2.0, 360.0 * scale_factor))
		if safe_rect.has_point(screen_pos):
			continue
		var direction := offset.normalized()
		if direction.length_squared() < 0.01:
			continue
		var edge := Vector2(clampf(screen_pos.x, safe_rect.position.x, safe_rect.end.x), clampf(screen_pos.y, safe_rect.position.y, safe_rect.end.y))
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([edge + direction * 12.0 * scale_factor, edge - direction * 8.0 * scale_factor + side * 8.0 * scale_factor, edge - direction * 8.0 * scale_factor - side * 8.0 * scale_factor]), AMBER)
