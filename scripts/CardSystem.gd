extends Node
## 카드 / 키스톤 도메인 컨트롤러 — 카드 뽑기·키스톤 선택·효과 적용·카드 뷰 (Phase 2 #2, 핫존).
## 데이터 = CardData.gd. 공유 run-state(castle·keystone·effect 수치 전부)는 Game 소유 → game 역참조로 쓰기(GS2).
## 효과 결과(vulnerability_amount·execution_threshold·keystone_echo_dmg·ability_*_card_mult 등)는
## Enemy/Boss/AbilitySystem이 game.X로 읽음(불변). Game._ready서 new → add_child → setup(self).
## 외부 진입점: _show_cards() · _show_keystones(ids, axis_pick).

const CardData = preload("res://scripts/data/CardData.gd")
const MinionData = preload("res://scripts/data/MinionData.gd")

var game: Node = null  # Game.gd 허브 역참조

# 카드-로컬 상태
var available_skill_cards: Array = []
var current_cards: Array = []
var _card_rows: Array = []
var _value_re: RegEx = null  # 카드 수치 강조용 정규식 (lazy compile)
var _shown_recommend_hint: bool = false  # 런 내 추천 배지 튜토 힌트 1회 표시 여부 (영구 저장 안 함)

func setup(g: Node) -> void:
	game = g
	available_skill_cards = CardData.SKILL_CARDS.duplicate()

