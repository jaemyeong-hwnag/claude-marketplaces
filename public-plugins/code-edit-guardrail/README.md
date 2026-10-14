# code-edit-guardrail

Claude 가 코드를 고칠 때 넘지 말아야 할 선을 프로젝트 설정 하나로 강제한다 — 언어 무관. 코드를 고치고 테스트를 안 고치면 완료 차단, 고친 경로의 린트 · 포맷 · 타입 검사 명령 실패 시 완료 차단, 공유자원 편집은 사용자 확인.

엔진은 플러그인 훅이 돌리고, 프로젝트에는 설정 파일 하나만 둔다. 스크립트를 프로젝트에 복사하지 않으므로 플러그인을 업데이트하면 모든 프로젝트에 같이 반영된다.

```json
{
  "test":    { "code": ["src/main/**"], "tests": ["src/test/"] },
  "quality": [{ "name": "api", "paths": ["src/**"], "command": "./gradlew ktlintCheck" }],
  "shared":  { "paths": ["db/migration/"] }
}
```

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install code-edit-guardrail@jaemyeong-hwnag-plugins --scope project
```

설치한 뒤 "가드레일 설정해줘" 로 `code-edit-guardrail-apply` 를 불러 `.claude/code-edit-guardrail.json` 을 만든다. 설정이 없는 동안 훅은 아무것도 하지 않는다.

필요한 것: `jq`. 없으면 훅이 조용히 통과한다 (fail-open).

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| code-edit-guardrail-apply | 테스트 없이 못 끝내게 · 끝날 때 린트 · 마이그레이션 고치면 확인 · 가드레일 설정 | 스택을 감지해 코드 · 테스트 글롭과 품질 lane 을 채우고, 공유자원은 후보만 내 사용자가 확정한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| code-edit-guardrail.sh reset | UserPromptSubmit | 이번 요청의 편집 기록 · 면제를 비운다 |
| code-edit-guardrail.sh shared | PreToolUse (Edit\|Write\|MultiEdit) | 공유자원 경로 · 내용 패턴에 걸리면 **사용자 확인** (`G-03`) |
| code-edit-guardrail.sh track | PostToolUse (Edit\|Write\|MultiEdit\|NotebookEdit) | 고친 파일을 기록한다 |
| code-edit-guardrail.sh stop | Stop | 코드만 고치고 테스트를 안 고쳤으면 (`G-01`), 고친 경로의 품질 lane 이 실패하면 (`G-02`) 완료를 **차단**. 한 번 되돌린 뒤에는 경고만 |

## 주의

- 판정 단위는 한 요청이다. Claude 의 편집 도구로 바꾼 파일만 본다 — Bash 로 바꾼 파일(코드 생성기 · `sed`)은 보지 않는다. git 과 무관하다
- `G-01` 은 "테스트 파일을 하나라도 고쳤는가" 만 본다. 커버리지는 보지 않는다
- 동작이 그대로인 변경은 사용자에게 알린 뒤 면제한다 — 차단 메시지에 면제 파일 경로가 나온다. 면제는 그 요청에만 유효하다
- 편집 기록 · 면제 파일은 프로젝트의 `.claude/code-edit-guardrail/` 에 둔다. 스스로 ignore 하므로 커밋되지 않는다
- 품질 lane 은 Stop 마다 돈다. 전체 빌드 · 테스트가 아니라 빠른 검사 명령을 쓴다 (시간 제한 600초)
- 설정 경로는 환경 변수 `CODE_EDIT_GUARDRAIL_CONFIG` 로 바꿀 수 있다 (기본 `.claude/code-edit-guardrail.json`)
- 시크릿 · 코드 ↔ 문서 동기는 다루지 않는다

## 무엇을 막나

| | 조항 |
|---|---|
| 게이트 (훅) | `G-01` 테스트 동반 · `G-02` 품질 lane · `G-03` 공유자원 확인 |
| 설정 (`validate`) | `C-01` 파일 · JSON · `C-02` 최상위 키 · `C-03` 절 모양 · `C-04` 정규식 · `C-05` 걸리는 파일 없는 글롭 (경고) |

## 파일

| 경로 | 역할 |
|---|---|
| `references/code-edit-guardrail-rules.md` | 규칙 원본 — 설정 형식, 글롭 문법, 조항, 면제 |
| `scripts/code-edit-guardrail.sh` | 훅 네 모드 + CLI `validate` |
| `test/` | 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 설정 스킬 발동(`guardrail-config-request`) · 테스트 없는 완료 차단(`test-missing-blocked`) |

## 사용

```bash
scripts/code-edit-guardrail.sh validate .   # 설정 검증
test/code-edit-guardrail.test.sh            # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
