extends Node
## 강화(마물 업그레이드) UI 도메인 컨트롤러 (Phase 2 #4) — 강화 버튼 + 팝업 + 강화 적용.
## 데이터 = MinionData.gd. 공유 run-state(souls·hire_levels·강화 UI 노드 등)는 Game 소유 → game 역참조(GS2).
## Game._ready서 new→add_child→setup(self)→_build_upgrade_ui.
## 외부 진입점: _build_upgrade_ui · _set_upgrade_btn_visible · _close_upgrade_popup · _refresh_upgrade_popup.

const MinionData = preload("res://scripts/data/MinionData.gd")

var game: Node = null  # Game.gd 허브 역참조

func setup(g: Node) -> void:
	game = g

func _build_upgrade_ui() -> void:
	var parent: Node = game.summon_container.get_parent()

	# ── 강화 버튼 ──────────────────────────────────────────────
	# 버튼 텍스트는 비우고, 안에 [▲ 강화] HBox를 풀-렉트 중앙정렬로 배치.
	# (▲만 초록·텍스트는 보라흰 → 단일 라벨로 색 분리 불가하므로 자식 2개. 소환 버튼 자식라벨 패턴과 동일)
	game._upgrade_btn = Button.new()
	game._upgrade_btn.focus_mode = Control.FOCUS_NONE
	game._upgrade_btn.text = ""
	game._apply_button_styleboxes(game._upgrade_btn)
	game._add_button_press_bounce(game._upgrade_btn)
	game._upgrade_btn.pressed.connect(_toggle_upgrade_popup)
	parent.add_child(game._upgrade_btn)

	var upg_hbox: HBoxContainer = HBoxContainer.new()
	upg_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 버튼 탭 입력 통과
	upg_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	upg_hbox.add_theme_constant_override("separation", 5)
	upg_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._upgrade_btn.add_child(upg_hbox)

	# ▲ 아이콘 (초록)
	game._upg_icon = Label.new()
	game._upg_icon.text = Loc.t("upgrade_icon")
	game._upg_icon.add_theme_font_size_override("font_size", 14)
	game._upg_icon.add_theme_color_override("font_color", Color(0.4, 0.85, 0.35, 1.0))
	game._upg_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game._upg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upg_hbox.add_child(game._upg_icon)

	# "강화" 텍스트 (보라흰)
	var upg_text: Label = Label.new()
	upg_text.text = Loc.t("upgrade_btn_label")
	upg_text.add_theme_font_size_override("font_size", 15)
	upg_text.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
	upg_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upg_hbox.add_child(upg_text)

	# ── 팝업 캐처 — 팝업보다 먼저 add_child(뒤에 깔림) ─────────
	game._upgrade_popup_catcher = Control.new()
	game._upgrade_popup_catcher.name = "UpgradePopupCatcher"
	game._upgrade_popup_catcher.anchor_right = 1.0
	game._upgrade_popup_catcher.anchor_bottom = 1.0
	game._upgrade_popup_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	game._upgrade_popup_catcher.visible = false
	# 딤 배경 없음 — 팝업 중에도 전투 상황이 그대로 보이도록. 투명 캐처는 rect로 바깥 탭만 잡음.
	game._upgrade_popup_catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.is_pressed() and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_upgrade_popup()
	)
	parent.add_child(game._upgrade_popup_catcher)

	# ── 팝업 패널 ──────────────────────────────────────────────
	game._upgrade_popup = PanelContainer.new()
	game._upgrade_popup.name = "UpgradePopup"
	game._upgrade_popup.visible = false
	game._upgrade_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	# 팝업 StyleBox
	var popup_sb: StyleBoxFlat = StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.93, 0.88, 0.75, 1.0)  # 양피지 크림 — 어두운 트레이와 확실히 구분(별도 팝업 인지)
	popup_sb.border_color = Color(0.42, 0.30, 0.18, 1.0)  # 따뜻한 갈색 테두리(양피지 프레임)
	popup_sb.set_border_width_all(game.UI_POPUP_BORDER_W)
	popup_sb.set_corner_radius_all(game.UI_POPUP_CORNER)
	popup_sb.content_margin_left   = 12.0
	popup_sb.content_margin_right  = 12.0
	popup_sb.content_margin_top    = 10.0
	popup_sb.content_margin_bottom = 10.0
	game._upgrade_popup.add_theme_stylebox_override("panel", popup_sb)
	parent.add_child(game._upgrade_popup)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER  # 커진 팝업 안에서 콘텐츠 세로 중앙
	game._upgrade_popup.add_child(vbox)

	# ── 상단: 골드 캡슐(중앙) + ✕(우) — RD19 레퍼런스 폴리싱 ─────────
	# 제목 텍스트는 폐기(레퍼런스처럼 자원 캡슐이 헤더 역할). 캡슐은 HUD 캡슐과 동일 스타일.
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 0)
	vbox.add_child(top_row)

	# 좌측 패드(우측 ✕ 폭과 대칭 → 캡슐이 진짜 중앙) + 좌 expand 스페이서
	var top_pad_l: Control = Control.new()
	top_pad_l.custom_minimum_size = Vector2(30.0, 0.0)  # 우측 ✕(30) 폭과 대칭 → 캡슐 중앙
	top_pad_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_pad_l)
	var top_sp_l: Control = Control.new()
	top_sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_sp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_sp_l)

	# 골드 캡슐 (PanelContainer — 콘텐츠에 맞춰 hug)
	var gold_cap: PanelContainer = PanelContainer.new()
	gold_cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gold_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold_cap_sb: StyleBoxFlat = game._make_capsule_stylebox()
	gold_cap_sb.content_margin_left   = 12.0
	gold_cap_sb.content_margin_right  = 12.0
	gold_cap_sb.content_margin_top    = 3.0
	gold_cap_sb.content_margin_bottom = 3.0
	gold_cap.add_theme_stylebox_override("panel", gold_cap_sb)
	top_row.add_child(gold_cap)

	var gold_cap_hbox: HBoxContainer = HBoxContainer.new()
	gold_cap_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_cap_hbox.add_theme_constant_override("separation", 5)
	gold_cap_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_cap.add_child(gold_cap_hbox)

	var gold_cap_icon: Label = Label.new()
	gold_cap_icon.text = "●"
	gold_cap_icon.add_theme_font_size_override("font_size", 16)
	gold_cap_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	gold_cap_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_cap_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_cap_hbox.add_child(gold_cap_icon)

	var gold_hdr_lbl: Label = Label.new()
	gold_hdr_lbl.name = "PopupGoldLabel"
	gold_hdr_lbl.add_theme_font_size_override("font_size", 16)
	gold_hdr_lbl.add_theme_color_override("font_color", Color(0.96, 0.95, 1.0, 1.0))
	gold_hdr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_hdr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_cap_hbox.add_child(gold_hdr_lbl)

	# 우 expand 스페이서 + ✕
	var top_sp_r: Control = Control.new()
	top_sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_sp_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_sp_r)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(30.0, 30.0)
	close_btn.add_theme_font_size_override("font_size", 20)
	var close_font_col: Color = Color(0.36, 0.26, 0.16, 1.0)  # 크림 배경 위 진한 갈색 — 플랫 코너 ✕
	# hover 색 변화 없음 — 배경(StyleBoxEmpty)뿐 아니라 글자색 상태별로도 동일하게 고정.
	close_btn.add_theme_color_override("font_color",         close_font_col)
	close_btn.add_theme_color_override("font_hover_color",   close_font_col)
	close_btn.add_theme_color_override("font_pressed_color", close_font_col)
	close_btn.add_theme_color_override("font_focus_color",   close_font_col)
	# 플랫 ✕ — 원형 배경 없이 글리프만(레퍼런스 코너형)
	var close_empty: StyleBoxEmpty = StyleBoxEmpty.new()
	close_btn.add_theme_stylebox_override("normal",   close_empty)
	close_btn.add_theme_stylebox_override("hover",    close_empty)
	close_btn.add_theme_stylebox_override("pressed",  close_empty)
	close_btn.add_theme_stylebox_override("focus",    close_empty)
	# 닫기 동작 통일 — 클릭 시 눌렸다 돌아오는 바운스를 다 보여준 뒤 닫음.
	# (즉시 닫으면 팝업이 사라져 바운스가 안 보이므로, 풀 바운스 후 close 콜백)
	close_btn.pressed.connect(func() -> void:
		if not is_instance_valid(close_btn):
			return
		close_btn.pivot_offset = close_btn.size * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(close_btn, "scale", Vector2(0.82, 0.82), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(close_btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_close_upgrade_popup)
	)
	top_row.add_child(close_btn)

	# ── 카드 행 — 탱크/전사/궁수 가로 배치 ───────────────────────
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	vbox.add_child(card_row)

	var type_loc_keys: Dictionary = {
		"warrior": "upgrade_minion_warrior",
		"archer":  "upgrade_minion_archer",
		"tank":    "upgrade_minion_tank",
	}
	# 아이콘 슬롯 종별 구분색 (아트 입고 전 플레이스홀더)
	var icon_accent: Dictionary = {
		"warrior": Color(0.55, 0.38, 0.80, 0.85),
		"archer":  Color(0.35, 0.60, 0.80, 0.85),
		"tank":    Color(0.70, 0.45, 0.30, 0.85),
	}
	var display_order: Array = ["warrior", "archer", "tank"]  # 소환 버튼 순서와 일치 (전사/궁수/탱크)
	for type_id in display_order:
		var card: VBoxContainer = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 5)
		card_row.add_child(card)

		# 종류명 라벨
		var name_lbl: Label = Label.new()
		name_lbl.text = Loc.t(type_loc_keys[type_id])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.28, 0.20, 0.14, 1.0))  # 크림 배경 위 진한 갈색
		card.add_child(name_lbl)

		# 아이콘 슬롯 (44×44 플레이스홀더 패널)
		var icon_slot: Panel = Panel.new()
		icon_slot.custom_minimum_size = Vector2(74.0, 74.0)  # 풀폭 팝업 — 넉넉한 아이콘 슬롯
		icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icon_sb: StyleBoxFlat = StyleBoxFlat.new()
		icon_sb.bg_color = Color(0.10, 0.09, 0.14, 0.92)
		icon_sb.border_color = icon_accent[type_id]
		icon_sb.set_border_width_all(2)
		icon_sb.set_corner_radius_all(6)
		icon_slot.add_theme_stylebox_override("panel", icon_sb)
		# 종별 구분 색점 (ColorRect, 중앙에 작게)
		var dot: ColorRect = ColorRect.new()
		dot.color = icon_accent[type_id]
		dot.custom_minimum_size = Vector2(20.0, 20.0)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		icon_slot.add_child(dot)
		card.add_child(icon_slot)

		# Lv 라벨
		var lv_lbl: Label = Label.new()
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_lbl.add_theme_font_size_override("font_size", 15)
		lv_lbl.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 1.0))  # 크림 배경 위 갈색
		lv_lbl.name = "LvLabel_" + type_id
		card.add_child(lv_lbl)

		# 코스트 알약 버튼 — 다크 배경 + 골드 테두리. 내부 [● 노랑][숫자]로 골드 아이콘 색 통일.
		var upg_btn: Button = Button.new()
		upg_btn.focus_mode = Control.FOCUS_NONE
		upg_btn.text = ""
		upg_btn.name = "UpgBtn_" + type_id
		upg_btn.size_flags_horizontal = Control.SIZE_FILL  # 카드 폭 채움 → 버튼 사이 간격은 카드 간격(8)만
		upg_btn.custom_minimum_size = Vector2(0.0, 36.0)   # 높이 키움(30→36), 가로는 카드 폭 채움
		# RD19 — hover/pressed 색 제거(바운스가 피드백). 팝업보다 밝은 보라 + 골드 보더로 "올라온 알약".
		var pill_normal: StyleBoxFlat = game._make_button_stylebox(Color(0.24, 0.20, 0.34, 1.0), game.UI_BTN_GOLD, game.UI_COST_PILL_CORNER, 1)
		var pill_dis:    StyleBoxFlat = game._make_button_stylebox(Color(0.18, 0.15, 0.24, 1.0), Color(0.40, 0.35, 0.20, 0.60), game.UI_COST_PILL_CORNER, 1)
		upg_btn.add_theme_stylebox_override("normal",   pill_normal)
		upg_btn.add_theme_stylebox_override("hover",    pill_normal)
		upg_btn.add_theme_stylebox_override("pressed",  pill_normal)
		upg_btn.add_theme_stylebox_override("disabled", pill_dis)
		upg_btn.add_theme_stylebox_override("focus",    pill_normal)
		# 눌림 바운스는 _on_upgrade_pressed 성공 경로에서만 재생(골드 부족 시 안 눌림)
		upg_btn.pressed.connect(func(): _on_upgrade_pressed(type_id, upg_btn))
		card.add_child(upg_btn)
		# 내부 [● 노랑][비용 숫자] 중앙정렬
		var pill_hbox: HBoxContainer = HBoxContainer.new()
		pill_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		pill_hbox.add_theme_constant_override("separation", 3)
		pill_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		upg_btn.add_child(pill_hbox)
		var pill_icon: Label = Label.new()
		pill_icon.text = "●"  # 노란 동그라미 (통일)
		pill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_icon.add_theme_font_size_override("font_size", 15)
		pill_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
		pill_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill_hbox.add_child(pill_icon)
		var pill_num: Label = Label.new()
		pill_num.name = "UpgCost_" + type_id
		pill_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_num.add_theme_font_size_override("font_size", 16)
		pill_num.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
		pill_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill_hbox.add_child(pill_num)

	# ── 강화 팝업 마왕 장식 (좌상단 빼꼼 + 짧은 바크) — 팝업의 형제로 추가, _open에서 배치/표시 ──
	var dl_tex: Texture2D = preload("res://assets/characters/DemonLord/victory.png")  # 전신(900×900) — 작게, 캐릭터 전체 노출
	var dl_h: float = 140.0   # 표시 박스 높이(노브) — 전신 작게. 900×900 정사각이라 dl_w=dl_h
	var dl_w: float = dl_h * float(dl_tex.get_width()) / float(dl_tex.get_height())
	game._upgrade_demon = TextureRect.new()
	game._upgrade_demon.texture = dl_tex
	# expand_mode=IGNORE_SIZE: 기본값(KEEP_SIZE)은 최소크기를 텍스처 원본(900×900)으로 고정 → size 무시됨.
	# IGNORE_SIZE로 dl_w/dl_h(140) 박스에 맞춰 축소.
	game._upgrade_demon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game._upgrade_demon.custom_minimum_size = Vector2(dl_w, dl_h)
	game._upgrade_demon.size = Vector2(dl_w, dl_h)
	game._upgrade_demon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # 종횡비 유지, 박스 중앙
	game._upgrade_demon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._upgrade_demon.visible = false
	parent.add_child(game._upgrade_demon)

	game._upgrade_demon_bubble = Panel.new()
	var bub_sb: StyleBoxFlat = StyleBoxFlat.new()
	bub_sb.bg_color = Color(0.97, 0.93, 0.82, 1.0)        # 밝은 크림 말풍선
	bub_sb.border_color = Color(0.42, 0.30, 0.18, 1.0)
	bub_sb.set_border_width_all(2)
	bub_sb.set_corner_radius_all(8)
	game._upgrade_demon_bubble.add_theme_stylebox_override("panel", bub_sb)
	game._upgrade_demon_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._upgrade_demon_bubble.visible = false
	parent.add_child(game._upgrade_demon_bubble)
	var bub_lbl: Label = Label.new()
	bub_lbl.text = Loc.t("upgrade_demon_bark")
	bub_lbl.add_theme_font_size_override("font_size", 12)
	bub_lbl.add_theme_color_override("font_color", Color(0.30, 0.22, 0.14, 1.0))
	bub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bub_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._upgrade_demon_bubble.add_child(bub_lbl)

	_refresh_upgrade_popup()

