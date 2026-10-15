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
var crate_slots: Array[Control] = []
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
var debug_tap_count := 0
var debug_tap_at := 0
var edge_arrow_timer := 0.0
var direction_label: Label
var previous_wave := 0
var crate_row: HBoxContainer
var progress_label: Label
var objective_progress: ColorRect
var objective_progress_fill: ColorRect
var countdown: Control
var countdown_label: Label
var reward_icon: TextureRect
var reward_label: Label
var missed_toast: Label
var final_stand_label: Label
var arsenal_row: HBoxContainer
var airstrike_button: Button
var reward_cache: Dictionary = {}
var arsenal_key := ""
var card_panel: PanelContainer

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
	var objective_panel := _panel(root, Rect2(8, 148, 400, 130))
	card_panel = objective_panel
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#14110F", 0.85)
	card_style.border_color = Color("#3A322B")
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(14)
	objective_panel.add_theme_stylebox_override("panel", card_style)
	var card_layer := Node2D.new()
	objective_panel.add_child(card_layer)
	var stripe := ColorRect.new()
	stripe.color = AMBER
	stripe.position = Vector2(3, 4)
	stripe.size = Vector2(8, 120)
	card_layer.add_child(stripe)
	countdown = Control.new()
	countdown.set_script(load("res://scripts/event_countdown.gd"))
	countdown.game = game
	countdown.position = Vector2(18,10)
	countdown.size = Vector2(52,52)
	card_layer.add_child(countdown)
	countdown_label = _label("45 s",18,card_layer)
	countdown_label.position = Vector2(19,62)
	countdown_label.size = Vector2(52,24)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_icon = TextureRect.new()
	reward_icon.position = Vector2(28,89)
	reward_icon.size = Vector2(34,30)
	reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_layer.add_child(reward_icon)
	# Fixed positions keep the objective card at 130px, regardless of text wrapping.
	objective_label = _label("GENERATOR OFFLINE",23,card_layer)
	objective_label.position = Vector2(82,7)
	objective_label.size = Vector2(304,31)
	objective_label.clip_text = true
	objective_icon = _label("",1,card_layer)
	objective_icon.hide()
	crate_row = HBoxContainer.new()
	crate_row.position = Vector2(82,38)
	crate_row.size = Vector2(300,27)
	crate_row.add_theme_constant_override("separation",1)
	card_layer.add_child(crate_row)
	for i in range(3):
		var crate := Control.new()
		crate.set_script(load("res://scripts/hud_crate_icon.gd"))
		crate.custom_minimum_size = Vector2(24,26)
		crate.scale = Vector2(0.6,0.75)
		crate_row.add_child(crate)
		crate_slots.append(crate)
	supplies_label = _label("SUPPLIES 0/3",22,crate_row)
	progress_label = _label("CHARGE 0%",22,card_layer)
	progress_label.position = Vector2(82,38)
	progress_label.size = Vector2(304,27)
	objective_progress = ColorRect.new()
	objective_progress.position = Vector2(82,66)
	objective_progress.size = Vector2(298,5)
	objective_progress.color = Color(AMBER,0.15)
	objective_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layer.add_child(objective_progress)
	objective_progress_fill = ColorRect.new()
	objective_progress_fill.size = Vector2(0,5)
	objective_progress_fill.color = Color(AMBER,0.8)
	objective_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_progress.add_child(objective_progress_fill)
	direction_label = _label("",18,card_layer)
	direction_label.position = Vector2(82,74)
	direction_label.size = Vector2(304,23)
	direction_label.add_theme_color_override("font_color",AMBER)
	reward_label = _label("",16,card_layer)
	reward_label.position = Vector2(82,99)
	reward_label.size = Vector2(304,23)
	reward_label.clip_text = true
	missed_toast = _label("MISSED",20,root)
	missed_toast.position = Vector2(100,330)
	missed_toast.size = Vector2(230,32)
	missed_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missed_toast.modulate = Color(1,1,1,0.7)
	missed_toast.hide()
	final_stand_label = _label("FINAL STAND IN 9 WAVES",14,root)
	final_stand_label.position = Vector2(60,99)
	final_stand_label.size = Vector2(155,20)
	final_stand_label.add_theme_color_override("font_color",AMBER)
	arsenal_row = HBoxContainer.new()
	arsenal_row.position = Vector2(12,282)
	arsenal_row.size = Vector2(288,28)
	arsenal_row.add_theme_constant_override("separation",5)
	root.add_child(arsenal_row)
	airstrike_button = Button.new()
	airstrike_button.text = "AIRSTRIKE"
	airstrike_button.position = Vector2(306,283)
	airstrike_button.size = Vector2(101,28)
	airstrike_button.add_theme_font_size_override("font_size",15)
	airstrike_button.pressed.connect(func() -> void:
		if game != null and game.events != null: game.events.arm_airstrike())
	airstrike_button.hide()
	root.add_child(airstrike_button)
	var event_panel := _panel(root, Rect2(0, 322, 412, 125), PANEL)
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
	banner_title = _label("", 52, banner_stack)
	banner_title.custom_minimum_size = Vector2(396, 58)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_color_override("font_color", AMBER)
	banner_title.add_theme_font_override("font", bebas_font if bebas_font != null else ThemeDB.fallback_font)
	banner_subtitle = _label("", 26, banner_stack)
	banner_subtitle.custom_minimum_size = Vector2(396, 32)
	var bottom_padding := Control.new()
	bottom_padding.custom_minimum_size = Vector2(396, 12)
	banner_stack.add_child(bottom_padding)
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
	shake.toggled.connect(func(value: bool) -> void: shake_enabled = value; if game != null: game.set("shake_enabled", value))
	menu.add_child(shake)
	var vibration := CheckButton.new()
	vibration.text = "Vibration"
	vibration.button_pressed = true
	vibration.toggled.connect(func(value: bool) -> void: vibration_enabled = value; if game != null: game.set("vibration_enabled", value))
	menu.add_child(vibration)
	var damage_numbers := CheckButton.new()
	damage_numbers.text = "Damage numbers"
	damage_numbers.button_pressed = true
	damage_numbers.toggled.connect(func(value: bool) -> void: if game != null: game.set("damage_numbers_enabled", value))
	menu.add_child(damage_numbers)
	var dev := Button.new()
	dev.text = "DEBUG (DEV BUILD)"
	dev.pressed.connect(func() -> void:
		if game != null and game.phase_ui != null:
			game.phase_ui.debug_panel.visible = not game.phase_ui.debug_panel.visible
			pause_menu.visible = false
			get_tree().paused = false)
	menu.add_child(dev)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(quit)

