extends Node2D

## ExecuteEffect — 처형(execute_kill) 전용 사망 이펙트
## 독립 Node2D: 월드 레이어에 직접 추가되어 원본 액터가 _die()로 사라져도 잔류.
## 수명 0.25s — _process에서 t 누산 → 매 프레임 queue_redraw() → 수명 끝 queue_free().
## _draw(): 확장 링 + 방사형 스파이크 8개 + 중앙 섬광 코어 (금+흰 배색).

const LIFETIME: float = 0.38
const SPIKE_COUNT: int = 8
const RING_MAX: float = 65.0   # 확장 링 최대 반경
const SPIKE_MAX: float = 48.0  # 방사 스파이크 최대 길이
const BURST_COLOR: Color = Color(1.0, 0.22, 0.18, 1.0)  # 처형 빨강 (낙뢰 노랑과 구별)
const WHITE_COLOR: Color = Color(1.0, 0.95, 0.9, 1.0)   # 흰-온기 코어

var _t: float = 0.0  # 누산 시간 (0 ~ LIFETIME)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFETIME:
		queue_free()

func _draw() -> void:
	var p: float = clampf(_t / LIFETIME, 0.0, 1.0)  # 0.0(시작) → 1.0(소멸)

	# ── 1. 확장 링: 반경 0→RING_MAX, 두께 5→1, 알파 1→0 ──────────────
	var ring_r: float = p * RING_MAX
	var ring_alpha: float = 1.0 - p
	var ring_w: float = 5.0 - p * 4.0
	var ring_col: Color = BURST_COLOR
	ring_col.a = ring_alpha
	if ring_r > 0.1:
		var segs: int = 32
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in segs + 1:
			var a: float = TAU * float(i) / float(segs)
			pts.append(Vector2(cos(a) * ring_r, sin(a) * ring_r))
		draw_polyline(pts, ring_col, ring_w, true)

	# ── 2. 방사형 스파이크 8방향: 중심에서 뻗으며 페이드 ──────────
	# 길이: 0→30px (전반부 급증, 후반 유지), 알파: 1→0
	var spike_len: float = minf(p * 2.0, 1.0) * SPIKE_MAX  # 전반부에 최대 도달
	var spike_alpha: float = 1.0 - p
	for k: int in SPIKE_COUNT:
		var angle: float = TAU * float(k) / float(SPIKE_COUNT)
		# 짝수/홀수 스파이크 길이 교대 — 톱니 느낌
		var len: float = spike_len * (1.0 if k % 2 == 0 else 0.65)
		if len < 0.5:
			continue
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var col: Color = BURST_COLOR
		col.a = spike_alpha
		draw_line(Vector2.ZERO, dir * len, col, 3.0, true)

	# ── 3. 중앙 섬광 코어: 반경 8→0px, 알파 1→0 (빠르게 사그라듦) ─
	# easing: 제곱 역 — 초반에 빠르게 수축
	var core_p: float = p * p  # ease-in 가속 수축
	var core_r: float = (1.0 - core_p) * 14.0
	var core_alpha: float = 1.0 - p
	if core_r > 0.1:
		var core_col: Color = WHITE_COLOR
		core_col.a = core_alpha
		draw_circle(Vector2.ZERO, core_r, core_col)
