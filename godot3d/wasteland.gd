extends Node3D

var survivor: CharacterBody3D
var camera: Camera3D
var stick := Vector2.ZERO
var touching := false
var start_touch := Vector2.ZERO
var camera_yaw := 0.0
const SPEED := 6.0

var brick_materials: Array[StandardMaterial3D] = []
var asphalt_material: StandardMaterial3D

func _make_texture(base: Color, brick: bool) -> ImageTexture:
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    for y in range(128):
        for x in range(128):
            var grain: float = float((x * 37 + y * 73 + (x * y) % 31) % 29) / 470.0 - 0.030
            var shade: float = 1.0 + grain
            if brick:
                var row_id: int = int(y / 16)
                var bx: int = (x + (row_id % 2) * 16) % 32
                var by: int = y % 16
                if bx < 2 or by < 2:
                    shade *= 0.57
                elif (x * 11 + y * 7) % 53 < 3:
                    shade *= 0.78
            else:
                if (x * 17 + y * 23) % 401 < 2:
                    shade *= 0.53
            img.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade))
    return ImageTexture.create_from_image(img)

func _textured_material(base: Color, brick: bool) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = _make_texture(base, brick)
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = Vector3(0.55, 0.55, 0.55) if brick else Vector3(0.025, 0.025, 0.025)
    mat.roughness = 0.97
    return mat


func _ready() -> void:
    for tint in [Color(0.54, 0.46, 0.40), Color(0.57, 0.49, 0.42), Color(0.46, 0.49, 0.47), Color(0.51, 0.43, 0.40)]:
        brick_materials.append(_textured_material(tint, true))
    asphalt_material = _textured_material(Color(0.22, 0.23, 0.23), false)
    _build_world()
    _build_player()
    _build_camera()
    _build_hud()

func _box(pos: Vector3, size: Vector3, color: Color, collision := true) -> Node3D:
    var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
    add_child(body)
    body.position = pos
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.95
    mesh.material_override = material
    body.add_child(mesh)
    if collision:
        var collider := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        collider.shape = box
        body.add_child(collider)
    return body

func _wheel(pos: Vector3) -> void:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.42
    cylinder.bottom_radius = 0.42
    cylinder.height = 0.18
    cylinder.radial_segments = 12
    mesh.mesh = cylinder
    mesh.position = pos
    mesh.rotation_degrees.z = 90
    var tire := StandardMaterial3D.new()
    tire.albedo_color = Color(0.075, 0.075, 0.073)
    mesh.material_override = tire
    add_child(mesh)
    var hub := MeshInstance3D.new()
    var hub_mesh := CylinderMesh.new()
    hub_mesh.top_radius = 0.22
    hub_mesh.bottom_radius = 0.22
    hub_mesh.height = 0.20
    hub_mesh.radial_segments = 10
    hub.mesh = hub_mesh
    hub.position = pos
    hub.rotation_degrees.z = 90
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.35, 0.36, 0.34)
    hub.material_override = steel
    add_child(hub)

func _car(x: float, z: float, color: Color, variant: int) -> void:
    # Recognizable vehicle silhouette: chassis, hood, sloped cabin, windows and wheels.
    _box(Vector3(x, 0.66, z), Vector3(2.05, 0.62, 4.05), color)
    _box(Vector3(x, 1.11, z - 0.78), Vector3(1.95, 0.24, 1.40), color, false)
    _box(Vector3(x, 1.42, z + 0.30), Vector3(1.72, 0.54, 1.78), color, false)
    _box(Vector3(x, 1.72, z + 0.30), Vector3(1.62, 0.08, 1.68), Color(0.21, 0.22, 0.21), false)
    _box(Vector3(x, 1.43, z - 0.64), Vector3(1.47, 0.43, 0.065), Color(0.11, 0.17, 0.19), false)
    _box(Vector3(x, 1.43, z + 1.24), Vector3(1.47, 0.43, 0.065), Color(0.10, 0.15, 0.16), false)
    for side in [-1.0, 1.0]:
        _box(Vector3(x + side * 0.88, 1.43, z + 0.32), Vector3(0.035, 0.38, 1.34), Color(0.10, 0.16, 0.17), false)
        _box(Vector3(x + side * 0.99, 0.62, z), Vector3(0.09, 0.12, 3.55), Color(0.20, 0.19, 0.17), false)
        _wheel(Vector3(x + side * 1.07, 0.43, z - 1.25))
        _wheel(Vector3(x + side * 1.07, 0.43, z + 1.25))
    _box(Vector3(x, 0.64, z - 2.06), Vector3(1.85, 0.17, 0.13), Color(0.23, 0.23, 0.22), false)
    _box(Vector3(x, 0.64, z + 2.06), Vector3(1.85, 0.17, 0.13), Color(0.23, 0.23, 0.22), false)
    if variant % 3 == 0:
        _box(Vector3(x, 1.80, z + 0.35), Vector3(1.5, 0.08, 1.3), Color(0.24, 0.22, 0.19), false)

