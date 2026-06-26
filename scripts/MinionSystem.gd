extends Node
## 미니언(마물) 도메인 컨트롤러 (Phase 2 #3, 슬라이스 1) — 소환 UI · 스폰 · 생애주기.
## 데이터 = MinionData.gd. 공유 run-state(souls·hire_levels·active_minions·max_minions·키스톤·소환버튼 등)는
## Game 소유 → game 역참조(GS2). Game._ready서 new→add_child→setup(self).
## 외부 진입점: _build_summon_buttons() · _spawn_minion() · minion_died() · _refresh_summon_buttons().
## ⚠️ 카운트 readout(_update_minion_readout 등)·강화 UI는 Game 잔존(별도 슬라이스).

const MinionData = preload("res://scripts/data/MinionData.gd")
const CardData = preload("res://scripts/data/CardData.gd")
const WaveData = preload("res://scripts/WaveData.gd")
const SkeletonWarriorScene = preload("res://scenes/SkeletonWarrior.tscn")

var game: Node = null  # Game.gd 허브 역참조

func setup(g: Node) -> void:
	game = g

func _build_summon_buttons() -> void:
	# Phase C — 3종만 생성 (MinionData.HIRE_TYPE_INDICES: warrior/archer/tank, 폭탄병 제외)
	# game.summon_btns[j] 는 MinionData.HIRE_TYPE_INDICES[j] 번째 MinionData.MINION_TYPES 항목에 대응
	for j in MinionData.HIRE_TYPE_INDICES.size():
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# 버튼 자체 텍스트는 비움 — 자식 Label 2개가 내용을 담당
		btn.text = ""
		# font_color override 불필요(텍스트 없음), 기존 add_theme_color_override 제거
		game._apply_button_styleboxes(btn)
		# 눌림 바운스는 _on_summon_pressed 성공 경로에서만 재생(골드 부족·슬롯 꽉참 시 안 눌림)
		var type_idx: int = MinionData.HIRE_TYPE_INDICES[j]
		btn.pressed.connect(func(): _on_summon_pressed(type_idx, btn))
		game.summon_container.add_child(btn)
		game.summon_btns.append(btn)

		# 콘텐츠 = [이름] / [● 비용] 세로 스택 (VBox 중앙정렬 → 겹침 없이 안정적 간격)
		var content: VBoxContainer = VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 3)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(content)

		# 이름 라벨
		var name_lbl: Label = Label.new()
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		content.add_child(name_lbl)
		game._summon_name_lbls.append(name_lbl)

		# 비용 행: [● 노랑][숫자] — ●만 노란색이도록 아이콘/숫자 분리 (단일 라벨은 줄 전체 한 색)
		var cost_box: HBoxContainer = HBoxContainer.new()
		cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_box.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_box.add_theme_constant_override("separation", 3)
		content.add_child(cost_box)
		var cost_icon: Label = Label.new()
		cost_icon.text = "●"  # 노란 동그라미 (항상 골드색)
		cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_icon.add_theme_font_size_override("font_size", 13)
		cost_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
		cost_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_box.add_child(cost_icon)
		var cost_lbl: Label = Label.new()
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_box.add_child(cost_lbl)
		game._summon_cost_lbls.append(cost_lbl)


