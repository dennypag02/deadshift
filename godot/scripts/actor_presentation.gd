extends Node2D
## Pooled, foot-anchored actors. Ratios refer to visible texture height, never collision diameter.
const SURVIVOR_HEIGHT := 96.0
const HEIGHT_RATIOS := {"shambler": 0.65, "runner": 0.60, "spitter": 0.65,
	"elite": 0.845, "bloater": 0.975, "brute": 0.975, "mech_miniboss": 0.975}
const ART := {
	"shambler": preload("res://art/characters/zombie_shambler.png"),
	"runner": preload("res://art/characters/zombie_runner.png"),
	"spitter": preload("res://art/characters/zombie_spitter.png"),
	"elite": preload("res://art/characters/zombie_elite.png"),
	"bloater": preload("res://art/characters/zombie_bloater.png"),
	"brute": preload("res://art/characters/zombie_brute.png"),
	"mech_miniboss": preload("res://art/characters/mech_miniboss.png")}
const OUTLINE := preload("res://shaders/actor_outline.gdshader")
## Three fixed-capacity MultiMeshes replace all per-zombie bodies/shadows.
var game: Node2D
var active: Dictionary = {}
var allocations := 0
var visible_actors := 0
var behind: MultiMeshInstance2D
var front: MultiMeshInstance2D
var shadows: MultiMeshInstance2D
var survivor: Sprite2D
var atlas_data: Dictionary = {}
var shared_material: ShaderMaterial
var sorted_enemies: Array[Dictionary] = []

static func height_for(kind: String, elite: bool = false) -> float:
	return SURVIVOR_HEIGHT * float(HEIGHT_RATIOS.get("elite" if elite else kind, 0.65))

static func radius_for(kind: String, elite: bool = false) -> float:
	return height_for(kind, elite) * 0.28

func _batch(texture: Texture2D, layer: int, atlas: bool) -> MultiMeshInstance2D:
	var node := MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = atlas
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = 251
	mm.visible_instance_count = 0
	node.multimesh = mm
	node.texture = texture
	node.z_index = layer
	if atlas:
		node.material = shared_material
	add_child(node)
	allocations += 1
	return node

func _ready() -> void:
	z_index = 2
	shared_material = ShaderMaterial.new()
	shared_material.shader = preload("res://shaders/actor_batch.gdshader")
	atlas_data = JSON.parse_string(FileAccess.get_file_as_string("res://art/runtime/actors_atlas.json"))
	var image := Image.create(64,32,false,Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(64):
			var d := Vector2((x-31.5)/31.5,(y-15.5)/15.5).length()
			image.set_pixel(x,y,Color(.015,.020,.015,pow(maxf(0,1-d),1.4)*.65))
	shadows = _batch(ImageTexture.create_from_image(image), 0, false)
	behind = _batch(preload("res://art/runtime/actors_atlas.png"), 0, true)
	front = _batch(preload("res://art/runtime/actors_atlas.png"), 0, true)
	survivor = Sprite2D.new()
	var source: Texture2D = preload("res://art/survivor_wasteland.svg")
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = source.get_image().get_used_rect()
	survivor.texture = atlas
	survivor.scale = Vector2.ONE * SURVIVOR_HEIGHT / atlas.get_height()
	survivor.z_index = 0
	add_child(survivor)
	move_child(front,get_child_count()-1) # Keep weapon/effect global layers unchanged.
	allocations += 1

func _sort_y(a: Dictionary, b: Dictionary) -> bool:
	return float(a["pos"].y) < float(b["pos"].y)

func _process(_delta: float) -> void:
	if game == null or survivor == null:
		return
	active.clear()
	sorted_enemies.clear()
	var half: Vector2 = game._camera_half_extents() + Vector2(120,120)
	var view := Rect2(Vector2(game.camera.position)-half,half*2)
	for enemy in game.enemies:
		var kind := "elite" if bool(enemy.get("elite",false)) else str(enemy["kind"])
		if not ART.has(kind):
			continue # Never substitute elite art for deferred boss.
		active[int(enemy["uid"])] = true
		if view.has_point(enemy["pos"]):
			sorted_enemies.append(enemy)
	sorted_enemies.sort_custom(_sort_y)
	visible_actors = sorted_enemies.size()
	var nb := 0
	var nf := 0
	var ns := 0
	for enemy in sorted_enemies:
		var kind := "elite" if bool(enemy.get("elite",false)) else str(enemy["kind"])
		var info: Dictionary = atlas_data[kind]
		var height := height_for(kind)
		var pos: Vector2 = enemy["pos"]
		var size := Vector2(info.size[0],info.size[1])
		if game.player_pos.x < pos.x:
			size.x = -size.x
		var use_back: bool = pos.y <= game.player_pos.y
		var mesh: MultiMesh = behind.multimesh if use_back else front.multimesh
		var idx := nb if use_back else nf
		if idx >= 250: break
		mesh.set_instance_transform_2d(idx,Transform2D(0,size,0,pos+Vector2(0,-height*.07+3)))
		mesh.set_instance_custom_data(idx,Color(info.uv[0],info.uv[1],info.uv[2],info.uv[3]))
		mesh.set_instance_color(idx,Color(1.25,1.25,1.25) if float(enemy.get("visual_hit",0))>0 else Color.WHITE)
		if use_back: nb += 1
		else: nf += 1
		shadows.multimesh.set_instance_transform_2d(ns,Transform2D(0,Vector2(float(info.body_width)*.88,height*.24),0,pos+Vector2(0,height*.43)))
		shadows.multimesh.set_instance_color(ns,Color.WHITE)
		ns += 1
	survivor.position = game.player_pos + game.recoil_vector + Vector2(0,-SURVIVOR_HEIGHT*.07+3)
	survivor.modulate = Color.WHITE if game.player_hit_invulnerability<=0 else Color(1.15,.95,.9)
	shadows.multimesh.set_instance_transform_2d(ns,Transform2D(0,Vector2(76,23),0,game.player_pos+Vector2(0,SURVIVOR_HEIGHT*.43)))
	shadows.multimesh.set_instance_color(ns,Color.WHITE)
	behind.multimesh.visible_instance_count = nb
	front.multimesh.visible_instance_count = nf
	shadows.multimesh.visible_instance_count = ns+1
