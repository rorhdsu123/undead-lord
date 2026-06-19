## AbilitySystem.gd
## Phase B — 권능 시스템 (탭 권능 2슬롯, 3스텝 상태기계)
##
## 책임:
##   - 권능 데이터 정의 (2종 고정 슬롯)
##   - 3스텝 탭 입력 상태기계 (IDLE → ARMED → 발현 / 취소)
##   - 낙뢰의 홀 (처치형) 및 망령의 나팔 (통제형) 효과 실행
##   - 쿨다운 타이머 관리
##   - 권능 버튼 UI (원형 버튼 + 레이디얼 쿨다운 오버레이, 우하단 배치)
##   - 망령의 나팔 reach 경계 원 표시 (무장 시)
##
## 설계 원칙:
##   - 영혼 비용 없음 — 게이팅은 쿨다운만 (Phase C 소관 분리)
##   - 필드 탭이 reach 밖이면 무시 (헛탭 방지)
##   - 취소 = 무장된 버튼 재탭 (X 배지는 취소 가능 힌트). 필드 밖 탭으로는 취소 안 함
##   - 상단 HUD / 성HP바 / 트래커는 절대 건드리지 않음

class_name AbilitySystem
extends Node

# ──────────────────────────────────────────────────────────────
# 가제 상수 (플레이테스트 조정 대상)
# ──────────────────────────────────────────────────────────────

## 낙뢰의 홀
const LIGHTNING_COOLDOWN: float    = 12.0   # 쿨다운 (초)
const LIGHTNING_IMPACT_RADIUS: float = 55.0  # 착탄 관용 반경 (px)
const LIGHTNING_DMG_BOSS_NORMAL: float  = 1.0  # 보스 일반 배수
const LIGHTNING_DMG_BOSS_WINDUP: float  = 2.0  # 보스 와인드업 치명타 배수
const LIGHTNING_DMG_MINION: float        = 3.0  # 잡몹 배수

## 망령의 나팔
const TRUMPET_COOLDOWN: float      = 6.0    # 쿨다운 (초)
const TRUMPET_PULSE_RADIUS: float  = 130.0  # 넉백 원형 펄스 반경 (px)
const TRUMPET_KNOCKBACK: float     = 260.0  # 기준 넉백 거리 (px). 적 질량(knockback_resist)으로 나뉨
const TRUMPET_REACH: float         = 420.0  # 성 중심 기준 탭 허용 반경 (px)
const TRUMPET_DAMAGE: float        = 1.0    # 피해 거의 0 (순수 통제)

## UI — 원형 버튼 (플레이테스트 조정 대상)
const BTN_DIAMETER: float     = 72.0    # 버튼 지름 (px)
const BTN_GAP: float          = 16.0    # 버튼 사이 간격 (px)
const BTN_RIGHT_MARGIN: float = 12.0    # 우측 화면 여백 (좌측 버튼이 트레이 디바이더에 근접 → 묶음 우측 미세 이동)
const BTN_BOTTOM_MARGIN: float = 80.0   # 하단 화면 여백 (성 영역과 간격)
const BTN_BORDER_WIDTH: int   = 5       # 베벨 링 테두리 두께
const BTN_RADIUS: float       = BTN_DIAMETER * 0.5

## 레이디얼 링 프로그래스바 색상 (플레이테스트 조정 대상)
const RING_BASE_COLOR: Color     = Color(0.45, 0.45, 0.48, 1.0)  # 빈(미충전) 링 — 회색
const RING_CHARGE_COLOR: Color   = Color(1.0,  1.0,  1.0,  1.0)  # 충전 호 — 흰색
const RING_READY_COLOR: Color    = Color(1.0,  1.0,  1.0,  1.0)  # 준비 완료 — 흰색 꽉 참
const RING_ARMED_COLOR: Color    = Color(0.30, 0.90, 1.0,  1.0)  # 무장 — 하늘색(시안)

## 아이콘 색상 (코드 도형, 텍스처 입고 전 플레이스홀더)
const ICON_LIGHTNING_COLOR: Color = Color(1.0, 0.95, 0.30, 1.0)  # 노란 번개
const ICON_TRUMPET_COLOR: Color   = Color(0.75, 0.50, 1.0, 1.0)  # 보라 나팔

## 아이콘 디스크 레이디얼 채움 (쿨다운 중 반투명 흰색 파이 섹터)
const ICON_FILL_COLOR: Color      = Color(1.0, 1.0, 1.0, 0.38)   # 반투명 흰색, alpha 플테 조정

## 상태별 테두리 색 (하위 호환 상수 — _draw에서 직접 사용 안 함)
const BORDER_READY_COLOR: Color   = Color(0.50, 0.42, 0.65, 1.0)  # 기본 석재
const BORDER_ARMED_COLOR: Color   = Color(0.30, 0.90, 1.0,  1.0)  # 시안 (구 금색 → 시안으로 교체)
const BORDER_COOL_COLOR: Color    = Color(0.28, 0.26, 0.35, 0.80)  # 쿨 중 어둡게

