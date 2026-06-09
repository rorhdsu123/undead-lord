# H. 튜토리얼 가이드 오버레이

> 레이어 **L5 (튜토리얼)**. 최상위 z, 1-1 스테이지(FTUE)에서만 등장.
> 특정 버튼·영역을 화살표/하이라이트로 강조해 처음 플레이어를 유도. L1·L2 위에 얹힘.

## 구성 요소

| ID | 이름 | 구현 | 역할 |
|---|---|---|---|
| H1 | 가이드 레이어 | `_guide_layer` (CanvasLayer 동적 생성) | 최상위 레이어 오버레이 |
| H2 | 가이드 화살표/텍스트 | 레이어 내 자식 노드 | 강조 대상 가리키는 화살표·설명 |

## 가이드 단계 (1-1 스테이지)

| 웨이브 | 가이드 | 트리거 |
|---|---|---|
| W0 시작 | 소환 버튼 안내(전사 강조) | `_trigger_wave_guide(0)` |
| W0 클리어 후 | 카드 선택 안내 | `_show_card_guide()` |
| W2 시작 | 상점 안내 | `_show_shop_guide()` |
| W4 | 특수기 안내 | `_special_atk_tip_shown` |

## 잠금 규칙 (튜토리얼 단계 해금)

| 기능 | 해제 시점 |
|---|---|
| 소환(전사) | W1부터 (W0 잠금) |
| 소환(궁수/탱크/폭탄병) | 튜토리얼 중 잠금 |
| 특수기 | `_special_atk_unlocked` 이후 |
| 희생 | 튜토리얼 전체 잠금 |

## 디자인 의제

- **레이어 구조** — 현재 CanvasLayer 코드 동적 생성. .tscn 사전 배치 + show/hide로 바꾸면 편집 용이.
- **연출 내용** — 화살표 방향·문구·강조 외형은 .tscn/디자인에서 결정. 코드는 골격만.
- **단계 진행** — 가이드 중 행동 시 즉시 닫힘(`_close_guide()`). 유도 충분성 플테 확인.
- **재노출** — `GameSave.tutorial_completed`로 완료 처리. 재관람 옵션 미결.

## 코드 위치

- `scripts/Game.gd`
  - `_guide_layer` (82) / `_guide_active` / `_guide_tween`
  - `_trigger_wave_guide()` / `_show_card_guide()` / `_show_shop_guide()` / `_close_guide()`
  - `_is_tutorial()`, `_special_atk_unlocked` (87) / `_special_atk_tip_shown` (85)
  - `GameSave.tutorial_completed`

## 관련 문서

- [07_연출_튜토리얼](../../07_연출_튜토리얼/) — 튜토리얼 흐름 정본
