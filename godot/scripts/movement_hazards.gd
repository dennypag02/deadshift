extends Node2D
## Goo stays under actors; damaging telegraphs are in a separate layer above HUD banners.
var game: Node2D
var danger: Node2D
class DangerLayer:
	extends Node2D
	var game: Node2D
	func _draw() -> void:
		if game==null or get_tree().paused or game.player_hp<=0: return
		var transform: Transform2D = game.get_canvas_transform()
		var scale_factor := transform.get_scale().x
		for h in game.stage1_hazards:
			if h.kind in ["goo","goo_visual"]: continue
			var p: Vector2 = transform*Vector2(h.pos)
			var radius: float = float(h.radius)*scale_factor
			var fade := clampf(float(h.life)/float(game.rules.goo.fade_seconds),0.0,1.0)
			var color := Color("#F2A23A") if str(h.kind).ends_with("warning") else Color("#EAAE47")
			# Outlined hazards are unambiguous; harmless slowing goo has no orange/cream boundary.
			draw_circle(p,radius,Color(color,0.12*fade))
			draw_arc(p,radius,0,TAU,int(game.rules.goo.segments),Color("#121816"),6*scale_factor)
			draw_arc(p,radius,0,TAU,int(game.rules.goo.segments),Color(color,maxf(0.2,fade)),3*scale_factor)
			if str(h.kind).ends_with("warning"):
				var elapsed := 1.0-float(h.life)/maxf(0.001,float(h.get("total",game.rules.threats.warning_seconds)))
				draw_arc(p,radius*elapsed,0,TAU,int(game.rules.goo.segments),Color(color,0.7),2*scale_factor)
				draw_line(p-Vector2(radius*0.3,0),p+Vector2(radius*0.3,0),color,2*scale_factor)
				draw_line(p-Vector2(0,radius*0.3),p+Vector2(0,radius*0.3),color,2*scale_factor)
		for enemy in game.enemies:
			if enemy.kind!="brute" or float(enemy.charge)>=0: continue
			var a: Vector2 = transform*Vector2(enemy.pos)
			var speed: float = game.rules.threats.early_brute_charge_speed if game.wave<=int(game.rules.threats.early_brute_until_wave) else game.rules.threats.brute_charge_speed
			var b: Vector2 = a+Vector2(enemy.charge_target)*speed*float(game.rules.threats.brute_charge_seconds)*scale_factor
			draw_line(a,b,Color("#F2A23A",0.24),float(game.rules.threats.charge_path_width)*scale_factor)
			draw_line(a,b,Color("#F2A23A"),3*scale_factor)

func _ready() -> void:
	z_index = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = int(game.rules.performance.hazard_render_layer)
	add_child(layer)
	danger = DangerLayer.new()
	danger.game = game
	layer.add_child(danger)

func _process(_delta: float) -> void:
	queue_redraw()
	danger.queue_redraw()

func _draw() -> void:
	if game==null: return
	var cfg: Dictionary = game.rules.goo
	for h in game.stage1_hazards:
		if h.kind not in ["goo","goo_visual"] or not game._is_position_on_screen(h.pos): continue
		var fade := clampf(float(h.life)/float(cfg.fade_seconds),0.0,1.0)
		var color := Color(str(cfg.color))
		for band in range(int(cfg.soft_rings),0,-1):
			var t := float(band)/float(cfg.soft_rings)
			draw_circle(h.pos,float(h.radius)*t,Color(color,float(cfg.opacity)*fade/float(cfg.soft_rings)))
		draw_arc(Vector2(h.pos)+Vector2(-float(h.radius)*0.2,-float(h.radius)*0.2),float(h.radius)*0.45,PI,PI*1.65,12,Color(Color(str(cfg.highlight)),0.36*fade),2)
