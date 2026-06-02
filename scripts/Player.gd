extends CharacterBody2D

# 기본 스탯
var speed: float = 200.0
var attack_damage: float = 20.0
var attack_speed: float = 1.0

# 범위 (카드로 증가 가능)
var basic_range: float = 280.0
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

# 넉백 세기 (튜닝값; 적 저항 = hp_mult로 나뉨)
const BASIC_KNOCKBACK: float = 170.0
const SPECIAL_KNOCKBACK: float = 340.0

const SkullScene = preload("res://scenes/Skull.tscn")

var game = null
var _anim_state: String = "idle"

# 범위 표시용
var range_circle: Node2D = null
var aura_circle: Node2D = null

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready():
	game = get_parent()
	_create_range_indicators()
	basic_timer = BASIC_INTERVAL
	_setup_sprite()

func _setup_sprite() -> void:
	anim_sprite.sprite_frames = _build_necromancer_frames()
	anim_sprite.scale = Vector2(0.633, 0.633)
	anim_sprite.animation_finished.connect(_on_animation_finished)
	anim_sprite.play("idle")

func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 15.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

func _build_necromancer_frames() -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/necromancer/"
	var prefix: String = "0_Fallen_Angels"
	_load_anim(sf, "idle",  base_path, prefix, "Idle",     18, true)
	_load_anim(sf, "slash", base_path, prefix, "Slashing", 12, false)
	_load_anim(sf, "throw", base_path, prefix, "Throwing", 12, false)
	_load_anim(sf, "hurt",  base_path, prefix, "Hurt",     12, false)
	return sf

func _play_anim(anim: String) -> void:
	if not is_instance_valid(anim_sprite):
		return
	if _anim_state == anim:
		return
	_anim_state = anim
	anim_sprite.play(anim)

func _on_animation_finished() -> void:
	if _anim_state != "idle":
		_anim_state = "idle"
		anim_sprite.play("idle")

const RANGE_BASIC_COLOR: Color = Color(1.0, 0.95, 0.85)
const RANGE_AURA_COLOR: Color  = Color(0.7, 0.3, 1.0)

func _create_range_indicators():
	range_circle = _make_circle(basic_range, RANGE_BASIC_COLOR)
	range_circle.z_index = -1
	add_child(range_circle)

	aura_circle = _make_circle(aura_radius, RANGE_AURA_COLOR)
	aura_circle.z_index = -1
	aura_circle.visible = false
	add_child(aura_circle)

func _make_circle(radius: float, base_color: Color) -> Node2D:
	var n: Node2D = Node2D.new()
	_build_circle_visuals(n, radius, base_color)
	return n

func _build_circle_visuals(parent: Node2D, radius: float, base_color: Color) -> void:
	var fill: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 64:
		var angle: float = (TAU / 64) * i
		pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	fill.polygon = pts
	fill.color = Color(base_color.r, base_color.g, base_color.b, 0.06)
	parent.add_child(fill)

	var line: Line2D = Line2D.new()
	line.default_color = Color(base_color.r, base_color.g, base_color.b, 0.45)
	line.width = 2.5
	for i: int in 65:
		var angle: float = (TAU / 64) * i
		line.add_point(Vector2(cos(angle) * radius, sin(angle) * radius))
	parent.add_child(line)

func _update_range_circles() -> void:
	_rebuild_circle(range_circle, basic_range, RANGE_BASIC_COLOR)
	_rebuild_circle(aura_circle, aura_radius, RANGE_AURA_COLOR)

func _rebuild_circle(parent: Node2D, radius: float, base_color: Color) -> void:
	if not is_instance_valid(parent):
		return
	for child in parent.get_children():
		child.queue_free()
	_build_circle_visuals(parent, radius, base_color)

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

func use_special_attack() -> void:
	# 특수기: 적 종류·상태별 데미지 분기 (영혼 50 소모는 Game.gd에서 체크)
	_play_anim("throw")
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var crit_landed: bool = false
	for e in enemies:
		if e.has_method("interrupt_windup"):  # 보스
			if e.is_charging_rage:
				e.interrupt_windup()  # 캔슬 + 스턴
				e.take_damage(attack_damage * 2.0 * game.attack_bonus * game.keystone_lord_atk_mult * game.keystone_special_mult, "crit")
				crit_landed = true
			else:
				e.take_damage(attack_damage * 1.0 * game.attack_bonus * game.keystone_lord_atk_mult * game.keystone_special_mult, "resist")
		else:  # 잡몹 — ×3 유지
			e.take_damage(attack_damage * 3.0 * game.attack_bonus * game.keystone_lord_atk_mult * game.keystone_special_mult)
		e.apply_knockback(position, SPECIAL_KNOCKBACK)
		_flash_attack_line(e.position)
	_flash_special_burst()
	if game:
		if crit_landed:
			game._screen_shake(3.5, 0.25)
			game.hit_stop(0.1)
			game.show_crit_text()
		else:
			game._screen_shake(2.0, 0.15)
			game.hit_stop(0.07)

func _flash_special_burst() -> void:
	var n: Node2D = Node2D.new()
	add_child(n)
	var base_r: float = 10.0
	var seg: int = 32
	var fill: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = (TAU / seg) * i
		pts.append(Vector2(cos(a) * base_r, sin(a) * base_r))
	fill.polygon = pts
	fill.color = Color(0.6, 0.0, 1.0, 0.7)
	n.add_child(fill)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(n, "scale", Vector2.ONE * 50.0, 0.4)
	tween.parallel().tween_property(n, "modulate:a", 0.0, 0.4)
	tween.tween_callback(n.queue_free)

func _basic_attack():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit: bool = false
	for e in enemies:
		if position.distance_to(e.position) <= basic_range:
			e.take_damage(attack_damage * game.attack_bonus * game.keystone_lord_atk_mult)
			e.apply_knockback(position, BASIC_KNOCKBACK)
			_flash_magic_bolt(e.position)
			hit = true
	if hit:
		_play_anim("throw")

func _death_aura():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if position.distance_to(e.position) <= aura_radius:
			e.take_damage(attack_damage * 0.6 * game.attack_bonus * game.keystone_lord_atk_mult)

func _skull_throw():
	var nearest = _get_nearest_enemy(600.0)
	if not nearest:
		return
	var skull = SkullScene.instantiate()
	skull.position = position
	skull.direction = (nearest.position - position).normalized()
	skull.damage = attack_damage * 1.5 * game.attack_bonus * game.keystone_lord_atk_mult
	get_parent().add_child(skull)

func _decay_curse():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if position.distance_to(e.position) <= curse_radius:
			e.apply_slow(3.0)

func _flash_attack_line(target_pos: Vector2):
	_flash_magic_bolt(target_pos)

func _flash_magic_bolt(target_pos: Vector2) -> void:
	var local_target: Vector2 = to_local(target_pos)
	var line: Line2D = Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(local_target)
	line.width = 4.0
	line.default_color = Color(0.7, 0.2, 1.0, 0.85)
	add_child(line)
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)
	var p: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 12:
		var a: float = (TAU / 12) * i
		pts.append(local_target + Vector2(cos(a) * 9.0, sin(a) * 9.0))
	p.polygon = pts
	p.color = Color(0.85, 0.3, 1.0, 0.9)
	add_child(p)
	var tween2: Tween = create_tween()
	tween2.parallel().tween_property(p, "scale", Vector2(1.6, 1.6), 0.3)
	tween2.parallel().tween_property(p, "modulate:a", 0.0, 0.3)
	tween2.tween_callback(p.queue_free)

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
