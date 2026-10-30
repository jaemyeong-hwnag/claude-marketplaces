# plugin-enforcement-effectiveness

플러그인이 훅 설정 · 에이전트 프런트매터 · 규칙 원본에 적어 둔 강제가 **실행에서 알림 없이 꺼지지 않았는지** 재현해 막는다.

차단 훅의 스크립트가 없거나 실행 권한이 없거나 상대 경로면 훅은 실패하고 도구 호출은 그대로 통과한다. 플러그인 에이전트의 `permissionMode` · `hooks` · `mcpServers` 는 무시된다. `claude plugin validate --strict` 는 이것들을 모두 통과시킨다 (규칙 원본 5절에 재현 명령).

형식은 `plugin-authoring`, 파일 위치는 `marketplace-directory-structure`, 생성 순서는 `plugin-workflow` 가 본다. 여기서는 형식이 맞아도 **실행에서 효력이 없는 것**을 본다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| enforcement-effectiveness-review | 플러그인 구성 · 역할 분리 · 훅이 실제로 막는지 검토 | 스크립트 → 검토 에이전트 → 지적 재현 확인 → 보고 |
| /enforcement-effectiveness-validate | 직접 호출 | 저장소 전체를 훅 · MCP 실행까지 포함해 검증한다 |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| enforcement-effectiveness-reviewer | 역할 분리(`EF-40` ~ `EF-44`)를 작성 맥락 없이 판정하고 지적마다 재현 명령을 붙인다. 파일을 고치지 않는다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-enforcement-effectiveness.sh | PreToolUse (Write) | 쓰려는 `hooks.json` · `plugin.json` · 에이전트 · 스킬 · 커맨드가 파일 하나로 판정되는 조항을 어기면 **차단** (`EF-01` · `EF-04` · `EF-10` · `EF-11` · `EF-13`). `onFailure: "block"` |
| validate-enforcement-effectiveness.sh | PostToolUse (Write\|Edit) | 플러그인 파일 저장 뒤 그 플러그인 전체를 검사해 **알림** |

## 파일

| 경로 | 역할 |
|---|---|
| `references/enforcement-effectiveness-rules.md` | 규칙 원본 — 조항, 판정 시점, 근거와 재현 명령 |
| `scripts/validate-enforcement-effectiveness.sh` | 기계 검증. 훅과 CLI 겸용 |
| `test/` | 회귀 테스트 · 변이 테스트 결과와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 무시되는 에이전트 필드 차단 · 검토 스킬 발동. `plugin-workflow` 의 `eval-all.sh` 로 돈다 |

## 무엇을 막나

| | 조항 |
|---|---|
| 강제 사슬 | `EF-01` 상대 경로 · `EF-02` 가리키는 파일 · `EF-03` 실행 권한 · `EF-04` matcher 를 받지 않는 이벤트 · `EF-05` 조항 ID ↔ TC · `EF-06` 조항이 있으면 검증기 · 훅 · `EF-07` `onFailure: "block"` (`--since` 만 차단) |
| 선언 적용 | `EF-10` 무시되는 에이전트 필드 · `EF-11` `tools` 선언 · `EF-12` 편집 도구 (경고) · `EF-13` 커맨드 · 스킬 이름 충돌 |
| 실행 | `EF-20` 무관한 입력에 훅 실행 (경고) · `EF-21` MCP `initialize` · `EF-22` 지시한 MCP 도구 이름 |
| eval | `EF-30` trigger · hook 케이스 · `EF-31` 스킬별 발동 그레이더 (`--since` 새 플러그인만 차단) |

## 기존 플러그인에 바로 걸지 않는 이유

`EF-07` · `EF-31` 은 `--all` 에서 경고다. 2026-10-30 기준 `onFailure` 가 없는 훅이 26개, 발동 그레이더가 없는 스킬이 17개다 — 한 번에 고치면 대부분의 플러그인 버전이 오른다.
`verify-all.sh` 가 `--since origin/main` 도 돌리므로 **새로 만들거나 고친 플러그인**에서 차단된다 (`EF-31` 은 새 플러그인만).

## 사용

저장소 루트에서 실행한다. `--all` 이 플러그인을 하나도 찾지 못하면 실행 오류(종료 코드 `1`)다. `--all` · `--since` 는 훅 스크립트와 MCP 서버를 임시 디렉터리에서 실제로 실행한다 (`--no-run` 이면 건너뛴다).

```bash
S=internal-plugins/plugin-enforcement-effectiveness
$S/scripts/validate-enforcement-effectiveness.sh $S                          # 플러그인 하나 (실행 검사 없음)
$S/scripts/validate-enforcement-effectiveness.sh --all .                     # 저장소 전체
$S/scripts/validate-enforcement-effectiveness.sh --since origin/main .       # 바뀐 플러그인만
$S/test/validate-enforcement-effectiveness.test.sh                           # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
