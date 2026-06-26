extends Node2D

@onready var crown_label: Label = $UI/CrownLabel
@onready var start_btn: Button = $UI/StartBtn
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var _ui: CanvasLayer = $UI

var skeleton_label: Label = null

# ── 위엄 HUD ─────────────────────────────────────────────────
var _majesty_gauge: Control = null   # 위엄 라디얼 게이지 위젯
var _majesty_lv_label: Label = null  # HUD 내 "위엄 Lv N" 텍스트

# ── 알현실 거점 ───────────────────────────────────────────────
var _throne_btn: Button = null          # 탭 가능 거점 버튼
var _throne_badge: Panel = null         # 레드닷 알림 뱃지

const INTRO_LINES: Array[String] = [
	"왕관이 있었다. 빼앗겼다.",
	"그 후로 한 200년쯤.\n\n...아직도 죽지 못했다.",
	"매일 토벌대가 온다.\n오늘은 '수습 용사 인턴'이라고 한다.",
	"...일이나 시작하자.",
]

const FACILITIES: Array = [
	{"id": "throne",    "label": "왕좌",
	 "descs": ["시작 골드 +20", "시작 골드 +40", "시작 골드 +60"], "costs": [5, 8, 13]},
	{"id": "wall",      "label": "성벽",
	 "descs": ["최대 HP +50", "최대 HP +100", "최대 HP +150"], "costs": [5, 8, 13]},
	{"id": "graveyard", "label": "묘지",
	 "descs": ["웨이브 회복 +15", "웨이브 회복 +30", "웨이브 회복 +50"], "costs": [5, 8, 13]},
	{"id": "arsenal",   "label": "무기고",
	 "descs": ["공격력 +10%", "공격력 +22%", "공격력 +37%"], "costs": [6, 10, 15]},
	{"id": "banquet",   "label": "연회장",
	 "descs": ["골드 획득 +20%", "골드 획득 +40%", "골드 획득 +60%"], "costs": [6, 10, 15]},
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

# ── 알현 오버레이 ─────────────────────────────────────────────
var _court_overlay: CanvasLayer = null   # 중복 생성 방지용 참조
var _throne_node: Node2D = null          # 거점 비주얼 (bounce 대상)

# ── 개발용 리셋 버튼 ──────────────────────────────────────────
var _dev_reset_btn: Button = null
var _dev_reset_armed: bool = false

func _ready() -> void:
	for path: String in ["UI/TitleLabel", "UI/SubtitleLabel", "UI/Sep1",
						  "UI/FacilityHeaderLabel", "UI/FacilityPanel",
						  "UI/Sep2", "UI/StartSubLabel"]:
		var n: Node = get_node_or_null(path)
		if n:
			n.visible = false

	# HUD 상단 한 줄 레이아웃: [위엄 게이지(좌)] [왕관(중)] [해골(우)]
	# 위엄 게이지는 _build_majesty_hud()에서 생성 (좌측, x=8)
	# 왕관·해골 라벨은 중앙·우측으로 재배치
	crown_label.position = Vector2(100, 8)
	crown_label.size = Vector2(180, 30)
	crown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown_label.add_theme_font_size_override("font_size", 15)

	skeleton_label = Label.new()
	skeleton_label.position = Vector2(290, 8)
	skeleton_label.size = Vector2(182, 30)
	skeleton_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skeleton_label.add_theme_font_size_override("font_size", 15)
	skeleton_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	skeleton_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(skeleton_label)

	start_btn.position = Vector2(40, 860)
	start_btn.size = Vector2(400, 60)
	start_btn.pressed.connect(_on_start_pressed)

	_dev_reset_btn = Button.new()
	_dev_reset_btn.position = Vector2(40, 824)
	_dev_reset_btn.size = Vector2(400, 28)
	_dev_reset_btn.add_theme_font_size_override("font_size", 13)
	_dev_reset_btn.text = "데이터 초기화 (개발용)"
	_dev_reset_btn.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	_dev_reset_btn.pressed.connect(_on_dev_reset_pressed)
	_ui.add_child(_dev_reset_btn)

	_update_crown_label()
	_update_skeleton_label()
	_update_start_btn()
	_build_majesty_hud()
	_build_castle()
	_build_throne_room()
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
		# 로비 진입 시 알현 보상 있으면 거점 통통 튀는 어텐션 (화면 비차단)
		if GameSave.has_court_reward() and is_instance_valid(_throne_btn):
			get_tree().create_timer(0.5).timeout.connect(_play_throne_attention)

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

func _update_majesty_hud() -> void:
	if not is_instance_valid(_majesty_gauge):
		return
	_majesty_gauge.queue_redraw()
	if is_instance_valid(_majesty_lv_label):
		if GameSave.majesty_level >= GameSave.MAJESTY_CAP:
			_majesty_lv_label.text = Loc.t("majesty_max")
		else:
			_majesty_lv_label.text = Loc.t("majesty_lv") % GameSave.majesty_level

# ── 위엄 라디얼 HUD ──────────────────────────────────────────

func _build_majesty_hud() -> void:
	# 컨테이너: 좌상단, 위엄 게이지 + 레벨 라벨
	const GAUGE_SIZE: float = 44.0
	const GAUGE_X: float = 8.0
	const GAUGE_Y: float = 4.0

	# 커스텀 Control: draw_arc()로 원형 EXP 게이지
	_majesty_gauge = Control.new()
	_majesty_gauge.position = Vector2(GAUGE_X, GAUGE_Y)
	_majesty_gauge.size = Vector2(GAUGE_SIZE, GAUGE_SIZE)
	_majesty_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# draw() 는 스크립트 없이 직접 연결 불가 → 인라인 스크립트 대신
	# set_script()으로 익명 스크립트 없이, _draw 시그널을 draw_item을 통해 구현
	# Godot 4에서는 Control에 스크립트 없이 draw_arc 연결 불가 →
	# 간단한 익명 클래스 대신 _draw callback을 서브노드 없이
	# ReferenceRect + draw_arc 패턴: 커스텀 스크립트를 set_script로 부착
	var gauge_script: GDScript = GDScript.new()
	gauge_script.source_code = """
extends Control
var _fill: float = 0.0
var _capped: bool = false
func _draw() -> void:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var r: float = cx - 3.0
	# 배경 링
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 48, Color(0.25, 0.20, 0.35, 0.8), 4.0, true)
	# 전경 링 (시계방향: -PI*0.5(12시) 시작, 각도 = _fill * TAU)
	if _fill > 0.001 or _capped:
		var fill_angle: float = TAU if _capped else _fill * TAU
		var col: Color = Color(1.0, 0.85, 0.2, 1.0) if not _capped else Color(1.0, 0.7, 0.1, 1.0)
		draw_arc(Vector2(cx, cy), r, -PI * 0.5, -PI * 0.5 + fill_angle, 48, col, 4.0, true)
"""
	gauge_script.reload()
	_majesty_gauge.set_script(gauge_script)

	# 레벨 라벨 (게이지 중앙)
	_majesty_lv_label = Label.new()
	_majesty_lv_label.position = Vector2(0, 0)
	_majesty_lv_label.size = Vector2(GAUGE_SIZE, GAUGE_SIZE)
	_majesty_lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_majesty_lv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_majesty_lv_label.add_theme_font_size_override("font_size", 10)
	_majesty_lv_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6, 1.0))
	_majesty_lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_majesty_gauge.add_child(_majesty_lv_label)

	_ui.add_child(_majesty_gauge)
	_refresh_majesty_gauge_fill()
	_update_majesty_hud()

