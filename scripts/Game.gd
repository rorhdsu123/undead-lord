extends Node2D

const WaveData = preload("res://scripts/WaveData.gd")
const Enemy = preload("res://scripts/Enemy.gd")
const EnemyScene = preload("res://scenes/Enemy.tscn")
const BossScene = preload("res://scenes/Boss.tscn")
const SkeletonWarriorScene = preload("res://scenes/SkeletonWarrior.tscn")

# 언데드 하인
var max_minions: int = 3
var minion_attack_bonus: float = 1.0
var minion_move_speed_bonus: float = 1.0
var minion_cost_reduction: int = 0
var minion_hp_bonus: float = 1.0
var minion_range_bonus: float = 0.0
var minion_lifesteal: float = 0.0

# 소환 가능 하인 타입 (영혼 비용 + UI 라벨)
const MINION_TYPES = [
	{"id": "warrior", "label": "전사",  "cost": 15},
	{"id": "archer",  "label": "궁수",  "cost": 25},
	{"id": "bomber",  "label": "폭탄병", "cost": 20},
	{"id": "tank",    "label": "탱크",  "cost": 35},
]
var summon_btns: Array = []

# 게임 상태
var current_chapter: int = 0
var current_stage: int = 0
var current_wave: int = 0
var castle_hp: int = 500
var castle_max_hp: int = 500
var wave_active: bool = false
var enemies_alive: int = 0

# 플레이어 스탯
var attack_bonus: float = 1.0
var graveyard_heal: int = 0

# 영혼 자원
var souls: int = 0
var _souls_shown: int = 0
var _souls_roll_tween: Tween = null
var _souls_bump_tween: Tween = null
const SPECIAL_COST: int = 50
const DOOM_SPECIAL_COST: int = 35
var special_cost: int = SPECIAL_COST

# 언데드 하인 상태
var active_minions: int = 0

# 성벽 경비 슬롯 (N/S/W/E, _ready에서 위치 초기화)
const CASTLE_S: float = 80.0   # CastleSprite.S 와 일치
const SLOT_OFFSET: float = 80.0  # 성벽 외면에 포스팅
var _minion_slots: Array = []

# 키스톤 (런 빌드 곱 레이어)
var lord_card_count: int = 0
var summoner_card_count: int = 0
var keystone1: String = ""   # "" | "kingdom"(영주) | "legion"(소환사)
var keystone2: String = ""   # "" | "berserker" | "cataclysm" | "horde" | "echo" | "ritual"
# 파생값(_recompute_keystones에서 재계산)
var keystone_lord_atk_mult: float = 1.0
var keystone_minion_atk_mult: float = 1.0
var keystone_revive_chance: float = 0.0
var keystone_echo_dmg: float = 0.0
var keystone_special_mult: float = 1.0
const KEYSTONE_ECHO_RADIUS: float = 90.0
var keystone_sacrifice_dmg_mult: float = 1.0
var keystone_sacrifice_radius_mult: float = 1.0
var keystone_sacrifice_refill: bool = false

# MD10 희생 시스템 (1탭 자동)
const SACRIFICE_RADIUS: float = 70.0      # 가제: 폭발 반경 (폭탄병 BOMB_RADIUS=80보다 작게)
const SACRIFICE_DMG: float = 40.0         # 가제: 폭발 피해 (폭탄병 60보다 약하게, MD8 위계)
const SACRIFICE_COOLDOWN: float = 8.0     # 가제: 발동당 쿨다운
var sacrifice_cooldown: float = 0.0       # 남은 쿨다운(초)

# 이번 판 왕관 조각 획득량
var crowns_this_run: int = 0
var run_start_time: float = 0.0

# 위엄 EXP — 런당 1회 부여 방지 (중복 호출 가드)
var _majesty_exp_granted: bool = false

# 시설 보너스
var soul_gain_mult: float = 1.0

# 가이드 오버레이 (튜토리얼)
var _guide_layer: CanvasLayer = null
var _guide_active: bool = false
var _guide_tween: Tween = null
var _special_atk_tip_shown: bool = false
var _freeze_for_special_tip: bool = false
var _special_atk_unlocked: bool = false

# 카드 풀 - 스킬 카드는 획득 후 제거, 스탯 카드는 계속 등장
const SKILL_CARDS = [
	{"id": "death_aura"},
	{"id": "skull_throw"},
	{"id": "decay_curse"},
]
const STAT_CARDS = [
	{"id": "arsenal"},
	{"id": "wall"},
	{"id": "graveyard"},
	{"id": "atk_speed"},
	{"id": "minion_speed"},
	{"id": "range_basic"},
	{"id": "range_all"},
	{"id": "minion_attack"},
	{"id": "minion_count"},
	{"id": "summon_speed"},
	{"id": "minion_hp"},
	{"id": "minion_range"},
	{"id": "minion_lifesteal"},
]

var available_skill_cards: Array = []
var current_cards: Array = []
const RARE_CHANCE: float = 0.3
const ALWAYS_RARE: Array[String] = ["minion_count", "range_all"]
const NEVER_RARE: Array[String] = ["minion_speed", "graveyard", "range_basic"]

# 카드 픽업 시각 효과: ID → 카테고리
const CARD_CATEGORY_MAP = {
	"arsenal":       "player",
	"atk_speed":     "player",
	"wall":          "castle",
	"graveyard":     "castle",
	"range_basic":   "range",
	"range_all":     "range",
	"minion_speed":    "minion",
	"minion_attack":   "minion",
	"minion_count":    "minion",
	"summon_speed":    "minion",
	"minion_hp":       "minion",
	"minion_range":    "minion",
	"minion_lifesteal": "minion",
	"death_aura":    "skill",
	"skull_throw":   "skill",
	"decay_curse":   "skill",
}

# 카드 → 축 분류
const CARD_AXIS = {
	"arsenal": "lord", "atk_speed": "lord", "range_basic": "lord", "range_all": "lord",
	"death_aura": "lord", "skull_throw": "lord", "decay_curse": "lord",
	"minion_speed": "summoner", "minion_attack": "summoner", "minion_count": "summoner", "summon_speed": "summoner",
	"minion_hp": "summoner", "minion_range": "summoner", "minion_lifesteal": "summoner",
	"wall": "neutral", "graveyard": "neutral",
}

# 연출/대사 텍스트
const GAME_START_LINES = [
	"...놈들이 또 몰려오는군.",
	"벌써 시간이 됐나.",
	"이 짓도 지겹다.",
	"또냐.",
]
const WAVE_CLEAR_LINES = [
	"다음.",
	"어림도 없다.",
	"약하군.",
	"계속 와라.",
	"...이 정도냐.",
]
const BOSS_INTRO_DIALOGUES = {
	"사관후보생":          "이, 이건 훈련 아닌가요...?",
	"수습 용사 인턴":      "저, 저는 아직 수습 기간이라서요...!",
	"용사 대리":           "부하들이 다 쓰러졌군요. 제가 직접 처리하겠습니다.",
	"정의의 용사 알바생":  "의뢰받은 일은 끝내고 가겠습니다.",
	"정의의 용사 과장":    "내가 직접 나설 줄은 몰랐겠지?",
}
const BOSS_ENTRANCE_PLAYER_LINES = ["또 왔군.", "이번엔 좀 강하려나.", "...지루하다.", "어디 해봐라."]
const BOSS_KILLED_MID_LINES      = ["다음은 누구냐.", "약하군.", "...그 정도냐."]
const BOSS_KILLED_FINAL_LINES    = ["조각이 돌아왔다.", "하나씩, 되찾겠다.", "...잘했다."]
const GAME_OVER_PLAYER_LINES     = ["...물러선다.", "오늘은 여기까지.", "다음엔 다르다."]
const GAME_CLEAR_PLAYER_LINES    = ["...잘 막았다.", "이 정도는 식은 죽.", "다음을 준비하라."]

const SHOP_ITEMS = [
	{"id": "repair",      "label": "성벽 수리",  "desc": "성 HP +60",         "cost": 40},
	{"id": "atk_boost",   "label": "공격 강화",  "desc": "공격력 +15%",        "cost": 35},
	{"id": "heal_minion", "label": "하인 치료",  "desc": "하인 HP 전체 회복",  "cost": 25},
	{"id": "minion_atk",  "label": "하인 강화",  "desc": "하인 공격력 +10%",   "cost": 18},
	{"id": "range_up",    "label": "저주 확장",  "desc": "기본 범위 +50",      "cost": 30},
]
var shop_btns: Array = []

@onready var castle_bar = $UI/CastleBar
@onready var castle_vis: Node2D = $Castle/CastleSprite
@onready var card_panel = $UI/CardPanel
@onready var card_title: Label = $UI/CardPanel/Title
@onready var card_subtitle: Label = $UI/CardPanel/Subtitle
@onready var result_panel = $UI/ResultPanel
@onready var result_btn1: Button = $UI/ResultPanel/Btn1
@onready var result_btn2: Button = $UI/ResultPanel/Btn2
@onready var enemies_node = $Enemies
@onready var wave_tracker = $UI/WaveTracker
var _last_tracker_sig: String = ""  # 직전 트래커 표시 노드 집합 시그니처(디졸브 트리거 판정용)
@onready var player = $Player
@onready var attack_button = $UI/AttackButton
var sacrifice_button: Button = null
@onready var summon_container: HBoxContainer = $UI/SummonContainer
@onready var minion_slot_label: Label = $UI/MinionSlotLabel
@onready var minions_node = $Minions
@onready var souls_label = $UI/SoulsLabel
var souls_icon: Label = null
var slot_icon: Label = null
@onready var shop_panel = $UI/ShopPanel
@onready var shop_title: Label = $UI/ShopPanel/ShopTitle
@onready var shop_subtitle: Label = $UI/ShopPanel/ShopSubtitle
@onready var shop_souls: Label = $UI/ShopPanel/ShopSouls
@onready var shop_items_node = $UI/ShopPanel/ShopItems
@onready var shop_close_btn = $UI/ShopPanel/CloseBtn
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var modal_dim: ColorRect = $UI/ModalDim