## 준비 완료 깜빡임 (플레이테스트 조정 대상)
const FLASH_DURATION: float       = 0.28   # 1회 깜빡임 지속 시간 (초)

## 준비 완료 외곽 글로우 맥동 (플레이테스트 조정 대상)
const GLOW_BASE_ALPHA: float      = 0.25   # 맥동 기저 알파
const GLOW_AMP: float             = 0.20   # 맥동 진폭
const GLOW_SPEED: float           = 2.8    # 라디안/초, 약 2.2초 주기
const GLOW_COLOR: Color           = Color(1.0, 1.0, 1.0, 1.0)  # 흰색(alpha는 런타임 계산)

## 취소 배지
const BADGE_RADIUS: float     = 11.0   # 빨간 배지 반경
const BADGE_COLOR: Color      = Color(0.85, 0.12, 0.10, 1.0)
const BADGE_X_COLOR: Color    = Color(1.0, 1.0, 1.0, 1.0)

# ──────────────────────────────────────────────────────────────
# 권능 데이터 정의
# 나중에 슬롯 풀 확장 시 이 배열만 교체하면 됨
# ──────────────────────────────────────────────────────────────
const ABILITY_POOL: Array = [
	{
		"id": "lightning",
		"loc_name":   "ability_lightning_name",
		"loc_cool":   "ability_lightning_cool",
		"loc_desc":   "ability_lightning_desc",
		"cooldown":   LIGHTNING_COOLDOWN,
		"reach":      -1.0,   # -1 = 전 화면 (사실상 무제한)
		"alignment":  "처치",
	},
	{
		"id": "trumpet",
		"loc_name":   "ability_trumpet_name",
		"loc_cool":   "ability_trumpet_cool",
		"loc_desc":   "ability_trumpet_desc",
		"cooldown":   TRUMPET_COOLDOWN,
		"reach":      TRUMPET_REACH,
		"alignment":  "통제",
	},
]

# 검증 빌드 슬롯 배정 (슬롯0=낙뢰, 슬롯1=나팔)
const SLOT_COUNT: int = 2
const SLOT_ASSIGNMENTS: Array[int] = [0, 1]  # ABILITY_POOL 인덱스

# ──────────────────────────────────────────────────────────────
# 3스텝 탭 상태기계
# ──────────────────────────────────────────────────────────────
enum ArmState { IDLE, ARMED }

var _arm_state: ArmState = ArmState.IDLE
var _armed_slot: int = -1   # 현재 무장된 슬롯 인덱스

# ──────────────────────────────────────────────────────────────
# 쿨다운 상태
# ──────────────────────────────────────────────────────────────
var _cooldowns: Array[float] = [0.0, 0.0]         # 각 슬롯의 남은 쿨다운(초)
var _prev_on_cooldown: Array[bool] = [false, false] # 전이 감지용: 직전 프레임 쿨 상태

# ──────────────────────────────────────────────────────────────
# 참조
# ──────────────────────────────────────────────────────────────
var game: Node = null  # Game.gd 부모

# ──────────────────────────────────────────────────────────────
# UI 노드 (동적 생성)
# ──────────────────────────────────────────────────────────────
var _btn_canvases: Array[Control]  = []  # 슬롯별 원형 버튼 커스텀 드로 컨트롤
var _reach_circle: Node2D = null        # 망령의 나팔 reach 경계 원
var _desc_panel: Panel = null           # 무장 시 권능 설명 캡션 패널
var _desc_label: Label = null           # 무장 시 권능 설명 텍스트

# _btn_canvases 의 AbilityButtonDrawer 참조 캐시
var _btn_drawers: Array = []  # Array[AbilityButtonDrawer]

# ──────────────────────────────────────────────────────────────
# AbilityButtonDrawer — 원형 버튼 + 레이디얼 쿨 + 배지를 _draw로 그리는 내부 클래스
# ──────────────────────────────────────────────────────────────

