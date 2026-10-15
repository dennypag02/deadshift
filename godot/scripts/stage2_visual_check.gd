extends SceneTree
var g: Node2D
var output := ""
func _initialize() -> void:
	output = OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	call_deferred("run")
func run() -> void:
	g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.progression.set_physics_process(false)
	g.telemetry.set_process(false)
	g.guidance.disabled_for_test = true
	paused = false
	for wave in [1,2,8,9]:
		g.events.interrupt("visual_fixture")
		g.events.offered_waves.erase(wave)
		g._start_wave(wave)
		g.events.active["elapsed"] = 12.0
		g.events.active["charge"] = 2.0 if wave == 1 else 0.0
		g.events.active["step"] = 1 if wave in [2,8] else 0
		g.events.active["hp"] = 19.0
		g.hud_overlay._update_event_card()
		g.player_pos = g._nearest_walkable_position(g.events.target()["pos"] + Vector2(0,180),g.PLAYER_RADIUS)
		g.camera.position = g.player_pos
		g.camera.reset_smoothing()
		for i in range(15): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("card-wave-%d.png" % wave))
	g.events.resolve("missed","visual_fixture")
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("quiet-missed.png"))
	print("STAGE2_VISUAL_CHECK_PASS")
	quit()
