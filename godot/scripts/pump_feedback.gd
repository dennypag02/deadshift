extends Node2D
var game: Node2D
func _ready() -> void:
	z_index = 5
func _process(_dt: float) -> void:
	queue_redraw()
func _draw() -> void:
	for pump in game.pumps:
		if not pump.alive or int(pump.hits)==0: continue
		var cfg: Dictionary = game.tuning.pumps
		var color := Color(str(cfg.hot_color if int(pump.hits)>=2 else cfg.heat_color))
		var r := float(cfg.heat_glow_radius)
		for ring in range(int(cfg.glow_rings),0,-1):
			draw_circle(pump.pos,r*float(ring)/cfg.glow_rings,Color(color,0.04+0.025*int(pump.hits)))
		draw_arc(pump.pos,r*0.75,-PI/2,-PI/2+TAU*float(pump.hits)/cfg.hits_required,24,color,3)
