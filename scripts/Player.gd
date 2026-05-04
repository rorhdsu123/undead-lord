extends CharacterBody2D

# 기본 스탯
var speed: float = 200.0
var attack_damage: float = 20.0
var attack_speed: float = 1.0

# 범위 (카드로 증가 가능)
var basic_range: float = 200.0
var aura_radius: float = 80.0
var curse_radius: float = 120.0

# 스킬 보유 여부
var has_death_aura: bool = false
var has_skull_throw: bool = false
var has_decay_curse: bool = false

# 내부 타이머
var basic_timer: float = 0.0
var aura_timer: float = 0.0
var skull_timer: float = 0.0
var curse_timer: float = 0.0

const BASIC_INTERVAL: float = 1.5
const AURA_INTERVAL: float = 0.8
const SKULL_INTERVAL: float = 1.2
const CURSE_INTERVAL: float = 2.0

const SkullScene = preload("res://scenes/Skull.tscn")

var game = null

# 범위 표시용
var range_circle: Node2D = null
var aura_circle: Node2D = null

func _ready():
	game = get_parent()
	_create_range_indicators()
	basic_timer = BASIC_INTERVAL  # 시작 시 즉시 공격 가능

func _create_range_indicators():
	range_circle = _make_circle(basic_range, Color(1, 1, 1, 0.12))
	add_child(range_circle)

	aura_circle = _make_circle(aura_radius, Color(0.6, 0.0, 1.0, 0.15))
	aura_circle.visible = false
	add_child(aura_circle)

func _make_circle(radius: float, color: Color) -> Node2D:
	var n = Node2D.new()
	var script = GDScript.new()
	script.source_code = """
extends Node2D
var r: float = 50.0
var c: Color = Color(1,1,1,0.1)
func _draw():
	draw_circle(Vector2.ZERO, r, c)
"""
	script.reload()
	n.set_script(script)
	n.set("r", radius)
	n.set("c", color)
	return n

func _update_range_circles():
	# 범위 변경 시 원 크기 갱신
	if range_circle:
		range_circle.set("r", basic_range)
		range_circle.queue_redraw()
	if aura_circle:
		aura_circle.set("r", aura_radius)
		aura_circle.queue_redraw()

func _physics_process(delta):
	_handle_attacks(delta)
	aura_circle.visible = has_death_aura

func _handle_attacks(delta):
	if not game or not game.wave_active:
		return

	var interval_mult = 1.0 / attack_speed

	# 기본 공격: 자동 발동 (1.5초마다 광역)
	basic_timer += delta
	if basic_timer >= BASIC_INTERVAL * interval_mult:
		basic_timer = 0.0
		_basic_attack()

	if has_death_aura:
		aura_timer += delta
		if aura_timer >= AURA_INTERVAL:
			aura_timer = 0.0
			_death_aura()

	if has_skull_throw:
		skull_timer += delta
		if skull_timer >= SKULL_INTERVAL * interval_mult:
			skull_timer = 0.0
			_skull_throw()

	if has_decay_curse:
		curse_timer += delta
		if curse_timer >= CURSE_INTERVAL:
			curse_timer = 0.0
			_decay_curse()

func use_special_attack():
	# 특수기: 모든 적에게 큰 광역 데미지 (영혼 50 소모는 Game.gd에서 체크)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		e.take_damage(attack_damage * 3.0 * game.attack_bonus)
		_flash_attack_line(e.position)
	_flash_special_burst()

func _flash_special_burst():
	# 영주 중심 큰 원 폭발 이펙트
	var n = Node2D.new()
	var script = GDScript.new()
	script.source_code = """
extends Node2D
var r: float = 600.0
var c: Color = Color(0.6, 0, 1, 0.4)
func _draw():
	draw_circle(Vector2.ZERO, r, c)
"""
	script.reload()
	n.set_script(script)
	add_child(n)
	var tween = create_tween()
	tween.tween_property(n, "modulate:a", 0.0, 0.4)
	tween.tween_callback(n.queue_free)

func _basic_attack():
	# 광역 공격: 반경 내 모든 적에게 데미지
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if position.distance_to(e.position) <= basic_range:
			e.take_damage(attack_damage * game.attack_bonus)
			_flash_attack_line(e.position)

func _death_aura():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if position.distance_to(e.position) <= aura_radius:
			e.take_damage(attack_damage * 0.6 * game.attack_bonus)

func _skull_throw():
	var nearest = _get_nearest_enemy(600.0)
	if not nearest:
		return
	var skull = SkullScene.instantiate()
	skull.position = position
	skull.direction = (nearest.position - position).normalized()
	skull.damage = attack_damage * 1.5 * game.attack_bonus
	get_parent().add_child(skull)

func _decay_curse():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if position.distance_to(e.position) <= curse_radius:
			e.apply_slow(3.0)

func _flash_attack_line(target_pos: Vector2):
	var line = Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(to_local(target_pos))
	line.width = 5.0
	line.default_color = Color(0.9, 0.3, 1.0, 0.9)
	add_child(line)
	var t = get_tree().create_timer(0.2)
	t.timeout.connect(line.queue_free)

func _get_nearest_enemy(range_limit: float):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var nearest_dist = range_limit
	for e in enemies:
		var d = position.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest
