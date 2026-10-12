extends Node2D
## World-space textured Sprite2D tiles. No procedural _draw geometry.
const ASPHALT = preload("res://art/asphalt.png")
const SIDEWALK = preload("res://art/sidewalk.png")
const LANE = preload("res://art/lane.png")
func _ready() -> void:
    for x in range(-5, 6):
        for y in range(-7, 8):
            var tile := Sprite2D.new()
            tile.texture = ASPHALT
            tile.position = Vector2(float(x) * 256.0, float(y) * 256.0)
            add_child(tile)
    for side in [-1.0, 1.0]:
        for i in range(-7, 8):
            var walk := Sprite2D.new()
            walk.texture = SIDEWALK
            walk.position = Vector2(side * 350.0, float(i) * 256.0)
            add_child(walk)
    for i in range(-17, 18):
        var stripe := Sprite2D.new()
        stripe.texture = LANE
        stripe.position = Vector2(0, float(i) * 100.0)
        add_child(stripe)
