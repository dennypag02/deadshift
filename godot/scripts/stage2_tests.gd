extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	var tuning_contract = load("res://scripts/tuning_contract.gd").new()
	var failures: int = tuning_contract.run_on(g)
	g.queue_free()
	await process_frame
	g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	var contract = load("res://scripts/movement_contract.gd").new()
	failures += contract.run_on(g)
	print("STAGE2_TESTS_%s retained_movement_contract=true tuning_contract=true" % ["PASS" if failures==0 else "FAIL"])
	quit(0 if failures==0 else 1)
