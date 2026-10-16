extends SceneTree
var g: Node2D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	seed(20261015)
	g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	paused = false
	g.guidance.disabled_for_test = true
	g.phase_ui.god_mode = true
	g.wave_active = false
	g.break_clock = 100000.0
	g.rng.seed = 8675309
	g.events.interrupt("isolated_performance_fixture")
	g.enemies.clear()
	for i in range(220):
		var p: Vector2 = g.player_pos + Vector2((i % 20 - 10) * 28, (i / 20 - 5) * 38)
		g._append_enemy(["shambler", "runner", "bloater", "spitter", "brute"][i % 5], g._nearest_walkable_position(p, 27))
		g.enemies[-1]["hp"] = 10000000.0
	assert(g.enemies.size()==220,"Stress fixture must start with exactly 220 enemies")
	for w in ["scrap_smg", "boomstick", "buzzsaw", "rocket", "chakram", "molotov"]:
		g.progression.debug_grant(w)
		g.progression.weapons[w] = 3
	# Suppress only stale-actor recycling in this isolated fixed-population workload.
	if g.get("rules")!=null:
		g.rules.pressure.recycle_budget = 0
	var frames: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(300):
		await process_frame
		var now := Time.get_ticks_usec()
		if i >= 60:
			frames.append((now-last) / 1000.0)
		last = now
	frames.sort()
	var total := 0.0
	for v in frames: total += v
	var r := {"gpu": RenderingServer.get_video_adapter_name(), "samples": frames.size(), "mean_ms": total/frames.size(), "p95_ms": frames[int(frames.size()*0.95)], "active_enemies": g.enemies.size(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "phone_test": false,"fixed_simulation_step_hz":60,"clock":"measured wall time, not fixed-fps video time","workload":"220 enemies, six level-3 weapons, no pickups; survival disabled only in stress fixture"}
	assert(g.enemies.size()==220,"Stress fixture lost an enemy")
	print("PERF_STRESS_RESULT ", JSON.stringify(r))
	FileAccess.open(OS.get_environment("STRESS_REPORT"), FileAccess.WRITE).store_string(JSON.stringify(r,"  "))
	quit()
