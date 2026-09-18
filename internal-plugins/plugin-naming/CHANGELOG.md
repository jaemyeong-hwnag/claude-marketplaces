# CHANGELOG

## 0.1.0

- 네이밍 규칙 원본 `references/naming-rules.md` 와 단어 사전 `references/glossary.json` 추가
- 이름 검증기 `scripts/validate-naming.sh` 추가 — 훅 모드와 CLI 모드(`--all` · `--glossary`)
- `Write`/`Edit` PreToolUse·PostToolUse 훅 연결
- `name-create` · `glossary-update` 스킬, `naming-reviewer` 에이전트, `/naming-review` 커맨드 추가
- 이름 슬롯을 `{대상}-{범위}-{관심사}-{목적}` 으로 확장하고 끝 단어를 사전으로 강제
- 정량 검증과 AI 판단을 분리 — 기계 규칙을 통과한 이름은 모두 판단으로 넘긴다
- 사전에 `role` 카테고리와 구조·이름 단어 추가
- 회귀 테스트 TC 86건 추가
