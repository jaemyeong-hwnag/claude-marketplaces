# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/code-edit-guardrail-rules.md` — 설정 `.claude/code-edit-guardrail.json` 형식과 글롭, 게이트 `G-01` 테스트 동반 · `G-02` 품질 lane · `G-03` 공유자원 확인, 설정 검증 `C-01` ~ `C-05` (#51)
- 훅 스크립트 `scripts/code-edit-guardrail.sh` — UserPromptSubmit 기록 초기화 · PreToolUse 공유자원 확인 · PostToolUse 편집 기록 · Stop 게이트, CLI `validate`. 편집 기록 · 면제 파일은 프로젝트의 `.claude/code-edit-guardrail/` (스스로 ignore)
- 스킬 `code-edit-guardrail-apply` — 스택 감지로 설정 초안을 쓰고 공유자원은 사용자가 확정한다
