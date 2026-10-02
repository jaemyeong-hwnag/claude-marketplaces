# claude-marketplaces

Claude Code 플러그인 마켓플레이스 저장소. 마켓플레이스 이름은 `jaemyeong-hwnag-plugins` 다.

이 문서는 **매번 알아야 하는 것**만 담는다. 규칙의 세부는 각 플러그인의 규칙 원본에 있고, 그 작업을 할 때는 해당 스킬을 쓴다.
규칙 원본과 이 문서가 다르면 규칙 원본이 맞다.

## 디렉터리

| 경로 | 성격 | 배포 | 반영 |
|---|---|---|---|
| `public-plugins/` | 배포용 플러그인 | github 마켓플레이스 | 커밋 · 푸시해야 다른 저장소가 받는다 |
| `internal-plugins/` | 이 저장소가 쓰는 플러그인 | 하지 않음 | 다음 세션 시작 때 (아래 "내부 플러그인") |
| `.claude/hooks/` | 저장소 정책 훅 (배치 · 등록 · 설치 동기화) | - | 세션 시작 때 |
| `.github/` | 이슈 폼 · PR 템플릿 (`feature` · `bugfix`) | - | main 에 있어야 GitHub 가 읽는다 |
| `test/` | 저장소 정책 훅의 회귀 테스트 | - | - |
| `.agent-tasks/<주제>/` | 설계 메모 · 작업 문서 (git 미추적) | - | - |

## 관심사와 담당

한 관심사는 한 곳이 맡는다. 플러그인에 저장소 정책을 넣지 않고, 저장소 정책 스크립트에 이름 규칙을 넣지 않는다.

| 관심사 | 담당 | 규칙 원본 (따로 적지 않으면 `internal-plugins/…`) | 작업할 때 쓰는 스킬 | 검토 |
|---|---|---|---|---|
| 이름 | `plugin-naming` | `plugin-naming/references/naming-rules.md` · `glossary.json` | `name-create` · `glossary-update` | `/naming-review` · `naming-reviewer` |
| 파일 위치 | `marketplace-directory-structure` | `…/references/directory-structure-rules.md` | `plugin-directory-create` | `/directory-structure-validate` |
| 버전 · CHANGELOG · 태그 | `plugin-versioning` | `plugin-versioning/references/versioning-rules.md` | `version-update` | `/versioning-validate` |
| 파일 내용 형식 (프런트매터 · README) | `plugin-authoring` | `plugin-authoring/references/authoring-rules.md` | `document-create` | `/authoring-validate` |
| 플러그인 사이의 의존 | `plugin-dependency` | `plugin-dependency/references/dependency-rules.md` | `dependency-update` | `/dependency-validate` |
| 이슈 → 브랜치 → PR → 머지 (`W-01` ~ `W-10`) | `github-workflow` (public) | `public-plugins/github-workflow/references/workflow-rules.md` | `issue-create` · `pull-request-create` · `pull-request-merge` · `github-template-create` | `/workflow-validate` |
| 버전 · 설치 확인 · 태그 · 릴리즈, 생성 · 삭제 절차 | `plugin-workflow` | `plugin-workflow/references/workflow-rules.md` | `release-create` · `plugin-create` · `plugin-delete` | `verify-all.sh` |
| 배치 · 등록 · 설치 동기화 | 저장소 `.claude/hooks/` | 아래 "마켓플레이스 등록" · `test/README.md` | - | `.claude/hooks/validate-plugin-scope.sh .` |

규칙은 `Write` · `Edit` · `Bash` 훅이 막거나 알린다. **훅이 막으면 우회하지 말고 메시지가 지시한 대로 고친다** (이름이면 사전이 지시한 단어로). 새로 막을 단어는 스크립트가 아니라 `glossary.json` 에 넣는다.

## 개발 플로우

모든 변경은 이 경로로 main 에 들어간다.

```
이슈 → 워크트리 · 브랜치 → 작업 → 버전 → 검증 · 테스트 → 리베이스 후 재검증 → PR
→ 머지 → main 에서 설치 확인 → 태그 · 릴리즈 → 정리
```

