extends Control
var game: Node2D
var progression: Node2D
var panel: PanelContainer
var debug_panel: PanelContainer
var cards: Array[Button] = []
var xp_track: ColorRect
var xp_fill: ColorRect
var level_badge: Label
var xp_flash := 0.0
var last_level := 1
var current_choices: Array[String] = []
var banish_mode := false
var pause_taps := 0
var last_pause_tap := 0
var god_mode := false
var debug_stats: Label
var font: Font
const CYAN := Color("#3FD0E0")
const DARK := Color("#14110F")
const COMMON := Color("#8FA7B3")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scale_factor := get_viewport_rect().size.x / 432.0
	scale = Vector2.ONE * scale_factor
	font = load("res://art/fonts/BarlowCondensed-SemiBold.ttf")
	_build_xp_bar()
	_build_levelup()
	_build_debug()
	progression.level_up_requested.connect(_show_choices)
	last_level = progression.level

func _build_xp_bar() -> void:
	xp_track = ColorRect.new()
	xp_track.position = Vector2(8, 132)
	xp_track.size = Vector2(416, 16)
	xp_track.color = Color("#23272B")
	add_child(xp_track)
	xp_fill = ColorRect.new()
	xp_fill.position = Vector2(8, 132)
	xp_fill.size = Vector2(0, 16)
	xp_fill.color = CYAN
	add_child(xp_fill)
	var badge := PanelContainer.new()
	badge.position = Vector2(8, 127)
	badge.size = Vector2(52, 26)
	var bs := StyleBoxFlat.new()
	bs.bg_color = DARK
	bs.border_color = CYAN
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", bs)
	add_child(badge)
	level_badge = Label.new()
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge.add_theme_font_size_override("font_size", 18)
	if font != null:
		level_badge.add_theme_font_override("font", font)
	badge.add_child(level_badge)

func _build_levelup() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(12, 165)
	panel.size = Vector2(408, 710)
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
	heading.add_theme_font_size_override("font_size", 42)
	if font != null:
		heading.add_theme_font_override("font", font)
	stack.add_child(heading)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(390, 120)
		b.add_theme_font_size_override("font_size", 21)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if font != null:
			b.add_theme_font_override("font", font)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color("#191A1C")
		cs.border_color = COMMON
		cs.set_border_width_all(3)
		cs.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", cs)
		b.pressed.connect(_pick.bind(i))
		stack.add_child(b)
		cards.append(b)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	for label in ["REROLL", "BANISH"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(150, 54)
		if label == "REROLL":
			b.pressed.connect(_reroll)
		else:
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
	if font != null:
		debug_stats.add_theme_font_override("font", font)
	dbg.add_child(debug_stats)
	for command in [
		"TEST 6 SHAMBLER KILLS", "XP +100", "LEVEL +1",
		"SMG +1", "BOOMSTICK +1", "BUZZSAW +1",
		"MUSCLE +1", "AMMO BELT +1", "TRIGGER +1", "MAGNET +1", "THICK HIDE +1",
		"SPAWN SHAMBLER", "SPAWN RUNNER", "SPAWN 20", "WAVE +1",
		"GOD MODE", "SPEED 0.5", "SPEED 1", "SPEED 2", "SPEED 4", "CLOSE"
	]:
		var b := Button.new()
		b.text = command
		b.custom_minimum_size.y = 48
		b.pressed.connect(_debug_action.bind(command))
		dbg.add_child(b)

func _show_choices() -> void:
	get_tree().paused = true
	panel.visible = true
	banish_mode = false
	_refresh_choices()

func _refresh_choices() -> void:
	current_choices = progression.available_choices()
	for i in range(cards.size()):
		cards[i].visible = i < current_choices.size()
		if i >= current_choices.size():
			continue
		var id := current_choices[i]
		var category: Dictionary = progression.config["weapons"] if progression.config["weapons"].has(id) else progression.config["passives"]
		var item: Dictionary = category[id]
		var current := int(progression.weapons.get(id, progression.passives.get(id, 0)))
		var target := current + 1
		var max_level := int(item.get("max_level", 5))
		var pips := ""
		for p in range(max_level):
			pips += "●" if p < target else "○"
		var level_adds: Array = item.get("level_adds", [])
		var addition := str(level_adds[target - 1]) if target - 1 < level_adds.size() else str(item.get("description", "Upgrade"))
		var icon := "▰" if progression.config["weapons"].has(id) else "◆"
		var new_tag := "   NEW" if current == 0 else ""
		cards[i].set_meta("upgrade", id)
		cards[i].text = "  %s  %s%s\n  %s   %s\n  %s LV %d: %s" % [icon, item["name"], new_tag, pips, str(item.get("rarity", "COMMON")), item["name"], target, addition]

func _pick(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	var id := current_choices[index]
	if banish_mode:
		progression.banish(id)
		banish_mode = false
		_refresh_choices()
		return
	panel.visible = false
	progression.choose(id)
	if progression.choosing:
		panel.visible = true
		get_tree().paused = true
	else:
		progression.resume_after_levelup()
		get_tree().paused = false

func _reroll() -> void:
	_refresh_choices()

func _banish() -> void:
	banish_mode = true

func _process(delta: float) -> void:
	if progression == null or progression.config.is_empty():
		return
	level_badge.text = "LV %d" % progression.level
	var needed := maxi(1, progression.xp_required(progression.level))
	xp_fill.size.x = 416.0 * clampf(float(progression.xp) / float(needed), 0.0, 1.0)
	if progression.level != last_level:
		last_level = progression.level
		xp_flash = 0.36
	xp_flash = maxf(0.0, xp_flash - delta)
	var pulse := 1.0 + 0.5 * (xp_flash / 0.36) if xp_flash > 0.0 else 1.0
	xp_track.modulate = Color(pulse, pulse, pulse, 1.0)
	xp_fill.modulate = Color(pulse, pulse, pulse, 1.0)
	if debug_stats != null and debug_panel.visible:
		debug_stats.text = "FPS %d   ENEMIES %d   PROJECTILES %d   GEMS %d\nLV %d  XP %d/%d  GOD %s  TIME %.1fx" % [
			Engine.get_frames_per_second(), game.enemies.size(), game.bullets.size(), progression.gems.size(),
			progression.level, progression.xp, needed, "ON" if god_mode else "OFF", Engine.time_scale
		]

func _grant_upgrade(id: String) -> void:
	if progression.config.get("weapons", {}).has(id):
		var max_level := int(progression.config["weapons"][id].get("max_level", 5))
		progression.weapons[id] = mini(max_level, int(progression.weapons.get(id, 0)) + 1)
	elif progression.config.get("passives", {}).has(id):
		var before := int(progression.passives.get(id, 0))
		var max_level := int(progression.config["passives"][id].get("max_level", 5))
		if before < max_level:
			progression.choose(id)
			# Debug grants should not consume a pending level-up choice.
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
		"SMG +1":
			_grant_upgrade("scrap_smg")
		"BOOMSTICK +1":
			_grant_upgrade("boomstick")
		"BUZZSAW +1":
			_grant_upgrade("buzzsaw")
		"MUSCLE +1":
			_grant_upgrade("muscle")
		"AMMO BELT +1":
			_grant_upgrade("ammo_belt")
		"TRIGGER +1":
			_grant_upgrade("trigger_finger")
		"MAGNET +1":
			_grant_upgrade("magnet")
		"THICK HIDE +1":
			_grant_upgrade("thick_hide")
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
