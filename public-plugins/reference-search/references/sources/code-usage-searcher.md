# code-usage-searcher 출처 카탈로그

기준일 2026-10. 공개 코드 · 이슈 · PR · Q&A · 설계 제안서 · 패키지 레지스트리에서 기술이 실제로 어떻게 쓰이고 논의되는지 찾는다.

## 언제 쓰는가

- 띄운다: API · 설정을 실제 프로젝트가 어떻게 쓰는지, 알려진 버그 · 우회법, 기능이 들어간 PR · 설계 이유, 라이브러리 사용처 수 · 버전 분포.
- 띄운다: 공식 문서와 동작이 달라 소스 · 이슈로 확인해야 할 때 (`official-document-searcher` 가 넘긴 경우).
- 띄우지 않는다: 공식 문서 · 표준 자체(`official-document-searcher`), 회사 도입 사례(`company-blog-searcher`), 장애 사후 분석(`postmortem-searcher`).

## 출처

### 코드 · 이슈 · PR 검색

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| GitHub 코드 검색 | `github.com` | 공개 저장소 기본 브랜치의 코드 | 무료 (인증 필요, `gh` 인증됨) | `reference-search.sh github-code 검색어`, 세부 조건은 `gh search code` |
| GitHub 저장소 검색 | `github.com` | 저장소 · 예제 프로젝트 · awesome 목록 | 무료 | `reference-search.sh github-repository 검색어` |
| GitHub 이슈 검색 | `github.com` | 버그 리포트 · 기능 요청 · 우회법 | 무료 | `reference-search.sh github-issue 검색어`, 세부 조건은 `gh search issues` |
| GitHub PR 검색 | `github.com` | 기능이 들어간 변경 · 리뷰 토론 | 무료 | `gh search prs 검색어 --repo <소유자>/<저장소> --merged` |
| GitHub Discussions | `github.com` | 질문 · 설계 토론 (저장소가 켰을 때만) | 무료 | `gh api graphql` 의 `search(type: DISCUSSION)` (아래 요령) |
| grep.app | `grep.app` | 공개 저장소 50만 개 이상의 정규식 코드 검색. 2025 Vercel 이 인수 | 무료 | 사람이 브라우저로 쓴다. 스크립트 · WebFetch 요청은 Vercel 보안 확인(429)으로 막힌다. 막히면 GitHub 코드 검색으로 돌아간다 |
| Sourcegraph | `sourcegraph.com/search` | 공개 코드 검색 (정규식 · 구조 검색 · 커밋 · diff) | 무료 (공개 코드), 비공개 · 사내 인스턴스는 키 필요 — TODO | WebFetch `sourcegraph.com/search?q=context:global+검색어`, 스트리밍 API `sourcegraph.com/.api/search/stream?q=…` 는 공개 코드에 토큰 없이 응답한다 |
| GitLab | `gitlab.com/explore` | GitLab 공개 프로젝트 | 무료 일부 (코드 검색은 로그인) | WebSearch `site:gitlab.com 검색어` |
| Codeberg | `codeberg.org` | Forgejo 기반 공개 저장소 | 무료 | WebSearch `site:codeberg.org 검색어` |

### Q&A · 토론

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Stack Overflow | `stackoverflow.com` | 질문 · 답변 · 오류 메시지 | 무료 | WebSearch `site:stackoverflow.com "<오류 메시지>"` (봇 요청은 403) |
| Stack Exchange API | `api.stackexchange.com` | Stack Overflow 등 질문 검색 · 점수 · 채택 여부 | 무료 (키 없이 IP 당 하루 300회), 고빈도는 키 필요 — TODO (키 있으면 하루 10,000회) | WebFetch 는 막힌다. Bash `curl` 로 `api.stackexchange.com/2.3/search/advanced?q=…&site=stackoverflow` (gzip 응답) |
| Hacker News | `news.ycombinator.com` | 라이브러리 · 도구에 대한 현업자 평 | 무료 | `reference-search.sh hackernews 검색어` |
| Lobsters | `lobste.rs` | 기술 링크 · 토론 | 무료 | WebSearch `site:lobste.rs 검색어` |
| Reddit | `reddit.com` | 언어 · 프레임워크별 커뮤니티 토론 | 무료 | WebSearch `site:reddit.com/r/<게시판> 검색어` |

