extends Node
## 상점 항목 콘텐츠 데이터.
## Game.gd에서 preload 참조(`ShopData.SHOP_ITEMS`). 효과 적용 로직 = Game.gd:_apply_shop_item (Phase 2서 ShopController로 이동 예정).
## 라이브 서비스: 상점 항목 추가·수치/가격 조정은 이 파일만 건드린다.
## ⚠️ 기존 부채: label/desc가 Loc 미경유 하드코딩 — 동작 보존 위해 현 상태 유지, Loc 이관은 별도 작업.

const SHOP_ITEMS: Array = [
	{"id": "castle_max",      "label": "성벽 증축",  "desc": "성 최대 HP +120",   "cost": 120},
	{"id": "restore",         "label": "긴급 수복",  "desc": "성·마물 즉시 완전 회복", "cost": 70},
	{"id": "lightning_dmg",   "label": "낙뢰 증폭",  "desc": "낙뢰 피해 +20%",    "cost": 110},
	{"id": "ability_cd",      "label": "마법 가속",  "desc": "마법 쿨다운 −15%",  "cost": 130},
	{"id": "ability_radius",  "label": "마법 확산",  "desc": "마법 반경 +25%",    "cost": 90},
]
