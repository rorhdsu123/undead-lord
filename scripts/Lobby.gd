extends Node2D

@onready var crown_label: Label = $UI/CrownLabel
@onready var start_btn: Button = $UI/StartBtn
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var _ui: CanvasLayer = $UI

var skeleton_label: Label = null

const INTRO_LINES: Array[String] = [
	"왕관이 있었다. 빼앗겼다.",
	"그 후로 한 200년쯤.\n\n...아직도 죽지 못했다.",
	"매일 토벌대가 온다.\n오늘은 '수습 용사 인턴'이라고 한다.",
	"...일이나 시작하자.",
]

const FACILITIES: Array = [
	{"id": "throne",    "label": "왕좌",
	 "descs": ["시작 영혼 +20", "시작 영혼 +40", "시작 영혼 +60"], "costs": [5, 8, 13]},
	{"id": "wall",      "label": "성벽",
	 "descs": ["최대 HP +50", "최대 HP +100", "최대 HP +150"], "costs": [5, 8, 13]},
	{"id": "graveyard", "label": "묘지",
	 "descs": ["웨이브 회복 +15", "웨이브 회복 +30", "웨이브 회복 +50"], "costs": [5, 8, 13]},
	{"id": "arsenal",   "label": "무기고",
	 "descs": ["공격력 +10%", "공격력 +22%", "공격력 +37%"], "costs": [6, 10, 15]},
	{"id": "banquet",   "label": "연회장",
	 "descs": ["영혼 획득 +20%", "영혼 획득 +40%", "영혼 획득 +60%"], "costs": [6, 10, 15]},
]

const CASTLE_SCALE: float = 1.0
const CASTLE_POS: Vector2 = Vector2(240, 500)
const PANEL_CLOSED_Y: float = 970.0
const PANEL_OPEN_Y: float = 650.0
const PANEL_H: float = 310.0

# 시설 버튼 스크린 좌표 (성 위 / 주변) — 480×960 portrait
const FAC_SCREEN_POS: Dictionary = {
	"throne":    Vector2(240, 220),   # 첨탑/깃발 → 왕좌
	"arsenal":   Vector2(120, 390),   # 왼쪽 타워 → 무기고
	"banquet":   Vector2(360, 390),   # 오른쪽 타워 → 연회장
	"wall":      Vector2(240, 520),   # 성문 아래 → 성벽
	"graveyard": Vector2(420, 560),   # 우측 → 묘지
}

# 해골 정원 배치 순서 (보스 처치 순서대로 등장)
const SKELETON_PLACEMENT: Array = [
	{"facility": "throne",    "job": "시종",   "offset": Vector2(-45, 50)},
	{"facility": "arsenal",   "job": "장인",   "offset": Vector2(-45, 50)},
	{"facility": "banquet",   "job": "요리장", "offset": Vector2(45, 50)},
	{"facility": "wall",      "job": "경비",   "offset": Vector2(-45, 50)},
	{"facility": "graveyard", "job": "묘지기", "offset": Vector2(-45, 30)},
	{"facility": "throne",    "job": "호위",   "offset": Vector2(45, 50)},
	{"facility": "arsenal",   "job": "견습",   "offset": Vector2(45, 50)},
	{"facility": "banquet",   "job": "보조",   "offset": Vector2(-45, 50)},
]

const FACILITY_TINT: Dictionary = {
	"throne":    Color(1.15, 1.05, 0.7, 1.0),   # 황금
	"arsenal":   Color(0.9, 0.95, 1.05, 1.0),   # 강철
	"banquet":   Color(1.1, 0.85, 0.7, 1.0),    # 따뜻한 갈색
	"wall":      Color(0.85, 0.85, 0.95, 1.0),  # 회색
	"graveyard": Color(0.75, 0.85, 1.05, 1.0),  # 청회색
}

const SkeletonResidentScript = preload("res://scripts/SkeletonResident.gd")

