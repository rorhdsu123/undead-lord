extends Node2D

@onready var crown_label: Label = $UI/CrownLabel
@onready var start_btn: Button = $UI/StartBtn
@onready var facility_panel: VBoxContainer = $UI/FacilityPanel
@onready var fade_rect: ColorRect = $UI/FadeRect

const INTRO_LINES: Array[String] = [
	"왕관이 있었다. 빼앗겼다.",
	"그 후로 한 200년쯤.\n\n...아직도 죽지 못했다.",
	"매일 토벌대가 온다.\n오늘은 '수습 용사 인턴'이라고 한다.",
	"...일이나 시작하자.",
]

const FACILITIES: Array = [
	{
		"id": "throne",
		"label": "🪑 왕좌",
		"descs": ["시작 영혼 +20", "시작 영혼 +40", "시작 영혼 +60"],
		"costs": [5, 8, 13],
	},
	{
		"id": "wall",
		"label": "🧱 성벽",
		"descs": ["최대 HP +50", "최대 HP +100", "최대 HP +150"],
		"costs": [5, 8, 13],
	},
	{
		"id": "graveyard",
		"label": "⚰ 묘지",
		"descs": ["웨이브 회복 +15", "웨이브 회복 +30", "웨이브 회복 +50"],
		"costs": [5, 8, 13],
	},
	{
		"id": "arsenal",
		"label": "⚔ 무기고",
		"descs": ["공격력 +10%", "공격력 +22%", "공격력 +37%"],
		"costs": [6, 10, 15],
	},
	{
		"id": "banquet",
		"label": "🍽 연회장",
		"descs": ["영혼 획득 +20%", "영혼 획득 +40%", "영혼 획득 +60%"],
		"costs": [6, 10, 15],
	},
]

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	_update_crown_label()
	_update_start_btn()
	_build_facility_list()
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

func _build_facility_list() -> void:
	for child in facility_panel.get_children():
		child.queue_free()
	for fac: Dictionary in FACILITIES:
		facility_panel.add_child(_build_row(fac))

func _build_row(fac: Dictionary) -> HBoxContainer:
	var level: int = GameSave.facility_levels.get(fac["id"], 0)

	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 64)

	# 왼쪽: 이름 + 레벨 도트 + 현재 효과
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_line: Label = Label.new()
	var dots: String = "●".repeat(level) + "○".repeat(3 - level)
	name_line.text = "%s   %s" % [fac["label"], dots]
	name_line.add_theme_font_size_override("font_size", 15)

	var effect_line: Label = Label.new()
	effect_line.add_theme_font_size_override("font_size", 13)
	if level == 0:
		effect_line.text = "미건설"
		effect_line.add_theme_color_override("font_color", Color(0.45, 0.43, 0.5, 1))
	else:
		effect_line.text = fac["descs"][level - 1]
		effect_line.add_theme_color_override("font_color", Color(0.75, 0.9, 0.75, 1))

	info.add_child(name_line)
	info.add_child(effect_line)
	row.add_child(info)

	# 오른쪽: 업그레이드 버튼
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(158, 0)
	if level >= 3:
		btn.text = "MAX"
		btn.disabled = true
	else:
		var cost: int = fac["costs"][level]
		var next_desc: String = fac["descs"][level]
		btn.text = "업그레이드\n👑 %d  →  %s" % [cost, next_desc]
		btn.disabled = GameSave.crown_shards < cost
		var fac_id: String = fac["id"]
		btn.pressed.connect(func() -> void: _upgrade(fac_id))
	row.add_child(btn)

	return row

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
	_build_facility_list()

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
	msg.text = "왕관 조각이 모일수록 성이 강해집니다.\n\n스테이지를 클리어할 때마다 조각을 획득합니다.\n조각으로 시설을 업그레이드해 다음 전투를 준비하세요."
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
	GameSave.start_chapter = GameSave.current_chapter
	GameSave.start_stage = GameSave.current_stage
	start_btn.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	)
