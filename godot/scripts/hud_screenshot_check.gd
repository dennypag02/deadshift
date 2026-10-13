extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var root := get_root()
	root.content_scale_size = Vector2i(1080, 2340)
	var scene: PackedScene = load("res://scenes/Outskirts.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	for i in range(35):
		await process_frame
	game.score = 4900
	game.player_hp = 86
	game.progression.level = 2
	game.progression.xp = 3
	for i in range(mini(2, game.supply_caches.size())):
		game.supply_caches[i]["collected"] = true
	game.banner.text = "SUPPLIES RECOVERED\n2 of 3 - find the last crate"
	for i in range(8):
		await process_frame
	var hud_image := root.get_texture().get_image()
	var hud_result := hud_image.save_png("user://hud_1080x2340.png")
	game.progression.add_xp(game.progression.xp_required(game.progression.level))
	for i in range(8):
		await process_frame
	var level_image := root.get_texture().get_image()
	var level_result := level_image.save_png("user://levelup_1080x2340.png")
	print("HUD_SCREENSHOT_RESULT: ", hud_result, " LEVELUP_SCREENSHOT_RESULT: ", level_result)
	quit(0 if hud_result == OK and level_result == OK else 1)