var _fac_icon_containers: Array = []
var _skeleton_residents: Array = []
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
	crown_label.size = Vector2(480, 36)
	crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown_label.add_theme_font_size_override("font_size", 18)

	skeleton_label = Label.new()
	skeleton_label.position = Vector2(0, 44)
	skeleton_label.size = Vector2(480, 24)
	skeleton_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skeleton_label.add_theme_font_size_override("font_size", 14)
	skeleton_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	skeleton_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(skeleton_label)

	start_btn.position = Vector2(40, 860)
	start_btn.size = Vector2(400, 60)
	start_btn.pressed.connect(_on_start_pressed)

	_update_crown_label()
	_update_skeleton_label()
	_update_start_btn()
	_build_castle()
	_build_facility_buttons()
	_build_skeleton_garden()
	_build_bottom_panel()

	if not GameSave.intro_seen:
		_show_intro()
	else:
		_fade_in()
		if GameSave.tutorial_completed and not GameSave.first_lobby_visit_done:
			get_tree().create_timer(0.7).timeout.connect(_show_first_facility_guide)
		elif GameSave.tutorial_completed:
			pass

func _update_start_btn() -> void:
	start_btn.text = "출정  (%d-%d)" % [GameSave.current_chapter + 1, GameSave.current_stage + 1]

func _fade_in() -> void:
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.4)

func _update_crown_label() -> void:
	crown_label.text = "왕관 조각: %d" % GameSave.crown_shards

func _update_skeleton_label() -> void:
	if is_instance_valid(skeleton_label):
		skeleton_label.text = "해골: %d / %d" % [GameSave.skeleton_count, GameSave.SKELETON_CAP]

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
	sub.size = Vector2(480, 24)
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
		btn.text = fac["label"]
		btn.add_theme_font_size_override("font_size", 22)
		if can_upgrade:
			btn.modulate = Color(1.2, 1.15, 0.5, 1.0)
		var fid: String = fac_id
		btn.pressed.connect(func() -> void: _open_panel(fid))
		container.add_child(btn)

		var dots_lbl: Label = Label.new()
		dots_lbl.text = str(level) + " / 3"
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

# ── 해골 정원 ───────────────────────────────────────────────

func _build_skeleton_garden() -> void:
	for r: Node in _skeleton_residents:
		if is_instance_valid(r):
			r.queue_free()
	_skeleton_residents.clear()

	var count: int = min(GameSave.skeleton_count, SKELETON_PLACEMENT.size())
	var newly_arrived: int = max(0, count - GameSave.skeleton_count_seen)

	for i: int in count:
		var entry: Dictionary = SKELETON_PLACEMENT[i]
		var facility_id: String = entry["facility"]
		var base_pos: Vector2 = FAC_SCREEN_POS.get(facility_id, Vector2(240, 400))
		var offset: Vector2 = entry["offset"]
		var home_pos: Vector2 = base_pos + offset

		var resident: Node2D = SkeletonResidentScript.new()
		resident.home_pos = home_pos
		resident.color_tint = FACILITY_TINT.get(facility_id, Color.WHITE)
		resident.job = entry["job"]
		add_child(resident)
		move_child(resident, get_child_count() - 1)
		_skeleton_residents.append(resident)

		# 새로 도착한 해골은 등장 연출
		if i >= GameSave.skeleton_count_seen:
			resident.call_deferred("play_arrival")

	if newly_arrived > 0:
		GameSave.skeleton_count_seen = count
		GameSave.save_data()

# ── 하단 슬라이드 패널 ──────────────────────────────────────

