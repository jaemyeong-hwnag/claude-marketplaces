# 근거

[`evidence-rules.md`](evidence-rules.md) 의 조항이 기대는 출처다.

- 출처는 2026-10-26 에 확인했다.
- 확인 수준 표기:
  - **원문**: 논문 페이지 · 문서를 직접 열어 확인함
  - **2차**: 요약 · 인용으로만 확인함
- 학회 표기는 arXiv 페이지에 없으면 조사 시점의 2차 확인이다.
- 수치는 출처의 측정값이다. 이 플러그인의 문턱(3줄 · 재검증 2회 · 주장 후보 10개)은 출처가 정한 것이 아니다.

## 1. 자기 검증은 검증이 아니다 — `E-01`

| 출처 | 내용 | 확인 |
|---|---|---|
| Huang et al., "Large Language Models Cannot Self-Correct Reasoning Yet", ICLR 2024 (arXiv 2310.01798) | 외부 피드백 없는 자기 수정은 추론 정확도를 올리지 못하고 떨어뜨리기도 한다. 이전 연구의 개선은 정답 라벨을 쓴 결과였다 | 원문 |
| Kamoi et al., "When Can LLMs Actually Correct Their Own Mistakes?", TACL 12 (2024) | 프롬프트만으로 자기 수정에 성공한 사례는 유리한 과제를 빼면 없다. 믿을 만한 외부 피드백이 있으면 된다 | 원문 |
| Stechly et al., "On the Self-Verification Limitations of LLMs on Reasoning and Planning Tasks", ICLR 2025 (arXiv 2402.08115) | 자기 비평은 성능을 떨어뜨리고 건전한 외부 검증기는 올린다. 검증자로서 거짓 음성이 많다 | 2차 |
| Tsui, "Self-Correction Bench", COLM 2026 (arXiv 2507.02778) | 같은 오류를 외부에서 오면 고치고 자기 출력이면 못 고친다. 맹점 비율 평균 64.5% | 원문 |
| Anthropic, "Best practices for Claude Code" | 작업한 에이전트가 자기 결과를 채점하지 않는다. 새 문맥의 리뷰어는 diff 와 기준만 보고 변경을 만든 추론은 보지 않는다 | 원문 |

## 2. 검증자에게 결론을 주지 않는다 — `E-02` · `E-03`

