# claude-marketplaces

Claude Code 플러그인 마켓플레이스 저장소. 마켓플레이스 이름은 `plugin-marketplace` 다.

| 경로 | 성격 | 배포 | 반영 시점 |
|---|---|---|---|
| [`public-plugins/`](public-plugins) | 배포용 플러그인 | github 마켓플레이스 | 커밋·푸시해야 반영 |
| [`internal-plugins/`](internal-plugins) | 이 저장소가 내부에서 쓰는 플러그인 | 하지 않음 | 로컬 디렉터리 소스. 고치면 세션 시작 시 재설치 |

둘 다 같은 `.claude-plugin/marketplace.json` 에 등록되고, `category` (`public` / `internal`) 로 구분한다.
디렉터리와 선언이 어긋나면 `.claude/hooks/validate-plugin-scope.sh` 가 막는다 — 미등록, `category` 불일치, `source` 불일치, 유령 항목.

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .     # 검증기 · 회귀 테스트 · claude plugin validate 전부
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick . # 스킬 발동 · 훅 차단 eval (모델 호출, 게시 안 함)
```

> 이름은 `plugin-naming`, 디렉터리 구조는 `marketplace-directory-structure`, 버전은 `plugin-versioning`, 파일 내용 형식은 `plugin-authoring`, 의존 관계는 `plugin-dependency`, 개발 플로우는 `plugin-workflow`, 배치·등록은 저장소 `.claude/hooks/` 가 담당한다. 서로 섞지 않는다.

## 수록 플러그인

| 이름 | 위치 | 설명 |
|---|---|---|
| [`plugin-naming`](internal-plugins/plugin-naming) | `internal-plugins/` | 플러그인·스킬·커맨드·에이전트 이름을 네이밍 규칙과 glossary 사전으로 강제한다 |
| [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) | `internal-plugins/` | 마켓플레이스 루트와 플러그인의 디렉터리 구조를 강제한다 |
| [`plugin-versioning`](internal-plugins/plugin-versioning) | `internal-plugins/` | 버전 값과 CHANGELOG · marketplace 엔트리 · git 태그의 정합성을 강제한다 |
| [`plugin-authoring`](internal-plugins/plugin-authoring) | `internal-plugins/` | 스킬·커맨드·에이전트 프런트매터와 README 절 구성 · 실제 구성요소의 일치를 강제한다 |
| [`plugin-dependency`](internal-plugins/plugin-dependency) | `internal-plugins/` | 플러그인 사이의 의존 관계(순환 · 층 · 경계 · 범위 겹침)를 강제한다 |
| [`plugin-workflow`](internal-plugins/plugin-workflow) | `internal-plugins/` | 이슈에서 릴리즈까지의 개발 플로우(템플릿 · 브랜치 · main 보호 · 머지 · 태그)를 강제한다 |

## 배포용 플러그인 설치 (다른 저장소에서)

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install <이름>@plugin-marketplace
```

프로젝트에 고정하려면 `.claude/settings.json` 에 넣는다.

```json
{
  "extraKnownMarketplaces": {
    "plugin-marketplace": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": { "<이름>@plugin-marketplace": true }
}
```

github 소스는 **푸시된 커밋만 읽는다.** `public-plugins/` 를 고쳤으면 푸시해야 배포된다.

## 이 저장소에서 작업할 때

`internal-plugins/` 하위 플러그인은 **세션 시작 시 자동으로 확인·설치된다.**
`.claude/settings.json` 의 SessionStart 훅이 [`sync-internal-plugins.sh`](.claude/hooks/sync-internal-plugins.sh) 를 실행해서

1. 마켓플레이스가 등록돼 있는지
2. `marketplace.json` 에 각 플러그인이 등록돼 있는지
3. `settings.json` 에서 활성화돼 있는지
4. 실제로 설치돼 있는지

5. 설치본이 작업 트리와 같은지

를 확인하고 빠진 것을 채운다. 커밋·푸시는 필요 없다.

