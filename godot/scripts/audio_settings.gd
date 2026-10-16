extends CanvasLayer
var game: Node2D
var panel: PanelContainer
var before_paused := false
var controls: Dictionary = {}
var title_button: Button
func _ready() -> void:
	layer = 60
	var factor := game.get_viewport_rect().size.x/432.0
	transform = Transform2D(0,Vector2.ONE*factor,0,Vector2.ZERO)
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.position = Vector2(24,170)
	panel.size = Vector2(384,600)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101818")
	style.border_color = Color("#F2A23A")
	style.set_border_width_all(2)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",18)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "SOUND & SETTINGS"
	title.add_theme_font_size_override("font_size",28)
	stack.add_child(title)
	for key in ["Music","SFX","UI"]:
		var label := Label.new()
		label.text = "Effects" if key=="SFX" else key
		label.add_theme_font_size_override("font_size",22)
		stack.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(320,36)
		slider.value_changed.connect(func(value: float)->void:
			SoundManager.set_setting(key,value/100.0)
			SoundManager.play("slider_tick"))
		stack.add_child(slider)
		controls[key] = slider
	for key in ["mute","vibration"]:
		var toggle := CheckButton.new()
		toggle.text = "Mute all" if key=="mute" else "Vibration"
		toggle.custom_minimum_size.y = 44
		toggle.toggled.connect(func(value: bool)->void:
			SoundManager.set_setting(key,value)
			SoundManager.play("toggle"))
		stack.add_child(toggle)
		controls[key] = toggle
	var credits := Button.new()
	credits.text = "CREDITS"
	credits.pressed.connect(func()->void:
		var dialog := AcceptDialog.new()
		dialog.title = "Audio credits"
		var credits_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_credits.json"))
		var text := "AUDIO CREDITS\n"
		for entry in credits_data.entries:
			text += "\n"+str(entry.file)+"\n"+str(entry.author)+" - "+str(entry.license)+"\n"+str(entry.attribution)+"\n"
		dialog.dialog_text = text
		add_child(dialog)
		dialog.popup_centered(Vector2i(360,230)))
	stack.add_child(credits)
	var close := Button.new()
	close.text = "BACK"
	close.custom_minimum_size.y = 50
	close.pressed.connect(close_settings)
	stack.add_child(close)
	panel.hide()
	title_button = Button.new()
	title_button.text = "SOUND / SETTINGS"
	title_button.position = Vector2(80,780)
	title_button.size = Vector2(272,48)
	title_button.pressed.connect(open_settings)
	game.phase_ui.add_child(title_button)
	for parent in [game.hud_overlay.pause_menu.get_child(0)]:
		var button := Button.new()
		button.text = "SOUND / SETTINGS"
		button.custom_minimum_size.y = 44
		button.pressed.connect(open_settings)
		parent.add_child(button)
	# Keep legacy pause Vibration toggle in sync with the persisted setting.
	for child in game.hud_overlay.pause_menu.get_child(0).get_children():
		if child is CheckButton and child.text=="Vibration":
			child.set_pressed_no_signal(bool(SoundManager.settings.vibration))
			child.toggled.connect(func(value: bool)->void: SoundManager.set_setting("vibration",value))
func open_settings() -> void:
	if panel.visible: return
	before_paused = get_tree().paused
	get_tree().paused = true
	for key in controls:
		if controls[key] is HSlider: controls[key].set_value_no_signal(float(SoundManager.settings[key])*100)
		else: controls[key].set_pressed_no_signal(bool(SoundManager.settings[key]))
	panel.show()
	SoundManager.play("pause_open")
func close_settings() -> void:
	for child in game.hud_overlay.pause_menu.get_child(0).get_children():
		if child is CheckButton and child.text=="Vibration": child.set_pressed_no_signal(bool(SoundManager.settings.vibration))
	panel.hide()
	get_tree().paused = before_paused
	SoundManager.play("back")

func _process(_delta: float) -> void:
	title_button.visible = game.phase_ui.main_menu_panel.visible and not panel.visible
