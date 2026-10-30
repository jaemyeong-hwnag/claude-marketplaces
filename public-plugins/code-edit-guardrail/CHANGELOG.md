# CHANGELOG

## 0.1.2

### Fixed
- `UserPromptSubmit`(`reset`) · `PreToolUse`(`shared`) 훅에 `"onFailure": "block"` — 스크립트가 깨지면 편집 기록 초기화 · 공유자원 확인(`G-03`) 없이 통과하던 것 (#157, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.1

### Fixed
- 세션 루트 아래 워크트리(`.claude/worktrees/<id>/…`)의 파일을 고치면 기록 경로가 루트 기준 글롭에 안 걸려 `G-01` · `G-02` 가 통과하던 것 — 프로젝트 아래의 다른 git 작업 트리에 있는 파일은 그 작업 트리에 설정이 있으면 그 작업 트리를 루트로 설정 · 상대 경로 · lane 실행 위치를 정한다 (#95). `G-03` 도 같은 루트로 본다

## 0.1.0

### Added
- 규칙 원본 `references/code-edit-guardrail-rules.md` — 설정 `.claude/code-edit-guardrail.json` 형식과 글롭, 게이트 `G-01` 테스트 동반 · `G-02` 품질 lane · `G-03` 공유자원 확인, 설정 검증 `C-01` ~ `C-05` (#51)
- 훅 스크립트 `scripts/code-edit-guardrail.sh` — UserPromptSubmit 기록 초기화 · PreToolUse 공유자원 확인 · PostToolUse 편집 기록 · Stop 게이트, CLI `validate`. 편집 기록 · 면제 파일은 프로젝트의 `.claude/code-edit-guardrail/` (스스로 ignore)
- 스킬 `code-edit-guardrail-apply` — 스택 감지로 설정 초안을 쓰고 공유자원은 사용자가 확정한다
