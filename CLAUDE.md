# claude-marketplaces

Claude Code 플러그인 마켓플레이스 저장소. 마켓플레이스 이름은 `plugin-marketplace` 다.

## 디렉터리 구분

| 경로 | 성격 | 배포 | 반영 시점 |
|---|---|---|---|
| `public-plugins/` | 배포용 플러그인 | github 마켓플레이스 | 커밋·푸시해야 반영 |
| `internal-plugins/` | 이 저장소가 내부에서 쓰는 플러그인 | 하지 않음 | 로컬 디렉터리 소스. 고치면 세션 시작 시 재설치 |

배포할 플러그인은 `public-plugins/` 에, 이 저장소에서만 쓸 플러그인은 `internal-plugins/` 에 둔다.
둘 다 같은 `.claude-plugin/marketplace.json` 에 등록되며 `category` (`public` / `internal`) 로 구분한다.
디렉터리와 `category` · `source` 가 어긋나면 `.claude/hooks/validate-plugin-scope.sh` 가 막는다.

## 관심사 분리

| 관심사 | 담당 | 범위 |
|---|---|---|
| 이름이 올바른가 | `plugin-naming` 플러그인 | kebab-case, 단어 사전, 줄임말. 배포·배치는 모른다 |
| 어떤 파일을 어디에 두는가 | `marketplace-directory-structure` 플러그인 | 마켓플레이스 루트와 플러그인의 디렉터리 구조. 이름·배포는 모른다 |
| 버전을 어떻게 매기는가 | `plugin-versioning` 플러그인 | 버전 값, CHANGELOG, marketplace 엔트리, git 태그의 정합성. 이름·구조는 모른다 |
| 파일 안을 어떤 형식으로 쓰는가 | `plugin-authoring` 플러그인 | 스킬·커맨드·에이전트 프런트매터, 본문·참조 크기, README 절과 실제 구성요소의 일치. 위치는 모른다 |
| 누가 누구에 기대도 되는가 | `plugin-dependency` 플러그인 | 존재·순환·common 과 번들의 층·마켓플레이스 경계·범위 겹침. 범위 문자열 형식은 모른다 |
| 변경이 어떤 경로로 반영되는가 | `plugin-workflow` 플러그인 | 이슈·PR 템플릿, 브랜치 이름, main 보호, 머지 방식, 태그 위치. 파일 내용은 모른다 |
| 어디에 두고 어떻게 배포하는가 | 저장소 `.claude/hooks/` | `public`/`internal` 배치, marketplace 등록, 설치 동기화 |

플러그인에 저장소 정책을 넣지 않는다. 저장소 정책 스크립트에 이름 규칙을 넣지 않는다.

## 마켓플레이스 등록 규칙

`.claude/hooks/validate-plugin-scope.sh` 가 강제한다 (SessionStart 에도 돈다).

- `category` 는 배치다 — `public` / `internal`, `.claude-plugin/categories.json` 에 있어야 한다.
- 주제 분류는 `tags` 로 한다 — `.claude-plugin/tags.json` 에 있는 것만, 2개까지, 2개면 `domain` 1 + `technology` 1.
- 새 태그는 그 태그로 묶일 플러그인이 3개 이상일 때 추가한다.
- 엔트리 `description` 은 `plugin.json` 과 같다. 내부 플러그인은 sync 훅이 맞춘다.
- `version` · `author` 는 엔트리에 쓰지 않는다 (`plugin.json` 이 원본).
- `common-*` 플러그인은 `public-plugins/` 에만 둔다.
- 이름 목록 파일(`plugins.json`)은 두지 않는다. `marketplace.json` 이 원본이다.

## 네이밍 규칙

규칙은 `plugin-naming` 플러그인이 강제한다. 이 저장소에서는 SessionStart 훅이 설치 상태를 확인·복구하므로 항상 켜져 있다.

- 규칙 원본: `internal-plugins/plugin-naming/references/naming-rules.md`
- 단어 사전: `internal-plugins/plugin-naming/references/glossary.json`

요약 — 충돌하면 규칙 원본이 우선한다.