func _survivor_piece(parent: Node3D, pos: Vector3, size: Vector3, tint: Color) -> void:
    var part := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    part.mesh = box
    part.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.92
    part.material_override = mat
    parent.add_child(part)

func _urban_decay() -> void:
    # Sparse broken pavement, cracks, vegetation, barricades and boarded openings.
    for i in range(62):
        var z: float = -47.0 + float(i) * 1.55
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var x: float = side * (3.2 + float(i % 5) * 0.53)
        _box(Vector3(x, 0.019, z), Vector3(0.025, 0.012, 0.55 + float(i % 3) * 0.21), Color(0.085, 0.09, 0.09), false)
        if i % 3 == 0:
            _box(Vector3(x + 0.23, 0.022, z + 0.12), Vector3(0.5, 0.012, 0.022), Color(0.08, 0.09, 0.08), false)
        if i % 4 == 0:
            var curb: float = side * 8.7
            _box(Vector3(curb, 0.18, z), Vector3(0.24, 0.36, 0.18), Color(0.22, 0.30, 0.18), false)
            _box(Vector3(curb + 0.1, 0.27, z + 0.10), Vector3(0.11, 0.52, 0.11), Color(0.28, 0.37, 0.21), false)
        if i % 7 == 0:
            var wall: float = side * 9.22
            _box(Vector3(wall, 1.75, z), Vector3(0.17, 0.17, 2.15), Color(0.31, 0.23, 0.17), false)
            _box(Vector3(wall, 2.08, z), Vector3(0.17, 0.15, 2.15), Color(0.32, 0.25, 0.18), false)
    for i in range(9):
        var z: float = -42.0 + float(i) * 10.5
        var side: float = -1.0 if i % 2 == 0 else 1.0
        _box(Vector3(side * 9.0, 0.58, z + 2.3), Vector3(0.85, 1.16, 0.42), Color(0.34, 0.29, 0.24), false)
        _box(Vector3(side * 9.0, 1.2, z + 2.3), Vector3(0.93, 0.14, 0.48), Color(0.20, 0.19, 0.17), false)

func _wedge(pos: Vector3, width: float, height: float, depth: float, tint: Color) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var vertices := [
        Vector3(-width * 0.5, 0, -depth * 0.5),
        Vector3(width * 0.5, 0, -depth * 0.5),
        Vector3(width * 0.5, 0, depth * 0.5),
        Vector3(-width * 0.5, 0, depth * 0.5),
        Vector3(-width * 0.5, height, depth * 0.5),
        Vector3(width * 0.5, height, depth * 0.5)
    ]
    var faces := [0, 1, 5, 0, 5, 4, 0, 4, 3, 1, 2, 5, 3, 4, 5, 3, 5, 2, 0, 3, 2, 0, 2, 1]
    for idx in faces:
        surface.add_vertex(vertices[idx])
    surface.generate_normals()
    var mesh := MeshInstance3D.new()
    mesh.mesh = surface.commit()
    mesh.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.92
    mesh.material_override = mat
    add_child(mesh)

