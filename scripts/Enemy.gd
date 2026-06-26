extends CharacterBody2D

const ArrowScene = preload("res://scenes/Arrow.tscn")
const RangeIndicatorScript = preload("res://scripts/RangeIndicator.gd")
const VulnIconScript = preload("res://scripts/VulnIcon.gd")

const TYPE_PRESETS: Dictionary = {
	"normal": {"hp_mult": 1.0, "speed_mult": 1.0, "damage_mult": 1.0, "scale": 1.0,
		"folder": "enemy_normal", "attack_anim": "Slashing",
		"cooldown": 1.5, "castle_range": 2.0, "ignore_minions": false, "ranged": false},
	# 사수=글래스 캐논(2026-06-23 튜닝): 무시하면 성을 아프게 깎되 궁수가 시원하게 지움.
	# hp 0.5→0.38(물몸·궁수 처치↑) · dmg 0.6→0.9(한 방 무게↑). 위협치 플테 노브.
	"scout":  {"hp_mult": 0.38, "speed_mult": 1.0, "damage_mult": 0.9, "scale": 0.8,
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

const HP_BAR_SHOW_RATIO: float = 0.5  # HP가 이 비율 미만일 때만 HP바 표시 (빈사·처치우선 신호). 튜닝 노브.
const BASE_HP: float = 50.0
const BASE_SPEED: float = 60.0
const BASE_DAMAGE: int = 10
const BASE_SPRITE_SCALE: float = 0.32  # 0.246 × 1.3 (성 1.8배 확대에 맞춘 캐릭터 비주얼 확대)
const MINION_ENGAGE_RANGE: float = 100.0
const KNOCKBACK_DECAY: float = 700.0
const CASTLE_HALF: float = 169.2  # 외벽+코너타워 외곽 (CastleSprite S+T=94 × Castle 노드 scale 1.8)
const BODY_FEET_OFFSET: float = 80.0  # 성벽 정지·범위원 중심 앵커(소스px 900프레임 중심 기준, *scale.y로 화면 px). 80=근접 발끝이 가운데 윗벽(커튼월)에 닿음. 값↓=더 아래로(겹침↑)·값↑=더 위. 플테 노브.
# 적 활동 범위 — 화면 480×960 세로. 상한=스폰선(HUD ~y142 아래), 하한=성 아래 여유.
# 나팔 넉백이 적을 화면 밖으로 날려보내 "안 보이는 적이 성을 때리는" 버그 방지.
const PLAY_BOUNDS: Rect2 = Rect2(0.0, 150.0, 480.0, 750.0)  # x:0~480, y:150~900
const MAX_KNOCKBACK: float = 600.0  # 넉백 속도 상한 (px/s) — 나팔 연타 누적 폭주 방지
# 넉백 전용 천장 — 스폰선(y150)·HP바(하단 y142)보다 아래에 둬 밀려난 적이 HUD에 붙지 않게.
# 스폰 클램프(PLAY_BOUNDS y150)와 별개: 등장 위치는 그대로, *밀려난* 적만 여기서 멈춘다. 노브.
const KNOCKBACK_CEILING_Y: float = 185.0
const HIT_TINT:  Color = Color(1.5, 0.4, 0.4, 1.0)    # 피격 순간 플래시(빨강)
const SLOW_TINT: Color = Color(0.5, 0.5, 1.5, 1.0)    # 둔화(파랑)
const VULN_TINT: Color = Color(1.5, 0.45, 1.6, 1.0)   # 취약(자주/보라) — 마법 축 색, 피격 빨강과 구별
const STUN_TINT: Color = Color(0.45, 1.25, 1.95, 1.0) # 제압(stun) 전용 틴트 — 둔화 파랑(0.5,0.5,1.5)보다 훨씬 밝고 시안

static var _cached_frames: Dictionary = {}

var hp: float = 50.0
var max_hp: float = 50.0
var incoming_damage: float = 0.0  # 전사 anti-overkill: 이 적에 예약된 전사 피해 합(SkeletonWarrior가 가감)
var speed: float = 60.0
var base_speed: float = 60.0
var damage: int = 10
var attack_cooldown: float = 1.5
var attack_timer: float = 0.0
var slow_timer: float = 0.0
var vulnerable_timer: float = 0.0
var stun_timer: float = 0.0
var _flash_timer: float = 0.0  # 피격 플래시 지속 카운트다운 (중앙 틴트 계산용)
var knockback_vel: Vector2 = Vector2.ZERO
var knockback_resist: float = 1.0  # 질량 대용(hp_mult). 클수록 덜 밀림
var _sprite_base_scale: Vector2 = Vector2.ONE
var _foot_offset: float = 0.0  # = BODY_FEET_OFFSET * 스프라이트 scale.y (원점→발끝 화면 px)
var enemy_type: String = "normal"
var castle_attack_range: float = 2.0
var ignore_minions: bool = false
var is_ranged: bool = false
var engaging_minion: bool = false  # 하인과 근접 교전 중(사거리 안) — 아군 타게팅이 ACQUIRE_TOP 무관히 포착하게 하는 신호(보스 combat_engaged의 일반 적 버전)
var _attack_anim: String = "slash"
var _anim_state: String = ""
var _last_valid_pos: Vector2 = Vector2.ZERO  # move_and_slide NaN 복구용 (겹친 바디 충돌 해소 가드)
var _is_execute: bool = false  # 처형 경로 플래그 — _die()에서 일반 death effect 스킵용

var game = null
var _vuln_icon: Node2D = null

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
	_foot_offset = BODY_FEET_OFFSET * anim_sprite.scale.y
	anim_sprite.animation_finished.connect(_on_animation_finished)
	# 공격 범위 표시(표시 전용): 일반 적 = 파랑 원(보스 타입은 빨강, Boss.gd). 원거리(scout)만 표시(근접은 원 수프 방지).
	if is_ranged:
		var indicator := RangeIndicatorScript.new()
		add_child(indicator)
		# 범위원 중심 = 발끝(_foot_offset) = 공격 판정 기준점. 원이 성에 닿을 때 실제로 공격 들어가도록 일치.
		indicator.setup(castle_attack_range, Color(0.3, 0.6, 1.0), _foot_offset)
	# 취약 상태 아이콘: HP바(offset_top=-50) 위 -64 에 배치. 평소 숨김, visible만 토글.
	_vuln_icon = VulnIconScript.new()
	add_child(_vuln_icon)
	_vuln_icon.setup(-64.0)
	_vuln_icon.visible = false
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
	# 제압(stun) 중에도 넉백은 계속 적용 — 설계: 나팔에 밀린 뒤 그 자리에 멈춤.
	# stun이 막는 건 자력 이동(걷기)과 공격이지 넉백 물리가 아님.
	if knockback_vel.length_squared() > 1.0:
		global_position += knockback_vel * delta
		knockback_vel = knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		# 상방 넉백은 스폰선보다 아래(KNOCKBACK_CEILING_Y)에서 멈춘다 — HP바 아래 여백 확보.
		# 천장에 닿으면 위쪽 속도를 죽여 벽에 갈리지 않고 부드럽게 정지(딱딱한 클램프 제거).
		if knockback_vel.y < 0.0 and global_position.y < KNOCKBACK_CEILING_Y:
			global_position.y = KNOCKBACK_CEILING_Y
			knockback_vel.y = 0.0

	# 상태 타이머 감소
	if _flash_timer > 0.0:
		_flash_timer -= delta
	if stun_timer > 0.0:
		stun_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
		speed = base_speed * 0.4
	else:
		speed = base_speed
	if vulnerable_timer > 0.0:
		vulnerable_timer -= delta

	# 상태 틴트 중앙 계산 — 우선순위: 피격(순간) > 제압 > 취약 > 둔화 > 없음
	# 넉백 처리 뒤·stun 이동 게이트 전에 두어 정지 중인 적도 갱신됨.
	var tint: Color = Color.WHITE
	if _flash_timer > 0.0:
		tint = HIT_TINT
	elif stun_timer > 0.0:
		tint = STUN_TINT
	elif vulnerable_timer > 0.0:
		tint = VULN_TINT
	elif slow_timer > 0.0:
		tint = SLOW_TINT
	anim_sprite.modulate = tint
	# 취약 아이콘: 취약 상태이고 살아 있을 때만 표시
	if is_instance_valid(_vuln_icon):
		_vuln_icon.visible = vulnerable_timer > 0.0

	# 제압 중: 자력 이동·공격만 차단 (넉백은 위에서 이미 처리됨).
	# ⚠️ early return 금지 — 여기서 빠져나가면 아래 경계 클램프/성벽 키프아웃을 건너뛴다.
	# 나팔은 넉백과 제압(stun)을 함께 걸기 때문에, return하면 stun 동안 넉백이 적을
	# 상단 HP바 밖으로 무제한 날려보낸 뒤, stun 해제 프레임에 클램프가 작동해 적이
	# "HP바 아래로 순간이동"하는 버그가 난다. 정지 시엔 이동·타게팅만 건너뛴다.
	if stun_timer > 0.0:
		velocity = Vector2.ZERO
	else:
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
			# 사수(ranged): 하인 타겟이어도 자기 사격 반경 유지(standoff 거리에서 저격, 50까지 붙지 않음)
			# 근접적: 기존대로 50 근접 교전 유지
			attack_range = (castle_attack_range if is_ranged else 50.0) if is_instance_valid(minion_target) else castle_attack_range
		else:
			# 성벽 판정은 발끝 기준(원점 아님) — 몸이 성에 안 잠기고 발끝=타워 윗선 정렬.
			var feet: Vector2 = global_position + Vector2(0.0, _foot_offset)
			var rel: Vector2 = feet - target_pos
			var dx: float = max(0.0, absf(rel.x) - CASTLE_HALF)
			var dy: float = max(0.0, absf(rel.y) - CASTLE_HALF)
			dist = sqrt(dx * dx + dy * dy)
			attack_range = castle_attack_range
		# 하인과 근접 교전(사거리 안) 중이면 아군이 위치 무관히 이 적을 포착해야 한다(forward_limit 위 사각지대 교착 방지).
		engaging_minion = is_instance_valid(minion_target) and dist < attack_range
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
		# 발끝(원점 + _foot_offset)을 성벽 박스 밖으로 — 북쪽 접근 시 발끝=타워 윗선, 몸은 그 위.
		var fx: float = global_position.x
		var fy: float = global_position.y + _foot_offset
		if fx > wl and fx < wr and fy > wt and fy < wb:
			var d_top: float = fy - wt
			var d_bot: float = wb - fy
			var d_left: float = fx - wl
			var d_right: float = wr - fx
			var m: float = min(min(d_top, d_bot), min(d_left, d_right))
			if m == d_top:
				global_position.y = wt - _foot_offset
			elif m == d_bot:
				global_position.y = wb - _foot_offset
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
				var arrow: Node = _shoot_arrow(contact)
				# 데미지·이펙트는 화살 착탄 순간에 발동 (공중 즉시 발동 버그 수정).
				# 발사 시점의 damage·위치·game을 지역변수로 캡처해 람다에 넘김.
				# game을 멤버가 아닌 지역으로 캡처해야 함 — 착탄 전 사수가 죽어 free되면
				# 멤버 참조(game)가 해제된 인스턴스를 타 "Bad address index"가 남.
				var dmg: int = damage
				var from: Vector2 = global_position
				var g: Node = game
				arrow.arrival_callback = func() -> void:
					if is_instance_valid(g):
						g.castle_take_damage(dmg, from)
		else:
			# 근접 적: 기존대로 즉시 데미지 발동.
			game.castle_take_damage(damage, global_position)

## 원거리 적(사수): 대상 방향으로 시각용 화살 발사. 실제 피해는 take_damage/castle_take_damage가 처리(화살 damage=0).
## 성 타격 시 arrival_callback을 설정하면 착탄 순간에 데미지·이펙트를 발동할 수 있음.
func _shoot_arrow(target_pos: Vector2) -> Node:
	var arrow = ArrowScene.instantiate()
	arrow.position = global_position
	arrow.direction = (target_pos - global_position).normalized()
	arrow.damage = 0.0
	arrow.source = self
	arrow.max_distance = global_position.distance_to(target_pos)  # 대상 지점에서 멈춤(통과 방지)
	game.add_child(arrow)
	arrow.monitoring = false  # 시각용 — 충돌/피해 없음 (자기·아군 적 오적중 방지, "-0" 버그)
	return arrow

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
		# 사수(ranged): 자기 사격 반경(castle_attack_range) 안 하인 우선 저격 — standoff 거리에서 탐지
		# 근접 적: 기존 MINION_ENGAGE_RANGE(100) 유지
		var engage: float = castle_attack_range if is_ranged else MINION_ENGAGE_RANGE
		if d < engage and d < nearest_dist:
			nearest_dist = d
			nearest = m
	return nearest

func take_damage(dmg: float) -> void:
	if _anim_state == "die":
		return
	if vulnerable_timer > 0.0 and game:
		dmg *= (1.0 + game.vulnerability_amount)
	hp -= dmg
	hp_bar.value = (hp / max_hp) * 100.0
	hp_bar.visible = (hp / max_hp) < HP_BAR_SHOW_RATIO
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
	# modulate는 _physics_process 중앙 계산이 담당. 스케일 팝 tween만 처리.
	_flash_timer = 0.1
	anim_sprite.scale = _sprite_base_scale * 1.18
	var tw: Tween = create_tween()
	tw.tween_property(anim_sprite, "scale", _sprite_base_scale, 0.13) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func apply_slow(duration: float) -> void:
	# modulate·SceneTreeTimer 제거 — _physics_process 중앙 틴트 계산이 담당.
	slow_timer = duration

func apply_vulnerable(duration: float) -> void:
	# modulate·SceneTreeTimer 제거 — _physics_process 중앙 틴트 계산이 담당.
	vulnerable_timer = duration

func apply_stun(duration: float) -> void:
	# modulate는 _physics_process 중앙 계산이 담당.
	stun_timer = duration

## 처형용 즉시 사망 — 소울·골드·enemy_died 정상 발동. 이미 사망 중이면 무시.
## 연출: 흰금 섬광 → scale implode(~0.1s) → ExecuteEffect 스폰 → _die() 직결.
## 일반 피격(빨강 팝)과 확연히 구별. _die()의 일반 death effect는 플래그로 스킵.
func execute_kill() -> void:
	if _anim_state == "die":
		return
	_is_execute = true  # _die()에서 일반 death effect 스킵하도록 마킹
	# 처형 폭발 이펙트 — *즉시* 스폰(implode tween과 독립, 항상 표시).
	# 부모(월드 레이어)에 추가해 액터가 _die()로 사라져도 잔류.
	var fx: Node2D = preload("res://scripts/ExecuteEffect.gd").new()
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.z_index = 10  # 잡몹 위로
	# 처형 전용 섬광: 빨강-흰(밝기 2.0 초과) 순간 점등 + scale implode → _die
	anim_sprite.modulate = Color(2.6, 0.8, 0.7, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(anim_sprite, "scale", Vector2.ZERO, 0.10) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_callback(_die)

func _die() -> void:
	# 사망 = 별도 death effect로 연출(보스와 일관). Dying 애니 미사용 — 스프라이트 즉시 숨기고 정리.
	# _anim_state="die"는 가드용(같은 프레임 연쇄피해의 중복 _die·이동 차단). queue_free는 프레임 끝 처리.
	_anim_state = "die"
	if is_instance_valid(anim_sprite):
		anim_sprite.visible = false
	if game:
		# 처형 경로: ExecuteEffect가 이미 스폰됐으므로 일반 death effect 스킵
		if not _is_execute:
			game.spawn_death_effect(global_position, Color.WHITE)
		game.add_souls(randi_range(12, 20))
		game.enemy_died()
	queue_free()
