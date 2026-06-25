extends Node2D

const WaveData = preload("res://scripts/WaveData.gd")
const Enemy = preload("res://scripts/Enemy.gd")
const EnemyScene = preload("res://scenes/Enemy.tscn")
const BossScene = preload("res://scenes/Boss.tscn")
const SkeletonWarriorScene = preload("res://scenes/SkeletonWarrior.tscn")

# 언데드 하인
var max_minions: int = 6  # MD12: 전역 총량 캡 (종류별 캡 → 전역 캡으로 변경)
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

# Phase C — 라이브 골드 고용 3종 (폭탄병 제외)
# 인덱스는 MINION_TYPES 내 위치와 대응 (warrior=0, archer=1, tank=3)
const HIRE_TYPE_INDICES: Array = [0, 1, 3]  # warrior / archer / tank
const HIRE_START_GOLD: int = 50  # 가제 시작 골드
var summon_btns: Array = []
var _summon_name_lbls: Array = []  # 소환 버튼 자식 이름 라벨 배열
var _summon_cost_lbls: Array = []  # 소환 버튼 자식 비용 라벨 배열

# RD16 — 하인 강화 시스템
# (HIRE_CAP_PER_TYPE·_hire_alive 제거 — MD12: 전역 총량 캡(max_minions)으로 교체)
const HIRE_UPGRADE_STAT_MULT: float = 0.25 # 가제: 레벨당 HP/공격력 +25% (밸런싱 TBD)
const HIRE_UPGRADE_COST_BASE: int = 30     # 가제: 강화 기본 비용 (Lv→Lv+1 = BASE × 현재레벨)
# 종류별 글로벌 레벨 (런 스코프, 리셋은 씬 reload로)
var hire_levels: Dictionary = {"warrior": 1, "archer": 1, "tank": 1}
# 강화 팝업 노드
var _upgrade_popup: Control = null
var _upgrade_btn: Button = null
var _upg_icon: Label = null                 # 강화 버튼 내부 ▲ 아이콘 (HBox 자식, 아트 입고 전 플레이스홀더)
var _upgrade_popup_catcher: Control = null  # 팝업 바깥 탭 캐처
var _upgrade_demon: TextureRect = null            # 강화 팝업 좌상단 마왕 빼꼼(victory)
var _upgrade_demon_bubble: Panel = null           # 마왕 바크 말풍선
var _gold_hud_hidden_by_popup: bool = false  # 강화 팝업이 하단 골드 HUD를 숨겼는지

# ── 하단 UI 팔레트 (AbilitySystem.gd BORDER_READY_COLOR 계열과 통일) ──────────
const UI_BTN_BG_NORMAL:   Color = Color(0.14, 0.12, 0.20, 0.96)
const UI_BTN_BG_HOVER:    Color = Color(0.22, 0.18, 0.35, 0.98)
const UI_BTN_BG_PRESSED:  Color = Color(0.10, 0.09, 0.14, 0.92)
const UI_BTN_BG_DISABLED: Color = Color(0.10, 0.09, 0.14, 0.92)
const UI_BTN_BORDER:      Color = Color(0.50, 0.42, 0.65, 1.0)
const UI_BTN_GOLD:        Color = Color(1.0,  0.82, 0.30, 1.0)
const UI_BTN_CORNER:      int   = 8   # corner_radius (플테 조정 대상)
const UI_BTN_BORDER_W:    int   = 2   # border_width  (플테 조정 대상)
# 팝업 전용
const UI_POPUP_CORNER:    int   = 10
const UI_POPUP_BORDER_W:  int   = 2
# 코스트 알약 버튼
const UI_COST_PILL_CORNER: int  = 12  # 알약(pill) 느낌을 위해 높게
# RD19 — 자원 캡슐 알약 코너 (높이의 절반 → 양끝 완전 둥글게)
const UI_CAPSULE_CORNER:   int  = 14
# 골드 부족 힌트 — 비용 숫자 전용 빨강 (플테 조정 대상)
const UI_COST_SHORT: Color = Color(0.9, 0.3, 0.3, 1.0)

# 게임 상태
var current_chapter: int = 0
var current_stage: int = 0
var current_wave: int = 0
var castle_hp: int = 500
var castle_max_hp: int = 500
var wave_active: bool = false
var _battle_over: bool = false  # 결과/패배 화면 진입 후 = true. 하단 조작 버튼은 보이되 입력 차단.
var _tutorial_teaching_minion: int = -1  # 현재 교습 중인 마물 MINION_TYPES 인덱스(-1=없음). 소환 게이트 + 한도 예외용.
var enemies_alive: int = 0
var _pulse_armed_t2: bool = true  # 2/3 임계 펄스 무장 상태
var _pulse_armed_t1: bool = true  # 1/3 임계 펄스 무장 상태

# 펄스 스폰 스케줄러
var _spawn_schedule: Array[Dictionary] = []  # 각 {t, enemy, hp, spd, dmg}
var _wave_elapsed: float = 0.0
var _wave_spawn_y_min: float = 150.0
var _wave_spawn_y_max: float = 240.0

# 플레이어 스탯
var attack_bonus: float = 1.0
var graveyard_heal: int = 0
var ability_cooldown_mult: float = 1.0   # 마법 가속 (상점)
var ability_radius_mult: float = 1.0     # 마법 확산 (상점)
var ability_radius_card_mult: float = 1.0  # 마법 반경 (연료 카드 area+)
var ability_cooldown_card_mult: float = 1.0  # 마법 쿨다운 (키스톤 쇄도, 상점 ability_cooldown_mult와 분리)
var chain_lightning_targets: int = 0   # 연쇄 낙뢰: 공격형 마법 적중 시 추가 연쇄 대상 수
var suppress_duration: float = 0.0     # 제압: 나팔 적중 적 정지 지속(초·누적, 0.0=무효)
var vulnerability_amount: float = 0.0    # 취약: 추가 피해 비율(0.0=무효). 표식된 적 take_damage서 (1+이값) 곱
var vulnerability_duration: float = 3.0  # 취약 표식 지속(초, 가제)
var execution_threshold: float = 0.0     # 처형: HP비율 문턱(0.0=무효, 예 0.15)

# 영혼 자원
var souls: int = 0
var _souls_shown: int = 0
var _souls_roll_tween: Tween = null
var _souls_bump_tween: Tween = null
var _gold_floaters: Array = []  # 화면에 살아 있는 골드 플로터 목록 (소프트 캡 관리용)
# 언데드 하인 상태
var active_minions: int = 0

# 키스톤 (런 빌드 곱 레이어)
var power_card_count: int = 0
var army_card_count: int = 0
var magic_card_count: int = 0
var keystone1: String = ""   # "" | "legion"([마물]) | "surge"([마법] 쇄도)
var keystone2: String = ""   # "" | "horde" | "echo" | "vulnerable" | "execute"
# 파생값(_recompute_keystones에서 재계산)
var keystone_lord_atk_mult: float = 1.0
var keystone_minion_atk_mult: float = 1.0
var keystone_revive_chance: float = 0.0
var keystone_echo_dmg: float = 0.0
const KEYSTONE_ECHO_RADIUS: float = 90.0
const HORDE_REFUND_BASE: float = 0.50
const HORDE_REFUND_PER_CARD: float = 0.05
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

# 마왕 위급 바크 — 위급 진입 엣지 디텍션
var _castle_in_danger: bool = false

# 시설 보너스
var soul_gain_mult: float = 1.0

# 가이드 오버레이 (튜토리얼)
var _guide_layer: CanvasLayer = null
var _guide_active: bool = false
var _guide_tween: Tween = null
# 카드 풀 - 스킬 카드는 획득 후 제거, 스탯 카드는 계속 등장
const SKILL_CARDS = []  # 패시브 거취 미정 — §4.1 보류, 풀에서 제외
# (death_aura / skull_throw / decay_curse 상수 보존, 드래프트에는 미등장)
const STAT_CARDS = [
	{"id": "wall"},
	{"id": "graveyard"},
	{"id": "minion_count"},
	{"id": "summon_cost"},
	{"id": "minion_range"},
	{"id": "minion_lifesteal"},
	{"id": "area", "magic": true},
	{"id": "chain_lightning", "magic": true},
	{"id": "suppress", "alignment": "통제", "magic": true},
]

var available_skill_cards: Array = []
var current_cards: Array = []
const RARE_CHANCE: float = 0.3
const ALWAYS_RARE: Array[String] = ["minion_count"]
const NEVER_RARE: Array[String] = ["graveyard"]

# 카드 픽업 시각 효과: ID → 카테고리
# (보류/연기 카드: range_basic·range_all·death_aura·skull_throw·decay_curse — 풀에 없으나 엔트리 보존)
const CARD_CATEGORY_MAP = {
	"wall":          "castle",
	"graveyard":     "castle",
	"range_basic":   "range",
	"range_all":     "range",
	"minion_count":    "minion",
	"summon_cost":     "minion",
	"minion_range":    "minion",
	"minion_lifesteal": "minion",
	"death_aura":    "skill",
	"skull_throw":   "skill",
	"decay_curse":   "skill",
	"area":          "range",
	"chain_lightning": "range",
	"suppress":      "range",
}

# 카드 → 축 분류
# (보류/연기 카드: range_basic·range_all·death_aura·skull_throw·decay_curse — 풀에 없으나 엔트리 보존)
const CARD_AXIS = {
	"range_basic": "power", "range_all": "power",
	"death_aura": "power", "skull_throw": "power", "decay_curse": "power",
	"minion_count": "army", "summon_cost": "army",
	"minion_range": "army", "minion_lifesteal": "army",
	"area": "magic",
	"chain_lightning": "magic",
	"suppress": "magic",
	"wall": "neutral", "graveyard": "neutral",
}

# 연출/대사 텍스트
const WAVE_CLEAR_LINES = [
	"좋아. 계속 막는다.",
	"멈추지 마라. 다음.",
	"에헴. 이 몸이 누군지 알겠지.",
	"에헴. 이게 마왕의 실력이다.",
	"이쯤이야 마왕에겐 가뿐하지. 에헴.",
	"크흠, 어떠냐. 이게 마왕이다.",
]
const POWER_LINES = [
	"이게 마왕의 힘이다.",
	"내 성에서, 감히.",
	"전부 쓸어주마.",
	"한 발도 못 들인다.",
	"여기까지다.",
]
const DANGER_LINES = [
	"성벽! 조금만 버텨줘…!",
	"마왕은… 마왕은 안 운다.",
	"이 정도로 안 무너진다… 아마.",
	"진정해. 마왕이잖아. 마왕.",
	"아직… 아직 안 졌어.",
]
const POWER_BARK_CHANCE: float = 0.2   # 마법 발동 시 바크 확률 (스팸 방지)
const DEMON_BARK_MIN_GAP_MSEC: int = 2800   # 마왕 바크 최소 간격(ms). 위급 바크는 무시(우선권).
const CASTLE_HALF: float = 169.2       # 외벽+코너타워 외곽 (Enemy/Boss/SkeletonWarrior와 동일·성 scale 1.8). ⚠️성 크기 바꾸면 같이 수정
const CASTLE_DANGER_RATIO: float = 0.25
const CASTLE_PULSE_T2: float = 2.0/3.0          # 넉백 펄스 1단계 임계값 (2/3)
const CASTLE_PULSE_T1: float = 1.0/3.0          # 넉백 펄스 2단계 임계값 (1/3)
const CASTLE_PULSE_FORCE: float = 350.0         # 펄스 기본 넉백 세기
const CASTLE_PULSE_REARM_MARGIN: float = 0.06   # 히스테리시스 마진 (회복 시 재무장)
const BOSS_INTRO_DIALOGUES = {
	"사관후보생":          "이, 이건 훈련 아닌가요...?",
	"수습 용사 인턴":      "저, 저는 아직 수습 기간이라서요...!",
	"용사 대리":           "마물들이 다 쓰러졌군요. 제가 직접 처리하겠습니다.",
	"정의의 용사 알바생":  "의뢰받은 일은 끝내고 가겠습니다.",
	"정의의 용사 과장":    "내가 직접 나설 줄은 몰랐겠지?",
}

const SHOP_ITEMS = [
	{"id": "castle_max",      "label": "성벽 증축",  "desc": "성 최대 HP +120",   "cost": 120},
	{"id": "restore",         "label": "긴급 수복",  "desc": "성·마물 즉시 완전 회복", "cost": 70},
	{"id": "lightning_dmg",   "label": "낙뢰 증폭",  "desc": "낙뢰 피해 +20%",    "cost": 110},
	{"id": "ability_cd",      "label": "마법 가속",  "desc": "마법 쿨다운 −15%",  "cost": 130},
	{"id": "ability_radius",  "label": "마법 확산",  "desc": "마법 반경 +25%",    "cost": 90},
]
var shop_btns: Array = []
var shop_purchased: Array = []  # SH4: 상점 진입마다 리셋, 종류당 1회 구매

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
var sacrifice_button: Button = null
@onready var summon_container: HBoxContainer = $UI/SummonContainer
@onready var minion_slot_label: Label = $UI/MinionSlotLabel
@onready var minions_node = $Minions
var _summon_fx: Node2D = null  # 소환 마법진 전용 레이어(트리상 Minions 앞 = 성 위·아군 아래)
@onready var souls_label = $UI/SoulsLabel
var souls_icon: Label = null
var slot_icon: Label = null
# MD12 — 하인 카운트 readout (active_minions / max_minions 표시)
var _minion_icon: Label = null   # 하인 아이콘 플레이스홀더 (■, 하인 아트 입고 후 교체 예정)
var _minion_group: HBoxContainer = null  # 👤 아이콘 + N/M 래퍼 (흔들림 연출 단위)
var _minion_group_base_pos: Vector2 = Vector2.ZERO  # 흔들림 원복용 레이아웃 기준 위치
var _minion_readout: Label = null
var _minion_flash_tween: Tween = null  # 캡 도달 소환 시도 시 N/M 빨강 펄스
var _minion_shake_tween: Tween = null  # 캡 도달 소환 시도 시 아이콘+N/M 좌우 흔들림
var _max_badge: Label = null     # 전역 소환 캡 도달 시 캡슐 우상단 "MAX" 배지
# RD19 — 자원 readout 캡슐 (골드/하인을 알약 영역 하나로 묶음)
var _resource_capsule: Panel = null
var _resource_hbox: HBoxContainer = null
# (3) 하단 트레이 패널
var _bottom_tray: Panel = null
# (3b) 트레이 좌/우 구역 디바이더 (경영 메뉴 | 마법 구분)
var _tray_divider: ColorRect = null
@onready var shop_panel = $UI/ShopPanel
@onready var shop_title: Label = $UI/ShopPanel/ShopTitle
@onready var shop_subtitle: Label = $UI/ShopPanel/ShopSubtitle
@onready var shop_souls: Label = $UI/ShopPanel/ShopSouls
@onready var shop_items_node = $UI/ShopPanel/ShopItems
@onready var shop_close_btn = $UI/ShopPanel/CloseBtn
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var modal_dim: ColorRect = $UI/ModalDim

var _shop_btn_pulse_tween: Tween = null
var _shop_anim_tween: Tween = null  # 상점 진입/퇴장 트랜지션 핸들 (재진입 시 kill)
var _shop_closing: bool = false     # 퇴장 페이드 진행 중 중복 호출 가드
var _shop_dim_alpha: float = 0.72   # modal_dim 원래 알파 보관 (노드 실제값 사용)
var _card_rows: Array = []

# ── Phase B — 마법 시스템 ─────────────────────────────────────
const AbilitySystemScript = preload("res://scripts/AbilitySystem.gd")
var ability_system: Node = null