func _toggle_pause() -> void:
	var now := Time.get_ticks_msec()
	debug_tap_count = debug_tap_count + 1 if now - debug_tap_at < 1000 else 1
	debug_tap_at = now
	if debug_tap_count >= 3 and game != null and game.phase_ui != null:
		game.phase_ui.debug_tap()
		game.phase_ui.debug_tap()
		game.phase_ui.debug_tap()
		debug_tap_count = 0
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
	var max_hp := maxi(1, int(game.player_max_hp))
	hp_fill.size.x = hp_bar_width * clampf(float(hp) / float(max_hp), 0.0, 1.0)
	hp_ghost.size.x = hp_bar_width * clampf(ghost_hp / float(max_hp), 0.0, 1.0)
	damage_flash = maxf(0.0, damage_flash - delta)
	hp_flash.color.a = 0.65 if damage_flash > 0.0 else 0.0
	health_label.text = "%d / %d" % [hp, max_hp]
	var remaining: int = game.enemies.size() + maxi(0, game.wave_total - game.wave_spawned)
	wave_label.text = "WAVE %d/10  ☠ %d" % [game.wave, remaining]
	score_display = move_toward(score_display, float(game.score), maxf(1.0, absf(float(game.score) - score_display) * delta / 0.3))
	score_label.text = _comma(int(score_display))
	var score_font: Font = bebas_font if bebas_font != null else ThemeDB.fallback_font
	var score_size := 56
	while score_size > 26 and score_font.get_string_size(score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size).x > 84.0:
		score_size -= 2
	score_label.add_theme_font_size_override("font_size", score_size)
	_update_event_card()
	if previous_wave != game.wave:
		previous_wave = game.wave
		banner_queue.clear()
		event_time = 0.0
		previous_event = ""
	if event_time > 0.0 and banner_title.text.begins_with("WAVE ") and not "CLEARED" in banner_title.text and game.guidance != null:
		banner_subtitle.text = game.guidance.label_text()
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
		if headline.begins_with("EVENT: "):
			headline = headline.trim_prefix("EVENT: ")
		elif headline.begins_with("WAVE ") and not "CLEARED" in headline:
			headline = "WAVE %d: THE HORDE IS HERE" % game.wave
			detail = game.guidance.label_text() if game.guidance != null else detail
		if headline.length() > 28:
			var split_at := headline.rfind(" ", 28)
			if split_at < 8:
				split_at = 28
			detail = headline.substr(split_at).strip_edges() + (" · " + detail if detail != "" else "")
			headline = headline.substr(0, split_at).strip_edges()
		banner_title.text = headline
		var font_for_title: Font = bebas_font if bebas_font != null else ThemeDB.fallback_font
		var title_size := 52
		while title_size > 24 and font_for_title.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 390.0:
			title_size -= 2
		banner_title.add_theme_font_size_override("font_size", title_size)
		banner_subtitle.text = detail
		var detail_font: Font = barlow_font if barlow_font != null else ThemeDB.fallback_font
		var detail_size := 26
		while detail_size > 16 and detail_font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_size).x > 390.0:
			detail_size -= 1
		banner_subtitle.add_theme_font_size_override("font_size", detail_size)
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

