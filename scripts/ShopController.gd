extends Node
## 상점 도메인 컨트롤러 — 상점 UI · 구매 로직 자급자족 모듈 (Phase 2 #1).
## 데이터 = ShopData.gd. 공유 run-state(souls·castle·ability mult·current_wave)와 타 서브시스템은 game 역참조(GS2/GS3).
## Game.gd가 _ready에서 new → add_child → setup(self). 외부 진입점: build_buttons()·open()·close().
## ⚠️ game._shop_dim_alpha는 Game 소유(_set_modal_dim 공유) — 여기선 game 경유로 읽고 쓴다.

const ShopData = preload("res://scripts/data/ShopData.gd")

var game: Node = null  # Game.gd 허브 역참조

# 상점 UI 노드 (setup서 game 트리에서 캐시)
var shop_panel: Control
var shop_title: Label
var shop_subtitle: Label
var shop_souls: Label
var shop_items_node: Node
var shop_close_btn: Button

# 상점-로컬 상태
var shop_btns: Array = []
var shop_purchased: Array = []  # SH4: 상점 진입마다 리셋, 종류당 1회 구매
var _shop_btn_pulse_tween: Tween = null  # 튜토리얼 가이드 펄스(Game._show_shop_guide가 구동)
var _shop_anim_tween: Tween = null       # 진입/퇴장 트랜지션 핸들 (재진입 시 kill)
var _shop_closing: bool = false          # 퇴장 페이드 진행 중 중복 호출 가드

