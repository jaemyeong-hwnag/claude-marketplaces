# common-design-soundness-review

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

구현 전 소프트웨어 설계(구조 · 플로우 · 결정)의 앞뒤가 맞는지 작성 맥락 없는 검증자가 판정한다 — 플랜 모드 계획 · 대화 속 설계안 · 설계 문서가 대상. 설계 요약을 먼저 내고 근거 · 반박, 모순 · 전개, 플로우의 막힘과 요구에 기여하지 않는 단계, 요구마다 대응 결정을 본다. 검토 없이 플랜 모드를 나가거나 설계 문서를 고치고 끝내면 한 번 되돌린다.

UI · 시각 디자인은 대상이 아니다. 다른 프로젝트에 설치해 두고 작업 중에 설계할 때 쓴다.

설계한 쪽이 자기 설계를 다시 읽는 것은 검토가 되지 않는다. 그래서 판정은 설계에 이른 대화를 모르는 검증자가 하고, 검증자는 설계 파일 · 요구 출처 · 결론 없는 질문만 받는다.

| 층 | 언제 | 하는 것 |
|---|---|---|
| 1. 기계 검사 | 설계 문서를 쓸 때 · 플랜 모드를 나갈 때 | 필수 절 · mermaid 플로우 도달성 · 요구 ID · 숫자 없는 품질 요구 · 정의 전 용어를 알린다 (`DD-20` ~ `DD-24`) |
| 2. 독립 판정 | 스킬이 부를 때 | 검증자가 설계 요약을 낸 뒤 논증 · 반박 · 모순 · 전개 · 플로우 건전성 · 플로우 적절성 · 요구 적합 · 결정 기록을 인용으로 판정한다 (`DD-01` ~ `DD-15`) |
| 3. 게이트 | 구현으로 넘어가기 직전 | 플랜 모드 종료를 한 번 막고(`DD-31`), 설계 문서를 3줄 이상 고친 요청의 종료를 한 번 되돌리고(`DD-30`), 설계 요청 뒤 첫 코드 편집에서 알린다(`DD-32`) |

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-design-soundness-review@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| design-soundness-review | 설계해줘 · 구조 잡아줘 · 플로우 짜줘 · 설계 검토 · 앞뒤 맞아? · 이 설계 괜찮아? | 설계를 파일로 정하고 요구 출처를 찾아(없으면 설계에서 뽑아 확인받음) 결론 없는 질문으로 검증자에게 넘긴다. 내 설계는 판정대로 고치고(재검토 2회), 남의 설계는 보고서와 설계자에게 물을 질문을 낸다 |
| /design-soundness-validate | 직접 호출 | 설계 문서 · 계획 파일(`--plan`)에서 `DD-20` ~ `DD-24` 를 찾는다. `--strict` 면 신호가 있을 때 exit 2 |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| design-soundness-reviewer | 설계 파일 · 요구 출처 · 질문만 받는다. 설계 요약(구성요소 · 결정 · 플로우 표 · 요구 ↔ 결정)을 낸 뒤 관점마다 인용 → 판정(`결함` · `빈 곳` · `판정 불가`)을 낸다. 설계를 고치지 않는다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| design-soundness-validate.sh | UserPromptSubmit | 요청 원문을 기록한다(요구 출처). 설계 신호어가 있으면 설계 요청으로 표시한다 |
| design-soundness-validate.sh | PreToolUse (ExitPlanMode) | 검토 없이 플랜 모드를 나가면 한 번 **막고** 계획 파일 · 기계 신호를 알린다 (`DD-31`) |
| design-soundness-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 설계 문서면 새 기계 신호를 **알린다**. 설계 요청 뒤 첫 코드 편집이면 검토를 알린다 (`DD-32`) |
| design-soundness-validate.sh | PostToolUse (Agent\|Task) | `design-soundness-reviewer` 가 동기로 끝나면 검토함, 백그라운드로 뜨면 검토 중으로 표시한다 |
| design-soundness-validate.sh | SubagentStop | 백그라운드 `design-soundness-reviewer` 가 끝나면 검토함으로 표시한다. 검토 중에는 플랜 모드 게이트가 같은 계획도 막는다 |
| design-soundness-validate.sh | Stop | 프로젝트 안 설계 문서를 3줄 이상 고쳤는데 검토하지 않았으면 종료를 한 번 되돌린다 (`DD-30`) |

## 주의

