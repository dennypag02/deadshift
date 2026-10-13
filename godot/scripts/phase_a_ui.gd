extends Control
var game: Node2D
var progression: Node2D
var panel: PanelContainer
var xp_label: Label
var level_label: Label
var debug_panel: PanelContainer
var debug_visible := false
var cards: Array[Button] = []
var pause_taps := 0
var last_pause_tap := 0
var god_mode := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var font := load("res://art/fonts/BarlowCondensed-SemiBold.ttf")
	var top := HBoxContainer.new()
	top.position = Vector2(14, 248)
	top.size = Vector2(405, 42)
	add_child(top)
	level_label = Label.new()
	level_label.text = "LV 1"
	level_label.add_theme_font_size_override("font_size", 26)
	if font != null:
		level_label.add_theme_font_override("font", font)
	top.add_child(level_label)
	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 24)
	if font != null:
		xp_label.add_theme_font_override("font", font)
	top.add_child(xp_label)
	panel = PanelContainer.new()
	panel.position = Vector2(16, 345)
	panel.size = Vector2(400, 560)
	panel.visible = false
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14110F",0.96)
	style.border_color = Color("#F2A23A")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",14)
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = "LEVEL UP! CHOOSE YOUR POWER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",32)
	stack.add_child(heading)
	for i in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(380,132)
		button.add_theme_font_size_override("font_size",26)
		button.pressed.connect(_pick.bind(i))
		stack.add_child(button)
		cards.append(button)
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(12,300)
	debug_panel.size = Vector2(408,780)
	debug_panel.visible = false
	add_child(debug_panel)
	var dbg := VBoxContainer.new()
	debug_panel.add_child(dbg)
	for command in ["XP +100","LEVEL +1","SPAWN 20","WAVE +1","GOD MODE","SPEED 0.5","SPEED 1","SPEED 2","SPEED 4","CLOSE"]:
		var b := Button.new()
		b.text = command
		b.custom_minimum_size.y = 60
		b.pressed.connect(_debug_action.bind(command))
		dbg.add_child(b)
	progression.level_up_requested.connect(_show_choices)

func _show_choices() -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = true
	var choices: Array[String] = progression.available_choices()
	for i in range(cards.size()):
		cards[i].visible = i < choices.size()
		if i < choices.size():
			cards[i].set_meta("upgrade",choices[i])
			var id := choices[i]
			var category: Dictionary = progression.config["weapons"] if progression.config["weapons"].has(id) else progression.config["passives"]
			var item: Dictionary = category[id]
			var current := int(progression.weapons.get(id,progression.passives.get(id,0)))
			cards[i].text = "%s  LV %d/5%s\n%s" % [item["name"],current+1,"  NEW" if current == 0 else "",item["description"]]

func _pick(index: int) -> void:
	var id: String = cards[index].get_meta("upgrade")
	panel.visible = false
	get_tree().paused = false
	progression.choose(id)

func _process(_delta: float) -> void:
	if progression == null:
		return
	level_label.text = "LV %d   " % progression.level
	xp_label.text = "XP %d / %d" % [progression.xp,progression.xp_required(progression.level)]

func _debug_action(command: String) -> void:
	match command:
		"XP +100":
			progression.add_xp(100)
		"LEVEL +1":
			progression.add_xp(progression.xp_required(progression.level))
		"SPAWN 20":
			for i in range(20):
				game._spawn_next_enemy()
		"WAVE +1":
			game._start_wave(mini(10,game.wave+1))
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
	pause_taps = pause_taps+1 if now-last_pause_tap < 1000 else 1
	last_pause_tap = now
	if pause_taps >= 3:
		pause_taps = 0
		debug_panel.visible = not debug_panel.visible