func setup(g: Node) -> void:
	game = g
	shop_panel = game.get_node("UI/ShopPanel")
	shop_title = game.get_node("UI/ShopPanel/ShopTitle")
	shop_subtitle = game.get_node("UI/ShopPanel/ShopSubtitle")
	shop_souls = game.get_node("UI/ShopPanel/ShopSouls")
	shop_items_node = game.get_node("UI/ShopPanel/ShopItems")
	shop_close_btn = game.get_node("UI/ShopPanel/CloseBtn")
	# 닫기 동작 통일 — 눌렸다 돌아오는 바운스를 보여준 뒤 닫음(즉시 닫으면 패널과 함께 사라져 안 보임)
	shop_close_btn.pressed.connect(func() -> void:
		if not is_instance_valid(shop_close_btn):
			return
		shop_close_btn.pivot_offset = shop_close_btn.size * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(shop_close_btn, "scale", Vector2(0.94, 0.94), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(shop_close_btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(close)
	)
	build_buttons()

func build_buttons() -> void:
	for i in ShopData.SHOP_ITEMS.size():
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 58)
		btn.add_theme_font_size_override("font_size", 16)
		# normal 상태: 어두운 보라 배경 + 테두리
		var sn: StyleBoxFlat = StyleBoxFlat.new()
		sn.bg_color = Color(0.18, 0.16, 0.24, 0.92)
		sn.border_width_left = 2
		sn.border_width_top = 2
		sn.border_width_right = 2
		sn.border_width_bottom = 2
		sn.border_color = Color(0.55, 0.5, 0.68)
		sn.corner_radius_top_left = 8
		sn.corner_radius_top_right = 8
		sn.corner_radius_bottom_right = 8
		sn.corner_radius_bottom_left = 8
		sn.content_margin_left = 12.0
		sn.content_margin_right = 12.0
		sn.content_margin_top = 8.0
		sn.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("normal", sn)
		# 버튼 동작 통일 — hover/pressed 색 변화 없음(normal 재사용), 눌림은 성공 시 스케일 바운스.
		btn.add_theme_stylebox_override("hover", sn)
		btn.add_theme_stylebox_override("pressed", sn)
		btn.add_theme_stylebox_override("focus", sn)
		# 글자색도 상태별 고정(기본 테마 font_hover_color가 hover 시 밝아지는 것 차단)
		var shop_font_col: Color = Color(0.90, 0.88, 0.98, 1.0)
		btn.add_theme_color_override("font_color",         shop_font_col)
		btn.add_theme_color_override("font_hover_color",   shop_font_col)
		btn.add_theme_color_override("font_pressed_color", shop_font_col)
		btn.add_theme_color_override("font_focus_color",   shop_font_col)
		# disabled 상태: 채도 낮은 배경 + 흐린 테두리
		var sd: StyleBoxFlat = StyleBoxFlat.new()
		sd.bg_color = Color(0.12, 0.11, 0.15, 0.85)
		sd.border_width_left = 2
		sd.border_width_top = 2
		sd.border_width_right = 2
		sd.border_width_bottom = 2
		sd.border_color = Color(0.32, 0.30, 0.36)
		sd.corner_radius_top_left = 8
		sd.corner_radius_top_right = 8
		sd.corner_radius_bottom_right = 8
		sd.corner_radius_bottom_left = 8
		sd.content_margin_left = 12.0
		sd.content_margin_right = 12.0
		sd.content_margin_top = 8.0
		sd.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("disabled", sd)
		btn.add_theme_color_override("font_color_disabled", Color(0.5, 0.48, 0.54))
		var idx: int = i
		# 눌림 바운스는 buy_item 성공 경로에서만(불가 시 disabled라 pressed 자체가 안 뜸 + 골드 가드)
		btn.pressed.connect(func(): buy_item(idx, btn))
		shop_items_node.add_child(btn)
		shop_btns.append(btn)

func open() -> void:
	# 퇴장 페이드 중 재진입 시 가드 해제 + 기존 트윈 정리
	_shop_closing = false
	if _shop_anim_tween and _shop_anim_tween.is_valid():
		_shop_anim_tween.kill()
	_shop_anim_tween = null

	# SH4: 상점 진입마다 구매 상태 리셋 (웨이브당 1회 상점 → 진입 시 초기화)
	shop_purchased.resize(ShopData.SHOP_ITEMS.size())
	shop_purchased.fill(false)
	_refresh_buttons()
	if is_instance_valid(game.ability_system):
		game.ability_system.cancel_for_shop()  # 무장 중이었다면 해제 (reach 원/무장 UI 잔상 제거)
	# RD16: 상점 중 강화 버튼+팝업 숨김. 팝업이 골드 HUD를 숨겼다면 먼저 복원시킨 뒤 상점용으로 다시 끄도록 _close를 HUD 숨김 앞에서 호출.
	game._close_upgrade_popup()
	# Phase C: 상점(모달) 표시 중 고용 버튼 숨김 (close에서 복원)
	game.summon_container.visible = false
	game.minion_slot_label.visible = false
	game._set_resource_hud_visible(false)  # 자원 캡슐 숨김
	game._set_upgrade_btn_visible(false)
	shop_title.text = Loc.t("shop_title")
	shop_subtitle.text = Loc.t("shop_subtitle")

	# ── A. 진입 트랜지션 ────────────────────────────────────────────────────
	# modal_dim: 원래 알파 보관 후 0 → 원래값 페이드인 (_shop_dim_alpha는 Game 소유)
	game._shop_dim_alpha = game.modal_dim.modulate.a  # 노드 실제값 사용(하드코딩 금지)
	game.modal_dim.modulate.a = 0.0
	game.modal_dim.visible = true

	# shop_panel: 중앙 피벗 → scale·alpha 초기화 후 visible, 탄력 팝인
	shop_panel.pivot_offset = shop_panel.size * 0.5
	shop_panel.scale = Vector2(0.92, 0.92)
	shop_panel.modulate.a = 0.0
	shop_panel.visible = true

	_shop_anim_tween = create_tween().set_parallel(true)
	_shop_anim_tween.tween_property(game.modal_dim, "modulate:a", game._shop_dim_alpha, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shop_anim_tween.tween_property(shop_panel, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shop_anim_tween.tween_property(shop_panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if game._is_tutorial():
		game._show_shop_guide()

func close() -> void:
	# 중복 호출 가드 (페이드 진행 중 재호출 방지)
	if _shop_closing:
		return
	_shop_closing = true

	# 기존 트윈 정리
	if _shop_anim_tween and _shop_anim_tween.is_valid():
		_shop_anim_tween.kill()
	_shop_anim_tween = null

	# 즉시 실행: 가이드·튜토리얼 상점 가이드 복원
	game._close_guide()
	if _shop_btn_pulse_tween and _shop_btn_pulse_tween.is_valid():
		_shop_btn_pulse_tween.kill()
	_shop_btn_pulse_tween = null
	shop_close_btn.modulate = Color.WHITE
	shop_title.text = Loc.t("shop_title")

	# ── B. 퇴장 트랜지션 ────────────────────────────────────────────────────
	# modal_dim + shop_panel 알파 → 0, 패널 scale 살짝 축소(~0.14s, 빠르게)
	_shop_anim_tween = create_tween().set_parallel(true)
	_shop_anim_tween.tween_property(game.modal_dim, "modulate:a", 0.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shop_anim_tween.tween_property(shop_panel, "modulate:a", 0.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shop_anim_tween.tween_property(shop_panel, "scale", Vector2(0.96, 0.96), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 페이드 완료 후: 숨김 + HUD 복원 + 웨이브 진행
	_shop_anim_tween.chain().tween_callback(func() -> void:
		shop_panel.visible = false
		game.modal_dim.visible = false
		game.modal_dim.modulate.a = game._shop_dim_alpha  # 다음 모달(결과창 등)을 위해 알파 복원
		shop_panel.scale = Vector2.ONE          # 다음 진입을 위해 scale 복원
		_shop_closing = false
		# Phase C: 상점 닫힌 후 고용 버튼 + 자원 캡슐 복원 (minion_slot_label은 캡 없어 숨김 유지)
		if is_instance_valid(game.summon_container):
			game.summon_container.visible = true
		game._set_resource_hud_visible(true)  # 자원 캡슐 복원 (MAX 배지 동기화 포함)
		# 마법 버튼 복원 (상점 진입 시 cancel_for_shop으로 숨김)
		if is_instance_valid(game.ability_system):
			game.ability_system.restore_after_shop()
		# RD16: 상점 닫힌 후 강화 버튼 + 아이콘 복원
		game._set_upgrade_btn_visible(true)
		game.current_wave += 1
		game.start_wave()
	)

func buy_item(index: int, btn: Button = null) -> void:
	# SH4: 이미 구매한 항목은 무시
	if index < shop_purchased.size() and shop_purchased[index]:
		return
	var item: Dictionary = ShopData.SHOP_ITEMS[index]
	if game.souls < item["cost"]:
		return
	game._play_button_bounce(btn)   # 구매 성공 시에만 눌림 피드백
	_flash_buy(btn)                 # 구매 성공 골드 플래시
	game.souls -= item["cost"]
	game._update_souls_ui()
	_apply_item(item["id"])
	# SH4: 구매 완료 마킹
	if index < shop_purchased.size():
		shop_purchased[index] = true
	_refresh_buttons()

func _apply_item(id: String) -> void:
	match id:
		"castle_max":
			game.castle_max_hp += 120
			game.castle_hp += 120
			game.castle_bar.set_hp(game.castle_hp, game.castle_max_hp)
			game.castle_vis.set_hp_ratio(float(game.castle_hp) / float(game.castle_max_hp))
			game._update_demon_danger()
		"restore":
			game.castle_hp = game.castle_max_hp
			game.castle_bar.set_hp(game.castle_hp, game.castle_max_hp)
			game.castle_vis.set_hp_ratio(float(game.castle_hp) / float(game.castle_max_hp))
			game._update_demon_danger()
			for m in game.minions_node.get_children():
				if is_instance_valid(m):
					m.hp = m.max_hp
		"lightning_dmg":
			game.attack_bonus *= 1.20
		"ability_cd":
			game.ability_cooldown_mult *= 0.85
		"ability_radius":
			game.ability_radius_mult *= 1.25

func _refresh_buttons() -> void:
	for i in ShopData.SHOP_ITEMS.size():
		var item: Dictionary = ShopData.SHOP_ITEMS[i]
		var btn: Button = shop_btns[i]
		var purchased: bool = i < shop_purchased.size() and shop_purchased[i]
		if purchased:
			btn.text = "%s  %s" % [item["label"], Loc.t("shop_purchased")]
			btn.disabled = true
		else:
			btn.text = "%s  [골드 %d]\n%s" % [item["label"], item["cost"], item["desc"]]
			btn.disabled = game.souls < item["cost"]
	shop_souls.text = Loc.t("shop_owned_souls") % game.souls

func _flash_buy(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var tween: Tween = create_tween()
	tween.tween_property(btn, "modulate", Color(1.6, 1.4, 0.7, 1.0), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