func _refresh_majesty_gauge_fill() -> void:
	if not is_instance_valid(_majesty_gauge):
		return
	var capped: bool = GameSave.majesty_level >= GameSave.MAJESTY_CAP
	var fill: float = 0.0
	if capped:
		fill = 1.0
	elif GameSave.majesty_level < GameSave.MAJESTY_LEVEL_REQ.size():
		var req: int = GameSave.MAJESTY_LEVEL_REQ[GameSave.majesty_level]
		fill = float(GameSave.majesty_exp) / float(req) if req > 0 else 0.0
	_majesty_gauge.set("_fill", fill)
	_majesty_gauge.set("_capped", capped)
	_majesty_gauge.queue_redraw()

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

# ── C-2 알현실 거점 ────────────────────────────────────────────

# 원형 레드닷 알림 뱃지 생성 (공용)
func _make_red_dot(diam: float = 14.0) -> Panel:
	var dot: Panel = Panel.new()
	dot.size = Vector2(diam, diam)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.18, 0.18, 1.0)
	sb.set_corner_radius_all(int(diam * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.85, 0.95)
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot

func _build_throne_room() -> void:
	# 좌하단 (70, 630) — 시설 버튼과 겹치지 않는 위치
	const THRONE_POS: Vector2 = Vector2(70, 630)
	const THRONE_W: float = 90.0
	const THRONE_H: float = 72.0

	# Node2D 컨테이너 (bounce 대상)
	_throne_node = Node2D.new()
	_throne_node.position = THRONE_POS

	# --- 단상 비주얼 (ColorRect 두 겹으로 옥좌 실루엣) ---
	# 기단부
	var base_rect: ColorRect = ColorRect.new()
	base_rect.position = Vector2(-THRONE_W * 0.5, 10)
	base_rect.size = Vector2(THRONE_W, 28)
	base_rect.color = Color(0.22, 0.16, 0.34, 0.95)
	_throne_node.add_child(base_rect)

	# 등받이 (좁고 높음)
	var back_rect: ColorRect = ColorRect.new()
	back_rect.position = Vector2(-18, -24)
	back_rect.size = Vector2(36, 38)
	back_rect.color = Color(0.38, 0.25, 0.55, 0.98)
	_throne_node.add_child(back_rect)

	# 팔걸이 좌
	var arm_l: ColorRect = ColorRect.new()
	arm_l.position = Vector2(-THRONE_W * 0.5 + 6, -4)
	arm_l.size = Vector2(10, 18)
	arm_l.color = Color(0.50, 0.34, 0.70, 0.95)
	_throne_node.add_child(arm_l)

	# 팔걸이 우
	var arm_r: ColorRect = ColorRect.new()
	arm_r.position = Vector2(THRONE_W * 0.5 - 16, -4)
	arm_r.size = Vector2(10, 18)
	arm_r.color = Color(0.50, 0.34, 0.70, 0.95)
	_throne_node.add_child(arm_r)

	# 금색 테두리 (상단 가로선)
	var crown_line: ColorRect = ColorRect.new()
	crown_line.position = Vector2(-THRONE_W * 0.5, -26)
	crown_line.size = Vector2(THRONE_W, 4)
	crown_line.color = Color(1.0, 0.82, 0.2, 0.9)
	_throne_node.add_child(crown_line)

	add_child(_throne_node)

	# --- 탭 버튼 (_ui CanvasLayer 에 붙임, 시설 버튼 패턴과 동일) ---
	_throne_btn = Button.new()
	_throne_btn.position = THRONE_POS - Vector2(THRONE_W * 0.5, THRONE_H * 0.5)
	_throne_btn.size = Vector2(THRONE_W, THRONE_H)
	_throne_btn.modulate = Color(1, 1, 1, 0)   # 투명 — 비주얼은 Node2D
	_throne_btn.pressed.connect(_open_court_overlay)
	_ui.add_child(_throne_btn)

	# --- "알현실" 라벨 ---
	var lbl: Label = Label.new()
	lbl.text = Loc.t("throne_room_label")
	lbl.position = THRONE_POS + Vector2(-THRONE_W * 0.5, 40)
	lbl.size = Vector2(THRONE_W, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 0.85))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(lbl)

	# --- 레드닷 알림 뱃지 ---
	const DOT_SIZE: float = 14.0
	_throne_badge = _make_red_dot(DOT_SIZE)
	_throne_badge.position = THRONE_POS + Vector2(THRONE_W * 0.5 - DOT_SIZE, -THRONE_H * 0.5)
	_throne_badge.visible = false
	_ui.add_child(_throne_badge)

	_refresh_throne_affordance()