- 이슈 · 라벨 · 브랜치 · PR 템플릿 · 커밋 타입을 `feature` / `bugfix` 한 단어로 맞춘다. 브랜치는 `{feature|bugfix}/{이슈}-{slug}` 이고 `origin/main` 에서 딴다 (`github-workflow` 의 `branch-create.sh`). `develop` 은 없다
- 워크트리는 `.claude/worktrees/{이슈}-{slug}` 에 둔다
- 파일을 바꾼 플러그인은 버전을 올린다. **CHANGELOG 먼저**, 그다음 `plugin.json`
- PR 전에 `verify-all.sh` 를 돌리고, `origin/main` 위로 리베이스한 **뒤에 다시** 돌린다
- 머지는 머지 커밋(`gh pr merge --merge`)만. main 에 직접 커밋 · 머지 · 푸시하지 않고, 강제 푸시는 `--force-with-lease` 만 쓴다
- 태그는 main 에서, 머지하고 설치를 확인한 뒤에 단다 (`release-plugins.sh`)
- **머지 · 태그 푸시 · 릴리즈 · 이슈 · 라벨은 원격에 남는다. 사용자 확인 없이 처음 하지 않는다**
- 저장소가 비공개 + 무료라 GitHub 브랜치 보호를 켤 수 없다. 위 규칙은 Claude 가 실행하는 명령에서만 막힌다 — 웹 UI 는 막지 못한다

## 마켓플레이스 등록

`.claude/hooks/validate-plugin-scope.sh` 가 강제한다 (세션 시작 때도 돈다). 이 정책을 맡는 스킬은 없다.

- `category` 는 배치다 — 디렉터리와 같은 `public` / `internal` (`.claude-plugin/categories.json`)
- 주제 분류는 `tags` 로 — `.claude-plugin/tags.json` 에 있는 것만, 2개까지, 2개면 `domain` 1 + `technology` 1. 새 태그는 그 태그로 묶일 플러그인이 3개 이상일 때 추가한다
- 엔트리 `description` 은 `plugin.json` 과 같다. `version` · `author` 는 엔트리에 쓰지 않는다
- `common-*` 은 `public-plugins/` 에만 둔다
- 배포용은 엔트리를 직접 등록한다. 내부용은 등록하지 않는다 — 세션 시작 훅이 한다
- internal 이 의존하는 public 플러그인은 `.claude/settings.json` `enabledPlugins` 에 `true` 로 커밋한다 — 없으면 설치 뒤 main 이 더러워진다
- 마켓플레이스 이름은 `claude` 로 시작할 수 없다 (공식 마켓플레이스 사칭으로 거부된다)

## 내부 플러그인

세션 시작 때 `.claude/hooks/sync-internal-plugins.sh` 가 `internal-plugins/*` 를 마켓플레이스 · `marketplace.json` · `settings.json` 에 등록하고 설치한 뒤 로드 오류를 보고한다. 멱등하고, 실패해도 세션을 막지 않는다.
내부 플러그인을 새로 만들 때는 디렉터리와 `.claude-plugin/plugin.json` 만 있으면 나머지는 이 훅이 한다.
public 플러그인은 이 훅이 설치하지 않는다. internal 이 `dependencies` 로 선언하면 Claude Code 가 같이 설치 · 활성화한다 (`plugin-workflow` → `github-workflow`).

**로드 방식** — 마켓플레이스를 로컬 디렉터리로 등록했으므로 플러그인은 **캐시가 아니라 소스 디렉터리에서 그대로** 로드된다 (세션 init 의 플러그인 경로와 훅 스크립트 경로가 `internal-plugins/…` 다).

- 훅 · 스킬 · 커맨드 · 에이전트 목록은 세션 시작 때 읽는다 — 매니페스트나 목록을 바꾸면 **다음 세션부터** 반영된다
- 소스 경로는 마켓플레이스가 등록된 **메인 체크아웃**이다. 워크트리 세션에서도 main 의 플러그인이 돈다 — 워크트리에서 고친 플러그인은 머지 뒤 반영된다
- `~/.claude/plugins/cache/` 의 사본은 `claude plugin list` 가 가리키는 설치 기록이다. 훅이 소스와 어긋나면 재설치해 맞춰 둔다

