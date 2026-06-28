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
const SHIELD_SCALE: float = 0.40             # 방패 성기사 전용 스케일 — 1-1 벽 컨셉, 플레이스홀더라도 크게 읽히게
const SHIELD_FIRST_WINDUP_DELAY: float = 3.0 # 첫 와인드업은 성벽 도달 후 3초(교습 빠른 진입)
const WINDUP_SCALE_MULT: float = 1.2         # 와인드업 중 스케일 팝(지속) — 피격 팝(0.05)보다 크게, 와인드업 내내 유지

const COLOR_NORMAL: Color  = Color.WHITE
const COLOR_OVERTIME: Color = Color(1.0, 0.55, 0.3, 1.0)
const COLOR_PHASE3: Color  = Color(1.5, 0.4, 0.4, 1.0)

const RAGE_DIALOGUES: Dictionary = {
	"사관후보생":     "후, 훈련받은 대로...!",
	"수습 용사 인턴": "정, 정직원만 되면...!",
	"용사 대리":      "더 이상은 못 봐준다.",
}

const BOUNDS: Rect2 = Rect2(100, -280, 280, 900)  # x:100~380(화면 중앙 대역). 보스가 가장자리로 새지 않게 성 lane에 가둠
const CASTLE_HALF: float = 169.2  # 외벽+코너타워 외곽 (CastleSprite S+T=94 × Castle 노드 scale 1.8)
const STOP_DIST: float = 18.0    # 외벽 바깥 standoff (중심 아님). deadzone ≫ 프레임 이동 → 경계 진동 방지
# 접근 중 dir.x가 0 근처에서 부호가 떨려도 flip이 깜빡이지 않도록 데드존.
const FLIP_DEADZONE: float = 0.12

# 성벽 standoff 보정: 스프라이트가 centered라 발끝이 원점 아래로 늘어진다.
# 발끝을 북벽 라인보다 WALL_PENETRATION만큼 성 안쪽에 두어, 큰 보스도 몸통이 벽에 닿아
# 근접 공격이 벽과 연결돼 보이고 잡몹과 정지 라인이 어긋나지 않게 한다.
const BODY_BOTTOM_OFFSET: float = 150.0   # 캔버스 중심→실제 보이는 부츠(발끝)까지의 보정값. *scale로 화면px. 주의: 불투명 하단(~300소스px)·폭 기준 검출은 부츠 아래로 늘어진 망토·꼬리까지 잡아 과대 → 신뢰 기준은 플테 실측(assistant 부츠≈원점아래 66game px). 150이면 발끝이 성 박스 외곽선에 거의 정확히 닿음(실측 2px). 노브: 키우면 멀리서 멈춤, 줄이면 파고듦
const WALL_PENETRATION: float = 30.0      # 박스 외곽선(±94=코너타워)은 중앙 커튼월(보이는 벽)보다 14px 위 + 흉벽 이빨까지 있어, 발끝이 박스에 닿아도 눈엔 떠 보임. 이 고정 game-px만큼 더 안쪽에 멈춰 발끝이 중앙 벽에 닿게 함(보스 크기 무관 균일 갭이라 여기서 보정).

# 하인 교전 (압박형) — 와인드업·격노·돌진 중엔 적용 안 됨(그 상태들이 _approach_castle 이전에 return)
const MINION_ENGAGE_RANGE: float = 100.0  # 길목 하인 감지 거리 (Enemy.gd와 일치)
const MINION_ATTACK_RANGE: float = 50.0   # 하인 교전 사거리 (Enemy.gd와 일치)

static var _cached_frames: Dictionary = {}

