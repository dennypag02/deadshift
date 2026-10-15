extends SceneTree

func _fail(message: String) -> void:
	push_error("SURVIVABILITY_UI_CHECK_FAIL " + message)
	paused = false
	quit(1)

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var scene: PackedScene = load("res://scenes/Outskirts.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	game.set_physics_process(false)
	if game.progression != null:
		game.progression.set_physics_process(false)

	game.capture_mode = false
	game.phase_ui.god_mode = false
	game.wave = 1
	game.player_hp = 100
	game.player_max_hp = 100
	game.player_armor = 0
	game.player_hit_invulnerability = 0.0
	game.incoming_damage_window = 0.0
	game.incoming_damage_this_window = 0.0
	game.progression.invulnerability = 0.0

	var enemy := {
		"uid": 9001,
		"pos": game.player_pos + Vector2(20, 0),
		"kind": "shambler",
		"hp": 10.0,
		"speed": 0.0,
		"radius": 18.0,
		"charge": 0.0,
		"contact_cooldown": 0.0,
	}
	game.enemies.clear()
	game.enemies.append(enemy)
	print("SURV_CHECK checkpoint=single_hit")
	game._apply_player_contact_damage(game.enemies[0])
	if game.player_hp != 94:
		_fail("Wave 1 shambler should deal about 6 damage; hp=%d" % game.player_hp)
		return
	if game.player_hit_invulnerability < 0.34:
		_fail("missing configured 0.35s player hit invulnerability")
		return
	if float(game.enemies[0].get("contact_cooldown", 0.0)) < 0.79:
		_fail("missing 0.8s per-enemy contact cooldown")
		return
	var hp_after_first: int = game.player_hp
	game._apply_player_contact_damage(game.enemies[0])
	if game.player_hp != hp_after_first:
		_fail("immediate stacked contact damage was not blocked")
		return

	print("SURV_CHECK checkpoint=damage_cap")
	game.player_hp = 100
	game.player_hit_invulnerability = 0.0
	game.incoming_damage_window = 0.0
	game.incoming_damage_this_window = 0.0
	game.enemies.clear()
	for n in range(10):
		var e := {
			"uid": 9100 + n,
			"pos": game.player_pos + Vector2.from_angle(TAU * float(n) / 10.0) * 24.0,
			"kind": "shambler",
			"hp": 10.0,
			"speed": 0.0,
			"radius": 18.0,
			"charge": 0.0,
			"contact_cooldown": 0.0,
		}
		game.enemies.append(e)
	for n in range(game.enemies.size()):
		game.player_hit_invulnerability = 0.0
		game.enemies[n]["contact_cooldown"] = 0.0
		game._apply_player_contact_damage(game.enemies[n])
	if 100 - game.player_hp > 35:
		_fail("incoming damage exceeded 35 percent per second cap")
		return

	print("SURV_CHECK checkpoint=density")
	game.wave = 1
	game.wave_clock = 0.0
	if game._active_horde_target() != 20:
		_fail("opening on-screen target is not 20")
		return
	game.wave_clock = float(game.progression.config.get("pacing", {}).get("wave_duration_seconds", 75.0))
	if game._active_horde_target() != 40:
		_fail("wave-end on-screen target is not 40")
		return

	print("SURV_CHECK checkpoint=spawn_safety")
	game.enemies.clear()
	game.wave_spawned = 0
	game.wave = 1
	game._spawn_pressure_group(10)
	var min_distance: float = float(game.progression.config.get("pacing", {}).get("min_spawn_distance_tiles", 1.5)) * game.TILE
	for e in game.enemies:
		if Vector2(e["pos"]).distance_to(game.player_pos) < min_distance - 1.0:
			_fail("spawned zombie inside 1.5-tile player safety radius")
			return

	print("SURV_CHECK checkpoint=level_cards")
	if game.phase_ui.panel.size.y < 800.0:
		_fail("level-up panel too short")
		return
	for wrapper in game.phase_ui.card_wrappers:
		if wrapper.custom_minimum_size.y < 160.0:
			_fail("level-up card too short")
			return
	for desc in game.phase_ui.card_descs:
		if desc.max_lines_visible != 2:
			_fail("level-up description does not wrap to two lines")
			return

	print("SURV_CHECK checkpoint=game_over")
	game.phase_ui.show_game_over(27.2, 1, 3, 20, 450, 0, false)
	if not game.phase_ui.game_over_panel.visible:
		_fail("game over panel did not open")
		return
	if not game.phase_ui.game_over_stats.text.contains("TIME SURVIVED"):
		_fail("game over stats missing")
		return
	paused = false

	print("SURVIVABILITY_UI_CHECK_PASS shambler=6 invuln=0.5 enemy_cd=0.8 damage_cap=35% density=20->40 game_over=PASS cards=PASS")
	print("SURV_CHECK checkpoint=cleanup")
	game.queue_free()
	quit(0)
