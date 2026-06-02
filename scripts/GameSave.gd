extends Node

const SAVE_PATH = "user://save.cfg"
const SKELETON_CAP: int = 8

# ── 위엄(Majesty) 시스템 상수 ─────────────────────────────────
const MAJESTY_CAP: int = 5
# 각 레벨 도달에 필요한 누적 EXP (placeholder — 밸런스 폴리싱 시 조정)
const MAJESTY_LEVEL_REQ: Array = [100, 150, 200, 250, 300]
const COURT_BASE_EXP: int = 30    # 알현 기본 EXP (placeholder)
const COURT_PER_SKELETON: int = 10 # 충신 1명당 추가 EXP (placeholder)

var crown_shards: int = 0
var skeleton_count: int = 0
var skeleton_count_seen: int = 0  # 로비에서 등장 연출을 본 해골 수
var facility_levels: Dictionary = {
	"throne": 0, "wall": 0, "graveyard": 0, "arsenal": 0, "banquet": 0
}
var start_chapter: int = 0   # 씬 전환 시 시작 챕터 (저장 불필요)
var start_stage: int = 0     # 씬 전환 시 시작 스테이지 (저장 불필요)
var current_chapter: int = 0 # 다음에 플레이할 챕터 (저장됨)
var current_stage: int = 0   # 다음에 플레이할 스테이지 (저장됨)
var intro_seen: bool = false        # 인트로 시퀀스 시청 여부
var tutorial_completed: bool = false # 1-1 튜토리얼 클리어 여부
var first_lobby_visit_done: bool = false # 첫 시설업 가이드 완료 여부

# ── 위엄(Majesty) 저장 필드 ───────────────────────────────────
var majesty_level: int = 0          # 0~5 (MAJESTY_CAP)
var majesty_exp: int = 0            # 현재 레벨 내 진척 EXP
var unlock_credits: int = 0         # 레벨업으로 받은 미사용 해제권
var doctrines: Dictionary = {       # ""/"A"/"B" — 카테고리별 선택
	"death": "", "war": "", "soul": "", "minion": "", "rule": ""
}
var last_court_day: String = ""     # 마지막 알현 로컬 날짜 "YYYY-MM-DD"

func _ready():
	load_data()

func add_crown_shards(n: int):
	crown_shards += n
	save_data()

# 보스 처치 시 호출. 성공 시 true(해골 추가), false(만랩 상태)
func gain_skeleton() -> bool:
	if skeleton_count >= SKELETON_CAP:
		return false
	skeleton_count += 1
	save_data()
	return true

# ── 위엄 API ─────────────────────────────────────────────────

# EXP 누적. 레벨업 시 unlock_credits += 1, 잔여 EXP 이월, lv5(캡) 도달 후 EXP 무시.
# 반환 = 이번에 오른 레벨 수 (레벨업 연출용).
func add_majesty_exp(n: int) -> int:
	if majesty_level >= MAJESTY_CAP or n <= 0:
		save_data()
		return 0
	var levels_gained: int = 0
	majesty_exp += n
	while majesty_level < MAJESTY_CAP:
		var req: int = MAJESTY_LEVEL_REQ[majesty_level]
		if majesty_exp >= req:
			majesty_exp -= req
			majesty_level += 1
			unlock_credits += 1
			levels_gained += 1
			if majesty_level >= MAJESTY_CAP:
				majesty_exp = 0  # 캡 후 잉여 EXP 버림
				break
		else:
			break
	save_data()
	return levels_gained

# 알현 EXP 계산: 기본 + 충신 수 비례
func court_exp_amount() -> int:
	return COURT_BASE_EXP + COURT_PER_SKELETON * skeleton_count

# 오늘 알현 가능 여부 (로컬 날짜 기준)
func can_hold_court() -> bool:
	var today: String = Time.get_date_string_from_system()
	return today != last_court_day

# 알현 실행. 가능하면 EXP 부여 후 오른 레벨 수 반환, 불가능하면 -1.
func hold_court() -> int:
	if not can_hold_court():
		return -1
	last_court_day = Time.get_date_string_from_system()
	var gained: int = add_majesty_exp(court_exp_amount())
	# add_majesty_exp 내부에서 save_data() 호출됨 (last_court_day도 저장됨)
	return gained

# 교리 선택. 해제권 있고 해당 카테고리 미선택일 때만 성공.
func assign_doctrine(category: String, choice: String) -> bool:
	if unlock_credits <= 0:
		return false
	if not doctrines.has(category):
		return false
	if doctrines[category] != "":
		return false
	doctrines[category] = choice
	unlock_credits -= 1
	save_data()
	return true

# 교리 5카테고리 전부 선택 완료 여부
func is_doctrine_complete() -> bool:
	for key: String in doctrines:
		if doctrines[key] == "":
			return false
	return true

# 어포던스 뱃지용: 알현 가능 OR 미사용 해제권 보유
func has_court_reward() -> bool:
	return can_hold_court() or unlock_credits > 0

func save_data():
	var config = ConfigFile.new()
	config.set_value("meta", "crown_shards", crown_shards)
	config.set_value("meta", "skeleton_count", skeleton_count)
	config.set_value("meta", "skeleton_count_seen", skeleton_count_seen)
	config.set_value("meta", "current_chapter", current_chapter)
	config.set_value("meta", "current_stage", current_stage)
	config.set_value("meta", "intro_seen", intro_seen)
	config.set_value("meta", "tutorial_completed", tutorial_completed)
	config.set_value("meta", "first_lobby_visit_done", first_lobby_visit_done)
	for id in facility_levels:
		config.set_value("facilities", id, facility_levels[id])
	# 위엄 저장
	config.set_value("majesty", "level", majesty_level)
	config.set_value("majesty", "exp", majesty_exp)
	config.set_value("majesty", "unlock_credits", unlock_credits)
	config.set_value("majesty", "last_court_day", last_court_day)
	for cat: String in doctrines:
		config.set_value("doctrines", cat, doctrines[cat])
	config.save(SAVE_PATH)

func load_data():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		crown_shards = config.get_value("meta", "crown_shards", 0)
		skeleton_count = config.get_value("meta", "skeleton_count", 0)
		skeleton_count_seen = config.get_value("meta", "skeleton_count_seen", 0)
		current_chapter = config.get_value("meta", "current_chapter", 0)
		current_stage = config.get_value("meta", "current_stage", 0)
		intro_seen = config.get_value("meta", "intro_seen", false)
		tutorial_completed = config.get_value("meta", "tutorial_completed", false)
		first_lobby_visit_done = config.get_value("meta", "first_lobby_visit_done", false)
		for id in facility_levels:
			facility_levels[id] = config.get_value("facilities", id, 0)
		# 위엄 로드
		majesty_level = config.get_value("majesty", "level", 0)
		majesty_exp = config.get_value("majesty", "exp", 0)
		unlock_credits = config.get_value("majesty", "unlock_credits", 0)
		last_court_day = config.get_value("majesty", "last_court_day", "")
		for cat: String in doctrines:
			doctrines[cat] = config.get_value("doctrines", cat, "")