var hp: float = 300.0
var max_hp: float = 300.0
var incoming_damage: float = 0.0  # 전사 anti-overkill: 이 적에 예약된 전사 피해 합(SkeletonWarrior가 가감)
var speed: float = 50.0
var base_speed: float = 50.0
var damage: int = 20
var base_damage: int = 20
var attack_cooldown: float = 1.2
var attack_timer: float = 0.0
var castle_standoff: float = STOP_DIST  # _ready에서 스프라이트 크기 반영해 재계산
var at_wall: bool = false  # 성벽 도달(교전 중) 여부 — 격노 시작 게이트가 참조(멀리서 헛스윙 방지). _physics_process에서 갱신
var _blocking_minion: bool = false  # 앞 근접 하인이 보스를 막는 중 — 참이면 성 피해 차단(라인이 성 보호). _engage_or_approach에서 갱신
# 교전 지대 진입 여부 = 성벽에 닿았거나(at_wall) 앞 하인에게 묶임(_blocking_minion).
# 하인 타겟팅은 at_wall 단독이 아니라 이 값을 참조한다: 앞 하인이 보스를 벽에서 ~70px 밖에 붙들면
# 보스 발끝이 벽에 안 닿아 at_wall=false가 되는데, 그 순간 궁수가 보스를 즉시 놓치고(매 프레임 재평가)
# 근접도 0.5s마다 놓쳐 surge/retreat 떨림이 생겼다. _blocking_minion을 OR로 묶어 묶인 동안 계속 타겟 유지.
var combat_engaged: bool = false
var minion_attack_timer: float = 0.0
var boss_name: String = "보스"
var boss_type: String = "mid_boss"
var boss_pattern: String = ""   # WaveData "pattern" 키. ""=기존 boss_type 분기, "shield"=방패 성기사
var shield_dr: bool = false      # 방패 DR(받는 피해 ×0.5) 활성 — 와인드업 중엔 해제(아래 take_damage)
var _first_windup: bool = true             # 첫 와인드업 여부 — 참이면 SHIELD_FIRST_WINDUP_DELAY, 이후 rage_interval
var _windup_marker: ProgressBar = null     # 머리 위 카운트다운 게이지 (null=방패 아님/비활성)
var _teach_label: Node = null              # 와인드업 교습 힌트 레이블 (null=비교습 상태)

var game = null
var _anim_state: String = ""
var vulnerable_timer: float = 0.0

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

var _sprite_base_scale: Vector2 = Vector2.ONE  # 피격 scale 팝 복귀 기준(스프라이트 크기 반영)
var _hit_tween: Tween = null  # 직전 피격 팝 tween 참조(연속 피격 시 중첩 방지)
var _ghost_tween: Tween = null  # 고스트 트레일 tween(연속 피격 시 중첩 방지)

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_ghost: ProgressBar = $HPGhost
@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")  # 하인 타겟팅이 보스를 origin 대신 at_wall 기준으로 판정
	base_speed = speed
	base_damage = damage
	collision_mask = 4  # 영주(레이어 3)하고만 충돌 — 겹침 방지. 잡몹(레이어1)·하인(레이어2) 무리엔 안 낌
	if boss_type == "mid_boss":
		rage_interval = 6.0
		rage_charge_duration = 1.5
		rage_damage = 50
	else:
		rage_interval = 6.0
		rage_charge_duration = 1.0
		rage_damage = 35

	if boss_pattern == "shield":
		# 방패 성기사: 평소 DR로 안 뚫리는 벽 + 와인드업 2초만 취약창. 소환·페이즈 없음.
		# rage_interval 14s > 낙뢰 쿨(12s) → 다음 와인드업 때 낙뢰가 자연히 차 있음 = 쿨 변경 없이 "항상 끊을 수 있음"
		rage_interval = 14.0
		rage_charge_duration = 3.0   # 1-1 튜토: 게이지 차는 시간 넉넉히(보고→낙뢰 버튼 찾고→탭 여유). 플테 노브
		rage_damage = 40
		shield_dr = true

	var folder: String = BOSS_SPRITE_MAP.get(boss_name, "boss_intern")
	var sprite_scale: float = BOSS_SCALE_MAP.get(folder, BASE_SPRITE_SCALE)
	if boss_pattern == "shield":
		sprite_scale = SHIELD_SCALE   # 1-1 = 거대 타워실드 '벽' 컨셉, 플레이스홀더라도 크게 읽히게
	anim_sprite.sprite_frames = _get_sprite_frames(folder)
	anim_sprite.scale = Vector2.ONE * sprite_scale
	_sprite_base_scale = anim_sprite.scale
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

	if vulnerable_timer > 0.0:
		vulnerable_timer -= delta

	if boss_pattern == "shield":
		_pattern_shield(delta)
	elif boss_type == "mid_boss":
		_pattern_intern(delta)
	else:
		_pattern_albaeng(delta)

	var castle_pos: Vector2 = game.get_node("Castle").global_position
	at_wall = _is_at_wall(castle_pos)  # 격노 게이트가 참조
	combat_engaged = at_wall or _blocking_minion  # 하인 타겟팅이 참조(벽에 닿거나 앞 하인에게 묶이면 교전 중)
	# 성 피해는 앞 하인이 없을 때만(_blocking_minion=false). 라인이 살아 있으면 보스는 거기 묶임.
	if _castle_wall_dist(castle_pos) <= castle_standoff and not is_charging_rage and not _blocking_minion:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			game.castle_take_damage(damage, global_position, true)
			if _anim_state not in ["hurt", "die"]:
				_update_facing((castle_pos - global_position).x)  # 공격 순간 성을 바라봄(돌진 잔여 방향 보정)
				_play_anim("slash")
	else:
		attack_timer = 0.0

	# 성벽 standoff 강제(키프아웃): 어떤 이유로든(하인 추격·밀림) 외벽에서 castle_standoff보다
	# 가까워지면 가장 가까운 변 바깥 standoff로 되민다. _approach_castle은 standoff에서 멈추지만
	# _engage_or_approach 하인 추격 분기엔 벽 제한이 없어 여기서 일괄 보장(발끝이 벽 안으로 못 들어감).
	_enforce_castle_standoff(castle_pos)

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
	_engage_or_approach(delta, castle_pos)

	# 격노는 성벽에 닿은 뒤에만 시작(타이머는 계속 누적 → 도달 즉시 발동). 멀리서 떠서 헛스윙 방지.
	rage_timer += delta
	if rage_timer >= rage_interval and _is_at_wall(castle_pos):
		rage_timer = 0.0
		var rage_line: String = RAGE_DIALOGUES.get(boss_name, "이건 진심이다.")
		_start_rage_charge(rage_line, Color(1.0, 0.6, 0.2))

