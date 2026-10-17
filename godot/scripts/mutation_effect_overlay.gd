extends Node2D

var manager: Node

func _process(_delta: float) -> void:
	queue_redraw()

func _tag_color(tags: Array) -> Color:
	if tags.has("acid"): return Color("#9BD13B",0.42)
	if tags.has("fire"): return Color("#FF7A2C",0.42)
	if tags.has("shock"): return Color("#58C8FF",0.42)
	if tags.has("bone"): return Color("#E8DFC6",0.42)
	if tags.has("swarm"): return Color("#A46BD9",0.42)
	return Color(1,1,1,0.3)

func _draw() -> void:
	if manager == null:
		return
	for zone in manager.zones:
		draw_circle(Vector2(zone["pos"]),float(zone["radius"]),_tag_color(zone["tags"]))
	for flash in manager.flashes:
		var c := _tag_color(flash["tags"])
		if str(flash["kind"]) == "line":
			draw_line(Vector2(flash["a"]),Vector2(flash["b"]),c,7.0)
		else:
			draw_arc(Vector2(flash["a"]),float(flash["radius"]),0.0,TAU,42,c,6.0)