func _build_bottom_panel() -> void:
	var vp_w: float = get_viewport_rect().size.x
	_bottom_panel = Control.new()
	_bottom_panel.position = Vector2(0, PANEL_CLOSED_Y)
	_bottom_panel.size = Vector2(vp_w, PANEL_H)
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.04, 0.13, 0.97)
	bg.size = Vector2(vp_w, PANEL_H)
	_bottom_panel.add_child(bg)

	var border: ColorRect = ColorRect.new()
	border.color = Color(0.45, 0.25, 0.75, 1)
	border.size = Vector2(vp_w, 2)
	_bottom_panel.add_child(border)

	var accent: ColorRect = ColorRect.new()
	accent.color = Color(0.28, 0.10, 0.48, 0.45)
	accent.position = Vector2(0, 2)
	accent.size = Vector2(vp_w, 10)
	_bottom_panel.add_child(accent)

	var close_w: float = 100.0
	var close_margin: float = 12.0

	_panel_name_lbl = Label.new()
	_panel_name_lbl.position = Vector2(16, 22)
	_panel_name_lbl.size = Vector2(vp_w - close_w - close_margin * 2 - 16, 36)
	_panel_name_lbl.add_theme_font_size_override("font_size", 22)
	_panel_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	_bottom_panel.add_child(_panel_name_lbl)

	_panel_cur_lbl = Label.new()
	_panel_cur_lbl.position = Vector2(16, 68)
	_panel_cur_lbl.size = Vector2(vp_w - 32, 26)
	_panel_cur_lbl.add_theme_font_size_override("font_size", 15)
	_panel_cur_lbl.add_theme_color_override("font_color", Color(0.78, 0.92, 0.78, 1))
	_bottom_panel.add_child(_panel_cur_lbl)

	_panel_next_lbl = Label.new()
	_panel_next_lbl.position = Vector2(16, 98)
	_panel_next_lbl.size = Vector2(vp_w - 32, 26)
	_panel_next_lbl.add_theme_font_size_override("font_size", 15)
	_bottom_panel.add_child(_panel_next_lbl)

	_panel_upgrade_btn = Button.new()
	_panel_upgrade_btn.position = Vector2(16, 140)
	_panel_upgrade_btn.size = Vector2(vp_w - 32, 52)
	_panel_upgrade_btn.add_theme_font_size_override("font_size", 16)
	_panel_upgrade_btn.pressed.connect(_on_panel_upgrade_pressed)
	_bottom_panel.add_child(_panel_upgrade_btn)

	var close_btn: Button = Button.new()
	close_btn.size = Vector2(close_w, 38)
	close_btn.position = Vector2(vp_w - close_w - close_margin, 18)
	close_btn.text = "닫기"
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
	var dots: String = str(level) + " / 3"
	_panel_name_lbl.text = "%s   %s" % [fac["label"], dots]

	if level == 0:
		_panel_cur_lbl.text = "현재 효과: 미건설"
	else:
		_panel_cur_lbl.text = "현재 효과: %s" % fac["descs"][level - 1]

	if level >= 3:
		_panel_next_lbl.text = "최대 레벨 달성"
		_panel_next_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
		_panel_upgrade_btn.text = "MAX"
		_panel_upgrade_btn.disabled = true
	else:
		var cost: int = fac["costs"][level]
		_panel_next_lbl.text = "→ %s" % fac["descs"][level]
		_panel_next_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.75, 0.9))
		_panel_upgrade_btn.text = "업그레이드  [%d 조각]" % cost
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

	var vp: Vector2 = get_viewport_rect().size

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var label: Label = Label.new()
	label.size = Vector2(vp.x - 40, 200)
	label.position = Vector2(20, vp.y * 0.28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	label.modulate.a = 0.0
	layer.add_child(label)

	var skip_btn: Button = Button.new()
	skip_btn.text = "건너뛰기 ›"
	skip_btn.size = Vector2(120, 36)
	skip_btn.position = Vector2(vp.x - 132, 24)
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

func _show_first_facility_guide() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var vp: Vector2 = get_viewport_rect().size

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 0.88)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var title: Label = Label.new()
	title.text = "— 성 시설 —"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x - 40, 50)
	title.position = Vector2(20, vp.y * 0.22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)

	var msg: Label = Label.new()
	msg.text = "성의 각 시설을 탭하면 업그레이드할 수 있습니다.\n\n왕관 조각이 모일수록 성이 강해집니다.\n스테이지를 클리어할 때마다 조각을 획득합니다."
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85, 1))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size = Vector2(vp.x - 40, 200)
	msg.position = Vector2(20, vp.y * 0.22 + 60)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(msg)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "확인"
	confirm_btn.size = Vector2(200, 52)
	confirm_btn.position = Vector2((vp.x - 200) * 0.5, vp.y * 0.22 + 280)
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
