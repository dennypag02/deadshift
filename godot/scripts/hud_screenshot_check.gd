extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var root := get_root()
	root.content_scale_size = Vector2i(1080, 2340)
	var scene: PackedScene = load("res://scenes/Outskirts.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	for i in range(45):
		await process_frame
	var image := root.get_texture().get_image()
	var output := "user://hud_1080x2340.png"
	var result := image.save_png(output)
	print("HUD_SCREENSHOT_RESULT: ", result, " ", ProjectSettings.globalize_path(output), " size ", image.get_size())
	quit(0 if result == OK else 1)