func _show_cards() -> void:
	# 강화 팝업이 열린 채 웨이브가 끝나면, 그 입력 캐처(move_to_front로 최상단)가
	# 카드 패널 위에 남아 카드 탭을 가로챈다 → 팝업을 닫지 말고 모달 레이어를
	# 다시 끌어올려 카드 패널이 입력 우선권을 갖게 한다(전화면 STOP 패널이라 탭 흡수).
	game._raise_modal_layers()
	for n: Node in _card_rows:
		if is_instance_valid(n):
			n.queue_free()
	_card_rows.clear()

	game.card_title.text = Loc.t("card_select_title")
	game.card_subtitle.text = Loc.t("card_select_subtitle")

	var pool: Array = available_skill_cards.duplicate()
	for stat_card: Dictionary in CardData.STAT_CARDS:
		pool.append(stat_card)

	# 죽은 카드 가드: 가장 싼 하인이 비용 바닥(5)에 닿으면 소환 비용 카드 제외.
	# 탱크 등 비싼 하인은 더 깎일 여지가 있으나, "이미 바닥인데 또 뜨네?"라는
	# 버그 같은 오해를 막으려 보수적으로 일찍 숨긴다.
	var min_minion_cost: int = 0
	for mt: Dictionary in MinionData.MINION_TYPES:
		var mc: int = int(mt["cost"])
		min_minion_cost = mc if min_minion_cost == 0 else min(min_minion_cost, mc)
	if game.minion_cost_reduction >= min_minion_cost - 5:
		pool = pool.filter(func(c: Dictionary) -> bool: return c["id"] != "summon_cost")

	# 온보딩 카드 풀 게이팅: taught_horn 전(1-2 이전)엔 통제형 카드 제외
	var control_unlocked: bool = (game.current_stage >= 2) or GameSave.taught_horn
	if not control_unlocked:
		pool = pool.filter(func(c: Dictionary) -> bool: return c.get("alignment", "") != "통제")
	# 낙뢰(마법) 학습 전(1-1 W3 이전)엔 마법 카드(연쇄낙뢰·넓은 마법·제압 등) 제외
	if not game._is_lightning_available():
		pool = pool.filter(func(c: Dictionary) -> bool: return not c.get("magic", false))

	pool.shuffle()

	# 교습 화면 = 1-1 축 선택 직후 첫 카드 화면(추천 큐레이션·힌트가 뜨는 1회).
	var teaching_screen: bool = game._is_tutorial() and game.keystone1 != "" and not _shown_recommend_hint

	# 튜토리얼 교습 큐레이션 (1회): 추천 카드가 0장이면 교습이 다음 스테이지로 밀리고,
	# 2장 이상이면 힌트가 모호해지는 문제를 "추천 1 + 반대 축 1 + 중립 1" 비교군으로 해결.
	# 교습이 뜬 후(_shown_recommend_hint = true)엔 적용 안 함 → 순수 랜덤 복귀.
	if teaching_screen:
		var chosen_axis: String = "army" if game.keystone1 == "legion" else "magic"
		var other_axis: String = "magic" if chosen_axis == "army" else "army"
		var curated: Array = []
		var used_ids: Array = []
		var slot_axes: Array = [chosen_axis, other_axis, "neutral"]
		for slot_axis in slot_axes:
			for c: Dictionary in pool:
				var c_axis: String = CardData.CARD_AXIS.get(c["id"], "neutral")
				if c_axis == slot_axis and not used_ids.has(c["id"]):
					curated.append(c)
					used_ids.append(c["id"])
					break
		# 못 채운 슬롯은 남은 풀에서 임의로 채움 (방어적 폴백)
		if curated.size() < 3:
			for c: Dictionary in pool:
				if curated.size() >= 3:
					break
				if not used_ids.has(c["id"]):
					curated.append(c)
					used_ids.append(c["id"])
		# 추천 카드는 맨 위 고정(말풍선이 카드 위 제목 영역에 떠 다른 카드를 안 가림),
		# 나머지 두 장만 순서 셔플. curated[0] = chosen_axis 슬롯 = 추천 카드.
		if curated.size() == 3:
			var bottom_two: Array = [curated[1], curated[2]]
			bottom_two.shuffle()
			curated = [curated[0], bottom_two[0], bottom_two[1]]
		# curated 3장을 pool 앞에 재배치 → 기존 pool.slice(0, 3) 로직이 그대로 집도록
		var remaining: Array = pool.filter(func(c: Dictionary) -> bool: return not used_ids.has(c["id"]))
		pool = curated + remaining

	var skill_ids: Array = CardData.SKILL_CARDS.map(func(c: Dictionary) -> String: return c["id"])
	current_cards = []
	for c: Dictionary in pool.slice(0, 3):
		var card: Dictionary = {"id": c["id"]}
		if skill_ids.has(c["id"]) or CardData.ALWAYS_RARE.has(c["id"]):
			card["rare"] = true
		elif CardData.NEVER_RARE.has(c["id"]):
			card["rare"] = false
		else:
			card["rare"] = randf() < CardData.RARE_CHANCE
		current_cards.append(card)

	var card_h: float = 120.0
	var gap: float = 10.0
	# 교습 화면은 카드를 약간 아래로 — 추천 카드(맨 위) 위에 뜨는 말풍선이 타이틀과 안 겹치게
	var start_y: float = 280.0 if teaching_screen else 250.0
	for i: int in 3:
		var row: Control = _build_card_row(current_cards[i], i, start_y + float(i) * (card_h + gap))
		game.card_panel.add_child(row)
		_card_rows.append(row)
		if current_cards[i]["rare"]:
			_flash_card_glow(row)

	game._set_modal_dim(true)
	game.card_panel.visible = true

	# 추천 배지 튜토 힌트 (1-1 1회): _is_tutorial()(1-1 한정) + 축 선택됨 + 추천 카드 있음.
	# current_chapter==0(Ch1 전체)로 잡으면 스테이지 전환 씬 reload로 플래그가 리셋돼 1-2에서 재노출됨
	# → 1-1 한정 게이트로 1회 보장. (배지 _is_recommended는 Ch1 전체 유지 — 말풍선만 1-1로 분리)
	if not _shown_recommend_hint and game._is_tutorial() and game.keystone1 != "":
		for i: int in current_cards.size():
			if _is_recommended(current_cards[i]["id"]) and i < _card_rows.size():
				# 추천 카드가 맨 위(i=0)라 말풍선이 제목/부제 영역에 뜸 → 부제를 비워 텍스트 안 가리게
				game.card_subtitle.text = ""
				# duration 0 = 자동 사라짐 없이 카드를 고를 때까지 유지(_pick_card의 _close_guide가 닫음)
				# dim=false = 다른 카드를 어둡게 하지 않음("추천일 뿐 강요 아님" — 3장 다 동등하게 보이게)
				game.show_tutorial_tip(Loc.t("card_recommend_hint"), _card_rows[i], 0.0, Rect2(), false)
				_shown_recommend_hint = true
				break

