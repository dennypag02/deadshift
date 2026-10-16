extends "res://scripts/phase_a_ui.gd"
var icon_map: Dictionary = {}
var icon_textures: Dictionary = {}
var card_art: Array[TextureRect] = []

func _ready() -> void:
	icon_map = JSON.parse_string(FileAccess.get_file_as_string("res://data/icon_map.json"))["icons"]
	for id in icon_map:
		var path: String = icon_map[id]
		if ResourceLoader.exists(path): icon_textures[id] = load(path)
		else: push_warning("MISSING_PROMOTED_ICON " + id + " " + path)
	super._ready()

func _build_levelup() -> void:
	super._build_levelup()
	for slot in card_icons:
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.custom_minimum_size = Vector2.ONE*float(game.rules.ui.icon_pixels)
		var art := TextureRect.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(art)
		card_art.append(art)

func _refresh_choices() -> void:
	super._refresh_choices()
	for i in range(current_choices.size()):
		if i>=card_art.size(): break
		var id := current_choices[i]
		card_art[i].texture = icon_textures.get(id)
		card_art[i].visible = card_art[i].texture!=null
		if card_art[i].visible: card_icons[i].color = Color.TRANSPARENT

func show_game_over(time_survived: float, wave_number: int, player_level: int, kill_count: int, run_score: int, scrap: int, pause_tree: bool = true) -> void:
	super.show_game_over(time_survived,wave_number,player_level,kill_count,run_score,scrap,pause_tree)
	var text := game_over_stats.text
	if not bool(game.rules.ui.garage_enabled): text = text.split("\nSCRAP EARNED")[0]
	text += "\nKilled by: " + game.fairness.killer
	game_over_stats.text = text
	game.hud_overlay.clear_notifications()
