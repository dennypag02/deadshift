extends "res://scripts/run_telemetry.gd"
var damage_history: Array[Dictionary] = []
var damage_ticks := 0
var last_blocked: Dictionary = {}
var pending_lines := PackedStringArray()
var flush_clock := 0.0

func damage_tick(source: String, source_id: int, requested: float, applied: int, before: int, blocked: String) -> void:
	# Coalesce blocked attempts from the same source at one physics instant; accepted ticks never coalesce.
	var key := source + ":" + str(source_id)
	if applied == 0 and float(last_blocked.get(key,-1.0)) == game.run_clock: return
	if applied == 0: last_blocked[key] = game.run_clock
	if last_blocked.size() > int(game.rules.fairness.history_capacity): last_blocked.clear()
	var tick := {"source":source,"source_id":source_id,"requested":requested,"amount":applied,"hp_before":before,"hp_after":game.player_hp,"active_s":snappedf(game.run_clock,0.001),"max_hp":game.player_max_hp,"blocked_reason":blocked}
	damage_history.append(tick)
	damage_ticks += 1
	while not damage_history.is_empty() and game.run_clock-float(damage_history[0].active_s)>float(game.rules.fairness.death_history_seconds): damage_history.pop_front()
	# Exact last-five-second accepted ticks are retained on disk even if a storm exceeds memory bound.
	while damage_history.size()>int(game.rules.fairness.history_capacity): damage_history.pop_front()
	emit("damage_tick",tick)

func summary() -> Dictionary:
	var result := super.summary()
	result["damage_ticks"] = damage_ticks
	result["killed_by"] = game.fairness.killer if game.player_hp<=0 and game.fairness!=null else null
	result["last_five_seconds_damage"] = damage_history if game.player_hp<=0 else []
	result["pressure_samples"] = game.pressure_samples
	return result

func finish(reason: String) -> void:
	if ended: return
	flush_damage()
	if game.player_hp<=0:
		# Read the append-only log so the final five-second receipt cannot drop accepted ticks.
		var exact: Array[Dictionary] = []
		if log_file!=null: log_file.flush()
		var source := FileAccess.open(directory.path_join("events.jsonl"),FileAccess.READ)
		if source!=null:
			while not source.eof_reached():
				var line := source.get_line()
				if line.strip_edges()=="": continue
				var row = JSON.parse_string(line)
				if row is Dictionary and row.get("event","")=="damage_tick" and game.run_clock-float(row.active_s)<=float(game.rules.fairness.death_history_seconds): exact.append(row)
		var receipt := {"death_s":game.run_clock,"wave":game.wave,"killed_by":game.fairness.killer,"ticks":exact}
		FileAccess.open(directory.path_join("death_damage.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
		emit("death_damage_window",receipt)
	super.finish(reason)

func emit(kind: String, values: Dictionary = {}) -> void:
	if kind!="damage_tick":
		flush_damage()
		super.emit(kind,values)
		return
	# Preserve every tick, but amortize synchronous disk writes rather than stalling every impact.
	var row := {"event":kind,"run_id":run_id,"active_s":snappedf(game.run_clock,0.001),"wave":game.wave,"hp":game.player_hp,"max_hp":game.player_max_hp}
	row.merge(values)
	pending_lines.append(JSON.stringify(row))

func flush_damage() -> void:
	if pending_lines.is_empty() or log_file==null: return
	var start := Time.get_ticks_usec()
	log_file.store_string("\n".join(pending_lines)+"\n")
	log_file.flush()
	pending_lines.clear()
	game.step_profile["damage_log_flush_ms"] = (Time.get_ticks_usec()-start)/1000.0

func checkpoint() -> void:
	flush_damage()
	super.checkpoint()

func _process(delta: float) -> void:
	flush_clock += delta/maxf(0.02,Engine.time_scale)
	if flush_clock>=float(game.rules.performance.damage_log_flush_seconds):
		flush_clock = 0.0
		flush_damage()
	super._process(delta)

func _exit_tree() -> void:
	flush_damage()
	super._exit_tree()
