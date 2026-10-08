# claude-marketplaces

Claude Code 플러그인 마켓플레이스 저장소. 마켓플레이스 이름은 `jaemyeong-hwnag-plugins` 다.

- **플러그인을 쓰려는 사람** — [처음 시작하기](#처음-시작하기) · [플러그인 찾기](#플러그인-찾기) · [필요한 플러그인 자동 설치](#필요한-플러그인-자동-설치) · [수록 플러그인](#수록-플러그인)
- **이 저장소에 기여하는 사람** — [이 저장소에서 작업할 때](#이-저장소에서-작업할-때) 부터

## 처음 시작하기

필요한 것: Claude Code, `bash`, `jq`.

**1. 마켓플레이스를 추가한다** (컴퓨터마다 한 번)

Claude Code 세션 안에서:

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
```

**2. 조회 · 설치 플러그인을 설치한다**

```
/plugin install plugin-search-install@jaemyeong-hwnag-plugins
```

설치 범위를 묻는다 — 팀이 같은 설정을 받게 하려면 `project`, 나만 쓰려면 `user`. 이 플러그인이 다른 플러그인을 찾고 설치해 준다 (로컬 MCP 서버 `plugin-search` 포함).

**3. Claude Code 를 다시 시작한다**

플러그인과 MCP 서버는 세션을 시작할 때 로드된다. `/mcp` 에 `plugin-search` 가 보이면 끝이다.

> 터미널에서는 같은 일을 `claude plugin marketplace add …` · `claude plugin install … --scope project` 로 한다.

## 플러그인 찾기

대상은 **이 마켓의 public 플러그인**이다 ([수록 플러그인](#수록-플러그인)).

### Claude 에게 말로

| 하고 싶은 것 | 이렇게 말한다 |
|---|---|
| 기능으로 찾기 | "테스트 커버리지 올려주는 플러그인 있어?" |
| 연관된 것 찾기 | "github-workflow 랑 비슷하거나 같이 쓰는 플러그인 보여줘" |
| 무엇이 있는지 둘러보기 | "어떤 플러그인들이 있는지 태그별로 보여줘" |
| 한 플러그인 자세히 | "java-naming 은 어떤 스킬이랑 훅이 있어?" |

Claude 가 `plugin-search` MCP 도구(또는 `plugin-search` 스킬)로 찾아 이유와 함께 보여 준다.

### 질의 문법 (정밀하게 찾을 때)

| 형태 | 뜻 | 예 |
|---|---|---|
| `단어` | 이름 · 설명 · 태그 · 키워드 · 스킬 · 훅 · MCP 어디서든 | `naming` |
| `필드:값` | 그 필드에서만 | `tag:spring` · `tech:spring` · `domain:development` · `skill:issue-create` |
| `-단어` | 빼기 | `naming -java` |
| `a\|b` | 둘 중 하나 | `github\|gitlab` |
| `has:종류` | 구성요소가 있는 것 | `has:hook` · `has:mcp` |
| `is:상태` | 설치 여부 | `is:not-installed` |

동의어(한 · 영) · 한글 조사 · 오타를 허용한다 — "네이밍" 으로도 `naming` 이 찾아진다. 전체 문법은 [`search-rules.md`](public-plugins/plugin-search-install/references/search-rules.md).

### 터미널 화면으로

표 · 카드로 보면서 화살표 · 스페이스로 골라 설치하려면 [`plugin-browser`](public-plugins/plugin-browser) 를 설치한다.

```
/plugin install plugin-browser@jaemyeong-hwnag-plugins
```

터미널(Claude 밖)에서:

```bash
PB="$(claude plugin list --json | jq -r '[.[] | select(.id=="plugin-browser@jaemyeong-hwnag-plugins")][0].installPath')/scripts/plugin-browser.sh"
bash "$PB"                        # 메뉴 — 프로젝트 · 기능 검색 · 연관 · 태그 · 설치된 것
bash "$PB" search 테스트 커버리지
```

## 필요한 플러그인 자동 설치

프로젝트 폴더에서 Claude 에게 말한다.

```
이 프로젝트에 필요한 플러그인 설치해줘
```

1. 세 갈래로 찾아 근거와 함께 보여 준다
   - **필수** — 프로젝트 `.claude/settings.json` 에 선언됐는데 설치되지 않은 것, 그것들이 기대는 플러그인
   - **추천** — 파일 신호로 고른 것 (예: `build.gradle` + Spring → `java-spring-*`, `.github/` → `github-workflow`)
2. 설치 계획을 먼저 보여 준다 — **바로 설치하지 않는다**
3. "전부" · "1번 3번만" · "추천은 빼고" · "조회만" 중 고르면 그대로 설치한다 (기본 범위 `project`)
4. Claude Code 를 다시 시작하면 로드된다

### CLI 로 (스크립트 · CI)

```bash
PSI="$(claude plugin list --json | jq -r '[.[] | select(.id=="plugin-search-install@jaemyeong-hwnag-plugins")][0].installPath')/scripts/plugin-search-install.sh"

"$PSI" project . --format tsv                          # 필요한 것 보기 (필수 + 추천, 근거 포함)
"$PSI" project . --only declared > /tmp/need.json      # 필수(선언 · 의존)만
"$PSI" install --from /tmp/need.json --all --dry-run   # 계획 — 이미 설치된 것은 건너뜀
"$PSI" install --from /tmp/need.json --all             # 설치
"$PSI" project . > /tmp/all.json && "$PSI" install --from /tmp/all.json --select 1,3-5   # 번호로 골라서
```

### 팀 전체가 같은 플러그인을 쓰게 하기

프로젝트의 `.claude/settings.json` 에 마켓과 플러그인을 적어 커밋한다. 팀원은 마켓을 추가한 뒤 "이 프로젝트에 필요한 플러그인 설치해줘" 한 번으로 받는다 — 여기 적힌 것이 **필수**로 잡힌다.

```json
{
  "extraKnownMarketplaces": {
    "jaemyeong-hwnag-plugins": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": {
    "plugin-search-install@jaemyeong-hwnag-plugins": true,
    "<이름>@jaemyeong-hwnag-plugins": true
  }
}
```

### 업데이트 · 문제 해결

```
/plugin marketplace update jaemyeong-hwnag-plugins     # 새 플러그인 · 새 버전 받기
```

| 증상 | 해결 |
|---|---|
| `/mcp` 에 `plugin-search` 가 없다 | Claude Code 를 다시 시작한다. 그래도 없으면 `claude plugin list` 의 `Error:` 를 본다 |
| 도구가 "jq 가 필요합니다" | `brew install jq` (macOS) · `apt install jq` |
| `…@plugin-marketplace` 로 설치돼 있다 | 예전 마켓 이름이다 — `claude plugin marketplace remove plugin-marketplace` 뒤 1단계부터 |
| 찾는 플러그인이 안 나온다 | 이 마켓의 **public** 만 대상이다. 다른 마켓 · internal 은 나오지 않는다 |

## 수록 플러그인

설치: `/plugin install <이름>@jaemyeong-hwnag-plugins`

| 분야 | 플러그인 | 하는 일 |
|---|---|---|
| 플러그인 찾기 · 설치 | [`plugin-search-install`](public-plugins/plugin-search-install) | 이 마켓의 public 플러그인 검색 · 연관 · 프로젝트에 필요한 것 · 설치. 로컬 MCP 서버 포함 |
| | [`plugin-browser`](public-plugins/plugin-browser) | 위 결과를 터미널 화면(표 · 카드 · 화살표 선택)으로 |
| 코드 네이밍 | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | 언어 공식 가이드가 정한 이름 모양을 훅으로 막고, 단어 선택은 스킬이 판단 |
| 테스트 | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) | Spring Boot 변경 메서드를 `@AiTest` 로 덮고 JaCoCo 100% 게이트 |
| 부하 · 성능 | [`common-stress-test`](public-plugins/common-stress-test) | 부하 테스트를 정량으로 설계 · 판정 (운영 호스트 차단 · 지속 가능 용량 · 회귀 통계). 언어 무관 |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | 프레임워크별 서버 계측 · 측정을 무효로 만드는 설정 탐지 · 마이크로벤치마크 |
| 프로젝트 품질 | [`project-completeness`](public-plugins/project-completeness) | 서비스로서 갖출 것을 갖췄는지 진단 · 적용 · 운영 지표 판정 |
| 문서 | [`domain-document-sync`](public-plugins/domain-document-sync) | 도메인 지식 문서를 3계층으로 두고 코드 변경과 맞춰 둔다 |
| GitHub 플로우 | [`github-workflow`](public-plugins/github-workflow) | 이슈 → 이슈 번호 브랜치 → PR → 머지 커밋 → 태그 흐름을 강제 |

이 저장소 개발에만 쓰는 internal 플러그인 — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-workflow`](internal-plugins/plugin-workflow).

## 이 저장소에서 작업할 때

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

> 이름은 `plugin-naming`, 디렉터리 구조는 `marketplace-directory-structure`, 버전은 `plugin-versioning`, 파일 내용 형식은 `plugin-authoring`, 의존 관계는 `plugin-dependency`, GitHub 플로우는 `github-workflow`, 플러그인 릴리즈 단계는 `plugin-workflow`, 배치·등록은 저장소 `.claude/hooks/` 가 담당한다. 서로 섞지 않는다.

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
| 이슈 → 브랜치 → PR → 머지 | `github-workflow` | [`workflow-rules.md`](public-plugins/github-workflow/references/workflow-rules.md) |
| 버전 · 설치 확인 · 태그 · 릴리즈 (위 흐름에 더하는 단계) | `plugin-workflow` | [`workflow-rules.md`](internal-plugins/plugin-workflow/references/workflow-rules.md) |

이슈 폼과 PR 템플릿은 GitHub 가 읽는 자리인 [`.github/`](.github) 에 있다 — `feature` · `bugfix` 두 가지.

## 플러그인 추가 절차

개발 플로우의 "작업" 단계 안에서 한다 (`issue-create` → … → `pull-request-merge` · `release-create`).

1. 이름을 정한다 (`name-create` 스킬).
2. 배포용은 `public-plugins/<이름>/`, 내부용은 `internal-plugins/<이름>/` 에 만든다 (`plugin-directory-create` 스킬).
3. `.claude-plugin/plugin.json` · `README.md` · `CHANGELOG.md` 를 작성한다. 초기 버전은 `0.1.0` 이고 CHANGELOG 에 그 항목이 있어야 한다.
   - 배포용: `marketplace.json` 에 `category: "public"` 으로 등록하고 푸시한다.
   - 내부용: SessionStart 훅이 알아서 등록·설치한다.
4. README 를 템플릿대로 쓴다 (`document-create` 스킬). 의존성이 있으면 `dependency-update` 스킬.
5. `verify-all.sh` 로 전부 돌린다.

> 마켓플레이스 이름은 `claude` 로 시작할 수 없다. 공식 마켓플레이스 사칭으로 거부된다.

## 라이선스

[MIT](LICENSE)
