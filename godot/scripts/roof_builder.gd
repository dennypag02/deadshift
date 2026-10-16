@tool
extends Node2D
class_name DeadShiftRoofBuilder

const TILE := 128.0
const PARAPET_PX := 12.0
const CANOPY_UNDER_ALPHA := 0.25
const SHADOW_OFFSET := Vector2(12.0, 12.0)
const DARK_EDGE := Color("#35312d")
const LIGHT_EDGE := Color(1.0, 0.94, 0.80, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)

@export var enabled := false:
	set(value):
		enabled = value
		queue_redraw()

var player_position := Vector2(-99999.0, -99999.0)
var _textures: Dictionary = {}
var _props: Dictionary = {}

static func footprint_spec() -> Dictionary:
	return {
		"diner": Rect2(Vector2(1, 8) * TILE, Vector2(7, 6) * TILE),
		"minimart": Rect2(Vector2(12, 8) * TILE, Vector2(8, 4) * TILE),
		"motel_north": Rect2(Vector2(23, 7) * TILE, Vector2(8, 3) * TILE),
		"motel_east": Rect2(Vector2(28, 10) * TILE, Vector2(3, 7) * TILE),
		"autoshop": Rect2(Vector2(1, 20) * TILE, Vector2(7, 6) * TILE),
		"canopy": Rect2(Vector2(11, 14) * TILE, Vector2(10, 8) * TILE),
	}

static func texture_assignment() -> Dictionary:
	return {
		"diner": "tex_roof_tar",
		"minimart": "tex_roof_concrete",
		"motel_north": "tex_roof_tar",
		"motel_east": "tex_roof_tar",
		"autoshop": "tex_roof_corrugated",
		"canopy": "tex_roof_canopy",
	}

static func prop_layouts() -> Dictionary:
	# All positions are local tile coordinates within the matching roof.
	# Every center is at least one full tile from the footprint edge.
	return {
		"diner": [
			["roof_ac_unit", Vector2(2.0, 2.0)],
			["roof_vent_fan", Vector2(4.0, 2.0)],
			["roof_vent_fan", Vector2(5.0, 4.0)],
			["roof_sign_frame", Vector2(3.5, 4.0)],
			["roof_debris", Vector2(1.5, 4.5)],
		],
		"minimart": [
			["roof_ac_unit", Vector2(2.0, 2.0)],
			["roof_ac_unit", Vector2(5.5, 2.0)],
			["roof_skylight", Vector2(4.0, 2.0)],
			["roof_puddle", Vector2(6.5, 2.0)],
		],
		"motel_north": [
			["roof_vent_fan", Vector2(1.5, 1.5)],
			["roof_vent_fan", Vector2(3.5, 1.5)],
			["roof_vent_fan", Vector2(5.5, 1.5)],
			["roof_debris", Vector2(6.5, 1.5)],
		],
		"motel_east": [
			["roof_vent_fan", Vector2(1.5, 1.5)],
			["roof_water_heater", Vector2(1.5, 3.5)],
			["roof_vent_fan", Vector2(1.5, 5.5)],
		],
		"autoshop": [
			["roof_exhaust_pipes", Vector2(2.0, 2.0)],
			["roof_tires", Vector2(5.0, 2.0)],
			["roof_debris", Vector2(2.0, 4.0)],
			["roof_ac_unit", Vector2(5.0, 4.0)],
		],
		"canopy": [
			["roof_puddle", Vector2(2.0, 2.0)],
			["roof_debris", Vector2(7.5, 5.5)],
		],
	}

static func texture_paths() -> Dictionary:
	return {
		"tex_roof_tar": "res://art/roofs/tex_roof_tar.png",
		"tex_roof_corrugated": "res://art/roofs/tex_roof_corrugated.png",
		"tex_roof_canopy": "res://art/roofs/tex_roof_canopy.png",
		"tex_roof_concrete": "res://art/roofs/tex_roof_concrete.png",
	}