var _shop_btn_pulse_tween: Tween = null
var _card_rows: Array = []

func _ready() -> void:
	available_skill_cards = SKILL_CARDS.duplicate()
	card_title.text = Loc.t("card_select_title")
	card_subtitle.text = Loc.t("card_select_subtitle")
	result_btn1.pressed.connect(_on_result_btn1_pressed)
	result_btn2.pressed.connect(_on_result_btn2_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	attack_button.add_theme_font_size_override("font_size", 16)
	sacrifice_button = Button.new()
	sacrifice_button.focus_mode = Control.FOCUS_NONE
	sacrifice_button.add_theme_font_size_override("font_size", 20)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	attack_button.get_parent().add_child(sacrifice_button)
	shop_close_btn.pressed.connect(_close_shop)
	_build_shop_buttons()
	_build_summon_buttons()
	souls_icon = Label.new()
	souls_icon.text = "◆"
	souls_icon.add_theme_font_size_override("font_size", 16)
	souls_icon.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	souls_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	souls_label.get_parent().add_child(souls_icon)
	slot_icon = Label.new()
	slot_icon.text = "●"
	slot_icon.add_theme_font_size_override("font_size", 16)
	slot_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minion_slot_label.get_parent().add_child(slot_icon)
	_layout_bottom_ui()
	# 모달 입력 레이어링: Godot GUI 입력은 z_index가 아니라 트리 순서로 판정되므로
	# HUD < ModalDim < 모달 패널 < FadeRect 순서가 되도록 끝으로 차례로 이동.
	# (안 그러면 트리상 뒤에 있는 ModalDim(STOP)이 모달 버튼 클릭을 가로챔)
	var ui_layer: CanvasLayer = $UI
	for n in [modal_dim, card_panel, result_panel, shop_panel, fade_rect]:
		ui_layer.move_child(n, ui_layer.get_child_count() - 1)
	current_chapter = GameSave.start_chapter
	current_stage = GameSave.start_stage
	current_wave = 0
	GameSave.start_chapter = 0
	GameSave.start_stage = 0
	run_start_time = Time.get_ticks_msec() / 1000.0
	_init_slots()
	_fade_in()
	_apply_facility_bonuses()
	if _is_tutorial():
		souls += 30
	_update_souls_ui()
	if not _is_tutorial() and randf() < 0.3:
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			var line: String = GAME_START_LINES[randi() % GAME_START_LINES.size()]
			show_dialogue(line, Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
		)
	start_wave()

func start_wave() -> void:
	card_panel.visible = false
	if current_wave == 0:
		_build_wave_tracker()
	update_wave_tracker()

	var data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)

	if data["type"] == "shop":
		wave_active = false
		_reveal_wave_tracker()
		_show_shop()
		return

	wave_active = true
	_reveal_wave_tracker()

	# composition 기반 스폰
	var composition: Array = data["composition"]
	var base_hp: float = data["base_hp"]
	var base_speed: float = data["base_speed"]
	var base_damage: int = data["base_damage"]

	enemies_alive = 0
	for entry: Dictionary in composition:
		enemies_alive += entry["count"]

	var spawn_sides: Array = data.get("spawn_sides", ["N", "S", "E", "W"])
	for entry: Dictionary in composition:
		var preset: Dictionary = Enemy.TYPE_PRESETS[entry["enemy"]]
		var e_hp: float = base_hp * preset["hp_mult"]
		var e_spd: float = base_speed * preset["speed_mult"]
		var e_dmg: int = int(base_damage * preset["damage_mult"])
		for i in entry["count"]:
			var e = EnemyScene.instantiate()
			e.position = _random_spawn_pos(spawn_sides)
			e.enemy_type = entry["enemy"]
			e.hp = e_hp
			e.max_hp = e_hp
			e.speed = e_spd
			e.base_speed = e_spd
			e.damage = e_dmg
			e.game = self
			enemies_node.add_child(e)

	if data["type"] == "mid_boss" or data["type"] == "boss":
		enemies_alive += 1
		var b = BossScene.instantiate()
		b.position = _random_spawn_pos(data.get("spawn_sides", ["N"]))
		b.hp = data["boss_hp"]
		b.max_hp = data["boss_hp"]
		b.speed = data["boss_speed"]
		b.base_speed = data["boss_speed"]
		b.damage = data["boss_damage"]
		b.base_damage = data["boss_damage"]
		b.boss_name = data["boss_name"]
		b.boss_type = data["type"]
		b.game = self
		enemies_node.add_child(b)
		_on_boss_entered(b)
	if _is_tutorial():
		_trigger_wave_guide(current_wave)

func _reveal_wave_tracker() -> void:
	wave_tracker.visible = true
	wave_tracker.modulate.a = 1.0

func _on_boss_entered(boss_node: Node) -> void:
	_screen_shake(6.0, 0.35)
	_show_boss_title(boss_node.boss_name)
	# 보스 첫 대사 (보스 머리 위, 1.2초 후) - 보스가 아직 살아있고 웨이브 진행 중일 때만
	var intro: String = BOSS_INTRO_DIALOGUES.get(boss_node.boss_name, "")
	if intro != "":
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(boss_node) and wave_active:
				show_dialogue(intro, Color(1.0, 0.9, 0.35, 1), boss_node.global_position + Vector2(0, -40))
		)
	# 영주 냉소 대사 (영주 머리 위, 2.5초 후) - 웨이브 진행 중일 때만
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if not wave_active:
			return
		var line: String = BOSS_ENTRANCE_PLAYER_LINES[randi() % BOSS_ENTRANCE_PLAYER_LINES.size()]
		show_dialogue(line, Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
	)

func on_boss_killed(kill_pos: Vector2, shards: int, is_final: bool) -> void:
	_screen_flash(Color(1.0, 0.85, 0.2, 0.55), 0.5)
	if shards > 0:
		_show_crown_shard_gain(kill_pos, shards)

	# 해골 +1 또는 만랩 시 영혼 보너스 변환
	var gained: bool = GameSave.gain_skeleton()
	if gained:
		_show_skeleton_gain(kill_pos)
		if GameSave.skeleton_count == 1:
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				show_dialogue("해골 1마리가 당신을 따른다...", Color(0.7, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
			)
	else:
		add_souls(50)
		_show_souls_overflow(kill_pos)

	var lines: Array = BOSS_KILLED_FINAL_LINES if is_final else BOSS_KILLED_MID_LINES
	var line: String = lines[randi() % lines.size()]
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		show_dialogue(line, Color(0.85, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
	)

func _show_skeleton_gain(pos: Vector2) -> void:
	var label: Label = Label.new()
	label.text = "해골 +1"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
	label.size = Vector2(200, 50)
	label.position = pos + Vector2(-100, -140)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 60, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

func _show_souls_overflow(pos: Vector2) -> void:
	var label: Label = Label.new()
	label.text = "영혼 +50 (해골 만랩)"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0, 1))
	label.size = Vector2(260, 50)
	label.position = pos + Vector2(-130, -140)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 60, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

func boss_summon(enemy_type: String, count: int) -> void:
	if not wave_active:
		return
	var data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)
	var spawn_sides: Array = data.get("spawn_sides", ["N"])
	var preset: Dictionary = Enemy.TYPE_PRESETS[enemy_type]
	var e_hp: float = data["base_hp"] * preset["hp_mult"]
	var e_spd: float = data["base_speed"] * preset["speed_mult"]
	var e_dmg: int = int(data["base_damage"] * preset["damage_mult"])
	for i in count:
		var e = EnemyScene.instantiate()
		e.position = _random_spawn_pos(spawn_sides)
		e.enemy_type = enemy_type
		e.hp = e_hp
		e.max_hp = e_hp
		e.speed = e_spd
		e.base_speed = e_spd
		e.damage = e_dmg
		e.game = self
		enemies_node.add_child(e)
		enemies_alive += 1

func enemy_died(is_boss: bool = false) -> void:
	if not wave_active:
		return
	enemies_alive -= 1

	if is_boss and WaveData.get_wave(current_chapter, current_stage, current_wave).get("type") == "boss":
		game_clear()
		return

	if enemies_alive <= 0:
		end_wave()

func castle_take_damage(dmg: int) -> void:
	if castle_hp <= 0:
		return
	castle_hp -= dmg
	castle_bar.set_hp(castle_hp, castle_max_hp)
	castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
	if castle_hp <= 0:
		castle_hp = 0
		castle_bar.set_hp(castle_hp, castle_max_hp)
		game_over()

func end_wave() -> void:
	if not wave_active:
		return
	wave_active = false
	_close_guide()

	if graveyard_heal > 0:
		castle_hp = min(castle_hp + graveyard_heal, castle_max_hp)
		castle_bar.set_hp(castle_hp, castle_max_hp)

	if current_wave >= WaveData.stage_wave_count(current_chapter, current_stage) - 1:
		game_clear()
		return

	if not _is_tutorial() and randf() < 0.3:
		var line: String = WAVE_CLEAR_LINES[randi() % WAVE_CLEAR_LINES.size()]
		show_dialogue(line, Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))

	await get_tree().create_timer(1.2).timeout
	if not _is_tutorial():
		var wtype: String = WaveData.get_wave(current_chapter, current_stage, current_wave).get("type", "normal")
		if current_wave == 0 and keystone1 == "":
			_show_keystones(["kingdom", "legion"])
			return
		elif wtype == "mid_boss" and keystone2 == "" and keystone1 != "":
			var pool: Array = ["berserker", "cataclysm", "doom"] if keystone1 == "kingdom" else ["horde", "echo", "ritual"]
			pool.shuffle()
			_show_keystones(pool.slice(0, 2))
			return
	_show_cards()

