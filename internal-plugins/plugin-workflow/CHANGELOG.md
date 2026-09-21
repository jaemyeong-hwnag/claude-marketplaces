# CHANGELOG

## 0.1.0

### Added
- 개발 플로우 규칙 원본 `references/workflow-rules.md` (`W-01` ~ `W-10`, 12 단계)
- `validate-workflow.sh` — `PreToolUse(Bash)` 훅으로 브랜치 이름 · main 보호 · 머지 방식 · 최신 확인 · 태그 위치 · PR 템플릿·라벨을 막는다. CLI `--templates` · `--branch` · `--up-to-date`
- `branch-create.sh` · `verify-all.sh` · `release-plugins.sh`
- `issue-create` · `pull-request-create` · `release-create` 스킬, `/workflow-validate` 커맨드
