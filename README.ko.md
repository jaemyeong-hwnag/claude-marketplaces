# claude-marketplaces

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

모델이 건너뛸 수 있는 지시 대신 훅으로 규칙을 강제하는 Claude Code 플러그인 모음. 코드를 고치고 테스트를 안 고쳤거나 린트가 실패하면 완료를 되돌리고, AI 의 변경을 작성자의 결론을 보지 않는 검증자에게 넘기고, 운영 호스트를 향한 부하 테스트를 막고, 시크릿 커밋을 막고, Java · Kotlin · TypeScript · Node.js · Python · Go 네이밍 컨벤션을 강제한다. 이 규칙을 Claude Code 세션마다 적용하고 싶은 개인과 팀을 위한 것이다. 완료(`Stop`) 게이트는 요청마다 한 번 되돌리는 장치라 사람의 리뷰를 대신하지 않는다.

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install code-edit-guardrail@jaemyeong-hwnag-plugins
```

마켓플레이스 이름은 `jaemyeong-hwnag-plugins` 다.

- **플러그인을 쓰려는 사람** — [처음 시작하기](#처음-시작하기) · [수록 플러그인](#수록-플러그인) · [자주 묻는 질문](#자주-묻는-질문)
- **이 저장소에 기여하는 사람** — [이 저장소에서 작업할 때](#이-저장소에서-작업할-때)

## 처음 시작하기

필요한 것: Claude Code, `bash`, `jq`.

**1. 마켓플레이스를 추가한다** (컴퓨터마다 한 번)

Claude Code 세션 안에서:

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
```

**2. 플러그인을 설치한다**

[수록 플러그인](#수록-플러그인) 표에서 이름을 골라 설치한다. `/plugin` 을 열어 목록에서 골라도 된다.

```
/plugin install <이름>@jaemyeong-hwnag-plugins
```

설치 범위를 묻는다 — 팀이 같은 설정을 받게 하려면 `project`, 나만 쓰려면 `user`.

**3. Claude Code 를 다시 시작한다**

훅 · 스킬 · MCP 서버는 세션을 시작할 때 로드된다.

> 터미널에서는 같은 일을 `claude plugin marketplace add …` · `claude plugin install … --scope project` 로 한다.

### 팀 전체가 같은 플러그인을 쓰게 하기

프로젝트의 `.claude/settings.json` 에 마켓과 플러그인을 적어 커밋한다. 팀원이 그 폴더를 신뢰하면 마켓이 등록되고 `enabledPlugins` 에 적은 플러그인이 켜진다.

```json
{
  "extraKnownMarketplaces": {
    "jaemyeong-hwnag-plugins": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": {
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
| 훅이 동작하지 않거나 오류를 낸다 | `claude plugin list` 의 오류를 본다. 훅 스크립트는 `jq` 가 필요하다 — `brew install jq` (macOS) · `apt install jq` |
| `…@plugin-marketplace` 로 설치돼 있다 | 예전 마켓 이름이다 — `claude plugin marketplace remove plugin-marketplace` 뒤 1단계부터 |

## 수록 플러그인

설치: `/plugin install <이름>@jaemyeong-hwnag-plugins`. public 플러그인마다 README 가 영어 · 한국어 · 중국어로 있다.

| 분야 | 플러그인 | 하는 일 |
|---|---|---|
| 코드 편집 가드레일 | [`code-edit-guardrail`](public-plugins/code-edit-guardrail) | 코드만 고치고 테스트를 안 고치면 · 고친 경로의 린트 · 포맷 검사가 실패하면 완료 차단, 공유자원 편집은 사용자 확인. 언어 무관 |
| 검증 · 리뷰 | [`common-evidence-review`](public-plugins/common-evidence-review) | 변경이 진짜 필요한지 · 주장이 맞는지를 작성 맥락 없는 검증자가 실행 근거로 판정 |
| | [`common-design-soundness-review`](public-plugins/common-design-soundness-review) | 구현 전 설계(구조 · 플로우 · 결정)의 앞뒤가 맞는지 작성 맥락 없는 검증자가 판정 |
| | [`common-performance-review`](public-plugins/common-performance-review) | 코드 변경의 성능을 9개 범주(복잡도 · 쿼리 · IO · 동시성 · 캐싱 …)로 빠짐없이 판정하고, 루프 안 쿼리 · await 같은 19개 패턴을 작성 시 알림. 언어 무관 |
| 부하 · 성능 | [`common-stress-test`](public-plugins/common-stress-test) | 부하 테스트를 정량으로 설계 · 판정 (운영 호스트 차단 · 지속 가능 용량 · 회귀 통계). 언어 무관 |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | 프레임워크별 서버 계측 · 측정을 무효로 만드는 설정 탐지 · 마이크로벤치마크 |
| 보안 | [`git-secret-validate`](public-plugins/git-secret-validate) | `git commit` · `git push` 전에 키 · 토큰 · 비밀번호와 `.env` · 키 파일을 막고, ignore 안 된 파일에 쓰면 경고. 탐지는 gitleaks (없으면 내장 패턴) |
| 테스트 | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) · [`kotlin-spring-aitest-coverage`](public-plugins/kotlin-spring-aitest-coverage) | Java · Kotlin Spring Boot 변경 메서드를 `@AiTest` 로 덮고 JaCoCo 100% 게이트 |
| 코드 네이밍 | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | 언어 공식 가이드가 정한 이름 모양을 훅으로 막고, 단어 선택은 스킬이 판단 |
| 문서 | [`domain-document-sync`](public-plugins/domain-document-sync) | 도메인 지식 문서를 3계층으로 두고 코드 변경과 맞춰 둔다 |
| | [`common-document-slop-review`](public-plugins/common-document-slop-review) | 문서를 쓰거나 고칠 때마다 slop(대화 잔재 · 깨진 링크 · 근거 없는 주장)을 막고 사실관계 리뷰를 요구 |
| 레퍼런스 찾기 | [`reference-search`](public-plugins/reference-search) | 논문 · 다른 회사 기술 사례 · 공식 문서 · 표준을 출처별 에이전트로 찾고, 없는 DOI · arXiv ID 인용을 막는다 |
| GitHub 플로우 | [`github-workflow`](public-plugins/github-workflow) | 이슈 → 이슈 번호 브랜치 → PR → 머지 커밋 → 태그 흐름을 강제 |
| 플러그인 찾기 · 설치 | [`plugin-search-install`](public-plugins/plugin-search-install) | 이 마켓의 public 플러그인 검색 · 연관 · 프로젝트에 필요한 것 · 설치. 로컬 MCP 서버 포함 |

이 저장소 개발에만 쓰는 internal 플러그인 — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-enforcement-effectiveness`](internal-plugins/plugin-enforcement-effectiveness) · [`plugin-workflow`](internal-plugins/plugin-workflow).

