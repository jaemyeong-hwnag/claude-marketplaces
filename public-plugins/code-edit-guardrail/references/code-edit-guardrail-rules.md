# 코드 편집 가드레일 규칙 (단일 원본)

Claude 가 코드를 고칠 때 넘지 말아야 할 선을 정한다. 기계 판정은 [`scripts/code-edit-guardrail.sh`](../scripts/code-edit-guardrail.sh).

다루지 않는 것 — 시크릿(`git-secret-validate`), 코드 ↔ 문서 동기(`domain-document-sync`), 커버리지 수치(`java-spring-aitest-coverage`), CI · 린트 설정을 처음 까는 것(`project-completeness`).

## 1. 설정

프로젝트의 `.claude/code-edit-guardrail.json` 하나. 커밋한다. 경로는 환경 변수 `CODE_EDIT_GUARDRAIL_CONFIG` 로 바꿀 수 있다 (상대 경로면 프로젝트 루트 기준).

```json
{
  "test": {
    "code": ["src/**/*.ts", "!src/**/*.d.ts"],
    "tests": ["**/*.test.ts", "test/"]
  },
  "quality": [
    { "name": "web", "paths": ["web/"], "command": "npm --prefix web run lint" },
    { "name": "api", "paths": ["api/**/*.kt"], "command": "./gradlew ktlintCheck" }
  ],
  "shared": {
    "paths": ["db/migration/", "proto/"],
    "content": ["DROP[[:space:]]+TABLE"]
  }
}
```

| 키 | 없으면 | 뜻 |
|---|---|---|
| `test.code` · `test.tests` | `G-01` 꺼짐 | 테스트가 따라와야 하는 코드 · 테스트로 치는 파일 |
| `quality[]` | `G-02` 꺼짐 | lane 마다 `name`(kebab-case) · `paths` · `command` |
| `shared.paths` · `shared.content` | `G-03` 꺼짐 | 공유자원 경로 글롭 · 새 내용에서 찾을 정규식 (ERE · Oniguruma) |

설정이 없으면 훅은 아무것도 하지 않는다. 플러그인을 깔기만 한 저장소는 막히지 않는다.

### 글롭

| 형식 | 뜻 |
|---|---|
| 앞이나 가운데에 `/` 가 있다 (`src/**/*.ts` · `/Makefile`) | 프로젝트 루트 기준 |
| `/` 가 없거나 끝에만 있다 (`*.ts` · `test/`) | 어느 깊이든 |
| 끝이 `/` (`test/`) | 그 디렉터리 아래 전부 |
| `*` · `?` | `/` 를 넘지 않는 0자 이상 · 1자 |
| `**/` · `**` | 디렉터리 0개 이상 · 무엇이든 |
| `!` 접두사 | 같은 목록에서 뺀다 |

테스트 글롭에 걸린 파일은 코드 글롭에 걸려도 코드로 치지 않는다.

## 2. 게이트

편집 기록은 PostToolUse 가 프로젝트의 `.claude/code-edit-guardrail/<세션>.edits` 에 쌓고, UserPromptSubmit 가 비운다. 그래서 판정 단위는 **한 요청**이고 git 과 무관하다. Bash 로 바꾼 파일(코드 생성기 · `sed`)은 기록되지 않는다.

| 조항 | 시점 | 내용 | 판정 |
|---|---|---|---|
| `G-01` | Stop | 이번 요청에서 `test.code` 파일을 고쳤는데 `test.tests` 파일을 하나도 안 고쳤다 | 차단 |
| `G-02` | Stop | 이번 요청에서 고친 파일이 lane 의 `paths` 에 걸리면 그 lane 의 `command` 를 루트에서 stdin 없이 돌린다. 0 이 아니면 출력 끝 20줄과 함께 | 차단 |
| `G-03` | PreToolUse (`Edit` · `Write` · `MultiEdit`) | 고칠 파일이 `shared.paths` 에 걸리거나 새 내용이 `shared.content` 에 걸린다 | 사용자 확인 (`ask`) |

- `G-01` · `G-02` 가 한 번 막은 뒤 다시 멈출 때(`stop_hook_active`)는 경고만 하고 완료를 허용한다 — 무한 반복을 막는다
- `G-02` 는 경로가 안 걸린 lane 을 돌리지 않는다. 다른 스택만 고친 요청은 비용 0 이다
- `G-02` 명령은 Stop 훅 시간 제한(600초) 안에 끝나야 한다. 전체 빌드 대신 바뀐 파일만 보는 명령을 쓴다
- `G-03` 의 `Edit` 내용 검사는 `new_string` 만 본다. 파일 전체가 아니다

### 면제 — G-01

동작이 그대로인 변경(리팩터 · 포맷 · 주석 · 이름만 바꿈)은 사용자에게 알린 뒤 면제한다. 차단 메시지에 나온 파일에 사유를 남긴다.

```bash
echo 'test: 포맷만 바꿈' >> ".claude/code-edit-guardrail/<세션>.ack"
```

상태 디렉터리는 프로젝트 안이라 Bash 샌드박스에서도 쓸 수 있고, 스스로 만든 `.gitignore` 로 git status 에 나오지 않는다. 경로는 `CODE_EDIT_GUARDRAIL_STATE_DIR` 로 바꿀 수 있다.

사유가 빈 `test:` 는 면제가 아니다. 면제는 그 요청에만 유효하다. `G-02` 는 면제가 없다 — 명령을 고치거나 lane 을 고친다.

## 3. 설정 검증

```bash
scripts/code-edit-guardrail.sh validate [루트]
```

| 조항 | 내용 | 판정 |
|---|---|---|
| `C-01` | 설정 파일이 있고 올바른 JSON 이다 | 차단 |
| `C-02` | 최상위는 객체이고 키는 `test` · `quality` · `shared` 뿐이다 | 차단 |
| `C-03` | 각 절의 모양 — 문자열 배열은 비지 않는다, `test` 는 `code` · `tests` 둘 다, lane 은 `name`(kebab-case · 유일) · `paths` · `command`, `shared` 는 `paths` · `content` 중 하나 이상. 알 수 없는 키 금지 | 차단 |
| `C-04` | `shared.content` 가 올바른 정규식이다 | 차단 |
| `C-05` | `!` 가 아닌 글롭이 저장소 파일(git 이면 `ls-files -co --exclude-standard`)에 하나도 안 걸린다 | 경고 |

훅은 설정이 깨져 있어도 막지 않는다 — 읽을 수 없으면 조용히 통과한다. 설정을 바꾼 뒤에는 `validate` 를 돌린다.

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `code-edit-guardrail.sh` | `G-01` ~ `G-03`, `C-01` ~ `C-05` |
| 판단 | AI (`code-edit-guardrail-apply`) | 어느 글롭이 코드 · 테스트인가, 어떤 명령이 빠르고 결정적인가, 무엇이 공유자원인가(후보만 내고 사용자가 확정), 면제가 정당한가 |
