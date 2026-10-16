# CHANGELOG

## 0.1.1

### Fixed
- gitleaks 실행이 실패하면 커밋을 통과시키던 것 — 내장 패턴으로 다시 보고 알린다 (#73, `GS-05`). 실패 처리가 파이프 서브셸 안이라 빈 결과로 exit 0 이었다
- `git commit <경로>` · `--only` · `-i` 가 커밋하는 작업 트리 내용을 보지 않던 것 (#73)

## 0.1.0

### Added
- 규칙 원본 `references/secret-rules.md` (`GS-01` ~ `GS-05`) 와 내장 패턴 · 민감 파일 목록 `references/secret-rules.json`
- 검증기 `scripts/validate-git-secret.sh` — 훅 모드(PreToolUse `Bash` 의 `git commit` · `git push` 차단, `Write|Edit|MultiEdit` 경고)와 CLI 모드(`<파일|디렉터리>` · `--all` · `--history`). 탐지는 gitleaks, 없으면 내장 패턴
- `secret-review` 스킬, `/secret-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
