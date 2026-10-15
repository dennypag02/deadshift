extends SceneTree
const ACTORS = preload("res://scripts/actor_presentation.gd")
var failures: Array[String] = []
func require(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FEEDBACK_FAIL " + message)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var game = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.progression.set_physics_process(false)
	game.guidance.disabled_for_test = true
	for i in range(3):
		await process_frame
	require(is_equal_approx(ACTORS.height_for("shambler") / 96.0, 0.65), "shambler ratio")
	require(is_equal_approx(ACTORS.height_for("runner") / 96.0, 0.60), "runner ratio")
	require(is_equal_approx(ACTORS.height_for("elite") / ACTORS.height_for("shambler"), 1.3), "elite ratio")
	for kind in ["brute", "bloater"]:
		require(is_equal_approx(ACTORS.height_for(kind) / ACTORS.height_for("shambler"), 1.5), "large ratio " + kind)
	for kind in ACTORS.ART:
		require(ACTORS.ART[kind].resource_path.begins_with("res://art/characters/"), "approved character path " + kind)
		require(is_equal_approx(ACTORS.radius_for(kind), ACTORS.height_for(kind) * 0.28), "collider ratio " + kind)
	game.generator_active = false
	game.guidance.refresh_target()
	require(game.guidance.target.id == "generator", "generator target")
	require(game.guidance.objectives().size() == 13, "every objective on map")
	game.guidance.rebuild_route()
	require(not game.guidance.route.is_empty(), "generator path exists")
	for p in game.guidance.route:
		require(not game._circle_hits_blocker(p, game.PLAYER_RADIUS), "route must avoid blocked tiles")
	game.generator_active = true
	game.supply_caches[0]["collected"] = true
	game.guidance.refresh_target()
	require(game.guidance.target.kind == "crate", "supplies after generator")
	require(game.guidance.target.id != "supply_0", "skip collected crate")
	game._start_wave(3)
	require(game.banner.text.begins_with("WAVE 3:"), "wave3 banner")
	require(game.banner.text.contains(game.guidance.label_text().to_upper()), "live objective banner")
	game.guidance.begin_briefing()
	require(paused and game.guidance.briefing, "briefing pauses combat")
	game.guidance._input(InputEventScreenTouch.new()) # Unpressed input must not skip.
	require(game.guidance.briefing, "no skip on touch release")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	game.guidance._input(tap)
	require(not paused and not game.guidance.briefing, "tap skips and resumes")
	game.tactical_map._toggle()
	require(paused and game.tactical_map.expanded, "map pauses combat")
	game.tactical_map.close_map()
	require(not paused, "map closes cleanly")
	# Backward-compatible legacy curve replay, not the new mobile pacing acceptance.
	# New curve is checked by performance_tests and the normal-damage capture.
	var p = game.progression
	p.level = 1
	p.xp = 0
	p.pending_levels = 0
	p.choosing = true
	p.xp_credit_remainder = 0
	var mobile_xp: Dictionary = p.config["xp"].duplicate(true)
	p.config["xp"]["required_by_level"] = []
	p.config["xp"]["collection_multiplier_by_level"] = {"1":1.0,"default":0.60}
	p._collect_xp(6)
	require(p.level == 2, "first six XP preserved")
	for second in range(1, 181):
		game.run_clock = second
		p._collect_xp(3 if second % 3 else 2) # 480 raw XP over three minutes, matched test fixture.
	var test_level: int = p.level
	require(test_level >= 10 and test_level <= 12, "three-minute XP replay target")
	print("FEEDBACK_XP_REPLAY level=%d raw=%d credited=%d" % [p.level, p.xp_collected_raw, p.xp_collected_total])
	p.config["xp"] = mobile_xp
	# Exercise pooled renderer with all 7 variants and 180 enemies.
	game.enemies.clear()
	for i in range(180):
		var kind: String = ["shambler", "runner", "bloater", "spitter", "brute", "elite", "mech_miniboss"][i % 7]
		game._append_enemy(kind, game.player_pos + Vector2((i % 15 - 7) * 35, (i / 15 - 6) * 45))
	game.actors._process(0.016)
	require(game.actors.active.size() == 180, "all stress actors rendered")
	var allocated: int = game.actors.allocations
	game.enemies.clear()
	game.actors._process(0.016)
	for i in range(180):
		game._append_enemy("shambler", game.player_pos)
	game.actors._process(0.016)
	require(game.actors.allocations == allocated, "pool reuse without allocation growth")
	print("FEEDBACK_TESTS_%s failures=%d pooled_actors=180" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	paused = false
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