- 플러그인·스킬·커맨드·에이전트 이름은 kebab-case 로 쓴다.
- 패턴은 `{대상}-{관심사}` / 공통은 `common-{관심사}` / 번들은 `{역할}-standard`.
- 한 단어짜리 이름은 쓰지 않는다. 언어명(`java`)·프레임워크명(`spring`)·범용 단어(`utils`) 단독 사용 금지가 여기에 포함된다.
- 같은 단어를 이름 안에서 두 번 쓰지 않는다.
- 줄임말은 금지한다. 예외는 사전에 `use` 로 등록된 공식·업계 표준 약어뿐이다.
- 사전의 `deny` 단어는 어떤 이름에도 쓰지 않는다.

## 디렉터리 구조 규칙

규칙은 `marketplace-directory-structure` 플러그인이 강제한다. `Write`/`Edit` 경로가 플러그인 안이면 그 위치에 그 파일을 둘 수 있는지 본다.

- 규칙 원본: `internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md`

요약 — 충돌하면 규칙 원본이 우선한다.

- 플러그인 루트에는 `README.md` · `CHANGELOG.md` · `LICENSE` · `.gitignore` 만 둔다. `.claude-plugin/plugin.json` · `README.md` · `CHANGELOG.md` 는 필수다.
- 디렉터리는 `.claude-plugin` · `skills` · `hooks` · `scripts` · `commands` · `references` · `agents` · `test` · `evals` 만 쓴다. `evals/` 에는 케이스 디렉터리(`prompt.md` 또는 `case.yaml`)만 둔다.
- `hooks/` 는 매니페스트(`*.json`)만, 실행 코드는 `scripts/*.sh` 에 둔다. 문서 모음은 `docs/` 가 아니라 `references/` 다.
- `skills/` 아래에는 스킬 디렉터리만 두고 각 디렉터리에 `SKILL.md` 가 있어야 한다. 스킬 디렉터리 안쪽은 자유다.
- `plugin.json` 의 `name` 은 디렉터리명과 같아야 한다.
- `plugin.json` 에 `"hooks": "./hooks/hooks.json"` 을 적지 않는다. 표준 경로는 자동 로드되고, 적으면 중복으로 **훅 로딩 전체가 실패한다.** `claude plugin validate --strict` 는 못 잡고 `claude plugin list` 의 Error 줄에만 나온다.
- 설계 메모·작업 문서는 플러그인 안이 아니라 `.agent-tasks/<주제>/` 에 둔다.
- 마켓플레이스 루트 `.claude-plugin/` 에는 `marketplace.json` `tags.json` `categories.json` `plugins.json` `keywords.json` 만 둔다.

## 버전 관리 규칙

규칙은 `plugin-versioning` 플러그인이 강제한다.

- 규칙 원본: `internal-plugins/plugin-versioning/references/versioning-rules.md`

요약 — 충돌하면 규칙 원본이 우선한다.

- 버전은 `MAJOR.MINOR.PATCH` 세 자리다. `v` 접두사·prerelease·build·선행 0 을 쓰지 않는다.
- 신규 플러그인은 `0.1.0` 부터 시작한다. `0.0.x` 는 쓰지 않는다.
- `plugin.json` 의 현재 버전이 `CHANGELOG.md` 에 `## {버전}` 항목으로 있어야 한다 (날짜는 선택: `## {버전} - YYYY-MM-DD`). 항목은 내림차순이고 `## 미출시` 는 맨 위에만 온다.
- marketplace 엔트리가 `version` 을 선언하면 `plugin.json` 과 같아야 한다. 어긋나면 **엔트리를 고친다** — 설치 시점에는 `plugin.json` 이 이긴다.
- 플러그인 파일을 바꿨으면 버전을 올린다 (`V-14`). PR 전에 `--since origin/main` 으로 본다.
- 버전을 올릴 때는 **CHANGELOG 먼저**, 그다음 `plugin.json`. `0.x` 에서는 호환성을 깨도 MINOR 를 올린다.
- 릴리즈 태그는 `{플러그인명}--v{버전}` 이고 **main 에서, 머지 뒤에** 단다. `claude plugin tag --push` 가 형식과 정합성을 함께 본다.
- 올림 등급(PATCH/MINOR/MAJOR)은 기계가 판정하지 않는다. `version-update` 스킬이 판단한다.

훅은 두 갈래다. `PreToolUse` 는 버전 값이 그 자체로 틀렸을 때만 차단하고, CHANGELOG 정합성은 `PostToolUse` 로 알리기만 한다.
버전을 올리고 CHANGELOG 를 쓰는 데 두 번의 편집이 필요하다. 순서를 거꾸로 밟는 경우까지 첫 편집부터 막으면 아무것도 못 한다.

