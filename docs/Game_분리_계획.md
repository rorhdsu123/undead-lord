# Game.gd 기능 단위 분리 계획

> `Game.gd`(현 4,051줄) 갓 오브젝트를 기능 컴포넌트로 분리하는 리팩터링 정본.
> 작성 2026-06-25 · 코드 변경 없음(계획만). 파일명은 모두 **(가제)**.
> 배경: [아키텍처.md §3](./아키텍처.md) 허브-앤-스포크 구조 · 동기 = 동시편집 충돌(클로버) 반복.

## 1. 현황 진단

| 지표 | 값 |
|---|---|
| 줄 수 | **4,051** (아키텍처.md 기록 1,534 → 2.6배 비대화) |
| 멤버 변수 | 122 |
| 상수 | 70 |
| 함수 | ~120 |
| 기능 클러스터(책임) | **~14** |

`Game.gd:extends Node2D`. 전투 액터(`Enemy`/`Boss`/`SkeletonWarrior`/`AbilitySystem`)가 부모 `Game`을 `game`으로 역참조해 콜백·스탯을 읽는 **허브-앤-스포크** 구조.

### 1.1 기능 클러스터와 규모

| 클러스터 | 대략 줄 | 액터 호출 | 대표 함수 |
|---|---|---|---|
| 하단 UI(소환·강화 버튼·팝업) | ~745 | ❌ 내부 | `_build_summon_buttons`·`_build_upgrade_ui`·`_on_summon_pressed`·`_refresh_summon_buttons` |
| 카드/키스톤 | ~600 | ❌ 내부 | `_show_cards`·`_apply_card`·`_apply_keystone`·`_build_card_row`·`_build_keystone_card`·`_card_value_preview` |
| 결과/게임오버/클리어 | ~467 | ✅ 일부 | `game_over`·`game_clear`·`_show_result`·`earn_crown_shards` |
| VFX/타격감 | ~290 | ✅ 다수 | `spawn_damage_number`·`spawn_death_effect`·`spawn_explosion_effect`·`hit_stop`·`_screen_shake` |
| 튜토리얼/온보딩(FTUE) | ~242 | ✅ 1 | `show_tutorial_tip`·`show_guide`·`_trigger_wave_guide`·`_close_guide`·`_is_summon_unlocked` |
| 웨이브 트래커 UI | ~230 | ❌ 내부 | `_build_wave_tracker`·`update_wave_tracker`·`_render_wave_tracker`·`_compute_wave_display` |
| 상점 | ~205 | ❌ 내부 | `_show_shop`·`_buy_item`·`_apply_shop_item`·`_refresh_shop_buttons` |
| 자원 HUD | ~160 | ✅ 1 | `add_souls`·`_update_souls_ui`·`_update_minion_readout`·`_spawn_gold_floater` |
| 미니언 생애주기 | ~105 | ✅ 일부 | `_spawn_minion`·`minion_died`·`_spawn_echo_effect`·`_spawn_refund_coin` |
| 코어(웨이브·보스·성·마왕·희생) | 나머지 | ✅ 코어 | `start_wave`·`end_wave`·`castle_take_damage`·`enemy_died`·`boss_summon`·`_update_demon_danger` |

## 2. 분리가 가능한 이유 — 외부 계약이 작다

액터가 `game.*`로 호출하는 **공개 메서드는 ~16개뿐**(나머지 ~104개 함수는 외부에서 안 부르는 순수 내부/UI):

| 분류 | 메서드 |
|---|---|
| 전투 이벤트 | `castle_take_damage`·`enemy_died`·`minion_died`·`on_boss_killed`·`boss_summon` |
| 타격감/VFX | `spawn_death_effect`·`spawn_damage_number`·`spawn_explosion_effect`·`show_crit_text`·`_screen_shake`·`hit_stop` |
| 기타 | `show_dialogue`·`add_souls`·`earn_crown_shards`·`demon_bark_power`·`_close_guide` |

> 호출처: `Enemy.gd`·`Boss.gd`·`SkeletonWarrior.gd`·`AbilitySystem.gd` (`아키텍처.md §3.3` 계약).

