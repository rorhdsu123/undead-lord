extends CharacterBody2D

const ArrowScene = preload("res://scenes/Arrow.tscn")
const RangeIndicatorScript = preload("res://scripts/RangeIndicator.gd")

const TYPE_PRESETS: Dictionary = {
	"normal": {"hp_mult": 1.0, "speed_mult": 1.0, "damage_mult": 1.0, "scale": 1.0,
		"folder": "enemy_normal", "attack_anim": "Slashing",
		"cooldown": 1.5, "castle_range": 2.0, "ignore_minions": false, "ranged": false},
	"scout":  {"hp_mult": 0.5, "speed_mult": 1.0, "damage_mult": 0.6, "scale": 0.8,
		"folder": "enemy_scout",  "attack_anim": "Shooting",
		"cooldown": 2.0, "castle_range": 120.0, "ignore_minions": false, "ranged": true},
	"brute":  {"hp_mult": 3.5, "speed_mult": 0.5, "damage_mult": 1.5, "scale": 1.45,
		"folder": "enemy_brute",  "attack_anim": "Slashing",
		"cooldown": 1.5, "castle_range": 2.0, "ignore_minions": false, "ranged": false},
	"swarm":  {"hp_mult": 0.3, "speed_mult": 1.3, "damage_mult": 0.5, "scale": 0.65,
		"folder": "enemy_swarm",  "attack_anim": "Kicking",
		"cooldown": 1.5, "castle_range": 2.0, "ignore_minions": false, "ranged": false},
	"runner": {"hp_mult": 0.6, "speed_mult": 1.7, "damage_mult": 1.2, "scale": 0.9,
		"folder": "enemy_normal", "attack_anim": "Slashing",
		"cooldown": 1.2, "castle_range": 2.0, "ignore_minions": true, "ranged": false},
}

const BASE_HP: float = 50.0
const BASE_SPEED: float = 60.0
const BASE_DAMAGE: int = 10
const BASE_SPRITE_SCALE: float = 0.246
const MINION_ENGAGE_RANGE: float = 100.0
const KNOCKBACK_DECAY: float = 700.0
const CASTLE_HALF: float = 80.0  # CastleSprite.S 와 일치
# 적 활동 범위 — 화면 480×960 세로. 상한=스폰선(HUD ~y142 아래), 하한=성 아래 여유.
# 나팔 넉백이 적을 화면 밖으로 날려보내 "안 보이는 적이 성을 때리는" 버그 방지.
const PLAY_BOUNDS: Rect2 = Rect2(0.0, 150.0, 480.0, 750.0)  # x:0~480, y:150~900
const MAX_KNOCKBACK: float = 600.0  # 넉백 속도 상한 (px/s) — 나팔 연타 누적 폭주 방지

static var _cached_frames: Dictionary = {}

var hp: float = 50.0
var max_hp: float = 50.0
var speed: float = 60.0
var base_speed: float = 60.0
var damage: int = 10
var attack_cooldown: float = 1.5
var attack_timer: float = 0.0
var slow_timer: float = 0.0
var knockback_vel: Vector2 = Vector2.ZERO
var knockback_resist: float = 1.0  # 질량 대용(hp_mult). 클수록 덜 밀림
var _sprite_base_scale: Vector2 = Vector2.ONE
var enemy_type: String = "normal"
var castle_attack_range: float = 2.0
var ignore_minions: bool = false
var is_ranged: bool = false
var _attack_anim: String = "slash"
var _anim_state: String = ""
var _last_valid_pos: Vector2 = Vector2.ZERO  # move_and_slide NaN 복구용 (겹친 바디 충돌 해소 가드)

var game = null

@onready var hp_bar: ProgressBar = $HPBar
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("enemies")
	# 잡몹끼리 안 밀어내고 자유롭게 겹치도록 충돌 해제(레이어 1은 유지 → 아군 화살 명중 판정 정상).
	# 성벽 막힘은 콜리전이 아니라 수동 위치 클램프라 영향 없음. 완전 겹침 시 NaN 해소도 불필요해짐.
	collision_mask = 0
	var preset: Dictionary = TYPE_PRESETS.get(enemy_type, TYPE_PRESETS["normal"])
	var base_scale: float = preset["scale"]
	hp = BASE_HP * preset["hp_mult"]
	max_hp = hp
	speed = BASE_SPEED * preset["speed_mult"]
	base_speed = speed
	damage = int(BASE_DAMAGE * preset["damage_mult"])
	knockback_resist = preset["hp_mult"]
	_attack_anim = preset["attack_anim"].to_lower()
	attack_cooldown = preset.get("cooldown", 1.5)
	castle_attack_range = preset.get("castle_range", 2.0)
	ignore_minions = preset.get("ignore_minions", false)
	is_ranged = preset.get("ranged", false)

	var folder: String = preset["folder"]
	anim_sprite.sprite_frames = _get_sprite_frames(folder, preset["attack_anim"])
	anim_sprite.scale = Vector2.ONE * BASE_SPRITE_SCALE * base_scale
	_sprite_base_scale = anim_sprite.scale
	anim_sprite.animation_finished.connect(_on_animation_finished)
	# 공격 범위 표시(표시 전용): 근접=파랑·원거리=빨강. 캐릭터 시각 중심에 정원으로 깐다.
	var ind_radius: float = castle_attack_range if is_ranged else 60.0 * base_scale
	var ind_color: Color = Color(1.0, 0.35, 0.35) if is_ranged else Color(0.3, 0.6, 1.0)
	var indicator := RangeIndicatorScript.new()
	add_child(indicator)
	# 원점→캐릭터 시각 중심 ≈ 37px×스케일 아래(발밑 아님 — 캐릭터가 원 중심).
	indicator.setup(ind_radius, ind_color, 37.0 * anim_sprite.scale.y)
	_play_anim("idle")