func _refresh_throne_affordance() -> void:
	# 어포던스 = 레드닷 표시/숨김만 (거점 글로우 펄스 없음)
	if is_instance_valid(_throne_badge):
		_throne_badge.visible = GameSave.has_court_reward()

func _play_throne_attention() -> void:
	if not is_instance_valid(_throne_node):
		return
	# 거점만 scale bounce — 화면 입력 차단 없음
	var orig_scale: Vector2 = _throne_node.scale
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_throne_node, "scale", orig_scale * 1.25, 0.18)
	tween.tween_property(_throne_node, "scale", orig_scale, 0.22)

# ── C-3 알현 오버레이 ─────────────────────────────────────────

func _open_court_overlay() -> void:
	# 중복 방지
	if is_instance_valid(_court_overlay):
		return

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 92
	add_child(layer)
	_court_overlay = layer

	var vp: Vector2 = get_viewport_rect().size

	# 반투명 배경 (탭 닫기)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.10, 0.90)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			_close_court_overlay()
		elif ev is InputEventMouseButton and ev.pressed:
			_close_court_overlay()
	)
	layer.add_child(bg)

	# 패널 컨테이너
	const PANEL_X: float = 16.0
	const PANEL_Y: float = 60.0
	const PANEL_W: float = 448.0

	var panel: Control = Control.new()
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size = Vector2(PANEL_W, vp.y - PANEL_Y - 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	var panel_bg: ColorRect = ColorRect.new()
	panel_bg.color = Color(0.07, 0.04, 0.14, 0.98)
	panel_bg.size = panel.size
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_bg)

	# 패널 상단 테두리
	var border: ColorRect = ColorRect.new()
	border.color = Color(0.55, 0.32, 0.85, 1.0)
	border.size = Vector2(PANEL_W, 2)
	panel.add_child(border)

	# 닫기 버튼
	var close_btn: Button = Button.new()
	close_btn.text = "닫기"
	close_btn.size = Vector2(80, 34)
	close_btn.position = Vector2(PANEL_W - 90, 10)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(_close_court_overlay)
	panel.add_child(close_btn)

	# 위엄 레벨 라벨
	var lv_lbl: Label = Label.new()
	lv_lbl.name = "LvLabel"
	if GameSave.majesty_level >= GameSave.MAJESTY_CAP:
		lv_lbl.text = Loc.t("majesty_max")
	else:
		lv_lbl.text = Loc.t("majesty_lv") % GameSave.majesty_level
	lv_lbl.position = Vector2(12, 12)
	lv_lbl.size = Vector2(PANEL_W - 110, 32)
	lv_lbl.add_theme_font_size_override("font_size", 20)
	lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lv_lbl)

	# EXP 게이지 (ProgressBar)
	var prog: ProgressBar = ProgressBar.new()
	prog.name = "ExpBar"
	prog.position = Vector2(12, 50)
	prog.size = Vector2(PANEL_W - 24, 14)
	prog.min_value = 0.0
	prog.max_value = 1.0
	if GameSave.majesty_level >= GameSave.MAJESTY_CAP:
		prog.value = 1.0
	else:
		var req: int = GameSave.MAJESTY_LEVEL_REQ[GameSave.majesty_level]
		prog.value = float(GameSave.majesty_exp) / float(req) if req > 0 else 0.0
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prog)

	# 해제권 라벨
	var credits_lbl: Label = Label.new()
	credits_lbl.name = "CreditsLabel"
	credits_lbl.text = Loc.t("unlock_credits_label") % GameSave.unlock_credits
	credits_lbl.position = Vector2(12, 70)
	credits_lbl.size = Vector2(PANEL_W - 24, 24)
	credits_lbl.add_theme_font_size_override("font_size", 14)
	credits_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 0.78, 1.0))
	credits_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(credits_lbl)

	# 구분선
	var sep1: ColorRect = ColorRect.new()
	sep1.color = Color(0.40, 0.25, 0.65, 0.6)
	sep1.position = Vector2(12, 100)
	sep1.size = Vector2(PANEL_W - 24, 1)
	panel.add_child(sep1)

	# [알현하다] 버튼
	var court_btn: Button = Button.new()
	court_btn.name = "CourtBtn"
	court_btn.position = Vector2(12, 108)
	court_btn.size = Vector2(PANEL_W - 24, 48)
	court_btn.add_theme_font_size_override("font_size", 16)
	if GameSave.can_hold_court():
		court_btn.text = Loc.t("court_btn_available")
		court_btn.disabled = false
	else:
		court_btn.text = Loc.t("court_btn_done")
		court_btn.disabled = true
	court_btn.pressed.connect(func() -> void: _on_court_btn_pressed(panel))
	panel.add_child(court_btn)

	# 알현하다 버튼 레드닷 — 알현 가능할 때만 (버튼 우상단)
	var court_dot: Panel = _make_red_dot()
	court_dot.name = "CourtDot"
	court_dot.position = Vector2(PANEL_W - 26, 102)
	court_dot.visible = GameSave.can_hold_court()
	panel.add_child(court_dot)

	# 구분선
	var sep2: ColorRect = ColorRect.new()
	sep2.color = Color(0.40, 0.25, 0.65, 0.6)
	sep2.position = Vector2(12, 164)
	sep2.size = Vector2(PANEL_W - 24, 1)
	panel.add_child(sep2)

	# 교리 트리 (ScrollContainer)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "DoctrineScroll"
	scroll.position = Vector2(0, 170)
	scroll.size = Vector2(PANEL_W, panel.size.y - 175)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var doctrine_vbox: VBoxContainer = VBoxContainer.new()
	doctrine_vbox.name = "DoctrineVBox"
	doctrine_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doctrine_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(doctrine_vbox)

	_build_doctrine_tree(doctrine_vbox, PANEL_W)

	# 페이드인
	bg.modulate.a = 0.0
	var fade: Tween = create_tween()
	fade.tween_property(bg, "modulate:a", 1.0, 0.25)