## 강화 버튼 가시성 토글 (▲ 아이콘은 버튼 내부 자식 → 자동 연동)
func _set_upgrade_btn_visible(v: bool) -> void:
	if is_instance_valid(game._upgrade_btn):
		game._upgrade_btn.visible = v

func _toggle_upgrade_popup() -> void:
	if game._battle_over:
		return  # 결과 화면: 강화 버튼 보이되 눌러도 무반응
	if not is_instance_valid(game._upgrade_popup):
		return
	if game._upgrade_popup.visible:
		_close_upgrade_popup()
	else:
		_open_upgrade_popup()

func _open_upgrade_popup() -> void:
	if not is_instance_valid(game._upgrade_popup):
		return
	# 강화 튜토리얼 팁 닫기 — 팝업이 열리면 강화 버튼이 숨겨져 스포트라이트가 어긋나므로,
	# 플레이어가 지시를 따라 팝업을 연 시점에 팁을 정리한다.
	game._close_guide()
	_refresh_upgrade_popup()
	# 캐처 먼저 표시 (팝업이 위에 그려짐)
	# move_to_front으로 마법 버튼 등 다른 UI 형제 위로 올림 (캐처→팝업 순서로 팝업이 최상단)
	if is_instance_valid(game._upgrade_popup_catcher):
		game._upgrade_popup_catcher.visible = true
		game._upgrade_popup_catcher.move_to_front()
	game._upgrade_popup.visible = true
	game._upgrade_popup.move_to_front()
	# 팝업 헤더에 골드를 표시하므로 하단 자원 캡슐은 숨김 (팝업 좌측에 ● 아이콘 노출 방지)
	if is_instance_valid(game._resource_capsule) and game._resource_capsule.visible:
		game._gold_hud_hidden_by_popup = true
		game._set_resource_hud_visible(false)
	var vp: Vector2 = game.get_viewport_rect().size
	const POPUP_SIDE: float    = 24.0   # 좌우 마진 — 뒤 트레이(x4~476)가 양옆 살짝 보이게(레퍼런스 여백)
	const POPUP_BOTTOM: float   = 8.0   # 화면 바닥에서 띄울 여백 — 라운드 모서리 노출로 "별도로 떠오른 시트" 인지
	const POPUP_TOP_MIN: float = 700.0  # 안전 상한 — 더 위로는 안 올라가 성/전투 보호
	var content_h: float = game._upgrade_popup.get_combined_minimum_size().y
	if content_h < 120.0:
		content_h = 178.0  # 폴백 (min 미산정 시)
	# 바닥을 화면 하단에 앵커 → 콘텐츠 높이만큼 위로 자람(높이 부족 오버플로우·강화버튼 가림 방지).
	# 트레이(y753~960) 위에 떠서 도크 버튼을 덮고, 플레이 영역(<753)은 가리지 않음.
	var bottom_y: float = vp.y - POPUP_BOTTOM
	var top_y: float = max(POPUP_TOP_MIN, bottom_y - content_h)
	game._upgrade_popup.position = Vector2(POPUP_SIDE, top_y)
	game._upgrade_popup.size = Vector2(vp.x - POPUP_SIDE * 2.0, bottom_y - top_y)
	# 마왕 장식 — 팝업 좌상단 위로 빼꼼, 바크 말풍선
	if is_instance_valid(game._upgrade_demon):
		# 좌상단에서 팝업 위로 빼꼼 — 캐릭터가 팝업 위에 서듯이 (노브: y오프셋 94)
		game._upgrade_demon.position = Vector2(POPUP_SIDE - 6.0, top_y - 94.0)
		game._upgrade_demon.visible = true
		game._upgrade_demon.move_to_front()
	if is_instance_valid(game._upgrade_demon_bubble):
		var bub_w: float = 84.0
		var bub_h: float = 26.0
		game._upgrade_demon_bubble.size = Vector2(bub_w, bub_h)
		# 마왕 머리 위 중앙에 작게 (노브: y의 +18은 머리끝 맞춤 보정)
		game._upgrade_demon_bubble.position = Vector2(
			game._upgrade_demon.position.x + (game._upgrade_demon.size.x - bub_w) * 0.5,
			game._upgrade_demon.position.y + 18.0 - bub_h)
		game._upgrade_demon_bubble.visible = true
		game._upgrade_demon_bubble.move_to_front()