func _show_cards() -> void:
	for n: Node in _card_rows:
		if is_instance_valid(n):
			n.queue_free()
	_card_rows.clear()

	var pool: Array = available_skill_cards.duplicate()
	for stat_card: Dictionary in STAT_CARDS:
		pool.append(stat_card)
	pool.shuffle()

	var skill_ids: Array = SKILL_CARDS.map(func(c: Dictionary) -> String: return c["id"])
	current_cards = []
	for c: Dictionary in pool.slice(0, 3):
		var card: Dictionary = {"id": c["id"]}
		if skill_ids.has(c["id"]) or ALWAYS_RARE.has(c["id"]):
			card["rare"] = true
		elif NEVER_RARE.has(c["id"]):
			card["rare"] = false
		else:
			card["rare"] = randf() < RARE_CHANCE
		current_cards.append(card)

	var card_h: float = 120.0
	var gap: float = 10.0
	var start_y: float = 250.0
	for i: int in 3:
		var row: Control = _build_card_row(current_cards[i], i, start_y + float(i) * (card_h + gap))
		card_panel.add_child(row)
		_card_rows.append(row)
		if current_cards[i]["rare"]:
			_flash_card_glow(row)

	card_panel.visible = true
	if _is_tutorial() and current_wave == 0:
		_show_card_guide.call_deferred()

func _pick_card(index: int) -> void:
	_close_guide()
	var card: Dictionary = current_cards[index]
	if card.get("keystone", false):
		_apply_keystone(card["id"])
		card_panel.visible = false
		_spawn_card_pickup_effect(card["id"])
		current_wave += 1
		start_wave()
		return
	var mult: float = 1.5 if card.get("rare", false) else 1.0
	_apply_card(card["id"], mult)

	for i in available_skill_cards.size():
		if available_skill_cards[i]["id"] == card["id"]:
			available_skill_cards.remove_at(i)
			break

	# 축 카운트 증가 (일반 카드만)
	var axis: String = CARD_AXIS.get(card["id"], "neutral")
	if axis == "lord":
		lord_card_count += 1
	elif axis == "summoner":
		summoner_card_count += 1
	_recompute_keystones()

	card_panel.visible = false
	_spawn_card_pickup_effect(card["id"])
	current_wave += 1
	start_wave()

func _recompute_keystones() -> void:
	keystone_lord_atk_mult = 1.0
	keystone_minion_atk_mult = 1.0
	keystone_revive_chance = 0.0
	keystone_echo_dmg = 0.0
	keystone_special_mult = 1.0
	keystone_sacrifice_dmg_mult = 1.0
	keystone_sacrifice_radius_mult = 1.0
	keystone_sacrifice_refill = false
	match keystone1:
		"kingdom":
			keystone_lord_atk_mult *= (1.30 + 0.06 * float(lord_card_count))
		"legion":
			keystone_minion_atk_mult *= (1.0 + 0.08 * float(summoner_card_count))
	match keystone2:
		"berserker":
			keystone_lord_atk_mult *= (1.0 + 0.08 * float(lord_card_count))
		"cataclysm":
			keystone_lord_atk_mult *= (1.0 + 0.08 * float(lord_card_count))
		"horde":
			keystone_revive_chance = min(0.30 + 0.04 * float(summoner_card_count), 0.80)
		"echo":
			keystone_echo_dmg = 20.0 * (1.0 + 0.10 * float(summoner_card_count))
		"doom":
			keystone_special_mult *= (1.0 + 0.12 * float(lord_card_count))
		"ritual":
			keystone_sacrifice_dmg_mult = 1.0 + 0.12 * float(summoner_card_count)
			keystone_sacrifice_radius_mult = 1.3
			keystone_sacrifice_refill = true

func _apply_keystone(id: String) -> void:
	match id:
		"kingdom":
			keystone1 = "kingdom"
		"legion":
			keystone1 = "legion"
			max_minions += 2
			_refresh_summon_buttons()
		"berserker":
			keystone2 = "berserker"
			player.attack_speed *= 1.5
		"cataclysm":
			keystone2 = "cataclysm"
			player.basic_range *= 1.4
			player.aura_radius *= 1.4
			player.curse_radius *= 1.4
			player._update_range_circles()
		"horde":
			keystone2 = "horde"
		"echo":
			keystone2 = "echo"
		"doom":
			keystone2 = "doom"
			special_cost = DOOM_SPECIAL_COST
			_update_attack_button()
		"ritual":
			keystone2 = "ritual"
	_recompute_keystones()

func _show_keystones(ids: Array) -> void:
	for n: Node in _card_rows:
		if is_instance_valid(n):
			n.queue_free()
	_card_rows.clear()

	current_cards = []
	for id: String in ids:
		current_cards.append({"id": id, "rare": true, "keystone": true})
	var stat_pool: Array = STAT_CARDS.duplicate()
	stat_pool.shuffle()
	var filler_id: String = stat_pool[0]["id"]
	current_cards.append({"id": filler_id, "rare": false})

	var card_h: float = 120.0
	var gap: float = 10.0
	var start_y: float = 250.0
	for i: int in current_cards.size():
		var row: Control = _build_card_row(current_cards[i], i, start_y + float(i) * (card_h + gap))
		card_panel.add_child(row)
		_card_rows.append(row)
		if current_cards[i].get("rare", false):
			_flash_card_glow(row)

	card_panel.visible = true

func _card_name(id: String) -> String:
	var full: String = Loc.t("card_%s" % id)
	var nl: int = full.find("\n")
	return full.substr(0, nl) if nl >= 0 else full

func _card_desc(id: String) -> String:
	var full: String = Loc.t("card_%s" % id)
	var nl: int = full.find("\n")
	return full.substr(nl + 1) if nl >= 0 else ""

func _format_axis_tags(s: String) -> String:
	s = s.replace("[영주]", "[color=#b5341f][lb]영주[rb][/color]")
	s = s.replace("[군단]", "[color=#0a7d6b][lb]군단[rb][/color]")
	return s

func _build_card_row(card: Dictionary, index: int, y_pos: float) -> Control:
	var is_rare: bool = card.get("rare", false)
	var bg_col: Color    = Color(0.97, 0.93, 0.82, 1.0) if is_rare else Color(0.91, 0.89, 0.97, 1.0)
	var border_col: Color = Color(0.88, 0.62, 0.08, 1.0) if is_rare else Color(0.48, 0.40, 0.75, 1.0)
	var badge_col: Color  = Color(0.88, 0.52, 0.04, 1.0) if is_rare else Color(0.50, 0.42, 0.76, 1.0)
	var art_col: Color    = Color(0.18, 0.11, 0.04, 1.0) if is_rare else Color(0.12, 0.08, 0.20, 1.0)
	var name_col: Color   = Color(0.13, 0.08, 0.05, 1.0)
	var desc_col: Color   = Color(0.35, 0.30, 0.28, 1.0)

	var card_w: float  = 444.0
	var card_h: float  = 120.0
	var art_sz: float  = 96.0
	var art_x: float   = 10.0
	var art_y: float   = 12.0
	var badge_w: float = 54.0
	var badge_h: float = 22.0
	var right_x: float = art_x + art_sz + 12.0
	var right_w: float = card_w - right_x - 8.0

	var root: Control = Control.new()
	root.position = Vector2(8.0, y_pos)
	root.size = Vector2(card_w, card_h)

	var bg: Panel = Panel.new()
	bg.size = Vector2(card_w, card_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = bg_col
	bg_style.set_border_width_all(2)
	bg_style.border_color = border_col
	bg_style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", bg_style)
	root.add_child(bg)

	var art: Panel = Panel.new()
	art.position = Vector2(art_x, art_y)
	art.size = Vector2(art_sz, art_sz)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_style: StyleBoxFlat = StyleBoxFlat.new()
	art_style.bg_color = art_col
	art_style.set_border_width_all(3)
	art_style.border_color = border_col
	art_style.set_corner_radius_all(6)
	art.add_theme_stylebox_override("panel", art_style)
	root.add_child(art)

	var badge_x: float = art_x + (art_sz - badge_w) * 0.5
	var badge_y: float = art_y - badge_h * 0.5
	var badge_bg: Panel = Panel.new()
	badge_bg.position = Vector2(badge_x, badge_y)
	badge_bg.size = Vector2(badge_w, badge_h)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = badge_col
	badge_style.set_border_width_all(1)
	badge_style.border_color = Color(1, 1, 1, 0.35)
	badge_style.set_corner_radius_all(11)
	badge_bg.add_theme_stylebox_override("panel", badge_style)
	root.add_child(badge_bg)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = Loc.t("rarity_legendary") if is_rare else Loc.t("rarity_common")
	badge_lbl.position = Vector2(badge_x, badge_y)
	badge_lbl.size = Vector2(badge_w, badge_h)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge_lbl)

	var name_lbl: Label = Label.new()
	name_lbl.text = _card_name(card["id"])
	name_lbl.position = Vector2(right_x, 16.0)
	name_lbl.size = Vector2(right_w, 34.0)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", name_col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	var desc: String = _card_desc(card["id"])
	if desc != "":
		var desc_lbl: RichTextLabel = RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.fit_content = true
		desc_lbl.scroll_active = false
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.position = Vector2(right_x, 54.0)
		desc_lbl.size = Vector2(right_w, 58.0)
		desc_lbl.add_theme_font_size_override("normal_font_size", 14)
		desc_lbl.add_theme_color_override("default_color", desc_col)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.text = _format_axis_tags(desc)
		root.add_child(desc_lbl)

	var btn: Button = Button.new()
	btn.size = Vector2(card_w, card_h)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	var idx: int = index
	btn.pressed.connect(func(): _pick_card(idx))
	root.add_child(btn)

	return root

