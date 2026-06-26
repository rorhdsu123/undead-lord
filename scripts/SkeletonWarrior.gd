extends CharacterBody2D

const ArrowScene = preload("res://scenes/Arrow.tscn")

const TYPE_PRESETS: Dictionary = {
	"warrior": {
		"hp": 100, "speed": 105, "damage": 10, "range": 30, "interval": 1.0,
		"scale": 1.0, "behavior": "melee", "variant": 1,
	},
	"archer": {
		"hp": 60, "speed": 90, "damage": 8, "range": 260, "interval": 1.2,
		"scale": 0.85, "behavior": "ranged", "variant": 2,
	},
	"tank": {
		"hp": 250, "speed": 65, "damage": 14, "range": 30, "interval": 1.3,
		"scale": 1.45, "behavior": "melee", "variant": 3,
	},
	"bomber": {
		"hp": 50, "speed": 125, "damage": 60, "range": 25, "interval": 999.0,
		"scale": 0.85, "behavior": "bomber", "variant": 1,
	},
}

const BOMB_RADIUS: float = 80.0
# 아군 궁수 화살 속도(px/s). Arrow 기본 420(=적 사수, 텔레그래프용)보다 빠른 직선 볼트로
# "쏜 게 꽂힌다"는 손맛·이동 표적 추적 오차↓. 진영 차별화 위해 인스턴스 단위로 덮어씀. 플테 노브(600~1000).
const ARCHER_ARROW_SPEED: float = 800.0
const BASE_SPRITE_SCALE: float = 0.246      # 측정 실패 시 폴백 배율
const TARGET_CONTENT_PX: float = 85.0       # base_scale 1.0 기준 화면 콘텐츠 높이 (에셋 여백 무관 정규화)
# 역할별 목표 높이 오버라이드 (실루엣 질량이 달라 bbox 높이만으론 안 맞는 경우 미세조정).
const TYPE_TARGET_PX: Dictionary = {
	"warrior": 71.5,   # 다부진 공룡 체형 (55 × 1.3, 성 확대 맞춤)
	"archer": 81.9,    # 박쥐 (63 × 1.3)
	"tank": 49.4,      # 슬라임 (38 × 1.3, ×base_scale 1.45 = ~72px)
}
const BOUNDS: Rect2 = Rect2(0, -230, 480, 930)  # x:0~480(화면 폭). 보스 추격 시 화면 밖 이탈 방지
const HIT_FLASH: Color = Color(2.2, 2.2, 2.2, 1.0)  # 피격 순간 흰 플래시(적의 빨강 HIT_TINT와 구분·아군 임팩트). 밝기 노브
const HIT_POP_SCALE: float = 1.10                   # 피격 스케일 팝 배율(적 1.18보다 절제). 노브

