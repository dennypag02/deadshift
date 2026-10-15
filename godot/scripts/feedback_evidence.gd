extends SceneTree
const ACTORS = preload("res://scripts/actor_presentation.gd")
var output := ""
var game: Node2D
func _initialize() -> void:
	output = OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	if output == "":
		output = "user://feedback-evidence"
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")
func _run() -> void:
	if OS.get_cmdline_user_args().has("--compare"):
		root.content_scale_size = Vector2i(1280, 600)
		root.size = Vector2i(1280, 600)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	game = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if OS.get_cmdline_user_args().has("--compare"):
		await _compare()
	elif OS.get_cmdline_user_args().has("--stress"):
		await _stress()
	else:
		await _record()
func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output.path_join(name))
	print("FEEDBACK_SCREENSHOT file=%s result=%d" % [name, result])
func _label(parent: Node, text: String, pos: Vector2, fontsize: int = 22) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", fontsize)
	label.add_theme_color_override("font_color", Color("#EEE5D2"))
	parent.add_child(label)
	return label
func _compare() -> void:
	paused = false
	game.guidance.disabled_for_test = true
	game.set_physics_process(false)
	game.progression.set_physics_process(false)
	game.visible = false
	game.camera.enabled = false
	for node in game.get_children():
		if node is CanvasLayer:
			node.hide()
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 600)
	bg.color = Color("#23282B")
	layer.add_child(bg)
	_label(layer, "DEADSHIFT | APPROVED CHARACTER SCALE", Vector2(34, 25), 32)
	_label(layer, "Same in-game renderer, shown at 2x. Source PNGs unchanged. Dark outlines + soft foot shadows.", Vector2(34, 74), 20)
	game.actors.reparent(layer)
	game.actors.visible = true
	game.actors.scale = Vector2.ONE * 2.0
	game.camera.position = Vector2(320, 190)
	game.player_pos = Vector2(55, 207 - 96 * 0.43)
	game.enemies.clear()
	_label(layer, "Survivor\n100%", Vector2(48, 443), 22)
	var kinds := ["shambler", "runner", "elite", "bloater", "brute", "spitter", "mech_miniboss"]
	for i in range(kinds.size()):
		var kind: String = kinds[i]
		game._append_enemy(kind, Vector2(120 + i * 76, 207 - ACTORS.height_for(kind) * 0.43))
		var title := "Mechanic" if kind == "mech_miniboss" else kind.capitalize()
		_label(layer, "%s\n%.1f%%" % [title, ACTORS.height_for(kind) / 96.0 * 100.0], Vector2(192 + i * 152, 443), 20)
	_label(layer, "Shambler 65% | Runner 60% | Elite = 1.3x shambler | Bloater / Brute = 1.5x shambler", Vector2(34, 555), 21)
	for i in range(20):
		await process_frame
	await _save("survivor-zombie-scale.png")
	quit()
func _stress() -> void:
	paused = false
	game.guidance.disabled_for_test = true
	game.phase_ui.god_mode = true # Test fixture only, never the gameplay capture.
	game.wave_active = false
	game.enemies.clear()
	for i in range(180):
		var p: Vector2 = game.player_pos + Vector2((i % 15 - 7) * 35, (i / 15 - 6) * 46)
		game._append_enemy(["shambler", "runner", "bloater", "spitter", "brute"][i % 5], game._nearest_walkable_position(p, 27))
		game.enemies[-1]["hp"] = 100000.0
	for i in range(90):
		await process_frame
	var frames: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(360):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	frames.sort()
	var total := 0.0
	for value in frames:
		total += value
	var report := {"platform": OS.get_name(), "gpu": RenderingServer.get_video_adapter_name(), "enemies": game.enemies.size(), "visible_actors": game.actors.visible_actors, "pool_allocations": game.actors.allocations, "samples": frames.size(), "mean_ms": total / frames.size(), "p95_ms": frames[int(frames.size() * 0.95)], "phone_validation": false}
	var file := FileAccess.open(output.path_join("stress-180.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("FEEDBACK_STRESS ", JSON.stringify(report))
	await _save("stress-180-desktop.png")
	quit()
func _record() -> void:
	game.capture_mode = false # Drive ordinary input; no capture-mode revivals or forced deaths.
	game.phase_ui.capture_mode = true # Auto-select cards; normal rewards/damage still apply.
	game.phase_ui.god_mode = false
	game.guidance.disabled_for_test = false
	game.rng.seed = 20261015
	var shown_map := false
	var map_frames := 0
	var saved_gameplay := false
	var deaths := 0
	for frame in range(6600):
		await process_frame
		if frame == 40:
			await _save("title-screen.png")
		if frame % 900 == 0:
			print("FEEDBACK_RECORDING seconds=%d gameplay_t=%.1f level=%d hp=%d enemies=%d god_mode=false" % [frame / 30, game.run_clock, game.progression.level, game.player_hp, game.enemies.size()])
		if frame >= 1500 and not shown_map and not paused and game.player_hp > 0:
			game.tactical_map._toggle()
			shown_map = true
		if shown_map and game.tactical_map.expanded:
			map_frames += 1
			if map_frames == 20:
				await _save("objective-map.png")
			if map_frames >= 100:
				game.tactical_map.close_map()
		if not paused and game.player_hp > 0:
			var desired := Vector2.RIGHT
			var route: PackedVector2Array = game.guidance.route
			if not route.is_empty():
				var best := 0
				var near := INF
				for i in range(route.size()):
					var d: float = Vector2(game.player_pos).distance_to(route[i])
					if d < near:
						near = d
						best = i
				var next := mini(best + (1 if near < 75 else 0), route.size() - 1)
				desired = (route[next] - Vector2(game.player_pos)).normalized()
			var repulsion := Vector2.ZERO
			for enemy in game.enemies:
				var away: Vector2 = Vector2(game.player_pos) - Vector2(enemy["pos"])
				var distance := away.length()
				if distance < 200 and distance > 0.1:
					repulsion += away.normalized() * pow(1.0 - distance / 200.0, 2.0) * 2.8
			desired = (desired + repulsion).normalized()
			for angle in [0.0, 0.55, -0.55, 1.1, -1.1, 1.65, -1.65, PI]:
				var test := desired.rotated(angle)
				if not game._circle_hits_blocker(Vector2(game.player_pos) + test * 65.0, game.PLAYER_RADIUS):
					desired = test
					break
			game.touch_active = true
			game.touch_origin = Vector2.ZERO
			game.touch_position = desired * 90.0
			if frame > 500 and not saved_gameplay and game.enemies.size() >= 20:
				await _save("gameplay-guidance.png")
				saved_gameplay = true
		if game.player_hp <= 0 and deaths == 0:
			deaths += 1
			print("FEEDBACK_RECORDING_DEATH t=%.1f; game-over remains visible; no revival" % game.run_clock)
		if frame >= 5399 and (game.run_clock >= 180.0 or game.player_hp <= 0):
			break
	var report := {"recording": "desktop scripted input, normal damage, god mode OFF", "gameplay_seconds": game.run_clock, "level": game.progression.level, "hp": game.player_hp, "kills": game.kills, "deaths": deaths, "level_up_times": game.progression.level_times}
	FileAccess.open(output.path_join("playthrough.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("FEEDBACK_RECORDING_COMPLETE ", JSON.stringify(report))
	quit()
