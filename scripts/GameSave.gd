extends Node

const SAVE_PATH = "user://save.cfg"

var crown_shards: int = 0
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
var last_login_date: String = ""     # 마지막 출석 날짜 (YYYY-MM-DD)

func _ready():
	load_data()

func add_crown_shards(n: int):
	crown_shards += n
	save_data()

func save_data():
	var config = ConfigFile.new()
	config.set_value("meta", "crown_shards", crown_shards)
	config.set_value("meta", "current_chapter", current_chapter)
	config.set_value("meta", "current_stage", current_stage)
	config.set_value("meta", "intro_seen", intro_seen)
	config.set_value("meta", "tutorial_completed", tutorial_completed)
	config.set_value("meta", "first_lobby_visit_done", first_lobby_visit_done)
	config.set_value("meta", "last_login_date", last_login_date)
	for id in facility_levels:
		config.set_value("facilities", id, facility_levels[id])
	config.save(SAVE_PATH)

func load_data():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		crown_shards = config.get_value("meta", "crown_shards", 0)
		current_chapter = config.get_value("meta", "current_chapter", 0)
		current_stage = config.get_value("meta", "current_stage", 0)
		intro_seen = config.get_value("meta", "intro_seen", false)
		tutorial_completed = config.get_value("meta", "tutorial_completed", false)
		first_lobby_visit_done = config.get_value("meta", "first_lobby_visit_done", false)
		last_login_date = config.get_value("meta", "last_login_date", "")
		for id in facility_levels:
			facility_levels[id] = config.get_value("facilities", id, 0)
