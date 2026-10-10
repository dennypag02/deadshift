extends Node3D

var survivor: CharacterBody3D
var camera: Camera3D
var stick := Vector2.ZERO
var touching := false
var start_touch := Vector2.ZERO
var camera_yaw := 0.0
const SPEED := 6.0

func _ready() -> void:
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
    _box(Vector3(0, -0.07, 0), Vector3(13, 0.08, 105), Color(0.20, 0.21, 0.22), false)
    for side in [-1, 1]:
        _box(Vector3(side * 7.7, 0, 0), Vector3(2.2, 0.18, 105), Color(0.45, 0.43, 0.40))
        for i in range(9):
            var z := -42.0 + i * 10.5
            var h := 7.0 + float((i * 7 + (side + 1) * 3) % 11)
            var facade_colors := [Color(0.43, 0.40, 0.36), Color(0.51, 0.43, 0.36), Color(0.36, 0.43, 0.43), Color(0.47, 0.39, 0.34), Color(0.37, 0.39, 0.42)]
            var facade: Color = facade_colors[(i + (side + 1) * 2) % facade_colors.size()]
            _box(Vector3(side * 14.5, h / 2.0, z), Vector3(10, h, 8), facade)
            for floor_idx in range(int(h / 3.0)):
                var front: float = float(side) * 9.43
                _box(Vector3(front, 2.1 + floor_idx * 2.9, z - 1.9), Vector3(0.08, 1.25, 1.1), Color(0.16, 0.25, 0.30), false)
                _box(Vector3(front, 2.1 + floor_idx * 2.9, z + 1.9), Vector3(0.08, 1.25, 1.1), Color(0.065, 0.085, 0.09), false)
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
        _box(Vector3(side * 4.2, 0.65, z), Vector3(2.2, 1.2, 3.6), Color(0.39 + 0.06 * (i % 3), 0.42, 0.40))
        _box(Vector3(side * 4.2, 1.42, z - 0.3), Vector3(1.7, 0.42, 1.8), Color(0.22, 0.33, 0.38), false)
    for i in range(12):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var z: float = -41.0 + i * 7.4
        _box(Vector3(side * 7.9, 2.5, z), Vector3(0.20, 5.0, 0.20), Color(0.35, 0.39, 0.40), false)
        _box(Vector3(side * 7.9, 5.0, z), Vector3(0.25, 0.18, 1.5), Color(0.89, 0.84, 0.65), false)
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
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.43
    mesh.height = 1.85
    body.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.17, 0.22, 0.17)
    body.material_override = mat
    survivor.add_child(body)

func _build_camera() -> void:
    camera = Camera3D.new()
    add_child(camera)
    camera.current = true
    camera.fov = 68
    _update_camera(1.0)

func _update_camera(weight: float) -> void:
    var target := survivor.position + Vector3(0, 2.2, 0)
    var offset := Vector3(sin(camera_yaw) * 8.5, 6.0, cos(camera_yaw) * 8.5)
    camera.global_position = camera.global_position.lerp(target + offset, weight)
    camera.look_at(target + Vector3(0, 0, -3), Vector3.UP)

func _build_hud() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var title := Label.new()
    title.text = "DEADSHIFT  |  WASTELAND 3D TEST"
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
