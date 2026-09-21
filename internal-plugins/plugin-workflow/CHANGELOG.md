# CHANGELOG

## 0.2.0

### Added
- `plugin-create` · `plugin-delete` 스킬 — 생성 체크리스트와 삭제 순서(역참조 → 의존 끊기 → 정리, 태그는 남긴다)
- `eval-all.sh` — 케이스 단위로 필요한 권한만 주고, 리포트는 게시하지 않고(`--no-publish`), 결과는 플러그인 밖에. Bash 샌드박스를 못 쓰는 환경은 실패가 아니라 환경 제한으로
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다 (넷)

### Changed
- `release-plugins.sh` 의 로드 확인을 `claude plugin list --json` 의 `errors` 로 (못 받으면 텍스트). 날짜가 붙은 CHANGELOG 절도 노트로 뽑는다

## 0.1.0

### Added
- 개발 플로우 규칙 원본 `references/workflow-rules.md` (`W-01` ~ `W-10`, 12 단계)
- `validate-workflow.sh` — `PreToolUse(Bash)` 훅으로 브랜치 이름 · main 보호 · 머지 방식 · 최신 확인 · 태그 위치 · PR 템플릿·라벨을 막는다. CLI `--templates` · `--branch` · `--up-to-date`
- `branch-create.sh` · `verify-all.sh` · `release-plugins.sh`
- `issue-create` · `pull-request-create` · `release-create` 스킬, `/workflow-validate` 커맨드
