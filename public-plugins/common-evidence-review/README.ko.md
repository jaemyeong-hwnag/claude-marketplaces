# common-evidence-review

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

AI 가 한 변경과 주장이 진짜 필요한지 · 맞는지를 작성 맥락 없는 검증자가 실행 근거로 판정한다 — 결론을 뺀 열린 질문만 넘김, 근거 먼저 · 없으면 판정 불가, 버그 주장은 수정 전 실패 · 후 통과 재현, 테스트 약화(skip · 단언 감소) 알림, 코드를 고치고 검증 없이 끝내면 한 번 되돌림.

작성한 모델이 자기 결과를 다시 읽는 것은 검증이 되지 않는다. 그리고 검증자에게 작성자의 결론을 보여 주면 판정이 그쪽으로 끌린다. 그래서 검증은 다른 문맥이 하고, 검증자는 결론을 받지 않는다.

| 층 | 언제 | 하는 것 |
|---|---|---|
| 1. 기계 검사 | 테스트 파일을 고칠 때마다 | skip · focus 표지가 늘거나 단언이 줄면 알린다 (`E-20`) |
| 2. 독립 판정 | 리뷰할 때 | 요청 원문 · 바뀐 파일 · 결론 없는 질문만 받은 검증자가 변경마다 필요성 · 정확성을 판정한다 (`E-01` ~ `E-11`) |
| 3. 완료 게이트 | 요청이 끝날 때 | 코드 · 설정을 고쳤는데 2층을 건너뛰었으면 한 번 되돌린다 (`E-30`) |

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-evidence-review@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| evidence-review | 진짜 필요해? · 사실확인 · 검증해줘 · 맞는지 확인 · 불필요한 변경 | 주장을 결론 없는 열린 질문으로 바꿔 검증자에게 넘기고, 판정대로 고침 · 되돌림 · `미확인` 표시를 한다. 재검증 2회 상한 |
| /evidence-validate | 직접 호출 | 기본 브랜치 대비 변경 · 추적되지 않는 파일에서 테스트 약화 신호(`E-20`)를 찾는다. `--strict` 면 신호가 있을 때 exit 2 |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| evidence-reviewer | 요청 원문 · 바뀐 파일 · 질문만 받는다. 변경마다 필요성(`필요함` · `불필요함` · `판정 불가`)과 정확성(`맞음` · `틀림` · `판정 불가`)을 근거 → 판정 순으로 낸다. 코드를 고치지 않고, 수정 전 동작은 임시 워크트리에서 돌린다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| evidence-validate.sh | UserPromptSubmit | 요청 원문을 기록한다. 게이트가 검증자에게 넘길 기준이다 |
| evidence-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 바꾼 파일 · 줄 수를 기록하고, 테스트 파일이면 `E-20` 신호를 **알린다** |
| evidence-validate.sh | PostToolUse (Agent\|Task) | `evidence-reviewer` 가 동기로 끝나면 검증함, 백그라운드로 뜨면 검증 중으로 표시한다 |
| evidence-validate.sh | SubagentStop | 백그라운드 `evidence-reviewer` 가 끝나면 검증함으로 표시한다 |
| evidence-validate.sh | Stop | 코드 · 설정을 고쳤는데 검증하지 않았으면 종료를 한 번 되돌린다 (`E-30`). 되돌림 메시지에 바꾼 파일 · 요청 기록 · 최종 답의 주장 후보를 넣는다. 백그라운드 `evidence-reviewer` 가 검증 중이면 막지 않는다 |

## 주의

- **검증자에게 작성자의 이유 · 요약 · 커밋 메시지를 넘기지 않는다.** "무시하라" 고 덧붙여도 판정이 끌린다.
- 검증자는 `sonnet` 으로 돈다. 작성자와 다른 모델이면 자기 선호 편향이 줄어든다.
- 검증자는 테스트 · 스크립트를 실행한다. 프로젝트 명령을 돌릴 수 있는 권한이 있어야 판정이 `판정 불가` 로 빠지지 않는다.
- `불필요함` 은 "요청 문장에 대응하지 않고 되돌려도 깨지는 것이 없다" 는 뜻이다. 사용자가 원했을 수 있는 변경이면 스킬이 되돌리기 전에 묻는다.
- 완료 게이트
  - 한 요청에서 프로젝트 안 코드 · 설정을 3줄 이상 바꿨을 때만 돈다. `EVIDENCE_REVIEW_MIN_LINES` 로 바꾼다.
  - 문서(`.md` 등)는 세지 않는다 — `common-document-slop-review` 의 몫이다. `requirements.txt` · `CMakeLists.txt` 같은 설정은 센다.
  - Bash 로 바꾼 파일은 훅이 보지 못한다.
  - 한 요청에서 두 번 막지 않는다. 다만 검증 뒤에 또 고치면 그 편집으로 다시 판정한다. 끄려면 `EVIDENCE_REVIEW_GATE=0`
- `E-20` 은 알림이다. 테스트를 일부러 바꾼 것일 수 있어서 막지 않는다.
- 스크립트는 bash · jq · grep 을 쓰고, `--diff` 에는 git 을 쓴다. jq 가 없으면 훅은 조용히 통과한다.

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `E-01` ~ `E-03` | 다른 문맥이 검증 · 결론을 넘기지 않음 · 주장은 열린 질문으로 | AI (스킬) |
| `E-04` ~ `E-09` | 근거 먼저 · 필요성 · 정확성 · 버그는 재현으로 · 테스트 자체 검사 · 지어낸 지적 금지 | AI (에이전트) |
| `E-10` | 검증자는 작업 트리를 바꾸지 않음 | AI (에이전트) |
| `E-11` | 틀림은 고침 · 불필요함은 되돌림 · 판정 불가는 `미확인` · 재검증 2회 | AI (스킬) |
| `E-20` | 테스트 파일의 skip · focus 표지 증가 · 단언 감소 | 알림 |
| `E-30` | 코드 · 설정을 고친 요청이 검증 없이 끝나면 한 번 되돌림 | 게이트 |

원본: [`references/evidence-rules.md`](references/evidence-rules.md) · 근거: [`references/evidence-methods.md`](references/evidence-methods.md)

## 사용

```bash
scripts/evidence-validate.sh --diff            # 기본 브랜치 대비 테스트 약화 신호
scripts/evidence-validate.sh --diff --strict   # 신호가 있으면 exit 2 (CI)
test/evidence-validate.test.sh                 # 회귀 테스트
```

## 근거

| 조항 | 근거 |
|---|---|
| 자기 검증 무효 | Huang et al. ICLR 2024 · Kamoi et al. TACL 2024 · Self-Correction Bench |
| 결론을 넘기지 않음 | 앵커링 CIKM 2026 · 보안 코드 리뷰 맥락 편향 · Chain-of-Verification · sycophancy |
| 근거 먼저 · 판정 불가 | CRITIC · Wang et al. ACL 2024 · Anthropic evals |
| 필요성 분리 | 과잉 편집 EMNLP 2026 · "Solved Issues" ICSE 2026 |
| 재현 | SWT-Bench · Agentless · SWE-Doctor · Refute-or-Promote |
| 테스트 약화 | ImpossibleBench · SWE-Bench+ · Anthropic 장기 실행 하네스 |
| 검증자 하나 | 다중 에이전트 토론 비교 연구 (ICML 2024 · NeurIPS 2025) |

각 항목의 출처 · 확인 수준은 `references/evidence-methods.md` 에 있다.

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
