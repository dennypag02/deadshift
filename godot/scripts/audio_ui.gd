extends "res://scripts/movement_ui.gd"
func _start_from_title() -> void:
	SoundManager.play("button_tap")
	super._start_from_title()
	SoundManager.start_music("outskirts_gameplay")
func _show_main_menu() -> void:
	super._show_main_menu()
	SoundManager.start_music("title_theme")
func _open_levelup_cards() -> void:
	super._open_levelup_cards()
	SoundManager.play("level_up")
func _run_chest_reveal(reward: String) -> void:
	SoundManager.play("chest_open")
	super._run_chest_reveal(reward)
func _pick(index: int) -> void:
	if index>=0 and index<current_choices.size(): SoundManager.play("card_pick")
	super._pick(index)
func _reroll() -> void:
	var before: int = progression.rerolls_left
	super._reroll()
	if progression.rerolls_left<before: SoundManager.play("reroll")
func _banish() -> void:
	super._banish()
	SoundManager.play("banish")
func show_game_over(time_survived: float, wave_number: int, player_level: int, kill_count: int, run_score: int, scrap: int, pause_tree: bool = true) -> void:
	super.show_game_over(time_survived,wave_number,player_level,kill_count,run_score,scrap,pause_tree)
	SoundManager.play("player_death")
	SoundManager.start_music("game_over_music")
	game.run_log.emit("audio_end",SoundManager.report())
