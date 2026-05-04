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

# 소환 가능 하인 타입 (영혼 비용 + UI 라벨)
const MINION_TYPES = [
	{"id": "warrior", "label": "⚔ 전사",  "cost": 15},
	{"id": "archer",  "label": "🏹 궁수",  "cost": 25},
	{"id": "bomber",  "label": "💣 폭탄병", "cost": 20},
	{"id": "tank",    "label": "🛡 탱크",  "cost": 35},
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
const SPECIAL_COST: int = 50

# 언데드 하인 상태
var active_minions: int = 0

# 이번 판 왕관 조각 획득량
var crowns_this_run: int = 0
var run_start_time: float = 0.0

# 시설 보너스
var soul_gain_mult: float = 1.0

# 가이드 오버레이 (튜토리얼)
var _guide_layer: CanvasLayer = null
var _guide_active: bool = false
var _guide_tween: Tween = null
var _special_atk_tip_shown: bool = false

# 카드 풀 - 스킬 카드는 획득 후 제거, 스탯 카드는 계속 등장
const SKILL_CARDS = [
	{"id": "death_aura",  "label": "죽음의 오라\n주변 적 지속 피해"},
	{"id": "skull_throw", "label": "저주 해골 던지기\n관통 투사체 발사"},
	{"id": "decay_curse", "label": "부패의 저주\n범위 내 적 슬로우"},
]
const STAT_CARDS = [
	{"id": "arsenal",       "label": "무기고\n공격력 +20%"},
	{"id": "wall",          "label": "성벽 강화\n최대 HP +50"},
	{"id": "graveyard",     "label": "묘지\n웨이브 클리어 시 HP +20 회복"},
	{"id": "atk_speed",     "label": "영주 공격속도 +20%"},
	{"id": "minion_speed",  "label": "언데드 가속\n하인 이동 속도 +15%"},
	{"id": "range_basic",   "label": "저주의 손길\n기본 공격 범위 +30"},
	{"id": "range_all",     "label": "어둠의 확장\n모든 범위 +25%"},
	{"id": "minion_attack", "label": "언데드 강화\n하인 공격력 +20%"},
	{"id": "minion_count",  "label": "군세 확장\n최대 소환 수 +1"},
	{"id": "summon_speed",  "label": "어둠의 효율\n소환 비용 -5 영혼"},
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
	"minion_speed":  "minion",
	"minion_attack": "minion",
	"minion_count":  "minion",
	"summon_speed":  "minion",
	"death_aura":    "skill",
	"skull_throw":   "skill",
	"decay_curse":   "skill",
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
var tracker_btns: Array = []

@onready var wave_label = $UI/WaveLabel
@onready var castle_hp_bar = $Castle/CastleHP
@onready var card_panel = $UI/CardPanel
@onready var card_btn1 = $UI/CardPanel/Card1
@onready var card_btn2 = $UI/CardPanel/Card2
@onready var card_btn3 = $UI/CardPanel/Card3
@onready var result_panel = $UI/ResultPanel
@onready var result_label = $UI/ResultPanel/ResultLabel
@onready var sub_label = $UI/ResultPanel/SubLabel
@onready var time_label: Label = $UI/ResultPanel/TimeLabel
@onready var result_btn1: Button = $UI/ResultPanel/Btn1
@onready var result_btn2: Button = $UI/ResultPanel/Btn2
@onready var enemies_node = $Enemies
@onready var wave_tracker = $UI/WaveTracker
@onready var player = $Player
@onready var attack_button = $UI/AttackButton
@onready var summon_container: HBoxContainer = $UI/SummonContainer
@onready var minion_slot_label: Label = $UI/MinionSlotLabel
@onready var minions_node = $Minions
@onready var souls_label = $UI/SoulsLabel
@onready var crown_label = $UI/ResultPanel/CrownLabel
@onready var shop_panel = $UI/ShopPanel
@onready var shop_items_node = $UI/ShopPanel/ShopItems
@onready var shop_close_btn = $UI/ShopPanel/CloseBtn
@onready var fade_rect: ColorRect = $UI/FadeRect

func _ready() -> void:
	available_skill_cards = SKILL_CARDS.duplicate()
	card_btn1.pressed.connect(func(): _pick_card(0))
	card_btn2.pressed.connect(func(): _pick_card(1))
	card_btn3.pressed.connect(func(): _pick_card(2))
	result_btn1.pressed.connect(_on_result_btn1_pressed)
	result_btn2.pressed.connect(_on_result_btn2_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	shop_close_btn.pressed.connect(_close_shop)
	_build_shop_buttons()
	_build_summon_buttons()
	current_chapter = GameSave.start_chapter
	current_stage = GameSave.start_stage
	current_wave = 0
	GameSave.start_chapter = 0
	GameSave.start_stage = 0
	run_start_time = Time.get_ticks_msec() / 1000.0
	_fade_in()
	_apply_facility_bonuses()
	if _is_tutorial():
		souls += 30
	_update_souls_ui()
	if randf() < 0.3:
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			var line: String = GAME_START_LINES[randi() % GAME_START_LINES.size()]
			show_dialogue(line, Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
		)
	start_wave()

func start_wave() -> void:
	card_panel.visible = false
	wave_label.text = "%d-%d" % [current_chapter + 1, current_stage + 1]
	if current_wave == 0:
		_build_wave_tracker()
	update_wave_tracker()

	var data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)

	if data["type"] == "shop":
		wave_active = false
		_show_shop()
		return

	wave_active = true

	# composition 기반 스폰
	var composition: Array = data["composition"]
	var base_hp: float = data["base_hp"]
	var base_speed: float = data["base_speed"]
	var base_damage: int = data["base_damage"]

	enemies_alive = 0
	for entry: Dictionary in composition:
		enemies_alive += entry["count"]

	for entry: Dictionary in composition:
		var preset: Dictionary = Enemy.TYPE_PRESETS[entry["enemy"]]
		var e_hp: float = base_hp * preset["hp_mult"]
		var e_spd: float = base_speed * preset["speed_mult"]
		var e_dmg: int = int(base_damage * preset["damage_mult"])
		for i in entry["count"]:
			var e = EnemyScene.instantiate()
			e.position = Vector2(randf_range(100, 924), randf_range(-50, -200))
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
		b.position = Vector2(512, -250)
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

func _on_boss_entered(boss_node: Node) -> void:
	_screen_shake(6.0, 0.35)
	_show_boss_title(boss_node.boss_name)
	# 보스 첫 대사 (보스 머리 위, 1.2초 후)
	var intro: String = BOSS_INTRO_DIALOGUES.get(boss_node.boss_name, "...")
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(boss_node):
			show_dialogue(intro, Color(1.0, 0.9, 0.35, 1), boss_node.global_position + Vector2(0, -40))
	)
	# 영주 냉소 대사 (영주 머리 위, 2.5초 후)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		var line: String = BOSS_ENTRANCE_PLAYER_LINES[randi() % BOSS_ENTRANCE_PLAYER_LINES.size()]
		show_dialogue(line, Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
	)

func on_boss_killed(kill_pos: Vector2, shards: int, is_final: bool) -> void:
	_screen_flash(Color(1.0, 0.85, 0.2, 0.55), 0.5)
	if shards > 0:
		_show_crown_shard_gain(kill_pos, shards)
	var lines: Array = BOSS_KILLED_FINAL_LINES if is_final else BOSS_KILLED_MID_LINES
	var line: String = lines[randi() % lines.size()]
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		show_dialogue(line, Color(0.85, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
	)

func boss_summon(enemy_type: String, count: int) -> void:
	if not wave_active:
		return
	var data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)
	var preset: Dictionary = Enemy.TYPE_PRESETS[enemy_type]
	var e_hp: float = data["base_hp"] * preset["hp_mult"]
	var e_spd: float = data["base_speed"] * preset["speed_mult"]
	var e_dmg: int = int(data["base_damage"] * preset["damage_mult"])
	for i in count:
		var e = EnemyScene.instantiate()
		e.position = Vector2(randf_range(100, 924), randf_range(-150, -50))
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
	castle_hp_bar.value = float(castle_hp) / float(castle_max_hp) * 100.0
	if castle_hp <= 0:
		castle_hp = 0
		castle_hp_bar.value = 0.0
		game_over()

func end_wave() -> void:
	if not wave_active:
		return
	wave_active = false
	_close_guide()

	if graveyard_heal > 0:
		castle_hp = min(castle_hp + graveyard_heal, castle_max_hp)
		castle_hp_bar.value = float(castle_hp) / float(castle_max_hp) * 100.0

	if current_wave >= WaveData.stage_wave_count(current_chapter, current_stage) - 1:
		game_clear()
		return

	if randf() < 0.3:
		var line: String = WAVE_CLEAR_LINES[randi() % WAVE_CLEAR_LINES.size()]
		show_dialogue(line, Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))

	_show_cards()