# ── 수비 밴드 상수 (RD13) ─ 실제 성 노드 기준 정렬 (성 1.8배 확대 대응) ──────
# 성 노드 = Game.tscn (240, 570). 적은 y<0 스폰, 아래(+y)로 하강해 윗벽서 멈춤.
# 적은 윗벽(CASTLE_TOP_WALL) 바깥에서 정지하고 origin은 발끝보다 위라 y≈364~384에 선다.
# 밴드/전진상한은 이 적 정지선을 포함하도록 윗벽 기준으로 잡는다.
const CASTLE_POS: Vector2 = Vector2(240.0, 570.0)   # 실제 성 위치(Game.tscn). 성 1.8배 확대로 바닥이 하단 UI와 겹쳐 620→570 상향
const CASTLE_HALF: float = 169.2                     # Enemy/Boss CASTLE_HALF와 동일(성 scale 1.8). ⚠️성 크기 바꾸면 같이 수정
const CASTLE_TOP_WALL: float = CASTLE_POS.y - CASTLE_HALF   # = 400.8, 적이 멈추는 윗벽 라인
const BAND_TOP: float = CASTLE_TOP_WALL - 50.0      # = 350.8. 적 정지 origin(~364~384)을 밴드에 포함
# 역할별 대기 y 위치 (성 윗벽 안쪽 상단에 포진)
const WAIT_Y_TANK: float    = CASTLE_POS.y - 160.0  # 최전방 (= 410, 윗벽 바로 안쪽)
const WAIT_Y_WARRIOR: float = CASTLE_POS.y - 110.0  # 중간    (= 460)
const WAIT_Y_ARCHER: float  = CASTLE_POS.y - 60.0   # 후방    (= 510)
# 역할별 대기 x (겹침 방지용 분산)
const WAIT_X_OFFSETS: Dictionary = {
	"tank":    [200.0, 280.0],
	"warrior": [160.0, 240.0, 320.0],
	"archer":  [180.0, 260.0],
}
# leash: 타겟이 밴드 밖으로 이 거리 이상 나가면 추격 포기
const LEASH_MARGIN: float = 40.0   # 밴드 상한에서 위로 얼마나 나가면 포기
const ACQUIRE_TOP: float = BAND_TOP - LEASH_MARGIN   # 획득선=leash 포기선과 일치(경계 깜빡임 제거)
const RETREAT_GRACE: float = 1.5   # 필드에 적 0인 채 이 시간 지나야 대형으로 복귀
const SPAWN_BELOW_WAIT: float = 40.0  # 스폰 시 정착선보다 이만큼 아래(짧게 한 발 올라서며 대형 합류, B안)
const RETARGET_INTERVAL: float = 0.5  # 근접 유닛 타겟 재평가 주기 (초)
const OVERKILL_CLAIM_MULT: float = 1.0  # 전사 1명이 예약하는 피해 = attack_damage × 이 값. 잡몹당 붙는 전사 수 튜닝 노브(플테)
# 역할별 전진 상한(최대 전진 = 최소 y). 작을수록 더 앞(적 쪽). 탱크를 최전방으로, 전사를 그 바로 뒤로.
# ⚠️탱크가 전사보다 앞이어야 보스가 '가장 가까운 하인'으로 물몸 전사 대신 탱크를 집중한다(역전 시 전사 학살).
# (실측값: CASTLE_TOP_WALL=400.8 → 탱크 정지선 ~380.8, 전사 정지선 ~400.8. 정지=상한+공격사거리30)
const FORWARD_LIMIT_TANK: float = CASTLE_TOP_WALL - 50.0     # 350.8, 탱크 최전방 (보스를 직접 막는 라인)
const FORWARD_LIMIT_WARRIOR: float = CASTLE_TOP_WALL - 30.0  # 370.8, 전사는 탱크 ~20px 뒤 (근접타는 거리 무관히 적중)

# ── 분리 스티어링 — 아군끼리 겹쳐 한 덩어리로 보이는 문제 완화(약한 밀어내기) ──
# 충돌 물리 대신 가벼운 밀어내기: 라인 정렬은 유지하면서 겹침만 푼다. move_speed보다 작게(접근·복귀 우선).
const SEPARATION_RADIUS: float = 30.0     # 이 거리 안의 아군에게서 밀려남
const SEPARATION_STRENGTH: float = 45.0   # 밀어내기 속도(px/s) — 에디터 플테 노브

# 정적 단일 이미지 오버라이드 (풀 애니 미입고 역할 — 전 동작이 한 컷으로 표시).
# 추후 같은 폴더에 0_[Role]_[Motion]_###.png 프레임 입고 시 여기서 제거하고 프레임 로더로 전환.
const STATIC_SPRITES: Dictionary = {
	"warrior": "res://assets/characters/Warrior/Warrior.png",
	"archer": "res://assets/characters/Archer/Archer.png",
	"tank": "res://assets/characters/Tank/Tank.png",
}

static var _cached_frames: Dictionary = {}  # minion_type → SpriteFrames
static var _cached_fit: Dictionary = {}     # minion_type → 자동맞춤 배율 (base_scale 1.0 기준)

var minion_type: String = "warrior"
var hp: float = 100.0
var max_hp: float = 100.0
var attack_damage: float = 10.0
var base_damage: float = 10.0       # 프리셋 기준 공격력 (카드보너스·강화 재계산 기준)
var move_speed: float = 90.0
var attack_range: float = 30.0
var attack_interval: float = 1.0
var behavior: String = "melee"
var base_max_hp: float = 100.0      # 프리셋 기준 최대 HP (강화 재계산 기준)
var base_scale: float = 1.0
var sprite_base_scale: float = BASE_SPRITE_SCALE  # 자동맞춤×base_scale, _ready에서 확정

