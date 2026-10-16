extends "res://scripts/objective_guidance.gd"

func _ready() -> void:
	super._ready()
	brief_text.position = Vector2(16,float(game.rules.ui.banner_y))
	brief_text.size = Vector2(400,float(game.rules.ui.banner_height))
	brief_text.add_theme_font_size_override("font_size",int(game.rules.ui.banner_detail_size))

func begin_briefing() -> void:
	super.begin_briefing()
	brief_text.hide() # The single HUD queue owns all notifications, including paused reveals.
	if game.run_log!=null: game.run_log.emit("reveal_started",{"paused":get_tree().paused})

func end_briefing() -> void:
	var was_briefing := briefing
	super.end_briefing()
	if was_briefing and game.fairness!=null: game.fairness.protect_after_reveal()
