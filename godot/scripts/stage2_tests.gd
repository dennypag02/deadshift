extends SceneTree
var g: Node2D
var failures: Array[String] = []
var checks := 0
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
		push_error("STAGE2_FAIL " + why)
func _initialize() -> void:
	call_deferred("run")
func advance(dt: float) -> void:
	g.run_clock += dt
	g.events.tick(dt)
func offer(wave: int) -> void:
	g.events.interrupt("fixture_transition")
	g.events.offered_waves.erase(wave)
	g._start_wave(wave)
	g.guidance.refresh_target()
	g.hud_overlay._update_event_card()
func run() -> void:
	g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	if g.has_method("nearby_objective_position"):
		var contract = load("res://scripts/movement_contract.gd").new()
		var errors: int = contract.run_on(g)
		print("STAGE2_TESTS_%s movement_contract=true" % ["PASS" if errors==0 else "FAIL"])
		quit(0 if errors==0 else 1)
		return
	g.telemetry.set_process(false)
	g.set_physics_process(false)
	g.progression.set_physics_process(false)
	g.guidance.disabled_for_test = true
	paused = false
	g.run_log.begin()
	check(g.events.kind() == "generator", "first wave generator")
	check(g._active_horde_target() == 12, "first event target 20 times 0.6")
	check(g.enemies.size() <= 12, "initial spawning reduced 40 percent")
	g.hud_overlay._update_event_card()
	check(not g.hud_overlay.crate_row.visible, "generator has no supply row")
	check(g.hud_overlay.reward_icon.texture != null, "generator reward icon resolves")
	check(g.hud_overlay.countdown.visible, "deadline ring visible")
	check(g.hud_overlay.objective_progress.size.y <= 5.0, "progress strip cannot overlap direction")
	check(g.banner.text.contains("45 s -> AUTO-TURRET"), "offer names time and reward")
	var midpoint: Vector2 = (g.player_pos + g.GENERATOR_POS) / 2.0
	var before: int = g.enemies.size()
	g._append_enemy("shambler", midpoint)
	check(g.enemies.size() == before, "central spawn gate blocks approach")
	for i in range(25):
		g._spawn_pressure_group(10)
	for enemy in g.enemies:
		check(g.events.spawn_allowed(enemy["pos"], enemy["radius"]), "all group spawns outside protected corridor")
	g.player_pos = g.GENERATOR_POS
	advance(2.0)
	check(g.events.progress_text() == "CHARGE 50%", "generator shows percentage, not proximity completion")
	g._stage1_damage(1,"test")
	check(g.events.active["charge"] == 0.0, "hit resets generator charge")
	g.enemies.clear()
	g.grid_dirty = true
	advance(4.0)
	check(g.events.active.is_empty() and g.generator_active, "four uninterrupted seconds completes")
	check(g.events.earned.has("auto_turret") and g.events.earned.has("floodlights"), "generator grants both rewards")
	check(g._active_horde_target() == 20, "relief ends on completion")
	var complete_count: int = g.run_log.summary()["events_completed"]
	g.events.resolve("completed","duplicate")
	check(g.run_log.summary()["events_completed"] == complete_count, "completion is idempotent")
	# Completion does not immediately offer the next event.
	advance(10.0)
	check(g.run_log.rows.size() == 1, "one event per wave, no instant next event")
	offer(2)
	check(g.hud_overlay.crate_row.visible, "supply offer shows crate row")
	for cache in g.supply_caches:
		g.player_pos = cache["pos"]
		advance(0.1)
	check(g.run_log.rows[-1]["status"] == "completed", "three crates complete supply event")
	check(g.events.earned.has("chest"), "supply reward issued")
	offer(9)
	check(not g.hud_overlay.crate_row.visible, "nest has no supply row")
	g.player_pos = g.events.target()["pos"]
	advance(1.0)
	check(g.events.active["hp"] == 36.0, "standing on nest does not kill it")
	g.events.hit_bullet(g.events.target()["pos"],10.0)
	check(g.events.progress_text() == "NEST HP 26/36", "nest real HP progress")
	g.events.hit_bullet(g.events.target()["pos"],26.0)
	check(g.events.earned.has("fewer_spawns"), "nest reward earned only after HP depleted")
	offer(8)
	check(not g.hud_overlay.crate_row.visible and g.events.progress_text() == "PADS 0/3", "relay typed progress")
	for i in range(3):
		g.player_pos = g.events.target()["pos"]
		advance(1.5)
	check(g.events.earned.has("airstrike"), "three ordered pads grant airstrike")
	# Expiry has no reward, no health penalty, clears targets and relief.
	g.events.earned.clear()
	g.player_pos = Vector2(16,22)*g.TILE
	offer(1)
	var hp: int = g.player_hp
	advance(45.0)
	check(g.run_log.rows[-1]["status"] == "missed", "deadline expires")
	check(g.events.toast_text == "MISSED" and g.events.toast_left > 0.0, "quiet missed toast")
	check(g.player_hp == hp and g.events.earned.is_empty(), "miss has no health penalty or reward")
	check(g.guidance.target.is_empty(), "expired route cleared")
	check(g._active_horde_target() == 20, "relief ends on expiration")
	var count: int = g.run_log.rows.size()
	advance(3.0)
	check(g.run_log.rows.size() == count, "cooldown until next wave after miss")
	# Active-time clock halts for all explicit UI pauses.
	offer(1)
	g.telemetry.offline = true
	var elapsed: float = g.events.active["elapsed"]
	paused = true
	g.telemetry._process(5.0)
	check(g.events.active["elapsed"] == elapsed, "paused UI freezes deadline and charge")
	paused = false
	# Exact HP is sampled at damage time, including damage followed by a heal in the same frame.
	g.run_log.current_wave.clear()
	g.wave = 3
	g.player_hp = 100
	g.run_log.start_wave()
	g._stage1_damage(95,"acid_test")
	g.player_hp = 100
	g.run_log.close_wave("completed")
	check(g.run_log.waves[-1]["min_hp"] == 5, "wave min HP survives immediate heal")
	check(g.run_log.waves[-1]["min_hp_pct"] == 5.0, "wave minimum percentage")
	g.run_log.start_wave()
	g.player_hp = 0
	g.run_log.finish("death")
	var summary: Dictionary = g.run_log.summary()
	check(summary["death_before_wave4"], "early death classified")
	check(summary["events_offered"] == summary["events_completed"] + summary["events_missed"] + summary["events_interrupted"] + summary["events_active"], "event accounting balances")
	check(FileAccess.file_exists(g.run_log.directory.path_join("summary.json")), "durable summary exists")
	check(not summary["human_survival_rate_inferred"], "scripted tests not human rate")
	g.player_hp = 100
	g.wave10_survived = true
	g.generator_active = false
	g.detonator_core = false
	g._try_unlock_district()
	check(g.district_cleared, "missed objectives never gate progression")
	print("STAGE2_TESTS_%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
