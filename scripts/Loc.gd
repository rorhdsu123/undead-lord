extends Node

static var _strings: Dictionary = {
	# 카드 등급
	"rarity_common":    "일반",
	"rarity_legendary": "전설",

	# 카드 이름/설명
	"card_arsenal":       "무기고\n[영주] 공격력 +20%",
	"card_wall":          "성벽 강화\n최대 HP +50",
	"card_graveyard":     "묘지\n웨이브 클리어 시 HP +20 회복",
	"card_atk_speed":     "공격속도 강화\n[영주] 공격속도 +20%",
	"card_minion_speed":  "언데드 가속\n[군단] 하인 이동 속도 +15%",
	"card_range_basic":   "저주의 손길\n[영주] 공격 범위 +30",
	"card_range_all":     "어둠의 확장\n[영주] 전 범위 +25%",
	"card_minion_attack": "언데드 강화\n[군단] 하인 공격력 +20%",
	"card_minion_count":  "군세 확장\n[군단] 최대 소환 수 +1",
	"card_summon_speed":      "어둠의 효율\n[군단] 소환 비용 -5 영혼",
	"card_minion_hp":         "강철 골수\n[군단] 하인 최대 HP +25%",
	"card_minion_range":      "뻗는 손아귀\n[군단] 하인 공격 사거리 +40",
	"card_minion_lifesteal":  "피의 갈증\n[군단] 하인 공격의 20% 흡혈",
	"card_death_aura":    "죽음의 오라\n[영주] 주변 적 지속 피해",
	"card_skull_throw":   "저주 해골 던지기\n[영주] 관통 투사체 발사",
	"card_decay_curse":   "부패의 저주\n[영주] 범위 내 적 슬로우",
	"card_kingdom":       "군림\n영주 공격 +30%. [영주] 카드를 모을수록 강해진다",
	"card_legion":        "언데드 군단\n소환 슬롯 +2. [군단] 카드를 모을수록 하인이 강해진다",
	"card_berserker":     "광전사\n공격 속도 +50%. [영주] 카드를 모을수록 공격이 강해진다",
	"card_cataclysm":     "재앙의 권화\n모든 범위 +40%. [영주] 카드를 모을수록 위력이 커진다",
	"card_doom":          "파멸의 일격\n특수기 영혼 비용 −30%. [영주] 카드를 모을수록 특수기가 강해진다",
	"card_horde":         "영원한 군세\n하인 사망 시 재소환. [군단] 카드를 모을수록 부활이 강해진다",
	"card_echo":          "죽음의 메아리\n하인이 죽으면 폭발. [군단] 카드를 모을수록 폭발이 강해진다",
}

static func t(key: String) -> String:
	if key in _strings:
		return _strings[key]
	push_warning("Loc: missing key '%s'" % key)
	return key