**함의**: 카드·상점·결과·웨이브트래커·하단UI·튜토리얼(합 ~2,500줄)은 액터 계약을 건드리지 않고 들어낼 수 있다. 분리 난이도가 외형보다 낮다.

## 3. 분리 방식 (결정)

| 코드 | 결정 | 근거 |
|---|---|---|
| `GS1` | **자식 노드 컴포넌트 + 정적 헬퍼, `Game.gd`는 허브로 잔존** | 기존 허브-앤-스포크 idiom 유지(개념 변화 최소). 명시 시그널 도입은 과잉 |
| `GS2` | **1차는 "코드만 이동", 런상태(122 var)는 `Game.gd`가 계속 소유.** 컴포넌트는 액터처럼 `game` 역참조로 상태 읽기/쓰기 | 동작 동일·기계적 이동이라 최저위험. 상태 소유권 분산은 별개 고위험 작업(§6 Phase 4 보류) |
| `GS3` | **액터 16-메서드 계약은 `Game.gd`에 얇은 위임(facade)으로 유지** (예: `func spawn_death_effect(...): fx.spawn_death_effect(...)`) | 액터 4파일 재배선 회피 → 1차 표면적 0. 위임 제거(액터가 `game.fx.X()` 직접 호출)는 후순위 |
| ~~`GS4`~~ | ~~추출 순서 = 무상태 헬퍼 → 충돌 핫존 → 큰 UI~~ → **`GS7`로 대체**(콘텐츠 도메인·데이터 우선) | (구) 시스템 기능 단위 가정 |
| `GS5` | **선행조건: 동시 `Game.gd` 편집 세션이 정리된 뒤 착수** | 리팩터 자체가 대규모 재작성 → 동시편집 중 진행하면 그 작업이 또 클로버로 소멸(자기 모순). ✅2026-06-26 정리 완료 |
| `GS6` | **분리 단위 = 시스템 기능 ❌ → 「콘텐츠 도메인」 수직 슬라이스** (카드·상점·마물·적·보스·대사). 각 도메인 = 데이터+로직+뷰 자급자족 | 라이브 서비스: 가장 자주 바뀌는 건 콘텐츠 → 신규 콘텐츠 추가가 엔진 코드(god object) 안 건드리게. **선례 이미 존재**: `WaveData.gd`(웨이브)·`Enemy.gd:TYPE_PRESETS`(적 프리셋) |
| `GS7` | **점진 경로: ① 콘텐츠 데이터 모듈 먼저(`scripts/data/*Data.gd`) → ② 도메인별 로직 이동 → ③ 뷰.** 각 단계 = 커밋 + 플테 | 데이터 추출은 저위험·즉시 라이브가치(수치/항목 추가가 한 파일). 로직 이동은 그 위에 점진. 사용자 결정 2026-06-26 |

### 3.1 컴포넌트 형태
- **자식 노드**(stateful UI): `Game` 씬의 자식 `Node`로 추가, 각 스크립트가 `@onready var game := get_parent()` 보유. Game은 `@onready var card_system`·`var fx` 등으로 참조·위임.
- **정적 헬퍼**(무상태): `class_name` 정적 함수 모음. 인스턴스·상태 없음(스타일박스·포맷·순수 빌더).

## 4. 분리 경계 — 클러스터 → 제안 컴포넌트