func _close_upgrade_popup() -> void:
	if is_instance_valid(game._upgrade_popup):
		game._upgrade_popup.visible = false
	if is_instance_valid(game._upgrade_popup_catcher):
		game._upgrade_popup_catcher.visible = false
	if is_instance_valid(game._upgrade_demon):
		game._upgrade_demon.visible = false
	if is_instance_valid(game._upgrade_demon_bubble):
		game._upgrade_demon_bubble.visible = false
	# 팝업이 숨겼던 하단 자원 캡슐 복원 (상점 진입 등 다른 곳에서 끈 경우는 건드리지 않음)
	if game._gold_hud_hidden_by_popup:
		game._gold_hud_hidden_by_popup = false
		game._set_resource_hud_visible(true)  # MAX 배지 동기화 포함

func _refresh_upgrade_popup() -> void:
	if not is_instance_valid(game._upgrade_popup):
		return
	# 헤더 현재 골드 표시
	var gold_hdr: Label = game._upgrade_popup.find_child("PopupGoldLabel", true, false)
	if is_instance_valid(gold_hdr):
		gold_hdr.text = "%d" % game.souls  # ● 아이콘은 캡슐 내 별도 라벨
	# 카드별 갱신
	for type_id in ["warrior", "archer", "tank"]:
		var lv: int = game.hire_levels.get(type_id, 1)
		var cost: int = MinionData.HIRE_UPGRADE_COST_BASE * lv
		var lv_lbl: Label = game._upgrade_popup.find_child("LvLabel_" + type_id, true, false)
		if is_instance_valid(lv_lbl):
			lv_lbl.text = Loc.t("upgrade_card_lv") % lv
		var upg_btn: Button = game._upgrade_popup.find_child("UpgBtn_" + type_id, true, false)
		if is_instance_valid(upg_btn):
			# 항상 활성 — 누름 가드는 _on_upgrade_pressed 의 "if game.souls < cost: return" 이 처리
			upg_btn.disabled = false
		# 비용 숫자 라벨 갱신 (●은 항상 노란색, 숫자만 색 변동)
		var upg_num: Label = game._upgrade_popup.find_child("UpgCost_" + type_id, true, false)
		if is_instance_valid(upg_num):
			upg_num.text = "%d" % cost
			var can_afford: bool = game.souls >= cost
			if can_afford:
				upg_num.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
			else:
				upg_num.add_theme_color_override("font_color", game.UI_COST_SHORT)