func _pick_card(index: int) -> void:
	game._close_guide()
	var card: Dictionary = current_cards[index]
	if card.get("keystone", false):
		_apply_keystone(card["id"])
		game.card_panel.visible = false
		game._set_modal_dim(false)
		game._spawn_card_pickup_effect(card["id"])
		game.current_wave += 1
		game.start_wave()
		return
	var mult: float = 1.5 if card.get("rare", false) else 1.0
	_apply_card(card["id"], mult)

	for i in available_skill_cards.size():
		if available_skill_cards[i]["id"] == card["id"]:
			available_skill_cards.remove_at(i)
			break

	# 축 카운트 증가 (일반 카드만)
	var axis: String = CardData.CARD_AXIS.get(card["id"], "neutral")
	if axis == "power":
		game.power_card_count += 1
	elif axis == "army":
		game.army_card_count += 1
		# legion 캡 스케일: [마물] 카드 획득마다 소환 슬롯 +1
		if game.keystone1 == "legion":
			game.max_minions += 1
			game._update_minion_readout()
			game._refresh_summon_buttons()
	elif axis == "magic":
		game.magic_card_count += 1
	_recompute_keystones()

	game.card_panel.visible = false
	game._set_modal_dim(false)
	game._spawn_card_pickup_effect(card["id"])
	game.current_wave += 1
	game.start_wave()

func _recompute_keystones() -> void:
	# 기본값 리셋 (보류 트랙 변수 포함 — Player/특수기/희생 시스템이 참조)
	game.keystone_lord_atk_mult = 1.0
	game.keystone_minion_atk_mult = 1.0
	game.keystone_revive_chance = 0.0
	game.keystone_echo_dmg = 0.0
	game.keystone_sacrifice_dmg_mult = 1.0
	game.keystone_sacrifice_radius_mult = 1.0
	game.keystone_sacrifice_refill = false
	game.ability_cooldown_card_mult = 1.0
	game.vulnerability_amount = 0.0
	game.execution_threshold = 0.0
	# game.keystone1: legion만 활성 (kingdom 제거됨)
	# game.keystone2: echo만 스케일 설정 (horde 환급은 minion_died에서 실시간 계산)
	#            vulnerable/execute는 여기서 파생 수치 계산
	match game.keystone2:
		"echo":
			game.keystone_echo_dmg = 20.0 * (1.0 + 0.10 * float(game.army_card_count))
		"vulnerable":
			game.vulnerability_amount = min(0.25 + 0.05 * float(game.magic_card_count), 0.50)
		"execute":
			game.execution_threshold = min(0.15 + 0.03 * float(game.magic_card_count), 0.25)
	# game.keystone1: 쇄도 = [마법] 카드 수에 비례한 쿨다운 감소 (echo처럼 파생 곱으로 재계산)
	if game.keystone1 == "surge":
		var reduction: float = min(0.35 + 0.05 * float(game.magic_card_count), 0.60)
		game.ability_cooldown_card_mult = 1.0 - reduction

func _apply_keystone(id: String) -> void:
	match id:
		"legion":
			game.keystone1 = "legion"
			game.max_minions += 2
			game._update_minion_readout()
			game._refresh_summon_buttons()
		"surge":
			game.keystone1 = "surge"
		"horde":
			game.keystone2 = "horde"
		"echo":
			game.keystone2 = "echo"
		"vulnerable":
			game.keystone2 = "vulnerable"
		"execute":
			game.keystone2 = "execute"
	_recompute_keystones()