| 제안 파일(가제) | 형태 | 흡수할 함수 | 액터 계약 | 상태 결합 | 위험 | Phase |
|---|---|---|---|---|---|---|
| `UIStyle.gd` | 정적 | `_make_capsule_stylebox`·`_make_button_stylebox`·`_apply_button_styleboxes`·`_play_button_bounce`·`_add_button_press_bounce` | ❌ | 없음(무상태) | 낮음 | 1 |
| `BattleFX.gd` | 자식 노드 | `spawn_damage_number`·`show_crit_text`·`spawn_death_effect`·`spawn_explosion_effect`·`spawn_evolve_effect`·`spawn_summon_effect`·`spawn_castle_hit_effect`·`_spawn_pulse_ring`·`_spawn_card_pickup_effect`·`_spawn_confetti`·`hit_stop`·`_screen_shake`·`_screen_flash`·`_spawn_gold_floater`·`show_dialogue`·`_show_boss_title`·`_show_crown_shard_gain` | ✅(다수) | 약함(주로 전이 노드 생성) | 낮음 | 1 |
| `CardSystem.gd` ⚠️핫존 | 자식 노드 | `_show_cards`·`_pick_card`·`_recompute_keystones`·`_apply_keystone`·`_show_keystones`·`_apply_card`·`_card_name`·`_card_desc`·`_hl`·`_card_value_preview`·`_format_axis_tags`·`_build_card_row`·`_build_keystone_card`·`_vcenter_richtext`·`_flash_card_glow` | ❌ | **강함**(`_apply_card`가 `castle_max_hp`·`souls`·`max_minions`·키스톤 상태 기록) | 중 | 2 |
| `TutorialDirector.gd` ⚠️핫존 | 자식 노드 | `_is_tutorial`·`_trigger_wave_guide`·`_show_shop_guide`·`show_tutorial_tip`·`show_guide`·`_close_guide`·`_set_battle_freeze`·`_is_summon_unlocked`·`_try_show_enhance_tip`·`_update_ability_buttons_for_stage`·`_is_lightning_available` | ✅(`_close_guide`) | 중(`GameSave` taught 플래그·전투 freeze) | 중 | 2 |
| `BottomUI.gd` | 자식 노드 | `_build_summon_buttons`·`_build_upgrade_ui`·`_open/_close/_refresh_upgrade_popup`·`_toggle_upgrade_popup`·`_on_upgrade_pressed`·`_apply_upgrade_to_alive_minions`·`_refresh_summon_buttons`·`_on_summon_pressed`·`_layout_bottom_ui_phase_c`·`_hide_bottom_ui_phase_a` | ❌ | 강함(souls·미니언·강화) | 중상 | 3 |
| `ResultScreen.gd` | 자식 노드 | `game_over`·`game_clear`·`_show_result`·`_fade_in`·`_on_result_btn1/2`·`_fade_to_scene`·`earn_crown_shards`·`_stage_has_final_boss`·`_format_time`·`_hide_battle_operation_ui` | ✅(`earn_crown_shards`) | 중(런 종료 상태 읽기) | 중 | 3 |
| `ShopController.gd` | 자식 노드 | `_build_shop_buttons`·`_show_shop`·`_close_shop`·`_buy_item`·`_apply_shop_item`·`_refresh_shop_buttons`·`_flash_shop_buy` | ❌ | 중(souls·마법 배수) | 중 | 3 |
| `WaveTracker.gd` | 자식 노드 | `_wave_icon`·`_wave_badge_color`·`_make_badge_column`·`_build_wave_tracker`·`update_wave_tracker`·`_compute_wave_display`·`_render_wave_tracker`·`_reveal_wave_tracker` | ❌ | 약함(웨이브 인덱스 읽기) | 낮음 | 3 |
| `ResourceHUD.gd` | 자식 노드 | `add_souls`·`_set_resource_hud_visible`·`_update_souls_ui`·`_set_souls_display`·`_bump_souls_label`·`_update_minion_readout`·`_position_max_badge`·`_flash_minion_cap`·`_set_minion_readout_color`·`_shake_minion_group` | ✅(`add_souls`) | 중(souls·캡 표시) | 중 | 3 |

### 4.1 코어 잔존 (`Game.gd` 허브)
분리 후 `Game.gd`에 남는 것(~1,200줄 목표):
- **런루프**: `_ready`·`_process`·`_unhandled_input`·`start_wave`·`end_wave`·`_spawn_scheduled_enemy`
- **전투 이벤트 API**: `castle_take_damage`·`enemy_died`·`minion_died`·`on_boss_killed`·`boss_summon`·`_on_boss_entered`·`_spawn_minion`
- **성·마왕·희생**: `_update_castle_pulse`·`_fire_castle_pulse`·`_update_demon_danger`·`_demon_say`·`demon_bark_power`·`_on_sacrifice_pressed`·`_sacrifice_minion` 외
- **런상태 122 변수의 단일 소유권**(GS2)