func _show_cards() -> void:
	var pool: Array = available_skill_cards.duplicate()
	pool.append_array(STAT_CARDS)
	pool.shuffle()

	var skill_ids: Array = SKILL_CARDS.map(func(c: Dictionary) -> String: return c["id"])
	current_cards = []
	for c: Dictionary in pool.slice(0, 3):
		var card: Dictionary = c.duplicate()
		if skill_ids.has(c["id"]) or ALWAYS_RARE.has(c["id"]):
			card["rare"] = true
		elif NEVER_RARE.has(c["id"]):
			card["rare"] = false
		else:
			card["rare"] = randf() < RARE_CHANCE
		current_cards.append(card)

	var btns: Array[Button] = [card_btn1, card_btn2, card_btn3]
	for i: int in 3:
		var card: Dictionary = current_cards[i]
		btns[i].text = ("✦ " + card["label"] + " ✦") if card["rare"] else card["label"]
		_apply_card_btn_style(btns[i], card["rare"])

	card_panel.visible = true
	if _is_tutorial() and current_wave == 0:
		_show_card_guide.call_deferred()

	for i: int in 3:
		if current_cards[i]["rare"]:
			_flash_button_glow(btns[i])

func _pick_card(index: int) -> void:
	_close_guide()
	var card: Dictionary = current_cards[index]
	var mult: float = 1.5 if card.get("rare", false) else 1.0
	_apply_card(card["id"], mult)

	for i in available_skill_cards.size():
		if available_skill_cards[i]["id"] == card["id"]:
			available_skill_cards.remove_at(i)
			break

	card_panel.visible = false
	_spawn_card_pickup_effect(card["id"])
	current_wave += 1
	start_wave()

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
			castle_hp_bar.value = float(castle_hp) / float(castle_max_hp) * 100.0
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

