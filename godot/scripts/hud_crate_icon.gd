extends Control
var collected := false
func _ready() -> void:
	custom_minimum_size = Vector2(40, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var tint := Color("#6FBF4A") if collected else Color("#3C342C")
	var ink := Color("#14110F")
	draw_rect(Rect2(2, 5, 36, 27), tint)
	draw_rect(Rect2(2, 5, 36, 27), ink, false, 2.0)
	draw_line(Vector2(2, 5), Vector2(38, 32), ink, 2.0)
	draw_line(Vector2(38, 5), Vector2(2, 32), ink, 2.0)
	draw_line(Vector2(20, 5), Vector2(20, 32), ink, 2.0)
	draw_line(Vector2(2, 5), Vector2(12, 1), ink, 2.0)
	draw_line(Vector2(38, 5), Vector2(28, 1), ink, 2.0)