**끄기와 지우기** — `settings.json` 의 `enabledPlugins` 를 `false` 로 두면 훅이 되돌리지 않는다. 디렉터리를 지우면 엔트리 · 활성화 키 · 설치 기록을 훅이 치운다 (`plugin-delete` 스킬).

## 겪어서 아는 함정

| 함정 | 결과 | 대책 |
|---|---|---|
| `plugin.json` 에 `"hooks": "./hooks/hooks.json"` | 자동 로드와 중복돼 **그 플러그인의 훅이 전부 꺼진다**. `validate --strict` 도 통과한다 | 적지 않는다 (구조 `P-09`). 설치 뒤 `claude plugin list --json` 의 `errors` 를 본다 |
| 검증 스크립트의 `*/.claude/…` 제외 패턴 | 루트가 워크트리 안이면 전부 제외돼 **아무것도 검사하지 않고 통과** | 제외는 루트 기준(`"$root/.claude/…"`)으로 쓴다 |
| macOS 기본 bash 3.2 | 연관 배열 없음, 빈 배열 확장이 `set -u` 로 죽음, `;;&` · `source <(…)` 안 됨, `=~` 가 `BASH_REMATCH` 를 덮어씀 | 그래프 계산은 jq, 빈 배열은 `${a+"${a[@]}"}`, 캡처는 함수 호출 전에 받는다 |
| 탭 구분 `read` | 빈 칸이 합쳐져 뒤 칸이 밀린다 | 공백이 아닌 구분자(`\x1f`) |
| `ls` 에 글롭 여럿 | 하나만 없어도 실패 | 파일마다 `-e` |
| 테스트 픽스처가 늘 모든 구성요소를 가짐 | "하나만 있을 때" 결함을 못 본다 | 구성요소를 하나씩 빼는 TC 를 따로 둔다 |
| 스킬 description | 매 세션 상시 비용 (스킬 하나 ~250 토큰) | 300자 이내 (작성 `A-05`) |
| `claude plugin eval` | 기본값이 리포트를 claude.ai 에 **게시** | 항상 `--no-publish` (`eval-all.sh` 가 붙인다) |
| `dependencies` 가 있는 플러그인의 eval | eval 은 격리된 설정으로 돌아 설치한 플러그인이 하나도 안 보인다 — 의존 대상을 **어느 범위에 설치해도** inline 로드가 `dependency-unsatisfied` 로 실패하고 결과는 **Skill 0x** 로만 보인다 (`plugin_errors` 는 trace 에만) | 작업 트리에서 `dependencies` 를 잠시 빼고 돌린 뒤 되돌린다. 커밋하지 않는다 |
| eval 그레이더 `regex` | JS 정규식이라 `(?i)` 같은 인라인 플래그가 **grader threw** 로 실패한다 | `[Hh]istogram` 처럼 문자 클래스로 쓴다 |

## 검증

PR 전에는 전부 한 번에 돌린다 — 검증기 · 회귀 테스트 · `claude plugin validate --strict` 를 경로 규칙으로 찾아 한 줄씩 요약한다.

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .
```

규칙이나 스크립트를 고쳤으면 그 플러그인의 `test/*.test.sh` 부터 돌리고, 조항을 추가했으면 TC 도 같이 추가한다 (TC 명세는 각 `test/README.md`).
저장소 훅을 고쳤으면 `test/validate-plugin-scope.test.sh` · `test/sync-internal-plugins.test.sh`.

스킬 발동 · 훅 차단은 eval 로 본다. 모델을 실제로 부르므로 비용이 든다 (빠른 모드 약 $2).

```bash
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick .   # 케이스당 1회
internal-plugins/plugin-workflow/scripts/eval-all.sh .           # 케이스당 3회 + 플러그인 없는 기준선과 비교
```

Bash 가 필요한 eval 케이스는 Bash 샌드박스가 있어야 돈다. Docker Desktop 의 `~/.docker/cli-plugins` 링크가 있는 머신에서는 ⚠️ 환경 제한으로 표시된다.

## 산출물

- 문서는 `.md` 로 만든다. 웹 페이지 · 아티팩트로 만들지 않는다.
- 진행 중인 설계 문서는 `.agent-tasks/<주제>/*.md` 에 둔다 (git 미추적).
