extends Node2D

var game: Node
var damage := 2.0
var speed := 150.0
var life := 12.0
var tags: Array = []
var bite_clock := 0.0

func _ready() -> void:
	z_index = 4
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or int(game.player_hp) <= 0:
		queue_free()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	bite_clock = maxf(0.0,bite_clock-delta)
	var target_index := _nearest_enemy()
	if target_index < 0:
		position = position.move_toward(Vector2(game.player_pos),speed*delta)
		return
	if target_index >= game.enemies.size():
		return
	var target := Vector2(game.enemies[target_index]["pos"])
	if position.distance_to(target) <= 34.0:
		if bite_clock <= 0.0:
			bite_clock = 0.55
			game.phase_b_damage_enemy(target_index,damage,false,"mutation:crawler")
			EventBus.hit_landed.emit({"source":"mutation:crawler","tags":tags.duplicate(),"position":target,"damage":damage})
	else:
		position = position.move_toward(target,speed*delta)
	queue_redraw()

func _nearest_enemy() -> int:
	var best := INF
	var chosen := -1
	for i in range(game.enemies.size()):
		var d := position.distance_squared_to(Vector2(game.enemies[i]["pos"]))
		if d < best:
			best = d
			chosen = i
	return chosen

func _draw() -> void:
	draw_circle(Vector2.ZERO,10.0,Color("#B6D85A"))
	draw_circle(Vector2(4,-2),2.5,Color("#14110F"))
