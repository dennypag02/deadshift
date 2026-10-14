extends Control
var game: Node2D
var progression: Node2D
var panel: PanelContainer
var debug_panel: PanelContainer
var cards: Array[PanelContainer] = []
var card_wrappers: Array[Control] = []
var card_buttons: Array[Button] = []
var card_icons: Array[ColorRect] = []
var card_names: Array[Label] = []
var card_pips: Array[Label] = []
var card_descs: Array[Label] = []
var card_badges: Array[PanelContainer] = []
var card_badge_labels: Array[Label] = []
var card_styles: Array[StyleBoxFlat] = []
var card_rarities: Array[String] = []
var reroll_button: Button
var banish_button: Button
var xp_track: ColorRect
var xp_fill: ColorRect
var xp_glow: ColorRect
var level_badge: Label
var xp_flash := 0.0
var xp_glow_clock := 0.0
var last_level := 1
var current_choices: Array[String] = []
var banish_mode := false
var pause_taps := 0
var last_pause_tap := 0
var god_mode := false
var debug_stats: Label
var barlow_font: Font
var bebas_font: Font
var capture_mode := false
var capture_start_msec := 0
var capture_title: ColorRect

const CYAN := Color("#3FD0E0")
const TRACK := Color("#2A3A40")
const DARK := Color("#14110F")
const AMBER := Color("#F2A23A")
const COMMON := Color("#8A8A8A")
const RARE := Color("#3D8BFF")
const EPIC := Color("#A060FF")
const LEGENDARY := Color("#F2C14E")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scale_factor := get_viewport_rect().size.x / 432.0
	scale = Vector2.ONE * scale_factor
	barlow_font = load("res://art/fonts/BarlowCondensed-SemiBold.ttf")
	bebas_font = load("res://art/fonts/BebasNeue-Regular.ttf")
	capture_mode = OS.get_cmdline_user_args().has("--pacing-capture")
	_build_xp_bar()
	_build_levelup()
	_build_debug()
	progression.level_up_requested.connect(_show_choices)
	last_level = progression.level
	if capture_mode:
		_start_capture_title()

func _start_capture_title() -> void:
	get_tree().paused = true
	capture_title = ColorRect.new()
	capture_title.color = Color("#090B0C")
	capture_title.position = Vector2.ZERO
	capture_title.size = Vector2(432, 960)
	capture_title.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(capture_title)
	var title := Label.new()
	title.text = "DEADSHIFT"
	title.position = Vector2(36, 385)
	title.size = Vector2(360, 95)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("#F2E8D8"))
	if bebas_font != null:
		title.add_theme_font_override("font", bebas_font)
	capture_title.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "OUTSKIRTS"
	subtitle.position = Vector2(36, 475)
	subtitle.size = Vector2(360, 45)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", AMBER)
	if barlow_font != null:
		subtitle.add_theme_font_override("font", barlow_font)
	capture_title.add_child(subtitle)
	_finish_capture_title()

func _finish_capture_title() -> void:
	await get_tree().create_timer(1.6, true, false, true).timeout
	if capture_title != null:
		capture_title.queue_free()
	capture_start_msec = Time.get_ticks_msec()
	print("PACING_CAPTURE_GAMEPLAY_START")
	get_tree().paused = false

func _capture_elapsed() -> float:
	if capture_start_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - capture_start_msec) / 1000.0

func _capture_auto_pick() -> void:
	await get_tree().create_timer(0.65, true, false, true).timeout
	if capture_mode and panel.visible and not current_choices.is_empty():
		_pick(0)

