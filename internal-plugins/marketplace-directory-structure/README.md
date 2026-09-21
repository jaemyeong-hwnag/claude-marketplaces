# marketplace-directory-structure

마켓플레이스 루트와 개별 플러그인의 **디렉터리 구조**를 강제한다.

다루는 것은 **무엇을 어디에 두는가** 하나뿐이다. 이름이 올바른지(`plugin-naming`), public 인지 internal 인지와 등록이 맞는지(저장소 `.claude/hooks/`)는 이 플러그인의 관심사가 아니다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다. 다른 곳에서 쓰려면 `public-plugins/` 로 옮긴다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| plugin-directory-create | 플러그인 만들기, 구성요소를 어디에 둘지 | 디렉터리 구조 규칙대로 플러그인과 구성요소를 만든다 |
| /directory-structure-validate | 직접 호출 | 루트와 모든 플러그인의 구조를 검증한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-directory-structure.sh | PreToolUse (Write\|Edit) | 플러그인 안의 경로가 규칙에 없는 위치면 **차단** |

## 파일

| 경로 | 역할 |
|---|---|
| `references/directory-structure-rules.md` | 구조 규칙 원본. 단일 기준 (`R-0x` 루트 / `P-0x` 플러그인) |
| `scripts/validate-directory-structure.sh` | 기계 검증. 훅과 CLI 겸용 |
| `test/` | 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 위치 안내 스킬 발동 · `docs/` 차단. `plugin-workflow` 의 `eval-all.sh` 로 돈다 |

## 동작

`Write` / `Edit` 시 경로가 플러그인 안(`*plugins/<이름>/...`)이면 **그 위치에 그 파일을 둘 수 있는지** 검사하고, 위반이면 종료 코드 2 로 차단한다.

| 경로 | 결과 |
|---|---|
| `internal-plugins/order-sync/scripts/run.sh` | 통과 |
| `internal-plugins/order-sync/hooks/run.sh` | 차단 — `hooks/` 는 매니페스트(`*.json`)만 |
| `internal-plugins/order-sync/docs/guide.md` | 차단 — 알 수 없는 디렉터리 |
| `internal-plugins/order-sync/NOTES.md` | 차단 — 루트에는 README·CHANGELOG·LICENSE·.gitignore 만 |
| `.agent-tasks/order/plan.md` | 반응하지 않음 |

훅은 **위치만** 본다. 필수 파일이 다 있는지(`README.md`, `CHANGELOG.md`, `SKILL.md` …)는 파일을 하나씩 만드는 도중에는 판정할 수 없으므로 CLI 전체 검사에서 본다.

## CLI

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" --all .            # 루트 + 모든 플러그인
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" --marketplace .    # 루트만
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" internal-plugins/order-sync
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" internal-plugins/order-sync/docs/guide.md
```

종료 코드: `0` 통과 / `2` 위반 / `1` 실행 오류.

## 규칙 요약

충돌하면 [`references/directory-structure-rules.md`](references/directory-structure-rules.md) 가 우선한다.

플러그인 루트: `.claude-plugin/plugin.json` · `README.md` · `CHANGELOG.md` 는 필수.

| 디렉터리 | 둘 수 있는 것 |
|---|---|
| `.claude-plugin/` | `plugin.json` |
| `skills/` | `{skill-name}/SKILL.md` (디렉터리 안쪽은 자유) |
| `hooks/` | `*.json` |
| `scripts/` | `*.sh` |
| `commands/` | `*.md` |
| `references/` | `*.md` `*.json` |
| `agents/` | `*.md` |
| `test/` | `*.test.sh` `README.md` |

마켓플레이스 루트: `.claude-plugin/marketplace.json` · `README.md` · `CHANGELOG.md` 필수, `.claude-plugin/` 에는 `marketplace.json` `tags.json` `categories.json` `plugins.json` `keywords.json` 만, 플러그인은 `public-plugins/<이름>/` · `internal-plugins/<이름>/` 바로 아래에만.

## 테스트

```bash
test/validate-directory-structure.test.sh          # 전체
test/validate-directory-structure.test.sh TC-D1    # ID 접두사로 필터
```

TC 명세는 [`test/README.md`](test/README.md).

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
