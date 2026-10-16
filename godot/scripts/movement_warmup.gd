extends Node
## Render real canvas pipelines in a small offscreen viewport before the run clock starts.
var game: Node2D
class WarmupGeometry:
	extends Node2D
	func _draw() -> void:
		draw_circle(Vector2(24,24),16,Color(0.2,0.4,0.2,0.3))
		draw_arc(Vector2(24,24),18,0,TAU,32,Color(1,0.6,0.2),3)
		draw_line(Vector2(4,4),Vector2(40,40),Color.WHITE,2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var view := SubViewport.new()
	var size_px: int = game.rules.performance.warmup_size
	view.size = Vector2i(size_px,size_px)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.transparent_bg = true
	add_child(view)
	view.add_child(WarmupGeometry.new())
	for original in [game.actors.behind,game.actors.shadows]:
		var item := MultiMeshInstance2D.new()
		item.texture = original.texture
		item.material = original.material
		var mm: MultiMesh = original.multimesh.duplicate()
		mm.visible_instance_count = 1
		mm.set_instance_transform_2d(0,Transform2D(0,Vector2(32,32),0,Vector2(32,32)))
		mm.set_instance_color(0,Color.WHITE)
		if mm.use_custom_data:
			var uv: Array = game.actors.atlas_data.shambler.uv
			mm.set_instance_custom_data(0,Color(uv[0],uv[1],uv[2],uv[3]))
		item.multimesh = mm
		view.add_child(item)
	var label := Label.new()
	label.text = "0123456789 DAMAGE LEVEL UP HOLD GRAB DESTROY"
	label.add_theme_font_override("font",game.phase_ui.barlow_font)
	view.add_child(label)
	# Preload/upload promoted card textures without changing any approved file.
	for texture in game.phase_ui.icon_textures.values():
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE*8.0/maxf(1.0,texture.get_width())
		sprite.position = Vector2(64,64)
		view.add_child(sprite)
