extends Node
## 소환 하인(마물) 로스터 · 고용 경제 콘텐츠 데이터.
## Game.gd에서 preload 참조(`MinionData.MINION_TYPES` 등). 스폰·강화 로직 = Game.gd (Phase 2서 MinionSystem으로 이동 예정).
## 라이브 서비스: 하인 추가·비용/강화 밸런스 조정은 이 파일만 건드린다.

## 소환 가능 하인 타입 (영혼 비용 + UI 라벨)
const MINION_TYPES: Array = [
	{"id": "warrior", "label": "전사",  "cost": 15},
	{"id": "archer",  "label": "궁수",  "cost": 25},
	{"id": "bomber",  "label": "폭탄병", "cost": 20},
	{"id": "tank",    "label": "탱크",  "cost": 35},
]

## Phase C — 라이브 골드 고용 3종 (폭탄병 제외). 인덱스는 MINION_TYPES 내 위치 대응 (warrior=0, archer=1, tank=3)
const HIRE_TYPE_INDICES: Array = [0, 1, 3]
const HIRE_START_GOLD: int = 50  # 가제 시작 골드

## RD16 — 하인 강화 (HIRE_CAP_PER_TYPE 제거 — MD12: 전역 총량 캡으로 교체)
const HIRE_UPGRADE_STAT_MULT: float = 0.25  # 가제: 레벨당 HP/공격력 +25% (밸런싱 TBD)
const HIRE_UPGRADE_COST_BASE: int = 30      # 가제: 강화 기본 비용 (Lv→Lv+1 = BASE × 현재레벨)