## 작성 규칙

규칙은 `plugin-authoring` 플러그인이 강제한다. 규칙 원본: `internal-plugins/plugin-authoring/references/authoring-rules.md`

- 스킬 `name` 은 디렉터리명, 에이전트 `name` 은 파일명과 같다. 스킬·커맨드·에이전트는 `description` 이 있다.
- 스킬 description 에 "언제 쓰는가"(`~ 때 사용한다`)가 있다. 300자를 넘기지 않는다 — **매 세션 상시 비용**이다.
- SKILL.md 가 200줄을 넘으면 `references/` 로 나눈다. `skills/` · `references/` 에 외부 URL 을 쓰지 않는다.
- README 는 `# 이름` → `## 설치` → `## 의존성` → `## 포함된 스킬` / `에이전트` / `훅` → (자유 절) → `## 변경 이력` 순서다. **표는 실제 구성요소와 같아야 한다.**

## 의존성 규칙

규칙은 `plugin-dependency` 플러그인이 강제한다. 규칙 원본: `internal-plugins/plugin-dependency/references/dependency-rules.md`

- 층: `common` ← 언어/프레임워크별 ← 워크플로우 ← 번들(`*-standard`). 역방향·순환 금지.
- `common-*` 은 어떤 플러그인에도 의존하지 않는다. 번들은 `dependencies` 만 가지고 다른 번들에 기대지 않는다.
- 다른 마켓플레이스에 의존하지 않는다. `public-plugins/` 는 `internal-plugins/` 에 의존하지 않는다.
- 같은 대상을 여럿이 범위로 고정하면 범위가 겹쳐야 한다. 지우기 전에 `--dependents` 로 누가 기대는지 본다.

## 개발 플로우

규칙은 `plugin-workflow` 플러그인이 강제한다. 규칙 원본: `internal-plugins/plugin-workflow/references/workflow-rules.md`

```
이슈 → 워크트리·브랜치 → 작업 → 버전 → 검증 → 테스트 → 리베이스 후 재검증 → PR
→ 머지 → main 에서 설치 확인 → 태그·릴리즈 → 정리
```

- 이슈 · 라벨 · 브랜치 · PR 템플릿 · 커밋 타입은 `feature` / `bugfix` 한 단어로 맞춘다. 브랜치는 `{feature|bugfix}/{이슈}-{slug}`, `origin/main` 에서 딴다. `develop` 은 없다.
- 워크트리는 `.claude/worktrees/{이슈}-{slug}`. 워크트리 세션의 훅은 **main 의 규칙**이다 (설치 기준이 메인 체크아웃).
- PR 전에 `verify-all.sh` 를 돌리고, `origin/main` 위로 리베이스한 **뒤 다시** 돌린다. PR 은 템플릿 본문 + 라벨.
- 머지는 머지 커밋(`gh pr merge --merge`)만. main 에 직접 커밋·머지·푸시하지 않는다. 강제 푸시는 `--force-with-lease` 만.
- 태그는 main 에서, 머지하고 설치 확인한 뒤에 단다 (`release-plugins.sh`).
- 저장소가 비공개 + 무료라 GitHub 브랜치 보호를 켤 수 없다. 위 규칙은 Claude 가 실행하는 명령에서만 막힌다 — **웹 UI 는 막지 못한다.**
- 머지 · 태그 푸시 · 릴리즈 · 이슈 · 라벨은 원격에 남는다. 사용자 확인 없이 처음 하지 않는다.

## 작업 규칙