static func _get_sprite_frames(folder: String, attack_folder: String) -> SpriteFrames:
	if folder in _cached_frames:
		return _cached_frames[folder]
	var sf: SpriteFrames = _build_sprite_frames(folder, attack_folder)
	_cached_frames[folder] = sf
	return sf

static func _get_char_prefix(folder: String) -> String:
	match folder:
		"enemy_normal", "enemy_brute": return "0_Bloody_Alchemist"
		"enemy_scout",  "enemy_swarm": return "0_Forest_Ranger"
	return "0_Bloody_Alchemist"

static func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 15.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

static func _build_sprite_frames(folder: String, attack_folder: String) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/%s/" % folder
	var prefix: String = _get_char_prefix(folder)
	var attack_frames: int = 9 if attack_folder == "Shooting" else 12
	_load_anim(sf, "idle",   base_path, prefix, "Idle",        18, true)
	_load_anim(sf, "walk",   base_path, prefix, "Walking",     24, true)
	_load_anim(sf, "attack", base_path, prefix, attack_folder, attack_frames, false)
	_load_anim(sf, "hurt",   base_path, prefix, "Hurt",        12, false)
	_load_anim(sf, "die",    base_path, prefix, "Dying",       15, false)
	return sf

func _play_anim(anim: String) -> void:
	if not is_instance_valid(anim_sprite):
		return
	if _anim_state == anim:
		return
	_anim_state = anim
	anim_sprite.play(anim)

func _on_animation_finished() -> void:
	match _anim_state:
		"attack", "hurt":
			_anim_state = ""
		"die":
			queue_free()

func _physics_process(delta: float) -> void:
	if not game:
		return
	if _anim_state == "die":
		return

	# 직전 유효 위치 기록 (move_and_slide NaN 복구 기준점)
	_last_valid_pos = global_position

	# 넉백: 직접 위치 이동 + 선형 감쇠 (이동 로직과 독립적으로 누적)
	if knockback_vel.length_squared() > 1.0:
		global_position += knockback_vel * delta
		knockback_vel = knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if slow_timer > 0:
		slow_timer -= delta
		speed = base_speed * 0.4
	else:
		speed = base_speed

	var minion_target = _find_nearby_minion()
	var effective_target = minion_target

	var target_pos: Vector2
	if is_instance_valid(effective_target):
		target_pos = effective_target.global_position
	else:
		target_pos = game.get_node("Castle").global_position

	var dist: float
	var attack_range: float
	if is_instance_valid(effective_target):
		dist = global_position.distance_to(target_pos)
		attack_range = 50.0 if is_instance_valid(minion_target) else castle_attack_range
	else:
		var rel: Vector2 = global_position - target_pos
		var dx: float = max(0.0, absf(rel.x) - CASTLE_HALF)
		var dy: float = max(0.0, absf(rel.y) - CASTLE_HALF)
		dist = sqrt(dx * dx + dy * dy)
		attack_range = castle_attack_range
	if dist < attack_range:
		velocity = Vector2.ZERO
		if _anim_state not in ["attack", "hurt"]:
			_play_anim("idle")
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_do_attack(effective_target)
	else:
		var dir: Vector2 = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		attack_timer = 0.0
		anim_sprite.flip_h = dir.x < 0
		if _anim_state not in ["hurt"]:
			_play_anim("walk")
	# move_and_slide/넉백이 완전히 겹친 바디의 충돌 해소 중 NaN을 낼 수 있음(0 길이 법선 나눗셈).
	# NaN 좌표는 렌더 불가 → "안 보이는데 성 때리는 적 + 웨이브 소프트락"의 원인. 직전 유효 위치로 복구.
	if not is_finite(global_position.x) or not is_finite(global_position.y):
		global_position = _last_valid_pos
		velocity = Vector2.ZERO
		knockback_vel = Vector2.ZERO
	# 화면 밖 이탈 방지 (넉백·밀림으로 안 보이는 곳으로 새지 않게)
	global_position.x = clamp(global_position.x, PLAY_BOUNDS.position.x, PLAY_BOUNDS.end.x)
	global_position.y = clamp(global_position.y, PLAY_BOUNDS.position.y, PLAY_BOUNDS.end.y)

	# 성벽 키프아웃: 적은 외벽 사각형(CASTLE_HALF 기준) 안으로 진입 불가.
	# 매 프레임 절대좌표를 보정 → 빠른 이동·넉백 터널링 없음. 가장 가까운 변 바깥으로 고정.
	var castle_node: Node2D = game.get_node_or_null("Castle")
	if is_instance_valid(castle_node):
		var c: Vector2 = castle_node.global_position
		var wl: float = c.x - CASTLE_HALF
		var wr: float = c.x + CASTLE_HALF
		var wt: float = c.y - CASTLE_HALF
		var wb: float = c.y + CASTLE_HALF
		if global_position.x > wl and global_position.x < wr and global_position.y > wt and global_position.y < wb:
			var d_top: float = global_position.y - wt
			var d_bot: float = wb - global_position.y
			var d_left: float = global_position.x - wl
			var d_right: float = wr - global_position.x
			var m: float = min(min(d_top, d_bot), min(d_left, d_right))
			if m == d_top:
				global_position.y = wt
			elif m == d_bot:
				global_position.y = wb
			elif m == d_left:
				global_position.x = wl
			else:
				global_position.x = wr

