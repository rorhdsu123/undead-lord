extends Control

# ─── 상태 ───────────────────────────────────────────────────────────────
var _ratio: float = 1.0
var _phase: float = 0.0
var _pulse_brightness: float = 1.0
var _vignette_rect: ColorRect = null
var _vignette_mat: ShaderMaterial = null
var _hp_label: Label = null

# ─── 레이아웃 상수 ────────────────────────────────────────────────────
const BODY_X: float = 34.0          # 방패 배지가 이 지점까지 왼쪽을 덮음
const BORDER_THICK: float = 3.0     # 바 외곽선 두께
const CORNER_R: float = 10.0        # 바 외곽 모서리 반경
const FILL_CORNER_R: float = 8.0    # 채움 모서리 반경
const SHIELD_CX: float = 17.0       # 방패 중심 X

# ─── 팔레트 ───────────────────────────────────────────────────────────
const C_BAR_BG:     Color = Color(0.12, 0.16, 0.14, 1.00)   # 바 배경 (다크 그린계)
const C_BAR_BORDER: Color = Color(0.06, 0.05, 0.08, 1.00)   # 외곽선 (거의 검정)
const C_NORMAL:     Color = Color(0.22, 0.82, 0.28, 1.00)   # 정상 — 라임 그린
const C_WARN:       Color = Color(0.92, 0.68, 0.10, 1.00)   # 경고 — 호박/황색
const C_DANGER:     Color = Color(0.90, 0.18, 0.14, 1.00)   # 위급 — 빨강
const C_DIVIDER:    Color = Color(0.85, 0.22, 0.16, 0.90)   # 분절 틱 (레드/오렌지)
const C_SHIELD:     Color = Color(0.48, 0.12, 0.16, 1.00)   # 방패 (마룬)
const C_SHIELD_OUT: Color = Color(0.10, 0.06, 0.08, 1.00)   # 방패 외곽선
const C_CROWN:      Color = Color(0.95, 0.78, 0.20, 1.00)   # 왕관 (골드)
const C_CROWN_OUT:  Color = Color(0.20, 0.10, 0.04, 1.00)   # 왕관 외곽선
const C_GLOSS:      Color = Color(1.0,  1.0,  1.0,  0.22)   # 광택 하이라이트

