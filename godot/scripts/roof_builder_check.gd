extends SceneTree

const RoofBuilder = preload("res://scripts/roof_builder.gd")

func fail(message: String) -> void:
	push_error("ROOF_BUILDER_CHECK_FAIL " + message)
	quit(1)

func _initialize() -> void:
	var footprints: Dictionary = RoofBuilder.footprint_spec()
	var expected := {
		"diner": Rect2(Vector2(1,8)*128.0, Vector2(7,6)*128.0),
		"minimart": Rect2(Vector2(12,8)*128.0, Vector2(8,4)*128.0),
		"motel_north": Rect2(Vector2(23,7)*128.0, Vector2(8,3)*128.0),
		"motel_east": Rect2(Vector2(28,10)*128.0, Vector2(3,7)*128.0),
		"autoshop": Rect2(Vector2(1,20)*128.0, Vector2(7,6)*128.0),
		"canopy": Rect2(Vector2(11,14)*128.0, Vector2(10,8)*128.0),
	}
	if footprints != expected:
		fail("footprints changed")
	var layouts: Dictionary = RoofBuilder.prop_layouts()
	for building in layouts:
		var rect: Rect2 = footprints[building]
		var tiles := rect.size / 128.0
		for item in layouts[building]:
			var local: Vector2 = item[1]
			if local.x < 1.0 or local.y < 1.0 or local.x > tiles.x - 1.0 or local.y > tiles.y - 1.0:
				fail("prop margin violation " + str(building) + " " + str(item))
	if RoofBuilder.PARAPET_PX < 10.0 or RoofBuilder.PARAPET_PX > 14.0:
		fail("parapet width outside 10-14 px")
	if not is_equal_approx(RoofBuilder.CANOPY_UNDER_ALPHA, 0.25):
		fail("canopy alpha must be 25 percent")
	if RoofBuilder.texture_assignment()["autoshop"] != "tex_roof_corrugated":
		fail("autoshop texture assignment")
	if RoofBuilder.texture_assignment()["canopy"] != "tex_roof_canopy":
		fail("canopy texture assignment")
	print("ROOF_BUILDER_CHECK_PASS")
	quit()