func _flash_card_glow(row: Control) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(row, "modulate", Color(1.6, 1.35, 0.5, 1), 0.12)
	tween.tween_property(row, "modulate", Color(1.0, 1.0, 1.0, 1), 0.35)

func _apply_card(id: String, mult: float = 1.0) -> void:
	match id:
		"death_aura":
			player.has_death_aura = true
		"skull_throw":
			player.has_skull_throw = true
		"decay_curse":
			player.has_decay_curse = true
		"arsenal":
			attack_bonus += 0.2 * mult
		"wall":
			var hp_gain: int = int(50 * mult)
			castle_max_hp += hp_gain
			castle_hp += hp_gain
			castle_bar.set_hp(castle_hp, castle_max_hp)
		"graveyard":
			graveyard_heal += int(20 * mult)
		"atk_speed":
			player.attack_speed *= (1.0 + 0.2 * mult)
		"minion_speed":
			var spd_mult: float = 1.0 + 0.15 * mult
			minion_move_speed_bonus *= spd_mult
			for m in minions_node.get_children():
				m.move_speed *= spd_mult
		"minion_attack":
			var atk_mult: float = 1.0 + 0.2 * mult
			minion_attack_bonus *= atk_mult
			for m in minions_node.get_children():
				m.attack_damage *= atk_mult
				m.base_damage *= atk_mult
		"minion_count":
			max_minions += 1
		"summon_speed":
			minion_cost_reduction += int(5 * mult)
		"range_basic":
			player.basic_range += 30.0 * mult
			player._update_range_circles()
		"range_all":
			var range_mult: float = 1.0 + 0.25 * mult
			player.basic_range *= range_mult
			player.aura_radius *= range_mult
			player.curse_radius *= range_mult
			player._update_range_circles()
		"minion_hp":
			minion_hp_bonus *= (1.0 + 0.25 * mult)
		"minion_range":
			minion_range_bonus += 40.0 * mult
		"minion_lifesteal":
			minion_lifesteal += 0.20 * mult

## 웨이브 트래커 — 카피바라고 스타일 캡슐형 노드 스트립
## 아이콘은 NotoEmoji placeholder (아트 입고 후 교체)
const TRACKER_ICON_NORMAL:   String = "👾"
const TRACKER_ICON_SHOP:     String = "💰"
const TRACKER_ICON_MID_BOSS: String = "👹"
const TRACKER_ICON_BOSS:     String = "💀"

## 노드 종류별 배지 채움색
const TRACKER_COLOR_NORMAL:   Color = Color(0.28, 0.26, 0.34)
const TRACKER_COLOR_SHOP:     Color = Color(0.20, 0.35, 0.40)
const TRACKER_COLOR_MID_BOSS: Color = Color(0.40, 0.22, 0.48)
const TRACKER_COLOR_BOSS:     Color = Color(0.55, 0.15, 0.20)

## 배지 크기 (고정)
const TRACKER_BADGE_SIZE: float = 30.0

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
	_last_tracker_sig = ""
	update_wave_tracker()

func update_wave_tracker() -> void:
	## 매 웨이브 호출. 표시 노드 집합이 바뀐 경우에만 크로스페이드 디졸브(보스 정지·가로 이동 없음),
	## 같은 윈도우(하이라이트만 이동)·첫 렌더는 즉시 갱신.
	var disp: Dictionary = _compute_wave_display()
	if disp.is_empty():
		for child in wave_tracker.get_children():
			child.queue_free()
		_last_tracker_sig = ""
		return

	var sig: String = str(disp["indices"]) + "|" + str(disp["show_ellipsis"])
	var has_old: bool = wave_tracker.get_child_count() > 0

	if _last_tracker_sig == "" or sig == _last_tracker_sig or not has_old:
		# 첫 렌더 / 같은 윈도우(하이라이트만 이동) → 즉시
		_render_wave_tracker(disp)
	else:
		# 윈도우(표시 노드 집합) 변경 → 진짜 크로스페이드(겹쳐서 동시 페이드, 빈 순간 없음·가로 이동 없음)
		var old_wrap: Control = wave_tracker.get_child(0)
		var new_wrap: Control = _render_wave_tracker(disp, false)  # 기존(old) 유지, 새 wrap을 위에 겹침
		new_wrap.modulate.a = 0.0
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(old_wrap, "modulate:a", 0.0, 0.12)
		tw.tween_property(new_wrap, "modulate:a", 1.0, 0.12)
		tw.chain().tween_callback(old_wrap.queue_free)
	_last_tracker_sig = sig

func _compute_wave_display() -> Dictionary:
	## 현재 웨이브 기준 표시할 노드 집합(항상 4칸 윈도우)을 계산. waves가 비면 {} 반환.
	var waves: Array = WaveData.CHAPTERS[current_chapter]["stages"][current_stage]["waves"]
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
		var s: int = clampi(current_wave - (current_wave % 2), 0, boss_idx - 3)
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
		for child in wave_tracker.get_children():
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
	chip_lbl.text = Loc.t("stage_label") % [current_chapter + 1, current_stage + 1]
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
	wave_tracker.add_child(wrap)

	# ── HBoxContainer (노드 배지들의 가로 행) ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(hbox)

	# 윈도우 항목 생성
	for w_idx in display_indices:
		var col := _make_badge_column(waves[w_idx], w_idx + 1, w_idx == current_wave, emoji_font)
		# 지난 노드(현재보다 앞) → 회색 흐림
		if w_idx < current_wave:
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
		var boss_col := _make_badge_column(waves[boss_idx], boss_idx + 1, boss_idx == current_wave, emoji_font)
		if boss_idx < current_wave:
			boss_col.modulate = Color(0.5, 0.5, 0.5)
		hbox.add_child(boss_col)

	return wrap

func _build_shop_buttons() -> void:
	for i in SHOP_ITEMS.size():
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
		# hover 상태: 약간 밝게 + 골드 테두리
		var sh: StyleBoxFlat = StyleBoxFlat.new()
		sh.bg_color = Color(0.24, 0.21, 0.32, 0.95)
		sh.border_width_left = 2
		sh.border_width_top = 2
		sh.border_width_right = 2
		sh.border_width_bottom = 2
		sh.border_color = Color(0.8, 0.72, 0.5)
		sh.corner_radius_top_left = 8
		sh.corner_radius_top_right = 8
		sh.corner_radius_bottom_right = 8
		sh.corner_radius_bottom_left = 8
		sh.content_margin_left = 12.0
		sh.content_margin_right = 12.0
		sh.content_margin_top = 8.0
		sh.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("hover", sh)
		# pressed 상태: 더 어둡게
		var sp: StyleBoxFlat = StyleBoxFlat.new()
		sp.bg_color = Color(0.14, 0.12, 0.18, 0.95)
		sp.border_width_left = 2
		sp.border_width_top = 2
		sp.border_width_right = 2
		sp.border_width_bottom = 2
		sp.border_color = Color(0.55, 0.5, 0.68)
		sp.corner_radius_top_left = 8
		sp.corner_radius_top_right = 8
		sp.corner_radius_bottom_right = 8
		sp.corner_radius_bottom_left = 8
		sp.content_margin_left = 12.0
		sp.content_margin_right = 12.0
		sp.content_margin_top = 8.0
		sp.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("pressed", sp)
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
		btn.pressed.connect(func(): _buy_item(idx))
		shop_items_node.add_child(btn)
		shop_btns.append(btn)

func _show_shop() -> void:
	modal_dim.visible = true
	_refresh_shop_buttons()
	shop_panel.visible = true
	summon_container.visible = false
	minion_slot_label.visible = false
	shop_title.text = Loc.t("shop_title")
	shop_subtitle.text = Loc.t("shop_subtitle")
	if _is_tutorial():
		_show_shop_guide()

func _close_shop() -> void:
	_close_guide()
	# 튜토리얼 상점 가이드 복원
	if _shop_btn_pulse_tween and _shop_btn_pulse_tween.is_valid():
		_shop_btn_pulse_tween.kill()
	_shop_btn_pulse_tween = null
	shop_close_btn.modulate = Color.WHITE
	shop_title.text = Loc.t("shop_title")
	shop_panel.visible = false
	modal_dim.visible = false
	summon_container.visible = true
	minion_slot_label.visible = true
	current_wave += 1
	start_wave()

func _buy_item(index: int) -> void:
	var item: Dictionary = SHOP_ITEMS[index]
	if souls < item["cost"]:
		return
	souls -= item["cost"]
	_update_souls_ui()
	_apply_shop_item(item["id"])
	_refresh_shop_buttons()

func _apply_shop_item(id: String) -> void:
	match id:
		"repair":
			castle_hp = min(castle_hp + 60, castle_max_hp)
			castle_bar.set_hp(castle_hp, castle_max_hp)
		"atk_boost":
			attack_bonus *= 1.15
		"heal_minion":
			for m in minions_node.get_children():
				if is_instance_valid(m):
					m.hp = m.max_hp
					m.hp_bar.value = 100.0
		"minion_atk":
			minion_attack_bonus *= 1.1
			for m in minions_node.get_children():
				m.attack_damage *= 1.1
				m.base_damage *= 1.1
		"range_up":
			player.basic_range += 50
			player._update_range_circles()

func _refresh_shop_buttons() -> void:
	for i in SHOP_ITEMS.size():
		var item: Dictionary = SHOP_ITEMS[i]
		var btn: Button = shop_btns[i]
		btn.text = "%s  [영혼 %d]\n%s" % [item["label"], item["cost"], item["desc"]]
		btn.disabled = souls < item["cost"]
	shop_souls.text = Loc.t("shop_owned_souls") % souls