# ── 마왕 표정 반응 컷인 ──────────────────────────────────────
const DemonPortraitScript = preload("res://scripts/DemonPortrait.gd")
var demon_portrait: Control = null
var _last_demon_bark_msec: int = 0

func _ready() -> void:
	# 소환 마법진 FX 레이어 — 트리상 Minions 앞에 삽입(성·적보다 위, 아군보다 아래로 렌더).
	_summon_fx = Node2D.new()
	_summon_fx.name = "SummonFX"
	add_child(_summon_fx)
	move_child(_summon_fx, minions_node.get_index())
	available_skill_cards = SKILL_CARDS.duplicate()
	card_title.text = Loc.t("card_select_title")
	card_subtitle.text = Loc.t("card_select_subtitle")
	result_btn1.pressed.connect(_on_result_btn1_pressed)
	result_btn2.pressed.connect(_on_result_btn2_pressed)
	# 눌림 바운스 — 페이드 전환(0.35s) 동안 보임. btn1은 비활성 시 pressed 안 떠 성공 시에만 재생.
	_add_button_press_bounce(result_btn1)
	_add_button_press_bounce(result_btn2)
	sacrifice_button = Button.new()
	sacrifice_button.focus_mode = Control.FOCUS_NONE
	sacrifice_button.add_theme_font_size_override("font_size", 20)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	$UI.add_child(sacrifice_button)
	# 닫기 동작 통일 — 눌렸다 돌아오는 바운스를 보여준 뒤 닫음(즉시 닫으면 패널과 함께 사라져 안 보임)
	shop_close_btn.pressed.connect(func() -> void:
		if not is_instance_valid(shop_close_btn):
			return
		shop_close_btn.pivot_offset = shop_close_btn.size * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(shop_close_btn, "scale", Vector2(0.94, 0.94), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(shop_close_btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_close_shop)
	)
	_build_shop_buttons()
	_build_summon_buttons()
	_build_upgrade_ui()
	# RD19 — 자원 readout 캡슐: 골드/하인을 알약 영역 하나로 묶음. 숫자 둘 다 흰색·아이콘만 색.
	# souls_label을 캡슐 HBox로 reparent하므로, $UI 참조는 먼저 hud_parent로 캡처해 둠
	# (reparent 후 souls_label.get_parent()는 HBox가 됨 → 트레이 등은 hud_parent로 add).
	var hud_parent: Node = souls_label.get_parent()
	_resource_capsule = Panel.new()
	_resource_capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_capsule.add_theme_stylebox_override("panel", _make_capsule_stylebox())
	hud_parent.add_child(_resource_capsule)

	_resource_hbox = HBoxContainer.new()
	_resource_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_hbox.alignment = BoxContainer.ALIGNMENT_CENTER  # 캡슐 내 중앙정렬
	_resource_hbox.add_theme_constant_override("separation", 5)
	_resource_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_resource_hbox.offset_left   = 12.0   # 좌우 내부 패딩
	_resource_hbox.offset_right  = -12.0
	_resource_hbox.offset_top    = 0.0
	_resource_hbox.offset_bottom = 0.0
	_resource_capsule.add_child(_resource_hbox)

	# 하인 아이콘(👤)용 NotoEmoji (모노크롬 → 색 틴트). 골드는 ● 글리프라 불필요.
	var capsule_emoji_font: Font = load("res://assets/fonts/NotoEmoji-Regular.ttf") as Font
	# 골드: ● (노란 동그라미) + 숫자(흰색)
	souls_icon = Label.new()
	souls_icon.text = "●"
	souls_icon.add_theme_font_size_override("font_size", 16)
	souls_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	souls_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	souls_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_hbox.add_child(souls_icon)
	# souls_label(@onready, 골드 숫자) 를 캡슐 HBox로 이동 — 숫자는 흰색·16px
	souls_label.reparent(_resource_hbox)
	souls_label.add_theme_color_override("font_color", Color(0.96, 0.95, 1.0, 1.0))
	souls_label.add_theme_font_size_override("font_size", 16)
	souls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 그룹 간격 스페이서 (골드 ↔ 하인)
	var res_spacer: Control = Control.new()
	res_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	res_spacer.custom_minimum_size = Vector2(12.0, 0.0)
	_resource_hbox.add_child(res_spacer)

	# 하인: ■ (플레이스홀더 색 아이콘) + N/M(흰색)
	# MD12 — 하인 카운트 readout (■ 플레이스홀더, 하인 아트 입고 후 교체 예정)
	# 아이콘+N/M을 묶는 래퍼(흔들림 연출 단위). 외부 HBox와 분리돼 position 흔들기가 레이아웃과 안 싸움.
	_minion_group = HBoxContainer.new()
	_minion_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minion_group.add_theme_constant_override("separation", 5)  # 아이콘↔숫자 간격 (외부 HBox와 동일)
	_resource_hbox.add_child(_minion_group)
	_minion_icon = Label.new()
	_minion_icon.text = "👤"  # 사람(하인 수) — NotoEmoji 모노크롬 글리프. 하인 아트 입고 후 교체 가능
	if capsule_emoji_font != null:
		_minion_icon.add_theme_font_override("font", capsule_emoji_font)
	_minion_icon.add_theme_font_size_override("font_size", 14)
	_minion_icon.add_theme_color_override("font_color", Color(0.72, 0.68, 0.86, 1.0))
	_minion_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_minion_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minion_group.add_child(_minion_icon)
	_minion_readout = Label.new()
	_minion_readout.add_theme_font_size_override("font_size", 16)   # 골드 숫자와 동일 크기
	_minion_readout.add_theme_color_override("font_color", Color(0.96, 0.95, 1.0, 1.0))
	_minion_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_minion_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minion_group.add_child(_minion_readout)

	# slot_icon — 구 캡 라벨 아이콘(Phase C 미사용). 호환 위해 노드만 유지·숨김.
	slot_icon = Label.new()
	slot_icon.text = "●"
	slot_icon.add_theme_font_size_override("font_size", 16)
	slot_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_icon.visible = false
	minion_slot_label.get_parent().add_child(slot_icon)

	# MD12 — 전역 소환 캡 MAX 배지 (캡슐 우상단 모서리에 걸침 — 캡슐 자식이라 캡슐 숨김 시 함께 숨음)
	_max_badge = Label.new()
	_max_badge.text = Loc.t("minion_cap_max")
	_max_badge.add_theme_font_size_override("font_size", 10)
	_max_badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_max_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_max_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badge_sb: StyleBoxFlat = StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.85, 0.18, 0.18, 1.0)
	badge_sb.corner_radius_top_left     = 4
	badge_sb.corner_radius_top_right    = 4
	badge_sb.corner_radius_bottom_left  = 4
	badge_sb.corner_radius_bottom_right = 4
	badge_sb.content_margin_left  = 3.0
	badge_sb.content_margin_right = 3.0
	badge_sb.content_margin_top    = 1.0
	badge_sb.content_margin_bottom = 1.0
	_max_badge.add_theme_stylebox_override("normal", badge_sb)
	_max_badge.visible = false
	_resource_capsule.add_child(_max_badge)
	# 마물 카운트(👤 N/M)가 HBox 중앙정렬이라 숫자 자릿수에 따라 좌우로 움직임
	# → 레이아웃 갱신(sort_children)마다 배지를 카운트 바로 위 중앙으로 재배치
	_resource_hbox.sort_children.connect(_position_max_badge)
	# (3) 하단 트레이 패널 — 모든 하단 컨트롤 뒤에 깔리는 다크보라 반투명 밴드
	_bottom_tray = Panel.new()
	_bottom_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 입력 가로채지 않음
	var tray_sb: StyleBoxFlat = StyleBoxFlat.new()
	tray_sb.bg_color = Color(0.10, 0.08, 0.16, 0.55)  # 흐리게 — 버튼(α0.96) 강조 (RD19)
	tray_sb.border_color = Color(0.35, 0.28, 0.50, 0.60)
	tray_sb.set_border_width_all(1)
	tray_sb.corner_radius_top_left  = 10
	tray_sb.corner_radius_top_right = 10
	tray_sb.corner_radius_bottom_left  = 0
	tray_sb.corner_radius_bottom_right = 0
	_bottom_tray.add_theme_stylebox_override("panel", tray_sb)
	hud_parent.add_child(_bottom_tray)
	_bottom_tray.move_to_front()  # 임시 — _layout_bottom_ui_phase_c에서 move_child로 최하단으로 이동
	_tray_divider = ColorRect.new()
	_tray_divider.color = Color(0.45, 0.38, 0.62, 0.30)
	_tray_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_parent.add_child(_tray_divider)
	# Phase A4 — 하단 UI 숨김 (특수기 버튼·소환 4버튼·희생 버튼·슬롯 라벨)
	# 상단 HUD·트래커·성HP바(UI-폴리싱 자산)는 건드리지 않음
	# 복원: 아래 블록을 제거하고 _process()의 Phase A 가드도 제거
	_hide_bottom_ui_phase_a()
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
	_fade_in()
	_apply_facility_bonuses()
	if _is_tutorial():
		souls += 30
	# Phase C — 시작 골드 보장: 시설 보너스 반영 후 HIRE_START_GOLD 미만이면 채움
	if souls < HIRE_START_GOLD:
		souls = HIRE_START_GOLD
	_update_souls_ui()
	# Phase C — 고용 버튼 + 골드 HUD 표시
	# summon_container: 마법 버튼(우하단)과 겹치지 않게 _layout_bottom_ui_phase_c에서 배치
	if is_instance_valid(summon_container):
		summon_container.visible = true
	# minion_slot_label·slot_icon은 캡 없어졌으므로 숨김 유지
	_set_resource_hud_visible(true)  # 자원 캡슐(골드+하인) 표시
	_set_upgrade_btn_visible(true)
	_layout_bottom_ui_phase_c()
	_refresh_summon_buttons()
	# Phase B — 마법 시스템 초기화
	ability_system = AbilitySystemScript.new()
	add_child(ability_system)
	ability_system.setup(self)
	_update_ability_buttons_for_stage()  # 낙뢰(슬롯0)·나팔(슬롯1) 온보딩 게이팅
	# 마왕 표정 컷인 노드 생성 — HUD 레이어(ModalDim보다 트리상 앞)에 배치
	# 모달 재정렬은 위에서 이미 완료됐으므로 ModalDim 바로 앞(즉 이 시점 마지막 자식이 ModalDim)에 삽입.
	# move_child로 ModalDim 바로 앞에 끼워 레이어 순서를 보장한다.
	demon_portrait = DemonPortraitScript.new()
	$UI.add_child(demon_portrait)
	var dim_idx: int = $UI.get_children().find(modal_dim)
	if dim_idx > 0:
		$UI.move_child(demon_portrait, dim_idx)
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

	var base_hp: float = data["base_hp"]
	var base_speed: float = data["base_speed"]
	var base_damage: int = data["base_damage"]

	# HUD 하단(~y142) 바로 아래에서 스폰 — 상시 바가 적을 가리지 않도록 (카피바라고 방식)
	_wave_spawn_y_min = 150.0
	_wave_spawn_y_max = 240.0
	if _is_tutorial() and current_wave == 4:
		_wave_spawn_y_min = 220.0
		_wave_spawn_y_max = 300.0
		# 느린 브루트 → 플레이어 사거리 안쪽에서 등장하도록 살짝 아래 스폰

	# 펄스 스케줄 구축
	_spawn_schedule.clear()
	_wave_elapsed = 0.0

	# pulses 포맷 처리 (composition fallback 포함)
	if data.has("pulses"):
		enemies_alive = 0
		for pulse: Dictionary in data["pulses"]:
			var pulse_t: float = float(pulse["t"])
			for entry: Dictionary in pulse["spawn"]:
				var preset: Dictionary = Enemy.TYPE_PRESETS[entry["enemy"]]
				var e_hp: float = base_hp * preset["hp_mult"]
				var e_spd: float = base_speed * preset["speed_mult"]
				var e_dmg: int = int(base_damage * preset["damage_mult"])
				for _i: int in entry["count"]:
					_spawn_schedule.append({
						"t": pulse_t + randf_range(0.0, 0.4),
						"enemy": entry["enemy"],
						"hp": e_hp,
						"spd": e_spd,
						"dmg": e_dmg,
					})
					enemies_alive += 1
	elif data.has("composition"):
		# 레거시 fallback: composition을 전부 t=0 펄스로 취급
		enemies_alive = 0
		for entry: Dictionary in data["composition"]:
			var preset: Dictionary = Enemy.TYPE_PRESETS[entry["enemy"]]
			var e_hp: float = base_hp * preset["hp_mult"]
			var e_spd: float = base_speed * preset["speed_mult"]
			var e_dmg: int = int(base_damage * preset["damage_mult"])
			for _i: int in entry["count"]:
				_spawn_schedule.append({
					"t": randf_range(0.0, 0.4),
					"enemy": entry["enemy"],
					"hp": e_hp,
					"spd": e_spd,
					"dmg": e_dmg,
				})
				enemies_alive += 1

	_spawn_schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])

	if data["type"] == "mid_boss" or data["type"] == "boss":
		enemies_alive += 1
		var b = BossScene.instantiate()
		# 보스도 HUD 밴드 아래에서 등장 (이름표가 position.y-95까지 뻗으므로 바 하단 y142 클리어)
		b.position = Vector2(240, 250)
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
	_update_ability_buttons_for_stage()  # 웨이브별 마법 버튼 노출(낙뢰는 튜토 W3부터) — 가이드 전에 갱신
	if _is_tutorial():
		_trigger_wave_guide(current_wave)
	# FX13 — 1-2 강화 교습 비트는 start_wave가 아니라 '첫 소환 직후'에 띄운다(_on_summon_pressed).
	#         (소환도 안 한 상태에서 강화부터 가르치면 어색 — 소환 → 강화 순서)
	# FX14 — 1-3 나팔 교습 비트: 나팔 버튼 스포트라이트 (taught_horn은 첫 발동 시 AbilitySystem이 켬)
	elif current_stage == 2 and not GameSave.taught_horn and current_wave == 0:
		var horn_btn: Control = ability_system.get_field_button(1)
		if is_instance_valid(horn_btn):
			show_tutorial_tip("나팔로 적들을 밀어내세요!", horn_btn, 12.0, ability_system.get_field_button_rect(1), false)

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
	label.text = "골드 +50 (해골 만랩)"
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

func _spawn_scheduled_enemy(s: Dictionary) -> void:
	var vp_w: float = get_viewport_rect().size.x
	var e = EnemyScene.instantiate()
	e.position = Vector2(randf_range(30, vp_w - 30), randf_range(_wave_spawn_y_min, _wave_spawn_y_max))
	e.enemy_type = s["enemy"]
	e.hp = s["hp"]
	e.max_hp = s["hp"]
	e.speed = s["spd"]
	e.base_speed = s["spd"]
	e.damage = s["dmg"]
	e.game = self
	enemies_node.add_child(e)

func boss_summon(enemy_type: String, count: int) -> void:
	if not wave_active:
		return
	var data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)
	var preset: Dictionary = Enemy.TYPE_PRESETS[enemy_type]
	var e_hp: float = data["base_hp"] * preset["hp_mult"]
	var e_spd: float = data["base_speed"] * preset["speed_mult"]
	var e_dmg: int = int(data["base_damage"] * preset["damage_mult"])
	var vp_w: float = get_viewport_rect().size.x
	for i in count:
		var e = EnemyScene.instantiate()
		e.position = Vector2(randf_range(30, vp_w - 30), randf_range(150, 240))
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

