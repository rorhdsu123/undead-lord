extends CharacterBody2D

# 언데드 하인 - 4종 + 경험치 진화 지원
# (파일명은 호환성 위해 유지, 실질은 범용 Minion)

const ArrowScene = preload("res://scenes/Arrow.tscn")

const TYPE_PRESETS = {
	"warrior": {
		"hp": 100, "speed": 90, "damage": 10, "range": 30, "interval": 1.0,
		"color": Color(0.85, 0.85, 0.8, 1), "scale": 1.0,
		"behavior": "melee", "evolves": true,
	},
	"archer": {
		"hp": 60, "speed": 80, "damage": 8, "range": 260, "interval": 1.2,
		"color": Color(0.95, 0.85, 0.35, 1), "scale": 0.85,
		"behavior": "ranged", "evolves": true,
	},
	"tank": {
		"hp": 250, "speed": 50, "damage": 14, "range": 30, "interval": 1.3,
		"color": Color(0.55, 0.55, 0.75, 1), "scale": 1.45,
		"behavior": "melee", "evolves": true,
	},
	"bomber": {
		"hp": 50, "speed": 115, "damage": 60, "range": 25, "interval": 999.0,
		"color": Color(1.0, 0.45, 0.2, 1), "scale": 0.85,
		"behavior": "bomber", "evolves": false,
	},
}

const EVOLUTION_THRESHOLDS = [5, 10]      # Lv2: 5킬, Lv3: 10킬
const EVOLUTION_MULTS = [1.0, 1.25, 1.6]  # Lv1, Lv2, Lv3 (HP·데미지 배율)
const BOMB_RADIUS: float = 80.0

var minion_type: String = "warrior"
var hp: float = 100.0
var max_hp: float = 100.0
var attack_damage: float = 10.0
var base_damage: float = 10.0
var move_speed: float = 90.0
var attack_range: float = 30.0
var attack_interval: float = 1.0
var behavior: String = "melee"
var evolves: bool = true
var base_max_hp: float = 100.0
var base_scale: float = 1.0
var type_color: Color = Color.WHITE

# 진화
var kill_count: int = 0
var level: int = 1

# 내부 상태
var attack_timer: float = 0.0
var current_target = null
var game = null

const BOUNDS = Rect2(0, -230, 1024, 930)

@onready var hp_bar = $HPBar
@onready var sprite = $Sprite

func _ready() -> void:
	add_to_group("minions")
	var preset: Dictionary = TYPE_PRESETS.get(minion_type, TYPE_PRESETS["warrior"])
	hp = preset["hp"]
	max_hp = preset["hp"]
	base_max_hp = max_hp
	attack_damage = preset["damage"]
	base_damage = attack_damage
	move_speed = preset["speed"]
	attack_range = preset["range"]
	attack_interval = preset["interval"]
	behavior = preset["behavior"]
	evolves = preset["evolves"]
	type_color = preset["color"]
	base_scale = preset["scale"]
	sprite.color = type_color
	sprite.scale = Vector2.ONE * base_scale

func _physics_process(delta: float) -> void:
	if not is_instance_valid(current_target):
		current_target = _find_nearest_enemy()
	if not current_target:
		velocity = Vector2.ZERO
		return

	var dist: float = position.distance_to(current_target.position)
	if dist > attack_range:
		var dir: Vector2 = (current_target.position - position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
		position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)
		attack_timer = 0.0
	else:
		velocity = Vector2.ZERO
		attack_timer += delta
		if attack_timer >= attack_interval:
			attack_timer = 0.0
			_do_attack()

func _do_attack() -> void:
	if not is_instance_valid(current_target):
		return
	match behavior:
		"ranged":
			_shoot_arrow()
		"bomber":
			_explode()
		_:
			_melee_strike()

func _melee_strike() -> void:
	var prev_hp: float = current_target.hp
	current_target.take_damage(attack_damage)
	if prev_hp > 0 and prev_hp <= attack_damage:
		_on_kill()

func _shoot_arrow() -> void:
	if not game:
		return
	var arrow = ArrowScene.instantiate()
	var dir: Vector2 = (current_target.position - position).normalized()
	arrow.position = position
	arrow.direction = dir
	arrow.damage = attack_damage
	game.add_child(arrow)

func _explode() -> void:
	if not game:
		queue_free()
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if position.distance_to(e.position) <= BOMB_RADIUS:
			e.take_damage(attack_damage)
	if game.has_method("spawn_explosion_effect"):
		game.spawn_explosion_effect(position)
	if game.has_method("minion_died"):
		game.minion_died()
	queue_free()

func _on_kill() -> void:
	if not evolves:
		return
	kill_count += 1
	if level < 3 and kill_count >= EVOLUTION_THRESHOLDS[level - 1]:
		_evolve()

func _evolve() -> void:
	level += 1
	var prev_max: float = max_hp
	var mult: float = EVOLUTION_MULTS[level - 1]
	max_hp = base_max_hp * mult
	hp += max_hp - prev_max  # 진화 시 증가분만큼 회복
	hp = min(hp, max_hp)
	attack_damage = base_damage * mult
	sprite.scale = Vector2.ONE * base_scale * (1.0 + 0.15 * (level - 1))
	sprite.color = type_color.lerp(Color(1, 1, 1, 1), 0.25 * (level - 1))
	hp_bar.value = (hp / max_hp) * 100.0
	if game and game.has_method("spawn_evolve_effect"):
		game.spawn_evolve_effect(global_position)

func _find_nearest_enemy():
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var nearest_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d: float = position.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

func take_damage(dmg: float) -> void:
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	if hp <= 0:
		_die()

func _die() -> void:
	if game:
		if game.has_method("spawn_death_effect"):
			game.spawn_death_effect(global_position, type_color)
		if game.has_method("minion_died"):
			game.minion_died()
	queue_free()
