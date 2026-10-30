# CHANGELOG

## 0.1.2

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 2건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.1

### Fixed
- 백그라운드로 띄운 `evidence-reviewer` 를 띄운 순간(`PostToolUse` 의 `status: "async_launched"`)에 검토함으로 쳐서, 판정이 오기 전에 게이트가 풀리던 것 (#148). 끝났을 때(`SubagentStop`)만 검토함으로 친다. 검증 중에 완료 알림을 기다리며 끝나는 응답은 `E-30` 이 막지 않고 기록을 남긴다
- `UserPromptSubmit` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 요청 원문 기록 없이 통과하던 것 (`plugin-enforcement-effectiveness` `EF-07`)

## 0.1.0

### Added
- 규칙 원본 `references/evidence-rules.md` (`E-01` ~ `E-30`), 근거 `evidence-methods.md` (#138)
- `evidence-reviewer` 에이전트 — 요청 원문 · 바뀐 파일 · 결론 없는 질문만 받아 변경마다 필요성 · 정확성을 근거 → 판정 순으로 낸다. 작업 트리를 바꾸지 않고 수정 전 동작은 임시 워크트리에서 돌린다
- `evidence-review` 스킬 — 주장을 열린 질문으로 바꿔 넘기고 판정대로 고침 · 되돌림 · `미확인` 표시, 재검증 2회 상한
- `evidence-validate.sh` — 테스트 약화 신호 `E-20` (PostToolUse `Write|Edit|MultiEdit`, CLI `--diff` · `--strict`), 완료 게이트 `E-30` (Stop, `EVIDENCE_REVIEW_GATE=0` 으로 끔)
- `/evidence-validate` 커맨드, 회귀 테스트 `test/`, eval 케이스 셋
