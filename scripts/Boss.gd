extends CharacterBody2D

const WaveData = preload("res://scripts/WaveData.gd")
const RangeIndicatorScript = preload("res://scripts/RangeIndicator.gd")

const BOSS_SPRITE_MAP: Dictionary = {
	"수습 용사 인턴":    "boss_intern",
	"정의의 용사 알바생": "boss_parttime",
	"용사 대리":          "boss_assistant",
	"정의의 용사 과장":   "boss_manager",
}
const BOSS_SCALE_MAP: Dictionary = {
	"boss_intern":    0.211,
	"boss_parttime":  0.404,
	"boss_assistant": 0.457,
	"boss_manager":   0.580,
}
const BASE_SPRITE_SCALE: float = 0.316

const COLOR_NORMAL: Color  = Color.WHITE
const COLOR_DASH: Color    = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_OVERTIME: Color = Color(1.0, 0.55, 0.3, 1.0)
const COLOR_PHASE3: Color  = Color(1.5, 0.4, 0.4, 1.0)

const RAGE_DIALOGUES: Dictionary = {
	"사관후보생":     "후, 훈련받은 대로...!",
	"수습 용사 인턴": "정, 정직원만 되면...!",
	"용사 대리":      "더 이상은 못 봐준다.",
}

const BOUNDS: Rect2 = Rect2(0, -280, 1024, 900)
const DASH_SPEED: float = 400.0
const CASTLE_HALF: float = 94.0  # 외벽+코너타워 외곽 (CastleSprite S+T=94)
const STOP_DIST: float = 18.0    # 외벽 바깥 standoff (중심 아님). deadzone ≫ 프레임 이동 → 경계 진동 방지
# 접근 중 dir.x가 0 근처에서 부호가 떨려도 flip이 깜빡이지 않도록 데드존.
const FLIP_DEADZONE: float = 0.12

# 성벽 standoff 보정: 스프라이트가 centered라 발끝이 원점 아래로 늘어진다.
# 발끝을 북벽 라인보다 WALL_PENETRATION만큼 성 안쪽에 두어, 큰 보스도 몸통이 벽에 닿아
# 근접 공격이 벽과 연결돼 보이고 잡몹과 정지 라인이 어긋나지 않게 한다.
const BODY_BOTTOM_OFFSET: float = 306.0   # 캔버스 중심→발끝 (px, 알파>200 실측, 4종 공통)
const WALL_PENETRATION: float = 0.0       # 발끝을 북벽 라인에 맞춤(파고들지 않음). 0보다 크면 안쪽으로.

# 하인 교전 (압박형) — 와인드업·격노·돌진 중엔 적용 안 됨(그 상태들이 _approach_castle 이전에 return)
const MINION_ENGAGE_RANGE: float = 100.0  # 길목 하인 감지 거리 (Enemy.gd와 일치)
const MINION_ATTACK_RANGE: float = 50.0   # 하인 교전 사거리 (Enemy.gd와 일치)
const MAX_ENGAGE_TIME: float = 3.0        # 이 시간만 교전 후 뿌리치고 전진
const ENGAGE_COOLDOWN: float = 4.0        # 뿌리친 뒤 하인 무시하고 성으로 밀고 드는 시간

static var _cached_frames: Dictionary = {}

var hp: float = 300.0
var max_hp: float = 300.0
var speed: float = 50.0
var base_speed: float = 50.0
var damage: int = 20
var base_damage: int = 20
var attack_cooldown: float = 1.2
var attack_timer: float = 0.0
var castle_standoff: float = STOP_DIST  # _ready에서 스프라이트 크기 반영해 재계산
var minion_attack_timer: float = 0.0
var engage_time: float = 0.0
var ignore_minion_timer: float = 0.0
var boss_name: String = "보스"
var boss_type: String = "mid_boss"

var game = null
var _anim_state: String = ""

# 인턴 - 돌진
var dash_timer: float = 0.0
var dash_interval: float = 3.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_duration: float = 0.5
var dash_elapsed: float = 0.0

# 알바생 - 페이즈
var overtime_triggered: bool = false
var phase3_triggered: bool = false

var rage_timer: float = 0.0
var rage_interval: float = 6.0
var is_charging_rage: bool = false
var rage_charge_time: float = 0.0
var is_stunned: bool = false
var rage_charge_duration: float = 1.5
var rage_damage: int = 50

