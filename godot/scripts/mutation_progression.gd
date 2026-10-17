extends "res://scripts/tuned_progression.gd"

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_required(level):
		xp -= xp_required(level)
		level += 1
		var elapsed := float(game.run_clock) if game != null else 0.0
		level_times.append({"level":level,"time":elapsed})
		if game != null and game.telemetry != null:
			game.telemetry.event("level_up",{"level":level,"xp_required_next":xp_required(level),"legacy_powerup_offer":false})
		print("MUTATION_LEVEL_TRACK level=%d t=%.2f" % [level,elapsed])
