# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/design-soundness-rules.md` (`DD-01` ~ `DD-32`), 근거 `design-soundness-methods.md`, 패턴 `design-soundness-patterns.json` (#145)
- `design-soundness-reviewer` 에이전트 — 설계 파일 · 요구 출처 · 결론 없는 질문만 받아 설계 요약을 낸 뒤 논증 · 반박 · 모순 · 전개 · 플로우 건전성 · 플로우 적절성 · 요구 적합 · 결정 기록을 인용 → 판정 순으로 낸다. 설계를 고치지 않는다
- `design-soundness-review` 스킬 — 대상 · 모드(내 설계 / 남의 설계) · 요구 출처를 정하고, 판정대로 고치거나(재검토 2회) 보고서와 설계자에게 물을 질문을 낸다
- `design-soundness-validate.sh` — 기계 신호 `DD-20` ~ `DD-24` (필수 절 · mermaid 플로우 도달성 · 요구 ID · 측정 기준 없는 품질 요구 · 정의 전 용어), 플랜 모드 게이트 `DD-31` (PreToolUse `ExitPlanMode`), 설계 문서 게이트 `DD-30` (Stop), 설계 뒤 첫 코드 편집 알림 `DD-32`
- `/design-soundness-validate` 커맨드, 회귀 테스트 `test/`, eval 케이스 셋