var summon_timer: float = 0.0
var summon_interval: float = 18.0
var summon_count: int = 2

@onready var hp_bar: ProgressBar = $HPBar
@onready var name_label: Label = $NameLabel
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("enemies")
	base_speed = speed
	base_damage = damage
	name_label.text = boss_name
	collision_mask = 4  # 영주(레이어 3)하고만 충돌 — 겹침 방지. 잡몹(레이어1)·하인(레이어2) 무리엔 안 낌
	if boss_type == "mid_boss":
		rage_interval = 6.0
		rage_charge_duration = 1.5
		rage_damage = 50
	else:
		rage_interval = 6.0
		rage_charge_duration = 1.0
		rage_damage = 35

	var folder: String = BOSS_SPRITE_MAP.get(boss_name, "boss_intern")
	var sprite_scale: float = BOSS_SCALE_MAP.get(folder, BASE_SPRITE_SCALE)
	anim_sprite.sprite_frames = _get_sprite_frames(folder)
	anim_sprite.scale = Vector2.ONE * sprite_scale
	# 발끝 = 북벽 라인 + WALL_PENETRATION 에 멈추도록 standoff를 크기에 비례해 산정.
	# 작은 보스는 발끝 늘어짐이 작아 음수가 될 수 있어 STOP_DIST로 하한(공격 판정 보장).
	castle_standoff = maxf(STOP_DIST, BODY_BOTTOM_OFFSET * sprite_scale - WALL_PENETRATION)
	# 공격 범위 표시(표시 전용·보스타입=빨강): 발밑에 깐다. 반경은 크기 비례.
	var boss_indicator := RangeIndicatorScript.new()
	add_child(boss_indicator)
	# 원점→캐릭터 시각 중심 ≈ 37px×스케일 아래(발밑 아님 — 보스가 원 중심).
	boss_indicator.setup(110.0 * sprite_scale + 40.0, Color(1.0, 0.35, 0.35), 37.0 * sprite_scale)
	anim_sprite.animation_finished.connect(_on_animation_finished)
	_play_anim("idle")

static func _get_sprite_frames(folder: String) -> SpriteFrames:
	if folder in _cached_frames:
		return _cached_frames[folder]
	var sf: SpriteFrames = _build_sprite_frames(folder)
	_cached_frames[folder] = sf
	return sf

static func _get_char_prefix(folder: String) -> String:
	match folder:
		"boss_intern":    return "0_Goblin"
		"boss_parttime":  return "0_Orc"
		"boss_assistant": return "0_Valkyrie"
		"boss_manager":   return "0_Golem"
	return "0_Goblin"

static func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 15.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

static func _build_sprite_frames(folder: String) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/%s/" % folder
	var prefix: String = _get_char_prefix(folder)
	_load_anim(sf, "idle",  base_path, prefix, "Idle",     18, true)
	_load_anim(sf, "walk",  base_path, prefix, "Walking",  24, true)
	_load_anim(sf, "slash", base_path, prefix, "Slashing", 12, false)
	_load_anim(sf, "hurt",  base_path, prefix, "Hurt",     12, false)
	_load_anim(sf, "die",   base_path, prefix, "Dying",    15, false)
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
		"slash", "hurt":
			_anim_state = ""
		"die":
			queue_free()

func _physics_process(delta: float) -> void:
	if not game:
		return
	if _anim_state == "die":
		return
	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if boss_type == "mid_boss":
		_pattern_intern(delta)
	else:
		_pattern_albaeng(delta)

	var castle_pos: Vector2 = game.get_node("Castle").global_position
	if _castle_wall_dist(castle_pos) <= castle_standoff and not is_dashing and not is_charging_rage:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			game.castle_take_damage(damage, global_position)
			if _anim_state not in ["hurt", "die"]:
				_play_anim("slash")
	else:
		attack_timer = 0.0

	# 성벽 키프아웃 안전망: 돌진·밀림으로 외벽 안에 들어가면 가장 가까운 변 바깥으로 고정.
	# (정상 접근은 _approach_castle의 standoff에서 먼저 멈추므로 여기 거의 안 걸림)
	var kc: Vector2 = castle_pos
	if global_position.x > kc.x - CASTLE_HALF and global_position.x < kc.x + CASTLE_HALF \
			and global_position.y > kc.y - CASTLE_HALF and global_position.y < kc.y + CASTLE_HALF:
		var kd_top: float = global_position.y - (kc.y - CASTLE_HALF)
		var kd_bot: float = (kc.y + CASTLE_HALF) - global_position.y
		var kd_left: float = global_position.x - (kc.x - CASTLE_HALF)
		var kd_right: float = (kc.x + CASTLE_HALF) - global_position.x
		var km: float = min(min(kd_top, kd_bot), min(kd_left, kd_right))
		if km == kd_top:
			global_position.y = kc.y - CASTLE_HALF
		elif km == kd_bot:
			global_position.y = kc.y + CASTLE_HALF
		elif km == kd_left:
			global_position.x = kc.x - CASTLE_HALF
		else:
			global_position.x = kc.x + CASTLE_HALF

