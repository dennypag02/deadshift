extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var g = load("res://scenes/Outskirts.tscn").instantiate()
	root.add_child(g)
	var test = load("res://scripts/movement_contract.gd").new()
	var failures: int = test.run_on(g)
	quit(0 if failures==0 else 1)
