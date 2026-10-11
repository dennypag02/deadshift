extends Node2D
## Static asphalt, sidewalks, lane markings and wear underneath Y-sorted actors.
func _draw() -> void:
    draw_rect(Rect2(-1400, -1600, 2800, 3200), Color("#343b3a"))
    draw_rect(Rect2(-315, -1600, 630, 3200), Color("#252a2b"))
    for side in [-1.0, 1.0]:
        var x: float = side * 340.0
        draw_rect(Rect2(x - 28.0, -1600.0, 56.0, 3200.0), Color("#676258"))
        draw_line(Vector2(x - side * 27.0, -1600.0), Vector2(x - side * 27.0, 1600.0), Color("#a39a84"), 5.0)
    for i in range(30):
        var y: float = -1520.0 + float(i) * 108.0
        draw_rect(Rect2(-5.0, y, 10.0, 51.0), Color("#b5a16e"))
    for i in range(110):
        var x: float = -295.0 + float((i * 89) % 580)
        var y: float = -1490.0 + float((i * 167) % 2950)
        draw_line(Vector2(x,y), Vector2(x + float(i % 3) * 11.0 + 8.0,y + 8.0), Color("#151b1c",0.55), 2.0)