func _do_attack(minion_target) -> void:
	_play_anim("attack")
	if is_instance_valid(minion_target):
		if is_ranged:
			_shoot_arrow(minion_target.global_position)
		minion_target.take_damage(damage)
	else:
		if is_ranged:
			var castle = game.get_node_or_null("Castle")
			if is_instance_valid(castle):
				# 화살은 성 중심이 아니라 가장 가까운 외벽 지점으로(마당 침범 방지, 피격 스파크와 일치).
				var cc: Vector2 = castle.global_position
				var contact: Vector2 = Vector2(
					clamp(global_position.x, cc.x - CASTLE_HALF, cc.x + CASTLE_HALF),
					clamp(global_position.y, cc.y - CASTLE_HALF, cc.y + CASTLE_HALF))
				_shoot_arrow(contact)
		game.castle_take_damage(damage, global_position)

## 원거리 적(사수): 대상 방향으로 시각용 화살 발사. 실제 피해는 take_damage/castle_take_damage가 처리(화살 damage=0).
func _shoot_arrow(target_pos: Vector2) -> void:
	var arrow = ArrowScene.instantiate()
	arrow.position = global_position
	arrow.direction = (target_pos - global_position).normalized()
	arrow.damage = 0.0
	arrow.source = self
	arrow.max_distance = global_position.distance_to(target_pos)  # 대상 지점에서 멈춤(통과 방지)
	game.add_child(arrow)
	arrow.monitoring = false  # 시각용 — 충돌/피해 없음 (자기·아군 적 오적중 방지, "-0" 버그)

func _find_nearby_minion():
	if ignore_minions:
		return null
	var nearest = null
	var nearest_dist: float = INF
	for m in get_tree().get_nodes_in_group("minions"):
		if not is_instance_valid(m):
			continue
		# 궁수(ranged)는 일반 어그로를 끌지 않음 — 적이 궁수에게 멈추지 않고 성벽으로 진행(후열 궁수 보호)
		if m.get("behavior") == "ranged":
			continue
		var d: float = global_position.distance_to(m.global_position)
		if d < MINION_ENGAGE_RANGE and d < nearest_dist:
			nearest_dist = d
			nearest = m
	return nearest

func take_damage(dmg: float) -> void:
	if _anim_state == "die":
		return
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg)
	if hp <= 0:
		_die()

func apply_knockback(from_pos: Vector2, force: float) -> void:
	if _anim_state == "die":
		return
	var dir: Vector2 = global_position - from_pos
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	knockback_vel += dir.normalized() * (force / sqrt(max(knockback_resist, 0.1)))
	knockback_vel = knockback_vel.limit_length(MAX_KNOCKBACK)

func _hit_flash() -> void:
	anim_sprite.modulate = Color(1.5, 0.4, 0.4, 1.0)
	anim_sprite.scale = _sprite_base_scale * 1.18
	var tw: Tween = create_tween()
	tw.tween_property(anim_sprite, "scale", _sprite_base_scale, 0.13) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t: SceneTreeTimer = get_tree().create_timer(0.1)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			anim_sprite.modulate = Color.WHITE
	)

func apply_slow(duration: float) -> void:
	slow_timer = duration
	anim_sprite.modulate = Color(0.5, 0.5, 1.5, 1.0)
	var t: SceneTreeTimer = get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			anim_sprite.modulate = Color.WHITE
	)

func _die() -> void:
	_play_anim("die")
	if game:
		game.spawn_death_effect(global_position, Color.WHITE)
		game.add_souls(randi_range(12, 20))
		game.enemy_died()