func _refresh_summon_buttons() -> void:
	# Phase C — game.minion_slot_label·slot_icon 숨김 유지 (캡 없어짐)
	# RD19 — 자원 캡슐 가시성은 _set_resource_hud_visible 단일 지점이 관리하므로
	#        여기서 개별 노드 visibility 동기화 불필요 (캡슐 자식이 함께 표시/숨김됨).

	# C4: 특수(상점) 웨이브 판정
	var wave_is_combat: bool = true
	if game.current_wave < WaveData.stage_wave_count(game.current_chapter, game.current_stage):
		var wdata: Dictionary = WaveData.get_wave(game.current_chapter, game.current_stage, game.current_wave)
		if wdata.get("type", "normal") == "shop":
			wave_is_combat = false

	# game.summon_btns[j] → MinionData.HIRE_TYPE_INDICES[j]
	for j in MinionData.HIRE_TYPE_INDICES.size():
		var type_idx: int = MinionData.HIRE_TYPE_INDICES[j]
		var entry: Dictionary = MinionData.MINION_TYPES[type_idx]
		var cost: int = max(5, entry["cost"] - game.minion_cost_reduction)
		var btn: Button = game.summon_btns[j]
		var name_lbl: Label = game._summon_name_lbls[j]
		var cost_lbl: Label = game._summon_cost_lbls[j]
		if not _is_summon_unlocked(j):
			# 튜토리얼 잠금 — 전사(j=0)만 처음부터 사용 가능, 궁수·탱크는 잠금
			# 이름 라벨에 잠금 표시, 비용 행(●+숫자) 숨김
			name_lbl.text = "🔒 %s" % [entry["label"]]
			name_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.65, 0.85))
			cost_lbl.get_parent().visible = false  # cost_box(아이콘+숫자) 숨김
			btn.disabled = true
		else:
			var gold_short: bool = game.souls < cost
			var is_blocked: bool = (not game.wave_active) or (not wave_is_combat)
			# 비전투/비활성 웨이브만 비활성 — 골드 부족은 비활성 안 함(상시 활성)
			# 누름 가드는 _on_summon_pressed 의 골드/캡 체크가 처리
			btn.disabled = is_blocked
			# 이름 라벨
			name_lbl.text = entry["label"]
			name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
			# 비용 행(●+숫자) — ●은 항상 노란색, 숫자만 색 변동
			cost_lbl.get_parent().visible = true
			cost_lbl.text = "%d" % cost
			# 골드 부족 → 숫자 빨강, 아니면 평소 밝은 색
			# is_blocked 상태에서는 빨강 표시 안 함(골드 부족 전용)
			if gold_short and not is_blocked:
				cost_lbl.add_theme_color_override("font_color", game.UI_COST_SHORT)
			else:
				cost_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))

func _on_summon_pressed(index: int, btn: Button = null) -> void:
	# Phase C — 고용 가능 조건: game.wave_active + 비특수(비상점) 웨이브 + 골드만 게이팅
	# MD12: 전역 총량 캡(game.active_minions >= game.max_minions) 으로 교체
	# 차단 사유(웨이브/골드/슬롯)면 여기서 early-return → 눌림 바운스도 재생 안 됨.
	if not game.wave_active:
		return
	var wave_data: Dictionary = WaveData.get_wave(game.current_chapter, game.current_stage, game.current_wave)
	if wave_data.get("type", "normal") == "shop":
		return
	var disp_j: int = MinionData.HIRE_TYPE_INDICES.find(index)
	if game._is_tutorial() and (disp_j == -1 or not _is_summon_unlocked(disp_j)):
		return  # 튜토리얼: 해금된 마물만 소환 가능 (W0=전사, W1+=궁수, W2+=탱크)
	var entry: Dictionary = MinionData.MINION_TYPES[index]
	var cost: int = max(5, entry["cost"] - game.minion_cost_reduction)
	if game.souls < cost:
		return
	# MD12 — 전역 총량 캡 초과 시 거부 (N/M 빨강 펄스로 피드백 — 누를 때마다 깜빡)
	if game.active_minions >= game.max_minions:
		# 튜토리얼 한도 예외: 교습 중인 종류면 '이번에만' 한도 +1 (한도 인지시키며 교습 완성)
		if game._is_tutorial() and index == game._tutorial_teaching_minion:
			game.max_minions += 1
			game._update_minion_readout()
			game._demon_say("victory", "한도가 찼군… 이번에만 한 자리 내주마.", true)
		else:
			game._flash_minion_cap()
			return
	# 모든 게이트 통과 — 성공 시에만 눌림 피드백
	game._play_button_bounce(btn)
	game.souls -= cost
	game._update_souls_ui()
	# 교습 중인 종류를 소환하면 그 가이드 팁을 닫고 교습 완료 (다른 종류 소환은 팁 유지=게이트)
	if index == game._tutorial_teaching_minion:
		game._tutorial_teaching_minion = -1
		game._close_guide()
	_spawn_minion(entry["id"])

	# FX13 — 1-2 강화 교습: 소환을 해봤다는 사실만 기록. 실제 팁은 골드가 강화비용 이상으로
	# 차오르는 순간(game._try_show_enhance_tip, 보통 킬 보상 add_souls 경유)에 띄운다.
	# (소환 직후 game.souls 체크는 골드를 다 써버려 거의 안 떠서 폐기 — 소환→강화 순서는 플래그로 보장)
	if game.current_stage == 1:
		game._st1_summoned = true
		game._try_show_enhance_tip()

