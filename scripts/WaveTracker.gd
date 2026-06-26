extends Node
## 웨이브 트래커 UI 도메인 컨트롤러 (Phase 2 #5) — 카피바라고 스타일 캡슐형 노드 스트립.
## 외부 호출 0(Game 내부만). 상태(wave_tracker 노드·current_*·_last_tracker_sig)는 Game 소유 → game 역참조(GS2).
## Game._ready/start_wave서 _build_wave_tracker/update_wave_tracker/_reveal_wave_tracker 호출(Game이 wave_tracker_ui.X로).

const WaveData = preload("res://scripts/WaveData.gd")

# 아이콘은 NotoEmoji placeholder (아트 입고 후 교체)
const TRACKER_ICON_NORMAL:   String = "👾"
const TRACKER_ICON_SHOP:     String = "💰"
const TRACKER_ICON_MID_BOSS: String = "👹"
const TRACKER_ICON_BOSS:     String = "💀"

# 노드 종류별 배지 채움색
const TRACKER_COLOR_NORMAL:   Color = Color(0.28, 0.26, 0.34)
const TRACKER_COLOR_SHOP:     Color = Color(0.20, 0.35, 0.40)
const TRACKER_COLOR_MID_BOSS: Color = Color(0.40, 0.22, 0.48)
const TRACKER_COLOR_BOSS:     Color = Color(0.55, 0.15, 0.20)

# 배지 크기 (고정)
const TRACKER_BADGE_SIZE: float = 30.0

var game: Node = null  # Game.gd 허브 역참조

func setup(g: Node) -> void:
	game = g

func _reveal_wave_tracker() -> void:
	game.wave_tracker.visible = true
	game.wave_tracker.modulate.a = 1.0

func _wave_icon(wave_data: Dictionary) -> String:
	match wave_data.get("type", "normal"):
		"boss":     return TRACKER_ICON_BOSS
		"mid_boss": return TRACKER_ICON_MID_BOSS
		"shop":     return TRACKER_ICON_SHOP
		_:          return TRACKER_ICON_NORMAL

func _wave_badge_color(wave_data: Dictionary) -> Color:
	match wave_data.get("type", "normal"):
		"boss":     return TRACKER_COLOR_BOSS
		"mid_boss": return TRACKER_COLOR_MID_BOSS
		"shop":     return TRACKER_COLOR_SHOP
		_:          return TRACKER_COLOR_NORMAL

## 원형 배지 VBox(포인터슬롯+배지+번호)를 생성해 반환한다.
## wave_data: 해당 웨이브 딕셔너리, wave_number: 1-based 표시 번호, is_current: 현재 노드 여부
func _make_badge_column(wave_data: Dictionary, wave_number: int, is_current: bool, emoji_font) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	# ── 포인터 슬롯 (현재 노드에만 ▼, 나머지는 빈 라벨로 높이 유지) ──
	var pointer_lbl := Label.new()
	pointer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	pointer_lbl.add_theme_font_size_override("font_size", 10)
	if is_current:
		pointer_lbl.text = "▼"
		pointer_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		pointer_lbl.text = " "   # 빈 슬롯 — 높이 확보
	col.add_child(pointer_lbl)

	# ── 원형 배지 (Panel + 아이콘 Label) ──
	var badge_panel := Panel.new()
	badge_panel.custom_minimum_size = Vector2(TRACKER_BADGE_SIZE, TRACKER_BADGE_SIZE)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = _wave_badge_color(wave_data)
	badge_style.corner_radius_top_left     = int(TRACKER_BADGE_SIZE / 2)
	badge_style.corner_radius_top_right    = int(TRACKER_BADGE_SIZE / 2)
	badge_style.corner_radius_bottom_left  = int(TRACKER_BADGE_SIZE / 2)
	badge_style.corner_radius_bottom_right = int(TRACKER_BADGE_SIZE / 2)
	if is_current:
		badge_style.border_width_left   = 3
		badge_style.border_width_top    = 3
		badge_style.border_width_right  = 3
		badge_style.border_width_bottom = 3
		badge_style.border_color = Color(1.0, 0.85, 0.3)  # 금색 링
	badge_panel.add_theme_stylebox_override("panel", badge_style)

	# 아이콘 Label — Panel 자식, anchors full rect + 중앙 정렬
	var icon_lbl := Label.new()
	icon_lbl.text = _wave_icon(wave_data)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	if emoji_font != null:
		icon_lbl.add_theme_font_override("font", emoji_font)
	# anchors preset: FULL_RECT (15) — Panel은 Container가 아니므로 수동 anchor
	icon_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	icon_lbl.set_anchor_and_offset(SIDE_TOP,    0.0,  0.0)
	icon_lbl.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	icon_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	badge_panel.add_child(icon_lbl)

	col.add_child(badge_panel)

	# ── 웨이브 번호 라벨 (배지 아래) ──
	var num_lbl := Label.new()
	num_lbl.text = str(wave_number)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 9)
	num_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.78))
	col.add_child(num_lbl)

	return col