## 키스톤 선택 화면.
## axis_pick=true(W1 축 선언) → 전용 「전투 전략」 2열 갈림 화면.
## axis_pick=false(중간보스 #2 심화) → 일반 카드 UI(키스톤 2장 + 필러 1장, 3개중 1택).
func _show_keystones(ids: Array, axis_pick: bool = false) -> void:
	# 카드 화면과 동일 — 모달 레이어를 끌어올려 강화 캐처보다 카드 패널이 입력 우선.
	game._raise_modal_layers()
	for n: Node in _card_rows:
		if is_instance_valid(n):
			n.queue_free()
	_card_rows.clear()

	if axis_pick:
		# W1 축 선언 — 전용 2열 갈림 화면
		game.card_title.text = Loc.t("keystone_select_title")
		game.card_subtitle.text = Loc.t("keystone_select_subtitle")
		current_cards = []
		for id: String in ids:
			current_cards.append({"id": id, "rare": true, "keystone": true})
		var col_w: float = 218.0
		var gap: float = 16.0
		var card_y: float = 340.0
		var total: float = col_w * float(current_cards.size()) + gap * float(current_cards.size() - 1)
		var x0: float = (480.0 - total) * 0.5
		for i: int in current_cards.size():
			var x: float = x0 + float(i) * (col_w + gap)
			var row: Control = _build_keystone_card(current_cards[i], i, x, card_y, col_w)
			game.card_panel.add_child(row)
			_card_rows.append(row)
			_flash_card_glow(row)
		game._set_modal_dim(true)
		game.card_panel.visible = true
		return

	# 중간보스 #2 — 일반 카드 UI(키스톤 2장 + 필러 스탯 1장)
	game.card_title.text = Loc.t("card_select_title")
	game.card_subtitle.text = Loc.t("card_select_subtitle")
	current_cards = []
	for id: String in ids:
		current_cards.append({"id": id, "rare": true, "keystone": true})
	var stat_pool: Array = CardData.STAT_CARDS.duplicate()
	stat_pool.shuffle()
	current_cards.append({"id": stat_pool[0]["id"], "rare": false})

	var card_h: float = 120.0
	var gap2: float = 10.0
	var start_y: float = 250.0
	for i: int in current_cards.size():
		var row: Control = _build_card_row(current_cards[i], i, start_y + float(i) * (card_h + gap2))
		game.card_panel.add_child(row)
		_card_rows.append(row)
		if current_cards[i].get("rare", false):
			_flash_card_glow(row)

	game._set_modal_dim(true)
	game.card_panel.visible = true

## 추천 판정: W1에서 고른 축(keystone1)과 카드 축이 일치하면 true.
## neutral 카드는 어느 축과도 일치하지 않아 항상 false.
## 튜토리얼(Ch1, current_chapter == 0) 한정 — 실전에선 빌드 결정을 온전히 플레이어에게 맡긴다.
func _is_recommended(id: String) -> bool:
	if game.current_chapter != 0:
		return false
	var chosen: String = ""
	if game.keystone1 == "legion":
		chosen = "army"
	elif game.keystone1 == "surge":
		chosen = "magic"
	if chosen == "":
		return false
	return CardData.CARD_AXIS.get(id, "neutral") == chosen

func _card_name(id: String) -> String:
	var full: String = Loc.t("card_%s" % id)
	var nl: int = full.find("\n")
	return full.substr(0, nl) if nl >= 0 else full

func _card_desc(card: Dictionary) -> String:
	# {val} 치환은 _build_card_row에서 _format_axis_tags 이후에 수행(동적 값은 코드에서 직접 빨강 칠함 → 정규식 이중처리 방지)
	var full: String = Loc.t("card_%s" % card["id"])
	var nl: int = full.find("\n")
	return full.substr(nl + 1) if nl >= 0 else ""

## 동적 미리보기 숫자 1개를 빨강으로 감싼다. (단위 글자·화살표는 호출부에서 밖에 두어 검정 유지)
func _hl(s: String) -> String:
	return "[color=#cc2222]%s[/color]" % s

