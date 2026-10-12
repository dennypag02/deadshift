extends Sprite2D
@onready var area: Area2D = $Area2D

func _ready() -> void:
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)

func _on_enter(body: Node2D) -> void:
    if body.is_in_group("player"):
        create_tween().tween_property(self, "modulate:a", 0.3, 0.25)

func _on_exit(body: Node2D) -> void:
    if body.is_in_group("player"):
        create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
