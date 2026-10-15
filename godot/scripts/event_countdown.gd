extends Control
## Outer ring = deadline. Inner ring = generator charge / relay progress.
const AMBER := Color("#F2A23A")
var game: Node2D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	var center := Vector2(26,26)
	draw_arc(center,24,-PI/2,PI*1.5,40,Color(AMBER,0.20),3.0,true)
	if game == null or game.events == null or game.events.active.is_empty(): return
	var event: Node2D = game.events
	var ratio: float = event.remaining() / float(event.active["seconds"])
	draw_arc(center,24,-PI/2,-PI/2+TAU*ratio,40,AMBER,3.0,true)
	if event.kind() in ["generator","relay"]:
		draw_arc(center,18,-PI/2,-PI/2+TAU*event.progress_ratio(),32,Color("#F2E8D8"),2.5,true)
	preload("res://scripts/objective_guidance.gd").draw_icon(self,center,str(event.target()["kind"]),10.0,AMBER)