## 동적 미리보기: 반복 획득 스탯 카드의 "현재값 → 다음값" 표기(첫 픽=얻는 값만).
## rare면 증가폭 ×1.5(_pick_card mult와 일치). 단 minion_count/chain은 _apply_card가 mult 무시(+1 고정).
## 숫자는 _hl로 직접 빨강 처리(plain 정수도 강조되도록). 비대상이면 "".
func _card_value_preview(id: String, rare: bool) -> String:
	var mult: float = 1.5 if rare else 1.0
	match id:
		"minion_lifesteal":
			var cur: int = int(round(game.minion_lifesteal * 100.0))
			var nxt: int = int(round((game.minion_lifesteal + 0.20 * mult) * 100.0))
			return _hl("%d%%" % nxt) if cur == 0 else _hl("%d%%" % cur) + " → " + _hl("%d%%" % nxt)
		"minion_range":
			var cur: int = int(round(game.minion_range_bonus))
			var nxt: int = int(round(game.minion_range_bonus + 40.0 * mult))
			return _hl("+%d" % nxt) if cur == 0 else _hl("+%d" % cur) + " → " + _hl("+%d" % nxt)
		"area":
			var cur: int = int(round((game.ability_radius_card_mult - 1.0) * 100.0))
			var nxt: int = int(round((game.ability_radius_card_mult - 1.0 + 0.25 * mult) * 100.0))
			return _hl("+%d%%" % nxt) if cur == 0 else _hl("+%d%%" % cur) + " → " + _hl("+%d%%" % nxt)
		"graveyard":
			var cur: int = game.graveyard_heal
			var nxt: int = cur + int(20 * mult)
			return _hl("%d" % nxt) if cur == 0 else _hl("%d" % cur) + " → " + _hl("%d" % nxt)
		"chain_lightning":
			var cur: int = game.chain_lightning_targets
			var nxt: int = cur + 1
			return _hl("%d" % nxt) if cur == 0 else _hl("%d" % cur) + " → " + _hl("%d" % nxt)
		"summon_cost":
			# 누적 총액이 아니라 이 카드가 깎는 양(고정 증가폭)만 표기 — 항상 "5 골드 감소"(전설 7)
			return _hl("%d" % int(5 * mult))
		"minion_count":
			var cur: int = game.max_minions
			return _hl("%d" % cur) + " → " + _hl("%d" % (cur + 1))
		"wall":
			var cur: int = game.castle_max_hp
			return _hl("%d" % cur) + " → " + _hl("%d" % (cur + int(50 * mult)))
		"suppress":
			if game.suppress_duration >= 2.0:
				return _hl("2.0") + "초 (최대)"
			var nxt_d: float = minf(game.suppress_duration + 0.5, 2.0)
			var cap: String = " (최대)" if nxt_d >= 2.0 else ""
			if game.suppress_duration == 0.0:
				return _hl("%.1f" % nxt_d) + "초" + cap
			return _hl("%.1f" % game.suppress_duration) + "초 → " + _hl("%.1f" % nxt_d) + "초" + cap
	return ""


func _format_axis_tags(s: String) -> String:
	# 수치 강조: 부호(+/-)나 % 붙은 값만 빨강. ([b] 볼드는 폰트 메트릭 차이로 baseline이 어긋나 제외 — 색만으로 강조)
	# 축 태그 치환 *전*에 적용 — 치환이 삽입하는 색 hex(#7b4fc9 등)의 숫자가 오염되지 않도록.
	if _value_re == null:
		_value_re = RegEx.new()
		_value_re.compile("([+\\-]?\\d+(?:\\.\\d+)?%|[+\\-]\\d+(?:\\.\\d+)?)")
	s = _value_re.sub(s, "[color=#cc2222]$1[/color]", true)
	s = s.replace("[마법]", "[color=#7b4fc9][lb]마법[rb][/color]")
	s = s.replace("[마물]", "[color=#0a7d6b][lb]마물[rb][/color]")
	return s

