extends Node
## All incoming damage uses one sliding window, so stacking sources cannot evade the cap.
var game: Node2D
var recent: Array[Dictionary] = []
var grace_left := 0.0
var killer := "Unknown"
var last_source := ""

func protect_after_reveal() -> void:
	grace_left = float(game.rules.fairness.reveal_grace_seconds)
	game.run_log.emit("reveal_grace", {"seconds":grace_left})

func tick(dt: float) -> void:
	grace_left = maxf(0.0,grace_left-dt)

func apply(amount: float, source: String, source_id: int = -1) -> int:
	if game.player_hp <= 0 or amount <= 0.0: return 0
	var reason := ""
	if game.phase_ui != null and game.phase_ui.god_mode: return 0 # Isolated stress fixtures do not simulate damage ticks.
	if game.guidance != null and game.guidance.briefing: reason = "camera_reveal"
	elif grace_left > 0.0: reason = "reveal_grace"
	elif game.progression != null and game.progression.invulnerability > 0.0: reason = "modal_grace"
	var cfg: Dictionary = game.rules.fairness
	var now: float = game.run_clock
	while not recent.is_empty() and now - float(recent[0].time) >= float(cfg.window_seconds): recent.pop_front()
	var spent := 0.0
	for hit in recent: spent += float(hit.fraction)
	var remaining: float = maxf(0.0,float(cfg.damage_fraction_per_second)-spent)
	var allowed := mini(floori(amount),floori(float(game.player_max_hp)*remaining+0.000001))
	if source in ["pump_explosion","explosion"]:
		allowed = mini(allowed,floori(game.player_max_hp*float(cfg.pump_max_fraction)))
	if allowed <= 0 and reason == "": reason = "rolling_damage_cap"
	if reason != "": allowed = 0
	var before: int = game.player_hp
	allowed = mini(allowed,before)
	if allowed > 0:
		game.player_hp -= allowed
		recent.append({"time":now,"fraction":float(allowed)/maxf(1.0,game.player_max_hp)})
		last_source = source
		killer = str(game.rules.source_labels.get(source,source.capitalize()))
		game.wave_damage_taken += allowed
		game.wave_min_hp = mini(game.wave_min_hp,game.player_hp)
		game.stage1_wave_min_hp_pct = minf(game.stage1_wave_min_hp_pct,100.0*game.player_hp/maxf(1.0,game.player_max_hp))
		game.stage1_damage_sources[source] = int(game.stage1_damage_sources.get(source,0))+allowed
		game.run_log.sample_hp(source,allowed)
		game.events.player_damaged()
	game.run_log.damage_tick(source,source_id,amount,allowed,before,reason)
	return allowed