var level: int = 1                  # 종류별 글로벌 강화 레벨 (RD16)
var attack_timer: float = 0.0
var retarget_timer: float = 0.0
var attack_phase: float = 0.0   # 같은 종 일제 타격 방지용 위상 오프셋(_ready에서 randf)
var no_enemy_timer: float = 0.0
var current_target = null
var _claimed = null            # 전사 anti-overkill: 현재 incoming_damage를 예약해 둔 적
var _claim_amount: float = 0.0 # 예약해 둔 양(해제 시 정확히 차감하려고 보관)
var game = null
var _anim_state: String = ""
var lifesteal: float = 0.0
var _died_reported: bool = false
var _flash_tween: Tween  # 피격 플래시 tween 참조(연속 피격 시 중첩 가드)

@onready var anim_sprite: AnimatedSprite2D = $AnimSprite

func _ready() -> void:
	add_to_group("minions")
	collision_layer = 2
	collision_mask = 0
	var preset: Dictionary = TYPE_PRESETS.get(minion_type, TYPE_PRESETS["warrior"])
	hp = preset["hp"]
	max_hp = preset["hp"]
	base_max_hp = max_hp
	attack_damage = preset["damage"]
	base_damage = attack_damage
	move_speed = preset["speed"]
	attack_range = preset["range"]
	attack_interval = preset["interval"]
	attack_phase = randf()
	attack_timer = attack_phase * attack_interval
	behavior = preset["behavior"]
	base_scale = preset["scale"]

	anim_sprite.sprite_frames = _get_sprite_frames(minion_type, preset["variant"])
	sprite_base_scale = _get_fit_scale(minion_type, anim_sprite.sprite_frames) * base_scale
	anim_sprite.scale = Vector2.ONE * sprite_base_scale
	anim_sprite.animation_finished.connect(_on_animation_finished)
	_play_anim("idle")
	# 소환 등장(materialize): 발치 마법진 위로 솟아나듯 — 절제된 페이드 + 약한 스케일(팝 아님).
	# _flash_tween 공유 — 등장 중 피격 시 _hit_flash가 kill하고 피격 팝으로 인계.
	var spawn_base: Vector2 = Vector2.ONE * sprite_base_scale
	anim_sprite.scale = spawn_base * 0.85
	anim_sprite.modulate.a = 0.0
	_flash_tween = create_tween()
	_flash_tween.parallel().tween_property(anim_sprite, "scale", spawn_base, 0.26) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.parallel().tween_property(anim_sprite, "modulate:a", 1.0, 0.22)

static func _get_sprite_frames(type: String, variant: int) -> SpriteFrames:
	if type in _cached_frames:
		return _cached_frames[type]
	var sf: SpriteFrames
	if type in STATIC_SPRITES:
		sf = _build_static_frames(STATIC_SPRITES[type])
	else:
		sf = _build_sprite_frames(variant)
	_cached_frames[type] = sf
	return sf

# idle 첫 프레임의 불투명 영역 높이를 재서 TARGET_CONTENT_PX에 맞추는 배율 (여백 무관 정규화).
static func _get_fit_scale(type: String, sf: SpriteFrames) -> float:
	if type in _cached_fit:
		return _cached_fit[type]
	var fit: float = BASE_SPRITE_SCALE  # 측정 실패 시 폴백
	var target: float = TYPE_TARGET_PX.get(type, TARGET_CONTENT_PX)
	if sf.has_animation("idle") and sf.get_frame_count("idle") > 0:
		var tex: Texture2D = sf.get_frame_texture("idle", 0)
		if tex:
			var img: Image = tex.get_image()
			if img and img.get_used_rect().size.y > 0:
				fit = target / float(img.get_used_rect().size.y)
	_cached_fit[type] = fit
	return fit