### 설계 문서 · 제안서

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Kubernetes KEP | `github.com/kubernetes/enhancements` | 쿠버네티스 기능 제안 · 단계(alpha · beta · stable) | 무료 | `gh search code "검색어" --repo kubernetes/enhancements --filename kep.yaml`, WebFetch `…/tree/master/keps` |
| Python PEP | `peps.python.org` | 파이썬 언어 · 표준 라이브러리 제안. 원본 `github.com/python/peps` | 무료 | WebFetch `peps.python.org/pep-<네 자리 번호>/`, WebSearch `site:peps.python.org 검색어` |
| Rust RFC | `rust-lang.github.io/rfcs` · `github.com/rust-lang/rfcs` | Rust 언어 · 도구 제안 | 무료 | WebSearch `site:rust-lang.github.io/rfcs 검색어`, 진행 중은 `gh search prs 검색어 --repo rust-lang/rfcs` |
| TC39 proposals | `github.com/tc39/proposals` | ECMAScript 제안과 단계(Stage 0~4) | 무료 | WebFetch `github.com/tc39/proposals` README (단계별 표) |
| Go proposals | `github.com/golang/proposal` · `github.com/golang/go` | Go 언어 · 라이브러리 제안. 논의는 `golang/go` 이슈의 `Proposal` 라벨 | 무료 | `gh search issues "proposal: 검색어" --repo golang/go` |
| Kotlin KEEP | `github.com/Kotlin/KEEP` | Kotlin 언어 기능 제안 | 무료 | `gh search code 검색어 --repo Kotlin/KEEP` |
| Swift Evolution | `github.com/swiftlang/swift-evolution` | Swift 언어 제안. `apple/swift-evolution` 이 이리로 넘어간다 | 무료 | `gh search code 검색어 --repo swiftlang/swift-evolution` |
| npm RFC | `github.com/npm/rfcs` | npm CLI 동작 제안 | 무료 | `gh search issues 검색어 --repo npm/rfcs` |
| ADR 모음 | `adr.github.io` · `github.com/architecture-decision-record/architecture-decision-record` | 아키텍처 결정 기록 형식 · 예시. 두 번째는 `joelparkerhenderson/architecture-decision-record` 가 옮겨 간 곳 | 무료 | WebFetch, 실제 ADR 은 `gh search code "## Decision" path:docs/adr` |

