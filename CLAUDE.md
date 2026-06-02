# CLAUDE.md — 프로젝트 가이드

> 매 세션 자동 로드되는 개발 규칙·구조 요약. 상세는 [docs/](./docs/) 참조.
> ⚠️ "개발 규칙"(§3)은 지금까지의 관행을 정리한 **초안** — 사용자 검토 후 확정.

## 1. 프로젝트 개요
- **엔진**: Godot 4.6 / GDScript · 프로젝트명 `undead-lord`
- **플랫폼**: 모바일 세로(480×960), 웹 export 병행
- **장르**: 로그라이트. **로비(경영·메타 강화) ↔ 출정(웨이브 전투, 매 런 새 빌드)** 2층 구조
- **핵심 재미**: "머리 쓰는 라이트 전략" = 매 런 빌드가 달라지는 운영. 실패해도 메타(왕관·해골·EXP)는 들고 나옴(실패 완충)
- **세계관**: "언데드 영주" → **"마지막 고대 괴수"로 피벗 중**(2026-05-29). 명명·서사는 가제, `세계관_기획.md`가 단일 진실

## 2. 구조 한눈에
- 코드: `scripts/*.gd` (허브=`Game.gd` 전투 / `Lobby.gd` 로비). 액터는 `game` 역참조 + 그룹(`enemies`/`minions`) 패턴
- Autoload: **`GameSave`**(영구 상태+저장) · **`Loc`**(모든 UI 문자열)
- 상태 3계층: 영구(GameSave/`save.cfg`) · 런(Game 멤버, 씬 reload로 리셋) · 전역(autoload)
- 상세: [docs/아키텍처.md](./docs/아키텍처.md) · [docs/게임루프_상태관리.md](./docs/게임루프_상태관리.md)

## 3. 개발 규칙 (초안 — 검토 요망)

### 워크플로우
- **기획 먼저, 구현은 합의 후**: 새 시스템은 설계를 충분히 논의해 합의한 뒤 코드 진입. 합의 전 코드 수정 금지
- **구현은 Sonnet, 출시 품질**: 설계·브리핑은 메인(Opus), 합의된 코드 편집은 Sonnet 모델로. 실제 출시 대상이므로 기존 컨벤션 준수·깔끔하게
- **godot CLI 설치됨**(`godot` → 4.6.2, `/opt/homebrew/bin/godot` 심볼릭 링크): 코드 수정 후 아래로 파싱/컴파일 검증. 런타임 로직·시각 확인은 에디터 플레이테스트
  ```bash
  # 전체 스크립트 파싱/컴파일 검증 (창 안 뜸)
  godot --headless --quit-after 5 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|Cannot|expected|invalid"
  ```

### 코드 컨벤션 (GDScript)
- **탭 들여쓰기**, 타입 힌트 사용(`var x: float`, `func f() -> void`)
- 모든 사용자 노출 텍스트는 **`Loc.gd`** 경유(하드코딩 금지). 전역 데이터는 **`GameSave`**
- 액터 공통 계약(`take_damage`/`apply_knockback`/`apply_slow`/`_play_anim`) 유지, Game 콜백 패턴 따름
- 새 카드: `STAT_CARDS`/`CARD_AXIS`/`CARD_CATEGORY_MAP` + `_apply_card` + Loc 텍스트 함께 등록

### 문서 (정본 3층 분리)
- **기획서(무엇이 정해졌나)** ↔ **README/devlog(왜·결정 로그)** ↔ **메모리(인계 요약)**
- 전투 설계 단일 진실 = `MainPlay/`, 로비 = `Lobby/`, 세계관 = `세계관_기획.md`
- 코드를 바꾸면 대응 정본 문서도 같이 갱신

### 톤 (콘텐츠)
- **블랙코미디**: 등장인물은 전원 진지, 웃음은 상황의 부조리에서. "자뻑 허세" 금지
- **글로벌 타깃**: 한국 전용 농담·말장난 금지

## 4. 문서 인덱스
| 문서 | 내용 |
|---|---|
| [docs/아키텍처.md](./docs/아키텍처.md) | 디렉토리·환경·클래스 다이어그램 |
| [docs/게임루프_상태관리.md](./docs/게임루프_상태관리.md) | 씬 전환·웨이브 루프·상태 3계층 |
| [기획문서.md](./기획문서.md) · [로드맵.md](./로드맵.md) · [세계관_기획.md](./세계관_기획.md) | GDD·로드맵·세계관 |
| [MainPlay/README.md](./MainPlay/README.md) | 전투 기능 7분류 설계 정본 |
| [Lobby/README.md](./Lobby/README.md) | 로비 D1~D7 설계 정본 |

## 5. 알려진 부채
- `SkeletonWarrior._evolve()`/`evolves`/`kill_count`: MD6(진화 폐기)로 **제거 대상**
- `Game.gd`(~1,534줄)·`Lobby.gd` 비대 → 분리 여지(후순위)
- 루트 `craftpix-*/`·`build/`: `.gitignore` 추가 권장
