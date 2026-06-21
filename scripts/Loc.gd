extends Node

static var _strings: Dictionary = {
	# 스테이지 HUD
	"stage_label": "스테이지 %d-%d",

	# 카드 등급
	"rarity_common":    "일반",
	"rarity_legendary": "전설",

	# 카드 선택 오버레이
	"card_select_title":    "카드 선택",
	"card_select_subtitle": "카드 1장 선택",

	# 상점 오버레이
	"shop_title":    "골드 상점",
	"shop_subtitle": "다음 웨이브 전, 전력을 보강하세요",
	"shop_owned_souls": "보유 골드  ● %d",
	"shop_purchased": "✓ 구매됨",

	# 카드 이름/설명
	"card_wall":          "성벽 강화\n최대 HP +50",
	"card_graveyard":     "묘지\n웨이브 클리어 시 HP +20 회복",
	"card_range_basic":   "마법 사거리 증가\n[마법] 마법 사거리 +30",
	"card_range_all":     "마법 범위 증가\n[마법] 마법 범위 +25%",
	"card_area":         "넓은 마법\n[마법] 마법 적중 반경 +25%. 모을수록 마법 범위가 커져 더 많은 적을 덮친다",
	"card_chain_lightning": "연쇄 낙뢰\n[마법] 맞은 적과 가까운 적 1명을 감전 (피해 50%). 모을수록 감전이 사슬처럼 이어진다",
	"card_minion_count":  "소환 한도 증가\n[군대] 최대 소환 수 +1",
	"card_summon_cost":       "소환 비용 감소\n[군대] 소환 비용 -5 골드",
	"card_minion_range":      "하인 사거리 증가\n[군대] 하인 공격 사거리 +40",
	"card_minion_lifesteal":  "생명 흡수\n[군대] 하인 공격의 20% 흡혈",
	"card_death_aura":    "죽음의 오라\n[마법] 주변 적 지속 피해",
	"card_skull_throw":   "저주 해골 던지기\n[마법] 관통 투사체 발사",
	"card_decay_curse":   "부패의 저주\n[마법] 범위 내 적 슬로우",
	"card_legion":        "소환 증원\n소환 슬롯 +2. [군대] 카드를 모을수록 슬롯이 늘어난다",
	"card_horde":         "골드 환급\n하인 전사 시 고용비 50%를 골드로 환급. [군대] 카드를 모을수록 환급이 커진다",
	"card_echo":          "사망 폭발\n하인이 죽으면 폭발. [군대] 카드를 모을수록 폭발이 강해진다",
	"card_surge":         "쇄도\n모든 마법 쿨다운 -35%. [마법] 카드를 모을수록 쿨다운이 짧아진다",

	# MD12 하단 readout + MAX 배지
	"minion_readout":         "%d / %d",  # active_minions / max_minions
	"minion_cap_max":         "MAX",      # readout 우상단 캡 도달 배지

	# MD10 희생 버튼 텍스트 (1탭 자동)
	"sacrifice_btn_idle":     "희생",
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
	"doctrine_category_soul":   "골드의 율법",
	"doctrine_category_minion": "부하의 율법",
	"doctrine_category_rule":   "지배의 율법",

	# ── RD16 하인 강화 시스템 ────────────────────────────────────
	"upgrade_btn_label":      "강화",
	"upgrade_popup_title":    "강화",
	"upgrade_icon":           "▲",   # 강화 버튼 아이콘 플레이스홀더 (아트 입고 전)
	"upgrade_card_lv":        "Lv.%d",
	"upgrade_card_cost":      "● %d",
	"upgrade_card_btn":       "강화 %d골드",
	"upgrade_card_btn_broke": "강화 %d골드",
	"upgrade_minion_warrior": "전사",
	"upgrade_minion_archer":  "궁수",
	"upgrade_minion_tank":    "탱크",
	"upgrade_demon_bark":     "강화해라!",

	# ── 골드 획득 플로팅 텍스트 ─────────────────────────────────
	"gold_floater": "● +%d",

	# ── 마법(유물) 버튼 텍스트 ─────────────────────────────────
	"ability_lightning_name":  "낙뢰의 홀",
	"ability_lightning_cool":  "준비 중 (%ds)",
	"ability_lightning_desc":  "탭한 곳에 벼락을 내린다.",
	"ability_trumpet_name":    "망령의 나팔",
	"ability_trumpet_cool":    "준비 중 (%ds)",
	"ability_trumpet_desc":    "탭한 곳의 적을 위로 밀어낸다.",
	"ability_cancel":          "✕",

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
	"doctrine_soul_A_name":   "골드 비축",
	"doctrine_soul_A_desc":   "미사용 골드 일부 메타 이월",
	"doctrine_soul_B_name":   "골드 폭주",
	"doctrine_soul_B_desc":   "마법 발동 후 5초 골드 드롭 ×2",

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
