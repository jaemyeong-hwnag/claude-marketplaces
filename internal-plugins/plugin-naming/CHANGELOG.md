# CHANGELOG

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