func _build_card_row(card: Dictionary, index: int, y_pos: float) -> Control:
	var is_rare: bool = card.get("rare", false)
	var bg_col: Color    = Color(0.97, 0.93, 0.82, 1.0) if is_rare else Color(0.91, 0.89, 0.97, 1.0)
	var border_col: Color = Color(0.88, 0.62, 0.08, 1.0) if is_rare else Color(0.48, 0.40, 0.75, 1.0)
	var badge_col: Color  = Color(0.88, 0.52, 0.04, 1.0) if is_rare else Color(0.50, 0.42, 0.76, 1.0)
	var art_col: Color    = Color(0.18, 0.11, 0.04, 1.0) if is_rare else Color(0.12, 0.08, 0.20, 1.0)
	var name_col: Color   = Color(0.13, 0.08, 0.05, 1.0)
	var desc_col: Color   = Color(0.35, 0.30, 0.28, 1.0)

	var card_w: float  = 444.0
	var card_h: float  = 120.0
	var art_sz: float  = 96.0
	var art_x: float   = 10.0
	var art_y: float   = 12.0
	var badge_w: float = 54.0
	var badge_h: float = 22.0
	var right_x: float = art_x + art_sz + 12.0
	var right_w: float = card_w - right_x - 8.0

	var root: Control = Control.new()
	root.position = Vector2(8.0, y_pos)
	root.size = Vector2(card_w, card_h)

	var bg: Panel = Panel.new()
	bg.size = Vector2(card_w, card_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = bg_col
	bg_style.set_border_width_all(2)
	bg_style.border_color = border_col
	bg_style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", bg_style)
	root.add_child(bg)

	var art: Panel = Panel.new()
	art.position = Vector2(art_x, art_y)
	art.size = Vector2(art_sz, art_sz)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_style: StyleBoxFlat = StyleBoxFlat.new()
	art_style.bg_color = art_col
	art_style.set_border_width_all(3)
	art_style.border_color = border_col
	art_style.set_corner_radius_all(6)
	art.add_theme_stylebox_override("panel", art_style)
	root.add_child(art)

	var badge_x: float = art_x + (art_sz - badge_w) * 0.5
	var badge_y: float = art_y - badge_h * 0.5
	var badge_bg: Panel = Panel.new()
	badge_bg.position = Vector2(badge_x, badge_y)
	badge_bg.size = Vector2(badge_w, badge_h)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = badge_col
	badge_style.set_border_width_all(1)
	badge_style.border_color = Color(1, 1, 1, 0.35)
	badge_style.set_corner_radius_all(11)
	badge_bg.add_theme_stylebox_override("panel", badge_style)
	root.add_child(badge_bg)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = Loc.t("rarity_legendary") if is_rare else Loc.t("rarity_common")
	badge_lbl.position = Vector2(badge_x, badge_y)
	badge_lbl.size = Vector2(badge_w, badge_h)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge_lbl)

	# 추천 배지 여부 — 이름 라벨 폭 조정 + pill 표시에 사용
	var is_rec: bool = _is_recommended(card["id"])

	var name_lbl: Label = Label.new()
	name_lbl.text = _card_name(card["id"])
	name_lbl.position = Vector2(right_x, 16.0)
	# 추천 pill(폭 50 + 여백 8 + 간격 4 = 62) 공간 확보: 겹침 방지
	name_lbl.size = Vector2(right_w - (62.0 if is_rec else 0.0), 34.0)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", name_col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	var desc: String = _card_desc(card)
	if desc != "":
		var desc_lbl: RichTextLabel = RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.fit_content = true
		desc_lbl.scroll_active = false
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.position = Vector2(right_x, 54.0)
		desc_lbl.size = Vector2(right_w, 58.0)
		desc_lbl.add_theme_font_size_override("normal_font_size", 14)
		desc_lbl.add_theme_color_override("default_color", desc_col)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var formatted: String = _format_axis_tags(desc)
		if formatted.find("{val}") >= 0:
			formatted = formatted.replace("{val}", _card_value_preview(card["id"], card.get("rare", false)))
		desc_lbl.text = formatted
		root.add_child(desc_lbl)

	# 추천 리본 — 우상단 안쪽(레퍼런스 색감). 코랄 레드 + 흰 글씨 + 밝은 외곽선.
	# 카드 밖으로 돌출시키면 튜토 노란 테두리(상위 CanvasLayer)가 가로지르므로 카드 안쪽에 둠.
	# btn보다 먼저 add_child (btn이 맨 위 레이어 유지)
	if is_rec:
		var rec_pw: float = 56.0
		var rec_ph: float = 26.0
		var rec_px: float = card_w - rec_pw - 6.0   # 우측 안쪽 여백 6px
		var rec_py: float = 6.0                     # 카드 안쪽 상단
		var rec_bg: Panel = Panel.new()
		rec_bg.position = Vector2(rec_px, rec_py)
		rec_bg.size = Vector2(rec_pw, rec_ph)
		rec_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rec_style: StyleBoxFlat = StyleBoxFlat.new()
		rec_style.bg_color = Color("#e85c52")       # 코랄 레드(레퍼런스)
		rec_style.set_corner_radius_all(8)
		rec_style.set_border_width_all(2)
		rec_style.border_color = Color(1.0, 0.95, 0.92, 0.9)  # 밝은 외곽선(스티커 느낌)
		rec_bg.add_theme_stylebox_override("panel", rec_style)
		root.add_child(rec_bg)
		var rec_lbl: Label = Label.new()
		rec_lbl.text = Loc.t("card_recommend")
		rec_lbl.position = Vector2(rec_px, rec_py)
		rec_lbl.size = Vector2(rec_pw, rec_ph)
		rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rec_lbl.add_theme_font_size_override("font_size", 14)
		rec_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		rec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rec_lbl)

	var btn: Button = Button.new()
	btn.size = Vector2(card_w, card_h)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	var idx: int = index
	btn.pressed.connect(func(): _pick_card(idx))
	root.add_child(btn)

	return root