func _on_upgrade_pressed(type_id: String, btn: Button = null) -> void:
	if not type_id in game.hire_levels:
		return
	var lv: int = game.hire_levels[type_id]
	var cost: int = MinionData.HIRE_UPGRADE_COST_BASE * lv
	if game.souls < cost:
		return  # 골드 부족 — 눌림 바운스도 재생 안 됨
	# 게이트 통과 — 성공 시에만 눌림 피드백
	game._play_button_bounce(btn)
	game.souls -= cost
	game._update_souls_ui()
	game.hire_levels[type_id] = lv + 1
	# 현재 살아있는 그 종 유닛 전부 스탯 즉시 갱신
	_apply_upgrade_to_alive_minions(type_id, lv + 1)
	_refresh_upgrade_popup()

func _apply_upgrade_to_alive_minions(type_id: String, new_lv: int) -> void:
	# 강화 시 현재 살아있는 그 종 유닛 level↑ + 스탯 재계산
	var new_scale: float = 1.0 + MinionData.HIRE_UPGRADE_STAT_MULT * (new_lv - 1)
	for m in game.minions_node.get_children():
		if not is_instance_valid(m):
			continue
		if m.get("minion_type") != type_id:
			continue
		m.level = new_lv
		# base_damage/base_max_hp는 프리셋 × 카드보너스 기준으로 재계산
		var preset: Dictionary = m.TYPE_PRESETS.get(type_id, {})
		if preset.is_empty():
			continue
		var base_dmg: float = preset["damage"] * game.minion_attack_bonus * game.keystone_minion_atk_mult
		var base_hp: float = preset["hp"] * game.minion_hp_bonus
		m.base_damage = base_dmg * new_scale
		m.attack_damage = m.base_damage
		m.base_max_hp = base_hp * new_scale
		var old_ratio: float = m.hp / m.max_hp if m.max_hp > 0.0 else 1.0
		m.max_hp = m.base_max_hp
		m.hp = m.max_hp * old_ratio
