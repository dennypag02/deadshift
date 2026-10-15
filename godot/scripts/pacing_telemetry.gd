extends Node
## Real-time active clock excludes explicit UI pauses, never hit-stop.
## Offline Movie Maker runs are clearly marked and use frame time, not fake FPS.
var game: Node2D
var log_file: FileAccess
var active_seconds := 0.0
var wall_seconds := 0.0
var pause_seconds := 0.0
var last_usec := 0
var sample_seconds := 0.0
var sample_frames: Array[float] = []
var offline := false
var ticks := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	offline = OS.get_environment("DEADSHIFT_OFFLINE_CAPTURE") == "1"
	var dir := OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	if dir == "": dir = "user://"
	DirAccess.make_dir_recursive_absolute(dir)
	log_file = FileAccess.open(dir.path_join("pacing.jsonl"),FileAccess.WRITE)
	last_usec = Time.get_ticks_usec()
	event("start", {"mode": "offline_frames" if offline else "realtime", "platform": OS.get_name(), "gpu": RenderingServer.get_video_adapter_name(), "android_runtime": OS.get_name()=="Android", "physical_device_verified": false})
func event(kind: String, values: Dictionary = {}) -> void:
	var row := {"event": kind, "active_s": snappedf(active_seconds,.001), "wall_s": snappedf(wall_seconds,.001), "pause_s": snappedf(pause_seconds,.001), "wave": game.wave}
	row.merge(values)
	var text := JSON.stringify(row)
	print("PACING ",text)
	if log_file != null:
		log_file.store_line(text)
		log_file.flush()
func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var actual := maxf(.000001,(now-last_usec)/1000000.0)
	last_usec = now
	wall_seconds += actual
	var clock_delta := delta/maxf(.02,Engine.time_scale) if offline else actual
	if not get_tree().paused and game.player_hp>0:
		active_seconds += clock_delta
		game.run_clock = active_seconds
		game._tick_wave_clock(clock_delta)
	else:
		pause_seconds += clock_delta
	sample_seconds += actual
	sample_frames.append(actual*1000.0)
	ticks += 1
	if sample_seconds>=1.0:
		sample_frames.sort()
		var p: Node2D = game.progression
		var fx: Node2D = game.juice_fx
		event("fps", {"fps": snappedf(sample_frames.size()/sample_seconds,.01), "p95_ms": sample_frames[int(sample_frames.size()*.95)], "active_entities": 1+game.enemies.size()+game.projectile_count()+p.gems.size()+fx.effects.size()+fx.decals.size()+fx.damage_numbers.size()+fx.popups.size()+game.stage1_hazards.size()+game.powerups.size()+p.molotov_pools.size(), "active_enemies": game.enemies.size(), "onscreen_enemies": game._onscreen_enemy_count(), "projectiles": game.projectile_count(), "gems": p.gems.size(), "hazards":game.stage1_hazards.size(), "pickups":game.powerups.size(),"area_effects":p.molotov_pools.size(), "particles": fx.effects.size(), "decals": fx.decals.size(), "damage_numbers": fx.damage_numbers.size(), "level": p.level, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "paused": get_tree().paused, "offline_frames": offline})
		sample_frames.clear()
		sample_seconds=0.0
