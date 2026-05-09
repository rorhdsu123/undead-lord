extends Node2D

@onready var crown_label: Label = $UI/CrownLabel
@onready var start_btn: Button = $UI/StartBtn
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var _ui: CanvasLayer = $UI

const INTRO_LINES: Array[String] = [
	"왕관이 있었다. 빼앗겼다.",
	"그 후로 한 200년쯤.\n\n...아직도 죽지 못했다.",
	"매일 토벌대가 온다.\n오늘은 '수습 용사 인턴'이라고 한다.",
	"...일이나 시작하자.",
]

const FACILITIES: Array = [
	{"id": "throne",    "label": "🪑 왕좌",  "emoji": "🪑",
	 "descs": ["시작 영혼 +20", "시작 영혼 +40", "시작 영혼 +60"], "costs": [5, 8, 13]},
	{"id": "wall",      "label": "🧱 성벽",  "emoji": "🧱",
	 "descs": ["최대 HP +50", "최대 HP +100", "최대 HP +150"], "costs": [5, 8, 13]},
	{"id": "graveyard", "label": "⚰ 묘지",  "emoji": "⚰",
	 "descs": ["웨이브 회복 +15", "웨이브 회복 +30", "웨이브 회복 +50"], "costs": [5, 8, 13]},
	{"id": "arsenal",   "label": "⚔ 무기고", "emoji": "⚔",
	 "descs": ["공격력 +10%", "공격력 +22%", "공격력 +37%"], "costs": [6, 10, 15]},
	{"id": "banquet",   "label": "🍽 연회장", "emoji": "🍽",
	 "descs": ["영혼 획득 +20%", "영혼 획득 +40%", "영혼 획득 +60%"], "costs": [6, 10, 15]},
]

const CASTLE_SCALE: float = 1.5
const CASTLE_POS: Vector2 = Vector2(512, 420)
const PANEL_CLOSED_Y: float = 710.0
const PANEL_OPEN_Y: float = 478.0
const PANEL_H: float = 222.0

# 시설 버튼 스크린 좌표 (성 위 / 주변)
const FAC_SCREEN_POS: Dictionary = {
	"throne":    Vector2(512, 148),   # 첨탑/깃발 → 왕좌
	"arsenal":   Vector2(398, 328),   # 왼쪽 타워 → 무기고
	"banquet":   Vector2(626, 328),   # 오른쪽 타워 → 연회장
	"wall":      Vector2(512, 460),   # 성문 아래 → 성벽
	"graveyard": Vector2(835, 534),   # 별도 건물 (우측 하단) → 묘지
}

var _fac_icon_containers: Array = []
var _bottom_panel: Control = null
var _panel_tween: Tween = null
var _panel_open: bool = false
var _current_fac_id: String = ""

var _panel_name_lbl: Label = null
var _panel_cur_lbl: Label = null
var _panel_next_lbl: Label = null
var _panel_upgrade_btn: Button = null

func _ready() -> void:
	for path: String in ["UI/TitleLabel", "UI/SubtitleLabel", "UI/Sep1",
						  "UI/FacilityHeaderLabel", "UI/FacilityPanel",
						  "UI/Sep2", "UI/StartSubLabel"]:
		var n: Node = get_node_or_null(path)
		if n:
			n.visible = false

	crown_label.position = Vector2(0, 12)
	crown_label.size = Vector2(1024, 36)
	crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown_label.add_theme_font_size_override("font_size", 18)

	start_btn.position = Vector2(312, 605)
	start_btn.size = Vector2(400, 56)
	start_btn.pressed.connect(_on_start_pressed)

	_update_crown_label()
	_update_start_btn()
	_build_castle()
	_build_facility_buttons()
	_build_bottom_panel()

	if not GameSave.intro_seen:
		_show_intro()
	else:
		_fade_in()
		if GameSave.tutorial_completed and not GameSave.first_lobby_visit_done:
			get_tree().create_timer(0.7).timeout.connect(_show_first_facility_guide)
		elif GameSave.tutorial_completed:
			get_tree().create_timer(0.7).timeout.connect(_check_daily_login)

