extends Node2D
var game: Node2D
var batches: Array[MultiMeshInstance2D] = []
func _ready() -> void:
	z_index = -2
	rebuild()
func rebuild() -> void:
	for node in batches: node.queue_free()
	batches.clear()
	var cells := {}
	var textures := {",":game.TEX_SCRUB,"-":game.TEX_HIGHWAY,"=":game.TEX_FORECOURT,":":game.TEX_GRAVEL,"x":game.TEX_CRACKED,"o":game.TEX_OIL,".":game.TEX_ASPHALT}
	for y in range(game.MAP_H):
		for x in range(game.MAP_W):
			var ch: String = game._tile_char(x,y)
			if not textures.has(ch): ch="."
			if not cells.has(ch): cells[ch]=[]
			cells[ch].append(Vector2(x+.5,y+.5)*game.TILE)
	for ch in cells:
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_2D
		var quad:=QuadMesh.new()
		quad.size=Vector2.ONE*game.TILE
		mm.mesh=quad
		mm.instance_count=cells[ch].size()
		for i in range(cells[ch].size()): mm.set_instance_transform_2d(i,Transform2D(0,cells[ch][i]))
		var node:=MultiMeshInstance2D.new()
		node.multimesh=mm
		node.texture=textures[ch]
		node.z_index=-1
		add_child(node)
		batches.append(node)
	queue_redraw()
func _draw() -> void:
	# Static collision debug silhouettes below approved props, not rebuilt each frame.
	var colors: Dictionary={"B":Color("#555555"),"T":Color("#9a9a9a"),"P":Color("#c0392b"),"b":Color("#e67e22"),"J":Color("#bbbbbb"),"F":Color("#777777")}
	for y in range(game.MAP_H):
		for x in range(game.MAP_W):
			var ch: String=game._tile_char(x,y)
			if colors.has(ch):
				draw_rect(Rect2(Vector2(x,y)*game.TILE,Vector2.ONE*game.TILE),colors[ch])
