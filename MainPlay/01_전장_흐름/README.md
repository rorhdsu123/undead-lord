# 01. 전장 흐름 (Battlefield Flow)

> 전투 한 판의 뼈대 — 웨이브 스폰·진행, 성 HP·게임오버 조건, 상단 웨이브 트래커.
> 다른 모든 기능(공격·하인·카드·보스)이 이 흐름 위에서 돈다.

## 책임

- 웨이브 시작 → 적 스폰 → 전멸 감지 → 다음 웨이브 (또는 상점/보스/클리어)
- 챕터-스테이지-웨이브 좌표 관리 (`WaveData.gd` 테이블 조회)
- 성(Castle) HP 관리, 적 근접 시 피해, HP 0 → 게임오버
- 웨이브 트래커 UI (현재 위치·남은 웨이브 시각화)

## 현재 상태

| ID | 기능 | 상태 |
|---|---|---|
| B1 | 웨이브 시작·적 스폰 (`composition` 기반) | ✅ |
| B2 | 적 전멸 카운트 → 웨이브 종료 | ✅ |
| B3 | 웨이브 타입 분기 (일반 / 상점 / 보스) | ✅ |
| B4 | 성 HP·최대 HP, 적 근접 자동 피해 | ✅ |
| B5 | 성 HP 0 → 게임오버 (06으로) | ✅ |
| B6 | 웨이브 트래커 UI + 갱신 | ✅ |
| B7 | 보스의 잡몹 소환(`boss_summon`)으로 진행 중 적 추가 | ✅ |

## 코드 위치

- `scripts/Game.gd`
  - 상태 변수 — `current_chapter/stage/wave`, `castle_hp/castle_max_hp`, `wave_active`, `enemies_alive` (24–31줄)
  - `start_wave()` (194) — 웨이브 데이터 로드·적 스폰·타입 분기
  - `end_wave()` (377) — 전멸 후 처리, 카드/상점/다음 웨이브 분기
  - `enemy_died()` (354) / `boss_summon()` (332)
  - `castle_take_damage()` (366) → `game_over()` (724)
  - `_build_wave_tracker()` (616) / `update_wave_tracker()` (635)
  - `@onready wave_label / castle_hp_bar / wave_tracker / enemies_node` (138–149)
- `scripts/WaveData.gd` — `CHAPTERS` 테이블(16–), 조회 헬퍼(190–206). 웨이브 타입·적 구성·기준 수치.
- `scripts/Enemy.gd` — 적 이동·근접 공격·`TYPE_PRESETS`(normal/scout/brute/swarm)
- `scripts/CastleSprite.gd` — 성 시각

## 미해결 의제

- **성 HP 기본값 코드 ≠ 기획** — 코드 `castle_hp = 500`(28줄). 기획·시설 표는 "최대 HP +50/+100" 식 증분 기준이라 시작값 정합 재확인 필요.
- **상점 웨이브 위치** — 기획 §12는 W3·W9. 실제는 `WaveData.gd` 테이블이 단일 진실 — 동기화 확인 필요.
- **적 타입 4종(scout/brute/swarm) 밸런스** — 기획 §12엔 "특이사항"만, 타입별 등장 곡선 미문서화.

## 관련 결정·문서

- [기획문서.md §12 웨이브 설계](../../기획문서.md) · [§14 성 시스템](../../기획문서.md)
- 게임오버·클리어 처리 상세 → [06_결과_보상](../06_결과_보상/)
- 보스 웨이브 진입 → [05_보스](../05_보스/)
