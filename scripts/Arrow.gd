extends Area2D

var direction: Vector2 = Vector2.UP
var damage: float = 8.0
var speed: float = 420.0
var lifetime: float = 1.8

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()