func _close_court_overlay() -> void:
	if not is_instance_valid(_court_overlay):
		return
	var layer: CanvasLayer = _court_overlay
	_court_overlay = null
	var bg: ColorRect = layer.get_child(0) if layer.get_child_count() > 0 else null
	if is_instance_valid(bg):
		var tween: Tween = create_tween()
		tween.tween_property(bg, "modulate:a", 0.0, 0.20)
		tween.tween_callback(func() -> void:
			if is_instance_valid(layer):
				layer.queue_free()
		)
	else:
		layer.queue_free()

func _on_court_btn_pressed(panel: Control) -> void:
	var lv: int = GameSave.hold_court()
	_update_majesty_hud()
	_refresh_majesty_gauge_fill()
	_refresh_throne_affordance()
	_refresh_court_overlay_content(panel)
	if lv > 0:
		_show_levelup_toast(panel)

func _refresh_court_overlay_content(panel: Control) -> void:
	var lv_lbl: Label = panel.get_node_or_null("LvLabel")
	if is_instance_valid(lv_lbl):
		if GameSave.majesty_level >= GameSave.MAJESTY_CAP:
			lv_lbl.text = Loc.t("majesty_max")
		else:
			lv_lbl.text = Loc.t("majesty_lv") % GameSave.majesty_level

	var prog: ProgressBar = panel.get_node_or_null("ExpBar")
	if is_instance_valid(prog):
		if GameSave.majesty_level >= GameSave.MAJESTY_CAP:
			prog.value = 1.0
		else:
			var req: int = GameSave.MAJESTY_LEVEL_REQ[GameSave.majesty_level]
			prog.value = float(GameSave.majesty_exp) / float(req) if req > 0 else 0.0

	var credits_lbl: Label = panel.get_node_or_null("CreditsLabel")
	if is_instance_valid(credits_lbl):
		credits_lbl.text = Loc.t("unlock_credits_label") % GameSave.unlock_credits

	var court_btn: Button = panel.get_node_or_null("CourtBtn")
	if is_instance_valid(court_btn):
		if GameSave.can_hold_court():
			court_btn.text = Loc.t("court_btn_available")
			court_btn.disabled = false
		else:
			court_btn.text = Loc.t("court_btn_done")
			court_btn.disabled = true

	var court_dot: Panel = panel.get_node_or_null("CourtDot")
	if is_instance_valid(court_dot):
		court_dot.visible = GameSave.can_hold_court()

	var scroll: ScrollContainer = panel.get_node_or_null("DoctrineScroll")
	if is_instance_valid(scroll):
		var vbox: VBoxContainer = scroll.get_node_or_null("DoctrineVBox")
		if is_instance_valid(vbox):
			for c: Node in vbox.get_children():
				c.queue_free()
			_build_doctrine_tree(vbox, panel.size.x)

