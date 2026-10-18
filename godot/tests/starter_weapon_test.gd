extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var p: Node = game.progression
	var cfg: Dictionary = p.config

	if str(cfg.get("run",{}).get("starting_weapon","")) != "boomstick":
		_fail("run_starting_weapon_not_boomstick")
		return
	if p.weapons.size() != 1 or int(p.weapons.get("boomstick",0)) != 1 or p.weapons.has("scrap_smg"):
		_fail("starting_inventory_not_boomstick_only")
		return
	var options: Array[String] = p._eligible_options()
	if not options.has("scrap_smg") or not options.has("boomstick"):
		_fail("starter_or_previous_weapon_missing_from_card_pool")
		return

	var boom: Dictionary = cfg["weapons"]["boomstick"]
	if int(boom.get("base_pellets",0)) < 5 or int(boom.get("base_pellets",0)) > 6:
		_fail("boomstick_pellet_count")
		return
	var total_spread := rad_to_deg(float(boom.get("base_cone_step",0.0)) * float(int(boom.get("base_pellets",1))-1))
	if absf(total_spread-30.0) > 3.0:
		_fail("boomstick_spread_not_about_30_degrees")
		return
	if float(boom.get("base_fire_period",0.0)) < 0.8 or float(boom.get("base_fire_period",0.0)) > 1.0:
		_fail("boomstick_fire_period")
		return
	if float(boom.get("aim_assist_degrees",0.0)) < 40.0 or float(boom.get("aim_assist_degrees",0.0)) > 50.0:
		_fail("boomstick_aim_assist")
		return

	game.last_aim = Vector2.RIGHT
	game.enemies = [
		{"pos":game.player_pos+Vector2(160,80)},
		{"pos":game.player_pos+Vector2(-80,0)}
	]
	var assisted: Vector2 = game._boomstick_heading(float(boom["aim_assist_degrees"]))
	if assisted.dot(Vector2.RIGHT) <= 0.7:
		_fail("aim_assist_left_facing_cone")
		return

	p.weapons = {"boomstick":5}
	p.passives = {"muscle":1}
	p.evolutions.clear()
	var evolved := str(p.chest_evolution())
	if "Dragon" not in evolved:
		_fail("dragon_breath_requirement_changed")
		return

	print("STARTER_WEAPON_TEST_PASS starter=boomstick scrap_pool=true pellets=%d spread_deg=%.1f period=%.2f assist=%.1f evolution=%s" % [int(boom["base_pellets"]),total_spread,float(boom["base_fire_period"]),float(boom["aim_assist_degrees"]),evolved])
	quit(0)

func _fail(reason: String) -> void:
	push_error("STARTER_WEAPON_TEST_FAIL reason=%s" % reason)
	quit(1)