> 마켓플레이스를 로컬 디렉터리로 등록했으므로 플러그인은 캐시가 아니라 **소스 디렉터리에서 그대로** 로드된다 — 훅 스크립트도 `internal-plugins/…` 에서 돈다.
> 다만 훅 · 스킬 · 커맨드 · 에이전트 목록은 세션 시작 때 읽으므로 **매니페스트나 목록을 바꾸면 다음 세션부터 적용된다.**
> `~/.claude/plugins/cache/` 의 사본은 `claude plugin list` 가 가리키는 설치 기록이고, 훅이 소스와 어긋나면 재설치해 맞춰 둔다.

```bash
.claude/hooks/sync-internal-plugins.sh   # 수동 실행도 된다
```

## 네이밍 규칙

플러그인을 추가하기 전에 규칙을 읽는다. 규칙은 `plugin-naming` 이 훅으로 강제하므로, 어기는 이름으로는 파일이 만들어지지 않는다.

- 규칙: [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md)
- 사전: [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json)

```bash
internal-plugins/plugin-naming/scripts/validate-naming.sh --all .   # 저장소 전체 이름
internal-plugins/plugin-naming/test/validate-naming.test.sh          # 이름 규칙 회귀 테스트
```

## 디렉터리 구조 규칙

어떤 파일을 어디에 두는지는 `marketplace-directory-structure` 가 훅으로 강제한다. 규칙에 없는 위치에는 파일이 만들어지지 않는다.

- 규칙: [`directory-structure-rules.md`](internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md)

```bash
internal-plugins/marketplace-directory-structure/scripts/validate-directory-structure.sh --all .
internal-plugins/marketplace-directory-structure/test/validate-directory-structure.test.sh
```

## 버전 관리 규칙

버전 값과 그 값이 남는 자리(`plugin.json` · `CHANGELOG.md` · marketplace 엔트리 · git 태그)의 정합성은 `plugin-versioning` 이 강제한다.

- 규칙: [`versioning-rules.md`](internal-plugins/plugin-versioning/references/versioning-rules.md)

```bash
internal-plugins/plugin-versioning/scripts/validate-versioning.sh --all .
internal-plugins/plugin-versioning/test/validate-versioning.test.sh
```

올림 등급(PATCH/MINOR/MAJOR)은 기계가 판정하지 않는다. `version-update` 스킬이 판단한다.
릴리즈 태그는 `claude plugin tag --push` 로 만든다 — `{플러그인명}--v{버전}` 형식과 엔트리 정합성을 CLI 가 함께 검증한다.

## 작성 · 의존성 · 개발 플로우

| 관심사 | 플러그인 | 규칙 원본 |
|---|---|---|
| 파일 안의 형식 — 프런트매터, description, README 템플릿 | `plugin-authoring` | [`authoring-rules.md`](internal-plugins/plugin-authoring/references/authoring-rules.md) |
| 플러그인 사이의 의존 — 순환, common · 번들, public → internal 금지 | `plugin-dependency` | [`dependency-rules.md`](internal-plugins/plugin-dependency/references/dependency-rules.md) |
| 이슈 → 브랜치 → PR → 머지 → 릴리즈 | `plugin-workflow` | [`workflow-rules.md`](internal-plugins/plugin-workflow/references/workflow-rules.md) |

이슈 폼과 PR 템플릿은 GitHub 가 읽는 자리인 [`.github/`](.github) 에 있다 — `feature` · `bugfix` 두 가지.

## 플러그인 추가 절차

개발 플로우의 "작업" 단계 안에서 한다 (`issue-create` → … → `release-create`).

1. 이름을 정한다 (`name-create` 스킬).
2. 배포용은 `public-plugins/<이름>/`, 내부용은 `internal-plugins/<이름>/` 에 만든다 (`plugin-directory-create` 스킬).
3. `.claude-plugin/plugin.json` · `README.md` · `CHANGELOG.md` 를 작성한다. 초기 버전은 `0.1.0` 이고 CHANGELOG 에 그 항목이 있어야 한다.
   - 배포용: `marketplace.json` 에 `category: "public"` 으로 등록하고 푸시한다.
   - 내부용: SessionStart 훅이 알아서 등록·설치한다.
4. README 를 템플릿대로 쓴다 (`document-create` 스킬). 의존성이 있으면 `dependency-update` 스킬.
5. `verify-all.sh` 로 전부 돌린다.

> 마켓플레이스 이름은 `claude` 로 시작할 수 없다. 공식 마켓플레이스 사칭으로 거부된다.
