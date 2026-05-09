extends Node2D

const C_STONE_DARK: Color = Color(0.18, 0.10, 0.30, 1)
const C_STONE_MID: Color  = Color(0.24, 0.14, 0.40, 1)
const C_SPIRE: Color      = Color(0.12, 0.06, 0.20, 1)
const C_WINDOW: Color     = Color(0.60, 0.28, 1.00, 0.80)
const C_FLAG: Color       = Color(0.60, 0.08, 0.80, 1)
const C_GATE: Color       = Color(0.05, 0.02, 0.10, 1)

func _draw() -> void:
	# 지면 그림자
	draw_rect(Rect2(Vector2(-88, 20), Vector2(176, 7)), Color(0, 0, 0, 0.40))

	# 기본 성벽
	draw_rect(Rect2(Vector2(-85, -20), Vector2(170, 45)), C_STONE_DARK)

	# 왼쪽 타워
	draw_rect(Rect2(Vector2(-82, -100), Vector2(45, 125)), C_STONE_MID)
	draw_rect(Rect2(Vector2(-79, -118), Vector2(13, 18)), C_STONE_MID)
	draw_rect(Rect2(Vector2(-63, -118), Vector2(13, 18)), C_STONE_MID)
	draw_circle(Vector2(-60, -68), 6, C_WINDOW)

	# 오른쪽 타워
	draw_rect(Rect2(Vector2(37, -100), Vector2(45, 125)), C_STONE_MID)
	draw_rect(Rect2(Vector2(50, -118), Vector2(13, 18)), C_STONE_MID)
	draw_rect(Rect2(Vector2(66, -118), Vector2(13, 18)), C_STONE_MID)
	draw_circle(Vector2(60, -68), 6, C_WINDOW)

	# 중앙 메인 타워
	draw_rect(Rect2(Vector2(-27, -160), Vector2(54, 185)), C_STONE_DARK)
	# 흉벽 (3개)
	draw_rect(Rect2(Vector2(-24, -178), Vector2(13, 18)), C_STONE_DARK)
	draw_rect(Rect2(Vector2(-7,  -178), Vector2(13, 18)), C_STONE_DARK)
	draw_rect(Rect2(Vector2(10,  -178), Vector2(13, 18)), C_STONE_DARK)
	# 창문
	draw_circle(Vector2(0, -110), 9, C_WINDOW)
	# 성문
	draw_rect(Rect2(Vector2(-12, -10), Vector2(24, 35)), C_GATE)

	# 첨탑
	var spire: PackedVector2Array = PackedVector2Array([
		Vector2(-27, -160), Vector2(27, -160), Vector2(0, -185)
	])
	draw_colored_polygon(spire, C_SPIRE)

	# 깃발 (첨탑 꼭대기)
	var flag: PackedVector2Array = PackedVector2Array([
		Vector2(0, -205), Vector2(0, -185), Vector2(22, -195)
	])
	draw_colored_polygon(flag, C_FLAG)

func set_hp_ratio(ratio: float) -> void:
	if ratio > 0.5:
		modulate = Color.WHITE
	elif ratio > 0.25:
		modulate = Color(1.0, 0.75, 0.75, 1.0)
	else:
		modulate = Color(1.0, 0.45, 0.45, 1.0)
