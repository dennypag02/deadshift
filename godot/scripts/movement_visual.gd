extends SceneTree
var g: Node2D
var output := ""
func _initialize() -> void:
	output = OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func save_image(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	root.size = Vector2i(720,1600)
	g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.telemetry.set_process(false)
	g.set_physics_process(false)
	g.progression.set_physics_process(false)
	g.guidance.disabled_for_test = true
	paused = false
	for frame in range(10): await process_frame
	for number in [1,2,3,5,8,9]:
		g.events.interrupt("visual_fixture")
		g.events.offered_waves.erase(number)
		g._start_wave(number)
		g.wave_clock = 4.0
		g.events.tick(0)
		g.events.active.elapsed = 12.0
		g.hud_overlay._update_event_card()
		g.player_pos = g._nearest_walkable_position(Vector2(g.events.target().pos)+Vector2(0,180),g.PLAYER_RADIUS)
		g.camera.position = g.player_pos
		g.camera.reset_smoothing()
		await save_image("objective-wave-%d" % number)
	g.stage1_hazards.clear()
	for i in range(6): g.add_hazard("goo",g.player_pos+Vector2(i*50-100,30),float(g.rules.goo.radius),5,"",-1)
	g.add_hazard("acid_warning",g.player_pos,48,0.8,"spitter",1)
	g.hud_overlay.clear_notifications()
	g.announce("PUMP DETONATED!","THE MECHANIC waits its turn")
	g.announce("THE MECHANIC")
	await save_image("hazard-layer-and-top-band")
	g.progression.pending_levels = 1
	g.phase_ui.queue_upgrade_crate()
	await save_image("promoted-card-icons")
	g.phase_ui.panel.hide()
	g.player_hp = 0
	g.fairness.killer = "Pump explosion"
	g.phase_ui.show_game_over(282,5,13,800,1200,0,false)
	await save_image("named-killer-no-garage")
	print("MOVEMENT_VISUAL_PASS")
	quit()
