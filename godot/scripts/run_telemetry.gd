extends Node
## Per-attempt append-only events and a crash-readable summary; no network upload.
var game: Node2D
var run_id := ""
var directory := ""
var log_file: FileAccess
var rows: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var current_wave: Dictionary = {}
var ended := false
var started := false
var attempt := 0
var run_kind := "human"
var save_clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run_kind = OS.get_environment("DEADSHIFT_RUN_KIND")
	if run_kind == "":
		run_kind = "scripted_test" if OS.get_cmdline_args().has("--script") else "human"
	run_id = "%s-%s" % [str(int(Time.get_unix_time_from_system())), str(Time.get_ticks_usec())]
	var base := OS.get_environment("DEADSHIFT_EVIDENCE_DIR")
	if base == "": base = "user://runs"
	directory = base.path_join(run_id)
	DirAccess.make_dir_recursive_absolute(directory)
	log_file = FileAccess.open(directory.path_join("events.jsonl"), FileAccess.WRITE)
	if log_file == null: push_error("RUN_TELEMETRY_OPEN_FAILED " + directory)
	emit("run_created", {"run_kind":run_kind, "platform":OS.get_name(), "rng_seed":str(game.rng.seed), "first_run_in_install":null})

func begin() -> void:
	if started: return
	started = true
	if run_kind == "human":
		var history := ConfigFile.new()
		history.load("user://run_history.cfg")
		attempt = int(history.get_value("runs", "started", 0)) + 1
		history.set_value("runs", "started", attempt)
		history.save("user://run_history.cfg")
	emit("run_started", {"attempt_in_install":attempt, "first_run_in_install":attempt == 1 if run_kind == "human" else null})
	checkpoint()

func emit(kind: String, values: Dictionary = {}) -> void:
	var row := {"event":kind, "run_id":run_id, "active_s":snappedf(game.run_clock, 0.001), "wave":game.wave, "hp":game.player_hp, "max_hp":game.player_max_hp}
	row.merge(values)
	var text := JSON.stringify(row)
	print("STAGE2 ", text)
	if log_file != null:
		log_file.store_line(text)
		log_file.flush()

func start_wave() -> void:
	if not current_wave.is_empty(): close_wave("interrupted")
	current_wave = {"wave":game.wave, "start_s":game.run_clock, "min_hp":game.player_hp, "min_hp_pct":100.0 * game.player_hp / maxf(1.0, game.player_max_hp), "damage_by_source":{}, "complete":false}
	emit("wave_started")

func sample_hp(source: String = "", damage: int = 0) -> void:
	if current_wave.is_empty(): return
	current_wave["min_hp"] = mini(int(current_wave["min_hp"]), game.player_hp)
	current_wave["min_hp_pct"] = minf(float(current_wave["min_hp_pct"]), 100.0 * game.player_hp / maxf(1.0, game.player_max_hp))
	if source != "" and damage > 0:
		var by_source: Dictionary = current_wave["damage_by_source"]
		by_source[source] = int(by_source.get(source, 0)) + damage

func close_wave(reason: String) -> void:
	if current_wave.is_empty(): return
	sample_hp()
	current_wave["end_s"] = game.run_clock
	current_wave["duration_s"] = game.run_clock - float(current_wave["start_s"])
	current_wave["complete"] = reason == "completed"
	current_wave["outcome"] = reason
	current_wave["level"] = game.progression.level
	waves.append(current_wave.duplicate(true))
	emit("wave_summary", current_wave)
	current_wave.clear()
	checkpoint()

func summary() -> Dictionary:
	var offered := 0
	var completed := 0
	var missed := 0
	var interrupted := 0
	var active := 0
	var rewards: Array = []
	for row in rows:
		offered += 1
		match str(row["status"]):
			"completed": completed += 1
			"missed": missed += 1
			"interrupted": interrupted += 1
			_: active += 1
		if row["status"] == "completed": rewards.append_array(row.get("rewards", []))
	var result := {"schema":1,"run_id":run_id,"run_kind":run_kind,"attempt_in_install":attempt,"first_run_in_install":attempt == 1 if run_kind == "human" else null,"started":started,"ended":ended,"active_seconds":game.run_clock,"wave":game.wave,"hp":game.player_hp,"max_hp":game.player_max_hp,"level":game.progression.level,"events_offered":offered,"events_completed":completed,"events_missed":missed,"events_interrupted":interrupted,"events_active":active,"event_details":rows,"rewards_earned":rewards,"waves":waves,"current_wave_partial":current_wave,"level_up_times":game.progression.level_times,"death_before_wave4":game.player_hp <= 0 and game.wave < 4 if ended else null,"final_stand_survived":game.wave10_survived,"human_survival_rate_inferred":false}
	return result

func checkpoint() -> void:
	var file := FileAccess.open(directory.path_join("summary.tmp"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary(), "  "))
		file.flush()
		file.close()
		DirAccess.rename_absolute(directory.path_join("summary.tmp"), directory.path_join("summary.json"))

func finish(reason: String) -> void:
	if ended: return
	if is_instance_valid(game.events): game.events.interrupt(reason)
	close_wave(reason)
	ended = true
	emit("run_ended", {"reason":reason,"death_wave":game.wave if game.player_hp <= 0 else null,"death_before_wave4":game.player_hp <= 0 and game.wave < 4,"reached_wave4":game.wave >= 4,"final_stand_survived":game.wave10_survived})
	checkpoint()

func _process(delta: float) -> void:
	if not started or ended: return
	sample_hp()
	save_clock += delta
	if save_clock >= 10.0:
		save_clock = 0.0
		checkpoint()

func _exit_tree() -> void:
	if started and not ended and is_instance_valid(game): finish("interrupted")
