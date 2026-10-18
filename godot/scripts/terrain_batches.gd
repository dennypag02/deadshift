extends Node2D
# Ground layer for the Outskirts.
#
# 1. One baked base image (tools/bake_ground.py) for the whole map, drawn at 2x.
#    Replaces the per-tile MultiMesh batches, which rendered white in release
#    exports (see tuned_game.gd) and showed hard 128-px tile seams.
# 2. Soft-edged overlays on every hazard tile (o = oil, x = cracked, : = gravel),
#    read from the live generated map so what you see always matches what slows you.
# 3. Subtle collision pads for props whose art is smaller than their footprint,
#    with explosive pumps/barrels keeping a warm warning outline.
var game: Node2D
var batches: Array[MultiMeshInstance2D] = []  # kept empty; tuned_game.gd still iterates it

const BASE := preload("res://art/ground/outskirts_base.png")
const HAZARD_TEXTURES := {
	"o": [preload("res://art/ground/hazard_oil_0.png"), preload("res://art/ground/hazard_oil_1.png"), preload("res://art/ground/hazard_oil_2.png")],
	"x": [preload("res://art/ground/hazard_crack_0.png"), preload("res://art/ground/hazard_crack_1.png"), preload("res://art/ground/hazard_crack_2.png")],
	":": [preload("res://art/ground/hazard_gravel_0.png"), preload("res://art/ground/hazard_gravel_1.png"), preload("res://art/ground/hazard_gravel_2.png")],
}
const HAZARD_DRAW_ORDER := [":", "x", "o"]  # oil on top: it's the strongest hazard
const OVERLAY_SIZE := 160.0

const PAD_FILL := Color(0.10, 0.105, 0.115, 0.55)
const PAD_EDGE := Color(0.45, 0.46, 0.48, 0.30)
const EXPLOSIVE_FILL := Color(0.38, 0.12, 0.05, 0.30)
const EXPLOSIVE_EDGE := Color(0.90, 0.49, 0.13, 0.65)

func _ready() -> void:
	z_index = -2
	rebuild()

func rebuild() -> void:
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(BASE, Rect2(Vector2.ZERO, game.MAP_SIZE as Vector2), false)
	for kind in HAZARD_DRAW_ORDER:
		var variants: Array = HAZARD_TEXTURES[kind]
		for y in range(game.MAP_H):
			for x in range(game.MAP_W):
				if game._tile_char(x, y) != kind:
					continue
				var h := absi(x * 73856093 ^ y * 19349663)
				var center: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * float(game.TILE)
				draw_set_transform(center, float(h % 4) * PI * 0.5, Vector2.ONE)
				draw_texture_rect(variants[(h / 4) % variants.size()], Rect2(Vector2.ONE * -OVERLAY_SIZE * 0.5, Vector2.ONE * OVERLAY_SIZE), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for y in range(game.MAP_H):
		for x in range(game.MAP_W):
			var ch: String = game._tile_char(x, y)
			var rect := Rect2(Vector2(x, y) * float(game.TILE), Vector2.ONE * float(game.TILE))
			match ch:
				"T":
					draw_rect(rect, PAD_FILL)
					_outer_edges(x, y, ch, rect, PAD_EDGE, 2.0)
				"P", "b":
					draw_rect(rect, EXPLOSIVE_FILL)
					_outer_edges(x, y, ch, rect, EXPLOSIVE_EDGE, 3.0)

# Outline only the outside of a multi-tile footprint (no grid lines inside it).
func _outer_edges(x: int, y: int, ch: String, rect: Rect2, color: Color, width: float) -> void:
	var inset := width * 0.5
	var a := rect.position + Vector2(inset, inset)
	var b := rect.end - Vector2(inset, inset)
	if game._tile_char(x, y - 1) != ch: draw_line(Vector2(a.x, a.y), Vector2(b.x, a.y), color, width)
	if game._tile_char(x, y + 1) != ch: draw_line(Vector2(a.x, b.y), Vector2(b.x, b.y), color, width)
	if game._tile_char(x - 1, y) != ch: draw_line(Vector2(a.x, a.y), Vector2(a.x, b.y), color, width)
	if game._tile_char(x + 1, y) != ch: draw_line(Vector2(b.x, a.y), Vector2(b.x, b.y), color, width)