### 패키지 레지스트리

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| npm | `npmjs.com` · `registry.npmjs.org` · `api.npmjs.org` | JS 패키지 버전 · 배포일 · 주간 내려받기 | 무료 | Bash `curl registry.npmjs.org/<패키지>` (`time` 칸이 버전별 배포일), 내려받기 `api.npmjs.org/downloads/point/last-week/<패키지>`. 웹 페이지는 봇 요청에 403 |
| npm trends | `npmtrends.com` | 패키지 내려받기 비교 | 무료 | WebFetch `npmtrends.com/<패키지1>-vs-<패키지2>` |
| PyPI | `pypi.org` | 파이썬 패키지 버전 · 배포일 · 의존 | 무료 | WebFetch `pypi.org/pypi/<패키지>/json` |
| PyPI Stats | `pypistats.org` | 파이썬 패키지 내려받기 | 무료 | WebFetch `pypistats.org/api/packages/<패키지>/recent` |
| Maven Central | `central.sonatype.com` · `search.maven.org` | Java 아티팩트 버전 · 배포일 | 무료 | WebFetch `search.maven.org/solrsearch/select?q=g:<그룹>+AND+a:<아티팩트>&core=gav&rows=20&wt=json` |
| MVN Repository | `mvnrepository.com` | 아티팩트별 "Used By" 수 | 무료 | WebSearch `site:mvnrepository.com <아티팩트>` (봇 요청은 403) |
| crates.io | `crates.io` | Rust 크레이트 버전 · 역의존 | 무료 | Bash `curl -A <이름> crates.io/api/v1/crates/<크레이트>` · `…/reverse_dependencies` (User-Agent 필수) |
| deps.dev | `deps.dev` | npm · PyPI · Maven · Go · Cargo 의존 그래프 · 피의존 수 · 보안 권고 | 무료 | WebFetch `api.deps.dev/v3/systems/<체계>/packages/<패키지>` |
| Libraries.io | `libraries.io` | 여러 레지스트리의 의존 · 피의존 저장소 | 무료 일부 (API 는 키 필요 — TODO) | WebFetch 웹 페이지 `libraries.io/<체계>/<패키지>` |
| pkg.go.dev | `pkg.go.dev` | Go 모듈 버전 · "Imported by" 수 | 무료 | WebFetch `pkg.go.dev/<모듈>?tab=importedby` |

## 검색 문법과 요령

### `gh search code`

| 하는 일 | 문법 |
|---|---|
| 기본 | `gh search code "<문자열>"` (따옴표 안은 구) |
| 저장소 · 소유자 | `--repo <소유자>/<저장소>` · `--owner <소유자>` 또는 쿼리 안 `repo:` · `org:` |
| 언어 · 확장자 · 파일 이름 | `--language go` · `--extension yml` · `--filename package.json` |
| 경로 | 쿼리 안 `path:src/main` 또는 `--match path` (경로에서만 찾기) |
| 크기 | `--size "<100"` (KB) |
| 출력 | `--json path,repository,sha,textMatches,url` · `-L <건수>` |
| 예 | `gh search code "spring.threads.virtual.enabled" --filename application.yml` |

한도 · 제약:

- 코드 검색은 인증해야 하고 분당 10회다. 다른 검색(이슈 · PR · 저장소)은 분당 30회다 (`gh api rate_limit` 로 남은 횟수 확인).
- 검색당 결과는 최대 1,000건이다. 쿼리는 연산자 · 한정자를 빼고 256자, AND · OR · NOT 은 5개까지다.
- 기본 브랜치만, 384KB 이하 파일만 찾는다. 한정자만 있는 쿼리(`language:go` 만)는 안 된다.
- `gh` 는 레거시 코드 검색 엔진을 쓴다. 웹 화면 결과와 다를 수 있고 정규식이 안 된다. 정규식이 필요하면 Sourcegraph 를 쓴다.
- 제외 한정자(`-label:bug` · `-repo:…`)는 `gh search issues -- "검색어 -label:bug"` 처럼 `--` 뒤에 쓴다 (`gh search --help`).

### `gh search issues` · `gh search prs`

| 하는 일 | 문법 |
|---|---|
| 상태 | `--state open|closed`, PR 은 `--merged` · `--draft` |
| 찾을 칸 | `--match title|body|comments` |
| 라벨 · 저장소 | `--label bug` · `--repo <소유자>/<저장소>` |
| 날짜 | `--created ">2025-01-01"` · `--updated ">=2026-01-01"` · `--merged-at` |
| 반응 · 댓글 수 | `--reactions ">10"` · `--comments ">5"` · `--sort reactions-+1` |
| 이슈에 PR 포함 | `--include-prs` |
| 의미 검색 | `gh search issues --search-type semantic|hybrid` (기본 lexical) |
| 출력 | `--json title,url,state,createdAt,commentsCount,repository` |

예:

