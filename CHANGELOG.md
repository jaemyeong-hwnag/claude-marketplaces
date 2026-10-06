# CHANGELOG

## 미출시

### Changed
- `.gitignore` 에 로컬 IDE · MCP 설정(`.mcp.json` · `.idea/`)을 더했다 (#46)
- 마켓플레이스 이름을 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바꿨다 — 흔한 이름이라 다른 마켓과 겹쳤다. 설치 id 가 `<플러그인>@jaemyeong-hwnag-plugins` 로 바뀐다 (#44)

### Added
- MIT 라이선스 (`LICENSE`) (#46)
- 스트레스 테스트 public 플러그인 일곱 — `common-stress-test`(운영 호스트 부하 차단 `ST-01`, open 모델 · thresholds · p99 점검, 단계 결과로 지속 가능 용량 · Kneedle knee · USL · Little 정합성, Mann-Whitney U · Cliff's delta 회귀 판정, local · Docker · k8s 템플릿)와 이에 의존하는 `java-spring` · `python-fastapi` · `python-django` · `node-express` · `typescript-nestjs` · `go-gin` `-stress-test`(서버 계측 · 무효 설정 탐지 · 손잡이 · 마이크로벤치마크). 근거 문헌과 Docker 실측으로 확인한 것만 담았다 (#33)
- `domain-document-sync` public 플러그인 — 도메인 지식 문서를 3계층(`_index` → `_meta` → concept)으로 두고 코드와 맞춰 둔다. 도메인 ↔ 코드 매핑을 `_meta.md` 프런트매터 `code:` 글롭으로 해 언어 · 프레임워크를 가정하지 않는다. 도메인 문서를 코드와 맞춰 두는 플러그인이다 (#14)
- 언어별 코드 네이밍 public 플러그인 여섯 — `java-naming` · `kotlin-naming` · `typescript-naming` · `node-naming` · `python-naming` · `go-naming`. 각 언어 공식 가이드가 분명히 정한 모양만 `PreToolUse(Write|Edit)` 로 막고(편집 전과 비교해 새로 생긴 위반만), 갈리는 관례는 경고, 단어 선택은 `{언어}-name-create` 스킬이 판단한다 (#13)
- `github-workflow` public 플러그인 — `plugin-workflow` 에서 이슈 · 브랜치 · PR · 머지 플로우와 훅(`W-01` ~ `W-10`)을 떼어 다른 저장소도 설치할 수 있게 했다. 기본 브랜치를 `origin/HEAD` 에서 읽고, 템플릿 설치 스킬과 머지 · 정리 스킬을 더했다. `plugin-workflow` 는 이것에 의존한다 (#12)
- eval 자동화 — 플러그인마다 스킬 발동 · 훅 차단 케이스, `eval-all.sh`(케이스 단위 권한, `--no-publish`, 결과는 플러그인 밖). 구조 규칙 `P-10`
- `plugin-create` · `plugin-delete` 스킬 — 생성 체크리스트, 역참조부터 시작하는 삭제 순서
- `V-05` — CHANGELOG 항목에 날짜(`## x.y.z - YYYY-MM-DD`)를 붙일 수 있다
- 이름 판단 5번 — 기존 이름과 헷갈리거나 기능이 겹치지 않는가
- 로드 확인을 `claude plugin list --json` 의 `errors` 로 (훅 로드 실패가 `errorDetails[].type = hook-load-failed` 로 나오는 것을 실측)
- `plugin-authoring` 내부 플러그인 — 스킬·커맨드·에이전트 프런트매터, 본문·참조 크기, README 절 구성과 실제 구성요소의 일치
- `plugin-dependency` 내부 플러그인 — 존재 · 순환 · common 과 번들의 층 · 마켓플레이스 경계 · public → internal 금지 · 범위 겹침
- `plugin-workflow` 내부 플러그인 — 이슈 · 브랜치 · PR · 머지 · 태그의 12 단계 플로우를 `PreToolUse(Bash)` 훅으로. `verify-all.sh` · `release-plugins.sh` · `branch-create.sh`
- `.github/` 이슈 폼 `feature` · `bugfix`, PR 템플릿 `feature` · `bugfix`
- `.claude-plugin/categories.json` · `tags.json` — `category` 는 배치, 주제는 태그(domain + technology)
- 배치 검사에 이름 중복 · 카테고리 · 태그 · description 일치 · common 은 public 에만
- `plugin-versioning` `V-14`(바뀌었으면 올렸는가) · 루트 CHANGELOG 검사
- 사전에 `authoring` · `dependency` · `workflow`

### Changed
- sync 훅이 명시적 `enabledPlugins: false` 를 존중한다 — 지금까지 내부 플러그인은 끌 방법이 없었다
- sync 훅이 설치본을 **설치 기준 디렉터리**와 비교한다 — 워크트리에서 재설치가 헛돌던 것
- sync 훅이 사라진 내부 플러그인의 엔트리 · 활성화 키 · 설치본을 치우고, description 을 `plugin.json` 에 맞추고, 끝에 로드 실패(`Error:`)를 보고한다
- `.claude/worktrees/` 를 검증기가 보지 않는다 (`.gitignore` 에도)
- 기존 플러그인 README 를 작성 규칙 템플릿으로 개편
- `plugin-versioning` — 릴리즈 순서를 CHANGELOG 먼저로, `V-12` 는 형식만, `V-11` 이 Claude Code 가 받는 범위를 모두 허용

### Fixed
- CLAUDE.md 함정 — 의존성 있는 플러그인 eval 은 의존 대상을 설치해도 풀리지 않는다 (eval 이 격리된 설정으로 돈다). 대책을 `dependencies` 를 잠시 빼는 것으로 고쳤다 (#37)
- `plugin-naming` 이 상위 경로의 `…-plugins/` 폴더 다음 폴더를 플러그인 이름으로 읽고 막던 것 (#24) — 가장 오른쪽 일치, 프로젝트 기준 상대 경로
- `plugin-workflow` 의 의존성 `github-workflow` 활성화 키가 `settings.json` 에 없어 설치 뒤 main 이 더러워지던 것 (#16). 배치 검사가 켜 둔 internal 의 public 의존성 키를 요구한다
- CLAUDE.md · README · test/README 가 로컬 디렉터리 플러그인이 캐시 사본으로 돈다고 잘못 설명하던 것 — 소스에서 그대로 로드된다. CLAUDE.md 는 관심사 표 하나로 줄여 규칙 요약이 스킬을 가리지 않게 했다 (#10)
- 배치 검사에서 탭 구분 `read` 가 빈 칸을 합쳐 뒤 칸이 앞으로 밀리던 것
- 범위가 `*` 한 글자면 파일 이름으로 확장돼 `V-11` 이 잘못 막던 것

- 내부 플러그인 3종의 훅이 로드되지 않던 결함 수정 — `plugin.json` 의 `"hooks": "./hooks/hooks.json"` 이 자동 로드와 중복돼 `Hook load failed` 로 훅 전체가 꺼져 있었다. `plugin-naming` 0.1.1 · `marketplace-directory-structure` 0.2.0 · `plugin-versioning` 0.1.1
- 구조 규칙 `P-09` 추가 — 같은 결함을 기계로 막는다
- `plugin-versioning` 내부 플러그인 추가 — 버전 값과 CHANGELOG · marketplace 엔트리 · git 태그의 정합성을 검증한다
- `plugin-naming` 사전에 `versioning` 추가 (`quality`), 줄임말 `semver` 는 `deny`
- `marketplace-directory-structure` 내부 플러그인 추가 — 마켓플레이스 루트와 플러그인의 디렉터리 구조를 검증한다
- 루트와 각 플러그인에 `CHANGELOG.md` 추가 (구조 규칙 `R-02` · `P-01`)

## 0.1.0

- 마켓플레이스 `jaemyeong-hwnag-plugins` 와 `public-plugins/` · `internal-plugins/` 배치 구조
- 배치 정책 검증 훅 `.claude/hooks/validate-plugin-scope.sh`
- 내부 플러그인 설치 동기화 훅 `.claude/hooks/sync-internal-plugins.sh`
- SessionStart 훅 등록과 플러그인 활성화 설정
- `plugin-naming` 내부 플러그인 추가
- 배치 정책·동기화 훅 회귀 테스트