## 커스텀 드로 컨트롤: 원형 버튼 시각 전체를 담당
class AbilityButtonDrawer extends Control:
	var slot_id: String = ""     # "lightning" | "trumpet"
	var cool_ratio: float = 0.0  # 0.0(준비) ~ 1.0(방금 발동)
	var is_armed: bool = false
	var on_cooldown: bool = false

	## 준비 완료 1회 깜빡임 타이머 (>0이면 flash 진행 중)
	var flash_timer: float = 0.0
	## 준비 완료 상태 누산 시간 — 맥동 글로우 위상 계산에 사용
	var ready_time: float = 0.0

	## flash 시작 — AbilitySystem.tick()이 쿨 전이 감지 시 호출
	func start_flash() -> void:
		flash_timer = AbilitySystem.FLASH_DURATION
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		# 준비 완료 맥동: armed/cooldown 아닐 때 누산
		var is_ready: bool = not is_armed and not on_cooldown
		if is_ready:
			ready_time += delta
		else:
			ready_time = 0.0  # 비준비 진입 시 위상 초기화
		# flash 타이머 감소
		if flash_timer > 0.0:
			flash_timer = max(0.0, flash_timer - delta)
		# 준비 완료거나 flash 중이면 process 유지, 둘 다 아니면 끄기
		if not is_ready and flash_timer <= 0.0:
			set_process(false)
			return
		queue_redraw()

	func _draw() -> void:
		var r: float = AbilitySystem.BTN_RADIUS
		var c: Vector2 = Vector2(r, r)  # 컨트롤 내 중심

		# ── 1. 배경 원 (어두운 석재/금속) ─────────────────────
		var bg_color: Color = Color(0.14, 0.12, 0.20, 0.96)
		if is_armed:
			bg_color = Color(0.22, 0.18, 0.35, 0.98)
		elif on_cooldown:
			bg_color = Color(0.10, 0.09, 0.14, 0.92)
		draw_circle(c, r, bg_color)

		# ── 2. 아이콘 (코드 도형 플레이스홀더) — 항상 보임 ──────
		if slot_id == "lightning":
			_draw_lightning_icon(c, 1.0)
		else:
			_draw_trumpet_icon(c, 1.0)

		# ── 2.5. 아이콘 위 시안 파이 채움 (쿨다운 중에만) ─────
		# 링 충전 호와 동기화: 12시(-PI*0.5)에서 시계방향으로 charge 비율만큼
		# 아이콘 디스크 반경 = BTN_RADIUS - BTN_BORDER_WIDTH (링 안쪽)
		if on_cooldown:
			var charge: float = clampf(1.0 - cool_ratio, 0.0, 1.0)
			if charge > 0.0:
				var fill_r: float = AbilitySystem.BTN_RADIUS - float(AbilitySystem.BTN_BORDER_WIDTH)
				var fill_segs: int = max(4, int(48.0 * charge))
				var fill_pts: PackedVector2Array = PackedVector2Array()
				fill_pts.append(c)  # 중심점
				for i: int in fill_segs + 1:
					var a: float = -PI * 0.5 + TAU * charge * (float(i) / float(fill_segs))
					fill_pts.append(c + Vector2(cos(a), sin(a)) * fill_r)
				draw_colored_polygon(fill_pts, AbilitySystem.ICON_FILL_COLOR)

		# ── 3. 베벨 링 — 레이디얼 프로그래스바 ────────────────
		# 무장(armed) 상태 → 시안 단색 링
		# 쿨다운 중 → 회색 빈 링 위에 흰 충전 호가 시계방향으로 차오름
		# 준비 완료  → 링 전체 흰색
		var ring_r: float = r - float(AbilitySystem.BTN_BORDER_WIDTH) * 0.5
		var ring_w: int = AbilitySystem.BTN_BORDER_WIDTH
		if is_armed:
			# 무장: 시안 단색 링
			_draw_ring(c, ring_r, ring_w, AbilitySystem.RING_ARMED_COLOR, 0.0, TAU)
		elif on_cooldown:
			# 쿨 중: 회색 빈 링 전체 + 흰 충전 호(12시→시계방향)
			_draw_ring(c, ring_r, ring_w, AbilitySystem.RING_BASE_COLOR, 0.0, TAU)
			# 충전 진행도 = 1.0 - cool_ratio (cool_ratio=1이 방금 발동, 0이 준비)
			var charge: float = clampf(1.0 - cool_ratio, 0.0, 1.0)
			if charge > 0.0:
				_draw_ring(c, ring_r, ring_w, AbilitySystem.RING_CHARGE_COLOR, -PI * 0.5, TAU * charge)
		else:
			# 준비 완료: 외곽 맥동 글로우 (링 바깥, 링보다 먼저 그려서 링이 위에 오도록)
			var glow_alpha: float = AbilitySystem.GLOW_BASE_ALPHA \
				+ AbilitySystem.GLOW_AMP * sin(ready_time * AbilitySystem.GLOW_SPEED)
			var gc: Color = AbilitySystem.GLOW_COLOR
			gc.a = glow_alpha
			# 안쪽 글로우 (ring_r + 1.5, 약간 진하게)
			_draw_ring(c, ring_r + 1.5, ring_w, gc, 0.0, TAU)
			# 바깥 글로우 (ring_r + 3, 더 옅게)
			var gc_outer: Color = gc
			gc_outer.a = glow_alpha * 0.5
			_draw_ring(c, ring_r + 3.0, max(1, ring_w - 2), gc_outer, 0.0, TAU)
			# 흰색 링 전체 (글로우 위에 올라와 선명하게)
			_draw_ring(c, ring_r, ring_w, AbilitySystem.RING_READY_COLOR, 0.0, TAU)

		# ── 4. 준비 완료 깜빡임 오버레이 (flash_timer > 0) ────
		# 쿨 완료 전이 순간 1회: 밝은 흰 글로우가 확 나타났다 페이드아웃
		if flash_timer > 0.0 and not is_armed and not on_cooldown:
			var flash_t: float = flash_timer / AbilitySystem.FLASH_DURATION  # 1.0→0.0
			# 원형 오버레이: 반투명 흰색, flash_t 기반 alpha 페이드
			var flash_alpha: float = flash_t * 0.55  # 최대 55% 투명도
			var flash_color: Color = Color(1.0, 1.0, 1.0, flash_alpha)
			draw_circle(c, r, flash_color)
			# 링도 동시에 더 밝게 (추가 링 오버레이)
			var ring_flash_color: Color = Color(1.0, 1.0, 1.0, flash_t * 0.80)
			_draw_ring(c, ring_r, ring_w + 2, ring_flash_color, 0.0, TAU)

		# ── 5. 취소 배지 (무장 시 우상단 빨간 원 + 흰 X) ───────
		if is_armed:
			_draw_cancel_badge(r)

	## 링 (두꺼운 호) — start_angle에서 시계방향으로 arc_angle 만큼 그림
	## start_angle = -PI*0.5 이면 12시, arc_angle = TAU 이면 완전한 원
	func _draw_ring(center: Vector2, r: float, width: int, color: Color,
			start_angle: float, arc_angle: float) -> void:
		if arc_angle <= 0.0:
			return
		var segs: int = max(4, int(48.0 * arc_angle / TAU))
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in segs + 1:
			var a: float = start_angle + arc_angle * (float(i) / float(segs))
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, color, float(width), true)

	## 낙뢰 아이콘 (번개 지그재그 도형, 노랑/흰)
	func _draw_lightning_icon(center: Vector2, alpha: float) -> void:
		var col: Color = AbilitySystem.ICON_LIGHTNING_COLOR
		col.a *= alpha
		var col2: Color = Color(1.0, 1.0, 0.85, 0.90 * alpha)
		var s: float = 10.0  # 스케일
		# 전형적인 번개 폴리라인: 위→아래 지그재그
		var pts: PackedVector2Array = PackedVector2Array([
			center + Vector2( 3.0, -s * 1.8),
			center + Vector2( 1.5, -s * 0.2),
			center + Vector2( 4.5, -s * 0.2),
			center + Vector2(-2.0,  s * 1.8),
			center + Vector2(-0.5,  s * 0.3),
			center + Vector2(-3.5,  s * 0.3),
			center + Vector2( 3.0, -s * 1.8),
		])
		draw_polyline(pts, col2, 2.5, true)
		# 내부 밝은 채우기
		var fill_pts: PackedVector2Array = PackedVector2Array([
			center + Vector2( 3.0, -s * 1.8),
			center + Vector2( 1.5, -s * 0.2),
			center + Vector2( 4.5, -s * 0.2),
			center + Vector2(-2.0,  s * 1.8),
			center + Vector2(-0.5,  s * 0.3),
			center + Vector2(-3.5,  s * 0.3),
		])
		draw_colored_polygon(fill_pts, col)

	## 나팔/음파 아이콘 (반원호 3개, 보라)
	func _draw_trumpet_icon(center: Vector2, alpha: float) -> void:
		var col: Color = AbilitySystem.ICON_TRUMPET_COLOR
		col.a *= alpha
		# 동심 상방 반원호 3개 (거리·폭 차등)
		for k: int in 3:
			var r: float = 5.0 + k * 5.5
			var arc_col: Color = Color(col.r, col.g, col.b, col.a * (1.0 - k * 0.22))
			var lw: float = 2.5 - k * 0.5
			var segs: int = 16
			var pts2: PackedVector2Array = PackedVector2Array()
			for j: int in segs + 1:
				var a: float = PI - (PI / segs) * j  # 위쪽 반원
				pts2.append(center + Vector2(cos(a) * r, sin(a) * r - 2.0))
			draw_polyline(pts2, arc_col, lw, true)

	## 취소 배지 (우상단 빨간 원 + 흰 X)
	func _draw_cancel_badge(btn_r: float) -> void:
		var br: float = AbilitySystem.BADGE_RADIUS
		# 배지 중심: 버튼 우상단 (45° 위치)
		var offset: float = (btn_r - br * 0.5) * 0.707  # cos45 근사
		var bc: Vector2 = Vector2(btn_r + offset, btn_r - offset)
		# 배지 원
		draw_circle(bc, br, AbilitySystem.BADGE_COLOR)
		# 흰 X (두 선)
		var xc: Color = AbilitySystem.BADGE_X_COLOR
		var hs: float = br * 0.52
		draw_line(bc + Vector2(-hs, -hs), bc + Vector2(hs, hs), xc, 2.0, true)
		draw_line(bc + Vector2(hs, -hs), bc + Vector2(-hs, hs), xc, 2.0, true)