| 출처 | 내용 | 확인 |
|---|---|---|
| Kapetanovic et al., "Anchoring Bias in LLM-as-a-Judge Systems", CIKM 2026 (arXiv 2608.25869) | 이전 판정을 배경 정보로만 줘도 판정이 그쪽으로 끌린다 (8개 중 7개 모델, Cohen's d 최대 0.71). 오류 교정의 48% 를 막았다. CoT 도, "무시하라" 는 경고도 전체 효과를 줄이지 못했다 | 원문 |
| Alexopoulos et al., "Measuring and Exploiting Contextual Bias in LLM-Assisted Security Code Review" (arXiv 2603.18740) | 변경을 "버그 없음" 으로 강하게 소개하면 취약점 탐지가 모델에 따라 16–93%p 떨어진다 (Claude Opus 4.5 는 6.9%p). PR 설명 · 커밋 메타데이터를 가리면 관련 사례 전부에서 회복된다 | 원문 |
| Dhuliawala et al., "Chain-of-Verification Reduces Hallucination in LLMs" (arXiv 2309.11495) | 초안을 보지 않고 검증 질문에 답하는 factored 방식이 모든 과제에서 joint 보다 낫다. 사실을 넣은 예/아니오 질문은 더 나빴고, 저자는 사실이 맞든 틀리든 동의하는 일화 사례를 든다 | 원문 |
| Sharma et al., "Towards Understanding Sycophancy in Language Models", ICLR 2024 (arXiv 2310.13548) | 어시스턴트 5종 모두 사용자 견해에 맞추는 경향이 있다 | 원문 |
| Advani, "From Confident Closing to Silent Failure", FAGEN@ICML 2026 (arXiv 2606.09863) | 실패 중 거짓 성공 보고가 tau2-bench 단일 제어 45–48%, AppWorld 75.8% 다. LLM 판정기는 확신에 찬 마무리 문장 같은 표면 단서에 기대 tau2-bench 에서 AUROC 0.65 를 넘지 못한다 | 원문 |

## 3. 근거 먼저, 없으면 판정 불가 — `E-04` · `E-09`

| 출처 | 내용 | 확인 |
|---|---|---|
| Gou et al., "CRITIC", ICLR 2024 (arXiv 2305.11738) | 검색 · 코드 실행 같은 도구로 검증하면 꾸준히 개선된다 | 원문 |
| Wang et al., "Large Language Models are not Fair Evaluators", ACL 2024 (arXiv 2305.17926) | 순서만 바꿔도 판정이 뒤집힌다. 근거를 먼저 쓰고 판정을 나중에 쓰면 줄어든다 | 원문 |
| Tapwal et al., "Faithful or Fabricated?" (arXiv 2605.23970) | 판정기는 단서에 맞춘 근거를 지어낸다. 근거를 먼저 고정하면 단서에 덜 흔들린다 | 원문 |
| Anthropic, "Demystifying evals for AI agents" (2026-01-09) | 판정기에 "Unknown" 선택지를 주면 지어낸 판정이 준다. 가능하면 결정적 채점기를 쓴다 | 원문 |
| Jin & Chen, ASE 2025 NIER (arXiv 2508.12358) | LLM 은 맞는 코드를 요구사항 위반으로 판정하는 경우가 많고, 수정안까지 요구하면 오판이 는다 | 원문 |
| Anthropic, "Best practices for Claude Code" | 갭을 찾으라고 하면 멀쩡해도 뭔가 보고한다. 정확성 · 요구사항에 영향 있는 것만 보고하게 한다 | 원문 |

## 4. 필요성은 정확성과 따로 — `E-05` · `E-06`

| 출처 | 내용 | 확인 |
|---|---|---|
| Zhu et al., "When Models Edit Too Much", EMNLP 2026 (arXiv 2609.04061) | 강한 모델도 과잉 편집이 흔하고 Pass@1 이 높으면서 불필요하게 크게 고친다. 보존 지시를 주면 초과 편집거리 0.195 → 0.131. 모델 크기 · 추론 예산으로는 해결되지 않는다 | 원문 |
| Wang, Pradel, Liu, "Are 'Solved Issues' in SWE-bench Really Solved Correctly?", ICSE 2026 (arXiv 2503.15223) | 테스트를 통과한 패치의 29.6% 가 정답과 동작이 다르다. 동작 차이의 원인 중 27.3% 는 정답보다 더 많은 동작을 바꾼 것이다 | 원문 |

## 5. 버그 주장은 재현으로 — `E-07`

| 출처 | 내용 | 확인 |
|---|---|---|
| Mündler et al., "SWT-Bench", NeurIPS 2024 (arXiv 2406.12952) | 이슈를 재현하는 테스트를 생성해 패치 필터로 쓰면 SWE-Agent 의 정밀도가 두 배다 | 원문 |
| Xia et al., "Agentless", FSE 2025 (arXiv 2407.01489) | 패치 검증 단계에서 오류 재현 테스트로 후보 패치를 고른다 | 2차 |
| Guo et al., "SWE-Doctor" (arXiv 2607.00990) | 수정 후에도 실패하는 재현 테스트는 에이전트를 오도한다 | 원문 |
| Agarwal, "Refute-or-Promote" (arXiv 2604.19049) | 리뷰어 10명이 만장일치로 지지한 취약점이 실재하지 않았고 실증 테스트 하나로 기각됐다 | 원문 |

## 6. 테스트 통과 주장은 테스트를 본다 — `E-08` · `E-20`

| 출처 | 내용 | 확인 |
|---|---|---|
| Zhong, Raghunathan, Carlini, "ImpossibleBench" (arXiv 2510.20270) | 명세와 모순된 테스트를 통과시키려고 테스트를 고치거나 지우고, 연산자 오버로딩까지 쓴다 | 원문 |
| Aleithan et al., "SWE-Bench+" (arXiv 2410.06992) | 성공 패치의 31.08% 는 약한 테스트 때문에 의심스럽다 | 원문 |
| Anthropic, "Effective harnesses for long-running agents" (2025-11-26) | Claude 는 제대로 테스트하지 않고 완료로 표시하는 경향이 있었다. "테스트를 지우거나 고치는 것은 허용되지 않는다" 로 대응했다 | 원문 |
| Guo et al., "Are Your Agents Upward Deceivers?" (arXiv 2512.04864) | 도구가 고장 난 환경에서 결과 추측 · 파일 날조로 실패를 숨긴다 | 원문 |

## 7. 검증자는 하나, 재검증엔 상한 — `E-11`

| 출처 | 내용 | 확인 |
|---|---|---|
| Smit et al., "Should we be going MAD?", ICML 2024 (arXiv 2311.17371) | 토론은 self-consistency · 다중 경로 앙상블을 안정적으로 넘지 못한다 | 원문 |
| Choi, Zhu, Li, "Debate or Vote", NeurIPS 2025 (arXiv 2508.17536) | 토론 이득의 대부분은 다수결에서 온다 | 원문 |
| Panickssery et al., "LLM Evaluators Recognize and Favor Their Own Generations", NeurIPS 2024 (arXiv 2404.13076) | 판정기는 자기 텍스트를 알아보고 더 높게 평가한다 — 검증자 모델을 작성자와 다르게 두는 이유 | 원문 |
| Anthropic, "Building effective agents" (2024-12-19) | 매 단계 환경에서 ground truth 를 얻는다. 반복 상한 같은 정지 조건을 둔다 | 원문 |
| OpenAI, "A practical guide to building agents" | 실패 임계를 넘거나 비가역 작업이면 사람에게 넘긴다 (발행일 미확인) | 2차 |

## 8. Stop 의 agent 훅을 쓰지 않는 이유

Claude Code hooks 문서(2026-10-26, Claude Code 2.1.310)에서 확인했다.
- agent 훅은 "spawns a subagent with your prompt and the hook's JSON input" 이다.
- Stop 입력에는 `last_assistant_message`, 곧 작성자의 최종 답이 들어 있다. 그래서 검증자에게 결론을 주게 된다 (`E-02` 위반).
- Stop 은 응답이 끝날 때마다 돈다. 그래서 고친 것이 없는 응답에도 검증자를 띄운다.
- agent 훅은 실험 기능이다.