func earn_crown_shards(n: int) -> void:
	if n <= 0:
		return
	crowns_this_run += n
	GameSave.add_crown_shards(n)

# 현재 스테이지에 "boss" 타입 웨이브가 있는지 확인 (위엄 EXP 보너스 판정용)
func _stage_has_final_boss() -> bool:
	var wave_count: int = WaveData.stage_wave_count(current_chapter, current_stage)
	for w: int in wave_count:
		if WaveData.get_wave(current_chapter, current_stage, w).get("type", "") == "boss":
			return true
	return false

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d분 %02d초" % [mins, secs]

func game_over() -> void:
	wave_active = false
	_close_guide()
	card_panel.visible = false
	shop_panel.visible = false
	summon_container.visible = false
	minion_slot_label.visible = false

	# 적·하인 처리 정지
	for e in enemies_node.get_children():
		if is_instance_valid(e):
			e.set_physics_process(false)
			e.set_process(false)
	for m in minions_node.get_children():
		if is_instance_valid(m):
			m.set_physics_process(false)
			m.set_process(false)

	# 영주 대사
	var line: String = GAME_OVER_PLAYER_LINES[randi() % GAME_OVER_PLAYER_LINES.size()]
	show_dialogue(line, Color(0.9, 0.55, 0.55, 1), player.global_position + Vector2(0, -60))

	# 붉은 오버레이 페이드인 → 패널 등장
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.4, 0.0, 0.0, 0.0)
	overlay.size = Vector2(480, 960)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(overlay)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - run_start_time
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.55, 0.9)
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		overlay.queue_free()
		# 위엄 EXP 부여 (실패 완충 — 소량, 런당 1회)
		var majesty_gain: int = 0
		if not _majesty_exp_granted:
			_majesty_exp_granted = true
			const GAME_OVER_MAJESTY: int = 5
			GameSave.add_majesty_exp(GAME_OVER_MAJESTY)
			majesty_gain = GAME_OVER_MAJESTY
		var rewards: Array = []
		if crowns_this_run > 0:
			rewards.append({"icon": "👑", "qty": "+%d" % crowns_this_run})
		if majesty_gain > 0:
			rewards.append({"icon": "✦", "qty": "+%d" % majesty_gain})
		_show_result(
			false,
			"성이 함락됐다...",
			"스테이지 %d-%d  웨이브 %d" % [current_chapter + 1, current_stage + 1, current_wave + 1],
			_format_time(elapsed),
			rewards,
			"↩  다시 시작",
			"retry",
			true
		)
	)

func game_clear() -> void:
	wave_active = false
	_close_guide()
	card_panel.visible = false
	summon_container.visible = false
	minion_slot_label.visible = false

	# 영주 대사
	var line: String = GAME_CLEAR_PLAYER_LINES[randi() % GAME_CLEAR_PLAYER_LINES.size()]
	show_dialogue(line, Color(0.85, 0.95, 0.75, 1), player.global_position + Vector2(0, -60))

	# 금빛 오버레이 페이드인 → 패널 등장
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.9, 0.8, 0.1, 0.0)
	overlay.size = Vector2(480, 960)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(overlay)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - run_start_time
	var next_ch: int = current_chapter
	var next_st: int = current_stage + 1
	if next_st >= WaveData.chapter_stage_count(current_chapter):
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
		if not _majesty_exp_granted:
			_majesty_exp_granted = true
			majesty_gain = 40 if _stage_has_final_boss() else 20
			GameSave.add_majesty_exp(majesty_gain)
		if has_next:
			if current_chapter == 0 and current_stage == 0:
				GameSave.tutorial_completed = true
			GameSave.current_chapter = next_ch
			GameSave.current_stage = next_st
			GameSave.save_data()
		var rewards: Array = []
		if crowns_this_run > 0:
			rewards.append({"icon": "👑", "qty": "+%d" % crowns_this_run})
		if majesty_gain > 0:
			rewards.append({"icon": "✦", "qty": "+%d" % majesty_gain})
		_show_result(
			true,
			"스테이지 클리어!",
			"%d-%d 완료" % [current_chapter + 1, current_stage + 1],
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
	result_panel.add_theme_stylebox_override("panel", rp_style)

	# ── 이전 동적 자식 제거 (Btn1/Btn2는 .tscn 정적 노드 — 건드리지 않음) ───
	for child in result_panel.get_children():
		if child != result_btn1 and child != result_btn2:
			child.queue_free()

	# ── 콘텐츠 VBox ─────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	# 콘텐츠 컨테이너는 패널 전체를 덮으므로 입력 통과(IGNORE) — 안 그러면 하단 버튼 클릭을 가로챔
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(vbox)

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
	result_btn1.text = btn1_text
	result_btn1.disabled = not btn1_enabled
	result_btn1.set_meta("action", btn1_action)
	result_btn1.add_theme_font_size_override("font_size", 17)
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
	result_btn1.add_theme_stylebox_override("normal", b1n)
	# Btn1 hover
	var b1h := StyleBoxFlat.new()
	b1h.bg_color = Color(0.75, 0.58, 0.18, 0.98)
	b1h.border_width_left = 2; b1h.border_width_top = 2
	b1h.border_width_right = 2; b1h.border_width_bottom = 2
	b1h.border_color = Color(1.0, 0.95, 0.55, 1.0)
	b1h.corner_radius_top_left = 8; b1h.corner_radius_top_right = 8
	b1h.corner_radius_bottom_left = 8; b1h.corner_radius_bottom_right = 8
	b1h.content_margin_left = 12.0; b1h.content_margin_right = 12.0
	b1h.content_margin_top = 10.0; b1h.content_margin_bottom = 10.0
	result_btn1.add_theme_stylebox_override("hover", b1h)
	# Btn1 pressed
	var b1p := StyleBoxFlat.new()
	b1p.bg_color = Color(0.45, 0.33, 0.07, 0.98)
	b1p.border_width_left = 2; b1p.border_width_top = 2
	b1p.border_width_right = 2; b1p.border_width_bottom = 2
	b1p.border_color = Color(0.85, 0.70, 0.25, 1.0)
	b1p.corner_radius_top_left = 8; b1p.corner_radius_top_right = 8
	b1p.corner_radius_bottom_left = 8; b1p.corner_radius_bottom_right = 8
	b1p.content_margin_left = 12.0; b1p.content_margin_right = 12.0
	b1p.content_margin_top = 10.0; b1p.content_margin_bottom = 10.0
	result_btn1.add_theme_stylebox_override("pressed", b1p)
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
	result_btn1.add_theme_stylebox_override("disabled", b1d)
	result_btn1.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0) if btn1_enabled else Color(0.50, 0.47, 0.38, 1.0))
	result_btn1.add_theme_color_override("font_color_disabled", Color(0.50, 0.47, 0.38, 1.0))

	# Btn2 (보조) — 차분한 보라/회색
	result_btn2.text = "로비로 돌아가기"
	result_btn2.disabled = false
	result_btn2.add_theme_font_size_override("font_size", 15)
	var b2n := StyleBoxFlat.new()
	b2n.bg_color = Color(0.18, 0.16, 0.24, 0.88)
	b2n.border_width_left = 1; b2n.border_width_top = 1
	b2n.border_width_right = 1; b2n.border_width_bottom = 1
	b2n.border_color = Color(0.55, 0.50, 0.68, 0.80)
	b2n.corner_radius_top_left = 8; b2n.corner_radius_top_right = 8
	b2n.corner_radius_bottom_left = 8; b2n.corner_radius_bottom_right = 8
	b2n.content_margin_left = 12.0; b2n.content_margin_right = 12.0
	b2n.content_margin_top = 8.0; b2n.content_margin_bottom = 8.0
	result_btn2.add_theme_stylebox_override("normal", b2n)
	var b2h := StyleBoxFlat.new()
	b2h.bg_color = Color(0.24, 0.21, 0.32, 0.92)
	b2h.border_width_left = 1; b2h.border_width_top = 1
	b2h.border_width_right = 1; b2h.border_width_bottom = 1
	b2h.border_color = Color(0.72, 0.68, 0.85, 0.90)
	b2h.corner_radius_top_left = 8; b2h.corner_radius_top_right = 8
	b2h.corner_radius_bottom_left = 8; b2h.corner_radius_bottom_right = 8
	b2h.content_margin_left = 12.0; b2h.content_margin_right = 12.0
	b2h.content_margin_top = 8.0; b2h.content_margin_bottom = 8.0
	result_btn2.add_theme_stylebox_override("hover", b2h)
	result_btn2.add_theme_color_override("font_color", Color(0.82, 0.80, 0.90, 1.0))

	# ── 모달 + 패널 표시 ────────────────────────────────────────────────────
	modal_dim.visible = true
	result_panel.visible = true

	# ── 패널 등장 애니 (scale pop + fade) ────────────────────────────────────
	result_panel.pivot_offset = result_panel.size / 2.0
	result_panel.modulate.a = 0.0
	result_panel.scale = Vector2(0.9, 0.9)
	var anim_tw: Tween = create_tween()
	anim_tw.set_parallel(true)
	anim_tw.tween_property(result_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tw.tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		$UI.add_child(piece)
		var fall_tw: Tween = create_tween()
		var fall_y: float = randf_range(700.0, 980.0)
		var fall_dur: float = randf_range(1.2, 2.2)
		fall_tw.set_parallel(true)
		fall_tw.tween_property(piece, "position:y", fall_y, fall_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tw.tween_property(piece, "rotation", piece.rotation + randf_range(4.0, 10.0), fall_dur)
		fall_tw.tween_property(piece, "modulate:a", 0.0, fall_dur).set_delay(fall_dur * 0.6)
		fall_tw.tween_callback(piece.queue_free).set_delay(fall_dur)

func _fade_in() -> void:
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.4)

func _on_result_btn1_pressed() -> void:
	var action: String = result_btn1.get_meta("action", "retry")
	if action == "next_stage":
		GameSave.start_chapter = GameSave.current_chapter
		GameSave.start_stage = GameSave.current_stage
	else:
		GameSave.start_chapter = current_chapter
		GameSave.start_stage = current_stage
	_fade_to_scene("res://scenes/Game.tscn")

func _on_result_btn2_pressed() -> void:
	_fade_to_scene("res://scenes/Lobby.tscn")

func _fade_to_scene(path: String) -> void:
	result_btn1.disabled = true
	result_btn2.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(path)
	)