# 한 장짜리 정적 스프라이트: 전 동작을 동일 프레임으로 채움 (애니 없음, 임시).
static func _build_static_frames(path: String) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load(path)
	for anim: String in ["idle", "walk", "slash", "hurt", "die"]:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, anim == "idle" or anim == "walk")
		sf.set_animation_speed(anim, 15.0)
		if tex:
			sf.add_frame(anim, tex)
	return sf

static func _load_anim(sf: SpriteFrames, anim: String, base_path: String, prefix: String, sub: String, count: int, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, 15.0)
	for i: int in count:
		var tex: Texture2D = load("%s%s/%s_%s_%03d.png" % [base_path, sub, prefix, sub, i])
		if tex:
			sf.add_frame(anim, tex)

static func _build_sprite_frames(variant: int) -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var base_path: String = "res://assets/characters/skeleton_warrior_%d/" % variant
	var prefix: String = "0_Skeleton_Warrior"
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
	if _anim_state == "die":
		return

	# ── 폭탄병은 기존 돌격 로직 유지 (자폭 미사일) ───────────────────────
	if behavior == "bomber":
		_physics_process_bomber(delta)
		return

	# ── 수비 밴드 AI (RD13) ───────────────────────────────────────────────
	# 1) leash: 현재 타겟이 밴드 밖으로 나갔으면 포기 (단 성벽 교전 중인 보스는 예외 — origin이 발끝보다 한참 위라 항상 밴드 밖으로 보임)
	if is_instance_valid(current_target):
		if current_target.position.y < BAND_TOP - LEASH_MARGIN and not current_target.is_in_group("boss") and not current_target.get("engaging_minion"):
			current_target = null

	# 2) 타겟 갱신
	# 원거리(궁수)는 매 프레임 재평가 — 사거리 내 적 사수를 최우선 저격(EN9·EN12).
	# 근접은 RETARGET_INTERVAL마다 가장 가까운 적으로 재평가 — 스웜 분산(RD13).
	if behavior == "ranged":
		current_target = _find_ranged_target()
	else:
		retarget_timer += delta
		if not is_instance_valid(current_target) or retarget_timer >= RETARGET_INTERVAL:
			current_target = _find_nearest_enemy_in_band()
			retarget_timer = 0.0

	# 전사만 anti-overkill 예약 갱신 — 매 프레임 현재 결정에 맞춰 동기화(같으면 no-op)
	if minion_type == "warrior":
		_set_claim(current_target)

	# 3) 타겟 없음 — 필드에 적이 남아 있으면 그 자리 사수하며 재탐색 대기(곧장 후진 금지).
	#    필드에 적이 0일 때만 짧은 유예 후 대형으로 복귀(웨이브 소강).
	if not is_instance_valid(current_target):
		if _any_enemy_on_field():
			no_enemy_timer = 0.0
			# 갓 스폰돼 정착선보다 아래(성 쪽)면 라인까지 올라가 합류 — 올라가는 건 후진이 아니므로
			# 적이 있어도 허용. (앞으로 나가 교전 후 타깃을 잃은 경우는 라인 위라 _hold_position으로 전방 사수)
			if position.y > _get_wait_position().y + 8.0:
				_move_to_wait_position(delta)
			else:
				_hold_position()
		else:
			no_enemy_timer += delta
			if no_enemy_timer >= RETREAT_GRACE:
				_move_to_wait_position(delta)
			else:
				_hold_position()
		return

	# 4) 마중 이동 — 역할별 전진 상한(_forward_limit())을 넘어 위로는 나가지 않음
	var clamped_target_pos: Vector2 = current_target.position
	if clamped_target_pos.y < _forward_limit():
		clamped_target_pos.y = _forward_limit()

	var dist: float = position.distance_to(clamped_target_pos)
	if dist > attack_range:
		var dir: Vector2 = (clamped_target_pos - position).normalized()
		velocity = dir * move_speed + _separation_vector()
		move_and_slide()
		attack_timer = attack_phase * attack_interval
		anim_sprite.flip_h = dir.x < 0
		if _anim_state not in ["hurt"]:
			_play_anim("walk")
	else:
		# 정지 대신 약한 분리만 — 같은 적을 둘러싸며 때려 '여럿이 친다'는 그림을 만든다
		velocity = _separation_vector()
		if velocity != Vector2.ZERO:
			move_and_slide()
		if _anim_state not in ["slash", "hurt"]:
			_play_anim("idle")
		attack_timer += delta
		if attack_timer >= attack_interval:
			attack_timer = 0.0
			_do_attack()

	# 5) 전진 상한 클램프 — 탱크는 FORWARD_LIMIT_TANK, 나머지는 BAND_TOP
	position.y = max(position.y, _forward_limit())
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

