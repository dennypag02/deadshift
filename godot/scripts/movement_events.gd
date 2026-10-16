extends "res://scripts/stage2_events.gd"
var pending_wave := 0
var phase := "breather"
var anchor := Vector2.ZERO
var payoff_left := 0.0
var payoff_at := Vector2.ZERO
var used_positions: Dictionary = {}
var support_positions: Dictionary = {}
var reward_origin := Vector2.ZERO

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/movement_events.json"))
	z_index = 4

func rhythm() -> String:
	if not game.wave_active: return "break"
	if game.wave_clock>=game._wave_duration()-float(game.rules.pressure.surge_seconds): return "surge"
	return phase

func _points(event_kind: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var center: Vector2 = game.nearby_objective_position()
	var count := 3 if event_kind in ["supplies","relay"] else 1
	for i in range(count):
		var p := center
		if i>0: p = game._nearest_walkable_position(center+Vector2.from_angle(TAU*float(i)/count)*game.metres(float(game.rules.objectives.cluster_metres)),game.PLAYER_RADIUS)
		result.append(p)
	return result

func start_wave(number: int) -> void:
	if offered_waves.has(number): return
	if not active.is_empty(): resolve("missed","wave_ended")
	pending_wave = number
	phase = "breather"
	if number==10:
		offered_waves[number] = true
		pending_wave = 0
		game.run_log.emit("final_stand_started",{"arsenal":earned.keys()})

func _offer() -> void:
	var number := pending_wave
	pending_wave = 0
	offered_waves[number] = true
	for definition in config.schedule:
		if int(definition.wave)!=number: continue
		active = definition.duplicate(true)
		var points := _points(str(active.kind))
		active.merge({"elapsed":0.0,"charge":0.0,"step":0,"hp":float(active.target_hp),"carrying":false,"mechanic_uid":-1,"status":"active","points":points})
		anchor = points[0]
		used_positions[active.id] = points
		active["row"] = {"id":active.id,"kind":kind(),"verb":active.verb,"wave":number,"offered_s":game.run_clock,"deadline_s":game.run_clock+float(active.seconds),"status":"active","time_to_complete_s":null,"rewards":active.rewards.duplicate(),"offered_distance_m":game.player_pos.distance_to(anchor)/game.metres(1.0)}
		game.run_log.rows.append(active.row)
		if kind()=="supplies":
			game.supply_caches.clear()
			for p in points: game.supply_caches.append({"pos":p,"name":"Supply crate","collected":false})
		if kind()=="mechanic": _spawn_mechanic()
		phase = "announce"
		game.announce(str(active.verb)+" - "+str(active.title),"%d s > %s" % [active.seconds,active.short_reward])
		game.run_log.emit("event_offered",active.row)
		game.guidance.refresh_target()
		game.guidance.rebuild_route()
		game.run_log.checkpoint()
		return

func is_tutorial() -> bool:
	return game.wave==1 and (pending_wave==1 or (not active.is_empty() and active.id=="generator"))

func spawn_allowed(pos: Vector2, radius: float = 24.0) -> bool:
	if active.is_empty(): return true
	return super.spawn_allowed(pos,radius)

func target() -> Dictionary:
	if active.is_empty(): return {}
	var point: Vector2 = active.points[mini(int(active.step),active.points.size()-1)]
	if kind()=="mechanic":
		var index := _mechanic_index()
		if index>=0: point = game.enemies[index].pos
	return {"id":str(active.id)+(str("_step_",active.step) if int(active.step)>0 else ""),"kind":str({"HOLD":"bolt","GRAB":"crate","DESTROY":"skull"}[active.verb]),"label":active.title,"pos":point,"done":false,"reward":active.reward,"reward_icon":active.reward_icon}

func map_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not active.is_empty(): result.append(target())
	return result

func progress_text() -> String:
	if active.is_empty(): return "KEEP MOVING"
	match str(active.verb):
		"HOLD":
			if int(active.count)>1: return "%d/%d | %d%%" % [active.step,active.count,roundi(float(active.charge)/float(active.hold_seconds)*100)]
			return "%d%%" % roundi(float(active.charge)/float(active.hold_seconds)*100)
		"GRAB": return "%d/%d" % [active.step,active.count]
		"DESTROY": return "HP %d" % ceili(float(active.hp))
	return ""

func progress_ratio() -> float:
	if active.is_empty(): return 0.0
	if active.verb=="DESTROY": return float(active.hp)/maxf(1.0,active.target_hp)
	return (float(active.step)+float(active.charge)/maxf(0.01,float(active.hold_seconds)))/float(active.count)

func player_damaged() -> void:
	if bool(game.rules.objectives.progress_reset_on_damage): super.player_damaged()

func movement_multiplier() -> float:
	return 1.0

func mechanic_damage_multiplier(_enemy: Dictionary) -> float:
	return 1.0 # DESTROY only: no hidden weak-point or timing puzzle.

func tick(dt: float) -> void:
	toast_left = maxf(0.0,toast_left-dt)
	shot_left = maxf(0.0,shot_left-dt)
	payoff_left = maxf(0.0,payoff_left-dt)
	_tick_rewards(dt)
	if pending_wave>0 and game.wave_clock>=float(game.rules.objectives.breather_seconds): _offer()
	if active.is_empty():
		queue_redraw()
		return
	active.elapsed = float(active.elapsed)+dt
	if phase=="announce" and active.elapsed>=float(game.rules.objectives.announce_seconds): phase = "event"
	if remaining()<=0:
		resolve("missed","timeout")
		return
	var inside: bool = game.player_pos.distance_to(target().pos)<float(game.rules.objectives.interact_radius)
	if active.verb=="HOLD":
		active.charge = float(active.charge)+dt if inside else 0.0
		if float(active.charge)>=float(active.hold_seconds):
			active.step = int(active.step)+1
			active.charge = 0.0
			if int(active.step)>=int(active.count):
				if kind()=="generator": game.generator_active = true
				resolve("completed","held")
	elif active.verb=="GRAB" and inside:
		if kind()=="supplies": game.supply_caches[int(active.step)].collected = true
		active.step = int(active.step)+1
		if int(active.step)>=int(active.count): resolve("completed","grabbed")
	elif kind()=="mechanic":
		var index := _mechanic_index()
		if index<0: resolve("completed","destroyed")
		else: active.hp = game.enemies[index].hp
	queue_redraw()

func aim_target() -> Dictionary:
	# Allow the trigger even when DESTROY is the last target. Movement still binds every bullet heading.
	return {"pos":target().pos} if not active.is_empty() and active.verb=="DESTROY" else {}

func hit_bullet(pos: Vector2, damage: float) -> bool:
	if active.is_empty() or active.verb!="DESTROY" or kind()=="mechanic": return false
	if pos.distance_to(target().pos)>float(game.rules.objectives.destroy_radius): return false
	active.hp = maxf(0.0,float(active.hp)-damage)
	if active.hp<=0: resolve("completed","destroyed")
	return true

func pump_exploded(_pos: Vector2) -> void:
	pass # Nearby DESTROY markers no longer require map-wide pump order.

func resolve(status: String, reason: String) -> void:
	if active.is_empty(): return
	var pos: Vector2 = target().pos
	var title: String = active.title
	var reward: String = active.short_reward
	reward_origin = pos
	super.resolve(status,reason)
	phase = "event" # Continue fighting until the scheduled surge/break.
	game.banner.text = ""
	if status=="completed":
		payoff_at = pos
		payoff_left = float(game.rules.objectives.payoff_seconds)
		game.announce("COMPLETE - "+title,"EARNED: "+reward)
		game._haptic_pulse(30)

func _grant(reward: String) -> void:
	if reward in ["chest","big_chest","nuke"]:
		earned[reward] = true
		game.run_log.emit("reward_earned",{"reward":reward,"requires_pickup":true})
		game.drop_reward("Nuke" if reward=="nuke" else "Chest",game.player_pos)
	else:
		if reward in ["auto_turret","flamethrower"]: support_positions[reward] = reward_origin
		super._grant(reward)

func _tick_rewards(dt: float) -> void:
	if earned.has("auto_turret"):
		turret_clock -= dt
		if turret_clock <= 0.0:
			turret_clock = value("turret_interval")
			var best := -1
			var distance := value("turret_range")
			for i in game.enemy_indices_near(support_positions.get("auto_turret",game.GENERATOR_POS),value("turret_range")):
				var d: float = Vector2(game.enemies[i]["pos"]).distance_to(support_positions.get("auto_turret",game.GENERATOR_POS))
				if d < distance:
					distance = d
					best = i
			if best >= 0:
				shot_to = game.enemies[best]["pos"]
				shot_left = 0.08
				game.phase_b_damage_enemy(best,value("turret_damage"),false,"auto_turret")
	if earned.has("flamethrower"):
		flame_clock -= dt
		if flame_clock <= 0.0:
			flame_clock = value("flame_interval")
			var point: Vector2 = support_positions.get("flamethrower",_walk(Vector2(16.0,35.0)*game.TILE))
			var indices: Array = game.enemy_indices_near(point,value("flame_radius"))
			indices.sort()
			indices.reverse()
			for i in indices:
				if Vector2(game.enemies[i]["pos"]).distance_to(point) < value("flame_radius"):
					game.phase_b_damage_enemy(i,value("flame_damage"),false,"flamethrower")

func value(key: String) -> float:
	if key=="interact_radius": return float(game.rules.objectives.interact_radius)
	if key in ["generator_charge_seconds","relay_charge_seconds"] and not active.is_empty(): return float(active.hold_seconds)
	return super.value(key)

func _draw() -> void:
	if game == null: return
	if earned.has("auto_turret"):
		GUIDE.draw_icon(self,support_positions.get("auto_turret",game.GENERATOR_POS),"relay",20.0,AMBER)
		if shot_left > 0.0: draw_line(support_positions.get("auto_turret",game.GENERATOR_POS),shot_to,AMBER,3.0)
	if earned.has("flamethrower"):
		var point: Vector2 = support_positions.get("flamethrower",_walk(Vector2(16,35)*game.TILE))
		draw_arc(point,value("flame_radius"),0,TAU,24,Color(AMBER,0.3),5.0)
	if payoff_left>0:
		var t := payoff_left/float(game.rules.objectives.payoff_seconds)
		draw_arc(payoff_at,float(game.rules.objectives.payoff_radius)*(1-t),0,TAU,32,Color(AMBER,t),4)
	if active.is_empty(): return
	var point: Vector2 = target()["pos"]
	if kind() == "supplies":
		for cache in game.supply_caches:
			if not cache["collected"]: GUIDE.draw_icon(self,cache["pos"],"crate",25.0,AMBER)
	else:
		GUIDE.draw_icon(self,point,str(target()["kind"]),25.0,AMBER)
	if kind() in ["generator","relay"]:
		draw_arc(point,value("interact_radius"),0,TAU,32,Color(AMBER,0.25),4.0)
		var duration := value("generator_charge_seconds") if kind() == "generator" else value("relay_charge_seconds")
		draw_arc(point,value("interact_radius"),-PI/2,-PI/2+TAU*clampf(float(active["charge"])/duration,0,1),32,AMBER,7.0)
	if kind() in ["nest","chain","oil","mechanic"]:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(point+direction*35.0,point+direction*55.0,AMBER,4.0)
	if not active.is_empty() and active.verb=="HOLD" and not kind() in ["generator","relay"]:
		draw_arc(target().pos,float(game.rules.objectives.interact_radius),0,TAU,32,AMBER,4)

func interrupt(reason: String) -> void:
	pending_wave = 0
	phase = "event"
	super.interrupt(reason)