func _build_keystone_card(card: Dictionary, index: int, x_pos: float, y_pos: float, col_w: float) -> Control:
	var id: String = card["id"]
	var axis: String = "magic" if id in ["surge", "vulnerable", "execute"] else "army"
	var axis_label: String = "마법" if axis == "magic" else "마물"
	var axis_col: Color = Color("#7b4fc9") if axis == "magic" else Color("#0a7d6b")

	var parts: PackedStringArray = Loc.t("card_%s" % id).split("\n")
	var card_name: String = parts[0] if parts.size() > 0 else id
	# Loc는 \n을 name/effect/synergy 필드 구분자로 쓰므로, 필드 내부 수동 줄바꿈은 '|' 마커 → 여기서 \n으로 치환
	var card_effect: String = (parts[1] if parts.size() > 1 else "").replace("|", "\n")
	var card_synergy: String = (parts[2] if parts.size() > 2 else "").replace("|", "\n")

	var card_h: float = 324.0

	var root: Control = Control.new()
	root.position = Vector2(x_pos, y_pos)
	root.size = Vector2(col_w, card_h)

	# 배경 패널 — 축 색 틴트
	var bg: Panel = Panel.new()
	bg.size = Vector2(col_w, card_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = axis_col.lerp(Color.WHITE, 0.86)
	bg_style.set_border_width_all(3)
	bg_style.border_color = axis_col
	bg_style.set_corner_radius_all(10)
	bg.add_theme_stylebox_override("panel", bg_style)
	root.add_child(bg)

	# 축 배지 (pill)
	var pill_w: float = 74.0
	var pill_h: float = 28.0
	var pill_x: float = (col_w - pill_w) * 0.5
	var pill_y: float = -pill_h * 0.5  # 카드 상단 테두리에 탭처럼 반쯤 걸침
	var pill_bg: Panel = Panel.new()
	pill_bg.position = Vector2(pill_x, pill_y)
	pill_bg.size = Vector2(pill_w, pill_h)
	pill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = axis_col
	pill_style.set_corner_radius_all(13)
	pill_bg.add_theme_stylebox_override("panel", pill_style)
	root.add_child(pill_bg)

	var pill_lbl: Label = Label.new()
	pill_lbl.text = axis_label
	pill_lbl.position = Vector2(pill_x, pill_y)
	pill_lbl.size = Vector2(pill_w, pill_h)
	pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_lbl.add_theme_font_size_override("font_size", 15)
	pill_lbl.add_theme_color_override("font_color", Color.WHITE)
	pill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill_lbl)

	# 이름 라벨 (위)
	var name_lbl: Label = Label.new()
	name_lbl.text = card_name
	name_lbl.position = Vector2(0.0, 22.0)
	name_lbl.size = Vector2(col_w, 32.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.13, 0.08, 0.05))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# 아이콘 네모박스 (중간) — 일반 카드 art 박스와 동일 규격(96×96), 테두리만 축 색. 임시 플레이스홀더(아트 입고 시 교체)
	var icon_sz: float = 96.0
	var icon_box: Panel = Panel.new()
	icon_box.position = Vector2((col_w - icon_sz) * 0.5, 60.0)
	icon_box.size = Vector2(icon_sz, icon_sz)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.18, 0.11, 0.04, 1.0)
	icon_style.set_border_width_all(3)
	icon_style.border_color = axis_col
	icon_style.set_corner_radius_all(6)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	root.add_child(icon_box)

	# 핵심효과 라벨 (아이콘 아래) — 수치 강조(빨강) 위해 RichText
	# AUTOWRAP_WORD(공백 단위)로 한국어 단어 중간 분리 방지 — "감소" 등이 통째로 다음 줄로
	var effect_lbl: RichTextLabel = RichTextLabel.new()
	effect_lbl.bbcode_enabled = true
	effect_lbl.fit_content = true
	effect_lbl.scroll_active = false
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	effect_lbl.position = Vector2(8.0, 166.0)
	effect_lbl.size = Vector2(col_w - 16.0, 44.0)
	effect_lbl.add_theme_font_size_override("normal_font_size", 18)
	effect_lbl.add_theme_color_override("default_color", Color(0.15, 0.12, 0.10))
	effect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_lbl.text = "[center]%s[/center]" % _format_axis_tags(card_effect)
	root.add_child(effect_lbl)

	# 시너지 RichTextLabel (아래)
	if card_synergy != "":
		# "성장" 섹션 헤더 — 효과(즉시)와 시너지(성장) 구분
		var grow_lbl: Label = Label.new()
		grow_lbl.text = "성장"
		grow_lbl.position = Vector2(0.0, 238.0)
		grow_lbl.size = Vector2(col_w, 18.0)
		grow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grow_lbl.add_theme_font_size_override("font_size", 12)
		grow_lbl.add_theme_color_override("font_color", axis_col)
		grow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(grow_lbl)

		var synergy_col: Color = Color(0.40, 0.37, 0.35)
		var syn_lbl: RichTextLabel = RichTextLabel.new()
		syn_lbl.bbcode_enabled = true
		syn_lbl.fit_content = true
		syn_lbl.scroll_active = false
		syn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		syn_lbl.position = Vector2(16.0, 264.0)
		syn_lbl.size = Vector2(col_w - 32.0, 50.0)
		syn_lbl.add_theme_font_size_override("normal_font_size", 14)
		syn_lbl.add_theme_color_override("default_color", synergy_col)
		syn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		syn_lbl.text = "[center]%s[/center]" % _format_axis_tags(card_synergy)
		root.add_child(syn_lbl)
		# 시너지 1줄/2줄 줄 수가 달라도 좌우 카드가 균형 잡히도록 영역 중심에 수직 정렬.
		_vcenter_richtext.call_deferred(syn_lbl, 286.0)

	# 투명 버튼 (탭 입력 수신)
	var btn: Button = Button.new()
	btn.size = Vector2(col_w, card_h)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	var idx: int = index
	btn.pressed.connect(func(): _pick_card(idx))
	root.add_child(btn)

	return root