## 5. 상태 소유권 원칙

- **1차(GS2)**: `Game.gd`가 런상태 단일 소유자. 컴포넌트는 `game.souls`·`game.castle_max_hp`처럼 역참조로 읽기/쓰기. → 동작 불변, 기계적.
- **검증**: 추출 전후 동작 동일성. 전투계 파싱은 `Game.tscn` 직접 로드로(헤드리스 `--quit-after 5`는 로비만 부팅 → 위음성, 메모리 `project_parse_check_false_negative`).
- **2차(보류·Phase 4)**: 컴포넌트가 자기 상태를 소유(예: `ShopController`가 상점 전용 상태). 고위험·가치 불확실 → 1차 안정화 후 재평가.

## 6. 단계별 순서 (GS6/GS7 — 콘텐츠 도메인 · 데이터 우선 점진)

### 6.1 콘텐츠 데이터 도메인 → 데이터 모듈 (Phase 1)
`scripts/data/*Data.gd`로 콘텐츠 데이터 테이블만 먼저 추출. `WaveData.gd` 선례 그대로(`extends Node` + `const` + 필요 시 static 접근자, `Game.gd`에서 `preload`). 각 = 1 커밋 + 플테.

| 데이터 모듈(가제) | 흡수할 상수 | Game.gd 참조 갱신 | 위험 |
|---|---|---|---|
| `DialogueData.gd` | `WAVE_CLEAR_LINES`·`POWER_LINES`·`DANGER_LINES`·`BOSS_INTRO_DIALOGUES`·바크 관련 상수 | 마왕 바크 함수 4곳 | 낮음(순수 문자열) |
| `ShopData.gd` | `SHOP_ITEMS` | `_build_shop_buttons`·`_buy_item`·`_apply_shop_item` | 낮음 |
| `MinionData.gd` | `MINION_TYPES`·`HIRE_TYPE_INDICES`·`HIRE_START_GOLD`·`HIRE_UPGRADE_*` | 소환·강화·스폰 다수 | 중(참조 많음) |
| `CardData.gd` | `STAT_CARDS`·`SKILL_CARDS`·`RARE_CHANCE`·`ALWAYS_RARE`·`NEVER_RARE`·`CARD_CATEGORY_MAP`·`CARD_AXIS`·키스톤 상수(`KEYSTONE_ECHO_RADIUS`·`HORDE_REFUND_*`) | 카드/키스톤 로직 다수 | 중(핫존·참조 많음) |

> 적 프리셋(`Enemy.gd:TYPE_PRESETS`)·웨이브(`WaveData.gd`)는 이미 분리됨 — 추가 작업 없음.

### 6.2 도메인별 로직 이동 (Phase 2~)
데이터 모듈 안정화 후, 도메인별로 로직(+뷰)을 자급자족 모듈로 이동. 한 도메인 = 1 커밋 + 플테.

| Phase | 도메인 모듈 | 흡수 | 비고 |
|---|---|---|---|
| 2 | `ShopController` (+ `ShopData`) | `_show_shop`·`_buy_item`·`_apply_shop_item`·`_refresh_shop_buttons`·`_build_shop_buttons` | 작고 자기완결(`$UI/ShopPanel`)→첫 로직 슬라이스 |
| 3 | `CardSystem` (+ `CardData`·`CardView`) | `_show_cards`·`_pick_card`·`_apply_card`·`_apply_keystone`·`_recompute_keystones`·`_show_keystones`·카드 뷰 빌더 | 핫존(클로버 원천). 강한 상태결합→`game` 역참조(GS2) |
| 4 | `MinionSystem` (+ `MinionData`) | 소환·강화·스폰·생애주기 + 하단 소환/강화 UI | souls·캡 결합 |
| 5 | (비콘텐츠) `BattleFX`·`UIStyle`·`ResultScreen`·`WaveTracker`·`ResourceHUD`·`TutorialDirector` | §4 표 | 엔진/공유. 콘텐츠 도메인 정리 후 |
| 6 (보류) | 상태 소유권 분산 | — | 고위험. 가치 검증 후 |

