# CHANGELOG

## 0.1.6

### Added
- README 세 언어판에 개인정보 절 — 무엇을 어디에 얼마나 두는지(요청 원문 · 계획 사본 · 고친 설계 문서 · 게이트 상태), 밖으로 보내지 않음, 지우는 법. `plugin.json` 에 `privacyPolicyUrl` (#292)

## 0.1.5

### Fixed
- Anthropic 디렉터리 검증기가 막는 표기를 같은 동작의 표기로 바꿨다 — 따옴표 안에 `>` 가 많은 신호 awk 프로그램은 `scripts/design-soundness-signal-list.sh` 로 옮겨 훅 스크립트가 bash 로 부르고, jq 비교식은 `<` 로 뒤집고, 패턴 문자열의 `>` 는 실행 때 만든 값으로, `${…}` 안에 겹친 따옴표 4곳은 풀어 썼다. 판정 · 출력은 그대로다 (#284, `TC-D96`)

## 0.1.4

### Fixed
- 훅 스크립트 `scripts/design-soundness-validate.sh` 를 Anthropic 디렉터리 검증기가 읽을 수 있게 따옴표 안 명령 치환 · here-document · here-string 을 변수 · 줄 단위 루프로 바꿨다. 판정은 그대로다 (#258)

## 0.1.3

### Changed
- `plugin.json` 에 `license`(MIT)를 적었다 — Anthropic 디렉터리 제출 조건 (#233)

## 0.1.2

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 3건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.1

### Fixed
- 백그라운드로 띄운 `design-soundness-reviewer` 를 띄운 순간(`PostToolUse` 의 `status: "async_launched"`)에 검토함으로 쳐서, 판정이 오기 전에 게이트가 풀리던 것 (#148). 끝났을 때(`SubagentStop`)만 검토함으로 친다. 검토 중에는 `DD-31` 이 같은 계획도 막고, `DD-30` 은 완료 알림을 기다리는 종료를 막지 않으며, `DD-32` 는 알리지 않는다
- 회귀 테스트 `TC-D19` 가 임시 경로에 든 글자(`y` · `Z`)에 걸려 가끔 실패하던 것. 노드 목록이 정확히 `A, B` 로 끝나는지로 본다

## 0.1.0

### Added
- 규칙 원본 `references/design-soundness-rules.md` (`DD-01` ~ `DD-32`), 근거 `design-soundness-methods.md`, 패턴 `design-soundness-patterns.json` (#145)
- `design-soundness-reviewer` 에이전트 — 설계 파일 · 요구 출처 · 결론 없는 질문만 받아 설계 요약을 낸 뒤 논증 · 반박 · 모순 · 전개 · 플로우 건전성 · 플로우 적절성 · 요구 적합 · 결정 기록을 인용 → 판정 순으로 낸다. 설계를 고치지 않는다
- `design-soundness-review` 스킬 — 대상 · 모드(내 설계 / 남의 설계) · 요구 출처를 정하고, 판정대로 고치거나(재검토 2회) 보고서와 설계자에게 물을 질문을 낸다
- `design-soundness-validate.sh` — 기계 신호 `DD-20` ~ `DD-24` (필수 절 · mermaid 플로우 도달성 · 요구 ID · 측정 기준 없는 품질 요구 · 정의 전 용어), 플랜 모드 게이트 `DD-31` (PreToolUse `ExitPlanMode`), 설계 문서 게이트 `DD-30` (Stop), 설계 뒤 첫 코드 편집 알림 `DD-32`
- `/design-soundness-validate` 커맨드, 회귀 테스트 `test/`, eval 케이스 셋