func _build_wave_tracker() -> void:
	for child in wave_tracker.get_children():
		child.queue_free()
	tracker_btns.clear()

	var waves: Array = WaveData.CHAPTERS[current_chapter]["stages"][current_stage]["waves"]
	for w_idx in waves.size():
		var wave_data: Dictionary = waves[w_idx]
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match wave_data.get("type", "normal"):
			"boss":     btn.text = "💀"
			"mid_boss": btn.text = "⚠"
			"shop":     btn.text = "💰"
			_:          btn.text = str(w_idx + 1)
		wave_tracker.add_child(btn)
		tracker_btns.append(btn)

func update_wave_tracker() -> void:
	for i in tracker_btns.size():
		if i == current_wave:
			tracker_btns[i].modulate = Color(1, 1, 0)
		elif i < current_wave:
			tracker_btns[i].modulate = Color(0.4, 0.4, 0.4)
		else:
			tracker_btns[i].modulate = Color(1, 1, 1)

func _build_shop_buttons() -> void:
	for i in SHOP_ITEMS.size():
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 58)
		var idx: int = i
		btn.pressed.connect(func(): _buy_item(idx))
		shop_items_node.add_child(btn)
		shop_btns.append(btn)

func _show_shop() -> void:
	_refresh_shop_buttons()
	shop_panel.visible = true
	summon_container.visible = false
	minion_slot_label.visible = false
	if _is_tutorial():
		_show_shop_guide()

func _close_shop() -> void:
	_close_guide()
	shop_panel.visible = false
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
			castle_hp_bar.value = float(castle_hp) / float(castle_max_hp) * 100.0
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

func earn_crown_shards(n: int) -> void:
	if n <= 0:
		return
	crowns_this_run += n
	GameSave.add_crown_shards(n)

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

	# 영주 대사
	var line: String = GAME_OVER_PLAYER_LINES[randi() % GAME_OVER_PLAYER_LINES.size()]
	show_dialogue(line, Color(0.9, 0.55, 0.55, 1), player.global_position + Vector2(0, -60))

	# 붉은 오버레이 페이드인 → 패널 등장
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.4, 0.0, 0.0, 0.0)
	overlay.size = Vector2(1024, 700)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(overlay)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - run_start_time
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.55, 0.9)
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		overlay.queue_free()
		result_label.text = "성이 함락됐다..."
		sub_label.text = "스테이지 %d-%d  웨이브 %d" % [current_chapter + 1, current_stage + 1, current_wave + 1]
		time_label.text = "⏱ %s" % _format_time(elapsed)
		crown_label.text = "👑 +%d (총 %d개)" % [crowns_this_run, GameSave.crown_shards] if crowns_this_run > 0 else ""
		result_btn1.text = "↩  다시 시작"
		result_btn1.disabled = false
		result_btn1.set_meta("action", "retry")
		result_panel.visible = true
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
	overlay.size = Vector2(1024, 700)
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
		result_label.text = "스테이지 클리어!"
		sub_label.text = "%d-%d 완료" % [current_chapter + 1, current_stage + 1]
		time_label.text = "⏱ %s" % _format_time(elapsed)
		crown_label.text = "👑 +%d (총 %d개)" % [crowns_this_run, GameSave.crown_shards]
		if has_next:
			if current_chapter == 0 and current_stage == 0:
				GameSave.tutorial_completed = true
			GameSave.current_chapter = next_ch
			GameSave.current_stage = next_st
			GameSave.save_data()
			result_btn1.disabled = false
		else:
			result_btn1.disabled = true
		result_btn1.text = "▶  다음 스테이지"
		result_btn1.set_meta("action", "next_stage")
		result_panel.visible = true
	)

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

