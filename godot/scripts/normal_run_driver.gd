extends RefCounted
## Input-only qualification controller. No health, XP, enemy, weapon or position writes.
var game: Node2D
var last_direction := Vector2.UP
var route := PackedVector2Array()
var next_route_time := 0.0
var last_goal := Vector2.INF
func direction() -> Vector2:
	var player: Vector2 = game.player_pos
	var goal: Vector2 = Vector2(game.MAP_SIZE)*0.5
	var target: Dictionary = game.events.target()
	if not target.is_empty(): goal = target.pos
	var nearest := 700.0
	var combat_goal := false
	for enemy in game.enemies:
		var d: float = player.distance_to(enemy.pos)
		if d<nearest and d>100.0:
			nearest = d
			goal = enemy.pos
			combat_goal = true
	if not target.is_empty() and game.progression.level>=3 and nearest>250.0:
		goal = target.pos
		combat_goal = false
	var gem_dist := 520.0
	for gem in game.progression.gems:
		var d: float = player.distance_to(gem.pos)
		if d<gem_dist:
			gem_dist = d
			goal = gem.pos
			combat_goal = false
	for pickup in game.powerups:
		var d: float = player.distance_to(pickup.pos)
		var important: bool = str(pickup.kind) in ["Chest","Upgrade crate","Magnet"] or (str(pickup.kind)=="Medkit" and game.player_hp<game.player_max_hp*0.8)
		if important and d<350.0:
			goal = pickup.pos
			combat_goal = false
	if not target.is_empty() and game.events.kind() in ["generator","relay"] and player.distance_to(target.pos)<80.0:
		var safe := true
		for enemy in game.enemies:
			if player.distance_to(enemy.pos)<120.0: safe = false
		for hazard in game.stage1_hazards:
			if str(hazard.kind) not in ["goo","goo_visual"] and player.distance_to(hazard.pos)<float(hazard.radius)+50.0: safe = false
		if safe: return Vector2.ZERO
	var desired: Vector2 = (goal-player).normalized()
	if not combat_goal:
		if game.run_clock>=next_route_time or goal.distance_to(last_goal)>128:
			next_route_time = game.run_clock+0.5
			last_goal = goal
			route = game.guidance.navigation.get_point_path(game.guidance._walkable_cell(player),game.guidance._walkable_cell(goal))
		if route.size()>1:
			var best := 0
			var near := INF
			for i in range(route.size()):
				var d: float = player.distance_to(route[i])
				if d<near: best=i; near=d
			var next := mini(best+(1 if near<90 else 0),route.size()-1)
			desired = (route[next]-player).normalized()
			if player.distance_to(goal)<130: desired = (goal-player).normalized()
	var best_score := -INF
	var result := -last_direction
	var bounds := Rect2(Vector2.ONE*75,Vector2(game.MAP_SIZE)-Vector2.ONE*150)
	var directions: Array[Vector2] = [desired,last_direction]
	for enemy in game.enemies:
		var relative: Vector2 = Vector2(enemy.pos)-player
		if relative.length()>100.0 and relative.length()<600.0:
			directions.append(relative.normalized())
			break
	for index in range(24): directions.append(Vector2.from_angle(TAU*index/24.0))
	for d in directions:
		var ahead: Vector2 = player+d*100.0
		if not bounds.has_point(ahead) or game._circle_hits_blocker(ahead,game.PLAYER_RADIUS) or game._circle_hits_blocker(player+d*40.0,game.PLAYER_RADIUS): continue
		var score := d.dot(desired)*2.0+d.dot(last_direction)*0.15
		var shooting := 0.0
		for enemy in game.enemies:
			var relative: Vector2 = Vector2(enemy.pos)-player
			if relative.length()>750: continue
			var gap: float = ahead.distance_to(enemy.pos)-float(enemy.radius)-game.PLAYER_RADIUS
			if gap<120: score -= pow(maxf(0,1-gap/120),2)*4.0
			if relative.length()>110 and relative.normalized().dot(d)>0.97:
				shooting += minf(1.0,200.0/maxf(1,relative.length()))
			if str(enemy.kind)=="brute" and float(enemy.get("charge",0))!=0:
				var endpoint: Vector2 = Vector2(enemy.pos)+Vector2(enemy.charge_target)*350.0
				if Geometry2D.get_closest_point_to_segment(ahead,enemy.pos,endpoint).distance_to(ahead)<70: score -= 6.0
		score += minf(2.0,shooting)*1.5
		for hazard in game.stage1_hazards:
			var distance: float = ahead.distance_to(hazard.pos)
			if str(hazard.kind) in ["goo","goo_visual"]:
				if distance<float(hazard.radius): score -= 0.3
			else:
				var safe_radius: float = float(hazard.radius)+game.PLAYER_RADIUS+40.0
				if distance<safe_radius: score -= 12.0*(1-distance/safe_radius)
		if score>best_score:
			best_score=score
			result=d
	last_direction=result
	return result
