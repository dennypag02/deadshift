extends SceneTree
var output := ""
var game: Node2D
var capture_seed := 20261015
var target_seconds := 180.0
var death_frames := 0
var test_mode := "moving"
var displacement := 0.0
var distance_travelled := 0.0
var initial_position := Vector2.ZERO
var previous_position := Vector2.ZERO
var driver = preload("res://scripts/normal_run_driver.gd").new()
func _initialize() -> void:
	output = OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	if output == "":
		output = "user://feedback-evidence"
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")
func _run() -> void:
	if OS.get_environment("DEADSHIFT_VALIDATION_SEED") != "": capture_seed = int(OS.get_environment("DEADSHIFT_VALIDATION_SEED"))
	if OS.get_environment("DEADSHIFT_CAPTURE_SECONDS") != "": target_seconds = float(OS.get_environment("DEADSHIFT_CAPTURE_SECONDS"))
	seed(capture_seed) # Deterministic capture choices only, not production gameplay.
	if OS.get_environment("DEADSHIFT_RECORDING")=="1": root.size = Vector2i(720,1600)
	game = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _record()
func _save(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output.path_join(name))
	print("FEEDBACK_SCREENSHOT file=%s result=%d" % [name, result])
func _record() -> void:
	test_mode = OS.get_environment("DEADSHIFT_TEST_MODE")
	driver.game = game
	initial_position = game.player_pos
	previous_position = game.player_pos
	game.capture_mode = false # Drive ordinary input; no capture-mode revivals or forced deaths.
	game.phase_ui.capture_mode = false # Script chooses only normally offered cards below.
	game.phase_ui._start_capture_title() if OS.get_environment("DEADSHIFT_RECORDING")=="1" else game.phase_ui._start_from_title()
	game.phase_ui.god_mode = false
	game.guidance.disabled_for_test = OS.get_environment("DEADSHIFT_RECORDING") != "1"
	game.rng.seed = capture_seed
	var shown_map := false
	var map_frames := 0
	var card_frames := 0
	var completed_horizon := false
	var saved_gameplay := false
	var deaths := 0
	for frame in range(60000):
		await process_frame
		var ready_card := false
		for button in game.phase_ui.card_buttons:
			if button.visible and not button.disabled: ready_card = true
		if game.phase_ui.panel.visible and not game.phase_ui.current_choices.is_empty() and ready_card:
			card_frames += 1
			if card_frames >= 24:
				card_frames = 0
				var preference := ["buzzsaw", "scrap_smg", "molotov", "drone", "lightning", "boomstick", "rocket", "chakram", "muscle", "trigger_finger", "ammo_belt", "thick_hide", "magnet"]
				if game.player_hp < game.player_max_hp*0.6:
					preference.push_front("thick_hide")
					preference.push_front("fallback_heal")
				var selected := 0
				for wanted in preference:
					if game.phase_ui.current_choices.has(wanted):
						selected = game.phase_ui.current_choices.find(wanted)
						break
				game.telemetry.event("upgrade_choice", {"id":game.phase_ui.current_choices[selected], "offered":game.phase_ui.current_choices,"hp":game.player_hp})
				game.phase_ui._pick(selected)
		else:
			card_frames = 0
		if frame == 40 and OS.get_environment("DEADSHIFT_RECORDING")=="1":
			_save("title-screen.png")
		if frame % 900 == 0:
			print("FEEDBACK_RECORDING seconds=%d gameplay_t=%.1f level=%d hp=%d enemies=%d god_mode=false" % [frame / 30, game.run_clock, game.progression.level, game.player_hp, game.enemies.size()])
		if false and frame >= 1500 and not shown_map and not paused and game.player_hp > 0:
			game.tactical_map._toggle()
			shown_map = true
		if shown_map and game.tactical_map.expanded:
			map_frames += 1
			if map_frames == 20:
				_save("objective-map.png")
			if map_frames >= 100:
				game.tactical_map.close_map()
		if not paused and game.player_hp > 0:
			displacement = maxf(displacement,initial_position.distance_to(game.player_pos))
			distance_travelled += previous_position.distance_to(game.player_pos)
			previous_position = game.player_pos
			var desired: Vector2 = Vector2.ZERO if test_mode=="stationary" else driver.direction()
			game.touch_active = true
			game.touch_origin = Vector2.ZERO
			game.touch_position = desired * 90.0
			if OS.get_environment("DEADSHIFT_RECORDING")=="1" and frame > 500 and not saved_gameplay and game.enemies.size() >= 20:
				_save("gameplay-guidance.png")
				saved_gameplay = true
		if game.player_hp <= 0 and deaths == 0:
			deaths += 1
			print("FEEDBACK_RECORDING_DEATH t=%.1f; game-over remains visible; no revival" % game.run_clock)
		if game.player_hp <= 0:
			death_frames += 1
		if game.run_clock >= target_seconds or death_frames >= 90:
			break
	completed_horizon = game.run_clock>=target_seconds or deaths>0
	game.run_log.finish("death" if deaths > 0 else ("qualification_censored" if completed_horizon else "qualification_invalid_stalled"))
	var summary: Dictionary = game.run_log.summary()
	summary["test"] = {"valid":completed_horizon,"controller":"input_only_direction_scoring_v4","mode":test_mode,"seed":capture_seed,"horizon":target_seconds,"maximum_displacement_px":displacement,"distance_travelled_px":distance_travelled,"normal_damage":true,"god_mode":false,"input_only":true,"physical_phone_test":false}
	FileAccess.open(output.path_join("qualification.json"),FileAccess.WRITE).store_string(JSON.stringify(summary,"  "))
	print("QUALIFICATION_COMPLETE ",JSON.stringify({"valid":completed_horizon,"mode":test_mode,"seed":capture_seed,"seconds":game.run_clock,"wave":game.wave,"hp":game.player_hp,"level":game.progression.level,"max_displacement":displacement}))
	var report := {"seed":capture_seed,"requested_active_seconds":target_seconds,"run_log_directory":game.run_log.directory,"recording": "desktop scripted input, normal damage, god mode OFF; fixed-FPS/offline capture is not a performance benchmark", "gameplay_seconds": game.run_clock, "level": game.progression.level, "hp": game.player_hp, "kills": game.kills, "deaths": deaths, "level_up_times": game.progression.level_times, "active_seconds":game.telemetry.active_seconds, "wall_seconds":game.telemetry.wall_seconds, "explicit_pause_seconds":game.telemetry.pause_seconds}
	FileAccess.open(output.path_join("playthrough.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("FEEDBACK_RECORDING_COMPLETE ", JSON.stringify(report))
	quit(0 if completed_horizon else 2)
