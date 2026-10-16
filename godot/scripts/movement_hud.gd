extends "res://scripts/polish_hud.gd"
## One small FIFO notification band; no gameplay banner occupies the survivor's space.
var notifications: Array[Dictionary] = []
var notification_left := 0.0
var notification_title := ""
var notification_detail := ""
var last_legacy := ""
var band_text: Label
var band_detail: Label

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.position = Vector2(8,float(game.rules.ui.banner_y))
	backdrop.size = Vector2(400,float(game.rules.ui.banner_height))
	backdrop.clip_contents = true
	# Keep the inherited labels alive for baseline HUD bookkeeping, but never draw its large banner.
	for child in backdrop.get_children():
		if child is CanvasItem: child.hide()
	var layer := Node2D.new()
	backdrop.add_child(layer)
	band_text = _label("",int(game.rules.ui.banner_title_size),layer)
	band_text.position = Vector2(8,0)
	band_text.size = Vector2(384,25)
	band_text.clip_text = true
	band_detail = _label("",int(game.rules.ui.banner_detail_size),layer)
	band_detail.position = Vector2(8,24)
	band_detail.size = Vector2(384,20)
	band_detail.clip_text = true
	card_panel.position.y = float(game.rules.ui.card_y)
	card_panel.size.y = float(game.rules.ui.card_height)
	card_panel.clip_contents = true
	objective_label.position = Vector2(70,5)
	objective_label.size = Vector2(275,29)
	objective_label.add_theme_font_size_override("font_size",int(game.rules.ui.card_title_size))
	progress_label.position = Vector2(70,36)
	progress_label.size = Vector2(315,30)
	progress_label.clip_text = true
	countdown.position = Vector2(14,4)
	countdown.size = Vector2(42,42)
	countdown_label.position = Vector2(10,47)
	countdown_label.size = Vector2(52,22)
	reward_icon.position = Vector2(354,7)
	reward_icon.size = Vector2(32,27)
	arsenal_row.position.y = float(game.rules.ui.arsenal_y)
	airstrike_button.position.y = float(game.rules.ui.arsenal_y)
	missed_toast.position.y = float(game.rules.ui.toast_y)

func notify(title: String, detail: String = "") -> void:
	if title == notification_title and notification_left>0: return
	for row in notifications:
		if row.title==title: return
	if notifications.size()>=int(game.rules.ui.banner_queue_cap): notifications.pop_front()
	notifications.append({"title":title,"detail":detail})

func clear_notifications() -> void:
	notifications.clear()
	notification_left = 0.0
	backdrop.hide()

func _process(delta: float) -> void:
	var legacy: String = game.banner.text
	game.banner.text = ""
	previous_event = ""
	banner_queue.clear()
	event_time = 0.0
	super._process(delta)
	game.banner.text = legacy
	game.banner.hide() # Legacy Label must never be made visible by pickup callbacks.
	if legacy!="" and legacy!=last_legacy:
		last_legacy = legacy
		var lines := legacy.split("\n",false,1)
		notify(lines[0],lines[1] if lines.size()>1 else "")
	if game.player_hp<=0:
		clear_notifications()
		return
	notification_left = maxf(0.0,notification_left-delta/maxf(0.02,Engine.time_scale))
	if notification_left<=0 and not notifications.is_empty():
		var row: Dictionary = notifications.pop_front()
		notification_title = row.title
		notification_detail = row.detail
		notification_left = float(game.rules.ui.banner_seconds)
	band_text.text = notification_title
	band_detail.text = notification_detail
	backdrop.visible = notification_left>0
	backdrop.modulate.a = 1.0

func _update_event_card() -> void:
	if game.events==null: return
	super._update_event_card()
	crate_row.hide()
	objective_progress.hide()
	direction_label.hide()
	reward_label.hide()
	progress_label.show()
	var ev: Node2D = game.events
	if ev.active.is_empty():
		objective_label.text = "SURVIVE - " + ev.rhythm().to_upper()
		progress_label.text = "Keep moving. Gather XP."
	else:
		objective_label.text = str(ev.active.verb) + " - " + str(ev.active.title)
		var distance: int = game.guidance.distance_metres() if game.guidance!=null else 0
		progress_label.text = "%s | %d m > %s" % [ev.progress_text(),distance,ev.active.short_reward]
	progress_label.add_theme_font_size_override("font_size",int(game.rules.ui.card_detail_size))
	# Keep two lines; clip unusually long text rather than covering gameplay.
	objective_label.clip_text = true
	missed_toast.visible = ev.toast_left>0
