extends Node

const SAVE_PATH = "user://save.cfg"
const SKELETON_CAP: int = 8

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