func _show_levelup_toast(panel: Control) -> void:
	var toast: Label = Label.new()
	toast.text = Loc.t("majesty_levelup")
	toast.position = Vector2(12, 108)
	toast.size = Vector2(panel.size.x - 24, 48)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(1.0, 0.90, 0.2, 1.0))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0.0
	panel.add_child(toast)

	# 크기 scale + 페이드아웃
	toast.pivot_offset = toast.size * 0.5
	toast.scale = Vector2(0.8, 0.8)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.22)
	tween.tween_property(toast, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(1.8)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
	)

# ── D 교리 트리 ───────────────────────────────────────────────

const DOCTRINE_CATS: Array[String] = ["death", "war", "soul", "minion", "rule"]

func _build_doctrine_tree(vbox: VBoxContainer, panel_w: float) -> void:
	const INNER_PAD: float = 8.0
	const CELL_W_FRAC: float = 0.44   # 각 A/B 칸 너비 비율

	for cat: String in DOCTRINE_CATS:
		var chosen: String = GameSave.doctrines.get(cat, "")
		var has_credits: bool = GameSave.unlock_credits > 0

		# 카테고리 행 컨테이너
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		vbox.add_child(row)

		# 카테고리 이름 라벨
		var cat_lbl: Label = Label.new()
		cat_lbl.text = Loc.t("doctrine_category_" + cat)
		cat_lbl.add_theme_font_size_override("font_size", 13)
		cat_lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 1.0, 1.0))
		cat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_lbl.custom_minimum_size = Vector2(panel_w - INNER_PAD * 2, 20)
		row.add_child(cat_lbl)

		# A / B 칸 가로 배치
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		row.add_child(hbox)

		for choice: String in ["A", "B"]:
			var name_key: String = "doctrine_%s_%s_name" % [cat, choice]
			var desc_key: String = "doctrine_%s_%s_desc" % [cat, choice]
			var cell_name: String = Loc.t(name_key)
			var cell_desc: String = Loc.t(desc_key)

			var is_selected: bool = chosen == choice
			var is_opposite_selected: bool = chosen != "" and chosen != choice
			var can_pick: bool = chosen == "" and has_credits

			var cell: Control = Control.new()
			cell.custom_minimum_size = Vector2((panel_w - INNER_PAD * 2 - 6) * 0.5, 58)
			hbox.add_child(cell)

			# 배경 색
			var cell_bg: ColorRect = ColorRect.new()
			cell_bg.size = cell.custom_minimum_size
			if is_selected:
				cell_bg.color = Color(0.30, 0.22, 0.08, 0.95)   # 금색 강조
			elif is_opposite_selected:
				cell_bg.color = Color(0.10, 0.09, 0.14, 0.90)   # 회색 잠금
			elif can_pick:
				cell_bg.color = Color(0.12, 0.08, 0.22, 0.95)   # 선택 가능
			else:
				cell_bg.color = Color(0.09, 0.07, 0.16, 0.90)   # 프리뷰
			cell.add_child(cell_bg)

			# 이름 라벨
			var name_lbl: Label = Label.new()
			name_lbl.text = cell_name
			name_lbl.position = Vector2(6, 4)
			name_lbl.size = Vector2(cell.custom_minimum_size.x - 12, 18)
			name_lbl.add_theme_font_size_override("font_size", 12)
			if is_selected:
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			elif is_opposite_selected:
				name_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1.0))
			else:
				name_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.96, 1.0))
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(name_lbl)

			# 설명 라벨
			var desc_lbl: Label = Label.new()
			desc_lbl.text = cell_desc
			desc_lbl.position = Vector2(6, 22)
			desc_lbl.size = Vector2(cell.custom_minimum_size.x - 12, 34)
			desc_lbl.add_theme_font_size_override("font_size", 10)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if is_opposite_selected:
				desc_lbl.add_theme_color_override("font_color", Color(0.38, 0.36, 0.44, 1.0))
			else:
				desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.70, 0.82, 1.0))
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(desc_lbl)

			# 선택 오버레이 버튼 (활성 시만)
			if can_pick:
				var pick_btn: Button = Button.new()
				pick_btn.size = cell.custom_minimum_size
				pick_btn.modulate = Color(1, 1, 1, 0)   # 투명 — 비주얼은 cell_bg
				var _cat: String = cat
				var _choice: String = choice
				pick_btn.pressed.connect(func() -> void:
					var ok: bool = GameSave.assign_doctrine(_cat, _choice)
					if ok:
						# 오버레이 컨텐츠 갱신
						var panel: Control = vbox.get_parent().get_parent()
						_refresh_court_overlay_content(panel)
						_update_majesty_hud()
						_refresh_throne_affordance()
				)
				cell.add_child(pick_btn)

			# 선택 완료 테두리
			if is_selected:
				var sel_border: ColorRect = ColorRect.new()
				sel_border.color = Color(1.0, 0.82, 0.15, 0.85)
				sel_border.size = Vector2(cell.custom_minimum_size.x, 2)
				sel_border.position = Vector2(0, 0)
				sel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(sel_border)

		# 행 하단 구분선
		var row_sep: ColorRect = ColorRect.new()
		row_sep.color = Color(0.30, 0.20, 0.50, 0.4)
		row_sep.custom_minimum_size = Vector2(panel_w - INNER_PAD * 2, 1)
		vbox.add_child(row_sep)

# ── 개발용 리셋 핸들러 ────────────────────────────────────────

func _on_dev_reset_pressed() -> void:
	if _dev_reset_armed:
		GameSave.reset_data()
		get_tree().reload_current_scene()
		return
	_dev_reset_armed = true
	_dev_reset_btn.text = "정말 초기화? 다시 탭"
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(_dev_reset_btn) and _dev_reset_armed:
			_dev_reset_armed = false
			_dev_reset_btn.text = "데이터 초기화 (개발용)"
	)