static func prop_paths() -> Dictionary:
	return {
		"roof_ac_unit": "res://art/roofs/props/roof_ac_unit.png",
		"roof_vent_fan": "res://art/roofs/props/roof_vent_fan.png",
		"roof_skylight": "res://art/roofs/props/roof_skylight.png",
		"roof_exhaust_pipes": "res://art/roofs/props/roof_exhaust_pipes.png",
		"roof_water_heater": "res://art/roofs/props/roof_water_heater.png",
		"roof_debris": "res://art/roofs/props/roof_debris.png",
		"roof_sign_frame": "res://art/roofs/props/roof_sign_frame.png",
		"roof_tires": "res://art/roofs/props/roof_tires.png",
		"roof_puddle": "res://art/roofs/props/roof_puddle.png",
	}

func _ready() -> void:
	if enabled:
		_reload_resources()

func set_player_position(value: Vector2) -> void:
	if player_position != value:
		player_position = value
		if enabled:
			queue_redraw()

func _reload_resources() -> void:
	_textures.clear()
	_props.clear()
	for key in texture_paths():
		var path: String = texture_paths()[key]
		if ResourceLoader.exists(path):
			_textures[key] = load(path)
	for key in prop_paths():
		var path: String = prop_paths()[key]
		if ResourceLoader.exists(path):
			_props[key] = load(path)
	queue_redraw()

func all_required_art_available() -> bool:
	for path in texture_paths().values():
		if not ResourceLoader.exists(path):
			return false
	for path in prop_paths().values():
		if not ResourceLoader.exists(path):
			return false
	return true

func _draw() -> void:
	if not enabled:
		return
	if _textures.is_empty() and _props.is_empty():
		_reload_resources()
	var footprints := footprint_spec()
	for building in ["diner", "minimart", "autoshop"]:
		_draw_roof(building, footprints[building], 1.0)
	# Motel is one L-shaped roof assembled from its two exact collision-aligned rectangles.
	_draw_roof("motel_north", footprints["motel_north"], 1.0)
	_draw_roof("motel_east", footprints["motel_east"], 1.0)
	_draw_motel_dividers(footprints["motel_north"], true)
	_draw_motel_dividers(footprints["motel_east"], false)
	var canopy_alpha := CANOPY_UNDER_ALPHA if footprints["canopy"].has_point(player_position) else 1.0
	_draw_roof("canopy", footprints["canopy"], canopy_alpha)

func _draw_roof(building: String, rect: Rect2, alpha: float) -> void:
	var texture_name: String = texture_assignment()[building]
	var texture: Texture2D = _textures.get(texture_name)
	if texture == null:
		return
	draw_rect(Rect2(rect.position + SHADOW_OFFSET, rect.size), Color(SHADOW, alpha))
	draw_texture_rect(texture, rect, true, Color(1.0, 1.0, 1.0, alpha))
	_draw_parapet(rect, alpha)
	for item in prop_layouts().get(building, []):
		_draw_prop(String(item[0]), rect.position + Vector2(item[1]) * TILE, alpha)

func _draw_parapet(rect: Rect2, alpha: float) -> void:
	draw_rect(rect, Color(DARK_EDGE, alpha), false, PARAPET_PX)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(LIGHT_EDGE, alpha), 2.0)
	draw_line(rect.position, rect.position + Vector2(0, rect.size.y), Color(LIGHT_EDGE, alpha), 2.0)

func _draw_prop(name: String, center: Vector2, alpha: float) -> void:
	var texture: Texture2D = _props.get(name)
	if texture == null:
		return
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))

func _draw_motel_dividers(rect: Rect2, horizontal_run: bool) -> void:
	var room_count := 8 if horizontal_run else 7
	var step := rect.size.x / float(room_count) if horizontal_run else rect.size.y / float(room_count)
	for index in range(1, room_count):
		if horizontal_run:
			var x := rect.position.x + step * float(index)
			draw_line(Vector2(x, rect.position.y + PARAPET_PX), Vector2(x, rect.end.y - PARAPET_PX), Color(0.12, 0.12, 0.12, 0.35), 2.0)
		else:
			var y := rect.position.y + step * float(index)
			draw_line(Vector2(rect.position.x + PARAPET_PX, y), Vector2(rect.end.x - PARAPET_PX, y), Color(0.12, 0.12, 0.12, 0.35), 2.0)