# ============ 방패 성기사 패턴 (1-1) ============
# 고정 근접 벽. 소환·페이즈 없음. 와인드업(2s)만 DR 해제 취약창 → 그때 낙뢰=캔슬+치명타.
func _pattern_shield(delta: float) -> void:
	if is_charging_rage:
		_process_charge(delta)
		return

	var castle_pos: Vector2 = game.get_node("Castle").global_position
	_engage_or_approach(delta, castle_pos)

	# 와인드업은 교전 중에만(멀리서 헛스윙 방지) — 성벽 도달 or 앞 하인에게 막힘.
	# 하인이 보스를 벽 앞에서 붙들어도 와인드업이 떠야 교습 성립(강타는 막은 하인이 받음).
	if not _is_at_wall(castle_pos) and not _blocking_minion:
		return
	rage_timer += delta
	var interval: float = SHIELD_FIRST_WINDUP_DELAY if _first_windup else rage_interval
	if rage_timer >= interval:
		rage_timer = 0.0
		_first_windup = false
		var line: String = RAGE_DIALOGUES.get(boss_name, "막아주마.")
		_start_rage_charge(line, Color(1.0, 0.6, 0.2))

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
	if rage_timer >= interval and _is_at_wall(castle_pos):
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
	summon_interval = 10.0
	summon_count = 3
	summon_timer = summon_interval * 0.5

func _enter_phase3() -> void:
	phase3_triggered = true
	speed = base_speed * 3.0
	damage = base_damage * 3
	attack_cooldown = 0.5
	anim_sprite.modulate = COLOR_PHASE3
	summon_interval = 7.0
	summon_count = 3
	rage_timer = rage_interval * 0.5

# ============ 공통 액션 ============
func _start_rage_charge(dialogue: String, color: Color) -> void:
	is_charging_rage = true
	rage_charge_time = 0.0
	velocity = Vector2.ZERO
	if _anim_state not in ["hurt", "die"]:
		_play_anim("idle")
	if game and game.has_method("show_dialogue"):
		game.show_dialogue(dialogue, color, global_position + Vector2(0, -80))
	if boss_pattern == "shield":
		_begin_windup_telegraph()

func _process_charge(delta: float) -> void:
	rage_charge_time += delta
	velocity = Vector2.ZERO
	move_and_slide()
	var t: float = rage_charge_time / rage_charge_duration
	var pulse: float = (sin(rage_charge_time * 30.0) + 1.0) * 0.5
	anim_sprite.modulate = Color(1.0, 0.9 - pulse * 0.5, 0.1 + t * 0.3, 1)
	if is_instance_valid(_windup_marker):
		_windup_marker.value = t   # 카운트다운 게이지 진행도 갱신 (0→1, 차오를수록 임팩트 임박)
	if rage_charge_time >= rage_charge_duration:
		_execute_rage_attack()