# ─── 비네트 셰이더 ────────────────────────────────────────────────────
const _VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.45;
	float edge = smoothstep(0.35, 0.9, d);
	COLOR = vec4(0.85, 0.05, 0.05, edge * intensity);
}
"""

func _ready() -> void:
	# ── 전체 화면 비네트 ColorRect 부모($UI)에 추가 ──────────────────
	# _ready 는 자식→부모 순 실행 → Game._ready modal 재정렬 이전 삽입
	# → 비네트는 모달 아래 (의도된 동작)
	var sh := Shader.new()
	sh.code = _VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = sh

	_vignette_rect = ColorRect.new()
	_vignette_rect.size = Vector2(480, 960)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.material = _vignette_mat
	# 부모($UI)가 _ready 중 자식 셋업으로 busy → 지연 추가
	get_parent().add_child.call_deferred(_vignette_rect)

	# ── HP 수치 라벨 생성 ────────────────────────────────────────────
	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 바디 영역(BODY_X..size.x)에 맞춰 위치·크기 설정
	# size는 tscn 오프셋 기준: width=460, height=24 → BODY_X~끝 = 460-34 = 426px
	_hp_label.position = Vector2(BODY_X, 0.0)
	_hp_label.size = Vector2(size.x - BODY_X, size.y)
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.text = ""
	add_child(_hp_label)

# ─── 공개 API ─────────────────────────────────────────────────────────
func set_hp(hp: int, max_hp: int) -> void:
	_ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if _hp_label:
		_hp_label.text = "%d / %d" % [hp, max_hp]
	queue_redraw()

# ─── 맥동 + 비네트 드라이브 ───────────────────────────────────────────
func _process(delta: float) -> void:
	if _ratio > 0.5:
		# 정상: 맥동 없음, 비네트 꺼짐
		_pulse_brightness = 1.0
		modulate = Color.WHITE
		if _vignette_mat:
			_vignette_mat.set_shader_parameter("intensity", 0.0)
		return

	# 경고/위급에서 위상 누적
	var speed: float = 1.8 if _ratio >= 0.25 else 3.5
	_phase += delta * speed
	var pulse: float = sin(_phase) * 0.5 + 0.5  # 0..1

	# 채움 밝기만 맥동 (modulate는 WHITE 고정 — 방패·라벨 영향 방지)
	_pulse_brightness = 0.80 + pulse * 0.20
	modulate = Color.WHITE
	queue_redraw()

	# 비네트
	if _vignette_mat:
		if _ratio >= 0.25:
			_vignette_mat.set_shader_parameter("intensity", 0.0)
		else:
			_vignette_mat.set_shader_parameter("intensity", pulse * 0.55)

# ─── 그리기 ───────────────────────────────────────────────────────────
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# ── 위험 단계 색상 결정 + 맥동 밝기 적용 ─────────────────────────
	var base_color: Color
	if _ratio > 0.5:
		base_color = C_NORMAL
	elif _ratio >= 0.25:
		base_color = C_WARN
	else:
		base_color = C_DANGER
	var fill_color: Color = base_color * _pulse_brightness
	fill_color.a = 1.0

	# ── 1. 바 배경 (다크 둥근 사각형) ──────────────────────────────
	var body_rect := Rect2(BODY_X, 0.0, w - BODY_X, h)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = C_BAR_BG
	body_style.corner_radius_top_left = int(CORNER_R)
	body_style.corner_radius_top_right = int(CORNER_R)
	body_style.corner_radius_bottom_right = int(CORNER_R)
	body_style.corner_radius_bottom_left = int(CORNER_R)
	body_style.border_width_left = int(BORDER_THICK)
	body_style.border_width_top = int(BORDER_THICK)
	body_style.border_width_right = int(BORDER_THICK)
	body_style.border_width_bottom = int(BORDER_THICK)
	body_style.border_color = C_BAR_BORDER
	draw_style_box(body_style, body_rect)

	# ── 2. 채움 바 ──────────────────────────────────────────────────
	var inner_x: float = BODY_X + BORDER_THICK
	var inner_y: float = BORDER_THICK
	var inner_w: float = w - BODY_X - BORDER_THICK * 2.0
	var inner_h: float = h - BORDER_THICK * 2.0
	var fill_w: float = inner_w * _ratio

	if fill_w > 1.0:
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.corner_radius_top_left = int(FILL_CORNER_R)
		fill_style.corner_radius_top_right = int(FILL_CORNER_R)
		fill_style.corner_radius_bottom_right = int(FILL_CORNER_R)
		fill_style.corner_radius_bottom_left = int(FILL_CORNER_R)
		draw_style_box(fill_style, Rect2(inner_x, inner_y, fill_w, inner_h))

		# ── 3. 광택 하이라이트 (채움 상단 ~40%) ────────────────────
		var gloss_h: float = inner_h * 0.40
		var gloss_style := StyleBoxFlat.new()
		gloss_style.bg_color = C_GLOSS
		gloss_style.corner_radius_top_left = int(FILL_CORNER_R)
		gloss_style.corner_radius_top_right = int(FILL_CORNER_R)
		gloss_style.corner_radius_bottom_right = 3
		gloss_style.corner_radius_bottom_left = 3
		draw_style_box(gloss_style, Rect2(inner_x, inner_y, fill_w, gloss_h))

	# ── 4. 분절 틱 (1/3, 2/3 지점에 얇은 세로 선) ──────────────────
	var tick_w: float = 2.0
	for i in range(1, 3):
		var tick_x: float = inner_x + inner_w * (float(i) / 3.0) - tick_w * 0.5
		draw_rect(Rect2(tick_x, inner_y, tick_w, inner_h), C_DIVIDER)

	# ── 5. 왕관 방패 배지 (좌측, 바보다 위아래로 약간 삐져나옴) ──────
	_draw_shield(h)

# ─── 왕관 방패 서브 드로우 ─────────────────────────────────────────────
func _draw_shield(bar_h: float) -> void:
	var cx: float = SHIELD_CX
	var sh: float = bar_h           # 방패 논리 높이 = 바 높이
	var overhang: float = 3.0       # 위아래로 튀어나오는 픽셀

	# 방패: 평평한 상단, 양 옆 수직 내려오다 아래서 뾰족하게 모임 (하향 오각형)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 15.0, -overhang),               # 좌상
		Vector2(cx + 15.0, -overhang),               # 우상
		Vector2(cx + 15.0, sh * 0.60 - overhang),    # 우 중간
		Vector2(cx,        sh + overhang * 1.5),      # 아래 꼭지점
		Vector2(cx - 15.0, sh * 0.60 - overhang),    # 좌 중간
	])

	# 방패 채움
	draw_colored_polygon(pts, C_SHIELD)

	# 방패 외곽선 (닫힌 폴리라인)
	var outline_pts := PackedVector2Array(pts)
	outline_pts.append(pts[0])   # 닫기
	draw_polyline(outline_pts, C_SHIELD_OUT, 1.5, true)

	# 왕관 (방패 상단부에 작은 3봉 왕관) ─────────────────────────────
	# crown_y_base를 sh의 70%로 잡아 24px 바에서도 봉우리 높이를 확보
	var crown_y_base: float = sh * 0.70 - overhang   # 왕관 베이스 Y
	var crown_y_top: float  = overhang + 1.0          # 왕관 최상단 Y
	var crown_half_w: float = 9.0
	var peak_h: float = (crown_y_base - crown_y_top) * 0.80   # 봉우리 높이

	# 3봉 왕관 실루엣 (폴리곤):
	# 베이스 좌→좌측봉→베이스 내려옴→중앙봉(가장높음)→베이스 내려옴→우측봉→베이스 우
	var crown_pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - crown_half_w, crown_y_base),                     # 베이스 좌
		Vector2(cx - crown_half_w, crown_y_base - peak_h * 0.75),     # 좌봉 아래
		Vector2(cx - crown_half_w * 0.55, crown_y_base - peak_h * 0.75),  # 좌봉→중앙 사이 V 바닥
		Vector2(cx - crown_half_w * 0.30, crown_y_top + 1.0),         # 중앙봉 좌 (높음)
		Vector2(cx,                        crown_y_top),               # 중앙봉 꼭대기
		Vector2(cx + crown_half_w * 0.30, crown_y_top + 1.0),         # 중앙봉 우 (높음)
		Vector2(cx + crown_half_w * 0.55, crown_y_base - peak_h * 0.75),  # 중앙→우봉 사이 V 바닥
		Vector2(cx + crown_half_w, crown_y_base - peak_h * 0.75),     # 우봉 아래
		Vector2(cx + crown_half_w, crown_y_base),                     # 베이스 우
	])
	draw_colored_polygon(crown_pts, C_CROWN)

	# 왕관 외곽선
	var crown_outline := PackedVector2Array(crown_pts)
	crown_outline.append(crown_pts[0])
	draw_polyline(crown_outline, C_CROWN_OUT, 1.0, true)
