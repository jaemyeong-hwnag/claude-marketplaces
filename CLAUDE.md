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
| 어디에 두고 어떻게 배포하는가 | 저장소 `.claude/hooks/` | `public`/`internal` 배치, marketplace 등록, 설치 동기화 |

플러그인에 저장소 정책을 넣지 않는다. 저장소 정책 스크립트에 이름 규칙을 넣지 않는다.

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
- 디렉터리는 `.claude-plugin` · `skills` · `hooks` · `scripts` · `commands` · `references` · `agents` · `test` 만 쓴다.
- `hooks/` 는 매니페스트(`*.json`)만, 실행 코드는 `scripts/*.sh` 에 둔다. 문서 모음은 `docs/` 가 아니라 `references/` 다.
- `skills/` 아래에는 스킬 디렉터리만 두고 각 디렉터리에 `SKILL.md` 가 있어야 한다. 스킬 디렉터리 안쪽은 자유다.
- `plugin.json` 의 `name` 은 디렉터리명과 같아야 한다.
- 설계 메모·작업 문서는 플러그인 안이 아니라 `.agent-tasks/<주제>/` 에 둔다.
- 마켓플레이스 루트 `.claude-plugin/` 에는 `marketplace.json` `tags.json` `categories.json` `plugins.json` `keywords.json` 만 둔다.

## 버전 관리 규칙

규칙은 `plugin-versioning` 플러그인이 강제한다.

- 규칙 원본: `internal-plugins/plugin-versioning/references/versioning-rules.md`

요약 — 충돌하면 규칙 원본이 우선한다.

- 버전은 `MAJOR.MINOR.PATCH` 세 자리다. `v` 접두사·prerelease·build·선행 0 을 쓰지 않는다.
- 신규 플러그인은 `0.1.0` 부터 시작한다. `0.0.x` 는 쓰지 않는다.
- `plugin.json` 의 현재 버전이 `CHANGELOG.md` 에 `## {버전}` 항목으로 있어야 한다. 항목은 내림차순이고 `## 미출시` 는 맨 위에만 온다.
- marketplace 엔트리가 `version` 을 선언하면 `plugin.json` 과 같아야 한다. 어긋나면 **엔트리를 고친다** — 설치 시점에는 `plugin.json` 이 이긴다.
- 릴리즈 태그는 `{플러그인명}--v{버전}` 이다. `claude plugin tag --push` 가 형식과 정합성을 함께 본다.
- 올림 등급(PATCH/MINOR/MAJOR)은 기계가 판정하지 않는다. `version-update` 스킬이 판단한다.

훅은 두 갈래다. `PreToolUse` 는 버전 값이 그 자체로 틀렸을 때만 차단하고, CHANGELOG 정합성은 `PostToolUse` 로 알리기만 한다.
버전을 올리고 CHANGELOG 를 쓰는 데 두 번의 편집이 필요하므로 첫 편집부터 막으면 아무것도 못 한다.

## 작업 규칙

- 이름을 정하거나 바꿀 때는 `name-create` 스킬을 따른다.
- 플러그인 디렉터리를 만들거나 구성요소를 추가할 때는 `plugin-directory-create` 스킬을 따른다.
- 사전을 고칠 때는 `glossary-update` 스킬을 따른다. 임의로 편집하지 않는다.
- 버전을 올리거나 릴리즈할 때는 `version-update` 스킬을 따른다.
- 이름 검토는 `/naming-review` 또는 `naming-reviewer` 에이전트를 쓴다.
- 구조 검토는 `/directory-structure-validate` 를 쓴다.
- 버전 검토는 `/versioning-validate` 를 쓴다.
- 새로 막을 단어가 생기면 스크립트가 아니라 `glossary.json` 에 추가한다.
- 이름 규칙을 고쳤으면 `internal-plugins/plugin-naming/test/validate-naming.test.sh` 를 돌린다.
- 구조 규칙을 고쳤으면 `internal-plugins/marketplace-directory-structure/test/validate-directory-structure.test.sh` 를 돌린다.
- 버전 규칙을 고쳤으면 `internal-plugins/plugin-versioning/test/validate-versioning.test.sh` 를 돌린다.
- 배치·배포 정책을 고쳤으면 `test/validate-plugin-scope.test.sh` 를 돌린다.
- 동기화 훅을 고쳤으면 `test/sync-internal-plugins.test.sh` 를 돌린다.
- 조항을 추가했으면 해당 쪽 TC 도 같이 추가한다.

