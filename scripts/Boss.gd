extends CharacterBody2D

const WaveData = preload("res://scripts/WaveData.gd")

var hp: float = 300.0
var max_hp: float = 300.0
var speed: float = 50.0
var base_speed: float = 50.0
var damage: int = 20
var base_damage: int = 20
var attack_cooldown: float = 1.2
var attack_timer: float = 0.0
var boss_name: String = "보스"
var boss_type: String = "mid_boss"  # "mid_boss" or "boss"

var game = null

# 수습 인턴 - 랜덤 돌진
var dash_timer: float = 0.0
var dash_interval: float = 3.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_duration: float = 0.5
var dash_elapsed: float = 0.0
const DASH_SPEED: float = 400.0
const BOUNDS = Rect2(0, -280, 1024, 900)

# 알바생 - 페이즈
var overtime_triggered: bool = false
var phase3_triggered: bool = false

# 빡침 충전 (인턴) / 혈투 분노 (알바생 P3) - 고지된 성 직격 공격
var rage_timer: float = 0.0
var rage_interval: float = 6.0
var is_charging_rage: bool = false
var rage_charge_time: float = 0.0
var rage_charge_duration: float = 1.5
var rage_damage: int = 50

# 알바생 P2+ 동료 호출
var summon_timer: float = 0.0
var summon_interval: float = 10.0

@onready var hp_bar = $HPBar
@onready var name_label = $NameLabel
@onready var sprite = $Sprite

var original_color: Color = Color(0.9, 0.2, 0.2, 1)

func _ready():
	add_to_group("enemies")
	base_speed = speed
	base_damage = damage
	name_label.text = boss_name
	original_color = sprite.color
	collision_mask = 0  # 하인/적에게 물리적으로 막히지 않음
	# 보스 타입별 충전 공격 파라미터
	if boss_type == "mid_boss":
		rage_interval = 6.0
		rage_charge_duration = 1.5
		rage_damage = 50
	else:
		rage_interval = 6.0
		rage_charge_duration = 1.0
		rage_damage = 35

func _physics_process(delta):
	if not game:
		return

	if boss_type == "mid_boss":
		_pattern_intern(delta)
	else:
		_pattern_albaeng(delta)

	# 성 근접 공격 (충전 / 돌진 중에는 멜리 비활성)
	var castle_pos = game.get_node("Castle").global_position
	var dist = global_position.distance_to(castle_pos)
	if dist < 60.0 and not is_dashing and not is_charging_rage:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			game.castle_take_damage(damage)
	else:
		attack_timer = 0.0