func _environment_story() -> void:
    # Localized wreckage, damaged shopfronts and roof silhouettes rather than uniform clutter.
    for i in range(9):
        var z: float = -39.0 + float(i) * 10.1
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var wall_x: float = side * 9.28
        _box(Vector3(wall_x, 3.52, z), Vector3(0.22, 0.15, 3.0), Color(0.20, 0.18, 0.16), false)
        for plank in range(3):
            _box(Vector3(wall_x + side * 0.13, 1.2 + float(plank) * 0.52, z + 0.2), Vector3(0.12, 0.13, 2.35), Color(0.34, 0.25, 0.17), false)
        _box(Vector3(wall_x + side * 0.25, 0.16, z - 2.4), Vector3(0.62, 0.27, 0.72), Color(0.25, 0.24, 0.21), false)
        _wedge(Vector3(wall_x + side * 0.3, 0.04, z - 2.1), 0.9, 0.48, 0.7, Color(0.37, 0.36, 0.31))
    for i in range(6):
        var z: float = -35.0 + float(i) * 15.2
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var x: float = side * 6.25
        _wedge(Vector3(x, 0.02, z), 1.1, 0.45, 1.5, Color(0.27, 0.27, 0.26))
        _box(Vector3(x + 0.4, 0.10, z + 0.8), Vector3(0.65, 0.19, 0.8), Color(0.32, 0.31, 0.28), false)
        _box(Vector3(x - 0.45, 0.08, z - 0.7), Vector3(0.4, 0.13, 0.7), Color(0.37, 0.36, 0.31), false)

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.33, 0.37, 0.40)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.68, 0.65, 0.59)
    e.ambient_light_energy = 0.85
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_color = Color(1.0, 0.79, 0.60)
    sun.light_energy = 1.1
    add_child(sun)
    _box(Vector3(0, -0.35, 0), Vector3(110, 0.5, 110), Color(0.42, 0.43, 0.37))
    var street := _box(Vector3(0, -0.07, 0), Vector3(13, 0.08, 105), Color(0.20, 0.21, 0.22), false)
    var street_mesh := street.get_child(0) as MeshInstance3D
    street_mesh.material_override = asphalt_material
    for side in [-1, 1]:
        _box(Vector3(side * 7.7, 0, 0), Vector3(2.2, 0.18, 105), Color(0.45, 0.43, 0.40))
        for i in range(9):
            var z := -42.0 + i * 10.5
            var h := 7.0 + float((i * 7 + (side + 1) * 3) % 11)
            var facade_colors := [Color(0.43, 0.40, 0.36), Color(0.51, 0.43, 0.36), Color(0.36, 0.43, 0.43), Color(0.47, 0.39, 0.34), Color(0.37, 0.39, 0.42)]
            var facade: Color = facade_colors[(i + (side + 1) * 2) % facade_colors.size()]
            var building := _box(Vector3(side * 14.5, h / 2.0, z), Vector3(10, h, 8), facade)
            var building_mesh := building.get_child(0) as MeshInstance3D
            building_mesh.material_override = brick_materials[(i + (side + 1)) % brick_materials.size()]
            for floor_idx in range(int(h / 3.0)):
                var front: float = float(side) * 9.43
                _box(Vector3(front, 2.1 + floor_idx * 2.9, z - 1.9), Vector3(0.08, 1.25, 1.1), Color(0.16, 0.25, 0.30), false)
                _box(Vector3(front, 2.1 + floor_idx * 2.9, z + 1.9), Vector3(0.08, 1.25, 1.1), Color(0.065, 0.085, 0.09), false)
                for win_z in [z - 1.9, z + 1.9]:
                    _box(Vector3(front, 2.80 + floor_idx * 2.9, win_z), Vector3(0.16, 0.12, 1.42), Color(0.29, 0.27, 0.25), false)
                    _box(Vector3(front, 1.43 + floor_idx * 2.9, win_z), Vector3(0.16, 0.12, 1.42), Color(0.30, 0.28, 0.25), false)
                    _box(Vector3(front, 2.1 + floor_idx * 2.9, win_z), Vector3(0.16, 1.38, 0.09), Color(0.31, 0.29, 0.26), false)
            _box(Vector3(side * 14.5, h + 0.13, z), Vector3(10.35, 0.25, 8.3), Color(0.26, 0.25, 0.24), false)
            _box(Vector3(side * 9.35, 1.35, z), Vector3(0.12, 2.0, 2.7), Color(0.24, 0.28, 0.30), false)
            _box(Vector3(side * 9.29, 3.0, z), Vector3(0.16, 0.16, 3.4), Color(0.80, 0.72, 0.54), false)
    for i in range(30):
        var z: float = -45.0 + float(i) * 3.0
        var side: float = -1.0 if i % 2 == 0 else 1.0
        _box(Vector3(side * 6.6, 0.09, z), Vector3(0.35, 0.18, 0.65), Color(0.35, 0.33, 0.30), false)
        if i % 3 == 0:
            _box(Vector3(side * 8.4, 0.42, z), Vector3(0.8, 0.8, 0.85), Color(0.26, 0.29, 0.27), false)
            _box(Vector3(side * 8.4, 0.85, z), Vector3(0.9, 0.07, 0.95), Color(0.18, 0.20, 0.18), false)
        if i % 4 == 0:
            _box(Vector3(side * 5.8, 0.045, z + 0.8), Vector3(0.65, 0.025, 1.3), Color(0.12, 0.13, 0.13), false)
    for i in range(14):
        var z: float = -43.0 + float(i) * 6.2
        var side: float = -1.0 if i % 2 == 0 else 1.0
        _box(Vector3(side * 9.28, 1.2, z), Vector3(0.16, 2.1, 1.7), Color(0.19, 0.24, 0.25), false)
        _box(Vector3(side * 9.27, 2.3, z), Vector3(0.3, 0.16, 2.2), Color(0.36, 0.29, 0.22), false)
    for i in range(16):
        var z := -43.0 + i * 5.6
        _box(Vector3(0, 0.015, z), Vector3(0.22, 0.025, 2.6), Color(0.65, 0.56, 0.36), false)
    for i in range(11):
        var z := -40.0 + i * 8.1
        var side := -1 if i % 2 == 0 else 1
        _car(float(side) * 4.2, z, Color(0.34 + 0.045 * float(i % 3), 0.37, 0.34), i)
    for i in range(12):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var z: float = -41.0 + i * 7.4
        _box(Vector3(side * 7.9, 2.5, z), Vector3(0.20, 5.0, 0.20), Color(0.35, 0.39, 0.40), false)
        _box(Vector3(side * 7.9, 5.0, z), Vector3(0.25, 0.18, 1.5), Color(0.89, 0.84, 0.65), false)
    _urban_decay()
    _environment_story()
    for i in range(24):
        var side := -1 if i % 2 == 0 else 1
        _box(Vector3(side * (5.6 + (i % 3) * 0.5), 0.12, -44 + i * 3.8), Vector3(0.65, 0.28, 0.8), Color(0.50, 0.47, 0.41))