func _reward_texture(id: String) -> Texture2D:
	if not reward_cache.has(id):
		var path := "res://art/curated/%s.png" % id
		reward_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return reward_cache[id]

func _update_event_card() -> void:
	if game.events == null: return
	var ev: Node2D = game.events
	var offered: bool = not ev.active.is_empty()
	crate_row.visible = offered and ev.kind() == "supplies"
	progress_label.visible = not crate_row.visible
	progress_label.text = ev.progress_text()
	var progress_font: Font = barlow_font if barlow_font != null else ThemeDB.fallback_font
	var progress_size := 22
	while progress_size > 14 and progress_font.get_string_size(progress_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,progress_size).x > 301:
		progress_size -= 1
	progress_label.add_theme_font_size_override("font_size",progress_size)
	objective_progress.visible = offered and ev.kind() in ["nest","generator","relay"]
	objective_progress_fill.size.x = objective_progress.size.x * clampf(ev.progress_ratio(),0.0,1.0)
	countdown.visible = offered
	countdown_label.visible = offered
	countdown_label.text = "%d s" % ceili(ev.remaining())
	reward_icon.visible = offered
	reward_icon.texture = _reward_texture(str(ev.active["reward_icon"])) if offered else null
	reward_label.text = "REWARD: " + str(ev.active["reward"]) if offered else "OPTIONAL EVENTS - WAVES KEEP MOVING"
	objective_label.text = str(ev.active["title"]) if offered else ("FINAL STAND" if game.wave == 10 else "SURVIVE THE HORDE")
	if crate_row.visible:
		var count: int = ev.active["step"]
		for i in range(crate_slots.size()):
			crate_slots[i].set("collected",i < count)
			crate_slots[i].queue_redraw()
		supplies_label.text = "SUPPLIES %d/3" % count
	if offered and game.guidance != null and not game.guidance.target.is_empty():
		var direction: Vector2 = game.guidance.direction_vector()
		var arrows := ["E","SE","S","SW","W","NW","N","NE"]
		var index := posmod(roundi(direction.angle()/(PI/4.0)),8)
		direction_label.text = "%d m %s | TAP MAP" % [game.guidance.distance_metres(),arrows[index]]
	else:
		direction_label.text = "NEXT OFFER NEXT WAVE" if game.wave < 9 else "USE YOUR ARSENAL"
	missed_toast.visible = ev.toast_left > 0.0
	missed_toast.text = ev.toast_text
	if ev.toast_left > 0.0:
		banner_queue.clear()
		event_time = 0.0
		previous_event = game.banner.text
	final_stand_label.text = "FINAL STAND IN %d WAVES" % (10-game.wave) if game.wave < 10 else "FINAL STAND: %d s" % ceili(maxf(0.0,game._wave_duration()-game.wave_clock))
	airstrike_button.visible = game.wave == 10 and ev.earned.has("airstrike")
	airstrike_button.text = "TAP TARGET" if ev.aiming else "AIRSTRIKE"
	var key: String = str(ev.earned.keys())
	if key != arsenal_key:
		arsenal_key = key
		for child in arsenal_row.get_children():
			arsenal_row.remove_child(child)
			child.queue_free()
		if not ev.earned.is_empty(): _label("ARSENAL",15,arsenal_row)
		var icons := {"auto_turret":"icon_attack_drone","floodlights":"icon_arsenal_floodlights","chest":"icon_chest","big_chest":"icon_chest","nuke":"icon_pickup_nuke","flamethrower":"icon_molotov","motel_lockdown":"icon_arsenal_nest_down","xp_shower":"icon_pickup_magnet","airstrike":"icon_arsenal_airstrike","fewer_spawns":"icon_arsenal_nest_down"}
		for reward in ev.earned:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(20,24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = _reward_texture(str(icons[reward]))
			arsenal_row.add_child(icon)

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
	var top_edge := maxf(inset_min.y + margin, (10.0 + 285.0) * view.x / 432.0 + margin)
	var bottom_edge := view.y - inset_max.y - margin
	var safe_rect := Rect2(Vector2(inset_min.x + margin, top_edge), Vector2(view.x - inset_min.x - inset_max.x - margin * 2.0, maxf(1.0, bottom_edge - top_edge)))
	var center := safe_rect.get_center()
	if game.guidance != null and not game.guidance.target.is_empty():
		_draw_edge_arrow(game.guidance.target["pos"], AMBER, "!", safe_rect, center, game.camera.zoom)
	var runner_arrows := 0
	for enemy in game.enemies:
		if str(enemy["kind"]) != "runner":
			continue
		_draw_edge_arrow(Vector2(enemy["pos"]), Color("#D93A2E"), "!", safe_rect, center, game.camera.zoom)
		runner_arrows += 1
		if runner_arrows >= 3:
			break
