extends Node

static var _strings: Dictionary = {
	# 스테이지 HUD
	"stage_label": "스테이지 %d-%d",

	# 카드 등급
	"rarity_common":    "일반",
	"rarity_legendary": "전설",
	"rarity_keystone":  "각성",

	# 카드 선택 오버레이
	"card_select_title":    "카드 선택",
	"card_select_subtitle": "카드 1장 선택",

	# 상점 오버레이
	"shop_title":    "영혼 상점",
	"shop_subtitle": "다음 웨이브 전, 전력을 보강하세요",
	"shop_owned_souls": "보유 영혼  ◆ %d",

	# 카드 이름/설명
	"card_arsenal":       "무기고\n[영주] 공격력 +20%",
	"card_wall":          "성벽 강화\n최대 HP +50",
	"card_graveyard":     "묘지\n웨이브 클리어 시 HP +20 회복",
	"card_atk_speed":     "공격속도 강화\n[영주] 공격속도 +20%",
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
	"card_ritual":        "제물의 의식\n하인을 희생하면 같은 하인을 즉시 무료로 다시 소환한다. [군단] 카드를 모을수록 희생 폭발이 강해진다",

	# 희생 버튼 텍스트
	"sacrifice_btn_idle":     "희생",
	"sacrifice_btn_armed":    "취소",
	"sacrifice_btn_locked":   "희생 (잠금)",
	"sacrifice_btn_cooldown": "희생 (%ds)",

	# ── 위엄(Majesty) 시스템 ───────────────────────────────────
	# HUD
	"majesty_lv":             "위엄 Lv %d",
	"majesty_max":            "위엄 MAX",

	# 알현실 거점
	"throne_room_label":      "알현실",

	# 알현 오버레이 — 버튼
	"court_btn_available":    "알현하다",
	"court_btn_done":         "오늘의 알현 완료 — 내일 다시",

	# 알현 레벨업
	"majesty_levelup":        "위엄이 깊어졌습니다.",
	"majesty_levelup_en":     "Your Majesty deepens.",

	# 해제권
	"unlock_credits_label":   "해제권 %d",

	# 전투 결과 위엄 EXP
	"majesty_exp_gain":       "위엄 +%d",

	# ── 교리(Doctrine) — 카테고리 이름 ───────────────────────
	"doctrine_category_death":  "죽음의 율법",
	"doctrine_category_war":    "전쟁의 율법",
	"doctrine_category_soul":   "영혼의 율법",
	"doctrine_category_minion": "부하의 율법",
	"doctrine_category_rule":   "지배의 율법",

	# ── 교리 — 선택지 이름 + 설명 ────────────────────────────
	# 죽음의 율법
	"doctrine_death_A_name":  "처형",
	"doctrine_death_A_desc":  "처치 시 1초 내 가까운 적 연쇄 즉사",
	"doctrine_death_B_name":  "자비",
	"doctrine_death_B_desc":  "적 일부 도주, 다음 웨이브 약화",

	# 전쟁의 율법
	"doctrine_war_A_name":    "전선 사수",
	"doctrine_war_A_desc":    "적이 성에 가까울수록 영주 공격력↑",
	"doctrine_war_B_name":    "기동전",
	"doctrine_war_B_desc":    "영주 기본공격이 방향성을 가짐",

	# 영혼의 율법
	"doctrine_soul_A_name":   "영혼 비축",
	"doctrine_soul_A_desc":   "미사용 영혼 일부 메타 이월",
	"doctrine_soul_B_name":   "영혼 폭주",
	"doctrine_soul_B_desc":   "특수기 후 5초 영혼 드롭 ×2",

	# 부하의 율법
	"doctrine_minion_A_name": "명예",
	"doctrine_minion_A_desc": "해골 사망 시 유령으로 5초 잔존",
	"doctrine_minion_B_name": "소모",
	"doctrine_minion_B_desc": "해골 사망 시 주변 적 폭발",

	# 지배의 율법
	"doctrine_rule_A_name":   "카리스마",
	"doctrine_rule_A_desc":   "시야 내 하인 공격속도 ×2",
	"doctrine_rule_B_name":   "공포",
	"doctrine_rule_B_desc":   "보스 제외 적 패닉 (무작위 정지)",
}

static func t(key: String) -> String:
	if key in _strings:
		return _strings[key]
	push_warning("Loc: missing key '%s'" % key)
	return key