# 폭탄병 전용: 기존 돌격형 그대로
func _physics_process_bomber(delta: float) -> void:
	if not is_instance_valid(current_target):
		current_target = _find_nearest_enemy()
	if not current_target:
		velocity = Vector2.ZERO
		if _anim_state not in ["slash", "hurt"]:
			_play_anim("idle")
		return

	var dist: float = position.distance_to(current_target.position)
	if dist > attack_range:
		var dir: Vector2 = (current_target.position - position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		attack_timer = 0.0
		anim_sprite.flip_h = dir.x < 0
		if _anim_state not in ["hurt"]:
			_play_anim("walk")
	else:
		velocity = Vector2.ZERO
		if _anim_state not in ["slash", "hurt"]:
			_play_anim("idle")
		attack_timer += delta
		if attack_timer >= attack_interval:
			attack_timer = 0.0
			_do_attack()
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

# 적이 필드에 남아 있을 때 — 후진하지 않고 그 자리에서 사수(idle)
func _hold_position() -> void:
	# 적이 필드에 남아 있을 때 — 후진은 않되 분리 밀어내기는 적용(겹침 방지)
	velocity = _separation_vector()
	if velocity != Vector2.ZERO:
		move_and_slide()
		position.y = max(position.y, _forward_limit())
		position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
		position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)
	if _anim_state not in ["slash", "hurt"]:
		_play_anim("idle")

# 필드(보스 포함)에 살아있는 적이 하나라도 있는지
func _any_enemy_on_field() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			return true
	return false

# 대기 위치로 서서히 복귀
func _move_to_wait_position(delta: float) -> void:
	var wait_pos: Vector2 = _get_wait_position()
	var dist: float = position.distance_to(wait_pos)
	if dist > 8.0:
		var dir: Vector2 = (wait_pos - position).normalized()
		velocity = dir * move_speed * 0.7 + _separation_vector()
		move_and_slide()
		anim_sprite.flip_h = dir.x < 0
		if _anim_state not in ["hurt"]:
			_play_anim("walk")
	else:
		# 정착선 도달 — 같은 종이 같은 x오프셋을 공유해도 분리로 벌어지게
		velocity = _separation_vector()
		if velocity != Vector2.ZERO:
			move_and_slide()
		if _anim_state not in ["slash", "hurt"]:
			_play_anim("idle")
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

# 역할별 대기 위치 (동일 종이 여러 명일 때 살짝 분산)
func _get_wait_position() -> Vector2:
	var wait_y: float
	match minion_type:
		"tank":    wait_y = WAIT_Y_TANK
		"archer":  wait_y = WAIT_Y_ARCHER
		_:         wait_y = WAIT_Y_WARRIOR

	# 같은 종 하인끼리 x 분산 — get_instance_id()로 일관된 오프셋 배정
	var offsets: Array = WAIT_X_OFFSETS.get(minion_type, [200.0, 240.0, 280.0])
	var wait_x: float = offsets[get_instance_id() % offsets.size()]
	return Vector2(wait_x, wait_y)

# 스폰 위치 — 역할별 정착선 살짝 아래에서 출발해 짧게 합류 (B안). 탱크 110px→40px 트럭킹 단축.
func get_spawn_position() -> Vector2:
	var wait_pos: Vector2 = _get_wait_position()
	return wait_pos + Vector2(randf_range(-20.0, 20.0), SPAWN_BELOW_WAIT)

func _do_attack() -> void:
	if not is_instance_valid(current_target):
		return
	_play_anim("slash")
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
	_heal(attack_damage * lifesteal)