## 자주 묻는 질문

### Claude Code 가 테스트 없이 작업을 끝내지 못하게 하려면?

[`code-edit-guardrail`](public-plugins/code-edit-guardrail) 을 설치하고 "가드레일 설정해줘" 라고 말한다. 한 요청에서 코드를 고쳤는데 테스트 파일을 하나도 안 고쳤거나, 고친 경로의 린트 · 포맷 · 타입 검사 명령이 실패하면 `Stop` 훅이 완료를 한 번 되돌린다. 동작이 그대로인 변경은 Claude 가 면제 파일에 사유를 적으면 통과한다 — 사용자가 동의했는지는 훅이 확인하지 않는다.

### Claude Code 의 변경을 Claude 자신이 아닌 쪽이 검증하게 하려면?

[`common-evidence-review`](public-plugins/common-evidence-review) 가 원래 요청 · 바뀐 파일 · 결론을 뺀 질문만 별도 검증 에이전트에 넘기고, 검증자는 변경마다 실행 근거로 판정한다. 한 요청에서 코드 · 설정을 3줄 이상 바꾸고 이 검증 없이 끝내려 하면 종료를 한 번 되돌린다. 게이트는 검증자를 불렀는지만 보고, 판정을 따랐는지는 보지 않는다.

### Claude Code 가 API 키나 `.env` 파일을 커밋하지 못하게 하려면?

[`git-secret-validate`](public-plugins/git-secret-validate) 가 시크릿 · 민감 파일이 실린 `git commit` · `git push` 를 막는다. `bash -c` · `sh -c` · `eval` 로 감싼 명령도 본다. 탐지는 gitleaks, 없으면 내장 패턴이다.

### Claude Code 로 운영 서버를 건드리지 않고 부하 테스트를 할 수 있나?

