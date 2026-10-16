extends "res://scripts/movement_progression.gd"
func _damage_area(center: Vector2, radius: float, damage: float, source: String) -> void:
	# Automatic targets still come ONLY from enemy_indices_near/_nearest_enemy_index.
	# Only the two explicitly permitted splash sources can heat world explosives.
	if source in ["molotov","rocket","carpet_bomber"]: game.heat_explosives_in_area(center,radius,source)
	super._damage_area(center,radius,damage,source)