func _process(_delta) -> void:
	_update_attack_button()
	_refresh_summon_buttons()

func _on_attack_pressed() -> void:
	if not wave_active:
		return
	if souls < SPECIAL_COST:
		return
	souls -= SPECIAL_COST
	_update_souls_ui()
	player.use_special_attack()

func _update_attack_button() -> void:
	if not wave_active:
		attack_button.disabled = true
		attack_button.text = "⚔ 특수기 (%d)" % SPECIAL_COST
		return
	if souls >= SPECIAL_COST:
		attack_button.disabled = false
		attack_button.text = "⚔ 특수기 (%d)" % SPECIAL_COST
	else:
		attack_button.disabled = true
		attack_button.text = "⚔ 특수기 (%d/%d)" % [souls, SPECIAL_COST]

func _apply_facility_bonuses() -> void:
	var fl: Dictionary = GameSave.facility_levels

	souls += fl.get("throne", 0) * 20

	var wall_hp: int = [0, 50, 100, 150][fl.get("wall", 0)]
	castle_max_hp += wall_hp
	castle_hp += wall_hp
	castle_hp_bar.value = float(castle_hp) / float(castle_max_hp) * 100.0

	var graveyard_bonus: int = [0, 15, 30, 50][fl.get("graveyard", 0)]
	graveyard_heal += graveyard_bonus

	var arsenal_mult: float = [1.0, 1.1, 1.22, 1.37][fl.get("arsenal", 0)]
	attack_bonus *= arsenal_mult

	soul_gain_mult = [1.0, 1.2, 1.4, 1.6][fl.get("banquet", 0)]

func add_souls(n: int) -> void:
	souls += int(n * soul_gain_mult)
	_update_souls_ui()
	if _is_tutorial() and not _special_atk_tip_shown and souls >= SPECIAL_COST:
		_special_atk_tip_shown = true
		show_tutorial_tip("특수기로 적을 한번에 처리하세요!", attack_button, 8.0)

func _update_souls_ui() -> void:
	souls_label.text = "영혼: %d" % souls

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

func _refresh_summon_buttons() -> void:
	var slot_full: bool = active_minions >= max_minions
	minion_slot_label.text = "🧟 하인 슬롯 %d/%d" % [active_minions, max_minions]
	if slot_full:
		minion_slot_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		minion_slot_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	var is_tut: bool = _is_tutorial()
	for i in MINION_TYPES.size():
		var entry: Dictionary = MINION_TYPES[i]
		var cost: int = max(5, entry["cost"] - minion_cost_reduction)
		var btn: Button = summon_btns[i]
		if is_tut and (current_wave < 1 or i > 0):
			btn.text = "%s\n🔒" % [entry["label"]]
			btn.disabled = true
		else:
			btn.text = "%s\n💀 %d" % [entry["label"], cost]
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
	_spawn_minion(entry["id"])

func _spawn_minion(type_id: String) -> void:
	var m = SkeletonWarriorScene.instantiate()
	m.position = $Castle.position + Vector2(randf_range(-30, 30), -50)
	m.game = self
	m.minion_type = type_id
	minions_node.add_child(m)
	# 카드 보너스 반영 (프리셋 적용 후)
	m.base_damage *= minion_attack_bonus
	m.attack_damage = m.base_damage
	m.move_speed *= minion_move_speed_bonus
	active_minions += 1
	spawn_summon_effect(m.position)

func minion_died() -> void:
	active_minions = max(0, active_minions - 1)