- **검증자에게 설계에 이른 대화 · 이유를 넘기지 않는다.** 대화 속 설계안은 설계안만 임시 파일로 옮겨 넘긴다.
- 검증자는 `sonnet` 으로 돈다. 설계한 쪽과 다른 모델을 쓰려는 선택이다 (`common-evidence-review` 와 같다).
- 요구 출처가 없으면 요구 적합과 플로우 적절성은 `판정 불가` 다. 스킬이 설계에서 요구를 뽑아 확인받으면 판정한다.
- 설계 문서는 `.md` · `.mdx` · `.markdown` 중에서 경로(`adr/` · `adrs/` · `decisions/` · `rfc/` · `rfcs/` · `design/` · `designs/`, `*-design.md` · `*-rfc.md`) 또는 첫 20줄의 `<!-- design-document -->` 로 판별한다. `DESIGN_SOUNDNESS_PATHS` 에 쉼표로 구분한 글롭을 주면 기본 경로 대신 쓴다.
- 기계 신호는 후보다. 막지 않는다. 같은 파일에서 이미 알린 신호는 다시 알리지 않는다. 의도한 줄이면 그 줄이나 윗줄에 `<!-- design-soundness-ignore -->`.
- `DD-24` 는 용어 절이 결정 절보다 앞에 있거나 결정 절이 없을 때만 본다 — 문서 끝의 용어집은 참고용이다. 한국어 용어는 부분 문자열로 찾는다.
- `DD-22` 의 요구 ID 는 `DESIGN_SOUNDNESS_REQUIREMENT_ID` 로 바꾼다 (기본 `(R|FR|NFR|QA|REQ)-[0-9]+`).
- `DD-21` 은 mermaid 의 간선만 본다. 중첩 상태 · `--x` · `--o` · `---` 간선은 보지 않는다.
- 플랜 모드 게이트
  - 같은 계획으로 다시 나가면 막지 않는다. 단 백그라운드 검증자가 아직 판정 중이면 같은 계획도 막는다. `DESIGN_SOUNDNESS_PLAN_GATE=0` 으로 이것만 끈다.
  - `claude -p`(비대화)에는 `ExitPlanMode` 도구가 없어 돌지 않는다 (2026-10-30, Claude Code 2.1.314 에서 확인).
- `DESIGN_SOUNDNESS_GATE=0` 이면 세 게이트를 모두 끈다. 기계 신호는 그대로 알린다.
- 대화 속 설계는 막지 않고 알린다. 어디까지가 설계인지 기계가 가르지 못한다.
- 설계 문서를 고치면 `common-document-slop-review` 의 게이트도 같이 돌 수 있다. 두 리뷰를 한 번에 돌리면 한 번에 끝난다.
- 스크립트는 bash · awk · jq 를 쓴다. jq 가 없으면 훅은 조용히 통과한다.

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `DD-01` · `DD-02` | 다른 문맥이 판정 · 설계 파일 · 요구 출처 · 질문만 넘김 | AI (스킬) |
| `DD-03` · `DD-15` | 요구 출처를 정함(없으면 추출 후 확인) · 설계 요약을 먼저 | AI |
| `DD-04` · `DD-05` | 논증 구조 · 핵심 결정마다 반박 2개 | AI (에이전트) |
| `DD-06` · `DD-14` | 모순 · 용어 · 전개 | AI (에이전트) |
| `DD-07` · `DD-13` | 플로우 건전성 · 적절성(요구에 기여하지 않는 단계, 대안 비교) | AI (에이전트) |
| `DD-08` · `DD-09` | 요구 시나리오마다 대응 결정 · 결정의 대안 · 확인 방법 | AI (에이전트) |
| `DD-10` ~ `DD-12` | 인용 먼저 · 지어낸 지적 금지 · 내 설계는 고침, 남의 설계는 보고서와 질문 | AI |
| `DD-20` ~ `DD-24` | 필수 절 · 플로우 도달성 · 요구 ID · 숫자 없는 품질 요구 · 정의 전 용어 | 알림 |
| `DD-30` | 설계 문서를 고친 요청이 검토 없이 끝나면 한 번 되돌림 | 게이트 |
| `DD-31` | 검토 없이 플랜 모드를 나가면 한 번 막음 | 게이트 |
| `DD-32` | 설계 요청 뒤 첫 코드 편집에서 알림 | 알림 |

원본: [`references/design-soundness-rules.md`](references/design-soundness-rules.md) · 근거: [`references/design-soundness-methods.md`](references/design-soundness-methods.md)

## 사용

```bash
scripts/design-soundness-validate.sh docs/adr/0003-cancel.md          # 설계 문서의 기계 신호
scripts/design-soundness-validate.sh --plan ~/.claude/plans/x.md      # 계획
scripts/design-soundness-validate.sh --strict docs/adr/*.md           # 신호가 있으면 exit 2 (CI)
test/design-soundness-validate.test.sh                                # 회귀 테스트
```

## 근거

| 조항 | 근거 |
|---|---|
| 시나리오로 요구 적합을 본다 | ATAM (ICECCS 1998) · 시나리오 기반 평가 비교 (APSEC 2004) · arc42 품질 시나리오 |
| 결정 단위 · 확인 방법 | DCAR (IEEE Software 2014) · MADR 4.0.0 · 피트니스 함수 (Thoughtworks Radar) |
| 주장 · 반박 | SACM 2.3 · 제거된 의심으로 신뢰도 (ASSURE 2013) · LLM 반박 생성 (ISSRE 2024) · pre-mortem (HBR 2007) |
| 모순 · 불일치 | 명세 불일치 관리 (TOSEM 1998 · RE 1995) · LLM 요구 불일치 검출 (RE 2023) |
| 플로우 | 워크플로 건전성 (TU/e 2008) · 다중 뷰 일관성 · AWS TLA+ (CACM 2015) |
| 남의 설계 | ARID (SEI 2000) · 인스펙션 (IBM Systems Journal 1976) |
| 다른 문맥 · 결론 없는 입력 | `common-evidence-review` 의 근거와 같다 |

각 항목의 출처 · 확인 수준과 "선택"(직접 근거가 없어 옮겨 쓰거나 정한 것)은 `references/design-soundness-methods.md` 에 있다.

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
