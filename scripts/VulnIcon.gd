extends Node2D

## 취약(vulnerable) 상태 머리 위 아이콘. Enemy._ready()에서 생성, visible로 토글.
## 형태: 금 간 방패(cracked shield). 보라색 계열.
## 위아래 bob 애니메이션으로 시선을 끈다.

const ICON_COLOR: Color = Color(0.78, 0.45, 0.95, 1.0)  # 방패 채움 보라
const SHIELD_OUTLINE_COLOR: Color = Color(0.45, 0.18, 0.62, 1.0)  # 어두운 보라 외곽선
const CRACK_COLOR: Color = Color(0.98, 0.98, 1.0, 1.0)   # 균열: 밝은 흰색
const LINE_WIDTH: float = 1.5     # 외곽선 선폭 (px)
const CRACK_WIDTH: float = 2.0    # 균열 선폭 (px)
const BOB_AMPLITUDE: float = 2.5  # bob 진폭 (px)
const BOB_SPEED: float = 3.8      # bob 각속도 (rad/s)

var _bob_phase: float = 0.0
var _base_y: float = 0.0

func setup(offset_y: float) -> void:
	position = Vector2(0.0, offset_y)
	_base_y = offset_y
	z_index = 2  # HP바·스프라이트 위
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_bob_phase += BOB_SPEED * delta
	position.y = _base_y + sin(_bob_phase) * BOB_AMPLITUDE

func _draw() -> void:
	# --- 방패 실루엣 ---
	# 중심 (0,0), 폭 ~13px(±6.5), 높이 ~16px(-8 상단 ~ +8 하단 뾰족점)
	# 좌상 어깨 → 우상 어깨 → 우측 → 우하 → 뾰족 하단 → 좌하 → 좌측
	var shield: PackedVector2Array = PackedVector2Array([
		Vector2(-6.5, -8.0),   # 좌상 어깨
		Vector2( 6.5, -8.0),   # 우상 어깨
		Vector2( 6.5, -2.0),   # 우측 상단
		Vector2( 4.5,  6.0),   # 우하 모서리
		Vector2( 0.0,  8.0),   # 하단 뾰족점
		Vector2(-4.5,  6.0),   # 좌하 모서리
		Vector2(-6.5, -2.0),   # 좌측 상단
	])
	# 채움
	draw_colored_polygon(shield, ICON_COLOR)
	# 외곽선 (closed polyline: 마지막 점→첫 점 닫기)
	var outline: PackedVector2Array = shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, SHIELD_OUTLINE_COLOR, LINE_WIDTH, true)

	# --- 균열(crack): 위에서 아래로 지그재그 ---
	# 방패 중앙을 상단(-6px)→하단(+6px)까지 관통하는 번개꼴 3꺾임
	var crack: PackedVector2Array = PackedVector2Array([
		Vector2( 1.0, -6.0),   # 상단 진입
		Vector2(-1.5, -1.5),   # 첫 꺾임 (좌)
		Vector2( 2.0,  1.5),   # 둘째 꺾임 (우)
		Vector2(-0.5,  6.0),   # 하단 출구
	])
	draw_polyline(crack, CRACK_COLOR, CRACK_WIDTH, true)