# ============ 인턴 패턴 ============
func _pattern_intern(delta: float) -> void:
	if is_charging_rage:
		_process_charge(delta)
		return

	summon_timer += delta
	if summon_timer >= summon_interval:
		summon_timer = 0.0
		_summon_companions()

	var castle_pos: Vector2 = game.get_node("Castle").global_position

	if is_dashing:
		dash_elapsed += delta
		velocity = dash_direction * DASH_SPEED
		move_and_slide()
		_clamp_to_bounds()
		_update_facing(dash_direction.x)
		if _anim_state not in ["hurt", "die"]:
			_play_anim("walk")
		if dash_elapsed >= dash_duration or not BOUNDS.has_point(position):
			is_dashing = false
			dash_elapsed = 0.0
			anim_sprite.modulate = COLOR_NORMAL
		return

	_engage_or_approach(delta, castle_pos)

	rage_timer += delta
	if rage_timer >= rage_interval:
		rage_timer = 0.0
		var rage_line: String = RAGE_DIALOGUES.get(boss_name, "이건 진심이다.")
		_start_rage_charge(rage_line, Color(1.0, 0.6, 0.2))
		return

	dash_timer += delta
	if dash_timer >= dash_interval:
		dash_timer = 0.0
		_start_dash()

func _start_dash() -> void:
	is_dashing = true
	var angle: float = randf_range(0, PI)
	dash_direction = Vector2(cos(angle), sin(angle))
	anim_sprite.modulate = COLOR_DASH

# ============ 알바생 패턴 ============
func _pattern_albaeng(delta: float) -> void:
	if not overtime_triggered and hp <= max_hp * 0.5:
		_enter_overtime()
	if not phase3_triggered and hp <= max_hp * 0.25:
		_enter_phase3()

	if is_charging_rage:
		_process_charge(delta)
		return

	var castle_pos: Vector2 = game.get_node("Castle").global_position
	_engage_or_approach(delta, castle_pos)

	summon_timer += delta
	if summon_timer >= summon_interval:
		summon_timer = 0.0
		_summon_companions()

	# 분노 충전(와인드업)을 전 페이즈에서 주기 발동 — 치명타 윈도우 보장.
	# 페이즈가 깊어질수록 더 잦게(escalation), phase3는 발악 대사·색.
	rage_timer += delta
	var interval: float = rage_interval
	if phase3_triggered:
		interval = rage_interval * 0.6
	elif overtime_triggered:
		interval = rage_interval * 0.8
	if rage_timer >= interval:
		rage_timer = 0.0
		summon_timer = 0.0
		if phase3_triggered:
			_start_rage_charge("이건 내 인생을 건 보고서다!!", Color(1.0, 0.2, 0.2))
		else:
			_start_rage_charge(RAGE_DIALOGUES.get(boss_name, "이건 진심이다."), Color(1.0, 0.5, 0.2))

func _enter_overtime() -> void:
	overtime_triggered = true
	speed = base_speed * 2.0
	damage = base_damage * 2
	attack_cooldown = 0.7
	anim_sprite.modulate = COLOR_OVERTIME
	name_label.text = boss_name + "\n[야근 모드]"
	summon_interval = 10.0
	summon_count = 3
	summon_timer = summon_interval * 0.5
	if game and game.has_method("show_dialogue"):
		game.show_dialogue("야근 수당이라도 달란 말이야!!", Color(1.0, 0.6, 0.1, 1), global_position + Vector2(0, -80))