func _update_start_btn() -> void:
	start_btn.text = "⚔  출정  (%d-%d)" % [GameSave.current_chapter + 1, GameSave.current_stage + 1]

func _fade_in() -> void:
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.4)

func _update_crown_label() -> void:
	crown_label.text = "👑  왕관 조각: %d" % GameSave.crown_shards

# ── 성 시각 및 시설 버튼 ────────────────────────────────────

func _build_castle() -> void:
	var castle: Node2D = Node2D.new()
	castle.set_script(preload("res://scripts/CastleSprite.gd"))
	castle.position = CASTLE_POS
	castle.scale = Vector2(CASTLE_SCALE, CASTLE_SCALE)
	add_child(castle)
	move_child(castle, 1)   # Background(0) 다음, UI 캔버스 앞

	var sub: Label = Label.new()
	sub.text = "— 폐허의 성 —"
	sub.position = Vector2(0, 488)
	sub.size = Vector2(1024, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.5, 0.45, 0.65, 0.65))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(sub)

func _build_facility_buttons() -> void:
	for c: Control in _fac_icon_containers:
		if is_instance_valid(c):
			c.queue_free()
	_fac_icon_containers.clear()

	for fac: Dictionary in FACILITIES:
		var fac_id: String = fac["id"]
		var screen_pos: Vector2 = FAC_SCREEN_POS.get(fac_id, Vector2(512, 400))
		var level: int = GameSave.facility_levels.get(fac_id, 0)
		var can_upgrade: bool = level < 3 and GameSave.crown_shards >= fac["costs"][level]

		var container: Control = Control.new()
		container.position = screen_pos - Vector2(40, 32)
		container.size = Vector2(80, 84)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var btn: Button = Button.new()
		btn.position = Vector2(0, 0)
		btn.size = Vector2(80, 64)
		btn.text = fac["emoji"]
		btn.add_theme_font_size_override("font_size", 32)
		if can_upgrade:
			btn.modulate = Color(1.2, 1.15, 0.5, 1.0)
		var fid: String = fac_id
		btn.pressed.connect(func() -> void: _open_panel(fid))
		container.add_child(btn)

		var dots_lbl: Label = Label.new()
		dots_lbl.text = "●".repeat(level) + "○".repeat(3 - level)
		dots_lbl.position = Vector2(0, 66)
		dots_lbl.size = Vector2(80, 18)
		dots_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dots_lbl.add_theme_font_size_override("font_size", 10)
		if can_upgrade:
			dots_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
		else:
			dots_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75, 0.9))
		container.add_child(dots_lbl)

		_ui.add_child(container)
		_fac_icon_containers.append(container)

# ── 하단 슬라이드 패널 ──────────────────────────────────────