- 이름을 정하거나 바꿀 때는 `name-create` 스킬을 따른다.
- 플러그인 디렉터리를 만들거나 구성요소를 추가할 때는 `plugin-directory-create` 스킬을 따른다.
- 사전을 고칠 때는 `glossary-update` 스킬을 따른다. 임의로 편집하지 않는다.
- 버전을 올리거나 릴리즈할 때는 `version-update` 스킬을 따른다.
- SKILL.md · 커맨드 · 에이전트 · README 를 쓸 때는 `document-create` 스킬을 따른다.
- 의존성을 추가·변경·삭제할 때는 `dependency-update` 스킬을 따른다.
- 작업 시작은 `issue-create`, PR 은 `pull-request-create`, 머지·릴리즈는 `release-create` 스킬을 따른다.
- 플러그인을 새로 만들 때는 `plugin-create`, 지우거나 끌 때는 `plugin-delete` 스킬을 따른다. 위치만 정할 때는 `plugin-directory-create`.
- 이름 검토는 `/naming-review` 또는 `naming-reviewer` 에이전트를 쓴다.
- 구조 검토는 `/directory-structure-validate` 를 쓴다.
- 버전 검토는 `/versioning-validate` 를 쓴다.
- 작성 형식 검토는 `/authoring-validate`, 의존성 검토는 `/dependency-validate`, 플로우 상태는 `/workflow-validate` 를 쓴다.
- 새로 막을 단어가 생기면 스크립트가 아니라 `glossary.json` 에 추가한다.
- 이름 규칙을 고쳤으면 `internal-plugins/plugin-naming/test/validate-naming.test.sh` 를 돌린다.
- 구조 규칙을 고쳤으면 `internal-plugins/marketplace-directory-structure/test/validate-directory-structure.test.sh` 를 돌린다.
- 버전 규칙을 고쳤으면 `internal-plugins/plugin-versioning/test/validate-versioning.test.sh` 를 돌린다.
- 작성 규칙 · 의존성 규칙 · 플로우를 고쳤으면 각 플러그인의 `test/*.test.sh` 를 돌린다.
- 어느 것을 고쳤든 PR 전에는 `internal-plugins/plugin-workflow/scripts/verify-all.sh .` 로 전부 돌린다.
- 배치·배포 정책을 고쳤으면 `test/validate-plugin-scope.test.sh` 를 돌린다.
- 동기화 훅을 고쳤으면 `test/sync-internal-plugins.test.sh` 를 돌린다.
- 조항을 추가했으면 해당 쪽 TC 도 같이 추가한다.

## 내부 플러그인 자동 설치

`internal-plugins/` 하위 플러그인은 세션 시작 시 `.claude/hooks/sync-internal-plugins.sh` 가 확인한다.
마켓플레이스 등록 → `marketplace.json` 등록 → `settings.json` 활성화 → 실제 설치 → 로드 확인 순으로 점검하고 빠진 것을 채운다.
멱등하며, 실패해도 세션을 막지 않고 보고만 한다.

- `enabledPlugins` 에 키가 없을 때만 `true` 로 추가한다. **명시적 `false` 는 끈 것이다** — 되돌리지 않고 설치도 건너뛴다.
- 디렉터리를 지운 내부 플러그인은 엔트리 · 활성화 키 · 설치본을 훅이 치운다. 디렉터리만 지우면 된다.
- 내부 엔트리의 `description` 은 훅이 `plugin.json` 에 맞춘다.
- 끝에 `claude plugin list --json` 의 `errors` 를 보고한다 (못 받으면 텍스트의 `Error:` 줄) — 정적 검증이 못 잡는 로드 실패가 여기 나온다.

이 저장소는 마켓플레이스를 로컬 디렉터리(`.`) 소스로 등록한다. 커밋·푸시는 필요 없다.
다만 설치본은 `~/.claude/plugins/cache/` 로 복사되므로 **고친 내용은 다음 세션부터 적용된다.**
훅이 설치본과 **설치 기준 디렉터리**를 비교해 어긋나면 재설치한다 (`claude plugin update` 는 버전이 같으면 갱신하지 않는다).
설치 기준은 마켓플레이스가 등록된 경로(메인 체크아웃)다. 워크트리에서 고친 플러그인은 머지 뒤 반영된다.

`public-plugins/` 를 설치하는 다른 저장소는 같은 마켓플레이스를 github 소스로 등록하며, 그쪽은 푸시된 커밋만 읽는다.

내부 플러그인을 추가할 때는 디렉터리와 `.claude-plugin/plugin.json` 만 만들면 된다. 나머지 등록은 훅이 한다.

## 플러그인 추가 절차

개발 플로우(이슈 → 브랜치 → … → 릴리즈)의 "작업" 단계 안에서 한다.