func _shoot_arrow() -> void:
	if not game:
		return
	var arrow = ArrowScene.instantiate()
	# 예측 조준(lead): 표적이 화살 비행시간 동안 이동할 위치를 겨눠, "쏜 자리를 적이 떠나
	# 화살이 뒤로 흘러 날아가는" 추적 오차 해소. 1패스(현 거리 기준)로 충분(적이 느림).
	# 정지·교전 중 적은 velocity≈0이라 자동으로 현 위치 조준.
	var to_target: Vector2 = current_target.position - position
	var flight_time: float = to_target.length() / ARCHER_ARROW_SPEED
	var aim_vec: Vector2 = (current_target.position + current_target.velocity * flight_time) - position
	arrow.position = position
	arrow.direction = aim_vec.normalized()
	arrow.target_node = current_target  # 보스 몸통 통과 판정용(조준 대상이 보스일 때만 보스 피격)
	arrow.speed = ARCHER_ARROW_SPEED  # 적 사수보다 빠른 직선 볼트 (스냅·추적오차↓)
	# 빗나가도 화면을 가로질러 날아가지 않게 조준점 부근서 소멸(직선 볼트라 통과 노이즈 방지).
	arrow.max_distance = aim_vec.length() + 60.0
	arrow.damage = attack_damage
	arrow.source = self
	arrow.lifesteal = lifesteal
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
	_report_died()
	queue_free()

# 폭탄병 전용: 가장 가까운 적 (돌격형)
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

# 수비 밴드 전용: 밴드 안(y >= BAND_TOP)에서 가장 깊이 침투한(y가 가장 큰) 적
func _find_deepest_enemy_in_band():
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var deepest = null
	var deepest_y: float = -INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		# 보스는 교전 지대 진입(combat_engaged: 성벽 도달 또는 앞 하인에게 묶임) 시 origin이 밴드 위라도 포함.
		# at_wall 단독이면 앞 하인이 보스를 벽 밖에 붙드는 동안 false라 궁수가 보스를 못 쏜다.
		if not (e.is_in_group("boss") and e.combat_engaged) and not e.get("engaging_minion") and e.position.y < ACQUIRE_TOP:
			continue   # 밴드 위(아직 안 들어온) 적 무시 — 단, 하인과 교전 중인 적은 위치 무관 포착(forward_limit 위 교착 방지)
		if e.position.y > deepest_y:
			deepest_y = e.position.y
			deepest = e
	return deepest

# 원거리 미니언 전용: 화면 내 적 사수를 사거리 무관 최우선 저격.
# BAND_TOP 필터 없음 — standoff 위치(y≈466 등)의 적 사수도 포착(EN12).
# 사수가 없으면 가장 깊이 침투한 적(전열 지원)으로 폴백.
func _find_ranged_target():
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest_archer = null
	var nearest_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not e.get("is_ranged"):
			continue   # 적 사수만 우선 탐색
		# 적 사수는 사거리 밖이라도 최우선 락온 — 화살이 전 화면을 덮으므로(speed×lifetime≈756px)
		# 제자리에서 쏴도 명중한다. standoff(120)로 우리 궁수보다 앞에 멈추는 적 사수를 놓치지 않도록 거리 게이트 제거.
		var d: float = position.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_archer = e
	if nearest_archer != null:
		return nearest_archer
	return _find_deepest_enemy_in_band()

# 전사 anti-overkill 예약: 타겟이 바뀌면 옛 적의 incoming_damage를 빼고 새 적에 더한다.
# 전사만 호출 — 탱크/궁수는 예약하지 않는다(탱크가 brute를 막는 걸 '포화'로 오판하지 않게).
func _set_claim(new_target) -> void:
	if new_target == _claimed:
		return
	if is_instance_valid(_claimed):
		_claimed.incoming_damage -= _claim_amount
	_claimed = new_target
	if is_instance_valid(new_target):
		_claim_amount = attack_damage * OVERKILL_CLAIM_MULT
		new_target.incoming_damage += _claim_amount
	else:
		_claim_amount = 0.0