func _vcenter_richtext(lbl: RichTextLabel, center_y: float) -> void:
	# RichTextLabel은 수직 정렬 속성이 없어, 렌더된 콘텐츠 높이를 측정해 지정 중심에 맞춘다.
	if is_instance_valid(lbl):
		lbl.position.y = center_y - lbl.get_content_height() * 0.5

func _flash_card_glow(row: Control) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(row, "modulate", Color(1.6, 1.35, 0.5, 1), 0.12)
	tween.tween_property(row, "modulate", Color(1.0, 1.0, 1.0, 1), 0.35)

## C. 상점 구매 성공 시 버튼에 짧은 골드 플래시 (_flash_card_glow 톤 참고)
func _apply_card(id: String, mult: float = 1.0) -> void:
	# Phase A2 — 패시브 3종(death_aura/skull_throw/decay_curse) 대입 무력화
	# Player._physics_process가 이미 early-return으로 막혀 있으나 상태 변수도 설정 안 함
	# 복원: 아래 Phase A 가드 블록을 제거하면 됨
	const _PHASE_A_PASSIVE_IDS: Array = ["death_aura", "skull_throw", "decay_curse"]
	if _PHASE_A_PASSIVE_IDS.has(id):
		return  # Phase A: 패시브 카드 효과 비활성
	match id:
		"death_aura":
			game.player.has_death_aura = true
		"skull_throw":
			game.player.has_skull_throw = true
		"decay_curse":
			game.player.has_decay_curse = true
		"wall":
			var hp_gain: int = int(50 * mult)
			game.castle_max_hp += hp_gain
			game.castle_hp += hp_gain
			game.castle_bar.set_hp(game.castle_hp, game.castle_max_hp)
			game.castle_vis.set_hp_ratio(float(game.castle_hp) / float(game.castle_max_hp))
			game._update_demon_danger()
		"graveyard":
			game.graveyard_heal += int(20 * mult)
		"minion_count":
			game.max_minions += 1
			game._update_minion_readout()
		"summon_cost":
			game.minion_cost_reduction += int(5 * mult)
		"range_basic":
			game.player.basic_range += 30.0 * mult
			game.player._update_range_circles()
		"range_all":
			var range_mult: float = 1.0 + 0.25 * mult
			game.player.basic_range *= range_mult
			game.player.aura_radius *= range_mult
			game.player.curse_radius *= range_mult
			game.player._update_range_circles()
		"minion_range":
			game.minion_range_bonus += 40.0 * mult
		"minion_lifesteal":
			game.minion_lifesteal += 0.20 * mult
		"area":
			game.ability_radius_card_mult += 0.25 * mult
		"chain_lightning":
			game.chain_lightning_targets += 1
		"suppress":
			game.suppress_duration = minf(game.suppress_duration + 0.5, 2.0)
