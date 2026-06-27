extends Node2D

const WaveData = preload("res://scripts/WaveData.gd")
const Enemy = preload("res://scripts/Enemy.gd")
const EnemyScene = preload("res://scenes/Enemy.tscn")
const BossScene = preload("res://scenes/Boss.tscn")
const SkeletonWarriorScene = preload("res://scenes/SkeletonWarrior.tscn")
const DialogueData = preload("res://scripts/data/DialogueData.gd")  # 마왕 바크·보스 인트로 대사 콘텐츠
const ShopData = preload("res://scripts/data/ShopData.gd")  # 상점 항목 콘텐츠
const MinionData = preload("res://scripts/data/MinionData.gd")  # 하인 로스터·고용 경제 콘텐츠
const CardData = preload("res://scripts/data/CardData.gd")  # 카드/키스톤 풀·등급·축·키스톤 튜닝 콘텐츠

# 언데드 하인
var max_minions: int = 6  # MD12: 전역 총량 캡 (종류별 캡 → 전역 캡으로 변경)
var minion_attack_bonus: float = 1.0
var minion_move_speed_bonus: float = 1.0
var minion_cost_reduction: int = 0
var minion_hp_bonus: float = 1.0
var minion_range_bonus: float = 0.0
var minion_lifesteal: float = 0.0

# 하인 로스터·고용 경제 콘텐츠 → scripts/data/MinionData.gd
var summon_btns: Array = []
var _summon_name_lbls: Array = []  # 소환 버튼 자식 이름 라벨 배열
var _summon_cost_lbls: Array = []  # 소환 버튼 자식 비용 라벨 배열

# RD16 — 하인 강화 (수치 → MinionData.HIRE_UPGRADE_*)
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
var _tutorial_teaching_minion: int = -1  # 현재 교습 중인 마물 MinionData.MINION_TYPES 인덱스(-1=없음). 소환 게이트 + 한도 예외용.
var enemies_alive: int = 0
var _pulse_armed_t2: bool = true  # 2/3 임계 펄스 무장 상태
var _pulse_armed_t1: bool = true  # 1/3 임계 펄스 무장 상태

# 펄스 스폰 스케줄러
var _spawn_schedule: Array[Dictionary] = []  # 각 {t, enemy, hp, spd, dmg}
var _threat_alerts: Array[float] = []  # 위협 텔레그래프 발동 시각(alert 펄스의 t - THREAT_WARN_LEAD), 정렬됨
const THREAT_WARN_LEAD: float = 1.3  # 무리/러시 펄스보다 이만큼 먼저 경고 알람(브레이스 호흡+마법 장전 여유)
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
# 키스톤 효과 튜닝(CardData.KEYSTONE_ECHO_RADIUS·HORDE_REFUND_*) → scripts/data/CardData.gd
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
# 카드/키스톤 풀·등급·축·카테고리 콘텐츠 → scripts/data/CardData.gd
# 카드 로직·뷰·로컬상태(available_skill_cards·current_cards·_card_rows·_value_re) → scripts/CardSystem.gd (card_system)

# 연출/대사 텍스트 콘텐츠 → scripts/data/DialogueData.gd (WAVE_CLEAR_LINES·POWER_LINES·DANGER_LINES)
const POWER_BARK_CHANCE: float = 0.2   # 마법 발동 시 바크 확률 (스팸 방지)
const DEMON_BARK_MIN_GAP_MSEC: int = 2800   # 마왕 바크 최소 간격(ms). 위급 바크는 무시(우선권).
const CASTLE_HALF: float = 169.2       # 외벽+코너타워 외곽 (Enemy/Boss/SkeletonWarrior와 동일·성 scale 1.8). ⚠️성 크기 바꾸면 같이 수정
const CASTLE_DANGER_RATIO: float = 0.25
const CASTLE_PULSE_T2: float = 2.0/3.0          # 넉백 펄스 1단계 임계값 (2/3)
const CASTLE_PULSE_T1: float = 1.0/3.0          # 넉백 펄스 2단계 임계값 (1/3)
const CASTLE_PULSE_FORCE: float = 350.0         # 펄스 기본 넉백 세기
const CASTLE_PULSE_REARM_MARGIN: float = 0.06   # 히스테리시스 마진 (회복 시 재무장)
# 상점 항목 콘텐츠 → scripts/data/ShopData.gd (SHOP_ITEMS)
# 상점 UI·상태(shop_btns·shop_purchased 등) → ShopController.gd (shop)

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
# 상점 UI 노드($UI/ShopPanel/*)·트윈·플래그 → ShopController.gd (shop)
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var modal_dim: ColorRect = $UI/ModalDim

