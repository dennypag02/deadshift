extends RefCounted
var count := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error("TUNING_FAIL "+text)
func run_on(g: Node2D) -> int:
	g.get_tree().paused = false
	g.set_physics_process(false)
	g.telemetry.set_process(false)
	g.progression.set_physics_process(false)
	g.guidance.disabled_for_test = true
	g.run_log.begin()
	for wave in range(1,10):
		g.wave = wave
		var expected := 0.75 if wave<=3 else (0.875 if wave==4 else 1.0)
		check(g.wave_multiplier("pressure_by_wave")==expected,"wave pressure ramp")
		check(g.wave_multiplier("enemy_damage_by_wave")==expected,"wave damage ramp")
	check(g.rules.camp.seconds==8.0 and g.rules.camp.radius_metres==3.0 and g.rules.camp.spawn_multiplier==1.5,"anti-camp intact")
	var pump: Dictionary = g.pumps[0]
	g.run_clock = 0.0
	g.heat_explosive(pump,"lightning",true)
	g.heat_explosive(pump,"drone",true)
	g.heat_explosive(pump,"buzzsaw",true)
	check(pump.hits==0 and pump.alive,"automatic weapons cannot trigger explosives")
	g.heat_explosive(pump,"facing_weapon",true)
	check(pump.hits==1 and pump.alive,"first hit heats but does not explode")
	g.run_clock += 0.2
	g.heat_explosive(pump,"rocket",true)
	check(pump.hits==2 and pump.alive,"second hit heats")
	g.run_clock += 1.1
	g.heat_explosive(pump,"molotov",true)
	check(pump.hits==3 and not pump.alive,"third hit arms warning")
	check(g.stage1_hazards[-1].kind=="pump_warning" and g.stage1_hazards[-1].life==1.0,"every explosion warns for one second")
	g._reset_pumps()
	check(not pump.alive,"spent pumps never respawn at wave transition")
	g.player_max_hp = 100
	g.player_hp = 100
	g.progression.invulnerability = 0
	g.fairness.grace_left = 0
	g.fairness.recent.clear()
	check(g.fairness.apply(1000,"player_pump_explosion")==15,"player explosion cap fifteen percent")
	g.run_clock += 1.1
	g.fairness.recent.clear()
	check(g.fairness.apply(1000,"pump_explosion")==30,"enemy explosion cap thirty percent")
	g.run_clock += 1.1
	g.fairness.recent.clear()
	check(g.fairness.apply(1000,"player_barrel_explosion")==15,"player barrel cap fifteen percent")
	# Relocated crates have walkable paths and bounds at every valid player test site.
	for player in [Vector2(16,22),Vector2(10,13),Vector2(21,29),Vector2(15,35),Vector2(25,5)]:
		g.player_pos = g._nearest_walkable_position(player*g.TILE,g.PLAYER_RADIUS)
		for kind in ["supplies","relay"]:
			var points: Array[Vector2] = g.events._points(kind)
			check(points.size()==3,"three crate/pad sites")
			for point in points:
				var metres: float = g.player_pos.distance_to(point)/g.metres(1)
				check(metres>=20 and metres<=40,"every crate inside 20-40m")
				check(not g._circle_hits_blocker(point,g.PLAYER_RADIUS),"every crate walkable")
	var c: String = g.tuning.asphalt_without_speckles
	check(not c.contains("circle") and g.tuning.remove_decorative_asphalt_speckles,"non-pickup speckles removed")
	var script: Script = g.progression.get_script()
	var has_tuning := false
	while script!=null:
		if script.resource_path.ends_with("tuned_progression.gd"): has_tuning = true
		script = script.get_base_script()
	check(has_tuning,"permitted splash hook installed through audio subclass")
	print("TUNING_TESTS_%s checks=%d failures=%d" % ["PASS" if failures==0 else "FAIL",count,failures])
	return failures
