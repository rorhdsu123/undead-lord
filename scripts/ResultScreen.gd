extends Node
## 결과 화면 도메인 컨트롤러 (Phase 2 #6) — 게임오버/클리어/결과 시퀀스/씬 전환.
## 외부 스크립트 호출 0. 상태(전투·메타 vars·결과 UI 노드)는 Game 소유 → game 역참조(GS2).
## Game 전투 로직(castle_take_damage·on_boss_killed)이 game_over/game_clear를 result_screen.X로 호출.

const WaveData = preload("res://scripts/WaveData.gd")

var game: Node = null  # Game.gd 허브 역참조

func setup(g: Node) -> void:
	game = g
	game.result_btn1.pressed.connect(_on_result_btn1_pressed)
	game.result_btn2.pressed.connect(_on_result_btn2_pressed)

func _stage_has_final_boss() -> bool:
	var wave_count: int = WaveData.stage_wave_count(game.current_chapter, game.current_stage)
	for w: int in wave_count:
		if WaveData.get_wave(game.current_chapter, game.current_stage, w).get("type", "") == "boss":
			return true
	return false

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d분 %02d초" % [mins, secs]

# 전투 종료(승/패) 시 필드 액터(적·하인) 처리를 정지 — 위치·애니·교전이 그대로 멈춘다.
# (마법 쿨다운은 Game._process가 _battle_over로 게이트)
func _freeze_actors() -> void:
	for e in game.enemies_node.get_children():
		if is_instance_valid(e):
			e.set_physics_process(false)
			e.set_process(false)
	for m in game.minions_node.get_children():
		if is_instance_valid(m):
			m.set_physics_process(false)
			m.set_process(false)

func game_over() -> void:
	game.wave_active = false
	game._battle_over = true  # 하단 조작 UI는 그대로 두되 입력만 차단 (숨기면 어색)
	game._spawn_schedule.clear()
	game._close_guide()
	game.card_panel.visible = false
	game.shop.shop_panel.visible = false

	_freeze_actors()

	# 붉은 오버레이 페이드인 → 패널 등장
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.4, 0.0, 0.0, 0.0)
	overlay.size = Vector2(480, 960)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.get_node("UI").add_child(overlay)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - game.run_start_time
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.55, 0.9)
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		overlay.queue_free()
		# 위엄 EXP 부여 (실패 완충 — 소량, 런당 1회)
		var majesty_gain: int = 0
		if not game._majesty_exp_granted:
			game._majesty_exp_granted = true
			const GAME_OVER_MAJESTY: int = 5
			GameSave.add_majesty_exp(GAME_OVER_MAJESTY)
			majesty_gain = GAME_OVER_MAJESTY
		var rewards: Array = []
		if game.crowns_this_run > 0:
			rewards.append({"icon": "👑", "qty": "+%d" % game.crowns_this_run})
		if majesty_gain > 0:
			rewards.append({"icon": "✦", "qty": "+%d" % majesty_gain})
		_show_result(
			false,
			"성이 함락됐다...",
			"스테이지 %d-%d  웨이브 %d" % [game.current_chapter + 1, game.current_stage + 1, game.current_wave + 1],
			_format_time(elapsed),
			rewards,
			"↩  다시 시작",
			"retry",
			true
		)
	)

func game_clear() -> void:
	game.wave_active = false
	game._battle_over = true  # 하단 조작 UI는 그대로 두되 입력만 차단 (숨기면 어색)
	game._spawn_schedule.clear()
	game._close_guide()
	game.card_panel.visible = false

	_freeze_actors()

	# 금빛 오버레이 페이드인 → 패널 등장
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.9, 0.8, 0.1, 0.0)
	overlay.size = Vector2(480, 960)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.get_node("UI").add_child(overlay)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - game.run_start_time
	var next_ch: int = game.current_chapter
	var next_st: int = game.current_stage + 1
	if next_st >= WaveData.chapter_stage_count(game.current_chapter):
		next_ch += 1
		next_st = 0
	var has_next: bool = next_ch < WaveData.chapter_count()
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.4, 0.6)
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		overlay.queue_free()
		# 위엄 EXP 부여 (런당 1회): 일반 클리어 +20, 보스 스테이지 +40
		var majesty_gain: int = 0
		if not game._majesty_exp_granted:
			game._majesty_exp_granted = true
			majesty_gain = 40 if _stage_has_final_boss() else 20
			GameSave.add_majesty_exp(majesty_gain)
		if has_next:
			if game.current_chapter == 0 and game.current_stage == 0:
				GameSave.tutorial_completed = true
			GameSave.current_chapter = next_ch
			GameSave.current_stage = next_st
			GameSave.save_data()
		var rewards: Array = []
		if game.crowns_this_run > 0:
			rewards.append({"icon": "👑", "qty": "+%d" % game.crowns_this_run})
		if majesty_gain > 0:
			rewards.append({"icon": "✦", "qty": "+%d" % majesty_gain})
		_show_result(
			true,
			"스테이지 클리어!",
			"%d-%d 완료" % [game.current_chapter + 1, game.current_stage + 1],
			_format_time(elapsed),
			rewards,
			"다음 스테이지",
			"next_stage",
			has_next
		)
	)

