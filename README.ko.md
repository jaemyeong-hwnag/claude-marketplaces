# claude-marketplaces

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

Claude Code 플러그인 마켓플레이스 저장소. 마켓플레이스 이름은 `jaemyeong-hwnag-plugins` 다.

- **플러그인을 쓰려는 사람** — [처음 시작하기](#처음-시작하기) · [플러그인 찾기](#플러그인-찾기) · [필요한 플러그인 자동 설치](#필요한-플러그인-자동-설치) · [수록 플러그인](#수록-플러그인)
- **이 저장소에 기여하는 사람** — [이 저장소에서 작업할 때](#이-저장소에서-작업할-때)

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

설치: `/plugin install <이름>@jaemyeong-hwnag-plugins`. 플러그인마다 README 가 영어 · 한국어 · 중국어로 있다.

| 분야 | 플러그인 | 하는 일 |
|---|---|---|
| 플러그인 찾기 · 설치 | [`plugin-search-install`](public-plugins/plugin-search-install) | 이 마켓의 public 플러그인 검색 · 연관 · 프로젝트에 필요한 것 · 설치. 로컬 MCP 서버 포함 |
| | [`plugin-browser`](public-plugins/plugin-browser) | 위 결과를 터미널 화면(표 · 카드 · 화살표 선택)으로 |
| 코드 네이밍 | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | 언어 공식 가이드가 정한 이름 모양을 훅으로 막고, 단어 선택은 스킬이 판단 |
| 테스트 | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) · [`kotlin-spring-aitest-coverage`](public-plugins/kotlin-spring-aitest-coverage) | Java · Kotlin Spring Boot 변경 메서드를 `@AiTest` 로 덮고 JaCoCo 100% 게이트 |
| 코드 편집 가드레일 | [`code-edit-guardrail`](public-plugins/code-edit-guardrail) | 코드만 고치고 테스트를 안 고치면 · 고친 경로의 린트 · 포맷 검사가 실패하면 완료 차단, 공유자원 편집은 사용자 확인. 언어 무관 |
| 검증 · 리뷰 | [`common-evidence-review`](public-plugins/common-evidence-review) | 변경이 진짜 필요한지 · 주장이 맞는지를 작성 맥락 없는 검증자가 실행 근거로 판정 |
| | [`common-design-soundness-review`](public-plugins/common-design-soundness-review) | 구현 전 설계(구조 · 플로우 · 결정)의 앞뒤가 맞는지 작성 맥락 없는 검증자가 판정 |
| | [`common-performance-review`](public-plugins/common-performance-review) | 코드 변경의 성능을 9개 범주(복잡도 · 쿼리 · IO · 동시성 · 캐싱 …)로 빠짐없이 판정하고, 루프 안 쿼리 · await 같은 19개 패턴을 작성 시 알림. 언어 무관 |
| 보안 | [`git-secret-validate`](public-plugins/git-secret-validate) | `git commit` · `git push` 전에 키 · 토큰 · 비밀번호와 `.env` · 키 파일을 막고, ignore 안 된 파일에 쓰면 경고. 탐지는 gitleaks (없으면 내장 패턴) |
| 부하 · 성능 | [`common-stress-test`](public-plugins/common-stress-test) | 부하 테스트를 정량으로 설계 · 판정 (운영 호스트 차단 · 지속 가능 용량 · 회귀 통계). 언어 무관 |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | 프레임워크별 서버 계측 · 측정을 무효로 만드는 설정 탐지 · 마이크로벤치마크 |
| 프로젝트 품질 | [`project-completeness`](public-plugins/project-completeness) | 서비스로서 갖출 것을 갖췄는지 진단 · 적용 · 운영 지표 판정 |
| 문서 | [`domain-document-sync`](public-plugins/domain-document-sync) | 도메인 지식 문서를 3계층으로 두고 코드 변경과 맞춰 둔다 |
| | [`common-document-slop-review`](public-plugins/common-document-slop-review) | 문서를 쓰거나 고칠 때마다 slop(대화 잔재 · 깨진 링크 · 근거 없는 주장)을 막고 사실관계 리뷰를 요구 |
| 레퍼런스 찾기 | [`reference-search`](public-plugins/reference-search) | 논문 · 다른 회사 기술 사례 · 공식 문서 · 표준을 출처별 에이전트로 찾고, 없는 DOI · arXiv ID 인용을 막는다 |
| GitHub 플로우 | [`github-workflow`](public-plugins/github-workflow) | 이슈 → 이슈 번호 브랜치 → PR → 머지 커밋 → 태그 흐름을 강제 |

이 저장소 개발에만 쓰는 internal 플러그인 — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-enforcement-effectiveness`](internal-plugins/plugin-enforcement-effectiveness) · [`plugin-workflow`](internal-plugins/plugin-workflow).

## 이 저장소에서 작업할 때

작업 규칙 전체는 [`CLAUDE.md`](CLAUDE.md) 에 있다 — Claude Code 가 세션마다 읽는 문서이고, 사람이 읽어도 같다. 규칙의 세부는 아래 표의 규칙 원본이 정한다.

| 경로 | 성격 | 배포 |
|---|---|---|
| [`public-plugins/`](public-plugins) | 배포용 플러그인 | github 마켓플레이스 — 머지해야 다른 저장소가 받는다 |
| [`internal-plugins/`](internal-plugins) | 이 저장소만 쓰는 플러그인 | 하지 않음 — 세션 시작 때 훅이 등록 · 설치한다 |

### 개발 플로우

```
이슈 → 워크트리 · 브랜치 → 작업 → 버전 → 검증 · 테스트 → 리베이스 후 재검증 → PR
→ 머지 → main 에서 설치 확인 → 태그 · 릴리즈 → 정리
```

- 이슈 · 브랜치 · PR · 커밋 타입은 `feature` / `bugfix` 둘뿐이다. 이슈 폼과 PR 템플릿은 [`.github/`](.github) 에 있다
- 파일을 바꾼 플러그인은 버전을 올린다 — CHANGELOG 먼저, 그다음 `plugin.json`
- 머지는 머지 커밋만. 태그 · 릴리즈는 머지하고 main 에서 설치를 확인한 뒤 `plugin-release-create` 스킬로 단다
- 플러그인을 만들 때는 `plugin-create`, 이름을 바꿀 때는 `plugin-name-update`, 지울 때는 `plugin-delete` 스킬을 쓴다

### 관심사마다 맡는 곳

한 관심사는 한 플러그인이 맡는다. 규칙은 `Write` · `Edit` · `Bash` 훅이 막거나 알린다.

| 관심사 | 플러그인 | 규칙 원본 |
|---|---|---|
| 이름 | `plugin-naming` | [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md) · [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json) |
| 파일 위치 | `marketplace-directory-structure` | [`directory-structure-rules.md`](internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md) |
| 버전 · CHANGELOG | `plugin-versioning` | [`versioning-rules.md`](internal-plugins/plugin-versioning/references/versioning-rules.md) |
| 파일 내용 형식 (프런트매터 · 세 언어 README) | `plugin-authoring` | [`authoring-rules.md`](internal-plugins/plugin-authoring/references/authoring-rules.md) |
| 플러그인 사이의 의존 | `plugin-dependency` | [`dependency-rules.md`](internal-plugins/plugin-dependency/references/dependency-rules.md) |
| 적어 둔 강제가 실행에서 효력을 내는가 | `plugin-enforcement-effectiveness` | [`enforcement-effectiveness-rules.md`](internal-plugins/plugin-enforcement-effectiveness/references/enforcement-effectiveness-rules.md) |
| 이슈 → 브랜치 → PR → 머지 | `github-workflow` | [`workflow-rules.md`](public-plugins/github-workflow/references/workflow-rules.md) |
| 설치 확인 · 태그 · 릴리즈, 생성 · 이름 변경 · 삭제 절차 | `plugin-workflow` | [`workflow-rules.md`](internal-plugins/plugin-workflow/references/workflow-rules.md) |
| 배치 · 마켓플레이스 등록 · 설치 동기화 | 저장소 [`.claude/hooks/`](.claude/hooks) | [`test/README.md`](test/README.md) |

### 검증

PR 전에, 그리고 `origin/main` 위로 리베이스한 뒤에 다시 돌린다.

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .        # 검증기 · 회귀 테스트 · claude plugin validate --strict 전부
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick .  # 스킬 발동 · 훅 차단 eval (모델 호출, 게시 안 함)
```

### README 는 세 언어로

플러그인과 이 저장소의 README 는 `README.md`(영어, 기본) · `README.ko.md` · `README.zh-CN.md` 세 개를 같은 내용으로 둔다. 하나가 없거나, 구성요소 표가 실제와 다르거나, 루트 README 에 public 플러그인이 빠지면 `verify-all.sh` 가 막는다 (`P-01` · `A-20` ~ `A-30`).

## 라이선스

[MIT](LICENSE)
