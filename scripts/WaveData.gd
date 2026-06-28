extends Node

# =============================================
# 챕터 / 스테이지 / 웨이브 데이터 테이블
# - 챕터: 배경·컨셉이 바뀌는 단위
# - 스테이지: 플레이 버튼을 누르는 단위 (1-1, 1-2…)
# - 웨이브: 스테이지 안의 전투 진행
#
# 웨이브 구조:
#   base_hp / base_speed / base_damage : 해당 웨이브 기준치
#   pulses : [{"t": 초, "spawn": [{"enemy": "타입", "count": N}, ...]}, ...]
#     t=0 은 웨이브 시작 즉시, t=6 은 웨이브 시작 6초 후 스폰
#   적 타입: normal(기준) / scout(사수=원거리·하인무시) / brute(벽) / swarm(무리) / runner(돌격병=빠름·하인무시)
#   타입별 배율은 Enemy.gd TYPE_PRESETS 참조
# =============================================

# =============================================
# 밀도 노브 — 펄스 count에 타입별로 곱하는 배율 (Game.gd start_wave에서 적용)
# ⚠️ 공격적 1차값: 대량 등장 체감 확보용. 플테로 하향 튜닝 대상.
# 튜토리얼(1-1)은 Game.gd에서 제외 — FTUE 점진 도입 카운트 보존.
const DENSITY_MULT := {
	"normal": 1.3,
	"scout": 1.5,
	"brute": 1.2,
	"swarm": 2.0,
	"runner": 1.7,
}
# =============================================