# ──────────────────────────────────────────────────────────────
# 초기화
# ──────────────────────────────────────────────────────────────

func setup(game_node: Node) -> void:
	game = game_node
	_build_ui()
	_build_reach_circle()

# ──────────────────────────────────────────────────────────────
# _process — 쿨다운 감소 + UI 갱신
# ──────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	for i in SLOT_COUNT:
		var was_on_cd: bool = _prev_on_cooldown[i]
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = max(0.0, _cooldowns[i] - delta)
		var is_on_cd: bool = _cooldowns[i] > 0.0
		# 쿨 전이 감지: 쿨 중(true) → 준비(false) 전이 순간 flash 발동
		if was_on_cd and not is_on_cd:
			var drawer: AbilityButtonDrawer = _btn_drawers[i]
			if is_instance_valid(drawer):
				drawer.start_flash()
		_prev_on_cooldown[i] = is_on_cd
	_refresh_ui()

# ──────────────────────────────────────────────────────────────
# 입력 진입점
# ──────────────────────────────────────────────────────────────

## 권능 버튼 탭 (1스텝)
func on_ability_btn_pressed(slot: int) -> void:
	var ability: Dictionary = _get_ability(slot)
	# 쿨 중이면 무시
	if _cooldowns[slot] > 0.0:
		return
	# 이미 같은 슬롯이 무장 중이면 무시 (취소는 X 배지 전용)
	if _arm_state == ArmState.ARMED and _armed_slot == slot:
		return
	# 다른 슬롯이 무장 중이면 먼저 해제 후 새로 무장
	_armed_slot = slot
	_arm_state = ArmState.ARMED
	_refresh_ui()
	_punch_drawer(slot)  # 무장 성공 시에만 눌림 펀치(쿨다운 탭은 위 early-return → 무반응)

