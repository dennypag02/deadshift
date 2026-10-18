extends SceneTree
# Renders the whole Outskirts map from above (actors hidden) to map-overview.png,
# plus a few player-eye-level crops. Visual review aid; not used in gameplay.
var out := ""
func _initialize() -> void:
	out = OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	if out == "": out = "user://map-overview"
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")
func _run() -> void:
	seed(20261018)
	var game: Node2D = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in range(10): await process_frame
	paused = false
	game.set_physics_process(false)
	game.progression.set_physics_process(false)
	game.guidance.disabled_for_test = true
	game.enemies.clear()
	for node in game.get_children():
		if node is CanvasLayer: node.hide()
	var size: Vector2 = game.MAP_SIZE
	var vp: Vector2 = Vector2(root.get_visible_rect().size)
	var cam := Camera2D.new()
	game.add_child(cam)
	game.camera.enabled = false
	cam.enabled = true
	cam.make_current()
	cam.zoom = Vector2.ONE * minf(vp.x / size.x, vp.y / size.y)
	cam.position = size * 0.5
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("map-overview.png"))
	cam.zoom = Vector2(0.68, 0.68)
	var spots := {"spawn": game.player_pos, "forecourt": Vector2(16, 17) * game.TILE, "truckstop": Vector2(25, 26) * game.TILE, "south": Vector2(14, 33) * game.TILE, "diner": Vector2(5, 11) * game.TILE}
	for name in spots:
		cam.position = spots[name]
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("view-%s.png" % name))
	print("MAP_OVERVIEW_COMPLETE")
	quit()