func _build_wave_tracker() -> void:
	## 초기 1회 호출 — 새 스테이지의 첫 렌더는 디졸브 없이 즉시 표시
	game._last_tracker_sig = ""
	update_wave_tracker()

func update_wave_tracker() -> void:
	## 매 웨이브 호출. 표시 노드 집합이 바뀐 경우에만 크로스페이드 디졸브(보스 정지·가로 이동 없음),
	## 같은 윈도우(하이라이트만 이동)·첫 렌더는 즉시 갱신.
	var disp: Dictionary = _compute_wave_display()
	if disp.is_empty():
		for child in game.wave_tracker.get_children():
			child.queue_free()
		game._last_tracker_sig = ""
		return

	var sig: String = str(disp["indices"]) + "|" + str(disp["show_ellipsis"])
	var has_old: bool = game.wave_tracker.get_child_count() > 0

	if game._last_tracker_sig == "" or sig == game._last_tracker_sig or not has_old:
		# 첫 렌더 / 같은 윈도우(하이라이트만 이동) → 즉시
		_render_wave_tracker(disp)
	else:
		# 윈도우(표시 노드 집합) 변경 → 진짜 크로스페이드(겹쳐서 동시 페이드, 빈 순간 없음·가로 이동 없음)
		var old_wrap: Control = game.wave_tracker.get_child(0)
		var new_wrap: Control = _render_wave_tracker(disp, false)  # 기존(old) 유지, 새 wrap을 위에 겹침
		new_wrap.modulate.a = 0.0
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(old_wrap, "modulate:a", 0.0, 0.12)
		tw.tween_property(new_wrap, "modulate:a", 1.0, 0.12)
		tw.chain().tween_callback(old_wrap.queue_free)
	game._last_tracker_sig = sig

func _compute_wave_display() -> Dictionary:
	## 현재 웨이브 기준 표시할 노드 집합(항상 4칸 윈도우)을 계산. waves가 비면 {} 반환.
	var waves: Array = WaveData.CHAPTERS[game.current_chapter]["stages"][game.current_stage]["waves"]
	if waves.is_empty():
		return {}
	var boss_idx: int = waves.size() - 1
	var total: int = waves.size()
	var display_indices: Array = []
	var show_ellipsis: bool = false
	if total <= 4:
		# 전체 4칸 이하 → 전부 표시, 생략/보스핀 없음
		for i in range(0, total):
			display_indices.append(i)
	else:
		# s: 짝수 앵커, boss_idx-3까지 클램프
		var s: int = clampi(game.current_wave - (game.current_wave % 2), 0, boss_idx - 3)
		if boss_idx == s + 3:
			display_indices = [s, s + 1, s + 2, boss_idx]
			show_ellipsis = false
		else:
			display_indices = [s, s + 1, s + 2]
			show_ellipsis = true
	return {"waves": waves, "boss_idx": boss_idx, "indices": display_indices, "show_ellipsis": show_ellipsis}