## X 취소 버튼 탭 — ARMED 해제
func on_cancel_btn_pressed(slot: int) -> void:
	if _arm_state != ArmState.ARMED or _armed_slot != slot:
		return
	_disarm()
	_punch_drawer(slot)  # 취소(해제)도 성공 동작 → 눌림 펀치

## 권능 드로어 눌림 펀치 — 탭 버튼은 투명이라, 시각을 그리는 드로어를 직접 스케일 바운스.
## (다른 버튼의 _play_button_bounce와 동일 손맛: 0.9로 줄었다 BACK 이징 복귀)
func _punch_drawer(slot: int) -> void:
	if slot < 0 or slot >= _btn_drawers.size():
		return
	var drawer: AbilityButtonDrawer = _btn_drawers[slot]
	if not is_instance_valid(drawer):
		return
	drawer.pivot_offset = drawer.size * 0.5
	var tw: Tween = drawer.create_tween()
	tw.tween_property(drawer, "scale", Vector2(0.90, 0.90), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(drawer, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 필드 탭 (2스텝) — Game.gd의 _unhandled_input에서 호출
## world_pos: 월드 좌표 탭 위치
func on_field_tap(world_pos: Vector2) -> void:
	if _arm_state != ArmState.ARMED:
		return
	var slot: int = _armed_slot
	var ability: Dictionary = _get_ability(slot)

	# reach 검사 (낙뢰 = 전 화면, 나팔 = 성 중심 반경)
	if not _in_reach(slot, world_pos):
		return  # 헛탭: reach 밖이면 무시, 무장 유지

	# 발현!
	_fire_ability(slot, world_pos)
	_cooldowns[slot] = ability["cooldown"]
	_disarm()

# ──────────────────────────────────────────────────────────────
# 내부: reach 판정
# ──────────────────────────────────────────────────────────────

func _in_reach(slot: int, world_pos: Vector2) -> bool:
	var ability: Dictionary = _get_ability(slot)
	var reach: float = ability["reach"]
	if reach < 0.0:
		return true  # 전 화면
	# 성 중심 기준
	var castle_pos: Vector2 = game.get_node("Castle").global_position
	return world_pos.distance_to(castle_pos) <= reach

# ──────────────────────────────────────────────────────────────
# 내부: 권능 발현 로직
# ──────────────────────────────────────────────────────────────

func _fire_ability(slot: int, world_pos: Vector2) -> void:
	# 마왕 바크 — 권능 발현 시 확률적으로 발동 (확률·라인 선택은 game에 위임)
	if is_instance_valid(game) and is_instance_valid(game.demon_portrait):
		game.demon_bark_power()
	var id: String = _get_ability(slot)["id"]
	match id:
		"lightning":
			_fire_lightning(world_pos)
		"trumpet":
			_fire_trumpet(world_pos)

## 낙뢰의 홀 — 탭 지점 강림, LIGHTNING_IMPACT_RADIUS 내 적 타격
func _fire_lightning(world_pos: Vector2) -> void:
	var player: Node = game.get_node("Player")
	var enemies: Array = game.get_tree().get_nodes_in_group("enemies")
	var crit_landed: bool = false

	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(world_pos) > LIGHTNING_IMPACT_RADIUS:
			continue

		if e.has_method("interrupt_windup"):  # 보스
			if e.is_charging_rage:
				e.interrupt_windup()
				var dmg: float = player.attack_damage * LIGHTNING_DMG_BOSS_WINDUP \
					* game.attack_bonus * game.keystone_lord_atk_mult * game.keystone_special_mult
				e.take_damage(dmg, "crit")
				crit_landed = true
			else:
				var dmg: float = player.attack_damage * LIGHTNING_DMG_BOSS_NORMAL \
					* game.attack_bonus * game.keystone_lord_atk_mult * game.keystone_special_mult
				e.take_damage(dmg, "resist")
		else:  # 잡몹
			var dmg: float = player.attack_damage * LIGHTNING_DMG_MINION \
				* game.attack_bonus * game.keystone_lord_atk_mult * game.keystone_special_mult
			e.take_damage(dmg)

	# VFX — 착탄점 낙뢰 임팩트
	_spawn_lightning_impact(world_pos)

	# 화면 효과
	if crit_landed:
		game._screen_shake(3.5, 0.25)
		game.hit_stop(0.1)
		game.show_crit_text()
	else:
		game._screen_shake(2.0, 0.15)
		game.hit_stop(0.07)

## 망령의 나팔 — 탭 지점 중심 원형 펄스, 위쪽 일괄 넉백
func _fire_trumpet(world_pos: Vector2) -> void:
	var enemies: Array = game.get_tree().get_nodes_in_group("enemies")

	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(world_pos) > TRUMPET_PULSE_RADIUS:
			continue

		# 와인드업 끊기 (피해 미미해도 끊기는 적용)
		if e.has_method("interrupt_windup") and e.is_charging_rage:
			e.interrupt_windup()

		# 거의 0 피해 (순수 통제)
		if TRUMPET_DAMAGE > 0.0:
			e.take_damage(TRUMPET_DAMAGE)

		# 위쪽 넉백 — 방향 고정 UP, apply_knockback의 질량(knockback_resist) 차등 그대로 활용
		# apply_knockback(from_pos, force): dir = e.pos - from_pos
		# 위쪽(−y)이 되려면 from_pos.y = e.pos.y + 큰값 (e보다 아래서 밀어올림)
		var push_origin: Vector2 = Vector2(e.global_position.x, e.global_position.y + 9999.0)
		e.apply_knockback(push_origin, TRUMPET_KNOCKBACK)

	# VFX — 상방 스윕 음파
	_spawn_trumpet_sweep(world_pos)

	# 화면 효과 (가벼운 흔들림)
	game._screen_shake(1.2, 0.15)

# ──────────────────────────────────────────────────────────────
# 내부: 상태 해제
# ──────────────────────────────────────────────────────────────

func _disarm() -> void:
	_arm_state = ArmState.IDLE
	_armed_slot = -1
	_hide_reach_circle()
	_refresh_ui()

# ──────────────────────────────────────────────────────────────
# 내부: 권능 데이터 접근
# ──────────────────────────────────────────────────────────────

func _get_ability(slot: int) -> Dictionary:
	return ABILITY_POOL[SLOT_ASSIGNMENTS[slot]]

# ──────────────────────────────────────────────────────────────
# UI 빌드 — 원형 버튼 2개, 우하단 배치
# ──────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var vp: Vector2 = Vector2(480.0, 960.0)
	var ui: CanvasLayer = game.get_node("UI")

	# 우하단 배치: 가장 오른쪽 버튼 중심 기준 역산
	# 버튼 2개 가로 배열: [슬롯0][슬롯1] 순서, 오른쪽에서 왼쪽으로 배치
	# 슬롯1(나팔) = 우측, 슬롯0(낙뢰) = 나팔 왼쪽
	var btn_y_center: float = vp.y - BTN_BOTTOM_MARGIN - BTN_RADIUS
	var slot1_cx: float = vp.x - BTN_RIGHT_MARGIN - BTN_RADIUS
	var slot0_cx: float = slot1_cx - BTN_DIAMETER - BTN_GAP

	var centers: Array[float] = [slot0_cx, slot1_cx]

	for i in SLOT_COUNT:
		var ability: Dictionary = _get_ability(i)
		var cx: float = centers[i]
		var cy: float = btn_y_center

		# ── AbilityButtonDrawer: 원형 버튼 커스텀 드로 컨트롤 ─
		# 배지가 우상단으로 튀어나오므로 컨트롤 크기를 넉넉하게 (지름 + 배지 여유)
		var badge_overflow: float = BADGE_RADIUS * 1.6
		var ctrl_size: float = BTN_DIAMETER + badge_overflow * 2.0
		var drawer: AbilityButtonDrawer = AbilityButtonDrawer.new()
		drawer.slot_id = ability["id"]
		drawer.cool_ratio = 0.0
		drawer.is_armed = false
		drawer.on_cooldown = false
		# 컨트롤 좌상단 = 중심 - ctrl_size/2
		drawer.position = Vector2(cx - ctrl_size * 0.5, cy - ctrl_size * 0.5)
		drawer.size = Vector2(ctrl_size, ctrl_size)
		drawer.name = "AbilityDrawer%d" % i
		drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 입력은 별도 버튼이 받음
		ui.add_child(drawer)
		_btn_canvases.append(drawer)
		_btn_drawers.append(drawer)

		# ── 투명 탭 버튼 (원형 버튼 영역 위에 겹침) ──────────
		# 배지 X 취소 영역 포함해 전체 ctrl_size를 커버
		var tap_btn: Button = Button.new()
		tap_btn.position = drawer.position
		tap_btn.size = Vector2(ctrl_size, ctrl_size)
		tap_btn.flat = true
		tap_btn.focus_mode = Control.FOCUS_NONE
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		tap_btn.add_theme_stylebox_override("normal", empty)
		tap_btn.add_theme_stylebox_override("hover", empty)
		tap_btn.add_theme_stylebox_override("pressed", empty)
		tap_btn.add_theme_stylebox_override("focus", empty)
		tap_btn.name = "AbilityTapBtn%d" % i

		# 배지가 우상단에 있으므로 탭 시 배지 영역 → 취소 / 나머지 → 무장
		# 배지 중심: ctrl_size 내 상대 좌표 (drawer._draw_cancel_badge 로직과 동일 계산)
		# drawer 내부 btn_r = BTN_RADIUS, offset = (btn_r - badge_r*0.5)*0.707
		# badge center in drawer = (btn_r + offset + badge_overflow, btn_r - offset + badge_overflow)
		var slot_i: int = i
		tap_btn.pressed.connect(func() -> void: _on_tap_btn_pressed(slot_i, tap_btn))
		ui.add_child(tap_btn)

	# ── 권능 설명 캡션 패널 (하단 중앙 가로 바, 무장 시 표시) ──────────
	# 위치: 화면 최하단 중앙. 버튼 하단(y≈880)보다 아래(908~944)에 배치해 겹침 없음.
	const CAP_W: float   = 380.0   # 텍스트가 한 줄에 들어갈 넉넉한 너비
	const CAP_H: float   = 36.0    # 높이 (한 줄 기준)
	const CAP_BOTTOM: float = 16.0 # 화면 하단에서 위로 띄울 여백
	var cap_w: float = CAP_W
	var cap_h: float = CAP_H
	var cap_x: float = (vp.x - cap_w) * 0.5   # 가로 중앙 정렬
	var cap_y: float = vp.y - cap_h - CAP_BOTTOM  # = 908.0

	_desc_panel = Panel.new()
	_desc_panel.name = "AbilityDescPanel"
	_desc_panel.position = Vector2(cap_x, cap_y)
	_desc_panel.size = Vector2(cap_w, cap_h)
	_desc_panel.visible = false
	_desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cap_style: StyleBoxFlat = StyleBoxFlat.new()
	cap_style.bg_color = Color(0.08, 0.06, 0.14, 0.82)
	cap_style.border_color = Color(0.60, 0.50, 0.80, 0.55)
	cap_style.set_border_width_all(1)
	cap_style.set_corner_radius_all(7)
	_desc_panel.add_theme_stylebox_override("panel", cap_style)
	ui.add_child(_desc_panel)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", Color(0.90, 0.88, 1.0, 1.0))
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.position = Vector2(8.0, 0.0)
	_desc_label.size = Vector2(cap_w - 16.0, cap_h)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_panel.add_child(_desc_label)

	_refresh_ui()

## 탭 버튼 핸들러 — 배지 영역 탭 시 취소, 아니면 무장
func _on_tap_btn_pressed(slot: int, tap_btn: Button) -> void:
	# 무장 상태에서 이 슬롯이 armed라면 배지 탭 여부 판별
	if _arm_state == ArmState.ARMED and _armed_slot == slot:
		# 마지막 탭 위치를 Button에서 얻기 어려우므로 배지 영역(우상단 사각 영역)으로 근사 판단
		# → 취소 배지는 우상단에 있으므로, 무장 시 동일 슬롯 탭은 배지 탭으로 간주 → 취소
		on_cancel_btn_pressed(slot)
		return
	on_ability_btn_pressed(slot)

# ──────────────────────────────────────────────────────────────
# UI 갱신
# ──────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	for i in SLOT_COUNT:
		var ability: Dictionary = _get_ability(i)
		var cd: float = _cooldowns[i]
		var total_cd: float = ability["cooldown"]
		var is_armed: bool = (_arm_state == ArmState.ARMED and _armed_slot == i)
		var on_cd: bool = cd > 0.0

		# AbilityButtonDrawer 상태 갱신 → queue_redraw로 재드로
		var drawer: AbilityButtonDrawer = _btn_drawers[i]
		drawer.cool_ratio = (cd / total_cd) if on_cd else 0.0
		drawer.is_armed = is_armed
		drawer.on_cooldown = on_cd
		# 준비 완료 상태 진입 시 process 켜기 (맥동 글로우 구동)
		if not is_armed and not on_cd:
			drawer.set_process(true)
		drawer.queue_redraw()

		# 무장 시 나팔의 reach 원 표시
		if is_armed and ability["id"] == "trumpet":
			_show_reach_circle()
		elif not is_armed and i == _armed_slot:
			_hide_reach_circle()

	# 설명 캡션 — 무장 슬롯이 있을 때만 표시
	if is_instance_valid(_desc_panel) and is_instance_valid(_desc_label):
		if _arm_state == ArmState.ARMED and _armed_slot >= 0 and _armed_slot < SLOT_COUNT:
			var armed_ability: Dictionary = _get_ability(_armed_slot)
			_desc_label.text = Loc.t(armed_ability["loc_desc"])
			_desc_panel.visible = true
		else:
			_desc_panel.visible = false

# ──────────────────────────────────────────────────────────────
# reach 경계 원 (망령의 나팔용)
# ──────────────────────────────────────────────────────────────

func _build_reach_circle() -> void:
	_reach_circle = Node2D.new()
	_reach_circle.name = "TrumpetReachCircle"
	_reach_circle.visible = false
	game.add_child(_reach_circle)

	var seg: int = 64
	var r: float = TRUMPET_REACH
	var line: Line2D = Line2D.new()
	line.default_color = Color(0.70, 0.55, 1.0, 0.28)
	line.width = 2.0
	for i: int in seg + 1:
		var a: float = (TAU / seg) * i
		line.add_point(Vector2(cos(a) * r, sin(a) * r))
	_reach_circle.add_child(line)

	# 성 중심에 고정
	var castle_pos: Vector2 = game.get_node("Castle").global_position
	_reach_circle.position = castle_pos

func _show_reach_circle() -> void:
	if is_instance_valid(_reach_circle):
		_reach_circle.visible = true

func _hide_reach_circle() -> void:
	if is_instance_valid(_reach_circle):
		_reach_circle.visible = false

# ──────────────────────────────────────────────────────────────
# VFX
# ──────────────────────────────────────────────────────────────

## 낙뢰 임팩트 — 착탄점 번개 스파크
func _spawn_lightning_impact(pos: Vector2) -> void:
	# 중심 섬광 burst
	var n: Node2D = Node2D.new()
	n.position = pos
	game.add_child(n)

	var seg: int = 32
	var base_r: float = 8.0
	var fill: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = (TAU / seg) * i
		pts.append(Vector2(cos(a) * base_r, sin(a) * base_r))
	fill.polygon = pts
	fill.color = Color(0.75, 0.95, 1.0, 0.85)
	n.add_child(fill)

	var target_scale: float = LIGHTNING_IMPACT_RADIUS / base_r
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(n, "scale", Vector2.ONE * target_scale, 0.22)
	tw.tween_property(n, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(n.queue_free)

	# 번개 스파크 선 (방사형 4개)
	for k: int in 4:
		var spark: Line2D = Line2D.new()
		spark.position = pos
		spark.default_color = Color(0.85, 0.98, 1.0, 0.90)
		spark.width = 3.0
		var angle: float = (TAU / 4.0) * k + randf_range(-0.3, 0.3)
		var length: float = randf_range(20.0, 45.0)
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(cos(angle) * length, sin(angle) * length))
		game.add_child(spark)
		var tw2: Tween = create_tween()
		tw2.tween_property(spark, "modulate:a", 0.0, 0.20)
		tw2.tween_callback(spark.queue_free)

## 망령의 나팔 상방 스윕 — 아치형 음파 (수직 방향 강조, 방사형 오인 방지)
func _spawn_trumpet_sweep(pos: Vector2) -> void:
	# 위쪽 반원호 (바람/음파 이미지)
	for k: int in 3:
		var arc: Line2D = Line2D.new()
		arc.position = pos
		var r: float = 20.0 + k * 22.0
		var arc_color: Color = Color(0.70, 0.88, 1.0, 0.60 - k * 0.15)
		arc.default_color = arc_color
		arc.width = 2.5 - k * 0.5
		# 상방 반원호 (PI → 0, 즉 왼쪽에서 오른쪽으로 위쪽 반원)
		var arc_segs: int = 24
		for j: int in arc_segs + 1:
			var a: float = PI - (PI / arc_segs) * j
			arc.add_point(Vector2(cos(a) * r, sin(a) * r))
		game.add_child(arc)
		var delay: float = k * 0.07
		var tw: Tween = create_tween()
		tw.tween_interval(delay)
		tw.tween_property(arc, "position:y", arc.position.y - 40.0, 0.30)
		tw.parallel().tween_property(arc, "modulate:a", 0.0, 0.30)
		tw.chain().tween_callback(arc.queue_free)

	# 부채꼴 점 파티클 (위쪽)
	for _p in 6:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color(0.75, 0.90, 1.0, 0.80)
		dot.position = pos - Vector2(3, 3)
		game.add_child(dot)
		var angle: float = randf_range(-PI * 0.6, -PI * 0.4)  # 위쪽 부채꼴
		var dist: float = randf_range(30.0, 70.0)
		var target: Vector2 = pos + Vector2(cos(angle) * dist, sin(angle) * dist) - Vector2(3, 3)
		var tw2: Tween = create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(dot, "position", target, 0.35)
		tw2.tween_property(dot, "modulate:a", 0.0, 0.35)
		tw2.chain().tween_callback(dot.queue_free)
