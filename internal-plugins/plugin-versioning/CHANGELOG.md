# CHANGELOG

## 0.1.1

- `plugin.json` 에서 `"hooks": "./hooks/hooks.json"` 제거 — 표준 경로는 자동 로드되므로 중복으로 판정돼 **훅 로딩 전체가 실패하고 있었다** (`claude plugin list` 에 `Hook load failed: Duplicate hooks file detected`). 이 버전부터 훅이 실제로 동작한다

## 0.1.0

- 버전 규칙 원본 `references/versioning-rules.md` 추가 (`V-01`~`V-13`)
- 버전 검증기 `scripts/validate-versioning.sh` 추가 — 훅 모드와 CLI 모드(`--all` · `--marketplace` · `--tag`)
- `Write`/`Edit` PreToolUse(차단)·PostToolUse(알림) 훅 연결
- `version-update` 스킬, `/versioning-validate` 커맨드 추가