## 마왕 바크 공통 게이트. force=true(위급)는 쿨다운 무시. 그 외는 DEMON_BARK_MIN_GAP_MSEC 간격 강제(연발 방지).
func _demon_say(emotion: String, text: String, force: bool = false) -> void:
	if not is_instance_valid(demon_portrait):
		return
	var now: int = Time.get_ticks_msec()
	if not force and now - _last_demon_bark_msec < DEMON_BARK_MIN_GAP_MSEC:
		return
	_last_demon_bark_msec = now
	demon_portrait.say(emotion, text)

## castle_hp 변경 후 위급 진입 엣지를 감지해 마왕 바크를 1회 발사한다.
## 모든 castle_hp 변경 지점에서 castle_bar.set_hp 옆에 함께 호출할 것.
func _update_demon_danger() -> void:
	if not is_instance_valid(demon_portrait):
		return
	var ratio: float = float(castle_hp) / float(castle_max_hp)
	var now_danger: bool = castle_hp > 0 and ratio < CASTLE_DANGER_RATIO
	if now_danger and not _castle_in_danger:
		_demon_say("hurt", DANGER_LINES[randi() % DANGER_LINES.size()], true)
	_castle_in_danger = now_danger

func castle_take_damage(dmg: int, from_pos: Vector2 = Vector2.INF, big: bool = false) -> void:
	if castle_hp <= 0:
		return
	castle_hp -= dmg
	castle_bar.set_hp(castle_hp, castle_max_hp)
	castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
	_update_demon_danger()
	_update_castle_pulse()
	# 공격자 위치를 외벽 사각형에 투영한 접촉점에 임팩트 표시(어느 쪽이 맞고 있는지 가독).
	if not is_inf(from_pos.x):
		var cc: Vector2 = $Castle.global_position
		var contact: Vector2 = Vector2(
			clamp(from_pos.x, cc.x - CASTLE_HALF, cc.x + CASTLE_HALF),
			clamp(from_pos.y, cc.y - CASTLE_HALF, cc.y + CASTLE_HALF))
		spawn_castle_hit_effect(contact, big)
	if castle_hp <= 0:
		castle_hp = 0
		castle_bar.set_hp(castle_hp, castle_max_hp)
		game_over()

## 성 HP가 1/3·2/3 임계값을 아래로 통과하는 순간 넉백 펄스를 1회 발동한다.
## 히스테리시스(+margin)로 회복 시 재무장 → 진동 연발 방지, 진짜 회복→재하락은 재발동.
func _update_castle_pulse() -> void:
	if castle_hp <= 0:
		return
	var ratio: float = float(castle_hp) / float(castle_max_hp)
	# 회복 시 재무장
	if ratio > CASTLE_PULSE_T2 + CASTLE_PULSE_REARM_MARGIN:
		_pulse_armed_t2 = true
	if ratio > CASTLE_PULSE_T1 + CASTLE_PULSE_REARM_MARGIN:
		_pulse_armed_t1 = true
	# 하향 통과 발동 — 깊은 임계값 우선, 한 번에 둘 다 지나면 강한 것만
	if ratio <= CASTLE_PULSE_T1 and _pulse_armed_t1:
		_pulse_armed_t1 = false
		_pulse_armed_t2 = false
		_fire_castle_pulse(2)
	elif ratio <= CASTLE_PULSE_T2 and _pulse_armed_t2:
		_pulse_armed_t2 = false
		_fire_castle_pulse(1)

## 성 중심에서 충격파 — 모든 적을 바깥으로 넉백(보스는 apply_knockback 면역)·링 VFX·화면 흔들림.
func _fire_castle_pulse(stage: int) -> void:
	var cc: Vector2 = $Castle.global_position
	var force: float = CASTLE_PULSE_FORCE if stage == 1 else CASTLE_PULSE_FORCE * 1.3
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.apply_knockback(cc, force)
	var radius: float = 200.0 if stage == 1 else 260.0
	_spawn_pulse_ring(cc, radius, Color(0.85, 0.55, 1.0, 0.85), 7.0)
	if stage == 1:
		_screen_shake(5.0, 0.25)
	else:
		_screen_shake(9.0, 0.4)
		hit_stop(0.05)

## 마법 발동 시 AbilitySystem이 호출하는 마왕 바크 (POWER_BARK_CHANCE 확률).
func demon_bark_power() -> void:
	if not is_instance_valid(demon_portrait):
		return
	if randf() >= POWER_BARK_CHANCE:
		return
	_demon_say("attack", POWER_LINES[randi() % POWER_LINES.size()])

func end_wave() -> void:
	if not wave_active:
		return
	wave_active = false
	_spawn_schedule.clear()
	_close_guide()

	if graveyard_heal > 0:
		castle_hp = min(castle_hp + graveyard_heal, castle_max_hp)
		castle_bar.set_hp(castle_hp, castle_max_hp)
		castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
		_update_demon_danger()

	if current_wave >= WaveData.stage_wave_count(current_chapter, current_stage) - 1:
		game_clear()
		return

	if not _is_tutorial() and randf() < 0.3:
		var line: String = WAVE_CLEAR_LINES[randi() % WAVE_CLEAR_LINES.size()]
		if is_instance_valid(demon_portrait):
			_demon_say("victory", line)

	await get_tree().create_timer(1.2).timeout
	# 카드/키스톤 루프 활성 — 운영자 모델 RD12 검증 통과(RD18, 2026-06-19) 후 게이트 플립
	# 되돌리기: `if false`→`if true`로 바꾸면 드래프트 우회·다음 웨이브 직행(구 Phase A 차단)
	if false:  # (구 Phase A 가드) 카드/키스톤 선택 차단 — 검증 통과로 해제
		current_wave += 1
		start_wave()
		return
	# 키스톤1 축 선언: 튜토리얼=W3(낙뢰 학습 완료 후), 비튜토리얼=W0 클리어 즉시
	var wtype: String = WaveData.get_wave(current_chapter, current_stage, current_wave).get("type", "normal")
	var axis_wave: int = 3 if _is_tutorial() else 0
	if current_wave == axis_wave and keystone1 == "":
		# 전용 「전투 전략」 화면
		_show_keystones(["legion", "surge"], true)
		return
	# 키스톤2 심화(중간보스 클리어 시): 비튜토리얼만 — 1-0 mid_boss는 game_clear로 빠져 여기 도달 안 함
	if not _is_tutorial():
		if wtype == "mid_boss" and keystone2 == "" and keystone1 == "legion":
			_show_keystones(["horde", "echo"])
			return
		elif wtype == "mid_boss" and keystone2 == "" and keystone1 == "surge":
			_show_keystones(["vulnerable", "execute"])
			return
	_show_cards()

func _set_modal_dim(on: bool) -> void:
	# 카드/키스톤 선택 모달 — 배경(월드·상단 HUD·성HP바·트래커)을 딤으로 덮어 선택에 집중시킨다.
	# z순서상 modal_dim은 HUD 위·모달 패널 아래라, 켜면 캐릭터 비침과 타이틀↔HUD 겹침이 함께 해소된다.
	if on:
		modal_dim.modulate.a = _shop_dim_alpha
	modal_dim.visible = on

func _show_cards() -> void:
	for n: Node in _card_rows:
		if is_instance_valid(n):
			n.queue_free()
	_card_rows.clear()

	card_title.text = Loc.t("card_select_title")
	card_subtitle.text = Loc.t("card_select_subtitle")

	var pool: Array = available_skill_cards.duplicate()
	for stat_card: Dictionary in STAT_CARDS:
		pool.append(stat_card)

	# 온보딩 카드 풀 게이팅: taught_horn 전(1-2 이전)엔 통제형 카드 제외
	var control_unlocked: bool = (current_stage >= 2) or GameSave.taught_horn
	if not control_unlocked:
		pool = pool.filter(func(c: Dictionary) -> bool: return c.get("alignment", "") != "통제")
	# 낙뢰(마법) 학습 전(1-1 W3 이전)엔 마법 카드(연쇄낙뢰·넓은 마법·제압 등) 제외
	if not _is_lightning_available():
		pool = pool.filter(func(c: Dictionary) -> bool: return not c.get("magic", false))

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

	_set_modal_dim(true)
	card_panel.visible = true

func _pick_card(index: int) -> void:
	_close_guide()
	var card: Dictionary = current_cards[index]
	if card.get("keystone", false):
		_apply_keystone(card["id"])
		card_panel.visible = false
		_set_modal_dim(false)
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
	if axis == "power":
		power_card_count += 1
	elif axis == "army":
		army_card_count += 1
		# legion 캡 스케일: [마물] 카드 획득마다 소환 슬롯 +1
		if keystone1 == "legion":
			max_minions += 1
			_update_minion_readout()
			_refresh_summon_buttons()
	elif axis == "magic":
		magic_card_count += 1
	_recompute_keystones()

	card_panel.visible = false
	_set_modal_dim(false)
	_spawn_card_pickup_effect(card["id"])
	current_wave += 1
	start_wave()

func _recompute_keystones() -> void:
	# 기본값 리셋 (보류 트랙 변수 포함 — Player/특수기/희생 시스템이 참조)
	keystone_lord_atk_mult = 1.0
	keystone_minion_atk_mult = 1.0
	keystone_revive_chance = 0.0
	keystone_echo_dmg = 0.0
	keystone_sacrifice_dmg_mult = 1.0
	keystone_sacrifice_radius_mult = 1.0
	keystone_sacrifice_refill = false
	ability_cooldown_card_mult = 1.0
	vulnerability_amount = 0.0
	execution_threshold = 0.0
	# keystone1: legion만 활성 (kingdom 제거됨)
	# keystone2: echo만 스케일 설정 (horde 환급은 minion_died에서 실시간 계산)
	#            vulnerable/execute는 여기서 파생 수치 계산
	match keystone2:
		"echo":
			keystone_echo_dmg = 20.0 * (1.0 + 0.10 * float(army_card_count))
		"vulnerable":
			vulnerability_amount = min(0.25 + 0.05 * float(magic_card_count), 0.50)
		"execute":
			execution_threshold = min(0.15 + 0.03 * float(magic_card_count), 0.25)
	# keystone1: 쇄도 = [마법] 카드 수에 비례한 쿨다운 감소 (echo처럼 파생 곱으로 재계산)
	if keystone1 == "surge":
		var reduction: float = min(0.35 + 0.05 * float(magic_card_count), 0.60)
		ability_cooldown_card_mult = 1.0 - reduction

func _apply_keystone(id: String) -> void:
	match id:
		"legion":
			keystone1 = "legion"
			max_minions += 2
			_update_minion_readout()
			_refresh_summon_buttons()
		"surge":
			keystone1 = "surge"
		"horde":
			keystone2 = "horde"
		"echo":
			keystone2 = "echo"
		"vulnerable":
			keystone2 = "vulnerable"
		"execute":
			keystone2 = "execute"
	_recompute_keystones()

## 키스톤 선택 화면.
## axis_pick=true(W1 축 선언) → 전용 「전투 전략」 2열 갈림 화면.
## axis_pick=false(중간보스 #2 심화) → 일반 카드 UI(키스톤 2장 + 필러 1장, 3개중 1택).
func _show_keystones(ids: Array, axis_pick: bool = false) -> void:
	for n: Node in _card_rows:
		if is_instance_valid(n):
			n.queue_free()
	_card_rows.clear()

	if axis_pick:
		# W1 축 선언 — 전용 2열 갈림 화면
		card_title.text = Loc.t("keystone_select_title")
		card_subtitle.text = Loc.t("keystone_select_subtitle")
		current_cards = []
		for id: String in ids:
			current_cards.append({"id": id, "rare": true, "keystone": true})
		var col_w: float = 218.0
		var gap: float = 16.0
		var card_y: float = 340.0
		var total: float = col_w * float(current_cards.size()) + gap * float(current_cards.size() - 1)
		var x0: float = (480.0 - total) * 0.5
		for i: int in current_cards.size():
			var x: float = x0 + float(i) * (col_w + gap)
			var row: Control = _build_keystone_card(current_cards[i], i, x, card_y, col_w)
			card_panel.add_child(row)
			_card_rows.append(row)
			_flash_card_glow(row)
		_set_modal_dim(true)
		card_panel.visible = true
		return

	# 중간보스 #2 — 일반 카드 UI(키스톤 2장 + 필러 스탯 1장)
	card_title.text = Loc.t("card_select_title")
	card_subtitle.text = Loc.t("card_select_subtitle")
	current_cards = []
	for id: String in ids:
		current_cards.append({"id": id, "rare": true, "keystone": true})
	var stat_pool: Array = STAT_CARDS.duplicate()
	stat_pool.shuffle()
	current_cards.append({"id": stat_pool[0]["id"], "rare": false})

	var card_h: float = 120.0
	var gap2: float = 10.0
	var start_y: float = 250.0
	for i: int in current_cards.size():
		var row: Control = _build_card_row(current_cards[i], i, start_y + float(i) * (card_h + gap2))
		card_panel.add_child(row)
		_card_rows.append(row)
		if current_cards[i].get("rare", false):
			_flash_card_glow(row)

	_set_modal_dim(true)
	card_panel.visible = true

func _card_name(id: String) -> String:
	var full: String = Loc.t("card_%s" % id)
	var nl: int = full.find("\n")
	return full.substr(0, nl) if nl >= 0 else full

func _card_desc(card: Dictionary) -> String:
	# {val} 치환은 _build_card_row에서 _format_axis_tags 이후에 수행(동적 값은 코드에서 직접 빨강 칠함 → 정규식 이중처리 방지)
	var full: String = Loc.t("card_%s" % card["id"])
	var nl: int = full.find("\n")
	return full.substr(nl + 1) if nl >= 0 else ""

## 동적 미리보기 숫자 1개를 빨강으로 감싼다. (단위 글자·화살표는 호출부에서 밖에 두어 검정 유지)
func _hl(s: String) -> String:
	return "[color=#cc2222]%s[/color]" % s

## 동적 미리보기: 반복 획득 스탯 카드의 "현재값 → 다음값" 표기(첫 픽=얻는 값만).
## rare면 증가폭 ×1.5(_pick_card mult와 일치). 단 minion_count/chain은 _apply_card가 mult 무시(+1 고정).
## 숫자는 _hl로 직접 빨강 처리(plain 정수도 강조되도록). 비대상이면 "".
func _card_value_preview(id: String, rare: bool) -> String:
	var mult: float = 1.5 if rare else 1.0
	match id:
		"minion_lifesteal":
			var cur: int = int(round(minion_lifesteal * 100.0))
			var nxt: int = int(round((minion_lifesteal + 0.20 * mult) * 100.0))
			return _hl("%d%%" % nxt) if cur == 0 else _hl("%d%%" % cur) + " → " + _hl("%d%%" % nxt)
		"minion_range":
			var cur: int = int(round(minion_range_bonus))
			var nxt: int = int(round(minion_range_bonus + 40.0 * mult))
			return _hl("+%d" % nxt) if cur == 0 else _hl("+%d" % cur) + " → " + _hl("+%d" % nxt)
		"area":
			var cur: int = int(round((ability_radius_card_mult - 1.0) * 100.0))
			var nxt: int = int(round((ability_radius_card_mult - 1.0 + 0.25 * mult) * 100.0))
			return _hl("+%d%%" % nxt) if cur == 0 else _hl("+%d%%" % cur) + " → " + _hl("+%d%%" % nxt)
		"graveyard":
			var cur: int = graveyard_heal
			var nxt: int = cur + int(20 * mult)
			return _hl("%d" % nxt) if cur == 0 else _hl("%d" % cur) + " → " + _hl("%d" % nxt)
		"chain_lightning":
			var cur: int = chain_lightning_targets
			var nxt: int = cur + 1
			return _hl("%d" % nxt) if cur == 0 else _hl("%d" % cur) + " → " + _hl("%d" % nxt)
		"summon_cost":
			# 누적 총액이 아니라 이 카드가 깎는 양(고정 증가폭)만 표기 — 항상 "5 골드 감소"(전설 7)
			return _hl("%d" % int(5 * mult))
		"minion_count":
			var cur: int = max_minions
			return _hl("%d" % cur) + " → " + _hl("%d" % (cur + 1))
		"wall":
			var cur: int = castle_max_hp
			return _hl("%d" % cur) + " → " + _hl("%d" % (cur + int(50 * mult)))
		"suppress":
			if suppress_duration >= 2.0:
				return _hl("2.0") + "초 (최대)"
			var nxt_d: float = minf(suppress_duration + 0.5, 2.0)
			var cap: String = " (최대)" if nxt_d >= 2.0 else ""
			if suppress_duration == 0.0:
				return _hl("%.1f" % nxt_d) + "초" + cap
			return _hl("%.1f" % suppress_duration) + "초 → " + _hl("%.1f" % nxt_d) + "초" + cap
	return ""

