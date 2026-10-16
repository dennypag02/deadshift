extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var test = load("res://scripts/audio_contract.gd").new()
	var errors: int = test.run_checks(self)
	quit(0 if errors==0 else 1)