# 근접 미니언 전용: 밴드 안(y >= BAND_TOP)에서 가장 가까운 적 — 스웜 분산용(RD13).
# 전사는 추가로 anti-overkill 분산(incoming_damage < hp인 적 우선), 탱크는 plain 최근접(블로킹).
func _find_nearest_enemy_in_band():
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var nearest_dist: float = INF
	var nearest_unsat = null        # 전사 전용: 아직 피해가 덜 예약된(incoming<hp) 적 중 최근접
	var nearest_unsat_dist: float = INF
	var spread: bool = (minion_type == "warrior")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		# 보스는 교전 지대 진입(combat_engaged: 성벽 도달 또는 앞 하인에게 묶임) 시 origin이 밴드 위라도 포함.
		# at_wall 단독이면 앞 하인에게 묶인 동안 false라 0.5s 재평가마다 보스를 놓쳐 surge/retreat 떨림이 났다.
		if not (e.is_in_group("boss") and e.combat_engaged) and not e.get("engaging_minion") and e.position.y < ACQUIRE_TOP:
			continue   # 밴드 위(아직 안 들어온) 적 무시 — 단, 하인과 교전 중인 적은 위치 무관 포착(forward_limit 위 교착 방지)
		var d: float = position.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
		if spread and e.incoming_damage < e.hp and d < nearest_unsat_dist:
			nearest_unsat_dist = d
			nearest_unsat = e
	if spread and nearest_unsat != null:
		return nearest_unsat  # 전사: 포화되지 않은 적 우선(분산)
	return nearest            # 폴백: 다 포화면 최근접(boss/brute는 항상 미달이라 여기 안 옴)

# 역할별 전진 상한 — 탱크 최전방, 전사는 그 바로 뒤, 궁수는 사격 위치(밴드 상한)
func _forward_limit() -> float:
	match minion_type:
		"tank":    return FORWARD_LIMIT_TANK
		"warrior": return FORWARD_LIMIT_WARRIOR
		_:         return BAND_TOP

# 인근 아군에게서 밀려나는 약한 분리 벡터(velocity, px/s). 겹침 방지·공격 분산용.
func _separation_vector() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("minions"):
		if other == self or not is_instance_valid(other):
			continue
		# 같은 종끼리만 분리 — 역할별 앞뒤 층(탱크 앞·전사 뒤)을 분리력이 무너뜨려
		# 전사가 탱크에게 뒤로 밀려 적을 못 때리던 문제 방지.
		if other.minion_type != minion_type:
			continue
		var diff: Vector2 = position - other.position
		var d: float = diff.length()
		if d >= SEPARATION_RADIUS:
			continue
		if d > 0.0:
			push += (diff / d) * (1.0 - d / SEPARATION_RADIUS)   # 가까울수록 강하게
		else:
			# 완전히 겹침 — instance_id 기반 결정적 방향으로 분리
			push += Vector2.RIGHT.rotated(float(get_instance_id() % 8) * (PI / 4.0))
	return push * SEPARATION_STRENGTH

## 피격 순간: 흰 플래시 + 약한 스케일 팝. 적의 _hit_flash와 같은 형태(색·강도만 절제).
func _hit_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	var base: Vector2 = Vector2.ONE * sprite_base_scale
	anim_sprite.modulate = HIT_FLASH
	anim_sprite.scale = base * HIT_POP_SCALE
	_flash_tween = create_tween()
	_flash_tween.parallel().tween_property(anim_sprite, "modulate", Color.WHITE, 0.12)
	_flash_tween.parallel().tween_property(anim_sprite, "scale", base, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _heal(amount: float) -> void:
	if amount <= 0.0:
		return
	hp = min(hp + amount, max_hp)

func take_damage(dmg: float) -> void:
	if _anim_state == "die":
		return
	hp -= dmg
	if hp <= 0:
		_die()
		return
	_hit_flash()

func _die() -> void:
	_play_anim("die")
	if game and game.has_method("spawn_death_effect"):
		game.spawn_death_effect(global_position, Color.WHITE)
	_report_died()

func _report_died() -> void:
	if _died_reported:
		return
	_died_reported = true
	_set_claim(null)  # 죽으면 예약 해제 — 살아있는 적의 incoming_damage 원복
	if game and game.has_method("minion_died"):
		game.minion_died(position, minion_type)

func sacrifice() -> void:
	_report_died()
	queue_free()
