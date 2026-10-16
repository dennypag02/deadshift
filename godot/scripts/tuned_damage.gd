extends "res://scripts/fair_damage.gd"
## Explicit provenance is required for player-caused explosions; legacy sources stay enemy-capped.
func apply(amount: float, source: String, source_id: int = -1) -> int:
	var incoming := amount
	if source in ["player_pump_explosion","player_barrel_explosion","player_explosion"]:
		incoming = minf(incoming,floorf(game.player_max_hp*float(game.tuning.pumps.player_explosion_cap)))
	elif source in ["pump_explosion","barrel_explosion","explosion"]:
		incoming = minf(incoming,floorf(game.player_max_hp*float(game.tuning.pumps.enemy_explosion_cap)))
	return super.apply(incoming,source,source_id)
