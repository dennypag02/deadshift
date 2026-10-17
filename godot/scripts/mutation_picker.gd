extends Control

var game: Node
var panel: PanelContainer
var timer_label: Label
var buttons: Array[Button] = []
var offers: Array[String] = []
var seconds_left := 0.0
var confirm_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	MutationManager.offer_ready.connect(_show_offer)
	MutationManager.offer_closed.connect(_hide_offer)

func _build() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(10,185)
	panel.size = Vector2(412,720)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0D0D10",0.98)
	style.border_color = Color("#9BD13B")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	panel.add_child(stack)

	var title_label := Label.new()
	title_label.text = "CHOOSE A MUTATION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size",34)
	stack.add_child(title_label)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size",20)
	stack.add_child(timer_label)

	for i in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(390,150)
		button.add_theme_font_size_override("font_size",22)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_pressed.bind(i))
		stack.add_child(button)
		buttons.append(button)

	var skip := Button.new()
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(390,62)
	skip.add_theme_font_size_override("font_size",22)
	skip.pressed.connect(func() -> void: MutationManager.skip_offer())
	stack.add_child(skip)

func _show_offer(values: Array) -> void:
	offers.clear()
	for value in values:
		offers.append(str(value))
	seconds_left = 15.0
	confirm_id = ""
	_refresh_buttons()
	panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true

func _hide_offer() -> void:
	panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_id = ""

func _process(delta: float) -> void:
	if not panel.visible:
		return
	seconds_left = maxf(0.0,seconds_left-delta)
	timer_label.text = "NEXT WAVE IN %d  -  PICK OR SKIP" % ceili(seconds_left)
	if seconds_left <= 0.0:
		MutationManager.skip_offer()

func _pressed(index: int) -> void:
	if index < 0 or index >= offers.size():
		return
	var id := offers[index]
	var replacement := MutationManager.replacement_for(id)
	if replacement != "" and confirm_id != id:
		confirm_id = id
		_refresh_buttons()
		return
	var result := MutationManager.take_mutation(id)
	if bool(result.get("ok",false)):
		if game != null and game.banner != null:
			game.banner.text = "%s  LV.%d" % [MutationManager.mutation_name(id).to_upper(),int(result["level"])]
		MutationManager.complete_offer()

func _refresh_buttons() -> void:
	for i in range(buttons.size()):
		if i >= offers.size():
			buttons[i].visible = false
			continue
		buttons[i].visible = true
		var id := offers[i]
		var row: Dictionary = MutationManager.definitions[id]
		var held_level := MutationManager.held_level(id)
		var next_level := mini(3,held_level+1)
		var replacement := MutationManager.replacement_for(id)
		var tags: Array = row["tags"]
		var tag_text := ""
		for tag in tags:
			if tag_text != "":
				tag_text += " + "
			tag_text += str(tag).to_upper()
		var suffix := ""
		if held_level > 0:
			suffix = "\nLEVEL UP  %d -> %d" % [held_level,next_level]
		elif replacement != "":
			if confirm_id == id:
				suffix = "\nREPLACE %s? TAP AGAIN" % MutationManager.mutation_name(replacement).to_upper()
			else:
				suffix = "\nREPLACES %s" % MutationManager.mutation_name(replacement).to_upper()
		buttons[i].text = "%s  -  %s\n%s%s" % [str(row["name"]).to_upper(),str(row["slot"]).to_upper(),tag_text,suffix]