**원칙**: 한 모듈 = 한 추출 = 한 커밋 + 플테. 묶음 금지. 데이터(6.1) 먼저 → 로직(6.2).

## 7. 위험 · 전제

- **자기 클로버(최우선)**: 리팩터 자체가 대규모 재작성 → §6 Phase 0(동시 세션 정리) 없이 착수 금지.
- **순환 참조**: 컴포넌트 ↔ `game` 역참조. 액터와 동일 패턴이라 검증됨이나, 컴포넌트끼리 직접 호출은 지양(허브 경유).
- **facade 누락**: 액터 16-메서드 중 이동분은 반드시 `Game`에 위임 stub 유지(GS3). 누락 시 액터 런타임 깨짐.
- **파싱 검증 위음성**: 전투계는 `Game.tscn` 직접 로드로 확인.
- **씬 트리 의존**: 일부 UI 함수는 특정 노드 경로(`@onready`)에 의존 → 컴포넌트 이동 시 노드 소유·경로 재정리 필요(확인 필요).

## 8. 남은 작업

1. ✅ **Phase 0** — 동시 세션 정리 완료(2026-06-26). 유실됐던 죽은카드 가드 재적용 커밋 `9f8b8c2`.
2. ✅ **Phase 1 (6.1) 완료** (2026-06-26) — 콘텐츠 데이터 4모듈 추출, 각 씬 로드 검증·커밋:
   - `DialogueData.gd`(`b316aa1`) · `ShopData.gd`(`a2e1a02`) · `MinionData.gd`(`4a4e86a`) · `CardData.gd`(`eea2c7a`).
   - Game.gd 4060→3970줄. 동작 동일(데이터 이동). **플테 대기**.
3. **Phase 2 진행 중 (6.2)** — 도메인 로직 이동:
   - ✅ `ShopController.gd`(`7b5cdb1`) — 상점 7함수+UI노드+상태. Game 3970→3742. **플테OK**(사용자 확인). +`0425be7` AbilitySystem `game.shop_panel`→`game.shop.shop_panel` 버그픽스(외부참조 누락 교훈).
   - ✅ `CardSystem.gd`(`7bb6374`, 2026-06-26) — 카드/키스톤 15함수+로컬상태. Game 3742→3164(세션시작4060→). game 역참조(GS2), 효과결과는 Enemy/Boss/AbilitySystem이 game.X 읽음(불변). **카드 화면 플테 대기**(뽑기/키스톤/효과 런타임).
   - ✅ `MinionSystem.gd`(`4f9a436`, 2026-06-26) — **슬라이스1**: 소환 UI·스폰·생애주기 6함수. 상태 Game 소유·game 역참조(GS2), facade 2개(minion_died←SkeletonWarrior·_refresh_summon_buttons←CardSystem). Game 3164→2967(세션 4060→). **소환/스폰/사망 플테 대기**.
   - ✅ `UpgradeSystem.gd`(`c223b16`, 2026-06-26) — 강화 UI 8함수. Game 2967→2541(세션 4060→). facade 3(ShopController·내부). 강화 버튼/팝업 플테 대기.
   - 다음 = readout(ResourceHUD) → Result → WaveTracker → Tutorial → 정적헬퍼.
4. 각 추출 시 `아키텍처.md §3.2 책임표`·`§3.5 부채` 동반 갱신.

## 관련 문서
- [아키텍처.md](./아키텍처.md) — 허브-앤-스포크 구조(§3.1)·책임표(§3.2)·액터 계약(§3.3)·코드 부채(§3.5)
- [게임루프_상태관리.md](./게임루프_상태관리.md) — 상태 3계층(영구·런·전역)
- [/CLAUDE.md](../CLAUDE.md) — 개발 규칙(기획 먼저·구현 Sonnet)
