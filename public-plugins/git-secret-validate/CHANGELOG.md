# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/secret-rules.md` (`GS-01` ~ `GS-05`) 와 내장 패턴 · 민감 파일 목록 `references/secret-rules.json`
- 검증기 `scripts/validate-git-secret.sh` — 훅 모드(PreToolUse `Bash` 의 `git commit` · `git push` 차단, `Write|Edit|MultiEdit` 경고)와 CLI 모드(`<파일|디렉터리>` · `--all` · `--history`). 탐지는 gitleaks, 없으면 내장 패턴
- `secret-review` 스킬, `/secret-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