func _execute_rage_attack() -> void:
	_end_windup_telegraph()   # 방패 외엔 no-op(_windup_marker null 검사)
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_modulate()
	if game:
		var castle_pos: Vector2 = game.get_node("Castle").global_position
		if _anim_state not in ["hurt", "die"]:
			_update_facing((castle_pos - global_position).x)  # 격노 일격도 성을 바라보며
			_play_anim("slash")                                # 격노 공격에 공격 모션 부여(기존엔 데미지만)
		# 앞 하인이 막고 있으면 격노 일격은 그 하인이 받아낸다(라인이 성 보호). 없을 때만 성 타격.
		# (멀리서 격노=헛스윙: 성벽 박스에 닿은 경우에만 성 피해)
		var rage_blocker = _find_nearby_minion(castle_pos)
		if is_instance_valid(rage_blocker):
			rage_blocker.take_damage(rage_damage)
		elif _castle_wall_dist(castle_pos) <= castle_standoff:
			game.castle_take_damage(rage_damage, global_position, true)

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

# ============ 방패 와인드업 텔레그래프 (방패 성기사 전용) ============
# "정지(이미)+커짐+글로우(_process_charge 펄스)+게이지" 4신호 → 작은 스프라이트라도 "지금 쳐라"가 읽힘.
# _windup_marker null = 방패 보스 아님 또는 비활성 → _end_*는 null 검사 후 no-op으로 다른 보스 무영향.
func _begin_windup_telegraph() -> void:
	# 기존 피격 팝 tween을 먼저 정리해 scale 충돌 방지
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	# 스케일 팝: 2초간 1.2배 유지(피격 팝과 달리 복귀 없음 — _end_*에서 base로)
	var pop: Tween = create_tween()
	pop.tween_property(anim_sprite, "scale", _sprite_base_scale * WINDUP_SCALE_MULT, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 머리 위 카운트다운 게이지 (차오를수록 임팩트 임박)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	# HP바와 동일한 offset 기반 배치 — HP바 바로 위, 상단 HUD 밴드에 안 가리는 안전대.
	# (position+size 방식은 안 보였음: 보스가 위쪽에 있을 때 -150이 HUD 뒤로 들어감 + Control 렌더 불안정)
	bar.offset_left = -55.0
	bar.offset_right = 55.0
	bar.offset_top = -70.0
	bar.offset_bottom = -56.0
	# 어두운 배경 + 검은 테두리 + 밝은(위험) 채움 — 가독성
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.88)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.9)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.75, 0.1, 1.0)   # 노랑 (낙뢰 신호색과 호응 — "낙뢰로 끊어라" 단서)
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	add_child(bar)
	_windup_marker = bar
	# 교습 진행 중이면 게이지 옆 힌트 레이블 + 낙뢰 버튼 스포트라이트
	if game and game.has_method("is_teaching_interrupt") and game.is_teaching_interrupt():
		_spawn_windup_teach_label()
		game.on_boss_windup_started()