func _enter_phase3() -> void:
	phase3_triggered = true
	speed = base_speed * 3.0
	damage = base_damage * 3
	attack_cooldown = 0.5
	anim_sprite.modulate = COLOR_PHASE3
	name_label.text = boss_name + "\n[초과 야근]"
	summon_interval = 7.0
	summon_count = 3
	rage_timer = rage_interval * 0.5
	if game and game.has_method("show_dialogue"):
		game.show_dialogue("...그냥 쓰러질 때까지 달린다!!", Color(1.0, 0.2, 0.2, 1), global_position + Vector2(0, -80))

# ============ 공통 액션 ============
func _start_rage_charge(dialogue: String, color: Color) -> void:
	is_charging_rage = true
	rage_charge_time = 0.0
	velocity = Vector2.ZERO
	if _anim_state not in ["hurt", "die"]:
		_play_anim("idle")
	if game and game.has_method("show_dialogue"):
		game.show_dialogue(dialogue, color, global_position + Vector2(0, -80))

func _process_charge(delta: float) -> void:
	rage_charge_time += delta
	velocity = Vector2.ZERO
	move_and_slide()
	var t: float = rage_charge_time / rage_charge_duration
	var pulse: float = (sin(rage_charge_time * 30.0) + 1.0) * 0.5
	anim_sprite.modulate = Color(1.0, 0.9 - pulse * 0.5, 0.1 + t * 0.3, 1)
	if rage_charge_time >= rage_charge_duration:
		_execute_rage_attack()

func _execute_rage_attack() -> void:
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_modulate()
	if game:
		game.castle_take_damage(rage_damage, global_position)

func _summon_companions() -> void:
	if game and game.has_method("boss_summon"):
		game.boss_summon("swarm", summon_count)

func _restore_phase_modulate() -> void:
	if phase3_triggered:
		anim_sprite.modulate = COLOR_PHASE3
	elif overtime_triggered:
		anim_sprite.modulate = COLOR_OVERTIME
	else:
		anim_sprite.modulate = COLOR_NORMAL

# ============ 와인드업 중단 / 스턴 ============
func interrupt_windup() -> void:
	if not is_charging_rage:
		return
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_modulate()
	_spawn_cancel_mark()
	apply_stun(1.5)

func apply_stun(duration: float) -> void:
	is_stunned = true
	var stars: Node2D = _spawn_stun_stars()
	var t: SceneTreeTimer = get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			is_stunned = false
			_restore_phase_modulate()
		if is_instance_valid(stars):
			stars.queue_free()
	)

func _spawn_cancel_mark() -> void:
	var container: Node2D = Node2D.new()
	container.position = Vector2(0, -80)
	add_child(container)

	var x_label: Label = Label.new()
	x_label.text = "✕"
	x_label.add_theme_font_size_override("font_size", 36)
	x_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1))
	x_label.position = Vector2(-18, -40)
	container.add_child(x_label)

	var text_label: Label = Label.new()
	text_label.text = "차단!"
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
	text_label.position = Vector2(-22, 0)
	container.add_child(text_label)

	var tween: Tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(container, "modulate:a", 0.0, 0.2)
	tween.tween_callback(container.queue_free)

func _spawn_stun_stars() -> Node2D:
	var container: Node2D = Node2D.new()
	container.position = Vector2(0, -100)
	add_child(container)

	var star_label: Label = Label.new()
	star_label.text = "★★★"
	star_label.add_theme_font_size_override("font_size", 22)
	star_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
	star_label.position = Vector2(-28, 0)
	container.add_child(star_label)

	# 좌우 흔들림 루프 tween
	var tween: Tween = create_tween().set_loops().set_ignore_time_scale(true)
	tween.tween_property(container, "position:x", 6.0, 0.18)
	tween.tween_property(container, "position:x", -6.0, 0.18)
	tween.tween_property(container, "position:x", 0.0, 0.14)

	return container

# ============ 피격 / 사망 ============
func take_damage(dmg: float, tier: String = "normal") -> void:
	if _anim_state == "die":
		return
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg, tier)
	if hp <= 0:
		_die()
		return
	if not is_charging_rage and not is_stunned:
		_play_anim("hurt")

func _hit_flash() -> void:
	if is_charging_rage:
		return
	anim_sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)
	var t: SceneTreeTimer = get_tree().create_timer(0.1)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_charging_rage:
			_restore_phase_modulate()
	)

