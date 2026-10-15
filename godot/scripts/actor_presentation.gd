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
var game: Node2D
var active: Dictionary = {}
var spare: Array[Node2D] = []
var materials: Dictionary = {}
var shadow_texture: ImageTexture
var survivor: Node2D
var allocations := 0
var visible_actors := 0

static func height_for(kind: String, elite: bool = false) -> float:
	return SURVIVOR_HEIGHT * float(HEIGHT_RATIOS.get("elite" if elite else kind, 0.65))

static func radius_for(kind: String, elite: bool = false) -> float:
	# Ground footprint, shared by obstacle, bullet and contact collision tests.
	return height_for(kind, elite) * 0.28

func _ready() -> void:
	z_index = 2
	y_sort_enabled = true
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(64):
			var d := Vector2((x - 31.5) / 31.5, (y - 15.5) / 15.5).length()
			image.set_pixel(x, y, Color(0.015, 0.020, 0.015, pow(maxf(0.0, 1.0 - d), 1.4) * 0.65))
	shadow_texture = ImageTexture.create_from_image(image)
	for kind in ART:
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE
		mat.set_shader_parameter("outline_texels", 1.5 * ART[kind].get_height() / height_for(kind))
		materials[kind] = mat
	survivor = _make_actor()
	var body := survivor.get_node("Body") as Sprite2D
	var source: Texture2D = preload("res://art/survivor_wasteland.svg")
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = source.get_image().get_used_rect()
	body.texture = atlas
	body.material = null
	_fit(survivor, SURVIVOR_HEIGHT)

func _make_actor() -> Node2D:
	var anchor := Node2D.new()
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = shadow_texture
	anchor.add_child(shadow)
	var body := Sprite2D.new()
	body.name = "Body"
	anchor.add_child(body)
	add_child(anchor)
	allocations += 1
	return anchor

func _fit(anchor: Node2D, height: float) -> void:
	var body := anchor.get_node("Body") as Sprite2D
	var factor := height / maxf(1.0, body.texture.get_height())
	body.scale = Vector2.ONE * factor
	body.position = Vector2(0, -height * 0.5 + 3.0)
	var width := body.texture.get_width() * factor
	var shadow := anchor.get_node("Shadow") as Sprite2D
	shadow.scale = Vector2(width * 0.88 / 64.0, height * 0.24 / 32.0)

func _process(_delta: float) -> void:
	if game == null or survivor == null:
		return
	var live: Dictionary = {}
	visible_actors = 0
	var half: Vector2 = game._camera_half_extents() + Vector2(120, 120)
	var view := Rect2(Vector2(game.camera.position) - half, half * 2.0)
	for enemy in game.enemies:
		var kind := str(enemy["kind"])
		if bool(enemy.get("elite", false)):
			kind = "elite"
		if not ART.has(kind):
			continue # The deferred Trucker boss is deliberately not replaced with an elite.
		var uid := int(enemy["uid"])
		live[uid] = true
		var anchor: Node2D
		if not active.has(uid):
			anchor = spare.pop_back() if not spare.is_empty() else _make_actor()
			active[uid] = anchor
			anchor.set_meta("kind", "")
		else:
			anchor = active[uid]
		anchor.position = Vector2(enemy["pos"]) + Vector2(0, height_for(kind) * 0.43)
		anchor.visible = view.has_point(anchor.position)
		if not anchor.visible:
			continue
		visible_actors += 1
		var body := anchor.get_node("Body") as Sprite2D
		if str(anchor.get_meta("kind")) != kind:
			body.texture = ART[kind]
			body.material = materials[kind]
			_fit(anchor, height_for(kind))
			anchor.set_meta("kind", kind)
		body.flip_h = Vector2(game.player_pos).x < anchor.position.x
		body.modulate = Color.WHITE
		var flash := float(enemy.get("visual_hit", 0.0))
		if flash > 0.0:
			body.modulate = Color(1.25, 1.25, 1.25)
	for uid in active.keys():
		if not live.has(uid):
			var dead: Node2D = active[uid]
			dead.visible = false
			spare.append(dead)
			active.erase(uid)
	survivor.position = Vector2(game.player_pos) + Vector2(game.recoil_vector) + Vector2(0, SURVIVOR_HEIGHT * 0.43)
	var player_body := survivor.get_node("Body") as Sprite2D
	player_body.modulate = Color.WHITE if float(game.player_hit_invulnerability) <= 0.0 else Color(1.15, 0.95, 0.90)