func _process(delta: float) -> void:
	if sacrifice_cooldown > 0.0:
		sacrifice_cooldown = max(0.0, sacrifice_cooldown - delta)
	_update_attack_button()
	_refresh_summon_buttons()
	_update_sacrifice_button()

func _on_attack_pressed() -> void:
	if not wave_active:
		return
	if _is_tutorial() and not _special_atk_unlocked:
		return
	if souls < special_cost:
		return
	_close_guide()  # 특수기 팁 동결 중이면 즉시 해제
	souls -= special_cost
	_update_souls_ui()
	player.use_special_attack()

func _update_attack_button() -> void:
	if not wave_active:
		attack_button.disabled = true
		attack_button.text = "특수기 (%d)" % special_cost
		return
	if _is_tutorial() and not _special_atk_unlocked:
		attack_button.disabled = true
		attack_button.text = "특수기 (잠금)"
		return
	if souls >= special_cost:
		attack_button.disabled = false
		attack_button.text = "특수기 (%d)" % special_cost
	else:
		attack_button.disabled = true
		attack_button.text = "특수기 (%d/%d)" % [souls, special_cost]

func _update_sacrifice_button() -> void:
	if not is_instance_valid(sacrifice_button):
		return
	if not wave_active:
		sacrifice_button.disabled = true
		sacrifice_button.text = Loc.t("sacrifice_btn_idle")
		return
	# 1-1 튜토리얼 전체에서 희생 잠금 (열리는 웨이브는 추후 튜토리얼 기획 때 보강)
	if _is_tutorial():
		sacrifice_button.disabled = true
		sacrifice_button.text = Loc.t("sacrifice_btn_locked")
		return
	if sacrifice_cooldown > 0.0:
		sacrifice_button.disabled = true
		sacrifice_button.text = Loc.t("sacrifice_btn_cooldown") % ceili(sacrifice_cooldown)
		return
	# 희생할 상주 하인이 없으면 비활성
	if _find_frontline_minion() == null:
		sacrifice_button.disabled = true
		sacrifice_button.text = Loc.t("sacrifice_btn_idle")
		return
	sacrifice_button.disabled = false
	sacrifice_button.text = Loc.t("sacrifice_btn_idle")

func _on_sacrifice_pressed() -> void:
	if not wave_active:
		return
	if _is_tutorial():
		return
	if sacrifice_cooldown > 0.0:
		return
	var target: Node = _find_frontline_minion()
	if target == null:
		return
	_close_guide()
	_sacrifice_minion(target)
	sacrifice_cooldown = SACRIFICE_COOLDOWN

func _find_frontline_minion() -> Node:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best: Node = null
	var best_dist: float = INF
	var fallback: Node = null   # 적이 없을 때용 (첫 상주 하인)
	for m in minions_node.get_children():
		if not is_instance_valid(m):
			continue
		if m.get("minion_type") == null or m.minion_type == "bomber":
			continue
		if fallback == null:
			fallback = m
		for e in enemies:
			if not is_instance_valid(e):
				continue
			var d: float = m.position.distance_to(e.position)
			if d < best_dist:
				best_dist = d
				best = m
	return best if best != null else fallback

func _sacrifice_minion(m: Node) -> void:
	var t: String = m.minion_type
	_sacrifice_explosion(m.position)
	m.sacrifice()
	# 제물의 의식: 희생 경로에서만 무료 재소환 (일반 사망 경로 제외)
	if keystone_sacrifice_refill and active_minions < max_minions:
		_spawn_minion(t)

func _sacrifice_explosion(pos: Vector2) -> void:
	var radius: float = SACRIFICE_RADIUS * keystone_sacrifice_radius_mult
	var dmg: float = SACRIFICE_DMG * keystone_sacrifice_dmg_mult
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.position.distance_to(pos) <= radius:
			e.take_damage(dmg)
	spawn_explosion_effect(pos)

func _apply_facility_bonuses() -> void:
	var fl: Dictionary = GameSave.facility_levels

	souls += fl.get("throne", 0) * 20

	var wall_hp: int = [0, 50, 100, 150][fl.get("wall", 0)]
	castle_max_hp += wall_hp
	castle_hp += wall_hp
	castle_bar.set_hp(castle_hp, castle_max_hp)

	var graveyard_bonus: int = [0, 15, 30, 50][fl.get("graveyard", 0)]
	graveyard_heal += graveyard_bonus

	var arsenal_mult: float = [1.0, 1.1, 1.22, 1.37][fl.get("arsenal", 0)]
	attack_bonus *= arsenal_mult

	soul_gain_mult = [1.0, 1.2, 1.4, 1.6][fl.get("banquet", 0)]

func add_souls(n: int) -> void:
	souls += int(n * soul_gain_mult)
	_update_souls_ui()