func _end_windup_telegraph() -> void:
	if not is_instance_valid(_windup_marker):
		return
	_windup_marker.queue_free()
	_windup_marker = null
	# 교습 힌트 레이블 정리
	if is_instance_valid(_teach_label):
		_teach_label.queue_free()
	_teach_label = null
	# 스케일을 base로 복귀
	var back: Tween = create_tween()
	back.tween_property(anim_sprite, "scale", _sprite_base_scale, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ============ 와인드업 중단 / 스턴 ============
func interrupt_windup() -> void:
	if not is_charging_rage:
		return
	_end_windup_telegraph()   # 방패 외엔 no-op(_windup_marker null 검사)
	is_charging_rage = false
	rage_charge_time = 0.0
	_restore_phase_modulate()
	_spawn_cancel_mark()
	apply_stun(1.5)
	# 교습 성공 훅 — Game이 미학습 게이트로 1회만 처리. 비-방패 보스는 _end_windup_telegraph가 null → 이미 early-return
	if game and game.has_method("on_boss_interrupt_taught"):
		game.on_boss_interrupt_taught()

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

## 와인드업 교습 힌트 레이블 — 게이지 상단에 "낙뢰로 내리쳐라!" 텍스트 띄움.
## _spawn_cancel_mark()와 동일한 방식(Label을 보스 직속 자식으로 추가).
## 소멸은 _end_windup_telegraph()에서 _teach_label.queue_free()로 처리.
func _spawn_windup_teach_label() -> void:
	var lbl: Label = Label.new()
	lbl.text = Loc.t("windup_teach_hint")
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3, 1.0))   # 노랑 — 게이지 색과 호응
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	# 게이지(offset_top=-70)보다 약 24px 위에 배치해 겹침 없이 가독
	lbl.position = Vector2(-65.0, -95.0)
	add_child(lbl)
	_teach_label = lbl

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
	# 방패 DR: 받는 피해 절반. 단 (1) 와인드업 중(is_charging_rage=취약창)엔 해제,
	# (2) 낙뢰 와인드업 치명타("crit" tier)는 캔슬이 is_charging_rage를 먼저 끄고 들어오지만
	#     정의상 와인드업을 잡은 풀딜이므로 DR을 통과시킨다.
	if shield_dr and not is_charging_rage and tier != "crit":
		dmg *= 0.5
	if vulnerable_timer > 0.0 and game:
		dmg *= (1.0 + game.vulnerability_amount)
	hp -= dmg
	var new_hp_value: float = (hp / max_hp) * 100.0
	hp_bar.value = new_hp_value
	_animate_ghost_trail(new_hp_value)
	_hit_flash()
	if game:
		game.spawn_damage_number(global_position, dmg, tier)
	if hp <= 0:
		_die()
		return
	# 피격 시 hurt 애니 미재생 — 공격·이동 모션을 끊어 어색했고, 빨강 플래시(_hit_flash)만으로
	# 타격 피드백. 보스는 자기 행동(성 공격·접근) 유지한 채 번쩍이기만 함(잡몹과 동일 방식).

func _animate_ghost_trail(target_value: float) -> void:
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	_ghost_tween.tween_interval(0.1)
	_ghost_tween.tween_property(hp_ghost, "value", target_value, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hit_flash() -> void:
	if is_charging_rage:
		return
	anim_sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)
	# 약한 scale 팝(1.05) — 거구라 잡몹 배율(1.18)은 출렁임이 과해 톤만 살짝.
	# 연속 피격 시 직전 tween을 죽여 scale 누적·떨림 방지(base에서 다시 시작).
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	anim_sprite.scale = _sprite_base_scale * 1.05
	_hit_tween = create_tween()
	_hit_tween.tween_property(anim_sprite, "scale", _sprite_base_scale, 0.13) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t: SceneTreeTimer = get_tree().create_timer(0.1)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_charging_rage:
			_restore_phase_modulate()
	)

func _update_facing(dx: float) -> void:
	# dx가 데드존 안이면 직전 방향 유지 — 중앙 정렬 시 flip_h 깜빡임(쪼개짐) 방지
	if absf(dx) > FLIP_DEADZONE:
		anim_sprite.flip_h = dx < 0

# 길목 교전: 앞을 막은 근접 하인이 있으면 계속 그 하인과 싸우고, 감지 범위에 하인이 없을 때만
# 성으로 접근·공격(일반 적과 동일 — 라인이 살아 있으면 보스가 거기 묶인다). 궁수는 _find_nearby_minion이 제외.
func _engage_or_approach(delta: float, castle_pos: Vector2) -> void:
	var minion = _find_nearby_minion(castle_pos)
	_blocking_minion = is_instance_valid(minion)  # 라인이 성 보호 — 성 피해 게이트(_physics_process·격노)가 참조
	if not is_instance_valid(minion):
		minion_attack_timer = 0.0
		_approach_castle(castle_pos)
		return

	var target_pos: Vector2 = minion.global_position
	var dist: float = _engage_origin().distance_to(target_pos)  # 발끝 기준 — 거구 보스 중심은 발끝보다 위라 중심 기준이면 사거리에 영영 못 듦
	if dist <= MINION_ATTACK_RANGE:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_bounds()  # 정지 교전 중 하인 밀림으로 화면 밖 드리프트 방지
		minion_attack_timer += delta
		if minion_attack_timer >= attack_cooldown:
			minion_attack_timer = 0.0
			minion.take_damage(damage)
			if _anim_state not in ["hurt", "die"]:
				_update_facing((target_pos - global_position).x)  # 때리는 하인을 바라봄
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

# 보스가 실제로 싸우는 지점(발끝=교전선). 거구 보스는 중심이 발끝보다 한참 위라(BODY_BOTTOM_OFFSET*scale),
# 하인 감지·교전 사거리를 중심에서 재면 발끝을 둘러싼 벽 앞 하인을 놓쳐 성을 때린다 → 발끝 기준으로 잰다.
func _engage_origin() -> Vector2:
	return global_position + Vector2(0.0, BODY_BOTTOM_OFFSET * _sprite_base_scale.x)

