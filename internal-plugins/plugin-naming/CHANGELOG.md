# CHANGELOG

## 0.17.0

### Changed
- `name-create` 는 이름을 낸 뒤 스스로 판단하지 않고 늘 `naming-reviewer` 에 목적 문장과 후보만 넘겨 판정받는다. 에이전트를 쓸 수 없으면 `판정 불가` 로 보고한다 (#208, `plugin-enforcement-effectiveness` `EF-41`). 규칙 3절 판단 담당도 `naming-reviewer` 로 맞췄다

## 0.16.0

### Added
- 사전 `quality` 에 `soundness` (동의어 `validity` 금지), `artifact` 에 `design` (동의어 `blueprint` 금지) (#145) — 새 플러그인 `common-design-soundness-review` 의 관심사 · 대상

## 0.15.0

### Added
- 사전 `quality` 에 `effectiveness`(적어 둔 것이 실행에서 실제로 효력을 내는 정도) · `enforcement`(적어 둔 규칙을 지키게 하는 것)를 더했다 (#143)

### Changed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 없거나 실행되지 않으면 이름 검사 없이 통과하던 것을 막는다 (#143, `plugin-enforcement-effectiveness` `EF-07`)

## 0.14.0

### Changed
- 이름을 조립하기 전에 목적 문장("이게 없으면 무슨 일이 생기는가")을 쓰고 담을 / 뺀 개념을 고른다 (#140). `name-create` 순서 1 · 2, 결과에 목적 문장 · 개념 표를 같이 낸다
- 판단 질문에 "목적 문장의 핵심어가 이름에 있는가"와 "단어마다 이 이름에서만 의미 있는 정보인가"를 더했다. 플러그인은 목적, 스킬 · 커맨드 · 에이전트 · 코드 식별자는 역할 · 사용을 드러낸다 (`naming-rules.md` 3절 · `naming-reviewer` · `/naming-review`)
- 슬롯 `{목적}` 을 `{행위}` 로 바꿨다. 들어가는 단어는 그대로 `action` · `role` 이다. `validate-naming.sh` 메시지도 `행위` 로 나온다
- eval `name-suggest` 가 답에 목적 문장 · 뺀 개념이 있는지 본다

## 0.13.0

### Added
- 사전 `quality` 에 `evidence` (동의어 `proof` 금지) (#138) — 새 플러그인 `common-evidence-review` 의 관심사

## 0.12.0

### Added
- 사전 `role` 에 `searcher` (동의어 `finder` · `seeker` 금지) (#136) — 새 플러그인 `reference-search` 의 출처별 에이전트 `*-searcher`

## 0.11.2

### Fixed
- 메인 체크아웃 세션에서 slug 가 `plugins` 로 끝나는 워크트리(`13-language-naming-plugins`)의 루트 파일(`CLAUDE.md` · `test/` · `.github/` …)을 그 slug 를 플러그인 이름으로 읽어 막던 것 (#121). 경로를 파일이 속한 git 작업 트리 기준으로 상대화한다

## 0.11.1

### Fixed
- 메인 체크아웃에서 로드된 훅 · CLI 가 워크트리에서 고친 사전을 보지 않던 것 (#86). `NAMING_GLOSSARY` 다음으로 기준 경로(훅은 편집 경로, `--all` 은 루트, 그 밖의 CLI 는 현재 디렉터리)의 git 최상위 `internal-plugins/plugin-naming/references/glossary.json` 을 쓴다
- 여러 단어 deny(`name-rule` · `continuous-integration` …)를 이름 전체하고만 비교해 이름 일부면 통과하던 것 (#86). 연속한 단어 조합을 모두 대조한다
- 훅의 줄임말 경고가 stderr + exit 0 으로 나가 Claude 에게 닿지 않던 것 (#86). 새 이름의 경고를 `additionalContext` 로 넘긴다 — 판단 요청처럼 기존 이름에는 붙이지 않는다
- `--all` 이 루트 전체에서 `skills/` 등을 찾아 `.agent-tasks/` 초안까지 검사하던 것 (#86). `<루트>/*plugins/*/` 아래만 본다

## 0.11.0

### Added
- 사전 `quality` 에 `slop` (동의어 `ai-slop` · `fluff` 금지) (#114) — 새 플러그인 `common-document-slop-review` 와 스킬 `document-slop-review` · 에이전트 `document-slop-reviewer`

## 0.10.1

### Fixed
- 훅이 기존 파일을 고칠 때마다 그 경로의 플러그인 · 스킬 이름까지 판단 요청으로 넘기던 것 (#62). 훅은 대상 디렉터리 · 파일이 아직 없는 새 이름만 넘긴다. 기계 위반은 기존 이름도 그대로 막고, CLI 는 전부 보여준다
- "어기는 이름으로는 파일이 만들어지지 않는다" 를 `Write` · `Edit` 한정으로 고쳤다 — `mkdir` · `git mv` · `cp` 는 `--all` 이 사후에 잡는다 (#62)

## 0.10.0

### Added
- 사전 `quality` 에 `performance` (동의어 `perf` · `efficiency` 금지) (#57) — 새 플러그인 `common-performance`(#56) 와 스킬 `performance-review`

## 0.9.0

### Added
- 사전 `quality` 에 `guardrail` (동의어 `guard` · `safeguard` 금지) (#52) — 새 플러그인 `code-edit-guardrail`(#51) 과 스킬 `code-edit-guardrail-apply`

## 0.8.0

### Added
- 사전 `action` 에 `install` (동의어 `installation` 금지) · `search` (동의어 `find` · `lookup` 금지), `role` 에 `browser` (동의어 `explorer` · `navigator` 금지) (#34) — 새 플러그인 `plugin-search-install` · `plugin-browser`

## 0.7.0

### Added
- 사전 `quality` 에 `completeness` (동의어 `maturity` 금지), `action` 에 `apply` (동의어 `setup` 금지) (#27) — 새 플러그인 `project-completeness` 와 스킬 `completeness-review` · `completeness-apply`

## 0.6.1

### Fixed
- 상위 경로에 `…-plugins/` 로 끝나는 폴더가 있으면 그다음 폴더(`public-plugins`)를 플러그인 이름으로 읽고 막던 것 (#24). 경로를 프로젝트 기준 상대 경로로 바꾸고, 플러그인 · 스킬 · 커맨드 · 에이전트 위치를 가장 오른쪽 일치로 판정한다 — 워크트리 이름(`13-language-naming-plugins`)이나 저장소를 둔 상위 폴더(`~/my-plugins/` · `~/skills/`)가 판정에 끼지 않는다

## 0.6.0

### Added
- 사전 `platform` 에 `go` (동의어 `golang` 금지) (#13) — `go-naming` · `go-name-create`. 3자 이하 앞 단어라 "줄임말이면 등록" 경고가 나던 것. Go 는 줄임말이 아니라 언어의 정식 이름이다

## 0.5.0

### Changed
- 슬롯 하나를 1 ~ 3 단어로 (#21). `kotlin-spring` 같은 언어 + 프레임워크를 대상 한 슬롯으로 쓸 수 있다. 이름 전체 "네 단어까지" 상한을 슬롯별 상한으로 바꿨다 — 관심사 · 목적 각 3, 대상·범위 합쳐 6. **전에 막히던 다섯 단어 이상 이름이 통과한다**

### Added
- 이름 64자 상한 (Claude Code 의 스킬 · 에이전트 이름 상한)
- 검증 결과에 단어별 슬롯 구분 — `대상·범위 [kotlin-spring-api] 관심사 [naming] 목적 [validate]`. 차단 메시지와 AI 판단 요청 모두
- 판단 2번에 대상 · 범위 경계를 묻는 항목, `name-create` 의 슬롯 표, `naming-reviewer` 출력의 `슬롯:` 줄

## 0.4.0

### Added
- 사전 `action` 에 `merge` (#12) — `github-workflow` 의 `pull-request-merge` 스킬

## 0.3.1

### Fixed
- 루트 자체가 워크트리(`.claude/worktrees/…`) 안이고 절대 경로로 주면 `--all` 이 스킬·커맨드·에이전트를 하나도 검사하지 않던 것 (#3). 제외를 루트 기준으로 바꿨다

## 0.3.0

### Added
- 판단 5번 — 기존 이름과 헷갈리거나 기능이 겹치지 않는가. 훅의 판단 요청과 `naming-reviewer` 에 `marketplace.json` 대조 절차
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다

### Fixed
- 규칙 원본의 "판단할 것은 셋이다" 가 실제 목록(넷)과 맞지 않던 것

## 0.2.1

### Changed
- README 를 작성 규칙 템플릿으로 개편 (설치 · 의존성 · 포함된 스킬/에이전트/훅 · 변경 이력). 낡은 "회귀 테스트 60건" 문구 제거
- `name-create` description 을 300자 안으로 — 트리거 동의어를 줄였다

## 0.2.0

- 사전에 `versioning` · `authoring` · `dependency` · `workflow` 추가 (`quality`). `semver` · `deps` · `flow` 등을 `deny` 로 막으므로 **전에 통과하던 이름이 막힐 수 있다** — `0.x` 라 MINOR
- `--all` 이 `.claude/worktrees/` 안을 보지 않는다. 워크트리의 사본이 메인 검사를 깨지 않게
- 회귀 테스트 TC 2건 추가 (86 → 88)

## 0.1.1

- `plugin.json` 에서 `"hooks": "./hooks/hooks.json"` 제거 — 표준 경로는 자동 로드되므로 중복으로 판정돼 **훅 로딩 전체가 실패하고 있었다** (`claude plugin list` 에 `Hook load failed: Duplicate hooks file detected`). 이 버전부터 훅이 실제로 동작한다

## 0.1.0

- 네이밍 규칙 원본 `references/naming-rules.md` 와 단어 사전 `references/glossary.json` 추가
- 이름 검증기 `scripts/validate-naming.sh` 추가 — 훅 모드와 CLI 모드(`--all` · `--glossary`)
- `Write`/`Edit` PreToolUse·PostToolUse 훅 연결
- `name-create` · `glossary-update` 스킬, `naming-reviewer` 에이전트, `/naming-review` 커맨드 추가
- 이름 슬롯을 `{대상}-{범위}-{관심사}-{목적}` 으로 확장하고 끝 단어를 사전으로 강제
- 정량 검증과 AI 판단을 분리 — 기계 규칙을 통과한 이름은 모두 판단으로 넘긴다
- 사전에 `role` 카테고리와 구조·이름 단어 추가
- 회귀 테스트 TC 86건 추가
