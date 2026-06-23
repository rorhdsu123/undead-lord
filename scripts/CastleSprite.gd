extends Node2D

# 탑다운 정사각형 성벽. S=80 기준 외벽 160×160, 코너타워 포함 188×188.
const C_FLOOR:  Color = Color(0.18, 0.07, 0.30, 1.0)
const C_WALL:   Color = Color(0.38, 0.17, 0.58, 1.0)
const C_TOWER:  Color = Color(0.26, 0.10, 0.44, 1.0)
const C_LIT:    Color = Color(0.56, 0.30, 0.76, 1.0)
const C_CRACK:  Color = Color(0.04, 0.02, 0.09, 0.92)   # 균열 (거의 검정 보라)
const C_RUBBLE: Color = Color(0.14, 0.05, 0.22, 1.0)    # 잔해 (어두운 보라)
const C_SCORCH: Color = Color(0.0, 0.0, 0.0, 0.28)      # 그을음 (반투명)

const S: float = 80.0  # 외벽 절반 크기 (Enemy.gd CASTLE_HALF와 맞춤)
const W: float = 20.0  # 벽 두께
const T: float = 14.0  # 코너 타워 돌출량

# ─── 파손 단계 상태 ───────────────────────────────────────────────────────
var _damage_stage: int = 0

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

	# ─── 파손 단계 오버레이 ───────────────────────────────────────────────
	# stage >= 1: 북벽 돌파구 1개 + 마당 균열선 2~3개 + NE 타워 모서리 결손
	if _damage_stage >= 1:
		# 북벽 돌파구 (C_FLOOR로 벽 일부를 뚫린 것처럼)
		draw_rect(Rect2(Vector2(-8.0, -S), Vector2(16.0, W)), C_FLOOR)
		# 마당 균열선 — 돌파구에서 마당 방향으로 뻗어 내려오는 선
		draw_line(Vector2(0.0, -S + W), Vector2(-12.0, -S + W + 28.0), C_CRACK, 2.0)
		draw_line(Vector2(0.0, -S + W), Vector2(10.0, -S + W + 22.0), C_CRACK, 2.0)
		draw_line(Vector2(-18.0, -S + W + 5.0), Vector2(-30.0, -S + W + 35.0), C_CRACK, 2.0)
		# NE 코너타워 모서리 결손
		draw_rect(Rect2(Vector2(S - W - T + tsz - 8.0, -S - T), Vector2(8.0, 8.0)), C_FLOOR)

	# stage >= 2: 북벽 돌파구 확장 + NE 타워 잔해화 + 추가 균열 + 그을음
	if _damage_stage >= 2:
		# 북벽 돌파구 확장
		draw_rect(Rect2(Vector2(-14.0, -S), Vector2(28.0, W)), C_FLOOR)
		# NE 코너타워 잔해 — C_RUBBLE로 덮고 불규칙 결손
		draw_rect(Rect2(Vector2(S - W - T, -S - T), Vector2(tsz, tsz)), C_RUBBLE)
		draw_rect(Rect2(Vector2(S - W - T, -S - T), Vector2(tsz * 0.4, tsz * 0.4)), C_FLOOR)
		draw_rect(Rect2(Vector2(S - W - T + tsz * 0.6, -S - T + tsz * 0.55), Vector2(tsz * 0.4, tsz * 0.45)), C_FLOOR)
		# 서벽까지 이어지는 추가 균열
		draw_line(Vector2(-S + W, -S + W + 15.0), Vector2(-S + W + 25.0, -S + W + 38.0), C_CRACK, 2.0)
		draw_line(Vector2(20.0, -S + W + 10.0), Vector2(35.0, -S + W + 40.0), C_CRACK, 2.0)
		# 돌파구 근처 그을음 원
		draw_circle(Vector2(0.0, -S + W + 10.0), 22.0, C_SCORCH)


func set_hp_ratio(ratio: float) -> void:
	# modulate 틴트: 흰색 > 2/3, 연빨강 > 1/3, 빨강 ≤ 1/3
	if ratio > 2.0/3.0:
		modulate = Color.WHITE
	elif ratio > 1.0/3.0:
		modulate = Color(1.0, 0.75, 0.75, 1.0)
	else:
		modulate = Color(1.0, 0.45, 0.45, 1.0)
	# 파손 단계 갱신
	var new_stage: int
	if ratio > 2.0/3.0:
		new_stage = 0
	elif ratio > 1.0/3.0:
		new_stage = 1
	else:
		new_stage = 2
	if new_stage != _damage_stage:
		_damage_stage = new_stage
		queue_redraw()