func _update_souls_ui() -> void:
	if _souls_roll_tween and _souls_roll_tween.is_valid():
		_souls_roll_tween.kill()
	if _souls_shown == souls:
		souls_label.text = "영혼: %d" % souls
	else:
		_souls_roll_tween = create_tween()
		_souls_roll_tween.tween_method(_set_souls_display, _souls_shown, souls, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bump_souls_label()

func _set_souls_display(v: float) -> void:
	_souls_shown = int(round(v))
	souls_label.text = "영혼: %d" % _souls_shown

func _bump_souls_label() -> void:
	if _souls_bump_tween and _souls_bump_tween.is_valid():
		_souls_bump_tween.kill()
	souls_label.pivot_offset = Vector2(0.0, souls_label.size.y * 0.5)
	souls_label.scale = Vector2.ONE
	_souls_bump_tween = create_tween()
	_souls_bump_tween.tween_property(souls_label, "scale", Vector2(1.15, 1.15), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_souls_bump_tween.tween_property(souls_label, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _build_summon_buttons() -> void:
	for i in MINION_TYPES.size():
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 16)
		var idx: int = i
		btn.pressed.connect(func(): _on_summon_pressed(idx))
		summon_container.add_child(btn)
		summon_btns.append(btn)

func _layout_bottom_ui() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var mx: float = 10.0
	var btn_w: float = vp.x - mx * 2
	var atk_h: float = 50.0
	var sum_h: float = 48.0
	var lbl_h: float = 20.0
	var bottom_margin: float = 20.0
	var gap: float = 22.0

	var btn_gap: float = 8.0
	var attack_w: float = (btn_w - btn_gap) * 0.6
	var sacrifice_w: float = (btn_w - btn_gap) * 0.4
	var atk_y: float = vp.y - bottom_margin - atk_h
	attack_button.position = Vector2(mx, atk_y)
	attack_button.size = Vector2(attack_w, atk_h)
	if is_instance_valid(sacrifice_button):
		sacrifice_button.position = Vector2(mx + attack_w + btn_gap, atk_y)
		sacrifice_button.size = Vector2(sacrifice_w, atk_h)

	summon_container.position = Vector2(mx, attack_button.position.y - gap - sum_h)
	summon_container.size = Vector2(btn_w, sum_h)

	minion_slot_label.position = Vector2(0, summon_container.position.y - 4 - lbl_h)
	minion_slot_label.size = Vector2(vp.x - mx, lbl_h)
	minion_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var icon_w: float = 18.0
	var icon_gap: float = 4.0
	souls_icon.position = Vector2(mx, minion_slot_label.position.y)
	souls_icon.size = Vector2(icon_w, lbl_h)
	souls_label.position = Vector2(mx + icon_w + icon_gap, minion_slot_label.position.y)
	souls_label.size = Vector2(vp.x * 0.5 - icon_w - icon_gap, lbl_h)
	souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	souls_label.add_theme_font_size_override("font_size", 16)
	slot_icon.size = Vector2(icon_w, lbl_h)
	slot_icon.position.y = minion_slot_label.position.y

func _refresh_summon_buttons() -> void:
	var slot_full: bool = active_minions >= max_minions
	minion_slot_label.text = "%d/%d" % [active_minions, max_minions]
	var slot_col: Color = Color(1.0, 0.5, 0.5) if slot_full else Color(0.85, 1.0, 0.85)
	minion_slot_label.add_theme_color_override("font_color", slot_col)
	if is_instance_valid(slot_icon):
		slot_icon.add_theme_color_override("font_color", slot_col)
		slot_icon.visible = minion_slot_label.visible
		var f: Font = minion_slot_label.get_theme_font("font")
		var fs: int = minion_slot_label.get_theme_font_size("font")
		var tw: float = f.get_string_size(minion_slot_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var num_left: float = minion_slot_label.position.x + minion_slot_label.size.x - tw
		slot_icon.position.x = num_left - 4.0 - slot_icon.size.x
	if is_instance_valid(souls_icon):
		souls_icon.visible = souls_label.visible
	var is_tut: bool = _is_tutorial()
	for i in MINION_TYPES.size():
		var entry: Dictionary = MINION_TYPES[i]
		var cost: int = max(5, entry["cost"] - minion_cost_reduction)
		var btn: Button = summon_btns[i]
		if is_tut and (current_wave < 1 or i > 0):
			btn.text = "%s (잠금)" % [entry["label"]]
			btn.disabled = true
		else:
			btn.text = "%s\n%d 영혼" % [entry["label"], cost]
			btn.disabled = (not wave_active) or slot_full or souls < cost

func _on_summon_pressed(index: int) -> void:
	if not wave_active:
		return
	if _is_tutorial() and (current_wave < 1 or index > 0):
		return
	if active_minions >= max_minions:
		return
	var entry: Dictionary = MINION_TYPES[index]
	var cost: int = max(5, entry["cost"] - minion_cost_reduction)
	if souls < cost:
		return
	souls -= cost
	_update_souls_ui()
	_close_guide()
	_spawn_minion(entry["id"])

func _init_slots() -> void:
	var c: Vector2 = $Castle.global_position
	_minion_slots = [
		{"dir": "N", "pos": Vector2(c.x, c.y - SLOT_OFFSET), "minion": null},
		{"dir": "S", "pos": Vector2(c.x, c.y + SLOT_OFFSET), "minion": null},
		{"dir": "W", "pos": Vector2(c.x - SLOT_OFFSET, c.y), "minion": null},
		{"dir": "E", "pos": Vector2(c.x + SLOT_OFFSET, c.y), "minion": null},
	]

func _get_empty_slot() -> int:
	for i in _minion_slots.size():
		var s: Dictionary = _minion_slots[i]
		if s["minion"] == null or not is_instance_valid(s["minion"]):
			return i
	return -1

func _random_spawn_pos(sides: Array) -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var side: String = sides[randi() % sides.size()]
	match side:
		"N": return Vector2(randf_range(40, vp.x - 40), -25)
		"S": return Vector2(randf_range(40, vp.x - 40), vp.y + 25)
		"E": return Vector2(vp.x + 25, randf_range(120, vp.y - 120))
		"W": return Vector2(-25, randf_range(120, vp.y - 120))
	return Vector2(randf_range(40, vp.x - 40), -25)

func _spawn_minion(type_id: String) -> void:
	var m = SkeletonWarriorScene.instantiate()
	m.position = $Castle.position
	m.game = self
	m.minion_type = type_id
	minions_node.add_child(m)
	var slot_idx: int = _get_empty_slot()
	if slot_idx >= 0:
		m.guard_slot_index = slot_idx
		m.has_post = true
		m.guard_post = _minion_slots[slot_idx]["pos"]
		_minion_slots[slot_idx]["minion"] = m
	# 카드 보너스 반영 (프리셋 적용 후)
	m.base_damage *= minion_attack_bonus * keystone_minion_atk_mult
	m.attack_damage = m.base_damage
	m.move_speed *= minion_move_speed_bonus
	m.max_hp *= minion_hp_bonus
	m.base_max_hp *= minion_hp_bonus
	m.hp = m.max_hp
	m.attack_range += minion_range_bonus
	m.lifesteal = minion_lifesteal
	active_minions += 1
	spawn_summon_effect(m.position)

func minion_died(pos = null, type_id: String = "", slot_idx: int = -1) -> void:
	active_minions = max(0, active_minions - 1)
	if slot_idx >= 0 and slot_idx < _minion_slots.size():
		_minion_slots[slot_idx]["minion"] = null
	if pos == null:
		return
	# 죽음의 메아리: 사망 폭발
	if keystone_echo_dmg > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.position.distance_to(pos) <= KEYSTONE_ECHO_RADIUS:
				e.take_damage(keystone_echo_dmg)
		_spawn_echo_effect(pos)
	# 영원한 군세: 재소환
	if keystone_revive_chance > 0.0 and type_id != "" and active_minions < max_minions:
		if randf() < keystone_revive_chance:
			_spawn_minion(type_id)

func _spawn_echo_effect(pos: Vector2) -> void:
	var n: Node2D = Node2D.new()
	n.position = pos
	add_child(n)
	var seg: int = 32
	var base_r: float = 10.0
	var fill: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = (TAU / seg) * i
		pts.append(Vector2(cos(a) * base_r, sin(a) * base_r))
	fill.polygon = pts
	fill.color = Color(0.4, 0.8, 1.0, 0.7)
	n.add_child(fill)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(n, "scale", Vector2.ONE * (KEYSTONE_ECHO_RADIUS / base_r), 0.4)
	tween.parallel().tween_property(n, "modulate:a", 0.0, 0.4)
	tween.tween_callback(n.queue_free)

func show_dialogue(text: String, color: Color = Color(1, 1, 0.3, 1), world_pos: Vector2 = Vector2(240, 400)) -> void:
	var label: Label = Label.new()
	label.text = '"%s"' % text
	label.size = Vector2(440, 60)
	label.position = Vector2(world_pos.x - 220, world_pos.y - 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func hit_stop(duration: float = 0.06) -> void:
	# 순간 정지 → 무게감. time_scale=0이라 ignore_time_scale 타이머로 실시간 복구.
	Engine.time_scale = 0.0
	var t: SceneTreeTimer = get_tree().create_timer(duration, true, false, true)
	await t.timeout
	Engine.time_scale = 1.0

func _screen_shake(intensity: float = 6.0, duration: float = 0.35) -> void:
	var origin: Vector2 = position
	var tween: Tween = create_tween()
	for i: int in 7:
		tween.tween_property(self, "position",
			origin + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)),
			duration / 7.0)
	tween.tween_property(self, "position", origin, 0.05)

func _screen_flash(color: Color, duration: float = 0.4) -> void:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(480, 960)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(rect)
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)

func _show_boss_title(boss_name: String) -> void:
	var vp_w: float = get_viewport_rect().size.x
	var label: Label = Label.new()
	label.text = "— %s —" % boss_name
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1))
	label.size = Vector2(vp_w, 50)
	label.position = Vector2(0, 210)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	$UI.add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _show_crown_shard_gain(pos: Vector2, shards: int) -> void:
	var label: Label = Label.new()
	label.text = "+%d 왕관" % shards
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	label.size = Vector2(200, 50)
	label.position = pos + Vector2(-100, -100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 60, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

func spawn_damage_number(pos: Vector2, dmg: float, tier: String = "normal") -> void:
	var label: Label = Label.new()
	label.text = "-%d" % int(dmg)
	add_child(label)

	match tier:
		"resist":
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
			label.position = pos + Vector2(-12, -32)
			var tween: Tween = create_tween()
			tween.parallel().tween_property(label, "position:y", label.position.y - 20, 0.6)
			tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
			tween.tween_callback(label.queue_free)
		"crit":
			label.add_theme_font_size_override("font_size", 32)
			label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1))
			label.position = pos + Vector2(-20, -48)
			var tween: Tween = create_tween()
			tween.parallel().tween_property(label, "position:y", label.position.y - 45, 0.8)
			tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
			tween.parallel().tween_property(label, "modulate", Color(1.0, 0.8, 0.1, 1), 0.8)
			# 좌우 살짝 흔들림
			var shake_tween: Tween = create_tween()
			shake_tween.tween_property(label, "position:x", label.position.x + 6.0, 0.08)
			shake_tween.tween_property(label, "position:x", label.position.x - 6.0, 0.08)
			shake_tween.tween_property(label, "position:x", label.position.x + 3.0, 0.06)
			shake_tween.tween_property(label, "position:x", label.position.x, 0.06)
			tween.tween_callback(label.queue_free)
		_: # "normal"
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1, 0.85, 0.85, 1))
			label.position = pos + Vector2(-12, -32)
			var tween: Tween = create_tween()
			tween.parallel().tween_property(label, "position:y", label.position.y - 30, 0.6)
			tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
			tween.tween_callback(label.queue_free)

func show_crit_text() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var label: Label = Label.new()
	label.text = "치명타!"
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	label.size = Vector2(vp_size.x, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, vp_size.y * 0.38)
	label.scale = Vector2(0.4, 0.4)
	label.pivot_offset = Vector2(vp_size.x * 0.5, 40)
	label.modulate.a = 1.0
	$UI.add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)

func spawn_death_effect(pos: Vector2, color: Color = Color(1, 0.6, 0.4, 1)) -> void:
	for i in 6:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.position = pos - Vector2(4, 4)
		dot.color = color
		add_child(dot)
		var angle: float = randf_range(0, TAU)
		var distance: float = randf_range(20, 50)
		var target_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * distance - Vector2(4, 4)
		var tween: Tween = create_tween()
		tween.parallel().tween_property(dot, "position", target_pos, 0.4)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.4)
		tween.tween_callback(dot.queue_free)

func spawn_explosion_effect(pos: Vector2) -> void:
	for i in 14:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(10, 10)
		dot.position = pos - Vector2(5, 5)
		dot.color = Color(1.0, 0.55, 0.15, 1)
		add_child(dot)
		var angle: float = randf_range(0, TAU)
		var distance: float = randf_range(45, 95)
		var target_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * distance - Vector2(5, 5)
		var tween: Tween = create_tween()
		tween.parallel().tween_property(dot, "position", target_pos, 0.5)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.5)
		tween.tween_callback(dot.queue_free)

func spawn_evolve_effect(pos: Vector2) -> void:
	for i in 6:
		var ring: ColorRect = ColorRect.new()
		ring.size = Vector2(6, 6)
		ring.color = Color(1.0, 0.95, 0.5, 0.9)
		var angle: float = (TAU / 6.0) * i
		var start_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 30 - Vector2(3, 3)
		ring.position = start_pos
		add_child(ring)
		var target_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 5 - Vector2(3, 3)
		var tween: Tween = create_tween()
		tween.parallel().tween_property(ring, "position", target_pos, 0.4)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
		tween.tween_callback(ring.queue_free)