- 알려진 버그: `gh search issues "<오류 메시지>" --repo <소유자>/<저장소> --state closed --match body`.
- 기능이 들어간 PR: `gh search prs "<기능명>" --repo <소유자>/<저장소> --merged --sort created`.

### Discussions

```
gh api graphql -f query='{search(query:"<검색어> repo:<소유자>/<저장소>", type:DISCUSSION, first:10){discussionCount nodes{... on Discussion{title url createdAt answer{url}}}}}'
```

### Sourcegraph 쿼리

| 하는 일 | 문법 |
|---|---|
| 전체 공개 코드 | `context:global <검색어>` |
| 저장소 · 파일 · 언어 | `repo:^github\.com/<소유자>/<저장소>$` · `file:\.ya?ml$` · `lang:go` |
| 정규식 | `patterntype:regexp` 또는 `/정규식/` |
| 커밋 · diff | `type:commit` · `type:diff` 와 `after:"2025-01-01"` |
| 셀 수 | `count:all` (기본은 일부만 센다) |

### 레지스트리로 사용처 · 버전 확인

- 버전 · 배포일은 레지스트리 JSON 으로 확인한다. 블로그 · 문서에 적힌 "현재 버전" 은 기준일을 붙여 다시 확인한다.
- 사용처 수는 레지스트리마다 세는 방식이 다르다 (npm 내려받기는 CI 를 포함한다, deps.dev 피의존은 공개 패키지만). 숫자를 비교할 때 같은 출처끼리만 비교한다.
- 이름이 비슷한 다른 패키지(타이포스쿼팅)를 섞지 않는다. 저장소 링크 · 배포자를 확인한다.

### 공통 요령

- 오류 메시지는 고유한 부분만 따옴표로 묶는다. 경로 · 숫자 · 사용자 이름은 뺀다.
- 코드 검색 결과는 예제 · 포크 · 학습용 저장소가 많다. 별 수 · 마지막 커밋 날짜 · 실제 서비스 저장소인지 같이 본다 (`reference-search.sh github-repository` 의 `stars` · `date`).
- 이슈가 닫혔으면 닫힌 이유(고침 · 중복 · 안 고침)와 고친 버전을 확인한다.
- 설계 제안서는 상태(Draft · Accepted · Final · Rejected · Withdrawn, TC39 는 Stage)를 먼저 본다. 받아들여지지 않은 제안을 동작 근거로 쓰지 않는다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 공식 저장소 코드 | 그 기술을 만든 쪽 저장소의 소스. 태그 · 커밋 · 경로를 적는다 |
| 사용 코드 | 다른 프로젝트의 사용례. 저장소 · 별 수 · 마지막 커밋 날짜를 적는다 |
| 이슈 · PR (상태) | open · closed(고침 · 안 고침) · merged. 메인테이너 답변이 있는지 적는다 |
| 설계 제안 (상태) | KEP · PEP · RFC · TC39 단계. 받아들여졌는지 적는다 |
| 커뮤니티 답변 | Stack Overflow 등. 점수 · 채택 여부 · 작성 연도를 적는다 |
| 레지스트리 수치 | 버전 · 배포일 · 내려받기 · 피의존 수. 조회 날짜를 적는다 |

주의:

- 작성 날짜: Stack Overflow 답변 · 이슈 댓글은 옛 버전 기준인 경우가 많다. 답변 연도와 대상 버전을 같이 적는다.
- 규모: 사용 코드 몇 건은 "널리 쓰인다" 의 근거가 아니다. 건수를 말할 때는 검색 범위(기본 브랜치 · 공개 저장소만)를 같이 적는다.
- 홍보성: 라이브러리 저자가 쓴 답변 · 비교 글은 자기 라이브러리 쪽으로 쓰인다.
- 지금도 유효한지: 보관(archived)된 저장소 · 지원 종료 버전의 코드는 그렇게 표시한다.
- 라이선스: 코드를 그대로 옮겨 쓸 때는 저장소 라이선스를 확인하고 적는다.