func _build_bottom_panel() -> void:
	_bottom_panel = Control.new()
	_bottom_panel.position = Vector2(0, PANEL_CLOSED_Y)
	_bottom_panel.size = Vector2(1024, PANEL_H)
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.04, 0.13, 0.97)
	bg.size = Vector2(1024, PANEL_H)
	_bottom_panel.add_child(bg)

	var border: ColorRect = ColorRect.new()
	border.color = Color(0.45, 0.25, 0.75, 1)
	border.size = Vector2(1024, 2)
	_bottom_panel.add_child(border)

	var accent: ColorRect = ColorRect.new()
	accent.color = Color(0.28, 0.10, 0.48, 0.45)
	accent.position = Vector2(0, 2)
	accent.size = Vector2(1024, 10)
	_bottom_panel.add_child(accent)

	_panel_name_lbl = Label.new()
	_panel_name_lbl.position = Vector2(50, 22)
	_panel_name_lbl.size = Vector2(680, 36)
	_panel_name_lbl.add_theme_font_size_override("font_size", 22)
	_panel_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	_bottom_panel.add_child(_panel_name_lbl)

	_panel_cur_lbl = Label.new()
	_panel_cur_lbl.position = Vector2(50, 68)
	_panel_cur_lbl.size = Vector2(720, 26)
	_panel_cur_lbl.add_theme_font_size_override("font_size", 15)
	_panel_cur_lbl.add_theme_color_override("font_color", Color(0.78, 0.92, 0.78, 1))
	_bottom_panel.add_child(_panel_cur_lbl)

	_panel_next_lbl = Label.new()
	_panel_next_lbl.position = Vector2(50, 98)
	_panel_next_lbl.size = Vector2(720, 26)
	_panel_next_lbl.add_theme_font_size_override("font_size", 15)
	_bottom_panel.add_child(_panel_next_lbl)

	_panel_upgrade_btn = Button.new()
	_panel_upgrade_btn.position = Vector2(50, 140)
	_panel_upgrade_btn.size = Vector2(250, 52)
	_panel_upgrade_btn.add_theme_font_size_override("font_size", 16)
	_panel_upgrade_btn.pressed.connect(_on_panel_upgrade_pressed)
	_bottom_panel.add_child(_panel_upgrade_btn)

	var close_btn: Button = Button.new()
	close_btn.position = Vector2(860, 18)
	close_btn.size = Vector2(120, 38)
	close_btn.text = "닫기  ✕"
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_close_panel)
	_bottom_panel.add_child(close_btn)

	_ui.add_child(_bottom_panel)

func _open_panel(fac_id: String) -> void:
	_current_fac_id = fac_id
	_refresh_panel_content()
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_ease(Tween.EASE_OUT)
	_panel_tween.set_trans(Tween.TRANS_BACK)
	_panel_tween.tween_property(_bottom_panel, "position:y", PANEL_OPEN_Y, 0.28)
	_panel_open = true

func _close_panel() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_ease(Tween.EASE_IN)
	_panel_tween.set_trans(Tween.TRANS_BACK)
	_panel_tween.tween_property(_bottom_panel, "position:y", PANEL_CLOSED_Y, 0.22)
	_panel_open = false

func _refresh_panel_content() -> void:
	var fac: Dictionary = FACILITIES.filter(func(f: Dictionary) -> bool: return f["id"] == _current_fac_id)[0]
	var level: int = GameSave.facility_levels.get(_current_fac_id, 0)
	var dots: String = "●".repeat(level) + "○".repeat(3 - level)
	_panel_name_lbl.text = "%s   %s" % [fac["label"], dots]

	if level == 0:
		_panel_cur_lbl.text = "현재 효과: 미건설"
	else:
		_panel_cur_lbl.text = "현재 효과: %s" % fac["descs"][level - 1]

	if level >= 3:
		_panel_next_lbl.text = "✦ 최대 레벨 달성"
		_panel_next_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
		_panel_upgrade_btn.text = "MAX"
		_panel_upgrade_btn.disabled = true
	else:
		var cost: int = fac["costs"][level]
		_panel_next_lbl.text = "→ %s" % fac["descs"][level]
		_panel_next_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.75, 0.9))
		_panel_upgrade_btn.text = "업그레이드  👑 %d" % cost
		_panel_upgrade_btn.disabled = GameSave.crown_shards < cost

func _on_panel_upgrade_pressed() -> void:
	_upgrade(_current_fac_id)
	_refresh_panel_content()
	_build_facility_buttons()

func _upgrade(id: String) -> void:
	var fac: Dictionary = FACILITIES.filter(func(f: Dictionary) -> bool: return f["id"] == id)[0]
	var level: int = GameSave.facility_levels.get(id, 0)
	if level >= 3:
		return
	var cost: int = fac["costs"][level]
	if GameSave.crown_shards < cost:
		return
	GameSave.crown_shards -= cost
	GameSave.facility_levels[id] = level + 1
	GameSave.save_data()
	_update_crown_label()