## ─────────────────────────────────────────────────────────────────────────────
## E 결과 시퀀스 헬퍼
## ─────────────────────────────────────────────────────────────────────────────

## 결과 패널 콘텐츠를 동적으로 빌드하고 등장 애니를 재생한다.
## rewards: [{"icon": "👑", "qty": "+5"}, ...] — 빈 배열이면 보상 행 생략(정사각 박스: 아이콘 상단 + 수량 하단).
## btn1_enabled=false이면 Btn1 비활성(마지막 스테이지 클리어).
func _show_result(
		is_clear: bool,
		title: String,
		subtitle: String,
		time_text: String,
		rewards: Array,
		btn1_text: String,
		btn1_action: String,
		btn1_enabled: bool
) -> void:
	# ── 팔레트 ──────────────────────────────────────────────────────────────
	var panel_bg:      Color
	var panel_border:  Color
	var banner_bg:     Color
	var banner_text:   Color
	var title_color:   Color
	if is_clear:
		panel_bg     = Color(0.20, 0.17, 0.26, 0.96)
		panel_border = Color(0.85, 0.7,  0.3,  1.0)
		banner_bg    = Color(0.78, 0.62, 0.22, 1.0)
		banner_text  = Color(0.12, 0.09, 0.04, 1.0)
		title_color  = Color(0.12, 0.09, 0.04, 1.0)
	else:
		panel_bg     = Color(0.13, 0.13, 0.17, 0.96)
		panel_border = Color(0.55, 0.2,  0.2,  1.0)
		banner_bg    = Color(0.45, 0.15, 0.15, 1.0)
		banner_text  = Color(0.95, 0.88, 0.88, 1.0)
		title_color  = Color(0.95, 0.88, 0.88, 1.0)

	# ── 이모지 폰트 (null 가드) ──────────────────────────────────────────────
	var emoji_font: Font = load("res://assets/fonts/NotoEmoji-Regular.ttf") as Font

	# ── ResultPanel 패널 스타일 갱신 ─────────────────────────────────────────
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = panel_bg
	rp_style.border_width_left   = 2
	rp_style.border_width_top    = 2
	rp_style.border_width_right  = 2
	rp_style.border_width_bottom = 2
	rp_style.border_color = panel_border
	rp_style.corner_radius_top_left     = 12
	rp_style.corner_radius_top_right    = 12
	rp_style.corner_radius_bottom_left  = 12
	rp_style.corner_radius_bottom_right = 12
	rp_style.content_margin_left   = 0.0
	rp_style.content_margin_right  = 0.0
	rp_style.content_margin_top    = 0.0
	rp_style.content_margin_bottom = 0.0
	game.result_panel.add_theme_stylebox_override("panel", rp_style)

	# ── 이전 동적 자식 제거 (Btn1/Btn2는 .tscn 정적 노드 — 건드리지 않음) ───
	for child in game.result_panel.get_children():
		if child != game.result_btn1 and child != game.result_btn2:
			child.queue_free()

	# ── 콘텐츠 VBox ─────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	# 콘텐츠 컨테이너는 패널 전체를 덮으므로 입력 통과(IGNORE) — 안 그러면 하단 버튼 클릭을 가로챔
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.result_panel.add_child(vbox)

	# ── 리본 배너 타이틀 ─────────────────────────────────────────────────────
	var banner_pc := PanelContainer.new()
	banner_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = banner_bg
	banner_style.corner_radius_top_left     = 10
	banner_style.corner_radius_top_right    = 10
	banner_style.corner_radius_bottom_left  = 0
	banner_style.corner_radius_bottom_right = 0
	banner_style.content_margin_left   = 12.0
	banner_style.content_margin_right  = 12.0
	banner_style.content_margin_top    = 14.0
	banner_style.content_margin_bottom = 14.0
	banner_pc.add_theme_stylebox_override("panel", banner_style)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", title_color)
	banner_pc.add_child(title_lbl)
	vbox.add_child(banner_pc)

	# ── 마왕 일러스트 (배너 바로 아래, body 위) ───────────────────────────────
	const _RESULT_ILLUST_SIZE: float = 150.0   # 플테 조정 대상: 결과창 일러스트 크기 (≤180이라야 보상행이 버튼 위에 안전)
	var illust_tex: Texture2D
	if is_clear:
		illust_tex = preload("res://assets/characters/DemonLord/victory.png")
	else:
		illust_tex = preload("res://assets/characters/DemonLord/defeat.png")
	var illust_rect := TextureRect.new()
	illust_rect.texture = illust_tex
	illust_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	illust_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illust_rect.custom_minimum_size = Vector2(_RESULT_ILLUST_SIZE, _RESULT_ILLUST_SIZE)
	illust_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	illust_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(illust_rect)
	# 가벼운 scale-pop 등장
	illust_rect.pivot_offset = Vector2(_RESULT_ILLUST_SIZE * 0.5, _RESULT_ILLUST_SIZE * 0.5)
	illust_rect.scale = Vector2(0.85, 0.85)
	illust_rect.modulate.a = 0.0
	var illust_tw: Tween = create_tween()
	illust_tw.set_parallel(true)
	illust_tw.tween_property(illust_rect, "scale", Vector2(1.0, 1.0), 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	illust_tw.tween_property(illust_rect, "modulate:a", 1.0, 0.22)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	# ── 본문 패딩 컨테이너 ───────────────────────────────────────────────────
	var body_margin := MarginContainer.new()
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 하단 버튼 영역까지 차지하므로 입력 통과
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left",   20)
	body_margin.add_theme_constant_override("margin_right",  20)
	body_margin.add_theme_constant_override("margin_top",    16)
	# 하단 여백: 버튼 2개(약 116px) 영역 확보
	body_margin.add_theme_constant_override("margin_bottom", 120)
	vbox.add_child(body_margin)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 6)
	body_margin.add_child(body_vbox)

	# 부제
	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.90, 1.0))
	body_vbox.add_child(sub_lbl)

	# 기록 시간
	var time_lbl := Label.new()
	time_lbl.text = time_text
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 14)
	time_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.88, 1.0))
	body_vbox.add_child(time_lbl)

	# ── 보상 구분선 + 슬롯 (rewards 배열이 비어있으면 생략) ──────────────────
	if rewards.size() > 0:
		# 구분선: [─────] 보상 [─────]
		var divider_hbox := HBoxContainer.new()
		divider_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		divider_hbox.add_theme_constant_override("separation", 8)
		divider_hbox.custom_minimum_size = Vector2(0, 20)
		var div_left := ColorRect.new()
		div_left.color = Color(0.55, 0.50, 0.68, 0.55)
		div_left.custom_minimum_size = Vector2(50, 1)
		div_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		div_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		divider_hbox.add_child(div_left)
		var div_lbl := Label.new()
		div_lbl.text = "보상"
		div_lbl.add_theme_font_size_override("font_size", 12)
		div_lbl.add_theme_color_override("font_color", Color(0.70, 0.67, 0.80, 0.85))
		divider_hbox.add_child(div_lbl)
		var div_right := ColorRect.new()
		div_right.color = Color(0.55, 0.50, 0.68, 0.55)
		div_right.custom_minimum_size = Vector2(50, 1)
		div_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		div_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		divider_hbox.add_child(div_right)
		body_vbox.add_child(divider_hbox)

		# 보상 슬롯 HBox — 정사각 박스에 아이콘(상단) + 수량(하단)
		var reward_hbox := HBoxContainer.new()
		reward_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_hbox.add_theme_constant_override("separation", 12)
		for r: Dictionary in rewards:
			var slot_pc := PanelContainer.new()
			var slot_style := StyleBoxFlat.new()
			slot_style.bg_color = Color(0.94, 0.91, 0.84, 0.97)  # 전리품 프레임 — 밝게(아이콘 부각)
			slot_style.border_width_left   = 2
			slot_style.border_width_top    = 2
			slot_style.border_width_right  = 2
			slot_style.border_width_bottom = 2
			slot_style.border_color = Color(0.85, 0.70, 0.30, 1.0)  # 골드 테두리
			slot_style.corner_radius_top_left     = 8
			slot_style.corner_radius_top_right    = 8
			slot_style.corner_radius_bottom_left  = 8
			slot_style.corner_radius_bottom_right = 8
			slot_style.content_margin_left   = 6.0
			slot_style.content_margin_right  = 6.0
			slot_style.content_margin_top    = 6.0
			slot_style.content_margin_bottom = 5.0
			slot_pc.add_theme_stylebox_override("panel", slot_style)
			# 세로 스택: 아이콘(EXPAND으로 상단 채움) → 수량(하단)
			var slot_vbox := VBoxContainer.new()
			slot_vbox.custom_minimum_size = Vector2(58, 58)
			slot_vbox.add_theme_constant_override("separation", 1)
			var icon_lbl := Label.new()
			icon_lbl.text = r["icon"]
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			icon_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
			icon_lbl.add_theme_font_size_override("font_size", 28)
			if emoji_font != null:
				icon_lbl.add_theme_font_override("font", emoji_font)
			slot_vbox.add_child(icon_lbl)
			var qty_lbl := Label.new()
			qty_lbl.text = r["qty"]
			qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			qty_lbl.add_theme_font_size_override("font_size", 15)
			qty_lbl.add_theme_color_override("font_color", Color(0.25, 0.17, 0.04, 1.0))
			slot_vbox.add_child(qty_lbl)
			slot_pc.add_child(slot_vbox)
			reward_hbox.add_child(slot_pc)
		body_vbox.add_child(reward_hbox)

	# ── 버튼 위계 ────────────────────────────────────────────────────────────
	# Btn1 (주행동) — 골드 강조 스타일
	game.result_btn1.text = btn1_text
	game.result_btn1.disabled = not btn1_enabled
	game.result_btn1.set_meta("action", btn1_action)
	game.result_btn1.add_theme_font_size_override("font_size", 17)
	# Btn1 normal
	var b1n := StyleBoxFlat.new()
	b1n.bg_color = Color(0.60, 0.45, 0.10, 0.95) if btn1_enabled else Color(0.20, 0.18, 0.14, 0.85)
	b1n.border_width_left = 2; b1n.border_width_top = 2
	b1n.border_width_right = 2; b1n.border_width_bottom = 2
	b1n.border_color = Color(1.0, 0.85, 0.30, 1.0) if btn1_enabled else Color(0.40, 0.36, 0.25, 0.70)
	b1n.corner_radius_top_left = 8; b1n.corner_radius_top_right = 8
	b1n.corner_radius_bottom_left = 8; b1n.corner_radius_bottom_right = 8
	b1n.content_margin_left = 12.0; b1n.content_margin_right = 12.0
	b1n.content_margin_top = 10.0; b1n.content_margin_bottom = 10.0
	game.result_btn1.add_theme_stylebox_override("normal", b1n)
	# 버튼 동작 통일 — hover/pressed 색 변화 없음(normal 재사용), 눌림은 바운스(페이드 동안 보임)
	game.result_btn1.add_theme_stylebox_override("hover", b1n)
	game.result_btn1.add_theme_stylebox_override("pressed", b1n)
	game.result_btn1.add_theme_stylebox_override("focus", b1n)
	# Btn1 disabled
	var b1d := StyleBoxFlat.new()
	b1d.bg_color = Color(0.14, 0.13, 0.10, 0.80)
	b1d.border_width_left = 1; b1d.border_width_top = 1
	b1d.border_width_right = 1; b1d.border_width_bottom = 1
	b1d.border_color = Color(0.35, 0.33, 0.25, 0.60)
	b1d.corner_radius_top_left = 8; b1d.corner_radius_top_right = 8
	b1d.corner_radius_bottom_left = 8; b1d.corner_radius_bottom_right = 8
	b1d.content_margin_left = 12.0; b1d.content_margin_right = 12.0
	b1d.content_margin_top = 10.0; b1d.content_margin_bottom = 10.0
	game.result_btn1.add_theme_stylebox_override("disabled", b1d)
	var b1_font: Color = Color(1.0, 0.92, 0.65, 1.0) if btn1_enabled else Color(0.50, 0.47, 0.38, 1.0)
	game.result_btn1.add_theme_color_override("font_color",         b1_font)
	game.result_btn1.add_theme_color_override("font_hover_color",   b1_font)  # hover 시 글자색 변화 차단
	game.result_btn1.add_theme_color_override("font_pressed_color", b1_font)
	game.result_btn1.add_theme_color_override("font_focus_color",   b1_font)
	game.result_btn1.add_theme_color_override("font_color_disabled", Color(0.50, 0.47, 0.38, 1.0))

	# Btn2 (보조) — 차분한 보라/회색
	game.result_btn2.text = "로비로 돌아가기"
	game.result_btn2.disabled = false
	game.result_btn2.add_theme_font_size_override("font_size", 15)
	var b2n := StyleBoxFlat.new()
	b2n.bg_color = Color(0.18, 0.16, 0.24, 0.88)
	b2n.border_width_left = 1; b2n.border_width_top = 1
	b2n.border_width_right = 1; b2n.border_width_bottom = 1
	b2n.border_color = Color(0.55, 0.50, 0.68, 0.80)
	b2n.corner_radius_top_left = 8; b2n.corner_radius_top_right = 8
	b2n.corner_radius_bottom_left = 8; b2n.corner_radius_bottom_right = 8
	b2n.content_margin_left = 12.0; b2n.content_margin_right = 12.0
	b2n.content_margin_top = 8.0; b2n.content_margin_bottom = 8.0
	game.result_btn2.add_theme_stylebox_override("normal", b2n)
	# 버튼 동작 통일 — hover/pressed 색 변화 없음(normal 재사용)
	game.result_btn2.add_theme_stylebox_override("hover", b2n)
	game.result_btn2.add_theme_stylebox_override("pressed", b2n)
	game.result_btn2.add_theme_stylebox_override("focus", b2n)
	var b2_font: Color = Color(0.82, 0.80, 0.90, 1.0)
	game.result_btn2.add_theme_color_override("font_color",         b2_font)
	game.result_btn2.add_theme_color_override("font_hover_color",   b2_font)
	game.result_btn2.add_theme_color_override("font_pressed_color", b2_font)
	game.result_btn2.add_theme_color_override("font_focus_color",   b2_font)

	# ── 모달 + 패널 표시 ────────────────────────────────────────────────────
	game.modal_dim.visible = true
	game.result_panel.visible = true

	# ── 패널 등장 애니 (scale pop + fade) ────────────────────────────────────
	game.result_panel.pivot_offset = game.result_panel.size / 2.0
	game.result_panel.modulate.a = 0.0
	game.result_panel.scale = Vector2(0.9, 0.9)
	var anim_tw: Tween = create_tween()
	anim_tw.set_parallel(true)
	anim_tw.tween_property(game.result_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tw.tween_property(game.result_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# ── 콘페티 (클리어 전용) ─────────────────────────────────────────────────
	# 콘페티: 임시 플레이스홀더 — 추후 아트 리소스로 교체
	if is_clear:
		_spawn_confetti()

func _spawn_confetti() -> void:
	# 콘페티: 임시 플레이스홀더 — 추후 아트 리소스로 교체
	var confetti_colors: Array = [
		Color(1.0, 0.85, 0.25), Color(0.95, 0.45, 0.45),
		Color(0.45, 0.85, 0.95), Color(0.65, 0.95, 0.50),
		Color(0.90, 0.55, 0.90), Color(1.0, 1.0, 1.0),
	]
	for _i in 22:
		var piece := ColorRect.new()
		piece.size = Vector2(randf_range(5.0, 10.0), randf_range(4.0, 8.0))
		piece.color = confetti_colors[randi() % confetti_colors.size()]
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.position = Vector2(randf_range(0.0, 480.0), randf_range(-20.0, -5.0))
		piece.rotation = randf_range(0.0, TAU)
		game.get_node("UI").add_child(piece)
		var fall_tw: Tween = create_tween()
		var fall_y: float = randf_range(700.0, 980.0)
		var fall_dur: float = randf_range(1.2, 2.2)
		fall_tw.set_parallel(true)
		fall_tw.tween_property(piece, "position:y", fall_y, fall_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tw.tween_property(piece, "rotation", piece.rotation + randf_range(4.0, 10.0), fall_dur)
		fall_tw.tween_property(piece, "modulate:a", 0.0, fall_dur).set_delay(fall_dur * 0.6)
		fall_tw.tween_callback(piece.queue_free).set_delay(fall_dur)

func _fade_in() -> void:
	game.fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(game.fade_rect, "color:a", 0.0, 0.4)

func _on_result_btn1_pressed() -> void:
	var action: String = game.result_btn1.get_meta("action", "retry")
	if action == "next_stage":
		GameSave.start_chapter = GameSave.current_chapter
		GameSave.start_stage = GameSave.current_stage
	else:
		GameSave.start_chapter = game.current_chapter
		GameSave.start_stage = game.current_stage
	_fade_to_scene("res://scenes/Game.tscn")

func _on_result_btn2_pressed() -> void:
	_fade_to_scene("res://scenes/Lobby.tscn")

func _fade_to_scene(path: String) -> void:
	game.result_btn1.disabled = true
	game.result_btn2.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(game.fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(path)
	)

