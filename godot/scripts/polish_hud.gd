extends Control
# Presentation-only overlay: gameplay values are read, never modified.
var game: Node2D
var health_label: Label
var wave_label: Label
var score_label: Label
var objective_label: Label
var event_label: Label
var event_time := 0.0
var previous_event := ""
var score_display := 0.0
var backdrop: PanelContainer
var pause_menu: PanelContainer
var shake_enabled := true
var vibration_enabled := true

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
	var hp_panel := _panel(root, Rect2(62, 12, 160, 43))
	health_label = _label("♥ 100 / 100", 19, hp_panel)
	var wave_panel := _panel(root, Rect2(62, 62, 160, 34))
	wave_label = _label("WAVE 1/10", 17, wave_panel)
	var score_panel := _panel(root, Rect2(225, 12, 80, 84))
	score_label = _label("SCORE\n0", 16, score_panel)
	var objective_panel := _panel(root, Rect2(12, 110, 263, 74))
	objective_label = _label("⚡ POWER THE GENERATOR", 15, objective_panel)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var event_panel := _panel(root, Rect2(12, 197, 408, 68), Color(0.08, 0.07, 0.06, 0.91))
	event_label = _label("", 21, event_panel)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func _process(delta: float) -> void:
	if game == null:
		return
	health_label.text = "♥ %d / 100" % game.player_hp
	wave_label.text = "WAVE %d/10    ☠ %d" % [game.wave, game.enemies.size()]
	score_display = move_toward(score_display, float(game.score), maxf(1.0, absf(float(game.score) - score_display) * delta / 0.3))
	score_label.text = "SCORE\n%s" % str(int(score_display))
	var supplies := 0
	for cache in game.supply_caches:
		if cache["collected"]:
			supplies += 1
	if not game.generator_active:
		objective_label.text = "⚡ POWER THE MINI-MART GENERATOR\nSUPPLIES %d/3" % supplies
	elif supplies < 3:
		objective_label.text = "▣ RECOVER SUPPLIES %d/3" % supplies
	elif not game.puzzle_complete:
		objective_label.text = "⚠ RELAY TRAPS %d/4" % game.puzzle_step
	else:
		objective_label.text = "◆ DETONATOR CORE SECURED"
	var message: String = game.banner.text
	if message != previous_event:
		previous_event = message
		if message != "":
			event_label.text = message
			event_time = 2.1
	if event_time > 0.0:
		event_time -= delta
		backdrop.visible = true
	else:
		backdrop.visible = false