func _spawn_minion(type_id: String) -> void:
	var m = SkeletonWarriorScene.instantiate()
	m.game = game
	m.minion_type = type_id
	m.position = m.get_spawn_position()  # 역할별 정착선 살짝 아래에서 스폰 (B안)
	game.minions_node.add_child(m)
	# 카드 보너스 반영 (프리셋 적용 후)
	m.base_damage *= game.minion_attack_bonus * game.keystone_minion_atk_mult
	m.attack_damage = m.base_damage
	m.move_speed *= game.minion_move_speed_bonus
	m.max_hp *= game.minion_hp_bonus
	m.base_max_hp *= game.minion_hp_bonus
	m.hp = m.max_hp
	m.attack_range += game.minion_range_bonus
	m.lifesteal = game.minion_lifesteal
	# RD16 — 종류별 글로벌 레벨 스탯 스케일 적용
	if type_id in game.hire_levels:
		var lv: int = game.hire_levels[type_id]
		m.level = lv
		var scale_mult: float = 1.0 + MinionData.HIRE_UPGRADE_STAT_MULT * (lv - 1)
		m.base_damage *= scale_mult
		m.attack_damage = m.base_damage
		m.base_max_hp *= scale_mult
		m.max_hp = m.base_max_hp
		m.hp = m.max_hp
	game.active_minions += 1  # MD12: 전역 총량 추적 (_hire_alive 종류별 추적 제거)
	game._update_minion_readout()
	_refresh_summon_buttons()
	game.spawn_summon_effect(m.position)

func minion_died(pos = null, type_id: String = "") -> void:
	game.active_minions = max(0, game.active_minions - 1)
	# game.hire_levels는 유지 — 레벨은 죽어도 안 날아감 (_hire_alive 종류별 추적 제거됨 — MD12)
	game._update_minion_readout()
	_refresh_summon_buttons()
	# 영원한 군세(horde): 전사 시 소환 비용 50%+[마물]카드당 5% 골드 환급
	if game.keystone2 == "horde" and type_id != "":
		var base_cost: int = 0
		for entry: Dictionary in MinionData.MINION_TYPES:
			if entry["id"] == type_id:
				base_cost = entry["cost"]
				break
		if base_cost > 0:
			var paid_cost: int = max(5, base_cost - game.minion_cost_reduction)
			var refund_rate: float = min(CardData.HORDE_REFUND_BASE + CardData.HORDE_REFUND_PER_CARD * float(game.army_card_count), 1.0)
			var refund: int = int(round(float(paid_cost) * refund_rate))
			game.souls += refund
			game._update_souls_ui()
			if refund > 0:
				game._spawn_gold_floater(refund)
				if pos != null:
					game._spawn_refund_coin(pos)
	if pos == null:
		return
	# 죽음의 메아리: 사망 폭발
	if game.keystone_echo_dmg > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.position.distance_to(pos) <= CardData.KEYSTONE_ECHO_RADIUS:
				e.take_damage(game.keystone_echo_dmg)
		game._spawn_echo_effect(pos)
	# Phase C — 영구사망: 자동 재소환/리필 분기 없음 (재고용은 유저가 버튼으로)


func _is_summon_unlocked(display_j: int) -> bool:
	if not game._is_tutorial():
		return true
	return display_j <= game.current_wave