func _render_wave_tracker(disp: Dictionary, clear_existing: bool = true) -> Control:
	## 캡슐형 노드 스트립(탭 칩 + 캡슐)을 재구성. clear_existing=true면 기존 자식 제거(즉시 갱신용),
	## false면 기존 wrap을 남겨둠(크로스페이드용 — 새 wrap을 위에 겹침). 생성한 wrap을 반환.
	if clear_existing:
		for child in game.wave_tracker.get_children():
			child.queue_free()

	# NotoEmoji 폰트 로드 (실패 시 null 가드)
	var emoji_font: Font = load("res://assets/fonts/NotoEmoji-Regular.ttf") as Font

	var waves: Array = disp["waves"]
	var boss_idx: int = disp["boss_idx"]
	var display_indices: Array = disp["indices"]
	var show_ellipsis: bool = disp["show_ellipsis"]

	# ── 래퍼 VBoxContainer (칩 탭 + 캡슐을 세로로 묶음) ──
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", -7)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER

	# ── 스테이지 탭 칩 ──
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.z_index = 1
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.20, 0.17, 0.26, 0.96)
	chip_style.corner_radius_top_left     = 10
	chip_style.corner_radius_top_right    = 10
	chip_style.corner_radius_bottom_left  = 3
	chip_style.corner_radius_bottom_right = 3
	chip_style.content_margin_left   = 12.0
	chip_style.content_margin_right  = 12.0
	chip_style.content_margin_top    = 3.0
	chip_style.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("panel", chip_style)
	var chip_lbl := Label.new()
	chip_lbl.text = Loc.t("stage_label") % [game.current_chapter + 1, game.current_stage + 1]
	chip_lbl.add_theme_font_size_override("font_size", 13)
	chip_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.96))
	chip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(chip_lbl)
	wrap.add_child(chip)

	# ── 캡슐 PanelContainer ──
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.10, 0.09, 0.12, 0.92)
	pill_style.corner_radius_top_left     = 18
	pill_style.corner_radius_top_right    = 18
	pill_style.corner_radius_bottom_left  = 18
	pill_style.corner_radius_bottom_right = 18
	pill_style.content_margin_left   = 10.0
	pill_style.content_margin_right  = 10.0
	pill_style.content_margin_top    = 6.0
	pill_style.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", pill_style)
	wrap.add_child(pill)
	game.wave_tracker.add_child(wrap)

	# ── HBoxContainer (노드 배지들의 가로 행) ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(hbox)

	# 윈도우 항목 생성
	for w_idx in display_indices:
		var col := _make_badge_column(waves[w_idx], w_idx + 1, w_idx == game.current_wave, emoji_font)
		# 지난 노드(현재보다 앞) → 회색 흐림
		if w_idx < game.current_wave:
			col.modulate = Color(0.5, 0.5, 0.5)
		hbox.add_child(col)

	# 생략 부호 ("…")
	if show_ellipsis:
		var ellipsis_lbl := Label.new()
		ellipsis_lbl.text = "…"
		ellipsis_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		ellipsis_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ellipsis_lbl.add_theme_font_size_override("font_size", 14)
		ellipsis_lbl.add_theme_color_override("font_color", Color(0.55, 0.53, 0.60))
		hbox.add_child(ellipsis_lbl)

	# 최종보스 고정 (생략이 있을 때만 — 연속 포함된 경우는 display_indices에 이미 포함)
	if show_ellipsis:
		var boss_col := _make_badge_column(waves[boss_idx], boss_idx + 1, boss_idx == game.current_wave, emoji_font)
		if boss_idx < game.current_wave:
			boss_col.modulate = Color(0.5, 0.5, 0.5)
		hbox.add_child(boss_col)

	return wrap