const CHAPTERS = [
	{   # 챕터 1
		"stages": [
			{   # 스테이지 1-1 (FTUE 튜토리얼: 시스템 점진 도입)
				"waves": [
					# W1(idx0): 전사 학습 — 자동 공격 체험, 약한 잡병만
					{"type": "normal", "base_hp": 30, "base_speed": 50, "base_damage": 5,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 3}]},
					 ]},

					# W2(idx1): 궁수 학습 — 후방 사수 등장으로 원거리 대응 동기부여
					{"type": "normal", "base_hp": 35, "base_speed": 55, "base_damage": 6,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}, {"enemy": "scout", "count": 1}]},
						{"t": 5.0, "spawn": [{"enemy": "normal", "count": 2}]},
					 ]},

					# W3(idx2): 탱크 학습 — brute(벽) 등장으로 방어 라인 동기부여
					{"type": "normal", "base_hp": 40, "base_speed": 58, "base_damage": 6,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 1}, {"enemy": "normal", "count": 2}]},
						{"t": 6.0, "spawn": [{"enemy": "normal", "count": 2}]},
					 ]},

					# W4(idx3): 낙뢰 학습 — 잡병 무리 뭉침으로 AoE 가시화
					{"type": "normal", "base_hp": 45, "base_speed": 60, "base_damage": 6,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 5}]},
						{"t": 5.0, "spawn": [{"enemy": "normal", "count": 3}]},
					 ]},

					# W5: brute 보강
					{"type": "normal", "base_hp": 50, "base_speed": 60, "base_damage": 7,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 1}, {"enemy": "normal", "count": 1}]},
						{"t": 6.0, "spawn": [{"enemy": "normal", "count": 2}]},
					 ]},

					# W6: 영혼 상점 학습
					{"type": "shop"},

					# W7: 약한 미니 보스 (튜토리얼 마무리)
					{"type": "mid_boss", "base_hp": 50, "base_speed": 60, "base_damage": 7,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 1}]},
						{"t": 5.0, "spawn": [{"enemy": "normal", "count": 1}]},
					 ],
					 "boss_hp": 500, "boss_speed": 45, "boss_damage": 10,
					 "boss_name": "사관후보생", "crown_shards": 2, "pattern": "shield"},
				]
			},
			{   # 스테이지 1-2 (적 타입 하나씩 소개)
				"waves": [
					{"type": "normal", "base_hp": 50, "base_speed": 60, "base_damage": 8,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "normal", "count": 3}]},  # 절정
					 ]},

					{"type": "normal", "base_hp": 60, "base_speed": 62, "base_damage": 8,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "normal", "count": 3}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "scout", "count": 3}]},  # 절정(견제)
					 ]},

					{"type": "normal", "base_hp": 70, "base_speed": 65, "base_damage": 10,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "brute", "count": 1}, {"enemy": "normal", "count": 2}]},  # 빌드(벽)
						{"t": 8.0, "spawn": [{"enemy": "brute", "count": 1}, {"enemy": "normal", "count": 3}]},  # 절정
					 ]},

					{"type": "normal", "base_hp": 80, "base_speed": 65, "base_damage": 10,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "swarm", "count": 3}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "swarm", "count": 5}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "swarm", "count": 6}, {"enemy": "normal", "count": 2}]},  # 절정(무리 정점)
					 ]},

					{"type": "mid_boss", "base_hp": 70, "base_speed": 63, "base_damage": 8,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "scout",  "count": 2}]},
						{"t": 6.0, "spawn": [{"enemy": "normal", "count": 3}]},
					 ],
					 "boss_hp": 1000, "boss_speed": 50, "boss_damage": 15,
					 "boss_name": "수습 용사 인턴", "crown_shards": 3},

					{"type": "shop"},

					{"type": "normal", "base_hp": 90, "base_speed": 68, "base_damage": 12,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "normal", "count": 3}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "runner", "count": 3}]},  # 절정(침투)
					 ]},

					# W8 "벽+견제+침투(입문)" — 아크 크레셴도, runner 누수 도입
					{"type": "normal", "base_hp": 100, "base_speed": 70, "base_damage": 12,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 2}, {"enemy": "normal", "count": 2}]},  # 탐색(벽)
						{"t": 4.0, "spawn": [{"enemy": "scout", "count": 3}]},  # 빌드(견제)
						{"t": 8.0, "spawn": [{"enemy": "runner", "count": 3}]},  # 빌드(침투)
						{"t": 11.0, "spawn": [{"enemy": "runner", "count": 3}, {"enemy": "normal", "count": 2}]},  # 절정
					 ]},

					# W9 "핀치(입문)" — 앵커→빌드→무리→침투→핀치 크레셴도. 1-3보다 가볍게
					{"type": "normal", "base_hp": 110, "base_speed": 72, "base_damage": 14,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 2}, {"enemy": "normal", "count": 2}]},  # 탐색(앵커)
						{"t": 4.0, "spawn": [{"enemy": "brute", "count": 2}, {"enemy": "scout", "count": 2}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "swarm", "count": 5}]},  # 무리
						{"t": 10.0, "spawn": [{"enemy": "runner", "count": 4}]},  # 침투
						{"t": 12.0, "spawn": [{"enemy": "runner", "count": 3}, {"enemy": "scout", "count": 2}]},  # 절정(핀치)
					 ]},

					{"type": "boss", "base_hp": 100, "base_speed": 70, "base_damage": 12,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 3}]},
						{"t": 6.0, "spawn": [{"enemy": "brute",  "count": 2}]},
					 ],
					 "boss_hp": 3000, "boss_speed": 45, "boss_damage": 10,
					 "boss_name": "정의의 용사 알바생", "crown_shards": 10},
				]
			},
			{   # 스테이지 1-3 (특화 웨이브 비중 ↑)
				"waves": [
					{"type": "normal", "base_hp": 130, "base_speed": 70, "base_damage": 14,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "normal", "count": 3}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "scout", "count": 3}, {"enemy": "normal", "count": 2}]},  # 절정(견제)
					 ]},

					{"type": "normal", "base_hp": 150, "base_speed": 72, "base_damage": 15,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "normal", "count": 3}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "swarm", "count": 5}]},  # 절정(무리 맛보기→W3 폭주 예고)
					 ]},

					# W3 "무리 폭주(크레셴도)+침투 꼬리" — swarm 4→6→8 점증 후 runner 꼬리 누수
					{"type": "normal", "base_hp": 170, "base_speed": 75, "base_damage": 17,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "swarm", "count": 4}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "swarm", "count": 6}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "swarm", "count": 8}, {"enemy": "runner", "count": 2}]},  # 절정(무리 정점)
						{"t": 12.0, "spawn": [{"enemy": "runner", "count": 3}]},  # 침투 꼬리=옆구리 러시
					 ]},

					{"type": "normal", "base_hp": 190, "base_speed": 76, "base_damage": 18,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 2}]},  # 탐색(벽 전진)
						{"t": 4.0, "spawn": [{"enemy": "brute", "count": 2}, {"enemy": "normal", "count": 2}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "runner", "count": 4}]},  # 절정(돌파)
					 ]},

					{"type": "mid_boss", "base_hp": 170, "base_speed": 74, "base_damage": 15,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "scout", "count": 2}]},  # 탐색
						{"t": 5.0, "spawn": [{"enemy": "scout", "count": 3}, {"enemy": "normal", "count": 2}]},  # 빌드(엘리트 압박)
					 ],
					 "boss_hp": 2000, "boss_speed": 58, "boss_damage": 22,
					 "boss_name": "용사 대리", "crown_shards": 5},

					{"type": "shop"},

					# W7 "벽+견제+침투(크레셴도)" — 4펄스 점증, 후반 돌파 비중↑
					{"type": "normal", "base_hp": 210, "base_speed": 78, "base_damage": 20,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 2}, {"enemy": "normal", "count": 2}]},  # 탐색
						{"t": 4.0, "spawn": [{"enemy": "brute", "count": 2}, {"enemy": "scout", "count": 3}]},  # 빌드(견제)
						{"t": 8.0, "spawn": [{"enemy": "runner", "count": 4}, {"enemy": "normal", "count": 2}]},  # 빌드(침투)
						{"t": 12.0, "spawn": [{"enemy": "runner", "count": 4}, {"enemy": "scout", "count": 2}]},  # 절정
					 ]},

					# W8 "벽+우회(크레셴도)" — 벽으로 열고 runner 누수 점증
					{"type": "normal", "base_hp": 225, "base_speed": 80, "base_damage": 22,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 3}, {"enemy": "normal", "count": 2}]},  # 탐색(벽)
						{"t": 4.0, "spawn": [{"enemy": "brute", "count": 3}]},  # 빌드(벽 보강)
						{"t": 8.0, "spawn": [{"enemy": "runner", "count": 4}]},  # 우회 1파
						{"t": 11.0, "spawn": [{"enemy": "runner", "count": 4}, {"enemy": "normal", "count": 2}]},  # 우회 2파
						{"t": 14.0, "spawn": [{"enemy": "runner", "count": 3}, {"enemy": "scout", "count": 2}]},  # 절정(마지막 누수)
					 ]},

					# W9 "핀치(최대 크레셴도)" — 앵커→빌드→무리폭주(경고)→침투→마지막 핀치. 1-3 유일 위협 경고.
					{"type": "normal", "base_hp": 240, "base_speed": 82, "base_damage": 24,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 3}, {"enemy": "normal", "count": 2}]},  # 탐색(앵커)
						{"t": 4.0, "spawn": [{"enemy": "brute", "count": 3}, {"enemy": "scout", "count": 2}]},  # 빌드
						{"t": 8.0, "spawn": [{"enemy": "swarm", "count": 8}], "alert": true},  # 무리 폭주 — 1-3 유일 위협 경고
						{"t": 11.0, "spawn": [{"enemy": "runner", "count": 5}]},  # 침투(낙뢰 쿨 중)
						{"t": 14.0, "spawn": [{"enemy": "runner", "count": 4}, {"enemy": "scout", "count": 3}]},  # 절정(마지막 핀치)
					 ]},

					{"type": "boss", "base_hp": 220, "base_speed": 78, "base_damage": 20,
					 "pulses": [
						{"t": 0.0, "spawn": [{"enemy": "brute", "count": 3}]},  # 탐색
						{"t": 5.0, "spawn": [{"enemy": "brute", "count": 4}, {"enemy": "swarm", "count": 6}]},  # 빌드(보스전 압박)
					 ],
					 "boss_hp": 6000, "boss_speed": 52, "boss_damage": 18,
					 "boss_name": "정의의 용사 과장", "crown_shards": 15},
				]
			},
		]
	},
	# 챕터 2 이후 추가 예정
]

# 웨이브 데이터 반환
static func get_wave(ch: int, st: int, w: int) -> Dictionary:
	return CHAPTERS[ch]["stages"][st]["waves"][w]

# 스테이지의 웨이브 수
static func stage_wave_count(ch: int, st: int) -> int:
	return CHAPTERS[ch]["stages"][st]["waves"].size()

# 챕터의 스테이지 수
static func chapter_stage_count(ch: int) -> int:
	return CHAPTERS[ch]["stages"].size()

# 챕터 수
static func chapter_count() -> int:
	return CHAPTERS.size()

# 웨이브 총 적 수 (pulses 합, composition fallback 유지)
static func wave_enemy_count(ch: int, st: int, w: int) -> int:
	var data: Dictionary = get_wave(ch, st, w)
	var total: int = 0
	if data.has("pulses"):
		for p: Dictionary in data["pulses"]:
			for s: Dictionary in p["spawn"]:
				total += s["count"]
	elif data.has("composition"):
		for entry: Dictionary in data["composition"]:
			total += entry["count"]
	return total
