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
var crate_slots: Array[ColorRect] = []
var supplies_label: Label
var objective_icon: Label
var hp_bar_width := 118.0
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
const PANEL := Color("#14110F", 0.75)
const BEBAS_PATH := "res://art/fonts/BebasNeue-Regular.ttf"
const BARLOW_PATH := "res://art/fonts/BarlowCondensed-SemiBold.ttf"
var bebas_font: Font
var barlow_font: Font
var vibration_enabled := true
var edge_arrow_timer := 0.0

func _label(text: String, size_px: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_font_override("font", barlow_font if barlow_font != null else ThemeDB.fallback_font)
	label.add_theme_color_override("font_color", Color("#F2E8D8"))
	label.add_theme_color_override("font_outline_color", Color("#0A0806"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _panel(parent: Node, rect: Rect2, color: Color = PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#3A322B")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _ready() -> void:
	if ResourceLoader.exists(BEBAS_PATH):
		bebas_font = load(BEBAS_PATH)
	if ResourceLoader.exists(BARLOW_PATH):
		barlow_font = load(BARLOW_PATH)
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
	var hud_theme := Theme.new()
	if barlow_font != null:
		hud_theme.default_font = barlow_font
	root.theme = hud_theme
	add_child(root)
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(10, 12)
	pause.size = Vector2(43, 43)
	pause.pressed.connect(_toggle_pause)
	root.add_child(pause)
	var hp_panel := _panel(root, Rect2(58, 12, 155, 44))
	var hp_layer := Node2D.new()
	hp_panel.add_child(hp_layer)
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(28, 12)
	hp_bg.size = Vector2(118, 20)
	hp_bg.color = Color("#3A322B")
	hp_layer.add_child(hp_bg)
	hp_bar_width = hp_bg.size.x
	hp_ghost = ColorRect.new()
	hp_ghost.color = Color("#F2A23A")
	hp_ghost.position = hp_bg.position
	hp_ghost.size = hp_bg.size
	hp_layer.add_child(hp_ghost)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("#D93A2E")
	hp_fill.position = hp_bg.position
	hp_fill.size = hp_bg.size
	hp_layer.add_child(hp_fill)
	hp_flash = ColorRect.new()
	hp_flash.color = Color(1,1,1,0)
	hp_flash.position = hp_bg.position
	hp_flash.size = hp_bg.size
	hp_layer.add_child(hp_flash)
	health_label = _label("100 / 100", 16, hp_panel)
	health_label.position = Vector2(28, 9)
	health_label.size = Vector2(118, 24)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_override("font", bebas_font if bebas_font != null else ThemeDB.fallback_font)
	var heart := _label("♥", 22, hp_panel)
	heart.position = Vector2(0, 7)
	heart.add_theme_color_override("font_color", Color("#D93A2E"))
	var wave_panel := _panel(root, Rect2(58, 61, 155, 34))
	wave_label = _label("WAVE 1/10", 17, wave_panel)
	wave_label.add_theme_color_override("font_color", AMBER)
	wave_label.add_theme_font_override("font", bebas_font if bebas_font != null else ThemeDB.fallback_font)
	var score_panel := _panel(root, Rect2(216, 12, 90, 100))
	var score_stack := VBoxContainer.new()
	score_stack.position = Vector2(3, 3)
	score_stack.size = Vector2(84, 94)
	score_stack.add_theme_constant_override("separation", 0)
	score_panel.add_child(score_stack)
	score_title = _label("SCORE", 22, score_stack)
	score_title.custom_minimum_size = Vector2(84, 29)
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = _label("0", 56, score_stack)
	score_label.custom_minimum_size = Vector2(84, 65)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_override("font", bebas_font if bebas_font != null else ThemeDB.fallback_font)
	var objective_panel := _panel(root, Rect2(8, 118, 298, 116))
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PANEL
	card_style.border_color = Color("#3A322B")
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(14)
	objective_panel.add_theme_stylebox_override("panel", card_style)
	var card_layer := Node2D.new()
	objective_panel.add_child(card_layer)
	var stripe := ColorRect.new()
	stripe.color = AMBER
	stripe.position = Vector2(3, 4)
	stripe.size = Vector2(8, 108)
	card_layer.add_child(stripe)
	var content := HBoxContainer.new()
	content.position = Vector2(19, 9)
	content.size = Vector2(258, 98)
	content.add_theme_constant_override("separation", 16)
	card_layer.add_child(content)
	objective_icon = _label("⚡", 30, content)
	objective_icon.custom_minimum_size = Vector2(48, 48)
	objective_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(194, 96)
	stack.add_theme_constant_override("separation", 3)
	content.add_child(stack)
	objective_label = _label("POWER THE MINI-MART GENERATOR", 15, stack)
	objective_label.custom_minimum_size = Vector2(194, 52)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var crates := HBoxContainer.new()
	crates.add_theme_constant_override("separation", 1)
	stack.add_child(crates)
	for i in range(3):
		var crate := ColorRect.new()
		crate.custom_minimum_size = Vector2(40, 34)
		crate.color = Color("#3C342C")
		crates.add_child(crate)
		crate_slots.append(crate)
	supplies_label = _label("SUPPLIES 0/3", 12, crates)
	supplies_label.custom_minimum_size = Vector2(70, 34)
	var event_panel := _panel(root, Rect2(0, 245, 412, 125), PANEL)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = PANEL
	banner_style.border_color = Color("#3A322B")
	banner_style.set_border_width_all(3)
	banner_style.set_corner_radius_all(14)
	event_panel.add_theme_stylebox_override("panel", banner_style)
	var banner_layer := Node2D.new()
	event_panel.add_child(banner_layer)
	for y in [3, 117]:
		var edge := ColorRect.new()
		edge.color = AMBER
		edge.position = Vector2(3, y)
		edge.size = Vector2(406, 5)
		banner_layer.add_child(edge)
	var banner_stack := VBoxContainer.new()
	banner_stack.position = Vector2(8, 11)
	banner_stack.size = Vector2(396, 104)
	banner_stack.add_theme_constant_override("separation", 0)
	banner_layer.add_child(banner_stack)
	banner_title = _label("", 64, banner_stack)
	banner_title.custom_minimum_size = Vector2(396, 68)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_color_override("font_color", AMBER)
	banner_title.add_theme_font_override("font", bebas_font if bebas_font != null else ThemeDB.fallback_font)
	banner_subtitle = _label("", 30, banner_stack)
	banner_subtitle.custom_minimum_size = Vector2(396, 36)
	banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label = banner_title
	event_panel.visible = false
	backdrop = event_panel
	pause_menu = _panel(root, Rect2(68, 290, 296, 280))
	pause_menu.visible = false
	var menu := VBoxContainer.new()
	pause_menu.add_child(menu)
	_label("PAUSED", 30, menu)
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
	hp_fill.size.x = hp_bar_width * clampf(float(hp) / 100.0, 0.0, 1.0)
	hp_ghost.size.x = hp_bar_width * clampf(ghost_hp / 100.0, 0.0, 1.0)
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
		crate_slots[i].color = Color("#6FBF4A") if i < supplies else Color("#3C342C")
	supplies_label.text = "SUPPLIES %d/3" % supplies
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
		var headline: String = parts[0]
		var detail: String = parts[1] if parts.size() > 1 else ""
		if headline.length() > 28:
			var split_at := headline.rfind(" ", 28)
			if split_at < 8:
				split_at = 28
			detail = headline.substr(split_at).strip_edges() + (" · " + detail if detail != "" else "")
			headline = headline.substr(0, split_at).strip_edges()
		banner_title.text = headline
		var font_for_title: Font = bebas_font if bebas_font != null else ThemeDB.fallback_font
		var title_size := 64
		while title_size > 40 and font_for_title.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 390.0:
			title_size -= 2
		banner_title.add_theme_font_size_override("font_size", title_size)
		banner_subtitle.text = detail
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

func _draw_edge_arrow(target: Vector2, color: Color, symbol: String, safe_rect: Rect2, center: Vector2, zoom: Vector2) -> void:
	var offset: Vector2 = (target - game.player_pos) * zoom
	var screen_pos := center + offset
	if safe_rect.has_point(screen_pos):
		return
	if offset.length_squared() < 0.001:
		return
	var direction := offset.normalized()
	var t := INF
	if direction.x > 0.001:
		t = minf(t, (safe_rect.end.x - center.x) / direction.x)
	elif direction.x < -0.001:
		t = minf(t, (safe_rect.position.x - center.x) / direction.x)
	if direction.y > 0.001:
		t = minf(t, (safe_rect.end.y - center.y) / direction.y)
	elif direction.y < -0.001:
		t = minf(t, (safe_rect.position.y - center.y) / direction.y)
	var edge: Vector2 = center + direction * maxf(0.0, t)
	edge = edge.clamp(safe_rect.position, safe_rect.end)
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([edge + direction * 12.0, edge - direction * 9.0 + side * 8.0, edge - direction * 9.0 - side * 8.0]), color)
	draw_circle(edge - direction * 17.0, 9.0, Color("#14110F"))
	draw_string(barlow_font if barlow_font != null else ThemeDB.fallback_font, edge - direction * 17.0 + Vector2(-5, 5), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _draw() -> void:
	if game == null:
		return
	var view := get_viewport_rect().size
	var display_size := DisplayServer.screen_get_size()
	var physical_safe := DisplayServer.get_display_safe_area()
	var sx := view.x / maxf(1.0, float(display_size.x))
	var sy := view.y / maxf(1.0, float(display_size.y))
	var inset_min := Vector2(float(physical_safe.position.x) * sx, float(physical_safe.position.y) * sy)
	var inset_max := Vector2(float(display_size.x - physical_safe.end.x) * sx, float(display_size.y - physical_safe.end.y) * sy)
	var margin := 22.0 * view.x / 432.0
	var top_edge := maxf(inset_min.y + margin, (10.0 + 234.0) * view.x / 432.0 + margin)
	var bottom_edge := view.y - inset_max.y - margin
	var safe_rect := Rect2(Vector2(inset_min.x + margin, top_edge), Vector2(view.x - inset_min.x - inset_max.x - margin * 2.0, maxf(1.0, bottom_edge - top_edge)))
	var center := safe_rect.get_center()
	var target: Vector2 = game.GENERATOR_POS
	var icon := "⚡"
	var found: bool = not game.generator_active
	if not found:
		for cache in game.supply_caches:
			if not bool(cache["collected"]):
				target = Vector2(cache["pos"])
				icon = "▣"
				found = true
				break
	if not found:
		for nest in game.infestation_nests:
			if not bool(nest["destroyed"]):
				target = Vector2(nest["pos"])
				icon = "!"
				found = true
				break
	if not found and not game.puzzle_complete:
		for color in ["RED", "BLUE", "YELLOW"]:
			if not game.trap_finished.has(color):
				target = game._relay_position(color)
				icon = "!"
				found = true
				break
	if not found and game.district_cleared:
		target = game.NORTH_EXIT.get_center()
		icon = "◆"
		found = true
	if found:
		_draw_edge_arrow(target, AMBER, icon, safe_rect, center, game.camera.zoom)
	var runner_arrows := 0
	for enemy in game.enemies:
		if str(enemy["kind"]) != "runner":
			continue
		_draw_edge_arrow(Vector2(enemy["pos"]), Color("#D93A2E"), "!", safe_rect, center, game.camera.zoom)
		runner_arrows += 1
		if runner_arrows >= 3:
			break
