# 02. 자원 HUD

> 상단 자원 표시. 현재 보유 자원의 *즉각적 가시성*.

## 책임

- 왕관 조각 수 라벨 (상단 중앙)
- 해골 수 / 캡 라벨 (상단 중앙 아래)
- 자원 변화 시 갱신

## 현재 상태

| ID | 기능 | 상태 |
|---|---|---|
| B1 | `왕관 조각: N` 라벨 | ✅ |
| B2 | `해골: N / CAP` 라벨 | ✅ |

## 코드 위치

- `scripts/Lobby.gd`
  - `crown_label` — `$UI/CrownLabel` (씬에서 주입)
  - `skeleton_label` — `_ready()`에서 동적 생성
  - `_update_crown_label()`, `_update_skeleton_label()` — 갱신
- `scripts/GameSave.gd` — `crown_shards`, `skeleton_count`, `SKELETON_CAP`

## 미해결 의제

- **교리 EXP / 영주 레벨 표시 추가** (D5) — 풀 10칸·해제 진척 시각화 필요
- **자원 종류 늘면 HUD 재설계** — 현재 2개. 영주 레벨 추가되면 3개. 4개 넘으면 레이아웃 변경 필요.
- 자원 변화 애니메이션 (숫자 카운트업, 반짝임) — 폴리싱 항목

## 관련 결정

- [D5](../핵심재미_검토.md) — 영주 레벨 시스템 도입 시 B 영역 확장
