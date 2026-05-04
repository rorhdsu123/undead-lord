extends Area2D

var direction: Vector2 = Vector2.UP
var damage: float = 30.0
var speed: float = 300.0
var lifetime: float = 3.0
var hit_enemies: Array = []  # 관통: 같은 적 중복 피해 방지

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemies") and body not in hit_enemies:
		hit_enemies.append(body)
		body.take_damage(damage)
