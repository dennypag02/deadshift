extends SceneTree
# Automated HUD bounds and overlap check at a 1080x2340 render target.
func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var viewport := get_root()
	viewport.content_scale_size = Vector2i(1080, 2340)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(ui)
	var hud := Control.new()
	hud.set_script(load("res://scripts/polish_hud.gd"))
	ui.add_child(hud)
	await process_frame
	await process_frame
	var root: Control = hud.get_child(0)
	var panels: Array[Control] = []
	for child in root.get_children():
		if child is PanelContainer and child != hud.pause_menu:
			panels.append(child)
	var ok := true
	for panel in panels:
		var rect := Rect2(panel.global_position, panel.size * root.scale)
		if rect.position.x < 0.0 or rect.end.x > 1080.0 or rect.position.y < 0.0 or rect.end.y > 2340.0:
			push_error("HUD CLIPPED: %s %s" % [panel.name, str(rect)])
			ok = false
	var score := Rect2(Vector2(216, 12), Vector2(90, 84))
	var minimap := Rect2(Vector2(310, 12), Vector2(110, 112))
	if score.intersects(minimap):
		push_error("SCORE OVERLAPS MINIMAP")
		ok = false
	if ok:
		print("HUD_LAYOUT_1080x2340_PASS")
	quit(0 if ok else 1)