func _update_facing(dx: float) -> void:
	# dx가 데드존 안이면 직전 방향 유지 — 중앙 정렬 시 flip_h 깜빡임(쪼개짐) 방지
	if absf(dx) > FLIP_DEADZONE:
		anim_sprite.flip_h = dx < 0

# 압박형 교전: 길목의 전사·탱커와 잠깐 싸우다, MAX_ENGAGE_TIME이 지나면 뿌리치고
# ENGAGE_COOLDOWN 동안 하인을 무시한 채 성으로 밀고 든다. 궁수는 _find_nearby_minion이 제외.
func _engage_or_approach(delta: float, castle_pos: Vector2) -> void:
	if ignore_minion_timer > 0.0:
		ignore_minion_timer -= delta
		_approach_castle(castle_pos)
		return

	var minion = _find_nearby_minion()
	if not is_instance_valid(minion):
		engage_time = 0.0
		minion_attack_timer = 0.0
		_approach_castle(castle_pos)
		return

	engage_time += delta
	if engage_time >= MAX_ENGAGE_TIME:
		engage_time = 0.0
		minion_attack_timer = 0.0
		ignore_minion_timer = ENGAGE_COOLDOWN
		_approach_castle(castle_pos)
		return

	var target_pos: Vector2 = minion.global_position
	var dist: float = global_position.distance_to(target_pos)
	if dist <= MINION_ATTACK_RANGE:
		velocity = Vector2.ZERO
		move_and_slide()
		minion_attack_timer += delta
		if minion_attack_timer >= attack_cooldown:
			minion_attack_timer = 0.0
			minion.take_damage(damage)
			if _anim_state not in ["hurt", "die"]:
				_play_anim("slash")
		elif _anim_state not in ["slash", "hurt", "die"]:
			_play_anim("idle")
	else:
		var dir: Vector2 = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		_clamp_to_bounds()
		_update_facing(dir.x)
		if _anim_state not in ["slash", "hurt", "die"]:
			_play_anim("walk")

# 길목 하인 탐색 — minions 그룹에서 가장 가까운 근접 하인. 궁수(ranged)는 어그로 제외(Enemy.gd와 동일).
func _find_nearby_minion():
	var nearest = null
	var nearest_dist: float = INF
	for m in get_tree().get_nodes_in_group("minions"):
		if not is_instance_valid(m):
			continue
		if m.get("behavior") == "ranged":
			continue
		var d: float = global_position.distance_to(m.global_position)
		if d < MINION_ENGAGE_RANGE and d < nearest_dist:
			nearest_dist = d
			nearest = m
	return nearest

# 성으로 접근하되 외벽 바깥 castle_standoff에 닿으면 멈춘다(마당 진입/파고들기/flip 토글 방지).
func _approach_castle(castle_pos: Vector2) -> void:
	if _castle_wall_dist(castle_pos) <= castle_standoff:
		velocity = Vector2.ZERO
		move_and_slide()
		# 정지 시 facing 갱신 안 함 — 수평 dir로 인한 매 프레임 flip 토글 차단
		if _anim_state not in ["slash", "hurt", "die"]:
			_play_anim("idle")
		return
	var dir: Vector2 = (castle_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_clamp_to_bounds()
	_update_facing(dir.x)
	if _anim_state not in ["slash", "hurt", "die"]:
		_play_anim("walk")

# 외벽 사각형(CASTLE_HALF)까지의 거리 — 점이 아니라 박스 기준. 박스 안이면 0.
func _castle_wall_dist(castle_pos: Vector2) -> float:
	var rel: Vector2 = global_position - castle_pos
	var dx: float = max(0.0, absf(rel.x) - CASTLE_HALF)
	var dy: float = max(0.0, absf(rel.y) - CASTLE_HALF)
	return sqrt(dx * dx + dy * dy)

func _clamp_to_bounds() -> void:
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

func apply_knockback(_from_pos: Vector2, _force: float) -> void:
	pass  # 보스는 넉백 면역

func apply_slow(_duration: float) -> void:
	pass  # 보스는 슬로우 면역

func _die() -> void:
	_play_anim("die")
	if game:
		game.spawn_death_effect(global_position, Color.WHITE)
		game.add_souls(randi_range(100, 200))
		var shards: int = WaveData.get_wave(game.current_chapter, game.current_stage, game.current_wave).get("crown_shards", 0)
		game.earn_crown_shards(shards)
		game.on_boss_killed(global_position, shards, boss_type == "boss")
		game.enemy_died(true)
