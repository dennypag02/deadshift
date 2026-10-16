extends "res://scripts/juice_fx.gd"
var frame_hits := 0
var number_accum: Dictionary = {}

func _visible_at(point: Vector2) -> bool:
	return game._is_position_on_screen(point)

func emit(kind: String, position: Vector2, direction: Vector2, duration: float) -> void:
	if not _visible_at(position): return
	var cap: int = game.rules.performance.particles
	if effects.size()>=cap: return
	super.emit(kind,position,direction,duration)

func shot(position: Vector2, _direction: Vector2) -> void:
	super.shot(position,game.facing)

func hit(position: Vector2, direction: Vector2) -> void:
	if not _visible_at(position) or frame_hits>=int(game.rules.performance.hit_effects_per_frame): return
	frame_hits += 1
	super.hit(position,direction)

func kill(position: Vector2, value: int) -> void:
	if _visible_at(position): super.kill(position,value)

func damage_number(uid: int, position: Vector2, amount: float, crit: bool) -> void:
	if not _visible_at(position): return
	var sum := float(number_accum.get(uid,0.0))+amount
	if sum < float(game.rules.performance.number_min_amount):
		number_accum[uid] = sum
		return
	number_accum.erase(uid)
	super.damage_number(uid,position,sum,crit)

func _process(delta: float) -> void:
	var profile_start := Time.get_ticks_usec()
	frame_hits = 0
	if number_accum.size()>int(game.rules.fairness.history_capacity): number_accum.clear()
	super._process(delta)
	game.step_profile["cosmetic_fx_ms"] = (Time.get_ticks_usec()-profile_start)/1000.0