func _build_xp_bar() -> void:
	xp_glow = ColorRect.new()
	xp_glow.position = Vector2(5, 129)
	xp_glow.size = Vector2(422, 26)
	xp_glow.color = Color(CYAN, 0.18)
	xp_glow.visible = false
	xp_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_glow)

	xp_track = ColorRect.new()
	xp_track.position = Vector2(8, 132)
	xp_track.size = Vector2(416, 20)
	xp_track.color = TRACK
	xp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_track)

	xp_fill = ColorRect.new()
	xp_fill.position = Vector2(8, 132)
	xp_fill.size = Vector2(0, 20)
	xp_fill.color = CYAN
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_fill)

	var badge := PanelContainer.new()
	badge.position = Vector2(8, 127)
	badge.size = Vector2(52, 30)
	var bs := StyleBoxFlat.new()
	bs.bg_color = DARK
	bs.border_color = CYAN
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(7)
	badge.add_theme_stylebox_override("panel", bs)
	add_child(badge)
	level_badge = Label.new()
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge.add_theme_font_size_override("font_size", 18)
	if barlow_font != null:
		level_badge.add_theme_font_override("font", barlow_font)
	badge.add_child(level_badge)

func _build_levelup() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(12, 165)
	panel.size = Vector2(408, 720)
	panel.visible = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#0E0D0C", 0.98)
	ps.border_color = CYAN
	ps.set_border_width_all(4)
	ps.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)

	var heading := Label.new()
	heading.text = "LEVEL UP!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size = Vector2(390, 60)
	heading.add_theme_font_size_override("font_size", 34)
	if bebas_font != null:
		heading.add_theme_font_override("font", bebas_font)
	stack.add_child(heading)

	for i in range(3):
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(390, 120)
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(wrapper)
		card_wrappers.append(wrapper)

		var card := PanelContainer.new()
		card.position = Vector2.ZERO
		card.size = Vector2(390, 120)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color("#191A1C")
		cs.border_color = COMMON
		cs.set_border_width_all(3)
		cs.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", cs)
		wrapper.add_child(card)
		cards.append(card)
		card_styles.append(cs)
		card_rarities.append("COMMON")

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.color = Color("#6B747C")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		card_icons.append(icon)

		var text_stack := VBoxContainer.new()
		text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_stack.add_theme_constant_override("separation", 2)
		row.add_child(text_stack)

		var top_line := HBoxContainer.new()
		top_line.add_theme_constant_override("separation", 7)
		text_stack.add_child(top_line)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 16)
		if bebas_font != null:
			name_label.add_theme_font_override("font", bebas_font)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_line.add_child(name_label)
		card_names.append(name_label)

		var new_badge := PanelContainer.new()
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = AMBER
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 5
		badge_style.content_margin_right = 5
		badge_style.content_margin_top = 1
		badge_style.content_margin_bottom = 1
		new_badge.add_theme_stylebox_override("panel", badge_style)
		top_line.add_child(new_badge)
		card_badges.append(new_badge)

		var badge_label := Label.new()
		badge_label.text = "NEW"
		badge_label.add_theme_font_size_override("font_size", 9)
		badge_label.add_theme_color_override("font_color", DARK)
		if barlow_font != null:
			badge_label.add_theme_font_override("font", barlow_font)
		new_badge.add_child(badge_label)
		card_badge_labels.append(badge_label)

		var pips_label := Label.new()
		pips_label.add_theme_font_size_override("font_size", 10)
		pips_label.add_theme_color_override("font_color", Color("#D9E3E8"))
		if barlow_font != null:
			pips_label.add_theme_font_override("font", barlow_font)
		pips_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_stack.add_child(pips_label)
		card_pips.append(pips_label)

		var desc_label := Label.new()
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color("#F2E8D8"))
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if barlow_font != null:
			desc_label.add_theme_font_override("font", barlow_font)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_stack.add_child(desc_label)
		card_descs.append(desc_label)

		var click := Button.new()
		click.set_anchors_preset(Control.PRESET_FULL_RECT)
		click.text = ""
		click.focus_mode = Control.FOCUS_NONE
		var clear_style := StyleBoxEmpty.new()
		click.add_theme_stylebox_override("normal", clear_style)
		click.add_theme_stylebox_override("hover", clear_style)
		click.add_theme_stylebox_override("pressed", clear_style)
		click.add_theme_stylebox_override("focus", clear_style)
		click.pressed.connect(_pick.bind(i))
		card.add_child(click)
		card_buttons.append(click)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	for label in ["REROLL", "BANISH"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(150, 54)
		if label == "REROLL":
			reroll_button = b
			b.pressed.connect(_reroll)
		else:
			banish_button = b
			b.pressed.connect(_banish)
		actions.add_child(b)

func _build_debug() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(12, 190)
	debug_panel.size = Vector2(408, 760)
	debug_panel.visible = false
	add_child(debug_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 748)
	debug_panel.add_child(scroll)
	var dbg := VBoxContainer.new()
	dbg.custom_minimum_size.x = 380
	scroll.add_child(dbg)
	debug_stats = Label.new()
	debug_stats.add_theme_font_size_override("font_size", 16)
	if barlow_font != null:
		debug_stats.add_theme_font_override("font", barlow_font)
	dbg.add_child(debug_stats)
	for command in [
		"TEST 6 SHAMBLER KILLS", "XP +100", "LEVEL +1",
		"SMG +1", "BOOMSTICK +1", "MOLOTOV +1", "BUZZSAW +1", "LIGHTNING +1", "ROCKET +1", "DRONE +1", "CHAKRAM +1",
		"MUSCLE +1", "AMMO BELT +1", "TRIGGER +1", "BATTERY +1", "BLAST +1", "FUEL +1", "BALL BEARINGS +1", "MAGNET +1", "THICK HIDE +1", "SHARP EDGE +1", "RABBIT FOOT +1",
		"SPAWN SHAMBLER", "SPAWN RUNNER", "SPAWN 20", "WAVE +1",
		"GOD MODE", "SPEED 0.5", "SPEED 1", "SPEED 2", "SPEED 4", "CLOSE"
	]:
		var b := Button.new()
		b.text = command
		b.custom_minimum_size.y = 48
		b.pressed.connect(_debug_action.bind(command))
		dbg.add_child(b)

func _rarity_color(rarity: String) -> Color:
	match rarity.to_upper():
		"RARE":
			return RARE
		"EPIC":
			return EPIC
		"LEGENDARY":
			return LEGENDARY
		_:
			return COMMON

func _placeholder_icon_color(id: String, _rarity: String) -> Color:
	match id:
		"scrap_smg":
			return Color("#3FD0E0")
		"boomstick":
			return Color("#F28C3A")
		"molotov":
			return Color("#F26A2E")
		"buzzsaw":
			return Color("#B8C4CA")
		"lightning":
			return Color("#73E9FF")
		"rocket":
			return Color("#D96D45")
		"drone":
			return Color("#8DD4D8")
		"chakram":
			return Color("#DDE4E7")
		"muscle":
			return Color("#D95A4E")
		"ammo_belt":
			return Color("#9BAA55")
		"trigger_finger":
			return Color("#F2C14E")
		"battery_pack":
			return Color("#9CEB74")
		"blast_radius":
			return Color("#E66D3B")
		"fuel_tank":
			return Color("#F08A38")
		"ball_bearings":
			return Color("#BFC6CE")
		"magnet":
			return Color("#5BA9FF")
		"thick_hide":
			return Color("#6E7FAE")
		"sharpened_edge":
			return Color("#D7DDE1")
		"rabbit_foot":
			return Color("#B78BFF")
		"fallback_gold":
			return Color("#F2C14E")
		"fallback_heal":
			return Color("#66D983")
		_:
			return Color("#8A8A8A")

func _show_choices() -> void:
	get_tree().paused = true
	panel.visible = true
	banish_mode = false
	_refresh_choices()
	_animate_cards_in()
	if capture_mode:
		print("PACING_LEVEL_UP level=%d t=%.2f" % [progression.level, _capture_elapsed()])
		_capture_auto_pick()

func _animate_cards_in() -> void:
	for i in range(cards.size()):
		var card := cards[i]
		card.position = Vector2(0, 32)
		card.modulate = Color(1, 1, 1, 0)
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(float(i) * 0.08)
		tween.set_parallel(true)
		tween.tween_property(card, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate", Color.WHITE, 0.18)

func _refresh_choices() -> void:
	current_choices = progression.available_choices()
	for i in range(cards.size()):
		var visible := i < current_choices.size()
		card_wrappers[i].visible = visible
		card_buttons[i].disabled = not visible
		if not visible:
			continue
		var id := current_choices[i]
		var rarity := progression.choice_rarity(id)
		var item: Dictionary = {}
		var current := 0
		var target := 0
		var max_level := 0
		var pips := ""
		var addition := ""
		var is_fallback := progression.config.get("fallbacks", {}).has(id)
		if is_fallback:
			item = progression.config["fallbacks"][id]
			addition = str(item.get("description", "Fallback"))
		else:
			var category: Dictionary = progression.config["weapons"] if progression.config["weapons"].has(id) else progression.config["passives"]
			item = category[id]
			current = int(progression.weapons.get(id, progression.passives.get(id, 0)))
			target = current + 1
			max_level = int(item.get("max_level", 5))
			for p in range(max_level):
				pips += "●" if p < target else "○"
			var level_adds: Array = item.get("level_adds", [])
			addition = str(level_adds[target - 1]) if target - 1 < level_adds.size() else str(item.get("description", "Upgrade"))
		card_rarities[i] = rarity
		card_styles[i].border_color = _rarity_color(rarity)
		card_icons[i].color = _placeholder_icon_color(id, rarity)
		card_names[i].text = str(item["name"])
		card_pips[i].text = ("%s   %s" % [pips, rarity]).strip_edges()
		card_descs[i].text = addition if is_fallback else "%s LV %d: %s" % [item["name"], target, addition]
		card_badges[i].visible = (not is_fallback) and current == 0
		card_buttons[i].set_meta("upgrade", id)

func _animate_choice(index: int) -> void:
	for button in card_buttons:
		button.disabled = true
	var chosen := cards[index]
	var flash := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flash.tween_property(chosen, "modulate", Color(1.45, 1.45, 1.45, 1.0), 0.08)
	flash.tween_property(chosen, "modulate", Color.WHITE, 0.10)
	for i in range(cards.size()):
		if i == index or not card_wrappers[i].visible:
			continue
		var fly := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		var target_x := -450.0 if i < index else 450.0
		fly.set_parallel(true)
		fly.tween_property(cards[i], "position:x", target_x, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		fly.tween_property(cards[i], "modulate:a", 0.0, 0.18)
	await flash.finished

func _pick(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	var id := current_choices[index]
	if banish_mode:
		if progression.banish(id):
			banish_mode = false
			_refresh_choices()
			_animate_cards_in()
		return
	await _animate_choice(index)
	panel.visible = false
	progression.choose(id)
	if progression.choosing:
		panel.visible = true
		get_tree().paused = true
		_refresh_choices()
		_animate_cards_in()
	else:
		progression.resume_after_levelup()
		get_tree().paused = false

func _reroll() -> void:
	if progression.use_reroll():
		_refresh_choices()
		_animate_cards_in()

func _banish() -> void:
	if progression.banishes_left <= 0:
		return
	banish_mode = true
	for i in range(card_descs.size()):
		if card_wrappers[i].visible:
			card_descs[i].text = "Tap this card to banish it for this run"

func _process(delta: float) -> void:
	if progression == null or progression.config.is_empty():
		return
	level_badge.text = "LV %d" % progression.level
	var needed := maxi(1, progression.xp_required(progression.level))
	var ratio := clampf(float(progression.xp) / float(needed), 0.0, 1.0)
	xp_fill.size.x = 416.0 * ratio
	if progression.level != last_level:
		last_level = progression.level
		xp_flash = 0.34
	xp_flash = maxf(0.0, xp_flash - delta)
	if xp_flash > 0.0:
		var flash_t := clampf(xp_flash / 0.34, 0.0, 1.0)
		xp_fill.color = CYAN.lerp(Color.WHITE, flash_t)
	else:
		xp_fill.color = CYAN
	xp_glow_clock += delta
	xp_glow.visible = ratio >= 0.80 and xp_flash <= 0.0
	if xp_glow.visible:
		var glow_alpha := 0.10 + 0.14 * (0.5 + 0.5 * sin(xp_glow_clock * 7.0))
		xp_glow.color = Color(CYAN, glow_alpha)
	for i in range(cards.size()):
		if card_wrappers[i].visible and card_rarities[i] == "LEGENDARY":
			var shimmer := 0.35 + 0.35 * (0.5 + 0.5 * sin(xp_glow_clock * 5.0 + float(i)))
			card_styles[i].border_color = LEGENDARY.lerp(Color.WHITE, shimmer)
	if reroll_button != null:
		reroll_button.text = "REROLL (%d)" % progression.rerolls_left
		reroll_button.disabled = progression.rerolls_left <= 0
	if banish_button != null:
		banish_button.text = "BANISH (%d)" % progression.banishes_left
		banish_button.disabled = progression.banishes_left <= 0
	if debug_stats != null and debug_panel.visible:
		debug_stats.text = "FPS %d   ENEMIES %d   PROJECTILES %d   GEMS %d\nLV %d  XP %d/%d  GOD %s  TIME %.1fx" % [
			Engine.get_frames_per_second(), game.enemies.size(), game.bullets.size(), progression.gems.size(),
			progression.level, progression.xp, needed, "ON" if god_mode else "OFF", Engine.time_scale
		]

func _grant_upgrade(id: String) -> void:
	progression.debug_grant(id)
	progression.pending_levels = 0
	progression.choosing = false
	panel.visible = false
	get_tree().paused = false

func _debug_action(command: String) -> void:
	match command:
		"TEST 6 SHAMBLER KILLS":
			debug_panel.visible = false
			game.phase_a_debug_six_shambler_kills()
		"XP +100":
			progression.add_xp(100)
		"LEVEL +1":
			progression.add_xp(progression.xp_required(progression.level))
		"SMG +1": _grant_upgrade("scrap_smg")
		"BOOMSTICK +1": _grant_upgrade("boomstick")
		"MOLOTOV +1": _grant_upgrade("molotov")
		"BUZZSAW +1": _grant_upgrade("buzzsaw")
		"LIGHTNING +1": _grant_upgrade("lightning")
		"ROCKET +1": _grant_upgrade("rocket")
		"DRONE +1": _grant_upgrade("drone")
		"CHAKRAM +1": _grant_upgrade("chakram")
		"MUSCLE +1": _grant_upgrade("muscle")
		"AMMO BELT +1": _grant_upgrade("ammo_belt")
		"TRIGGER +1": _grant_upgrade("trigger_finger")
		"BATTERY +1": _grant_upgrade("battery_pack")
		"BLAST +1": _grant_upgrade("blast_radius")
		"FUEL +1": _grant_upgrade("fuel_tank")
		"BALL BEARINGS +1": _grant_upgrade("ball_bearings")
		"MAGNET +1": _grant_upgrade("magnet")
		"THICK HIDE +1": _grant_upgrade("thick_hide")
		"SHARP EDGE +1": _grant_upgrade("sharpened_edge")
		"RABBIT FOOT +1": _grant_upgrade("rabbit_foot")
		"SPAWN SHAMBLER":
			game.enemies.append({"pos":game.player_pos + Vector2(220,0), "kind":"shambler", "hp":1, "speed":108.0, "radius":18.0, "charge":0.0})
		"SPAWN RUNNER":
			game.enemies.append({"pos":game.player_pos + Vector2(220,0), "kind":"runner", "hp":2, "speed":195.0, "radius":15.0, "charge":0.0})
		"SPAWN 20":
			for i in range(20):
				game._spawn_next_enemy()
		"WAVE +1":
			game._start_wave(mini(10, game.wave + 1))
		"GOD MODE":
			god_mode = not god_mode
		"SPEED 0.5":
			Engine.time_scale = 0.5
		"SPEED 1":
			Engine.time_scale = 1.0
		"SPEED 2":
			Engine.time_scale = 2.0
		"SPEED 4":
			Engine.time_scale = 4.0
		"CLOSE":
			debug_panel.visible = false

func debug_tap() -> void:
	var now := Time.get_ticks_msec()
	pause_taps = pause_taps + 1 if now - last_pause_tap < 1000 else 1
	last_pause_tap = now
	if pause_taps >= 3:
		pause_taps = 0
		debug_panel.visible = not debug_panel.visible
