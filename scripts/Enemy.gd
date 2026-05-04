extends CharacterBody2D

# 적 타입 프리셋 (HP/속도/데미지/색/크기 배율)
const TYPE_PRESETS = {
	"normal": {"hp_mult": 1.0, "speed_mult": 1.0, "damage_mult": 1.0, "color": Color(0.9, 0.35, 0.25, 1), "scale": 1.0},
	"scout":  {"hp_mult": 0.5, "speed_mult": 1.8, "damage_mult": 0.6, "color": Color(0.95, 0.85, 0.2, 1), "scale": 0.8},
	"brute":  {"hp_mult": 3.0, "speed_mult": 0.5, "damage_mult": 1.5, "color": Color(0.55, 0.3, 0.75, 1), "scale": 1.45},
	"swarm":  {"hp_mult": 0.3, "speed_mult": 1.3, "damage_mult": 0.5, "color": Color(0.55, 0.4, 0.25, 1), "scale": 0.65},
}

var hp: float = 50.0
var max_hp: float = 50.0
var speed: float = 60.0
var base_speed: float = 60.0
var damage: int = 10
var attack_cooldown: float = 1.5
var attack_timer: float = 0.0
var slow_timer: float = 0.0
var enemy_type: String = "normal"

var game = null

@onready var hp_bar = $HPBar
@onready var sprite = $Sprite

var original_color: Color = Color(0.8, 0.6, 0.2, 1)

func _ready():
	add_to_group("enemies")
	base_speed = speed
	var preset: Dictionary = TYPE_PRESETS.get(enemy_type, TYPE_PRESETS["normal"])
	sprite.color = preset["color"]
	sprite.scale = Vector2.ONE * preset["scale"]
	original_color = sprite.color

const MINION_ENGAGE_RANGE: float = 100.0

func _physics_process(delta):
	if not game:
		return

	if slow_timer > 0:
		slow_timer -= delta
		speed = base_speed * 0.4
	else:
		speed = base_speed

	# 근접 하인이 있으면 그 하인을 우선 타겟, 없으면 성
	var minion_target = _find_nearby_minion()
	var target_pos: Vector2
	if is_instance_valid(minion_target):
		target_pos = minion_target.global_position
	else:
		target_pos = game.get_node("Castle").global_position

	var dir = (target_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

	var dist = global_position.distance_to(target_pos)
	if dist < 50.0:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			if is_instance_valid(minion_target):
				minion_target.take_damage(damage)
			else:
				game.castle_take_damage(damage)
	else:
		attack_timer = 0.0

func _find_nearby_minion():
	var nearest = null
	var nearest_dist: float = INF
	for m in get_tree().get_nodes_in_group("minions"):
		if not is_instance_valid(m):
			continue
		var d: float = global_position.distance_to(m.global_position)
		if d < MINION_ENGAGE_RANGE and d < nearest_dist:
			nearest_dist = d
			nearest = m
	return nearest

func take_damage(dmg: float):
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg)
	if hp <= 0:
		die()

func _hit_flash():
	sprite.color = Color(1, 0.1, 0.1, 1)
	var t = get_tree().create_timer(0.1)
	t.timeout.connect(func():
		if is_instance_valid(self):
			sprite.color = original_color
	)

func apply_slow(duration: float):
	slow_timer = duration
	sprite.color = Color(0.4, 0.4, 1.0, 1)
	var t = get_tree().create_timer(duration)
	t.timeout.connect(func():
		if is_instance_valid(self):
			sprite.color = original_color
	)

func die():
	if game:
		game.spawn_death_effect(global_position, original_color)
		game.add_souls(randi_range(12, 20))
		game.enemy_died()
	queue_free()