var _value_re: RegEx = null  # 카드 수치 강조용 정규식 (lazy compile)

func _format_axis_tags(s: String) -> String:
	# 수치 강조: 부호(+/-)나 % 붙은 값만 빨강. ([b] 볼드는 폰트 메트릭 차이로 baseline이 어긋나 제외 — 색만으로 강조)
	# 축 태그 치환 *전*에 적용 — 치환이 삽입하는 색 hex(#7b4fc9 등)의 숫자가 오염되지 않도록.
	if _value_re == null:
		_value_re = RegEx.new()
		_value_re.compile("([+\\-]?\\d+(?:\\.\\d+)?%|[+\\-]\\d+(?:\\.\\d+)?)")
	s = _value_re.sub(s, "[color=#cc2222]$1[/color]", true)
	s = s.replace("[마법]", "[color=#7b4fc9][lb]마법[rb][/color]")
	s = s.replace("[마물]", "[color=#0a7d6b][lb]마물[rb][/color]")
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

	var desc: String = _card_desc(card)
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
		var formatted: String = _format_axis_tags(desc)
		if formatted.find("{val}") >= 0:
			formatted = formatted.replace("{val}", _card_value_preview(card["id"], card.get("rare", false)))
		desc_lbl.text = formatted
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

func _build_keystone_card(card: Dictionary, index: int, x_pos: float, y_pos: float, col_w: float) -> Control:
	var id: String = card["id"]
	var axis: String = "magic" if id in ["surge", "vulnerable", "execute"] else "army"
	var axis_label: String = "마법" if axis == "magic" else "마물"
	var axis_col: Color = Color("#7b4fc9") if axis == "magic" else Color("#0a7d6b")

	var parts: PackedStringArray = Loc.t("card_%s" % id).split("\n")
	var card_name: String = parts[0] if parts.size() > 0 else id
	# Loc는 \n을 name/effect/synergy 필드 구분자로 쓰므로, 필드 내부 수동 줄바꿈은 '|' 마커 → 여기서 \n으로 치환
	var card_effect: String = (parts[1] if parts.size() > 1 else "").replace("|", "\n")
	var card_synergy: String = (parts[2] if parts.size() > 2 else "").replace("|", "\n")

	var card_h: float = 324.0

	var root: Control = Control.new()
	root.position = Vector2(x_pos, y_pos)
	root.size = Vector2(col_w, card_h)

	# 배경 패널 — 축 색 틴트
	var bg: Panel = Panel.new()
	bg.size = Vector2(col_w, card_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = axis_col.lerp(Color.WHITE, 0.86)
	bg_style.set_border_width_all(3)
	bg_style.border_color = axis_col
	bg_style.set_corner_radius_all(10)
	bg.add_theme_stylebox_override("panel", bg_style)
	root.add_child(bg)

	# 축 배지 (pill)
	var pill_w: float = 74.0
	var pill_h: float = 28.0
	var pill_x: float = (col_w - pill_w) * 0.5
	var pill_y: float = -pill_h * 0.5  # 카드 상단 테두리에 탭처럼 반쯤 걸침
	var pill_bg: Panel = Panel.new()
	pill_bg.position = Vector2(pill_x, pill_y)
	pill_bg.size = Vector2(pill_w, pill_h)
	pill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = axis_col
	pill_style.set_corner_radius_all(13)
	pill_bg.add_theme_stylebox_override("panel", pill_style)
	root.add_child(pill_bg)

	var pill_lbl: Label = Label.new()
	pill_lbl.text = axis_label
	pill_lbl.position = Vector2(pill_x, pill_y)
	pill_lbl.size = Vector2(pill_w, pill_h)
	pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_lbl.add_theme_font_size_override("font_size", 15)
	pill_lbl.add_theme_color_override("font_color", Color.WHITE)
	pill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill_lbl)

	# 이름 라벨 (위)
	var name_lbl: Label = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(0.0, 22.0)
	name_lbl.size = Vector2(col_w, 32.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.13, 0.08, 0.05))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# 아이콘 네모박스 (중간) — 일반 카드 art 박스와 동일 규격(96×96), 테두리만 축 색. 임시 플레이스홀더(아트 입고 시 교체)
	var icon_sz: float = 96.0
	var icon_box: Panel = Panel.new()
	icon_box.position = Vector2((col_w - icon_sz) * 0.5, 60.0)
	icon_box.size = Vector2(icon_sz, icon_sz)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.18, 0.11, 0.04, 1.0)
	icon_style.set_border_width_all(3)
	icon_style.border_color = axis_col
	icon_style.set_corner_radius_all(6)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	root.add_child(icon_box)

	# 핵심효과 라벨 (아이콘 아래) — 수치 강조(빨강) 위해 RichText
	# AUTOWRAP_WORD(공백 단위)로 한국어 단어 중간 분리 방지 — "감소" 등이 통째로 다음 줄로
	var effect_lbl: RichTextLabel = RichTextLabel.new()
	effect_lbl.bbcode_enabled = true
	effect_lbl.fit_content = true
	effect_lbl.scroll_active = false
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	effect_lbl.position = Vector2(8.0, 166.0)
	effect_lbl.size = Vector2(col_w - 16.0, 44.0)
	effect_lbl.add_theme_font_size_override("normal_font_size", 18)
	effect_lbl.add_theme_color_override("default_color", Color(0.15, 0.12, 0.10))
	effect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_lbl.text = "[center]%s[/center]" % _format_axis_tags(card_effect)
	root.add_child(effect_lbl)

	# 시너지 RichTextLabel (아래)
	if card_synergy != "":
		# "성장" 섹션 헤더 — 효과(즉시)와 시너지(성장) 구분
		var grow_lbl: Label = Label.new()
		grow_lbl.text = "성장"
		grow_lbl.position = Vector2(0.0, 238.0)
		grow_lbl.size = Vector2(col_w, 18.0)
		grow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grow_lbl.add_theme_font_size_override("font_size", 12)
		grow_lbl.add_theme_color_override("font_color", axis_col)
		grow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(grow_lbl)

		var synergy_col: Color = Color(0.40, 0.37, 0.35)
		var syn_lbl: RichTextLabel = RichTextLabel.new()
		syn_lbl.bbcode_enabled = true
		syn_lbl.fit_content = true
		syn_lbl.scroll_active = false
		syn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		syn_lbl.position = Vector2(16.0, 264.0)
		syn_lbl.size = Vector2(col_w - 32.0, 50.0)
		syn_lbl.add_theme_font_size_override("normal_font_size", 14)
		syn_lbl.add_theme_color_override("default_color", synergy_col)
		syn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		syn_lbl.text = "[center]%s[/center]" % _format_axis_tags(card_synergy)
		root.add_child(syn_lbl)
		# 시너지 1줄/2줄 줄 수가 달라도 좌우 카드가 균형 잡히도록 영역 중심에 수직 정렬.
		_vcenter_richtext.call_deferred(syn_lbl, 286.0)

	# 투명 버튼 (탭 입력 수신)
	var btn: Button = Button.new()
	btn.size = Vector2(col_w, card_h)
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

func _vcenter_richtext(lbl: RichTextLabel, center_y: float) -> void:
	# RichTextLabel은 수직 정렬 속성이 없어, 렌더된 콘텐츠 높이를 측정해 지정 중심에 맞춘다.
	if is_instance_valid(lbl):
		lbl.position.y = center_y - lbl.get_content_height() * 0.5

func _flash_card_glow(row: Control) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(row, "modulate", Color(1.6, 1.35, 0.5, 1), 0.12)
	tween.tween_property(row, "modulate", Color(1.0, 1.0, 1.0, 1), 0.35)

