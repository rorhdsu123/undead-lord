extends Node2D

## 적/보스 공격 범위 표시(표시 전용·상시 옅게). 근접=파랑·원거리=빨강.
## 부모(액터)가 _ready에서 setup()으로 반경·색·중심 오프셋을 주입한다. 실제 피해/판정 없음.
## 원은 캐릭터 시각 중심에 정원으로 그려지고, 성보다 위(자기 스프라이트 아래) 레이어에 깔린다.
## 그라디언트: 중심=투명 → 경계 r=EDGE_ALPHA(피크) → r*OUTER_RATIO=투명(외곽 페더).
## 중심이 비어 있어 적 스프라이트를 틴팅하지 않고, 공격 반경 경계가 밝게 읽힌다.

const EDGE_ALPHA: float = 0.12   # 경계 반경 r에서의 피크 알파
const OUTER_RATIO: float = 1.08  # 외곽 페더링 링의 반경 배수 (알파 0)
const SEGMENTS: int = 48

var radius: float = 60.0
var color: Color = Color(0.3, 0.6, 1.0)

func setup(p_radius: float, p_color: Color, center_offset_y: float) -> void:
	radius = p_radius
	color = p_color
	position = Vector2(0.0, center_offset_y)
	# z_index 0 → 성(트리상 앞·z 0)보다 뒤에 추가된 액터라 성 위에 그려짐.
	# 부모 자식 중 맨 앞으로 보내 자기 스프라이트 아래(지면)에 깔리게 한다.
	z_index = 0
	var parent: Node = get_parent()
	if parent:
		parent.move_child(self, 0)
	queue_redraw()

func _draw() -> void:
	# 정원 그라디언트: 중심 fan(알파 0→EDGE_ALPHA) + 외곽 annulus(EDGE_ALPHA→0).
	# draw_polygon은 삼각형 내부에서 정점 색을 선형 보간하므로 자연스러운 방사형 그라디언트 생성.
	var c_transparent: Color = Color(color.r, color.g, color.b, 0.0)
	var c_edge: Color = Color(color.r, color.g, color.b, EDGE_ALPHA)
	var outer_r: float = radius * OUTER_RATIO

	# --- 내부 fan: 중심(0,0) → 반경 r 링 ---
	# 삼각형마다 정점 3개: 중심, 링[i], 링[i+1]
	var fan_pts: PackedVector2Array = PackedVector2Array()
	var fan_cols: PackedColorArray = PackedColorArray()
	for i: int in SEGMENTS:
		var a0: float = TAU * float(i) / float(SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(SEGMENTS)
		fan_pts.append(Vector2.ZERO)
		fan_pts.append(Vector2(cos(a0) * radius, sin(a0) * radius))
		fan_pts.append(Vector2(cos(a1) * radius, sin(a1) * radius))
		fan_cols.append(c_transparent)
		fan_cols.append(c_edge)
		fan_cols.append(c_edge)
	draw_polygon(fan_pts, fan_cols)

	# --- 외곽 annulus: 반경 r → r*OUTER_RATIO (페더링) ---
	# 삼각형마다 정점 3개: 쿼드당 2삼각형(각 4정점을 2개 삼각형으로 분할)
	var ann_pts: PackedVector2Array = PackedVector2Array()
	var ann_cols: PackedColorArray = PackedColorArray()
	for i: int in SEGMENTS:
		var a0: float = TAU * float(i) / float(SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(SEGMENTS)
		var inner0: Vector2 = Vector2(cos(a0) * radius, sin(a0) * radius)
		var inner1: Vector2 = Vector2(cos(a1) * radius, sin(a1) * radius)
		var outer0: Vector2 = Vector2(cos(a0) * outer_r, sin(a0) * outer_r)
		var outer1: Vector2 = Vector2(cos(a1) * outer_r, sin(a1) * outer_r)
		# 삼각형 1: inner0, inner1, outer0
		ann_pts.append(inner0)
		ann_pts.append(inner1)
		ann_pts.append(outer0)
		ann_cols.append(c_edge)
		ann_cols.append(c_edge)
		ann_cols.append(c_transparent)
		# 삼각형 2: inner1, outer1, outer0
		ann_pts.append(inner1)
		ann_pts.append(outer1)
		ann_pts.append(outer0)
		ann_cols.append(c_edge)
		ann_cols.append(c_transparent)
		ann_cols.append(c_transparent)
	draw_polygon(ann_pts, ann_cols)
