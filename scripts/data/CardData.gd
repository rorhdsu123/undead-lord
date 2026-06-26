extends Node
## 카드 / 키스톤 콘텐츠 데이터 — 카드 풀·등급·축/카테고리 맵·키스톤 효과 튜닝.
## Game.gd에서 preload 참조(`CardData.STAT_CARDS` 등). 효과 적용 로직 = Game.gd:_apply_card/_apply_keystone (Phase 3서 CardSystem으로 이동 예정).
## 카드 표시 문구는 Loc.gd `card_<id>`. 라이브 서비스: 카드 추가·풀/등급/축 조정은 이 파일 + Loc + _apply_card.

# 카드 풀 — 스킬 카드는 획득 후 제거, 스탯 카드는 계속 등장
const SKILL_CARDS: Array = []  # 패시브 거취 미정 — 보류, 풀에서 제외 (death_aura/skull_throw/decay_curse 상수 보존, 미등장)
const STAT_CARDS: Array = [
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

# 등급 가중치
const RARE_CHANCE: float = 0.3
const ALWAYS_RARE: Array[String] = ["minion_count"]
const NEVER_RARE: Array[String] = ["graveyard"]

# 카드 픽업 시각 효과: ID → 카테고리
# (보류/연기 카드: range_basic·range_all·death_aura·skull_throw·decay_curse — 풀에 없으나 엔트리 보존)
const CARD_CATEGORY_MAP: Dictionary = {
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
const CARD_AXIS: Dictionary = {
	"range_basic": "power", "range_all": "power",
	"death_aura": "power", "skull_throw": "power", "decay_curse": "power",
	"minion_count": "army", "summon_cost": "army",
	"minion_range": "army", "minion_lifesteal": "army",
	"area": "magic",
	"chain_lightning": "magic",
	"suppress": "magic",
	"wall": "neutral", "graveyard": "neutral",
	# 키스톤2 카드(중간보스 심화 화면) — 추천 판정용 축. 정규 풀엔 없고 _show_keystones로만 등장,
	# _pick_card는 keystone 분기로 early-return이라 축 카운트엔 영향 없음.
	"horde": "army", "echo": "army",
	"vulnerable": "magic", "execute": "magic",
}

# 키스톤 효과 튜닝 (마물 축)
const KEYSTONE_ECHO_RADIUS: float = 90.0
const HORDE_REFUND_BASE: float = 0.50
const HORDE_REFUND_PER_CARD: float = 0.05