func _build_player() -> void:
    survivor = CharacterBody3D.new()
    add_child(survivor)
    survivor.position = Vector3(0, 1.1, 16)
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.4
    capsule.height = 2.0
    collider.shape = capsule
    survivor.add_child(collider)
    # Imported mesh asset; collision remains independent of visuals.
    var imported: Mesh = load("res://assets/survivor.obj")
    var model := MeshInstance3D.new()
    model.mesh = imported
    survivor.add_child(model)

func _build_camera() -> void:
    camera = Camera3D.new()
    add_child(camera)
    camera.current = true
    camera.fov = 68
    _update_camera(1.0)

func _update_camera(weight: float) -> void:
    var target := survivor.position + Vector3(0, 2.2, 0)
    var offset := Vector3(sin(camera_yaw) * 5.9, 3.25, cos(camera_yaw) * 5.9)
    camera.global_position = camera.global_position.lerp(target + offset, weight)
    camera.look_at(target + Vector3(0, 0, -3), Vector3.UP)

func _build_hud() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var title := Label.new()
    title.text = "DEADSHIFT  |  URBAN SURVIVAL V6.2"
    title.position = Vector2(18, 16)
    title.add_theme_font_size_override("font_size", 23)
    ui.add_child(title)
    var help := Label.new()
    help.text = "LEFT: drag to move     RIGHT: drag to turn"
    help.position = Vector2(18, 52)
    help.add_theme_font_size_override("font_size", 17)
    ui.add_child(help)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.5:
            touching = true
            start_touch = event.position
        elif not event.pressed:
            touching = false
            stick = Vector2.ZERO
    if event is InputEventScreenDrag:
        if event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and touching:
            stick = ((event.position - start_touch) / 100.0).limit_length(1.0)
        elif event.position.x >= get_viewport().get_visible_rect().size.x * 0.5:
            camera_yaw -= event.relative.x * 0.007

func _physics_process(delta: float) -> void:
    var move := stick
    move += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    move = move.limit_length(1.0)
    var direction := Vector3(move.x, 0, move.y).rotated(Vector3.UP, camera_yaw)
    survivor.velocity.x = direction.x * SPEED
    survivor.velocity.z = direction.z * SPEED
    survivor.velocity.y -= 20.0 * delta
    survivor.move_and_slide()
    if direction.length() > 0.05:
        survivor.rotation.y = lerp_angle(survivor.rotation.y, atan2(-direction.x, -direction.z), min(1.0, delta * 8))
    _update_camera(min(1.0, delta * 6))
