# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/evidence-rules.md` (`E-01` ~ `E-30`), 근거 `evidence-methods.md` (#138)
- `evidence-reviewer` 에이전트 — 요청 원문 · 바뀐 파일 · 결론 없는 질문만 받아 변경마다 필요성 · 정확성을 근거 → 판정 순으로 낸다. 작업 트리를 바꾸지 않고 수정 전 동작은 임시 워크트리에서 돌린다
- `evidence-review` 스킬 — 주장을 열린 질문으로 바꿔 넘기고 판정대로 고침 · 되돌림 · `미확인` 표시, 재검증 2회 상한
- `evidence-validate.sh` — 테스트 약화 신호 `E-20` (PostToolUse `Write|Edit|MultiEdit`, CLI `--diff` · `--strict`), 완료 게이트 `E-30` (Stop, `EVIDENCE_REVIEW_GATE=0` 으로 끔)
- `/evidence-validate` 커맨드, 회귀 테스트 `test/`, eval 케이스 셋