[`common-stress-test`](public-plugins/common-stress-test) 가 대상 호스트가 허용 목록(루프백 · 사설 IP · `*.local` · `*.test` · `*.internal` · 직접 추가한 호스트) 밖인 부하 명령(k6 · Gatling · Locust · JMeter · wrk · hey · bombardier · siege 등)을 막는다. `make` · `npm run` 을 거친 간접 실행과 변수로 만든 명령 · 대상은 보지 못한다.

### Claude Code 가 언어의 네이밍 컨벤션을 지키게 하려면?

언어에 맞는 플러그인을 설치한다 — [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming). 훅은 이번 편집이 새로 만든 위반만 막으므로 기존 코드 때문에 막히지 않는다.

### 왜 `CLAUDE.md` 지시가 아니라 훅인가?

훅은 모델 밖에서 Claude Code 가 직접 실행한다. 지시는 건너뛸 수 있지만, `PreToolUse` 훅은 도구 호출을 거부하고 `Stop` 훅은 턴 종료를 거부할 수 있다. 다만 이 저장소의 `Stop` 게이트는 같은 요청에서 한 번만 되돌린다 — 모델이 두 번째 종료에서 넘어갈 수 있다.

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
- 머지는 머지 커밋만. 태그 · 릴리즈는 머지하고 main 에서 설치를 확인한 뒤 `plugin-release-create` 스킬로 단다. public 만 — internal 은 배포하지 않아 태그 · 릴리즈가 없다
- 플러그인을 만들 때는 `plugin-create`, 이름을 바꿀 때는 `plugin-name-update`, 지울 때는 `plugin-delete` 스킬을 쓴다

### 관심사마다 맡는 곳

한 관심사는 한 플러그인이 맡는다. 규칙은 `Write` · `Edit` · `Bash` 훅이 막거나 알린다.

| 관심사 | 플러그인 | 규칙 원본 |
|---|---|---|
| 이름 | `plugin-naming` | [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md) · [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json) |
| 파일 위치 | `marketplace-directory-structure` | [`directory-structure-rules.md`](internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md) |
| 버전 · CHANGELOG | `plugin-versioning` | [`versioning-rules.md`](internal-plugins/plugin-versioning/references/versioning-rules.md) |
| 파일 내용 형식 (프런트매터 · README) | `plugin-authoring` | [`authoring-rules.md`](internal-plugins/plugin-authoring/references/authoring-rules.md) |
| 플러그인 사이의 의존 | `plugin-dependency` | [`dependency-rules.md`](internal-plugins/plugin-dependency/references/dependency-rules.md) |
| 적어 둔 강제가 실행에서 효력을 내는가 | `plugin-enforcement-effectiveness` | [`enforcement-effectiveness-rules.md`](internal-plugins/plugin-enforcement-effectiveness/references/enforcement-effectiveness-rules.md) |
| 이슈 → 브랜치 → PR → 머지 | `github-workflow` | [`workflow-rules.md`](public-plugins/github-workflow/references/workflow-rules.md) |
| 설치 확인 · 태그 · 릴리즈, 생성 · 이름 변경 · 삭제 절차 | `plugin-workflow` | [`workflow-rules.md`](internal-plugins/plugin-workflow/references/workflow-rules.md) |
| 배치 · 마켓플레이스 등록 · 설치 동기화 | 저장소 [`.claude/hooks/`](.claude/hooks) | [`test/README.md`](test/README.md) |

### 검증

PR 전에, 그리고 `origin/main` 위로 리베이스한 뒤에 다시 돌린다.

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .        # 저장소 전체 검증기 + 바뀐 플러그인과 역의존의 테스트 · validate --strict
internal-plugins/plugin-workflow/scripts/verify-all.sh --all  # 전부 (릴리즈 전 · 의심될 때)
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick .  # 스킬 발동 · 훅 차단 eval (모델 호출, 게시 안 함)
```

### README 는 세 언어로

public 플러그인과 이 저장소의 README 는 `README.md`(영어, 기본) · `README.ko.md` · `README.zh-CN.md` 세 개를 같은 내용으로 둔다. internal 플러그인은 `README.ko.md` 하나만 둔다. 하나가 없거나, 구성요소 표가 실제와 다르거나, 루트 README 에 public 플러그인이 빠지면 `verify-all.sh` 가 막는다 (`P-01` · `A-20` ~ `A-30`).

## 라이선스

[MIT](LICENSE)