1. `name-create` 스킬로 이름을 정한다.
2. 배포용은 `public-plugins/<이름>/`, 내부용은 `internal-plugins/<이름>/` 에 만든다.
3. `.claude-plugin/plugin.json` · `README.md` · `CHANGELOG.md` 를 작성한다 (셋 다 필수). 초기 버전은 `0.1.0` 이고 CHANGELOG 에 `## 0.1.0` 항목이 있어야 한다.
   - 배포용: `.claude-plugin/marketplace.json` 에 `category: "public"` 으로 직접 등록하고, 커밋·푸시해야 배포된다.
   - 내부용: SessionStart 훅이 등록·활성화·설치를 자동으로 한다.
4. README 를 템플릿대로 쓴다 (`document-create`). 의존성이 있으면 `dependency-update`.
5. `verify-all.sh` 로 전체 검증·테스트를 돌린다.

마켓플레이스 이름은 `claude` 로 시작할 수 없다. 공식 마켓플레이스 사칭으로 거부된다.

## 검증

```bash
internal-plugins/plugin-naming/scripts/validate-naming.sh --all .   # 저장소 전체 이름
internal-plugins/plugin-naming/scripts/validate-naming.sh --glossary # 사전 구조
internal-plugins/marketplace-directory-structure/scripts/validate-directory-structure.sh --all .  # 디렉터리 구조
internal-plugins/plugin-versioning/scripts/validate-versioning.sh --all .  # 버전 정합성
internal-plugins/plugin-versioning/scripts/validate-versioning.sh --since origin/main .  # 바뀐 플러그인의 버전 (V-14)
internal-plugins/plugin-authoring/scripts/validate-authoring.sh --all .    # 작성 형식
internal-plugins/plugin-dependency/scripts/validate-dependency.sh --all .  # 의존 관계
internal-plugins/plugin-workflow/scripts/validate-workflow.sh --templates . # 이슈·PR 템플릿
.claude/hooks/validate-plugin-scope.sh .                             # 배치·배포 정책
test/validate-plugin-scope.test.sh                                   # 배치·등록 정책 TC 29건
test/sync-internal-plugins.test.sh                                   # 동기화 훅 TC 37건
internal-plugins/plugin-naming/test/validate-naming.test.sh          # 이름 규칙 회귀 테스트 (TC 90건)
internal-plugins/marketplace-directory-structure/test/validate-directory-structure.test.sh  # 구조 규칙 회귀 테스트 (TC 54건)
internal-plugins/plugin-versioning/test/validate-versioning.test.sh  # 버전 규칙 회귀 테스트 (TC 125건)
internal-plugins/plugin-authoring/test/validate-authoring.test.sh    # 작성 규칙 회귀 테스트 (TC 74건)
internal-plugins/plugin-dependency/test/validate-dependency.test.sh  # 의존성 회귀 테스트 (TC 55건)
internal-plugins/plugin-workflow/test/validate-workflow.test.sh      # 개발 플로우 회귀 테스트 (TC 101건)
```

전부 한 번에 — 검증기 · 회귀 테스트 · `claude plugin validate --strict` 를 경로 규칙으로 찾아 돌리고 한 줄씩 요약한다:

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .
```

스킬 발동 · 훅 차단은 eval 로 본다 — 모델을 실제로 부르므로 비용이 든다 (빠른 모드 약 $2).

```bash
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick .   # 케이스당 1회
internal-plugins/plugin-workflow/scripts/eval-all.sh .           # 케이스당 3회 + 플러그인 없는 기준선과 비교
```

- 리포트는 **게시하지 않는다** (`--no-publish`). `claude plugin eval` 의 기본값은 claude.ai 게시다.
- 결과는 플러그인 밖(`$TMPDIR/plugin-evals/`)에 쓴다. 플러그인 안에 `results/` 가 생기면 sync 훅이 재설치한다.
- Bash 가 필요한 케이스는 Bash 샌드박스가 있어야 돈다. Docker Desktop 의 `~/.docker/cli-plugins` 링크가 있는 머신에서는 ⚠️ 환경 제한으로 표시된다.

`Write` / `Edit` 에 훅이 걸려 있어 규칙을 어기는 이름으로는 파일이 만들어지지 않는다.
훅이 막으면 이름을 우회하지 말고 사전이 지시한 단어로 바꾼다.

## 산출물

- 문서는 `.md` 로 만든다. 웹 페이지·아티팩트로 만들지 않는다.
- 진행 중인 피처 문서는 `.agent-tasks/<주제>/*.md` 에 둔다 (git 미추적).
