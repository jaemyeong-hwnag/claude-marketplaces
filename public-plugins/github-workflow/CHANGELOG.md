# CHANGELOG

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `github-workflow@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- `plugin-workflow`(internal) 에서 GitHub 플로우를 떼어 public 으로 (#12). 규칙 원본 `W-01` ~ `W-10` 과 TC 를 그대로 옮겼다
- `validate-workflow.sh` — `PreToolUse(Bash)` 훅. 브랜치 이름 · 기본 브랜치 보호 · 머지 방식 · 최신 확인 · 태그 위치 · PR 템플릿 · 라벨. CLI `--templates` · `--branch` · `--up-to-date`
- 기본 브랜치를 `origin/HEAD` 에서 읽는다 (없으면 `main`) — 훅과 `branch-create.sh` 모두
- `branch-create.sh`, `/workflow-validate`
- 스킬 `github-template-create`(기본 템플릿 포함) · `issue-create` · `pull-request-create` · `pull-request-merge`
- eval 케이스 — PR 스킬 발동 · main 커밋 차단