# ============ 인턴 패턴 ============
func _pattern_intern(delta):
	if is_charging_rage:
		_process_charge(delta)
		return

	var castle_pos = game.get_node("Castle").global_position

	if is_dashing:
		dash_elapsed += delta
		velocity = dash_direction * DASH_SPEED
		move_and_slide()
		_clamp_to_bounds()
		if dash_elapsed >= dash_duration or not BOUNDS.has_point(position):
			is_dashing = false
			dash_elapsed = 0.0
			sprite.color = original_color
		return

	# 걷기 + 타이머 누적
	var dir = (castle_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_clamp_to_bounds()

	rage_timer += delta
	if rage_timer >= rage_interval:
		rage_timer = 0.0
		_start_rage_charge("잠깐만, 이거 정리 좀…", Color(1.0, 0.6, 0.2))
		return

	dash_timer += delta
	if dash_timer >= dash_interval:
		dash_timer = 0.0
		_start_dash()

func _start_dash():
	is_dashing = true
	var angle = randf_range(0, PI)
	dash_direction = Vector2(cos(angle), sin(angle))
	sprite.color = Color(1.0, 0.8, 0.0, 1)

# ============ 알바생 패턴 ============
func _pattern_albaeng(delta):
	if not overtime_triggered and hp <= max_hp * 0.5:
		_enter_overtime()
	if not phase3_triggered and hp <= max_hp * 0.25:
		_enter_phase3()

	if is_charging_rage:
		_process_charge(delta)
		return

	var castle_pos = game.get_node("Castle").global_position
	var dir = (castle_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_clamp_to_bounds()

	# 페이즈 2+: 동료 호출
	if overtime_triggered:
		summon_timer += delta
		if summon_timer >= summon_interval:
			summon_timer = 0.0
			_summon_companions()

	# 페이즈 3: 혈투 분노 (성 직격)
	if phase3_triggered:
		rage_timer += delta
		if rage_timer >= rage_interval:
			rage_timer = 0.0
			_start_rage_charge("이건 내 인생을 건 보고서다!!", Color(1.0, 0.2, 0.2))

func _enter_overtime():
	overtime_triggered = true
	speed = base_speed * 2.0
	damage = base_damage * 2
	attack_cooldown = 0.7
	sprite.color = Color(1.0, 0.3, 0.0, 1)
	name_label.text = boss_name + "\n[야근 모드]"
	summon_timer = summon_interval * 0.5  # 진입 후 5초 만에 첫 소환
	if game and game.has_method("show_dialogue"):
		game.show_dialogue("야근 수당이라도 달란 말이야!!", Color(1.0, 0.6, 0.1, 1))

func _enter_phase3():
	phase3_triggered = true
	speed = base_speed * 3.0
	damage = base_damage * 3
	attack_cooldown = 0.5
	sprite.color = Color(1.0, 0.05, 0.05, 1)
	name_label.text = boss_name + "\n[초과 야근]"
	summon_interval = 7.0  # P3에서 소환 빈도 ↑
	rage_timer = rage_interval * 0.5  # P3 진입 직후 첫 분노까지 짧게
	if game and game.has_method("show_dialogue"):
		game.show_dialogue("...그냥 쓰러질 때까지 달린다!!", Color(1.0, 0.2, 0.2, 1))

# ============ 공통 액션 ============
func _start_rage_charge(dialogue: String, color: Color):
	is_charging_rage = true
	rage_charge_time = 0.0
	velocity = Vector2.ZERO
	if game and game.has_method("show_dialogue"):
		game.show_dialogue(dialogue, color)

func _process_charge(delta):
	rage_charge_time += delta
	velocity = Vector2.ZERO
	move_and_slide()
	# 충전 중 노란색 빠르게 깜빡임 → 임팩트 직전 흰색
	var t: float = rage_charge_time / rage_charge_duration
	var pulse: float = (sin(rage_charge_time * 30.0) + 1.0) * 0.5
	sprite.color = Color(1.0, 0.9 - pulse * 0.5, 0.1 + t * 0.3, 1)

	if rage_charge_time >= rage_charge_duration:
		_execute_rage_attack()

func _execute_rage_attack():
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_color()
	if game:
		game.castle_take_damage(rage_damage)

func _summon_companions():
	if game and game.has_method("boss_summon"):
		game.boss_summon("swarm", 3)
		if game.has_method("show_dialogue"):
			game.show_dialogue("동료들도 같이 야근하자!", Color(0.95, 0.7, 0.2))

func _restore_phase_color():
	if phase3_triggered:
		sprite.color = Color(1.0, 0.05, 0.05, 1)
	elif overtime_triggered:
		sprite.color = Color(1.0, 0.3, 0.0, 1)
	else:
		sprite.color = original_color

# ============ 피격 / 사망 ============
func take_damage(dmg: float):
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg)
	if hp <= 0:
		die()

func _hit_flash():
	# 충전 중에는 충전 애니메이션 유지 (덮어쓰지 않음)
	if is_charging_rage:
		return
	var flash_color = Color(1, 1, 1, 1)
	sprite.color = flash_color
	var t = get_tree().create_timer(0.1)
	t.timeout.connect(func():
		if is_instance_valid(self):
			if is_charging_rage:
				return
			if phase3_triggered:
				sprite.color = Color(1.0, 0.05, 0.05, 1)
			elif overtime_triggered:
				sprite.color = Color(1.0, 0.3, 0.0, 1)
			elif is_dashing:
				sprite.color = Color(1.0, 0.8, 0.0, 1)
			else:
				sprite.color = original_color
	)

func _clamp_to_bounds():
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

func apply_slow(_duration: float):
	pass  # 보스는 슬로우 면역

func die():
	if game:
		game.spawn_death_effect(global_position, original_color)
		game.add_souls(randi_range(100, 200))
		var shards: int = WaveData.get_wave(game.current_chapter, game.current_stage, game.current_wave).get("crown_shards", 0)
		game.earn_crown_shards(shards)
		game.on_boss_killed(global_position, shards, boss_type == "boss")
		game.enemy_died(true)
	queue_free()
