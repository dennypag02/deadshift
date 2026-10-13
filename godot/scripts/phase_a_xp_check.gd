extends SceneTree
func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var scene: PackedScene = load("res://scenes/Outskirts.tscn")
	var game := scene.instantiate()
	get_root().add_child(game)
	for i in range(12):
		await process_frame
	game.wave_active = false
	game.enemies.clear()
	game.phase_a_debug_six_shambler_kills()
	for i in range(30):
		await process_frame
	var ok := game.progression.level == 2
	if ok:
		print("PHASE_A_XP_6_KILL_PASS")
	else:
		push_error("PHASE_A_XP_6_KILL_FAIL level=%d xp=%d gems=%d" % [game.progression.level, game.progression.xp, game.progression.gems.size()])
	quit(0 if ok else 1)
