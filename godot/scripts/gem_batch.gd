extends MultiMeshInstance2D
var progression: Node2D
func _ready() -> void:
	z_index=1
	var image:=Image.create(16,20,false,Image.FORMAT_RGBA8)
	for y in range(20):
		for x in range(16):
			if absf(x-7.5)/7.0+absf(y-9.5)/9.0<=1.0: image.set_pixel(x,y,Color.WHITE)
	texture=ImageTexture.create_from_image(image)
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true
	var q:=QuadMesh.new()
	q.size=Vector2(16,20)
	multimesh.mesh=q
	multimesh.instance_count=200
	multimesh.visible_instance_count=0
func _process(_delta:float) -> void:
	var count:=mini(200,progression.gems.size())
	for i in range(count):
		var gem:Dictionary=progression.gems[i]
		var value:=int(gem.value)
		multimesh.set_instance_transform_2d(i,Transform2D(0,gem.pos))
		multimesh.set_instance_color(i,Color("#9c6cff") if value>=10 else (Color("#6FBF4A") if value>=2 else Color("#5bceff")))
	multimesh.visible_instance_count=count