# ── 인트로 / 튜토리얼 가이드 ───────────────────────────────

func _show_intro() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = Vector2(1024, 700)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var label: Label = Label.new()
	label.size = Vector2(900, 200)
	label.position = Vector2(62, 260)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	label.modulate.a = 0.0
	layer.add_child(label)

	var skip_btn: Button = Button.new()
	skip_btn.text = "건너뛰기 ›"
	skip_btn.position = Vector2(880, 24)
	skip_btn.size = Vector2(120, 36)
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.pressed.connect(func() -> void: _finish_intro(layer))
	layer.add_child(skip_btn)

	_play_intro_slides(label, layer, 0)

func _play_intro_slides(label: Label, layer: CanvasLayer, index: int) -> void:
	if not is_instance_valid(layer):
		return
	if index >= INTRO_LINES.size():
		_finish_intro(layer)
		return
	label.text = INTRO_LINES[index]
	label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		_play_intro_slides(label, layer, index + 1)
	)

func _finish_intro(layer: CanvasLayer) -> void:
	if not is_instance_valid(layer):
		return
	GameSave.intro_seen = true
	GameSave.save_data()
	GameSave.start_chapter = GameSave.current_chapter
	GameSave.start_stage = GameSave.current_stage
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _check_daily_login() -> void:
	var today: String = Time.get_date_string_from_system()
	if GameSave.last_login_date == today:
		return
	GameSave.last_login_date = today
	GameSave.save_data()
	_show_daily_reward(3)

func _show_daily_reward(shards: int) -> void:
	GameSave.add_crown_shards(shards)
	_update_crown_label()

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 0.0)
	bg.size = Vector2(1024, 700)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var title: Label = Label.new()
	title.text = "— 일일 출정 보상 —"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(700, 50)
	title.position = Vector2(162, 220)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)

	var reward_label: Label = Label.new()
	reward_label.text = "👑  왕관 조각  +%d" % shards
	reward_label.add_theme_font_size_override("font_size", 32)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.size = Vector2(700, 60)
	reward_label.position = Vector2(162, 300)
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(reward_label)

	var sub: Label = Label.new()
	sub.text = "내일도 출정하면 추가 보상을 받을 수 있다."
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65, 1))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(700, 40)
	sub.position = Vector2(162, 375)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sub)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "수령"
	confirm_btn.size = Vector2(180, 52)
	confirm_btn.position = Vector2(422, 440)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.pressed.connect(func() -> void:
		var tween: Tween = create_tween()
		tween.tween_property(bg, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func() -> void:
			if is_instance_valid(layer):
				layer.queue_free()
		)
	)
	layer.add_child(confirm_btn)

	var tween: Tween = create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.35)

func _show_first_facility_guide() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 0.88)
	bg.size = Vector2(1024, 700)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var title: Label = Label.new()
	title.text = "— 성 시설 —"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(700, 50)
	title.position = Vector2(162, 200)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)

	var msg: Label = Label.new()
	msg.text = "성의 각 시설을 탭하면 업그레이드할 수 있습니다.\n\n왕관 조각이 모일수록 성이 강해집니다.\n스테이지를 클리어할 때마다 조각을 획득합니다."
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85, 1))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size = Vector2(680, 160)
	msg.position = Vector2(172, 270)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(msg)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "확인"
	confirm_btn.size = Vector2(200, 52)
	confirm_btn.position = Vector2(412, 460)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.pressed.connect(func() -> void:
		GameSave.first_lobby_visit_done = true
		GameSave.save_data()
		var tween: Tween = create_tween()
		tween.tween_property(bg, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void:
			if is_instance_valid(layer):
				layer.queue_free()
		)
	)
	layer.add_child(confirm_btn)

	bg.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.4)

func _on_start_pressed() -> void:
	if _panel_open:
		_close_panel()
	GameSave.start_chapter = GameSave.current_chapter
	GameSave.start_stage = GameSave.current_stage
	start_btn.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	)