func show_dialogue(text: String, color: Color = Color(1, 1, 0.3, 1), world_pos: Vector2 = Vector2(512, 300)) -> void:
	var label: Label = Label.new()
	label.text = '"%s"' % text
	label.size = Vector2(700, 60)
	label.position = Vector2(world_pos.x - 350, world_pos.y - 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

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
	rect.size = Vector2(1024, 700)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(rect)
	var tween: Tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)

func _show_boss_title(boss_name: String) -> void:
	var label: Label = Label.new()
	label.text = "— %s —" % boss_name
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1))
	label.size = Vector2(900, 50)
	label.position = Vector2(62, 210)
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
	label.text = "+%d 👑" % shards
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

func spawn_damage_number(pos: Vector2, dmg: float) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % int(dmg)
	label.position = pos + Vector2(-12, -32)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.85, 1))
	add_child(label)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
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

func _apply_card_btn_style(btn: Button, is_rare: bool) -> void:
	if is_rare:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.13, 0.02, 1)
		style.set_border_width_all(3)
		style.border_color = Color(1.0, 0.85, 0.2, 1)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1))
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_color_override("font_color")

func _flash_button_glow(btn: Button) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(btn, "modulate", Color(1.6, 1.35, 0.5, 1), 0.12)
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1), 0.3)

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

func _spawn_pulse_ring(pos: Vector2, max_radius: float, color: Color, line_width: float = 5.0) -> void:
	var n: Node2D = Node2D.new()
	n.position = pos
	var script: GDScript = GDScript.new()
	script.source_code = """
extends Node2D
var r: float = 10.0
var c: Color = Color(1, 1, 1, 0.5)
var w: float = 5.0
func _draw():
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, w)
"""
	script.reload()
	n.set_script(script)
	n.set("c", color)
	n.set("w", line_width)
	add_child(n)
	var tween: Tween = create_tween()
	tween.tween_method(func(v: float) -> void:
		n.set("r", v)
		n.queue_redraw()
	, 12.0, max_radius, 0.55)
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
			show_tutorial_tip("적들이 자동으로 공격합니다.\n성의 HP를 지키세요!", castle_hp_bar, 4.5)
		1:
			if summon_btns.size() > 0:
				show_tutorial_tip("전사를 소환해 방어를 강화하세요!", summon_btns[0], 12.0)
		2:
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				show_dialogue("빠른 놈이군.", Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
			)
		4:
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				show_dialogue("...큰 놈이다.", Color(0.75, 0.85, 1.0, 1), player.global_position + Vector2(0, -60))
			)

func _show_card_guide() -> void:
	var r1: Rect2 = card_btn1.get_global_rect()
	var r2: Rect2 = card_btn2.get_global_rect()
	var r3: Rect2 = card_btn3.get_global_rect()
	show_guide("카드를 선택하세요. 영주가 강해집니다.", [
		{"rect": r1, "callback": func() -> void: _pick_card(0)},
		{"rect": r2, "callback": func() -> void: _pick_card(1)},
		{"rect": r3, "callback": func() -> void: _pick_card(2)},
	])

func _show_shop_guide() -> void:
	show_tutorial_tip("영혼으로 강화할 수 있습니다.\n닫기를 눌러 계속하세요.", shop_close_btn, 60.0)

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
	msg.size = Vector2(600, 70)
	msg.position = Vector2(212, msg_y)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(msg)

	_guide_tween = create_tween().set_loops()
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y + 8, 0.4)
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y, 0.4)

	get_tree().create_timer(duration).timeout.connect(func() -> void: _close_guide())

func show_guide(message: String, targets: Array) -> void:
	_close_guide()
	_guide_active = true
	_guide_layer = CanvasLayer.new()
	_guide_layer.layer = 80
	add_child(_guide_layer)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(1024, 700)
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
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = Color(0, 0, 0, 0)
		proxy.add_theme_stylebox_override("normal", flat)
		proxy.add_theme_stylebox_override("hover", flat)
		proxy.add_theme_stylebox_override("pressed", flat)
		proxy.add_theme_stylebox_override("focus", flat)
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
	msg.size = Vector2(700, 70)
	msg.position = Vector2(162, msg_y)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(msg)

	_guide_tween = create_tween().set_loops()
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y + 10, 0.45)
	_guide_tween.tween_property(arrow, "position:y", arrow_base_y, 0.45)

func _close_guide() -> void:
	if _guide_tween != null and _guide_tween.is_valid():
		_guide_tween.kill()
	_guide_tween = null
	if is_instance_valid(_guide_layer):
		_guide_layer.queue_free()
	_guide_layer = null
	_guide_active = false
