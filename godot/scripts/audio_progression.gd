extends "res://scripts/tuned_progression.gd"
func _collect_xp(amount: int) -> void:
	super._collect_xp(amount)
	SoundManager.xp_gem()
func _spawn_molotovs() -> void:
	var before := molotov_pools.size()
	super._spawn_molotovs()
	if molotov_pools.size()>before:
		SoundManager.play("molotov_throw")
		SoundManager.play("molotov_burst",molotov_pools[-1].pos)
func _fire_lightning() -> void:
	var before := lightning_arcs.size()
	super._fire_lightning()
	if lightning_arcs.size()>before: SoundManager.play("lightning_zap")
func _spawn_rockets() -> void:
	var before := rockets.size()
	super._spawn_rockets()
	if rockets.size()>before: SoundManager.play("rocket_launch")
func _fire_drones() -> void:
	var before := drone_shots.size()
	super._fire_drones()
	if drone_shots.size()>before: SoundManager.play("drone_fire")
func _spawn_chakrams() -> void:
	var before := chakrams.size()
	super._spawn_chakrams()
	if chakrams.size()>before: SoundManager.play("hubcap_throw")
func _damage_area(center: Vector2, radius: float, damage: float, source: String) -> void:
	super._damage_area(center,radius,damage,source)
	if source in ["rocket","carpet_bomber","drone_rocket"]: SoundManager.play("rocket_hit",center)
func chest_evolution() -> String:
	var result := super.chest_evolution()
	if result!="": SoundManager.play("evolution")
	return result
