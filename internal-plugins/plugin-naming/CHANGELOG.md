# CHANGELOG

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