## 내부 플러그인 자동 설치

`internal-plugins/` 하위 플러그인은 세션 시작 시 `.claude/hooks/sync-internal-plugins.sh` 가 확인한다.
마켓플레이스 등록 → `marketplace.json` 등록 → `settings.json` 활성화 → 실제 설치 순으로 점검하고 빠진 것을 채운다.
멱등하며, 실패해도 세션을 막지 않고 보고만 한다.

이 저장소는 마켓플레이스를 로컬 디렉터리(`.`) 소스로 등록한다. 커밋·푸시는 필요 없다.
다만 설치본은 `~/.claude/plugins/cache/` 로 복사되므로 **고친 내용은 다음 세션부터 적용된다.**
훅이 설치본과 작업 트리를 비교해 어긋나면 재설치한다 (`claude plugin update` 는 버전이 같으면 갱신하지 않는다).

`public-plugins/` 를 설치하는 다른 저장소는 같은 마켓플레이스를 github 소스로 등록하며, 그쪽은 푸시된 커밋만 읽는다.

내부 플러그인을 추가할 때는 디렉터리와 `.claude-plugin/plugin.json` 만 만들면 된다. 나머지 등록은 훅이 한다.

## 플러그인 추가 절차

1. `name-create` 스킬로 이름을 정한다.
2. 배포용은 `public-plugins/<이름>/`, 내부용은 `internal-plugins/<이름>/` 에 만든다.
3. `.claude-plugin/plugin.json` · `README.md` · `CHANGELOG.md` 를 작성한다 (셋 다 필수). 초기 버전은 `0.1.0` 이고 CHANGELOG 에 `## 0.1.0` 항목이 있어야 한다.
   - 배포용: `.claude-plugin/marketplace.json` 에 `category: "public"` 으로 직접 등록하고, 커밋·푸시해야 배포된다.
   - 내부용: SessionStart 훅이 등록·활성화·설치를 자동으로 한다.
4. 테스트와 전체 검증을 돌린다.

마켓플레이스 이름은 `claude` 로 시작할 수 없다. 공식 마켓플레이스 사칭으로 거부된다.

## 검증

```bash
internal-plugins/plugin-naming/scripts/validate-naming.sh --all .   # 저장소 전체 이름
internal-plugins/plugin-naming/scripts/validate-naming.sh --glossary # 사전 구조
internal-plugins/marketplace-directory-structure/scripts/validate-directory-structure.sh --all .  # 디렉터리 구조
internal-plugins/plugin-versioning/scripts/validate-versioning.sh --all .  # 버전 정합성
.claude/hooks/validate-plugin-scope.sh .                             # 배치·배포 정책
test/validate-plugin-scope.test.sh                                   # 배치 정책 TC 10건
test/sync-internal-plugins.test.sh                                   # 동기화 훅 TC 14건
internal-plugins/plugin-naming/test/validate-naming.test.sh          # 이름 규칙 회귀 테스트 (TC 86건)
internal-plugins/marketplace-directory-structure/test/validate-directory-structure.test.sh  # 구조 규칙 회귀 테스트 (TC 39건)
internal-plugins/plugin-versioning/test/validate-versioning.test.sh  # 버전 규칙 회귀 테스트 (TC 91건)
```

`Write` / `Edit` 에 훅이 걸려 있어 규칙을 어기는 이름으로는 파일이 만들어지지 않는다.
훅이 막으면 이름을 우회하지 말고 사전이 지시한 단어로 바꾼다.

## 산출물

- 문서는 `.md` 로 만든다. 웹 페이지·아티팩트로 만들지 않는다.
- 진행 중인 피처 문서는 `.agent-tasks/<주제>/*.md` 에 둔다 (git 미추적).
