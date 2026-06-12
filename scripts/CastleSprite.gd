extends Node2D

# 탑다운 정사각형 성벽. S=80 기준 외벽 160×160, 코너타워 포함 188×188.
const C_FLOOR:  Color = Color(0.18, 0.07, 0.30, 1.0)
const C_WALL:   Color = Color(0.38, 0.17, 0.58, 1.0)
const C_TOWER:  Color = Color(0.26, 0.10, 0.44, 1.0)
const C_LIT:    Color = Color(0.56, 0.30, 0.76, 1.0)

const S: float = 80.0  # 외벽 절반 크기 (Enemy.gd CASTLE_HALF와 맞춤)
const W: float = 20.0  # 벽 두께
const T: float = 14.0  # 코너 타워 돌출량

func _draw() -> void:
	var tsz := W + T * 2.0  # 타워 한 변 길이 = 48

	# 내부 마당
	draw_rect(Rect2(Vector2(-S + W, -S + W), Vector2((S - W) * 2.0, (S - W) * 2.0)), C_FLOOR)

	# 4면 성벽
	draw_rect(Rect2(Vector2(-S,      -S),      Vector2(S * 2.0, W)),             C_WALL)  # 북
	draw_rect(Rect2(Vector2(-S,      S - W),   Vector2(S * 2.0, W)),             C_WALL)  # 남
	draw_rect(Rect2(Vector2(-S,      -S + W),  Vector2(W,       (S - W) * 2.0)), C_WALL)  # 서
	draw_rect(Rect2(Vector2(S - W,   -S + W),  Vector2(W,       (S - W) * 2.0)), C_WALL)  # 동

	# 벽 하이라이트 (NW 광원)
	draw_rect(Rect2(Vector2(-S, -S), Vector2(S * 2.0, 3.0)), C_LIT)
	draw_rect(Rect2(Vector2(-S, -S), Vector2(3.0, S * 2.0)), C_LIT)

	# 코너 타워 (4개)
	draw_rect(Rect2(Vector2(-S - T,     -S - T),     Vector2(tsz, tsz)), C_TOWER)  # NW
	draw_rect(Rect2(Vector2(S - W - T,  -S - T),     Vector2(tsz, tsz)), C_TOWER)  # NE
	draw_rect(Rect2(Vector2(-S - T,     S - W - T),  Vector2(tsz, tsz)), C_TOWER)  # SW
	draw_rect(Rect2(Vector2(S - W - T,  S - W - T),  Vector2(tsz, tsz)), C_TOWER)  # SE

	# 타워 하이라이트 (북쪽·서쪽 면)
	draw_rect(Rect2(Vector2(-S - T,    -S - T), Vector2(tsz, 3.0)),  C_LIT)
	draw_rect(Rect2(Vector2(-S - T,    -S - T), Vector2(3.0, tsz)),  C_LIT)
	draw_rect(Rect2(Vector2(S - W - T, -S - T), Vector2(tsz, 3.0)),  C_LIT)

	# 북벽 흉벽(crenels) 4개 — 적이 북쪽에서 접근
	for i in 4:
		draw_rect(Rect2(Vector2(-29.0 + i * 17.0, -S), Vector2(7.0, 9.0)), C_FLOOR)


func set_hp_ratio(ratio: float) -> void:
	if ratio > 0.5:
		modulate = Color.WHITE
	elif ratio > 0.25:
		modulate = Color(1.0, 0.75, 0.75, 1.0)
	else:
		modulate = Color(1.0, 0.45, 0.45, 1.0)
