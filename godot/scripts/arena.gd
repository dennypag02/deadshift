extends Node2D
## Layered, Y-sorted Deadshift 2D arena. Collision and visual draw order are independent.

const ZOMBIE_SCENE = preload("res://scenes/zombie.tscn")
const CAR_SCENE = preload("res://scenes/car.tscn")
const PLAYER_SPEED := 230.0
const ZOMBIE_SPEED := 65.0
@onready var player: CharacterBody2D = $World/Player
@onready var zombies: Node2D = $World/Zombies
@onready var props: Node2D = $World/Props
@onready var buildings: Node2D = $World/Buildings
@onready var decals: Node2D = $Decals
@onready var tint: CanvasModulate = $Atmosphere/NightTint
@onready var status: Label = $HUD/Status
var rng := RandomNumberGenerator.new()
var drag_origin := Vector2.ZERO
var drag_position := Vector2.ZERO
var dragging := false
var wave := 1
var hp := 100
var kills := 0
var elapsed := 0.0
var spawn_timer := 0.0
var fire_timer := 0.0

func _ready() -> void:
    rng.seed = 20261010
    player.add_to_group("player")
    _populate_arena()
    _refresh_hud()

func _populate_arena() -> void:
    for i in range(14):
        var road_z := -1150.0 + float(i) * 185.0
        for side in [-1, 1]:
            var car := CAR_SCENE.instantiate()
            car.position = Vector2(float(side) * 250.0, road_z + float((i * 43) % 100))
            props.add_child(car)
    for i in range(24):
        var b := StaticBody2D.new()
        b.position = Vector2((-1.0 if i % 2 == 0 else 1.0) * 455.0, -1200.0 + float(i) * 110.0)
        b.collision_layer = 1
        b.collision_mask = 0
        var collision := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Vector2(185, 55)
        collision.shape = rect
        b.add_child(collision)
        var facade := Polygon2D.new()
        facade.polygon = PackedVector2Array([Vector2(-120,-250),Vector2(120,-250),Vector2(120,0),Vector2(-120,0)])
        facade.color = Color(0.35 + float(i % 3) * 0.07, 0.31, 0.28)
        b.add_child(facade)
        buildings.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            drag_origin = event.position
            drag_position = event.position
            dragging = true
        else:
            dragging = false
    elif event is InputEventScreenDrag:
        drag_position = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        dragging = event.pressed
        drag_origin = event.position
        drag_position = event.position
    elif event is InputEventMouseMotion and dragging:
        drag_position = event.position

func _physics_process(delta: float) -> void:
    elapsed += delta
    wave = 1 + int(elapsed / 30.0)
    var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if dragging:
        movement += (drag_position - drag_origin) / 85.0
    player.velocity = movement.limit_length(1.0) * PLAYER_SPEED
    player.move_and_slide()
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        spawn_timer = maxf(0.35, 1.6 - float(wave) * 0.10)
        var enemy := ZOMBIE_SCENE.instantiate()
        enemy.position = player.position + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * 530.0
        zombies.add_child(enemy)
    fire_timer -= delta
    if fire_timer <= 0.0 and zombies.get_child_count() > 0:
        var closest: Node2D = null
        var best := INF
        for child in zombies.get_children():
            var distance := player.position.distance_squared_to(child.position)
            if distance < best:
                best = distance
                closest = child
        if closest != null and best < 650.0 * 650.0:
            closest.queue_free()
            kills += 1
            fire_timer = 0.35
    for child in zombies.get_children():
        if child.is_queued_for_deletion():
            continue
        var direction: Vector2 = player.position - child.position
        child.position += direction.normalized() * ZOMBIE_SPEED * delta
        if direction.length() < 30.0:
            child.queue_free()
            hp = maxi(0, hp - 4)
    var progress := clampf(elapsed / 210.0, 0.0, 1.0)
    tint.color = Color(0.86, 0.77, 0.68).lerp(Color(0.31, 0.39, 0.57), progress)
    _refresh_hud()

func _refresh_hud() -> void:
    status.text = "DEADSHIFT 2D  |  WAVE %d  |  HP %d  |  KILLS %d" % [wave, hp, kills]
