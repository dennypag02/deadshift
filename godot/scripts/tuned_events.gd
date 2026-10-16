extends "res://scripts/movement_events.gd"
## Validate EVERY crate against the player and the walkable route, not just the cluster center.
func _points(event_kind: String) -> Array[Vector2]:
	if event_kind not in ["supplies","relay"]: return super._points(event_kind)
	var center: Vector2 = game.nearby_objective_position()
	var candidates: Array[Vector2] = []
	var from: Vector2i = game.guidance._walkable_cell(game.player_pos)
	var low: float = game.metres(game.rules.objectives.minimum_metres)
	var high: float = game.metres(game.rules.objectives.maximum_metres)
	for y in range(game.MAP_H):
		for x in range(game.MAP_W):
			var point: Vector2 = game._tile_center(x,y)
			var distance: float = game.player_pos.distance_to(point)
			if distance<low or distance>high or game._circle_hits_blocker(point,game.PLAYER_RADIUS) or game.NORTH_EXIT.has_point(point): continue
			var route: PackedVector2Array = game.guidance.navigation.get_point_path(from,Vector2i(x,y))
			if route.is_empty(): continue
			var length: float = game.player_pos.distance_to(route[0])
			for i in range(1,route.size()): length += route[i-1].distance_to(route[i])
			if length<=high: candidates.append(point)
	candidates.sort_custom(func(a: Vector2,b: Vector2)->bool: return a.distance_squared_to(center)<b.distance_squared_to(center))
	var result: Array[Vector2] = []
	for point in candidates:
		var separate := true
		for previous in result:
			if previous.distance_to(point)<float(game.tuning.crate_min_separation_pixels): separate = false
		if separate: result.append(point)
		if result.size()==3: break
	assert(result.size()==3,"Three nearby, reachable, distinct crate sites required")
	var distances: Array[float] = []
	for point in result: distances.append(snappedf(game.player_pos.distance_to(point)/game.metres(1),0.01))
	game.run_log.emit("all_objective_sites_checked",{"kind":event_kind,"spawn_distances_m":distances,"all_routes_max_m":game.rules.objectives.maximum_metres})
	return result