var _shop_dim_alpha: float = 0.72   # modal_dim 원래 알파 보관(_set_modal_dim 공유 — Game 소유 유지). 상점이 game._shop_dim_alpha로 읽고 씀

# ── Phase B — 마법 시스템 ─────────────────────────────────────
const AbilitySystemScript = preload("res://scripts/AbilitySystem.gd")
var ability_system: Node = null
const ShopControllerScript = preload("res://scripts/ShopController.gd")  # 상점 도메인 컨트롤러
var shop: Node = null  # ShopController (build_buttons/open/close + 상점 UI·상태 소유)
const CardSystemScript = preload("res://scripts/CardSystem.gd")  # 카드/키스톤 도메인 컨트롤러
var card_system: Node = null  # CardSystem (_show_cards/_show_keystones/_pick_card/_apply_card + 카드 로컬상태)
const MinionSystemScript = preload("res://scripts/MinionSystem.gd")  # 미니언 도메인 컨트롤러(소환·스폰·생애주기 슬라이스1)
var minion_system: Node = null  # MinionSystem (상태는 Game 소유, 로직만 이동)
const UpgradeSystemScript = preload("res://scripts/UpgradeSystem.gd")  # 강화 UI 도메인 컨트롤러
var upgrade_system: Node = null  # UpgradeSystem (강화 버튼·팝업·적용, 상태는 Game 소유)
const WaveTrackerScript = preload("res://scripts/WaveTracker.gd")  # 웨이브 트래커 UI 도메인 컨트롤러
var wave_tracker_ui: Node = null  # WaveTracker (wave_tracker 노드는 Game 소유)
const ResultScreenScript = preload("res://scripts/ResultScreen.gd")  # 결과 화면 도메인 컨트롤러
var result_screen: Node = null  # ResultScreen (게임오버/클리어/결과/씬전환, 상태는 Game 소유)

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
	card_title.text = Loc.t("card_select_title")
	card_subtitle.text = Loc.t("card_select_subtitle")
	# 결과 버튼 연결은 ResultScreen.setup()에서 (result_screen 생성 후)
	# 눌림 바운스 — 페이드 전환(0.35s) 동안 보임. btn1은 비활성 시 pressed 안 떠 성공 시에만 재생.
	_add_button_press_bounce(result_btn1)
	_add_button_press_bounce(result_btn2)
	sacrifice_button = Button.new()
	sacrifice_button.focus_mode = Control.FOCUS_NONE
	sacrifice_button.add_theme_font_size_override("font_size", 20)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	$UI.add_child(sacrifice_button)
	# 상점 도메인 컨트롤러 생성 (UI 노드 캐시 + 닫기 버튼 연결 + 항목 버튼 빌드는 setup 내부)
	shop = ShopControllerScript.new()
	add_child(shop)
	shop.setup(self)
	# 카드/키스톤 도메인 컨트롤러 생성
	card_system = CardSystemScript.new()
	add_child(card_system)
	card_system.setup(self)
	# 미니언 도메인 컨트롤러 생성 (소환 UI·스폰·생애주기)
	minion_system = MinionSystemScript.new()
	add_child(minion_system)
	minion_system.setup(self)
	minion_system._build_summon_buttons()
	# 강화 UI 도메인 컨트롤러 생성
	upgrade_system = UpgradeSystemScript.new()
	add_child(upgrade_system)
	upgrade_system.setup(self)
	upgrade_system._build_upgrade_ui()
	# 웨이브 트래커 UI 도메인 컨트롤러 생성
	wave_tracker_ui = WaveTrackerScript.new()
	add_child(wave_tracker_ui)
	wave_tracker_ui.setup(self)
	# 결과 화면 도메인 컨트롤러 생성
	result_screen = ResultScreenScript.new()
	add_child(result_screen)
	result_screen.setup(self)
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
	for n in [modal_dim, card_panel, result_panel, shop.shop_panel, fade_rect]:
		ui_layer.move_child(n, ui_layer.get_child_count() - 1)
	current_chapter = GameSave.start_chapter
	current_stage = GameSave.start_stage
	current_wave = 0
	GameSave.start_chapter = 0
	GameSave.start_stage = 0
	run_start_time = Time.get_ticks_msec() / 1000.0
	result_screen._fade_in()
	_apply_facility_bonuses()
	if _is_tutorial():
		souls += 30
	# Phase C — 시작 골드 보장: 시설 보너스 반영 후 MinionData.HIRE_START_GOLD 미만이면 채움
	if souls < MinionData.HIRE_START_GOLD:
		souls = MinionData.HIRE_START_GOLD
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
		wave_tracker_ui._build_wave_tracker()
	wave_tracker_ui.update_wave_tracker()

	var data: Dictionary = WaveData.get_wave(current_chapter, current_stage, current_wave)

	if data["type"] == "shop":
		wave_active = false
		wave_tracker_ui._reveal_wave_tracker()
		shop.open()
		return

	wave_active = true
	wave_tracker_ui._reveal_wave_tracker()

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
	_threat_alerts.clear()
	_wave_elapsed = 0.0

	# pulses 포맷 처리 (composition fallback 포함)
	if data.has("pulses"):
		enemies_alive = 0
		for pulse: Dictionary in data["pulses"]:
			var pulse_t: float = float(pulse["t"])
			if pulse.get("alert", false):  # 위협 텔레그래프: 작곡가가 찍은 무리/러시 펄스만
				_threat_alerts.append(maxf(0.0, pulse_t - THREAT_WARN_LEAD))
			for entry: Dictionary in pulse["spawn"]:
				var preset: Dictionary = Enemy.TYPE_PRESETS[entry["enemy"]]
				var e_hp: float = base_hp * preset["hp_mult"]
				var e_spd: float = base_speed * preset["speed_mult"]
				var e_dmg: int = int(base_damage * preset["damage_mult"])
				var spawn_count: int = entry["count"]
				if not _is_tutorial():
					spawn_count = int(ceil(spawn_count * WaveData.DENSITY_MULT.get(entry["enemy"], 1.0)))
				for _i: int in spawn_count:
					_spawn_schedule.append({
						"t": pulse_t + randf_range(0.0, 0.25),
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
			var spawn_count: int = entry["count"]
			if not _is_tutorial():
				spawn_count = int(ceil(spawn_count * WaveData.DENSITY_MULT.get(entry["enemy"], 1.0)))
			for _i: int in spawn_count:
				_spawn_schedule.append({
					"t": randf_range(0.0, 0.25),
					"enemy": entry["enemy"],
					"hp": e_hp,
					"spd": e_spd,
					"dmg": e_dmg,
				})
				enemies_alive += 1

	_spawn_schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	_threat_alerts.sort()

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

func _on_boss_entered(boss_node: Node) -> void:
	_screen_shake(6.0, 0.35)
	_show_boss_title(boss_node.boss_name)

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

func enemy_died() -> void:
	if not wave_active:
		return
	enemies_alive -= 1
	if enemies_alive > 0:
		return

	# 최종 보스 웨이브는 보스 포함 모든 몬스터를 제거해야 클리어 (보스만 먼저 죽고 잡몹이 남으면 계속 전투)
	if WaveData.get_wave(current_chapter, current_stage, current_wave).get("type") == "boss":
		result_screen.game_clear()
	else:
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
		_demon_say("hurt", DialogueData.DANGER_LINES[randi() % DialogueData.DANGER_LINES.size()], true)
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
		result_screen.game_over()

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
	_demon_say("attack", DialogueData.POWER_LINES[randi() % DialogueData.POWER_LINES.size()])

func end_wave() -> void:
	if not wave_active:
		return
	wave_active = false
	_spawn_schedule.clear()
	_threat_alerts.clear()
	_close_guide()

	if graveyard_heal > 0:
		castle_hp = min(castle_hp + graveyard_heal, castle_max_hp)
		castle_bar.set_hp(castle_hp, castle_max_hp)
		castle_vis.set_hp_ratio(float(castle_hp) / float(castle_max_hp))
		_update_demon_danger()

	if current_wave >= WaveData.stage_wave_count(current_chapter, current_stage) - 1:
		result_screen.game_clear()
		return

	if not _is_tutorial() and randf() < 0.3:
		var line: String = DialogueData.WAVE_CLEAR_LINES[randi() % DialogueData.WAVE_CLEAR_LINES.size()]
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
		card_system._show_keystones(["legion", "surge"], true)
		return
	# 키스톤2 심화(중간보스 클리어 시): 비튜토리얼만 — 1-0 mid_boss는 game_clear로 빠져 여기 도달 안 함
	if not _is_tutorial():
		if wtype == "mid_boss" and keystone2 == "" and keystone1 == "legion":
			card_system._show_keystones(["horde", "echo"])
			return
		elif wtype == "mid_boss" and keystone2 == "" and keystone1 == "surge":
			card_system._show_keystones(["vulnerable", "execute"])
			return
	card_system._show_cards()

func _set_modal_dim(on: bool) -> void:
	# 카드/키스톤 선택 모달 — 배경(월드·상단 HUD·성HP바·트래커)을 딤으로 덮어 선택에 집중시킨다.
	# z순서상 modal_dim은 HUD 위·모달 패널 아래라, 켜면 캐릭터 비침과 타이틀↔HUD 겹침이 함께 해소된다.
	if on:
		modal_dim.modulate.a = _shop_dim_alpha
	modal_dim.visible = on

# 카드/키스톤 로직·뷰·효과적용(_show_cards·_pick_card·_apply_card·_build_card_row 등) → scripts/CardSystem.gd (card_system)

# 웨이브 트래커 UI(아이콘/색 const + 빌드/렌더 로직) → scripts/WaveTracker.gd (wave_tracker_ui)

func earn_crown_shards(n: int) -> void:
	if n <= 0:
		return
	crowns_this_run += n
	GameSave.add_crown_shards(n)

func _process(delta: float) -> void:
	# 펄스 스폰 드레인 — 웨이브 진행 중에만 동작
	if wave_active and not _spawn_schedule.is_empty():
		_wave_elapsed += delta
		while not _threat_alerts.is_empty() and _threat_alerts[0] <= _wave_elapsed:
			_threat_alerts.pop_front()
			_show_threat_warning()
		while not _spawn_schedule.is_empty() and _spawn_schedule[0]["t"] <= _wave_elapsed:
			_spawn_scheduled_enemy(_spawn_schedule.pop_front())
	# Phase B — 마법 시스템 쿨다운 + UI 갱신 (Phase A 가드보다 앞에 위치)
	# 전투 종료(클리어/패배) 후엔 쿨다운 정지 — 결과 팝업 띄운 채 마법이 차오르지 않게.
	if is_instance_valid(ability_system) and not _battle_over:
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
		minion_system._spawn_minion(t)

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

## 1-2(st1)에서 마물을 한 번이라도 소환했는지 (강화 교습 선행 조건)
var _st1_summoned: bool = false

## 1-2 강화 교습 팁: 소환 경험 + 강화 가능(골드 충분) + 전투 중일 때 1회.
## 소환 시 + 골드 증가 시(add_souls) 호출 → 둘 중 조건 충족되는 시점에 뜬다.
func _try_show_enhance_tip() -> void:
	if GameSave.taught_enhance:
		return
	if current_stage != 1 or not _st1_summoned:
		return
	if souls < MinionData.HIRE_UPGRADE_COST_BASE:
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

# ── 미니언 도메인 facade (로직 본체 = scripts/MinionSystem.gd) ──
# 외부 호출자(SkeletonWarrior=minion_died, CardSystem/내부=_refresh_summon_buttons) 인터페이스 보존(GS3)
func minion_died(pos = null, type_id: String = "") -> void:
	minion_system.minion_died(pos, type_id)

func _refresh_summon_buttons() -> void:
	minion_system._refresh_summon_buttons()

# ── 강화 UI 도메인 facade (로직 본체 = scripts/UpgradeSystem.gd) ──
# 외부 호출자(ShopController=_close_upgrade_popup·_set_upgrade_btn_visible, 내부 Game=_refresh_upgrade_popup) 보존(GS3)
func _set_upgrade_btn_visible(v: bool) -> void:
	upgrade_system._set_upgrade_btn_visible(v)

func _close_upgrade_popup() -> void:
	upgrade_system._close_upgrade_popup()

func _refresh_upgrade_popup() -> void:
	upgrade_system._refresh_upgrade_popup()

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
	tween.parallel().tween_property(n, "scale", Vector2.ONE * (CardData.KEYSTONE_ECHO_RADIUS / base_r), 0.4)
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

# 위협 텔레그래프 — 무리/러시 펄스 직전 "브레이스" 알람(탕탕특공대식 저정보 경고).
# 상단 가장자리 빨강 글로우(적이 들어오는 방향) + ⚠ 글리프 + 가벼운 흔들림. 종류·수는 안 알림(알람이지 인텔 아님).
func _show_threat_warning() -> void:
	# 중복 방지 — 배너가 이미 떠 있으면 덧대지 않음(연달아 깜빡여 거슬리는 것 차단)
	if not get_tree().get_nodes_in_group("threat_banner").is_empty():
		return
	var vp_w: float = get_viewport_rect().size.x
	# 빨강 리본 배너 — 전장 상단에 "여기 위험" 한 방. 종류·수는 안 알림(알람이지 인텔 아님).
	var bw: float = vp_w * 0.52
	var bh: float = 34.0
	var panel: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.74, 0.13, 0.13, 0.95)
	sb.border_color = Color(0.34, 0.04, 0.04, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(bw, bh)
	panel.position = Vector2((vp_w - bw) * 0.5, 300.0)
	panel.pivot_offset = Vector2(bw * 0.5, bh * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.add_to_group("threat_banner")
	$UI.add_child(panel)
	# 문구 — 하드코딩 금지(Loc 경유, 글로벌 타깃)
	var label: Label = Label.new()
	label.text = Loc.t("threat_warning")
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.26, 0.02, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.size = Vector2(bw, bh)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	# 팝 인 → 날카로운 깜빡임 ×3 → 길게 유지(위협 착지까지) → 아웃
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2)
	for _i in 3:  # 깜빡임 3회 — 짧게 꺼졌다 탁 켜지는 경보 리듬
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(panel, "modulate:a", 0.15, 0.1)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	tween.tween_interval(1.0)  # 스폰~압박 구간 내내 떠 있게
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(panel.queue_free)

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
	var category: String = CardData.CARD_CATEGORY_MAP.get(card_id, "player")
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
			_tutorial_teaching_minion = MinionData.HIRE_TYPE_INDICES[0]  # 전사
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if wave_active and summon_btns.size() > 0 and is_instance_valid(summon_btns[0]):
					show_tutorial_tip("전사를 소환해 성을 지키세요!", summon_btns[0], 0.0)
			)
		1:
			# FX9 — 궁수 학습: 후방 사수가 등장하는 웨이브, 궁수 버튼 스포트라이트
			_tutorial_teaching_minion = MinionData.HIRE_TYPE_INDICES[1]  # 궁수
			if summon_btns.size() > 1 and is_instance_valid(summon_btns[1]):
				show_tutorial_tip("궁수로 후방의 적을 노리세요!", summon_btns[1], 0.0)
		2:
			# FX10 — 탱크 학습: 브루트(벽)가 등장하는 웨이브, 탱크 버튼 스포트라이트
			_tutorial_teaching_minion = MinionData.HIRE_TYPE_INDICES[2]  # 탱크
			if summon_btns.size() > 2 and is_instance_valid(summon_btns[2]):
				show_tutorial_tip("탱크로 강한 적을 막으세요!", summon_btns[2], 0.0)
		3:
			# FX11 — 낙뢰 학습: 잡병 무리가 몰려오는 웨이브, 마법 버튼 스포트라이트
			var lightning_btn: Control = ability_system.get_field_button(0)
			if is_instance_valid(lightning_btn):
				show_tutorial_tip("낙뢰로 몰려드는 적을 쓸어버리세요!", lightning_btn, 12.0, ability_system.get_field_button_rect(0), false)
	# 골드 보장: 교습 중인 마물(궁수/탱크)은 팁이 뜨는 순간 살 수 있어야 함.
	# W0 소비로 비용 미달이면 강조 버튼을 눌러도 무반응(_on_summon_pressed early-return)
	# → "하라는데 안 됨" 죽은 창. 시작 골드 플로어(HIRE_START_GOLD)·교습 한도 +1 예외와
	# 동일한 튜토리얼 슈가로, 비용까지 조용히 채움(플로터 없음).
	if _tutorial_teaching_minion >= 0:
		var teach_entry: Dictionary = MinionData.MINION_TYPES[_tutorial_teaching_minion]
		var teach_cost: int = max(5, teach_entry["cost"] - minion_cost_reduction)
		if souls < teach_cost:
			souls = teach_cost
			_update_souls_ui()

func _show_shop_guide() -> void:
	# 타이틀을 튜토리얼 안내 문구로 교체 (부제에 힌트 표시)
	shop.shop_subtitle.text = "골드로 강화하고 '다음 웨이브'를 누르세요"

	# 닫기 버튼 노란 펄스 글로우
	if shop._shop_btn_pulse_tween and shop._shop_btn_pulse_tween.is_valid():
		shop._shop_btn_pulse_tween.kill()
	shop._shop_btn_pulse_tween = create_tween().set_loops().set_ignore_time_scale(true)
	shop._shop_btn_pulse_tween.tween_property(shop.shop_close_btn, "modulate", Color(1.6, 1.35, 0.5, 1), 0.5)
	shop._shop_btn_pulse_tween.tween_property(shop.shop_close_btn, "modulate", Color(1.0, 1.0, 1.0, 1), 0.5)

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
