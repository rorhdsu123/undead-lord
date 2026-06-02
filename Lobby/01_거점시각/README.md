# 01. 거점 시각 (Visual Hub)

> 로비의 *공간감*과 *진입 연출*. 성 sprite와 시설 배치 좌표.

## 책임

- 폐허의 성 sprite (CastleSprite) 렌더
- 5개 시설 화면 좌표 정의 (480×960 portrait 기준)
- 진입 페이드 인 / 출정 페이드 아웃

## 현재 상태

| ID | 기능 | 상태 |
|---|---|---|
| A1 | 성 sprite + 부제 라벨 "— 폐허의 성 —" | ✅ 단일 단계만 |
| A2 | 시설 5개 위치 (`FAC_SCREEN_POS`) | ✅ |
| A3 | 진입 페이드 / 출정 페이드 | ✅ |

## 코드 위치

- `scripts/Lobby.gd`
  - `_build_castle()` — 성 sprite 인스턴스
  - `_fade_in()` — 진입 페이드
  - `_on_start_pressed()` — 출정 페이드
  - `CASTLE_POS`, `CASTLE_SCALE`, `FAC_SCREEN_POS` 상수
- `scripts/CastleSprite.gd` — 성 그래픽

## 미해결 의제

- **시설 시각 4단계 (폐허→Lv1→Lv2→Lv3)** — 컨셉 핵심 시각인데 미구현. ROI 논의 필요. → [07_미구현_의제/시설시각성장.md](../07_미구현_의제/) (예정)
- 배경 깊이감 (전경/중경/원경 레이어) — 검토 미진행
- 시간대·날씨 변화 — 기획 외, 무게 큼

## 관련 결정

- 없음 (시각 자산 결정은 ROI 토론 후)