func _spawn_card_pickup_effect(card_id: String) -> void:
	var category: String = CARD_CATEGORY_MAP.get(card_id, "player")
	var castle_pos: Vector2 = $Castle.global_position
	match category:
		"player":
			_spawn_pulse_ring(player.global_position, 110.0, Color(1.0, 0.35, 0.35, 0.75), 6.0)
		"castle":
			_spawn_pulse_ring(castle_pos, 90.0, Color(0.45, 0.75, 1.0, 0.8), 6.0)
		"range":
			_spawn_pulse_ring(player.global_position, player.basic_range, Color(0.75, 0.4, 1.0, 0.55), 4.0)
		"minion":
			var any_minion: bool = false
			for m in minions_node.get_children():
				if is_instance_valid(m):
					_spawn_pulse_ring(m.global_position, 55.0, Color(0.75, 0.35, 1.0, 0.85), 5.0)
					any_minion = true
			if not any_minion:
				_spawn_pulse_ring(castle_pos, 90.0, Color(0.75, 0.35, 1.0, 0.7), 5.0)
		"skill":
			_spawn_pulse_ring(player.global_position, 280.0, Color(1.0, 0.85, 0.25, 0.7), 7.0)

func _spawn_pulse_ring(pos: Vector2, max_radius: float, color: Color, _line_width: float = 5.0) -> void:
	var n: Node2D = Node2D.new()
	n.position = pos
	add_child(n)
	var base_r: float = 12.0
	var seg: int = 32
	var fill: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = (TAU / seg) * i
		pts.append(Vector2(cos(a) * base_r, sin(a) * base_r))
	fill.polygon = pts
	fill.color = Color(color.r, color.g, color.b, color.a * 0.6)
	n.add_child(fill)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(n, "scale", Vector2.ONE * (max_radius / base_r), 0.55)
	tween.parallel().tween_property(n, "modulate:a", 0.0, 0.55)
	tween.tween_callback(n.queue_free)

func spawn_summon_effect(pos: Vector2) -> void:
	for i in 8:
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color(0.6, 0.2, 0.9, 0.9)
		var angle: float = randf_range(0, TAU)
		var distance: float = randf_range(40, 70)
		var start_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * distance - Vector2(3, 3)
		dot.position = start_pos
		add_child(dot)
		var tween: Tween = create_tween()
		tween.parallel().tween_property(dot, "position", pos - Vector2(3, 3), 0.3)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.3)
		tween.tween_callback(dot.queue_free)

# ── 튜토리얼 가이드 시스템 ───────────────────────────────────

func _is_tutorial() -> bool:
	return current_chapter == 0 and current_stage == 0 and not GameSave.tutorial_completed

func _trigger_wave_guide(wave_idx: int) -> void:
	match wave_idx:
		0:
			show_tutorial_tip("또 몰려오는군.\n성이 무너지면 끝이다.", castle_bar, 4.5)
		1:
			if summon_btns.size() > 0:
				show_tutorial_tip("전사를 소환해 방어를 강화하세요!", summon_btns[0], 12.0)
		2:
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if wave_active:
					show_dialogue("빠른 놈이군.", Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
			)
		4:
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if wave_active:
					show_dialogue("...큰 놈이다.", Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
			)
			if not _special_atk_tip_shown:
				get_tree().create_timer(2.0).timeout.connect(func() -> void:
					if not wave_active or _special_atk_tip_shown:
						return
					souls = max(souls, special_cost)
					_update_souls_ui()
					_special_atk_tip_shown = true
					_special_atk_unlocked = true
					show_tutorial_tip("특수기로 적을 한번에 처리하세요!", attack_button, 0.0)
					_freeze_for_special_tip = true
					_set_battle_freeze(true)
				)

func _show_card_guide() -> void:
	if _card_rows.size() < 3:
		return
	show_guide("카드를 선택하세요. 영주가 강해집니다.", [
		{"rect": _card_rows[0].get_global_rect(), "callback": func() -> void: _pick_card(0), "text": _card_name(current_cards[0]["id"]), "rare": current_cards[0]["rare"]},
		{"rect": _card_rows[1].get_global_rect(), "callback": func() -> void: _pick_card(1), "text": _card_name(current_cards[1]["id"]), "rare": current_cards[1]["rare"]},
		{"rect": _card_rows[2].get_global_rect(), "callback": func() -> void: _pick_card(2), "text": _card_name(current_cards[2]["id"]), "rare": current_cards[2]["rare"]},
	])

func _show_shop_guide() -> void:
	# 타이틀을 튜토리얼 안내 문구로 교체 (부제에 힌트 표시)
	shop_subtitle.text = "영혼으로 강화하고 '다음 웨이브'를 누르세요"

	# 닫기 버튼 노란 펄스 글로우
	if _shop_btn_pulse_tween and _shop_btn_pulse_tween.is_valid():
		_shop_btn_pulse_tween.kill()
	_shop_btn_pulse_tween = create_tween().set_loops()
	_shop_btn_pulse_tween.tween_property(shop_close_btn, "modulate", Color(1.6, 1.35, 0.5, 1), 0.5)
	_shop_btn_pulse_tween.tween_property(shop_close_btn, "modulate", Color(1.0, 1.0, 1.0, 1), 0.5)

func show_tutorial_tip(message: String, target: Control, duration: float = 4.0) -> void:
	_close_guide()
	_guide_active = true
	_guide_layer = CanvasLayer.new()
	_guide_layer.layer = 80
	add_child(_guide_layer)

	var rect: Rect2 = target.get_global_rect()

	var border: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.9, 0.2, 0.9)
	style.set_corner_radius_all(6)
	border.add_theme_stylebox_override("panel", style)
	border.position = rect.position - Vector2(4, 4)
	border.size = rect.size + Vector2(8, 8)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(border)

	var arrow_base_y: float = rect.position.y - 40
	var arrow: Label = Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.position = Vector2(rect.position.x + rect.size.x * 0.5 - 12, arrow_base_y)
	_guide_layer.add_child(arrow)

	var msg_y: float = arrow_base_y - 58
	if msg_y < 5:
		msg_y = rect.position.y + rect.size.y + 30
	var msg: Label = Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", 18)
	msg.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size = Vector2(440, 70)
	msg.position = Vector2(20, msg_y)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(msg)

	_guide_tween = create_tween().set_loops()
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y + 8, 0.4)
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y, 0.4)

	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(func() -> void: _close_guide())

func show_guide(message: String, targets: Array) -> void:
	_close_guide()
	_guide_active = true
	_guide_layer = CanvasLayer.new()
	_guide_layer.layer = 80
	add_child(_guide_layer)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(480, 960)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_guide_layer.add_child(bg)

	for tgt: Dictionary in targets:
		var rect: Rect2 = tgt["rect"]

		var border: Panel = Panel.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.set_border_width_all(3)
		style.border_color = Color(1.0, 0.9, 0.2, 1)
		style.set_corner_radius_all(6)
		border.add_theme_stylebox_override("panel", style)
		border.position = rect.position - Vector2(4, 4)
		border.size = rect.size + Vector2(8, 8)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_guide_layer.add_child(border)

		var proxy: Button = Button.new()
		proxy.position = rect.position
		proxy.size = rect.size
		var is_rare: bool = tgt.get("rare", false)
		var card_bg: StyleBoxFlat = StyleBoxFlat.new()
		card_bg.bg_color = Color(0.97, 0.93, 0.82, 1) if is_rare else Color(0.91, 0.89, 0.97, 1)
		card_bg.set_border_width_all(2)
		card_bg.border_color = Color(0.88, 0.62, 0.08, 1) if is_rare else Color(0.48, 0.40, 0.75, 1)
		card_bg.set_corner_radius_all(8)
		proxy.add_theme_stylebox_override("normal", card_bg)
		proxy.add_theme_stylebox_override("hover", card_bg)
		proxy.add_theme_stylebox_override("pressed", card_bg)
		proxy.add_theme_stylebox_override("focus", card_bg)
		if tgt.has("text"):
			proxy.text = tgt["text"]
			proxy.add_theme_font_size_override("font_size", 18)
			proxy.add_theme_color_override("font_color", Color(0.13, 0.08, 0.05, 1))
		var cb: Callable = tgt["callback"]
		proxy.pressed.connect(func() -> void:
			_close_guide()
			cb.call()
		)
		_guide_layer.add_child(proxy)

	var first_rect: Rect2 = targets[0]["rect"]
	var last_rect: Rect2 = targets[targets.size() - 1]["rect"]
	var center_x: float = (first_rect.position.x + last_rect.position.x + last_rect.size.x) * 0.5
	var arrow_base_y: float = first_rect.position.y - 42

	var arrow: Label = Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.position = Vector2(center_x - 14, arrow_base_y)
	_guide_layer.add_child(arrow)

	var msg_y: float = arrow_base_y - 65
	if msg_y < 5:
		msg_y = first_rect.position.y + first_rect.size.y + 30
	var msg: Label = Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", 18)
	msg.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size = Vector2(440, 70)
	msg.position = Vector2(20, msg_y)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(msg)

	_guide_tween = create_tween().set_loops()
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y + 10, 0.45)
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y, 0.45)

func _set_battle_freeze(frozen: bool) -> void:
	for e in enemies_node.get_children():
		if is_instance_valid(e):
			e.set_physics_process(not frozen)
			e.set_process(not frozen)
	for m in minions_node.get_children():
		if is_instance_valid(m):
			m.set_physics_process(not frozen)
			m.set_process(not frozen)
	player.set_physics_process(not frozen)

func _close_guide() -> void:
	if _guide_tween != null and _guide_tween.is_valid():
		_guide_tween.kill()
	_guide_tween = null
	if is_instance_valid(_guide_layer):
		_guide_layer.queue_free()
	_guide_layer = null
	_guide_active = false
	if _freeze_for_special_tip:
		_freeze_for_special_tip = false
		_set_battle_freeze(false)

