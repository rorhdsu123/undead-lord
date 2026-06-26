# 병렬 작업 영역 (도메인 오너십)

> Game.gd 분리(2026-06-26 일단락) 결과를 **병렬 작업 단위**로 정리.
> 한 사람/세션 = 한 도메인. 자기 도메인 파일만 건드리면 **서로 충돌(클로버) 없음**.

## 도메인 ↔ 담당 파일

| 도메인 | 작업 파일(.md) | 담당 코드 |
|---|---|---|
| 카드/키스톤 | [카드.md](./카드.md) | `scripts/CardSystem.gd` · `scripts/data/CardData.gd` · `Loc.gd` card_* |
| 상점 | [상점.md](./상점.md) | `scripts/ShopController.gd` · `scripts/data/ShopData.gd` |
| 마물(소환) | [마물.md](./마물.md) | `scripts/MinionSystem.gd` · `scripts/data/MinionData.gd` |
| 강화 | [강화.md](./강화.md) | `scripts/UpgradeSystem.gd` |
| 웨이브 트래커 | [웨이브트래커.md](./웨이브트래커.md) | `scripts/WaveTracker.gd` |
| 결과 화면 | [결과화면.md](./결과화면.md) | `scripts/ResultScreen.gd` |

> 미분리(아직 Game.gd 본체): VFX(BattleFX)·자원HUD·튜토리얼·코어(웨이브/성/보스/마왕). 이건 분리 전까지 단일 작업.

## 공통 규칙 (모든 도메인)

1. **자기 파일만 수정.** 다른 도메인 `.gd`·Game.gd 본체는 건드리지 않는다.
2. **공유 상태·노드는 `game.X`로만** 읽기/쓰기 (Game 소유 — GS2). 컴포넌트에 새 상태가 정말 필요하면 그 컴포넌트 안에 `var`로.
3. **외부(액터/다른 컴포넌트)가 부를 함수**를 새로 추가하면 → `Game.gd`에 위임 한 줄(facade) 추가 (GS3). 이 한 줄이 유일한 Game.gd 접점.
4. **검증** (커밋 전 필수):
   ```bash
   godot --headless --quit-after 5 scenes/Game.tscn 2>&1 \
     | grep -iE "error|not found|nonexistent|invalid|expected"
   # 빈 출력 = OK. (timeout 명령 쓰지 말 것 — 이 셸에 없음)
   ```
5. **런타임 동작은 에디터 플테**로 확인 (scene load는 파싱·_ready만).

## 커밋 · 푸시 (병렬 작업 필수 주의)

> 도메인이 파일로 분리됐어도, **커밋을 잘못하면 남의 작업을 덮어쓴다.** 아래는 클로버 재발 방지의 핵심.

1. **`git add -A` / `git commit -a` 금지.** 반드시 **자기 도메인 파일만** 스테이징:
   ```bash
   git add scripts/CardSystem.gd scripts/data/CardData.gd   # 내 도메인만
   ```
   작업트리에 다른 사람의 미커밋 변경이 섞여 있을 수 있다 → `-A`로 쓸어 담으면 남의 작업을 내 커밋에 끌고 들어감.
2. **푸시 전 항상 동기화:**
   ```bash
   git pull --rebase origin <브랜치>   # 남의 커밋 먼저 받고 그 위에 내 것
   ```
   바로 push 하면 거절(non-fast-forward)되거나, 강제하면 남의 커밋 유실.
3. **`Game.gd`를 만졌으면 특히 조심.** facade 추가·`_ready` 컴포넌트 생성 등으로 두 도메인이 동시에 Game.gd를 건드리면 충돌 가능 →
   - Game.gd 변경은 **최소(facade 1줄)**로,
   - 만졌으면 **즉시 작은 단위로** 커밋·푸시(오래 들고 있지 말 것),
   - 한 파일에 두 도메인이 섞였으면 헝크 분리 커밋(`git add -p` 또는 `git apply --cached`로 내 헝크만).
4. **검증 통과 후 커밋** (godot 직접 로드 에러 0).
5. **커밋 메시지에 도메인 명시** (예: `feat(카드): 연쇄낙뢰 사슬 +1`) — 누가 뭘 건드렸는지 추적.
6. **같은 도메인은 한 번에 한 사람.** 두 사람이 같은 `.gd`를 동시에 = 분리해도 클로버. 도메인 단위로 나눠 맡는다.

## 컴포넌트 패턴 (참고)

- 각 컨트롤러는 `extends Node`, Game의 자식. `var game` 으로 허브 역참조.
- `Game._ready`: `x = XScript.new(); add_child(x); x.setup(self)`.
- 공유 상태(souls·castle·키스톤 등)는 **전부 Game이 소유**, 컴포넌트는 `game.souls`처럼 접근.
- 정본 설계: [docs/Game_분리_계획.md](../docs/Game_분리_계획.md) · [docs/아키텍처.md](../docs/아키텍처.md)