## C. 상점 구매 성공 시 버튼에 짧은 골드 플래시 (_flash_card_glow 톤 참고)
func _flash_shop_buy(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var tween: Tween = create_tween()
	tween.tween_property(btn, "modulate", Color(1.6, 1.4, 0.7, 1.0), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _apply_card(id: String, mult: float = 1.0) -> void:
	# Phase A2 — 패시브 3종(death_aura/skull_throw/decay_curse) 대입 무력화
	# Player._physics_process가 이미 early-return으로 막혀 있으나 상태 변수도 설정 안 함
	# 복원: 아래 Phase A 가드 블록을 제거하면 됨
	const _PHASE_A_PASSIVE_IDS: Array = ["death_aura", "skull_throw", "decay_curse"]
	if _PHASE_A_PASSIVE_IDS.has(id):
		return  # Phase A: 패시브 카드 효과 비활성
	match id:
		"death_aura":
			player.has_death_aura = true
		"skull_throw":
			player.has_skull_throw = true
		"decay_curse":
			player.has_decay_curse = true
		"wall":
			var hp_gain: int = int(50 * mult)
			castle_max_hp += hp_gain
			castle_hp += hp_gain
			castle_bar.set_hp(castle_hp, castle_max_hp)
			castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
			_update_demon_danger()
		"graveyard":
			graveyard_heal += int(20 * mult)
		"minion_count":
			max_minions += 1
			_update_minion_readout()
		"summon_cost":
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
		"minion_range":
			minion_range_bonus += 40.0 * mult
		"minion_lifesteal":
			minion_lifesteal += 0.20 * mult
		"area":
			ability_radius_card_mult += 0.25 * mult
		"chain_lightning":
			chain_lightning_targets += 1
		"suppress":
			suppress_duration = minf(suppress_duration + 0.5, 2.0)

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
		# 눌림 바운스는 _buy_item 성공 경로에서만(불가 시 disabled라 pressed 자체가 안 뜸 + 골드 가드)
		btn.pressed.connect(func(): _buy_item(idx, btn))
		shop_items_node.add_child(btn)
		shop_btns.append(btn)

func _show_shop() -> void:
	# 퇴장 페이드 중 재진입 시 가드 해제 + 기존 트윈 정리
	_shop_closing = false
	if _shop_anim_tween and _shop_anim_tween.is_valid():
		_shop_anim_tween.kill()
	_shop_anim_tween = null

	# SH4: 상점 진입마다 구매 상태 리셋 (웨이브당 1회 상점 → 진입 시 초기화)
	shop_purchased.resize(SHOP_ITEMS.size())
	shop_purchased.fill(false)
	_refresh_shop_buttons()
	if is_instance_valid(ability_system):
		ability_system.cancel_for_shop()  # 무장 중이었다면 해제 (reach 원/무장 UI 잔상 제거)
	# RD16: 상점 중 강화 버튼+팝업 숨김. 팝업이 골드 HUD를 숨겼다면 먼저 복원시킨 뒤
	# 아래에서 상점용으로 다시 끄도록, _close를 HUD 숨김 앞에서 호출.
	_close_upgrade_popup()
	# Phase C: 상점(모달) 표시 중 고용 버튼 숨김 (_close_shop에서 복원)
	summon_container.visible = false
	minion_slot_label.visible = false
	_set_resource_hud_visible(false)  # 자원 캡슐 숨김
	_set_upgrade_btn_visible(false)
	shop_title.text = Loc.t("shop_title")
	shop_subtitle.text = Loc.t("shop_subtitle")

	# ── A. 진입 트랜지션 ────────────────────────────────────────────────────
	# modal_dim: 원래 알파 보관 후 0 → 원래값 페이드인
	_shop_dim_alpha = modal_dim.modulate.a  # 노드 실제값 사용(하드코딩 금지)
	modal_dim.modulate.a = 0.0
	modal_dim.visible = true

	# shop_panel: 중앙 피벗 → scale·alpha 초기화 후 visible, 탄력 팝인
	shop_panel.pivot_offset = shop_panel.size * 0.5
	shop_panel.scale = Vector2(0.92, 0.92)
	shop_panel.modulate.a = 0.0
	shop_panel.visible = true

	_shop_anim_tween = create_tween().set_parallel(true)
	_shop_anim_tween.tween_property(modal_dim, "modulate:a", _shop_dim_alpha, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shop_anim_tween.tween_property(shop_panel, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shop_anim_tween.tween_property(shop_panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _is_tutorial():
		_show_shop_guide()

func _close_shop() -> void:
	# 중복 호출 가드 (페이드 진행 중 재호출 방지)
	if _shop_closing:
		return
	_shop_closing = true

	# 기존 트윈 정리
	if _shop_anim_tween and _shop_anim_tween.is_valid():
		_shop_anim_tween.kill()
	_shop_anim_tween = null

	# 즉시 실행: 가이드·튜토리얼 상점 가이드 복원
	_close_guide()
	if _shop_btn_pulse_tween and _shop_btn_pulse_tween.is_valid():
		_shop_btn_pulse_tween.kill()
	_shop_btn_pulse_tween = null
	shop_close_btn.modulate = Color.WHITE
	shop_title.text = Loc.t("shop_title")

	# ── B. 퇴장 트랜지션 ────────────────────────────────────────────────────
	# modal_dim + shop_panel 알파 → 0, 패널 scale 살짝 축소(~0.14s, 빠르게)
	_shop_anim_tween = create_tween().set_parallel(true)
	_shop_anim_tween.tween_property(modal_dim, "modulate:a", 0.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shop_anim_tween.tween_property(shop_panel, "modulate:a", 0.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shop_anim_tween.tween_property(shop_panel, "scale", Vector2(0.96, 0.96), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 페이드 완료 후: 숨김 + HUD 복원 + 웨이브 진행
	_shop_anim_tween.chain().tween_callback(func() -> void:
		shop_panel.visible = false
		modal_dim.visible = false
		modal_dim.modulate.a = _shop_dim_alpha  # 다음 모달(결과창 등)을 위해 알파 복원
		shop_panel.scale = Vector2.ONE          # 다음 진입을 위해 scale 복원
		_shop_closing = false
		# Phase C: 상점 닫힌 후 고용 버튼 + 자원 캡슐 복원 (minion_slot_label은 캡 없어 숨김 유지)
		if is_instance_valid(summon_container):
			summon_container.visible = true
		_set_resource_hud_visible(true)  # 자원 캡슐 복원 (MAX 배지 동기화 포함)
		# 마법 버튼 복원 (상점 진입 시 cancel_for_shop으로 숨김)
		if is_instance_valid(ability_system):
			ability_system.restore_after_shop()
		# RD16: 상점 닫힌 후 강화 버튼 + 아이콘 복원
		_set_upgrade_btn_visible(true)
		current_wave += 1
		start_wave()
	)

func _buy_item(index: int, btn: Button = null) -> void:
	# SH4: 이미 구매한 항목은 무시
	if index < shop_purchased.size() and shop_purchased[index]:
		return
	var item: Dictionary = SHOP_ITEMS[index]
	if souls < item["cost"]:
		return
	_play_button_bounce(btn)   # 구매 성공 시에만 눌림 피드백
	_flash_shop_buy(btn)       # 구매 성공 골드 플래시
	souls -= item["cost"]
	_update_souls_ui()
	_apply_shop_item(item["id"])
	# SH4: 구매 완료 마킹
	if index < shop_purchased.size():
		shop_purchased[index] = true
	_refresh_shop_buttons()

func _apply_shop_item(id: String) -> void:
	match id:
		"castle_max":
			castle_max_hp += 120
			castle_hp += 120
			castle_bar.set_hp(castle_hp, castle_max_hp)
			castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
			_update_demon_danger()
		"restore":
			castle_hp = castle_max_hp
			castle_bar.set_hp(castle_hp, castle_max_hp)
			castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
			_update_demon_danger()
			for m in minions_node.get_children():
				if is_instance_valid(m):
					m.hp = m.max_hp
		"lightning_dmg":
			attack_bonus *= 1.20
		"ability_cd":
			ability_cooldown_mult *= 0.85
		"ability_radius":
			ability_radius_mult *= 1.25

func _refresh_shop_buttons() -> void:
	for i in SHOP_ITEMS.size():
		var item: Dictionary = SHOP_ITEMS[i]
		var btn: Button = shop_btns[i]
		var purchased: bool = i < shop_purchased.size() and shop_purchased[i]
		if purchased:
			btn.text = "%s  %s" % [item["label"], Loc.t("shop_purchased")]
			btn.disabled = true
		else:
			btn.text = "%s  [골드 %d]\n%s" % [item["label"], item["cost"], item["desc"]]
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
	_battle_over = true  # 하단 조작 UI는 그대로 두되 입력만 차단 (숨기면 어색)
	_spawn_schedule.clear()
	_close_guide()
	card_panel.visible = false
	shop_panel.visible = false

	# 적·하인 처리 정지
	for e in enemies_node.get_children():
		if is_instance_valid(e):
			e.set_physics_process(false)
			e.set_process(false)
	for m in minions_node.get_children():
		if is_instance_valid(m):
			m.set_physics_process(false)
			m.set_process(false)

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
	_battle_over = true  # 하단 조작 UI는 그대로 두되 입력만 차단 (숨기면 어색)
	_close_guide()
	card_panel.visible = false

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
	# 버튼 동작 통일 — hover/pressed 색 변화 없음(normal 재사용), 눌림은 바운스(페이드 동안 보임)
	result_btn1.add_theme_stylebox_override("hover", b1n)
	result_btn1.add_theme_stylebox_override("pressed", b1n)
	result_btn1.add_theme_stylebox_override("focus", b1n)
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
	var b1_font: Color = Color(1.0, 0.92, 0.65, 1.0) if btn1_enabled else Color(0.50, 0.47, 0.38, 1.0)
	result_btn1.add_theme_color_override("font_color",         b1_font)
	result_btn1.add_theme_color_override("font_hover_color",   b1_font)  # hover 시 글자색 변화 차단
	result_btn1.add_theme_color_override("font_pressed_color", b1_font)
	result_btn1.add_theme_color_override("font_focus_color",   b1_font)
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
	# 버튼 동작 통일 — hover/pressed 색 변화 없음(normal 재사용)
	result_btn2.add_theme_stylebox_override("hover", b2n)
	result_btn2.add_theme_stylebox_override("pressed", b2n)
	result_btn2.add_theme_stylebox_override("focus", b2n)
	var b2_font: Color = Color(0.82, 0.80, 0.90, 1.0)
	result_btn2.add_theme_color_override("font_color",         b2_font)
	result_btn2.add_theme_color_override("font_hover_color",   b2_font)
	result_btn2.add_theme_color_override("font_pressed_color", b2_font)
	result_btn2.add_theme_color_override("font_focus_color",   b2_font)

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
	# 펄스 스폰 드레인 — 웨이브 진행 중에만 동작
	if wave_active and not _spawn_schedule.is_empty():
		_wave_elapsed += delta
		while not _spawn_schedule.is_empty() and _spawn_schedule[0]["t"] <= _wave_elapsed:
			_spawn_scheduled_enemy(_spawn_schedule.pop_front())
	# Phase B — 마법 시스템 쿨다운 + UI 갱신 (Phase A 가드보다 앞에 위치)
	if is_instance_valid(ability_system):
		ability_system.tick(delta)
	# Phase A4/A5 — 희생·특수기 UI 갱신 비활성 (버튼 숨김 유지)
	# Phase C — 고용 버튼은 매 프레임 갱신 (골드·웨이브 상태 반영)
	_refresh_summon_buttons()
	# 아래는 Phase A 가드로 비활성 유지 (복원 시 제거)
	if true:  # Phase A 가드: 희생 쿨 갱신 비활성
		return
	if sacrifice_cooldown > 0.0:
		sacrifice_cooldown = max(0.0, sacrifice_cooldown - delta)
	_update_sacrifice_button()

## Phase B — 필드 탭 감지 (2스텝 발현)
## GUI 버튼(마법 버튼, 취소 버튼 등) 탭은 _unhandled_input에 도달하지 않으므로 안전
func _unhandled_input(event: InputEvent) -> void:
	var tap_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false
	if event is InputEventScreenTouch and event.is_pressed():
		tap_pos = event.position
		is_tap = true
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
		is_tap = true
	if is_tap:
		# 팝업 바깥 탭 닫기는 _upgrade_popup_catcher(MOUSE_FILTER_STOP)가 처리.
		# 팝업이 열린 상태에서 이 함수까지 도달하는 탭은 팝업/버튼 위이므로 그냥 통과.
		if is_instance_valid(ability_system):
			ability_system.on_field_tap(tap_pos)

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
	castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
	_update_demon_danger()

	var graveyard_bonus: int = [0, 15, 30, 50][fl.get("graveyard", 0)]
	graveyard_heal += graveyard_bonus

	var arsenal_mult: float = [1.0, 1.1, 1.22, 1.37][fl.get("arsenal", 0)]
	attack_bonus *= arsenal_mult

	soul_gain_mult = [1.0, 1.2, 1.4, 1.6][fl.get("banquet", 0)]

func add_souls(n: int) -> void:
	var gained: int = int(n * soul_gain_mult)
	souls += gained
	_update_souls_ui()
	if gained > 0:
		_spawn_gold_floater(gained)
	_try_show_enhance_tip()  # 골드가 강화비용 이상 차오르면 1-2 강화 교습 팁

## RD19 — 자원 캡슐(골드+하인) 가시성 토글 (단일 지점 관리)
## 캡슐 자식(souls_icon/souls_label/_minion_icon/_minion_readout/_max_badge)이 함께 표시/숨김됨.
func _set_resource_hud_visible(v: bool) -> void:
	if is_instance_valid(_resource_capsule):
		_resource_capsule.visible = v
	if v:
		_update_minion_readout()  # MAX 배지 상태 동기화
	elif is_instance_valid(_max_badge):
		_max_badge.visible = false

## MD12 — 하인 카운트 readout 갱신 (고용/사망/max_minions 변동 시 호출)
func _update_minion_readout() -> void:
	if not is_instance_valid(_minion_readout):
		return
	_minion_readout.text = Loc.t("minion_readout") % [active_minions, max_minions]
	var at_cap: bool = active_minions >= max_minions
	if is_instance_valid(_max_badge):
		# 캡슐이 보일 때만 배지 표시 (캡슐 숨김 시엔 자식이라 자동 숨김이지만 .visible도 맞춰 둠)
		var cap_vis: bool = is_instance_valid(_resource_capsule) and _resource_capsule.visible
		_max_badge.visible = at_cap and cap_vis

## MAX 배지를 마물 카운트(👤 N/M)의 최대 수(우측 숫자) 우측 상단 모서리에 배치.
## HBox 중앙정렬이라 숫자 자릿수에 따라 우측 끝 x가 바뀌므로 sort_children마다 재호출됨.
func _position_max_badge() -> void:
	if not (is_instance_valid(_max_badge) and is_instance_valid(_resource_capsule)):
		return
	if not is_instance_valid(_minion_readout):
		return
	const BADGE_W: float = 30.0
	const BADGE_H: float = 14.0
	_max_badge.size = Vector2(BADGE_W, BADGE_H)
	# N/M 우단(최대 수 오른쪽 끝)을 캡슐 로컬 좌표로 환산 → 그 위 우측에 살짝 걸치게
	var right_edge: float = _minion_readout.global_position.x + _minion_readout.size.x - _resource_capsule.global_position.x
	_max_badge.position = Vector2(right_edge - BADGE_W * 0.45, -BADGE_H * 0.7)
	# 흔들림 원복 기준 — sort 직후엔 그룹이 레이아웃 제자리에 있으므로 여기서 권위 있는 값 캡처
	if is_instance_valid(_minion_group) and not (_minion_shake_tween and _minion_shake_tween.is_valid()):
		_minion_group_base_pos = _minion_group.position

## 캡 도달 상태에서 소환 시도 → 마물 카운트(N/M)를 빨강으로 1회 펄스 + 좌우 흔들림으로 거부 피드백.
## 연타하면 매번 재시작되어 깜빡임/떨림처럼 보임.
func _flash_minion_cap() -> void:
	if not is_instance_valid(_minion_readout):
		return
	if _minion_flash_tween and _minion_flash_tween.is_valid():
		_minion_flash_tween.kill()
	const NORMAL: Color = Color(0.96, 0.95, 1.0, 1.0)  # 평소 흰보라 (생성 시와 동일)
	const FLASH: Color = Color(1.0, 0.28, 0.28, 1.0)   # MAX 배지와 같은 계열 빨강
	_set_minion_readout_color(FLASH)
	_minion_flash_tween = create_tween()
	_minion_flash_tween.tween_method(_set_minion_readout_color, FLASH, NORMAL, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake_minion_group()

func _set_minion_readout_color(c: Color) -> void:
	if is_instance_valid(_minion_readout):
		_minion_readout.add_theme_color_override("font_color", c)

## 아이콘+N/M 그룹을 좌우로 짧게 흔듦 (감쇠). HBox 레이아웃 제자리(_minion_group_base_pos) 기준 오프셋.
func _shake_minion_group() -> void:
	if not is_instance_valid(_minion_group):
		return
	if _minion_shake_tween and _minion_shake_tween.is_valid():
		_minion_shake_tween.kill()
	var base: Vector2 = _minion_group_base_pos
	_minion_group.position = base
	_minion_shake_tween = create_tween()
	# 레퍼런스 측정: native ±1px 미세 잔떨림(~30ms/스윙, ~150ms). 480 논리폭 최소 렌더치인 ±1px로.
	for off: float in [1.0, -1.0, 1.0, -1.0, 0.5, 0.0]:  # 빠른 ±1px 버즈 (감쇠)
		_minion_shake_tween.tween_property(_minion_group, "position", base + Vector2(off, 0.0), 0.03)

func _update_souls_ui() -> void:
	if _souls_roll_tween and _souls_roll_tween.is_valid():
		_souls_roll_tween.kill()
	if _souls_shown == souls:
		souls_label.text = "%d" % souls  # 캡슐에 ● 아이콘 별도 → 숫자만
	else:
		_souls_roll_tween = create_tween()
		_souls_roll_tween.tween_method(_set_souls_display, _souls_shown, souls, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bump_souls_label()
	# RD16 — 골드 변동 시 팝업 버튼 활성 상태 갱신
	_refresh_upgrade_popup()

func _set_souls_display(v: float) -> void:
	_souls_shown = int(round(v))
	souls_label.text = "%d" % _souls_shown

func _bump_souls_label() -> void:
	if _souls_bump_tween and _souls_bump_tween.is_valid():
		_souls_bump_tween.kill()
	souls_label.pivot_offset = Vector2(0.0, souls_label.size.y * 0.5)
	souls_label.scale = Vector2.ONE
	_souls_bump_tween = create_tween()
	_souls_bump_tween.tween_property(souls_label, "scale", Vector2(1.15, 1.15), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_souls_bump_tween.tween_property(souls_label, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 골드 획득 플로팅 텍스트 생성 — add_souls 단일 퍼널에서만 호출
const FLOATER_RISE:      float = 28.0   # 위로 상승 거리(px) (플테 조정 대상)
const FLOATER_DURATION:  float = 0.55   # 총 애니메이션 시간(s)
const FLOATER_POP_DUR:   float = 0.08   # 초기 scale 팝 시간(s)
const FLOATER_FONT_SIZE: int   = 15     # 폰트 크기 (플테 조정 대상)
const FLOATER_OUTLINE:   int   = 3      # 검은 외곽선 두께 (플테 조정 대상)
const FLOATER_SOFT_CAP:  int   = 8      # 동시 최대 플로터 수 (초과 시 가장 오래된 것 정리)
# horde 환급 월드 코인 연출 상수 (플테 조정 대상)
const COIN_RADIUS:       float = 5.0    # 코인 원 반지름(px) (플테 조정 대상)
const COIN_RISE:         float = 22.0   # 위로 아치 상승 거리(px) (플테 조정 대상)
const COIN_DURATION:     float = 0.50   # 총 연출 시간(s) (플테 조정 대상)
const COIN_POP_DUR:      float = 0.10   # 초기 scale 팝 시간(s) (플테 조정 대상)

func _spawn_gold_floater(amount: int) -> void:
	if not is_instance_valid(souls_icon):
		return
	# 강화 팝업이 열려 있으면 플로터 생략 (골드는 정상 적립, 팝업 위 어색함 방지)
	if is_instance_valid(_upgrade_popup) and _upgrade_popup.visible:
		return
	# 소프트 캡: 가장 오래된 플로터부터 즉시 정리
	while _gold_floaters.size() >= FLOATER_SOFT_CAP:
		var oldest: Label = _gold_floaters.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var lbl: Label = Label.new()
	lbl.text = Loc.t("gold_floater") % amount
	lbl.add_theme_font_size_override("font_size", FLOATER_FONT_SIZE)
	lbl.add_theme_color_override("font_color", UI_BTN_GOLD)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", FLOATER_OUTLINE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 10  # HUD 다른 컨트롤 위에 그려지도록
	# RD19 — souls_icon은 이제 캡슐 HBox 자식이므로, 플로터는 캡슐의 부모($UI CanvasLayer)에 추가.
	# (HBox에 직접 add하면 행 아이템으로 레이아웃되어 readout이 밀림)
	var parent: Node = _resource_capsule.get_parent() if is_instance_valid(_resource_capsule) else souls_icon.get_parent()
	parent.add_child(lbl)
	_gold_floaters.append(lbl)
	# 시작 위치: souls_icon 바로 위. CanvasLayer 직속이라 position == global_position.
	lbl.size = Vector2(60.0, 20.0)
	lbl.pivot_offset = lbl.size * 0.5
	var start_pos: Vector2 = souls_icon.global_position + Vector2(0.0, -lbl.size.y + 6.0)
	lbl.position = start_pos
	lbl.scale = Vector2(0.7, 0.7)
	lbl.modulate.a = 1.0
	# 트윈: scale 팝 → 위로 상승 + 페이드아웃 병렬
	var tw: Tween = create_tween()
	# 1) scale 팝: 0.7 → 1.0 빠르게
	tw.tween_property(lbl, "scale", Vector2.ONE, FLOATER_POP_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) 상승 + 페이드 병렬 (팝 직후부터)
	tw.parallel().tween_property(lbl, "position", start_pos + Vector2(0.0, -FLOATER_RISE), FLOATER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, FLOATER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_gold_floaters.erase(lbl)
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

## RD19 — 자원 캡슐(알약) StyleBox 생성 (HUD 캡슐·팝업 골드 캡슐 공용)
func _make_capsule_stylebox() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.11, 0.92)   # 트레이/패널보다 진한 반투명
	sb.border_color = Color(0.40, 0.33, 0.55, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(UI_CAPSULE_CORNER)
	return sb

## RD19 — 버튼 눌림 피드백: 탭 시 살짝 줄었다 커지는 스케일 바운스 (중심 기준)
## 항상 바운스하는 버튼용(강화 토글 등). 불가 상태에서 안 눌려야 하는 버튼은
## _add_button_press_bounce를 붙이지 말고, 핸들러의 성공 경로에서 _play_button_bounce를 직접 호출.
func _play_button_bounce(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5  # 중심에서 스케일 (컨테이너 자식이라 탭 시점에 산정)
	var tw: Tween = create_tween()
	tw.tween_property(btn, "scale", Vector2(0.90, 0.90), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _add_button_press_bounce(btn: Button) -> void:
	btn.pressed.connect(func() -> void: _play_button_bounce(btn))

## 팔레트 헬퍼 — 단색 배경 + 보라 테두리 StyleBoxFlat 생성
func _make_button_stylebox(bg: Color, border: Color, corner: int = UI_BTN_CORNER, border_w: int = UI_BTN_BORDER_W) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	return sb

## 버튼에 normal/hover/pressed/disabled StyleBox 세트 일괄 적용
func _apply_button_styleboxes(btn: Button, normal_bg: Color = UI_BTN_BG_NORMAL,
		hover_bg: Color = UI_BTN_BG_HOVER, pressed_bg: Color = UI_BTN_BG_PRESSED,
		disabled_bg: Color = UI_BTN_BG_DISABLED,
		border: Color = UI_BTN_BORDER,
		corner: int = UI_BTN_CORNER, border_w: int = UI_BTN_BORDER_W) -> void:
	# RD19 — hover/pressed 색 변경 제거: 모두 normal 색 사용 (눌림 피드백은 스케일 바운스가 담당).
	# disabled만 별도 색 유지(튜토리얼 잠금 등). hover_bg/pressed_bg 인자는 호환 위해 남김(미사용).
	var normal_box: StyleBoxFlat = _make_button_stylebox(normal_bg, border, corner, border_w)
	btn.add_theme_stylebox_override("normal",   normal_box)
	btn.add_theme_stylebox_override("hover",    normal_box)
	btn.add_theme_stylebox_override("pressed",  normal_box)
	btn.add_theme_stylebox_override("disabled", _make_button_stylebox(disabled_bg, border, corner, border_w))
	btn.add_theme_stylebox_override("focus",    normal_box)

func _build_summon_buttons() -> void:
	# Phase C — 3종만 생성 (HIRE_TYPE_INDICES: warrior/archer/tank, 폭탄병 제외)
	# summon_btns[j] 는 HIRE_TYPE_INDICES[j] 번째 MINION_TYPES 항목에 대응
	for j in HIRE_TYPE_INDICES.size():
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# 버튼 자체 텍스트는 비움 — 자식 Label 2개가 내용을 담당
		btn.text = ""
		# font_color override 불필요(텍스트 없음), 기존 add_theme_color_override 제거
		_apply_button_styleboxes(btn)
		# 눌림 바운스는 _on_summon_pressed 성공 경로에서만 재생(골드 부족·슬롯 꽉참 시 안 눌림)
		var type_idx: int = HIRE_TYPE_INDICES[j]
		btn.pressed.connect(func(): _on_summon_pressed(type_idx, btn))
		summon_container.add_child(btn)
		summon_btns.append(btn)

		# 콘텐츠 = [이름] / [● 비용] 세로 스택 (VBox 중앙정렬 → 겹침 없이 안정적 간격)
		var content: VBoxContainer = VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 3)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(content)

		# 이름 라벨
		var name_lbl: Label = Label.new()
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		content.add_child(name_lbl)
		_summon_name_lbls.append(name_lbl)

		# 비용 행: [● 노랑][숫자] — ●만 노란색이도록 아이콘/숫자 분리 (단일 라벨은 줄 전체 한 색)
		var cost_box: HBoxContainer = HBoxContainer.new()
		cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_box.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_box.add_theme_constant_override("separation", 3)
		content.add_child(cost_box)
		var cost_icon: Label = Label.new()
		cost_icon.text = "●"  # 노란 동그라미 (항상 골드색)
		cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_icon.add_theme_font_size_override("font_size", 13)
		cost_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
		cost_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_box.add_child(cost_icon)
		var cost_lbl: Label = Label.new()
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_box.add_child(cost_lbl)
		_summon_cost_lbls.append(cost_lbl)

## RD16 — 강화 버튼 + 팝업(캐처 포함) 빌드 (운빨존많겜 레퍼런스 + 다크 보라 팔레트)
func _build_upgrade_ui() -> void:
	var parent: Node = summon_container.get_parent()

	# ── 강화 버튼 ──────────────────────────────────────────────
	# 버튼 텍스트는 비우고, 안에 [▲ 강화] HBox를 풀-렉트 중앙정렬로 배치.
	# (▲만 초록·텍스트는 보라흰 → 단일 라벨로 색 분리 불가하므로 자식 2개. 소환 버튼 자식라벨 패턴과 동일)
	_upgrade_btn = Button.new()
	_upgrade_btn.focus_mode = Control.FOCUS_NONE
	_upgrade_btn.text = ""
	_apply_button_styleboxes(_upgrade_btn)
	_add_button_press_bounce(_upgrade_btn)
	_upgrade_btn.pressed.connect(_toggle_upgrade_popup)
	parent.add_child(_upgrade_btn)

	var upg_hbox: HBoxContainer = HBoxContainer.new()
	upg_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 버튼 탭 입력 통과
	upg_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	upg_hbox.add_theme_constant_override("separation", 5)
	upg_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_btn.add_child(upg_hbox)

	# ▲ 아이콘 (초록)
	_upg_icon = Label.new()
	_upg_icon.text = Loc.t("upgrade_icon")
	_upg_icon.add_theme_font_size_override("font_size", 14)
	_upg_icon.add_theme_color_override("font_color", Color(0.4, 0.85, 0.35, 1.0))
	_upg_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upg_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upg_hbox.add_child(_upg_icon)

	# "강화" 텍스트 (보라흰)
	var upg_text: Label = Label.new()
	upg_text.text = Loc.t("upgrade_btn_label")
	upg_text.add_theme_font_size_override("font_size", 15)
	upg_text.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
	upg_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upg_hbox.add_child(upg_text)

	# ── 팝업 캐처 — 팝업보다 먼저 add_child(뒤에 깔림) ─────────
	_upgrade_popup_catcher = Control.new()
	_upgrade_popup_catcher.name = "UpgradePopupCatcher"
	_upgrade_popup_catcher.anchor_right = 1.0
	_upgrade_popup_catcher.anchor_bottom = 1.0
	_upgrade_popup_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_popup_catcher.visible = false
	# 딤 배경 없음 — 팝업 중에도 전투 상황이 그대로 보이도록. 투명 캐처는 rect로 바깥 탭만 잡음.
	_upgrade_popup_catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.is_pressed() and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_upgrade_popup()
	)
	parent.add_child(_upgrade_popup_catcher)

	# ── 팝업 패널 ──────────────────────────────────────────────
	_upgrade_popup = PanelContainer.new()
	_upgrade_popup.name = "UpgradePopup"
	_upgrade_popup.visible = false
	_upgrade_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	# 팝업 StyleBox
	var popup_sb: StyleBoxFlat = StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.93, 0.88, 0.75, 1.0)  # 양피지 크림 — 어두운 트레이와 확실히 구분(별도 팝업 인지)
	popup_sb.border_color = Color(0.42, 0.30, 0.18, 1.0)  # 따뜻한 갈색 테두리(양피지 프레임)
	popup_sb.set_border_width_all(UI_POPUP_BORDER_W)
	popup_sb.set_corner_radius_all(UI_POPUP_CORNER)
	popup_sb.content_margin_left   = 12.0
	popup_sb.content_margin_right  = 12.0
	popup_sb.content_margin_top    = 10.0
	popup_sb.content_margin_bottom = 10.0
	_upgrade_popup.add_theme_stylebox_override("panel", popup_sb)
	parent.add_child(_upgrade_popup)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER  # 커진 팝업 안에서 콘텐츠 세로 중앙
	_upgrade_popup.add_child(vbox)

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
	var gold_cap_sb: StyleBoxFlat = _make_capsule_stylebox()
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
		var pill_normal: StyleBoxFlat = _make_button_stylebox(Color(0.24, 0.20, 0.34, 1.0), UI_BTN_GOLD, UI_COST_PILL_CORNER, 1)
		var pill_dis:    StyleBoxFlat = _make_button_stylebox(Color(0.18, 0.15, 0.24, 1.0), Color(0.40, 0.35, 0.20, 0.60), UI_COST_PILL_CORNER, 1)
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
	_upgrade_demon = TextureRect.new()
	_upgrade_demon.texture = dl_tex
	# expand_mode=IGNORE_SIZE: 기본값(KEEP_SIZE)은 최소크기를 텍스처 원본(900×900)으로 고정 → size 무시됨.
	# IGNORE_SIZE로 dl_w/dl_h(140) 박스에 맞춰 축소.
	_upgrade_demon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_upgrade_demon.custom_minimum_size = Vector2(dl_w, dl_h)
	_upgrade_demon.size = Vector2(dl_w, dl_h)
	_upgrade_demon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # 종횡비 유지, 박스 중앙
	_upgrade_demon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_demon.visible = false
	parent.add_child(_upgrade_demon)

	_upgrade_demon_bubble = Panel.new()
	var bub_sb: StyleBoxFlat = StyleBoxFlat.new()
	bub_sb.bg_color = Color(0.97, 0.93, 0.82, 1.0)        # 밝은 크림 말풍선
	bub_sb.border_color = Color(0.42, 0.30, 0.18, 1.0)
	bub_sb.set_border_width_all(2)
	bub_sb.set_corner_radius_all(8)
	_upgrade_demon_bubble.add_theme_stylebox_override("panel", bub_sb)
	_upgrade_demon_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_demon_bubble.visible = false
	parent.add_child(_upgrade_demon_bubble)
	var bub_lbl: Label = Label.new()
	bub_lbl.text = Loc.t("upgrade_demon_bark")
	bub_lbl.add_theme_font_size_override("font_size", 12)
	bub_lbl.add_theme_color_override("font_color", Color(0.30, 0.22, 0.14, 1.0))
	bub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bub_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_demon_bubble.add_child(bub_lbl)

	_refresh_upgrade_popup()

## 강화 버튼 가시성 토글 (▲ 아이콘은 버튼 내부 자식 → 자동 연동)
func _set_upgrade_btn_visible(v: bool) -> void:
	if is_instance_valid(_upgrade_btn):
		_upgrade_btn.visible = v

func _toggle_upgrade_popup() -> void:
	if _battle_over:
		return  # 결과 화면: 강화 버튼 보이되 눌러도 무반응
	if not is_instance_valid(_upgrade_popup):
		return
	if _upgrade_popup.visible:
		_close_upgrade_popup()
	else:
		_open_upgrade_popup()

func _open_upgrade_popup() -> void:
	if not is_instance_valid(_upgrade_popup):
		return
	# 강화 튜토리얼 팁 닫기 — 팝업이 열리면 강화 버튼이 숨겨져 스포트라이트가 어긋나므로,
	# 플레이어가 지시를 따라 팝업을 연 시점에 팁을 정리한다.
	_close_guide()
	_refresh_upgrade_popup()
	# 캐처 먼저 표시 (팝업이 위에 그려짐)
	# move_to_front으로 마법 버튼 등 다른 UI 형제 위로 올림 (캐처→팝업 순서로 팝업이 최상단)
	if is_instance_valid(_upgrade_popup_catcher):
		_upgrade_popup_catcher.visible = true
		_upgrade_popup_catcher.move_to_front()
	_upgrade_popup.visible = true
	_upgrade_popup.move_to_front()
	# 팝업 헤더에 골드를 표시하므로 하단 자원 캡슐은 숨김 (팝업 좌측에 ● 아이콘 노출 방지)
	if is_instance_valid(_resource_capsule) and _resource_capsule.visible:
		_gold_hud_hidden_by_popup = true
		_set_resource_hud_visible(false)
	var vp: Vector2 = get_viewport_rect().size
	const POPUP_SIDE: float    = 24.0   # 좌우 마진 — 뒤 트레이(x4~476)가 양옆 살짝 보이게(레퍼런스 여백)
	const POPUP_BOTTOM: float   = 8.0   # 화면 바닥에서 띄울 여백 — 라운드 모서리 노출로 "별도로 떠오른 시트" 인지
	const POPUP_TOP_MIN: float = 700.0  # 안전 상한 — 더 위로는 안 올라가 성/전투 보호
	var content_h: float = _upgrade_popup.get_combined_minimum_size().y
	if content_h < 120.0:
		content_h = 178.0  # 폴백 (min 미산정 시)
	# 바닥을 화면 하단에 앵커 → 콘텐츠 높이만큼 위로 자람(높이 부족 오버플로우·강화버튼 가림 방지).
	# 트레이(y753~960) 위에 떠서 도크 버튼을 덮고, 플레이 영역(<753)은 가리지 않음.
	var bottom_y: float = vp.y - POPUP_BOTTOM
	var top_y: float = max(POPUP_TOP_MIN, bottom_y - content_h)
	_upgrade_popup.position = Vector2(POPUP_SIDE, top_y)
	_upgrade_popup.size = Vector2(vp.x - POPUP_SIDE * 2.0, bottom_y - top_y)
	# 마왕 장식 — 팝업 좌상단 위로 빼꼼, 바크 말풍선
	if is_instance_valid(_upgrade_demon):
		# 좌상단에서 팝업 위로 빼꼼 — 캐릭터가 팝업 위에 서듯이 (노브: y오프셋 94)
		_upgrade_demon.position = Vector2(POPUP_SIDE - 6.0, top_y - 94.0)
		_upgrade_demon.visible = true
		_upgrade_demon.move_to_front()
	if is_instance_valid(_upgrade_demon_bubble):
		var bub_w: float = 84.0
		var bub_h: float = 26.0
		_upgrade_demon_bubble.size = Vector2(bub_w, bub_h)
		# 마왕 머리 위 중앙에 작게 (노브: y의 +18은 머리끝 맞춤 보정)
		_upgrade_demon_bubble.position = Vector2(
			_upgrade_demon.position.x + (_upgrade_demon.size.x - bub_w) * 0.5,
			_upgrade_demon.position.y + 18.0 - bub_h)
		_upgrade_demon_bubble.visible = true
		_upgrade_demon_bubble.move_to_front()

func _close_upgrade_popup() -> void:
	if is_instance_valid(_upgrade_popup):
		_upgrade_popup.visible = false
	if is_instance_valid(_upgrade_popup_catcher):
		_upgrade_popup_catcher.visible = false
	if is_instance_valid(_upgrade_demon):
		_upgrade_demon.visible = false
	if is_instance_valid(_upgrade_demon_bubble):
		_upgrade_demon_bubble.visible = false
	# 팝업이 숨겼던 하단 자원 캡슐 복원 (상점 진입 등 다른 곳에서 끈 경우는 건드리지 않음)
	if _gold_hud_hidden_by_popup:
		_gold_hud_hidden_by_popup = false
		_set_resource_hud_visible(true)  # MAX 배지 동기화 포함

func _refresh_upgrade_popup() -> void:
	if not is_instance_valid(_upgrade_popup):
		return
	# 헤더 현재 골드 표시
	var gold_hdr: Label = _upgrade_popup.find_child("PopupGoldLabel", true, false)
	if is_instance_valid(gold_hdr):
		gold_hdr.text = "%d" % souls  # ● 아이콘은 캡슐 내 별도 라벨
	# 카드별 갱신
	for type_id in ["warrior", "archer", "tank"]:
		var lv: int = hire_levels.get(type_id, 1)
		var cost: int = HIRE_UPGRADE_COST_BASE * lv
		var lv_lbl: Label = _upgrade_popup.find_child("LvLabel_" + type_id, true, false)
		if is_instance_valid(lv_lbl):
			lv_lbl.text = Loc.t("upgrade_card_lv") % lv
		var upg_btn: Button = _upgrade_popup.find_child("UpgBtn_" + type_id, true, false)
		if is_instance_valid(upg_btn):
			# 항상 활성 — 누름 가드는 _on_upgrade_pressed 의 "if souls < cost: return" 이 처리
			upg_btn.disabled = false
		# 비용 숫자 라벨 갱신 (●은 항상 노란색, 숫자만 색 변동)
		var upg_num: Label = _upgrade_popup.find_child("UpgCost_" + type_id, true, false)
		if is_instance_valid(upg_num):
			upg_num.text = "%d" % cost
			var can_afford: bool = souls >= cost
			if can_afford:
				upg_num.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
			else:
				upg_num.add_theme_color_override("font_color", UI_COST_SHORT)

func _on_upgrade_pressed(type_id: String, btn: Button = null) -> void:
	if not type_id in hire_levels:
		return
	var lv: int = hire_levels[type_id]
	var cost: int = HIRE_UPGRADE_COST_BASE * lv
	if souls < cost:
		return  # 골드 부족 — 눌림 바운스도 재생 안 됨
	# 게이트 통과 — 성공 시에만 눌림 피드백
	_play_button_bounce(btn)
	souls -= cost
	_update_souls_ui()
	hire_levels[type_id] = lv + 1
	# 현재 살아있는 그 종 유닛 전부 스탯 즉시 갱신
	_apply_upgrade_to_alive_minions(type_id, lv + 1)
	_refresh_upgrade_popup()

func _apply_upgrade_to_alive_minions(type_id: String, new_lv: int) -> void:
	# 강화 시 현재 살아있는 그 종 유닛 level↑ + 스탯 재계산
	var new_scale: float = 1.0 + HIRE_UPGRADE_STAT_MULT * (new_lv - 1)
	for m in minions_node.get_children():
		if not is_instance_valid(m):
			continue
		if m.get("minion_type") != type_id:
			continue
		m.level = new_lv
		# base_damage/base_max_hp는 프리셋 × 카드보너스 기준으로 재계산
		var preset: Dictionary = m.TYPE_PRESETS.get(type_id, {})
		if preset.is_empty():
			continue
		var base_dmg: float = preset["damage"] * minion_attack_bonus * keystone_minion_atk_mult
		var base_hp: float = preset["hp"] * minion_hp_bonus
		m.base_damage = base_dmg * new_scale
		m.attack_damage = m.base_damage
		m.base_max_hp = base_hp * new_scale
		var old_ratio: float = m.hp / m.max_hp if m.max_hp > 0.0 else 1.0
		m.max_hp = m.base_max_hp
		m.hp = m.max_hp * old_ratio

func _hide_bottom_ui_phase_a() -> void:
	# Phase A4 — 하단 전투 UI 전체 숨김
	# sacrifice_button(희생), summon_container(소환 4버튼),
	# minion_slot_label(슬롯 카운터), 아이콘 라벨들 숨김
	# 복원: 이 함수 호출을 _ready()에서 제거하면 됨
	if is_instance_valid(sacrifice_button):
		sacrifice_button.visible = false
	if is_instance_valid(summon_container):
		summon_container.visible = false
	if is_instance_valid(minion_slot_label):
		minion_slot_label.visible = false
	if is_instance_valid(slot_icon):
		slot_icon.visible = false
	# RD19 — 자원 캡슐 초기 숨김 (Phase C _ready 진입 시 다시 표시됨)
	_set_resource_hud_visible(false)

func _layout_bottom_ui_phase_c() -> void:
	# Phase C — 하단 UI 배치 (아래→위: 강화 / 소환 / 골드+하인 readout HUD)
	# 마법 버튼은 AbilitySystem이 우하단(x≈280~460)에 배치 → 겹침 없음.
	# 고용/강화 버튼은 화면 좌측(x14~270)에만 위치.
	#
	# 좌표 역산 (바닥 기준):
	#   DOCK_LIFT = 42  ← 도크 전체를 바닥에서 띄우는 양
	#   BOTTOM_MARGIN = 58 (= 16 + 42)
	#   강화 버튼 (h=36): y = 960-58-36 = 866  ← 맨 아래 행
	#   GAP_UPG_SUM = 6
	#   소환 컨테이너 (h=52): y = 866-6-52 = 808 (← 마법 버튼 윗변과 일치)
	#   GAP_SUM_GOLD = 6
	#   골드+하인 HUD (h=28): y = 808-6-28 = 774
	#
	# 트레이: y753 ~ 960 (하단까지 꽉 채움, 버튼만 42px 상향)
	var vp: Vector2 = get_viewport_rect().size
	const MX: float         = 14.0   # 좌측 마진 (트레이 패딩 고려해 10→14)
	const SUM_W: float      = 262.0  # 소환/강화 버튼 폭 (좌측 절반 이하)
	const DOCK_LIFT: float   = 42.0   # 도크 전체를 바닥에서 띄우는 양 (소환 윗변=마법 윗변 y808 정렬 + 하단 터치 여백 확보)
	const BOTTOM_MARGIN: float = 16.0 + DOCK_LIFT   # 도크 띄움 반영 (16 → 58)
	const UPGRADE_H:     float = 36.0
	const GAP_UPG_SUM:   float = 6.0
	const SUM_H:         float = 52.0
	const GAP_SUM_GOLD:  float = 6.0
	const GOLD_H:        float = 22.0
	const TRAY_TOP:      float = 795.0 - DOCK_LIFT  # 795 → 753, 도크 띄움 반영 (성 1.8배·y570 → 바닥 739, 트레이와 ~14px 이격)
	const TRAY_SIDE_MG:  float = 4.0    # 트레이 좌우 마진

	# ── 트레이 패널 배치 (최하단 z — move_child로 0번째로) ───────────
	if is_instance_valid(_bottom_tray):
		_bottom_tray.position = Vector2(TRAY_SIDE_MG, TRAY_TOP)
		_bottom_tray.size = Vector2(vp.x - TRAY_SIDE_MG * 2.0, vp.y - TRAY_TOP)
		# 트레이를 부모의 맨 앞 자식(index 0 방향)으로 내려 다른 컨트롤 뒤에 깔리게
		var tray_parent: Node = _bottom_tray.get_parent()
		if is_instance_valid(tray_parent):
			tray_parent.move_child(_bottom_tray, 0)

	# ── 좌/우 구역 디바이더 (경영 메뉴 | 마법) ──────────────────────
	# 좌측 버튼 끝(x=MX+SUM_W=276)과 마법 버튼 시작(x≈296) 사이 경계
	if is_instance_valid(_tray_divider):
		const DIV_X: float = 282.0   # 좌측 버튼 끝(276)과 6px 이격, 마법 버튼과의 간격 확보 위해 좌측 미세 이동
		const DIV_INSET: float = 12.0   # 트레이 상/하단에서 띄울 여백
		_tray_divider.position = Vector2(DIV_X, TRAY_TOP + DIV_INSET)
		_tray_divider.size = Vector2(1.0, (vp.y - TRAY_TOP) - DIV_INSET * 2.0)

	# ── 강화 버튼 — 맨 아래 행 ─────────────────────────────────────
	var upg_y: float = vp.y - BOTTOM_MARGIN - UPGRADE_H   # = 866
	if is_instance_valid(_upgrade_btn):
		_upgrade_btn.position = Vector2(MX, upg_y)
		_upgrade_btn.size = Vector2(SUM_W, UPGRADE_H)
	# ▲ 아이콘은 이제 버튼 내부 HBox 자식 → 별도 위치 계산 불필요 (RD18 폴리싱)

	# ── 소환 컨테이너 ───────────────────────────────────────────────
	var sum_y: float = upg_y - GAP_UPG_SUM - SUM_H          # = 808
	summon_container.position = Vector2(MX, sum_y)
	summon_container.size = Vector2(SUM_W, SUM_H)

	# ── 자원 캡슐 (골드 + 하인 readout) — RD19 ──────────────────────
	# 캡슐 폭 = 소환/강화 버튼 폭(SUM_W)에 맞춤. 내부 [● 골드 / ■ N/M]은 HBox가 중앙정렬.
	var cap_h: float = GOLD_H + 6.0         # readout 행보다 약간 키워 알약 패딩 확보
	var gold_y: float = sum_y - GAP_SUM_GOLD - cap_h
	if is_instance_valid(_resource_capsule):
		_resource_capsule.position = Vector2(MX, gold_y)
		_resource_capsule.size = Vector2(SUM_W, cap_h)
	# MAX 배지: 마물 카운트(👤 N/M) 바로 위 중앙에 배치 (실제 위치는 _position_max_badge)
	_position_max_badge()

	# 팝업 캐처는 전체화면 앵커이므로 별도 배치 불필요

## 튜토리얼 마물 점진 해금: W0=전사(j0), W1=+궁수(j1), W2=+탱크(j2). 비튜토리얼은 전부 해금.
func _is_summon_unlocked(display_j: int) -> bool:
	if not _is_tutorial():
		return true
	return display_j <= current_wave

## 1-2(st1)에서 마물을 한 번이라도 소환했는지 (강화 교습 선행 조건)
var _st1_summoned: bool = false

## 1-2 강화 교습 팁: 소환 경험 + 강화 가능(골드 충분) + 전투 중일 때 1회.
## 소환 시 + 골드 증가 시(add_souls) 호출 → 둘 중 조건 충족되는 시점에 뜬다.
func _try_show_enhance_tip() -> void:
	if GameSave.taught_enhance:
		return
	if current_stage != 1 or not _st1_summoned:
		return
	if souls < HIRE_UPGRADE_COST_BASE:
		return
	if not (wave_active and is_instance_valid(_upgrade_btn)):
		return
	GameSave.taught_enhance = true
	GameSave.save_data()
	show_tutorial_tip("마물을 강화해 더 강하게 만드세요!", _upgrade_btn, 12.0)

## 낙뢰(마법) 가용 여부: 튜토리얼 1-1은 W3(낙뢰 학습)부터, 그 외엔 항상.
## 버튼 노출과 마법 카드 게이팅이 같은 기준을 쓰도록 단일 지점.
func _is_lightning_available() -> bool:
	return (not _is_tutorial()) or current_wave >= 3

## 온보딩 마법 버튼 노출: 낙뢰=슬롯0, 나팔=슬롯1.
## 1-1 튜토리얼은 W3(낙뢰 학습)부터 낙뢰 노출 — 그 전(W0~W2)엔 순수 마물 운영에 집중.
func _update_ability_buttons_for_stage() -> void:
	if not is_instance_valid(ability_system):
		return
	# 숨김이 아니라 '잠금표시'(마물 잠금과 통일·영역이 휑하지 않게). 잠긴 버튼은 흐린 아이콘+자물쇠.
	ability_system.set_slot_locked(0, not _is_lightning_available())
	var horn_on: bool = (current_stage >= 2) or GameSave.taught_horn
	ability_system.set_slot_locked(1, not horn_on)

func _refresh_summon_buttons() -> void:
	# Phase C — minion_slot_label·slot_icon 숨김 유지 (캡 없어짐)
	# RD19 — 자원 캡슐 가시성은 _set_resource_hud_visible 단일 지점이 관리하므로
	#        여기서 개별 노드 visibility 동기화 불필요 (캡슐 자식이 함께 표시/숨김됨).

	# C4: 특수(상점) 웨이브 판정
	var wave_is_combat: bool = true
	if current_wave < WaveData.stage_wave_count(current_chapter, current_stage):
		var wdata: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)
		if wdata.get("type", "normal") == "shop":
			wave_is_combat = false

	# summon_btns[j] → HIRE_TYPE_INDICES[j]
	for j in HIRE_TYPE_INDICES.size():
		var type_idx: int = HIRE_TYPE_INDICES[j]
		var entry: Dictionary = MINION_TYPES[type_idx]
		var cost: int = max(5, entry["cost"] - minion_cost_reduction)
		var btn: Button = summon_btns[j]
		var name_lbl: Label = _summon_name_lbls[j]
		var cost_lbl: Label = _summon_cost_lbls[j]
		if not _is_summon_unlocked(j):
			# 튜토리얼 잠금 — 전사(j=0)만 처음부터 사용 가능, 궁수·탱크는 잠금
			# 이름 라벨에 잠금 표시, 비용 행(●+숫자) 숨김
			name_lbl.text = "🔒 %s" % [entry["label"]]
			name_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.65, 0.85))
			cost_lbl.get_parent().visible = false  # cost_box(아이콘+숫자) 숨김
			btn.disabled = true
		else:
			var gold_short: bool = souls < cost
			var is_blocked: bool = (not wave_active) or (not wave_is_combat)
			# 비전투/비활성 웨이브만 비활성 — 골드 부족은 비활성 안 함(상시 활성)
			# 누름 가드는 _on_summon_pressed 의 골드/캡 체크가 처리
			btn.disabled = is_blocked
			# 이름 라벨
			name_lbl.text = entry["label"]
			name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
			# 비용 행(●+숫자) — ●은 항상 노란색, 숫자만 색 변동
			cost_lbl.get_parent().visible = true
			cost_lbl.text = "%d" % cost
			# 골드 부족 → 숫자 빨강, 아니면 평소 밝은 색
			# is_blocked 상태에서는 빨강 표시 안 함(골드 부족 전용)
			if gold_short and not is_blocked:
				cost_lbl.add_theme_color_override("font_color", UI_COST_SHORT)
			else:
				cost_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))

func _on_summon_pressed(index: int, btn: Button = null) -> void:
	# Phase C — 고용 가능 조건: wave_active + 비특수(비상점) 웨이브 + 골드만 게이팅
	# MD12: 전역 총량 캡(active_minions >= max_minions) 으로 교체
	# 차단 사유(웨이브/골드/슬롯)면 여기서 early-return → 눌림 바운스도 재생 안 됨.
	if not wave_active:
		return
	var wave_data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)
	if wave_data.get("type", "normal") == "shop":
		return
	var disp_j: int = HIRE_TYPE_INDICES.find(index)
	if _is_tutorial() and (disp_j == -1 or not _is_summon_unlocked(disp_j)):
		return  # 튜토리얼: 해금된 마물만 소환 가능 (W0=전사, W1+=궁수, W2+=탱크)
	var entry: Dictionary = MINION_TYPES[index]
	var cost: int = max(5, entry["cost"] - minion_cost_reduction)
	if souls < cost:
		return
	# MD12 — 전역 총량 캡 초과 시 거부 (N/M 빨강 펄스로 피드백 — 누를 때마다 깜빡)
	if active_minions >= max_minions:
		# 튜토리얼 한도 예외: 교습 중인 종류면 '이번에만' 한도 +1 (한도 인지시키며 교습 완성)
		if _is_tutorial() and index == _tutorial_teaching_minion:
			max_minions += 1
			_update_minion_readout()
			_demon_say("victory", "한도가 찼군… 이번에만 한 자리 내주마.", true)
		else:
			_flash_minion_cap()
			return
	# 모든 게이트 통과 — 성공 시에만 눌림 피드백
	_play_button_bounce(btn)
	souls -= cost
	_update_souls_ui()
	# 교습 중인 종류를 소환하면 그 가이드 팁을 닫고 교습 완료 (다른 종류 소환은 팁 유지=게이트)
	if index == _tutorial_teaching_minion:
		_tutorial_teaching_minion = -1
		_close_guide()
	_spawn_minion(entry["id"])

	# FX13 — 1-2 강화 교습: 소환을 해봤다는 사실만 기록. 실제 팁은 골드가 강화비용 이상으로
	# 차오르는 순간(_try_show_enhance_tip, 보통 킬 보상 add_souls 경유)에 띄운다.
	# (소환 직후 souls 체크는 골드를 다 써버려 거의 안 떠서 폐기 — 소환→강화 순서는 플래그로 보장)
	if current_stage == 1:
		_st1_summoned = true
		_try_show_enhance_tip()

func _spawn_minion(type_id: String) -> void:
	var m = SkeletonWarriorScene.instantiate()
	m.game = self
	m.minion_type = type_id
	m.position = m.get_spawn_position()  # 역할별 정착선 살짝 아래에서 스폰 (B안)
	minions_node.add_child(m)
	# 카드 보너스 반영 (프리셋 적용 후)
	m.base_damage *= minion_attack_bonus * keystone_minion_atk_mult
	m.attack_damage = m.base_damage
	m.move_speed *= minion_move_speed_bonus
	m.max_hp *= minion_hp_bonus
	m.base_max_hp *= minion_hp_bonus
	m.hp = m.max_hp
	m.attack_range += minion_range_bonus
	m.lifesteal = minion_lifesteal
	# RD16 — 종류별 글로벌 레벨 스탯 스케일 적용
	if type_id in hire_levels:
		var lv: int = hire_levels[type_id]
		m.level = lv
		var scale_mult: float = 1.0 + HIRE_UPGRADE_STAT_MULT * (lv - 1)
		m.base_damage *= scale_mult
		m.attack_damage = m.base_damage
		m.base_max_hp *= scale_mult
		m.max_hp = m.base_max_hp
		m.hp = m.max_hp
	active_minions += 1  # MD12: 전역 총량 추적 (_hire_alive 종류별 추적 제거)
	_update_minion_readout()
	_refresh_summon_buttons()
	spawn_summon_effect(m.position)

func minion_died(pos = null, type_id: String = "") -> void:
	active_minions = max(0, active_minions - 1)
	# hire_levels는 유지 — 레벨은 죽어도 안 날아감 (_hire_alive 종류별 추적 제거됨 — MD12)
	_update_minion_readout()
	_refresh_summon_buttons()
	# 영원한 군세(horde): 전사 시 소환 비용 50%+[마물]카드당 5% 골드 환급
	if keystone2 == "horde" and type_id != "":
		var base_cost: int = 0
		for entry: Dictionary in MINION_TYPES:
			if entry["id"] == type_id:
				base_cost = entry["cost"]
				break
		if base_cost > 0:
			var paid_cost: int = max(5, base_cost - minion_cost_reduction)
			var refund_rate: float = min(HORDE_REFUND_BASE + HORDE_REFUND_PER_CARD * float(army_card_count), 1.0)
			var refund: int = int(round(float(paid_cost) * refund_rate))
			souls += refund
			_update_souls_ui()
			if refund > 0:
				_spawn_gold_floater(refund)
				if pos != null:
					_spawn_refund_coin(pos)
	if pos == null:
		return
	# 죽음의 메아리: 사망 폭발
	if keystone_echo_dmg > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.position.distance_to(pos) <= KEYSTONE_ECHO_RADIUS:
				e.take_damage(keystone_echo_dmg)
		_spawn_echo_effect(pos)
	# Phase C — 영구사망: 자동 재소환/리필 분기 없음 (재고용은 유저가 버튼으로)

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

## horde 환급 월드 코인 연출 — 하인 사망 위치에서 금색 원이 위로 튀어오르며 페이드
func _spawn_refund_coin(pos: Vector2) -> void:
	var n: Node2D = Node2D.new()
	n.position = pos
	n.z_index = 10  # 액터 레이어 위에 그려지도록
	add_child(n)
	# 금색 정원 (Polygon2D)
	var seg: int = 16
	var fill: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in seg:
		var a: float = (TAU / seg) * i
		pts.append(Vector2(cos(a) * COIN_RADIUS, sin(a) * COIN_RADIUS))
	fill.polygon = pts
	fill.color = UI_BTN_GOLD
	n.add_child(fill)
	# 연출: scale 팝(0.6→1.0) 후 위로 아치 상승 + 페이드아웃 병렬
	n.scale = Vector2(0.6, 0.6)
	var tw: Tween = create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, COIN_POP_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position", pos + Vector2(0.0, -COIN_RISE), COIN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "modulate:a", 0.0, COIN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)

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

func spawn_castle_hit_effect(pos: Vector2, big: bool = false) -> void:
	# 임팩트 플래시 — 마름모 한 점. big=보스 타격(크게·길게·사방 스파크로 가독성↑, 큰 몸에 안 묻히게)
	var sz: float = 30.0 if big else 16.0
	var dur: float = 0.34 if big else 0.22
	var flash: ColorRect = ColorRect.new()
	flash.size = Vector2(sz, sz)
	flash.position = pos - Vector2(sz * 0.5, sz * 0.5)
	flash.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	flash.rotation = 0.7853982  # 45°
	flash.color = Color(1.0, 0.92, 0.55, 0.95)
	flash.z_index = 60  # 액터(보스 몸) 위로 — 가림 방지
	add_child(flash)
	var ftw: Tween = create_tween()
	ftw.parallel().tween_property(flash, "scale", Vector2(0.3, 0.3), dur)
	ftw.parallel().tween_property(flash, "modulate:a", 0.0, dur)
	ftw.tween_callback(flash.queue_free)
	if not big:
		return
	# 보스 임팩트: 사방으로 튀는 스파크 몇 점
	for i in 7:
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(7, 7)
		spark.position = pos - Vector2(3.5, 3.5)
		spark.color = Color(1.0, 0.85, 0.45, 1.0)
		spark.z_index = 60
		add_child(spark)
		var ang: float = TAU * float(i) / 7.0
		var dst: float = 34.0 + float(i % 3) * 10.0
		var tgt: Vector2 = pos + Vector2(cos(ang), sin(ang)) * dst - Vector2(3.5, 3.5)
		var stw: Tween = create_tween()
		stw.parallel().tween_property(spark, "position", tgt, dur)
		stw.parallel().tween_property(spark, "modulate:a", 0.0, dur)
		stw.tween_callback(spark.queue_free)

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
	# 발치 별무늬 마법진(펜타그램). 스폰 지점(월드)에 정적으로 깔리고 아군은 거기서 등장해 걸어 나간다
	# (아군을 따라가지 않음). 전용 FX 레이어에 담겨 성 위·아군 아래로 렌더. 회전 없음.
	var purple: Color = Color(0.66, 0.32, 0.98, 1.0)
	var rx: float = 40.0
	var ry: float = 20.0   # 납작(바닥 원근)

	var circle: Node2D = Node2D.new()
	circle.position = pos + Vector2(0.0, 26.0)  # 스폰 지점 원점 아래 = 발치
	var layer: Node = _summon_fx if is_instance_valid(_summon_fx) else self
	layer.add_child(circle)

	# 외곽 원
	var outer: Line2D = Line2D.new()
	outer.width = 2.5
	outer.default_color = purple
	outer.closed = true
	for i in 32:
		var a: float = TAU * float(i) / 32.0
		outer.add_point(Vector2(cos(a) * rx, sin(a) * ry))
	circle.add_child(outer)

	# 내부 5각 별(펜타그램) — 점 0-2-4-1-3 순으로 이어 별무늬
	var star: Line2D = Line2D.new()
	star.width = 2.0
	star.default_color = purple
	star.closed = true
	for idx in [0, 2, 4, 1, 3]:
		var a: float = -PI / 2.0 + TAU * float(idx) / 5.0
		star.add_point(Vector2(cos(a) * rx * 0.82, sin(a) * ry * 0.82))
	circle.add_child(star)

	# 등장(살짝 커지며 페이드 인) → 유지(아군 솟는 동안) → 페이드 아웃. 회전 없음.
	circle.scale = Vector2(0.7, 0.7)
	circle.modulate.a = 0.0
	var tw: Tween = circle.create_tween()  # circle에 바인딩 → 미니언 사망 시 함께 정리
	tw.tween_property(circle, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(circle, "modulate:a", 1.0, 0.12)
	tw.tween_interval(0.16)
	tw.tween_property(circle, "modulate:a", 0.0, 0.26)
	tw.tween_callback(circle.queue_free)

# ── 튜토리얼 가이드 시스템 ───────────────────────────────────

func _is_tutorial() -> bool:
	return current_chapter == 0 and current_stage == 0 and not GameSave.tutorial_completed

func _trigger_wave_guide(wave_idx: int) -> void:
	# 마물 교습(W0~2)은 '소환 게이트' — 팁이 자동으로 안 사라지고(duration 0), 해당 종류를
	# 소환할 때까지 유지(_on_summon_pressed에서 닫음). teaching 인덱스는 한도 예외에도 쓰임.
	_tutorial_teaching_minion = -1
	match wave_idx:
		0:
			# FX8 — 전사 학습: 첫 적이 다가올 무렵 소환 버튼 스포트라이트
			_tutorial_teaching_minion = HIRE_TYPE_INDICES[0]  # 전사
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if wave_active and summon_btns.size() > 0 and is_instance_valid(summon_btns[0]):
					show_tutorial_tip("전사를 소환해 성을 지키세요!", summon_btns[0], 0.0)
			)
		1:
			# FX9 — 궁수 학습: 후방 사수가 등장하는 웨이브, 궁수 버튼 스포트라이트
			_tutorial_teaching_minion = HIRE_TYPE_INDICES[1]  # 궁수
			if summon_btns.size() > 1 and is_instance_valid(summon_btns[1]):
				show_tutorial_tip("궁수로 후방의 적을 노리세요!", summon_btns[1], 0.0)
		2:
			# FX10 — 탱크 학습: 브루트(벽)가 등장하는 웨이브, 탱크 버튼 스포트라이트
			_tutorial_teaching_minion = HIRE_TYPE_INDICES[2]  # 탱크
			if summon_btns.size() > 2 and is_instance_valid(summon_btns[2]):
				show_tutorial_tip("탱크로 강한 적을 막으세요!", summon_btns[2], 0.0)
		3:
			# FX11 — 낙뢰 학습: 잡병 무리가 몰려오는 웨이브, 마법 버튼 스포트라이트
			var lightning_btn: Control = ability_system.get_field_button(0)
			if is_instance_valid(lightning_btn):
				show_tutorial_tip("낙뢰로 몰려드는 적을 쓸어버리세요!", lightning_btn, 12.0, ability_system.get_field_button_rect(0), false)

func _show_shop_guide() -> void:
	# 타이틀을 튜토리얼 안내 문구로 교체 (부제에 힌트 표시)
	shop_subtitle.text = "골드로 강화하고 '다음 웨이브'를 누르세요"

	# 닫기 버튼 노란 펄스 글로우
	if _shop_btn_pulse_tween and _shop_btn_pulse_tween.is_valid():
		_shop_btn_pulse_tween.kill()
	_shop_btn_pulse_tween = create_tween().set_loops().set_ignore_time_scale(true)
	_shop_btn_pulse_tween.tween_property(shop_close_btn, "modulate", Color(1.6, 1.35, 0.5, 1), 0.5)
	_shop_btn_pulse_tween.tween_property(shop_close_btn, "modulate", Color(1.0, 1.0, 1.0, 1), 0.5)

func show_tutorial_tip(message: String, target: Control, duration: float = 4.0, rect_override: Rect2 = Rect2(), dim: bool = true) -> void:
	_close_guide()
	_guide_active = true
	_guide_layer = CanvasLayer.new()
	_guide_layer.layer = 80
	add_child(_guide_layer)

	# rect_override가 주어지면(원형 마법 버튼처럼 컨트롤 rect≠시각 영역일 때) 그걸 쓴다
	var rect: Rect2 = rect_override if rect_override.size.x > 0.0 else target.get_global_rect()

	# 배경 dim — 타깃(스포트라이트) 영역만 비우고 나머지를 어둡게. 입력은 통과(non-blocking)이라
	# 게임이 계속 돌아가고, 골드를 못 모았어도 갇히지 않는다(freeze 폐기).
	# dim=false: 낙뢰·나팔처럼 적을 조준해야 하는 팁은 배경 적이 어두워지면 안 되므로 생략.
	if dim:
		var vp: Vector2 = Vector2(480.0, 960.0)
		var spot_pad: float = 6.0
		var spot: Rect2 = Rect2(rect.position - Vector2(spot_pad, spot_pad), rect.size + Vector2(spot_pad, spot_pad) * 2.0)
		var dim_color: Color = Color(0, 0, 0, 0.55)
		var sx0: float = clampf(spot.position.x, 0.0, vp.x)
		var sy0: float = clampf(spot.position.y, 0.0, vp.y)
		var sx1: float = clampf(spot.position.x + spot.size.x, 0.0, vp.x)
		var sy1: float = clampf(spot.position.y + spot.size.y, 0.0, vp.y)
		# 사각 구멍을 만드는 4분할 스트립 (상 / 하 / 좌 / 우)
		for sr: Rect2 in [
			Rect2(0, 0, vp.x, sy0),                        # 상
			Rect2(0, sy1, vp.x, vp.y - sy1),               # 하
			Rect2(0, sy0, sx0, sy1 - sy0),                 # 좌
			Rect2(sx1, sy0, vp.x - sx1, sy1 - sy0),        # 우
		]:
			if sr.size.x <= 0.0 or sr.size.y <= 0.0:
				continue
			var strip: ColorRect = ColorRect.new()
			strip.color = dim_color
			strip.position = sr.position
			strip.size = sr.size
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_guide_layer.add_child(strip)

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
	# 안내 텍스트 — 게임 위에서도 잘 읽히게 흰색 박스 + 검정 글씨 + 큰 글씨
	var FONT_SIZE: int = 24
	var msg: Label = Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", FONT_SIZE)
	msg.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10, 1))  # 검정 텍스트
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(msg)  # 폰트 해석 후 텍스트 폭 측정

	var fnt: Font = msg.get_theme_font("font")
	var text_w: float = fnt.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
	var PAD_X: float = 20.0
	var PAD_Y: float = 11.0
	var box_w: float = min(text_w + PAD_X * 2.0, 460.0)
	var box_h: float = float(FONT_SIZE) + PAD_Y * 2.0
	var box_x: float = 240.0 - box_w * 0.5  # 화면 가로 중앙

	var box: Panel = Panel.new()
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.97, 0.97, 0.98, 0.98)  # 흰색 박스
	box_style.set_corner_radius_all(8)
	box_style.set_border_width_all(2)
	box_style.border_color = Color(0.15, 0.13, 0.20, 0.9)
	box.add_theme_stylebox_override("panel", box_style)
	box.position = Vector2(box_x, msg_y)
	box.size = Vector2(box_w, box_h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.add_child(box)
	_guide_layer.move_child(box, msg.get_index())  # 박스를 텍스트 뒤로

	msg.position = Vector2(box_x, msg_y)
	msg.size = Vector2(box_w, box_h)

	_guide_tween = create_tween().set_loops().set_ignore_time_scale(true)
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

	_guide_tween = create_tween().set_loops().set_ignore_time_scale(true)
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