# 길목 하인 탐색 — minions 그룹에서 발끝(교전선)에 가장 가까운 근접 하인. 궁수(ranged)는 어그로 제외(Enemy.gd와 동일).
# 발끝보다 더 깊이(남쪽) 들어간 하인만 제외 — 벽 뒤 못 닿는 하인 추격 지터 방지(그땐 성을 때림).
# (옛 CASTLE_HALF 박스 제외는 발끝이 박스 안까지 파고드는 거구 보스에서 벽 앞 방어 하인까지 통째로 빼 성 피해 유발)
func _find_nearby_minion(castle_pos: Vector2):
	var origin: Vector2 = _engage_origin()
	var feet_rel_y: float = origin.y - castle_pos.y  # 발끝의 성 기준 y = 보스가 닿는 가장 깊은 지점
	var nearest = null
	var nearest_dist: float = INF
	for m in get_tree().get_nodes_in_group("minions"):
		if not is_instance_valid(m):
			continue
		if m.get("behavior") == "ranged":
			continue
		var mrel: Vector2 = m.global_position - castle_pos
		if mrel.y > feet_rel_y and absf(mrel.x) < CASTLE_HALF:
			continue
		var d: float = origin.distance_to(m.global_position)
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

# 성벽에 닿았는지(standoff 안). 격노 시작 게이트 — 멀리서 충전 시작하면 떠서 헛스윙.
func _is_at_wall(castle_pos: Vector2) -> bool:
	return _castle_wall_dist(castle_pos) <= castle_standoff

# 외벽 박스에서 castle_standoff보다 가까우면 가장 가까운 변 바깥 standoff 거리로 밀어낸다.
# 부호거리(박스→점) 기반이라 대각선 접근도 처리. 박스 안(d=0)이면 가장 가까운 변으로 사출.
func _enforce_castle_standoff(castle_pos: Vector2) -> void:
	var rel: Vector2 = global_position - castle_pos
	var cx: float = clampf(rel.x, -CASTLE_HALF, CASTLE_HALF)
	var cy: float = clampf(rel.y, -CASTLE_HALF, CASTLE_HALF)
	var nx: float = rel.x - cx
	var ny: float = rel.y - cy
	var d: float = sqrt(nx * nx + ny * ny)
	if d >= castle_standoff:
		return
	if d > 0.01:
		var s: float = castle_standoff / d
		global_position = castle_pos + Vector2(cx + nx * s, cy + ny * s)
	else:
		# 완전히 박스 안: 가장 가까운 변 바깥 standoff로
		var dist_top: float = rel.y + CASTLE_HALF
		var dist_bot: float = CASTLE_HALF - rel.y
		var dist_left: float = rel.x + CASTLE_HALF
		var dist_right: float = CASTLE_HALF - rel.x
		var m: float = min(min(dist_top, dist_bot), min(dist_left, dist_right))
		if m == dist_top:
			global_position.y = castle_pos.y - CASTLE_HALF - castle_standoff
		elif m == dist_bot:
			global_position.y = castle_pos.y + CASTLE_HALF + castle_standoff
		elif m == dist_left:
			global_position.x = castle_pos.x - CASTLE_HALF - castle_standoff
		else:
			global_position.x = castle_pos.x + CASTLE_HALF + castle_standoff

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

func apply_vulnerable(duration: float) -> void:
	vulnerable_timer = duration
	anim_sprite.modulate = Color(1.5, 0.45, 1.6, 1.0)  # 취약 자주/보라 — Enemy.gd VULN_TINT와 일치
	var t: SceneTreeTimer = get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_charging_rage:
			_restore_phase_modulate()
	)

func _die() -> void:
	if _ghost_tween:
		_ghost_tween.kill()
		_ghost_tween = null
	hp_ghost.value = 0.0
	_play_anim("die")
	if game:
		game.spawn_death_effect(global_position, Color.WHITE)
		game.add_souls(randi_range(100, 200))
		var shards: int = WaveData.get_wave(game.current_chapter, game.current_stage, game.current_wave).get("crown_shards", 0)
		game.earn_crown_shards(shards)
		game.on_boss_killed(global_position, shards, boss_type == "boss")
		game.enemy_died()
