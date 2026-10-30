# 근거

[`design-soundness-rules.md`](design-soundness-rules.md) 의 조항이 기대는 출처다.

- 출처는 2026-10-30 에 확인했다. 식별자는 Crossref · arXiv · 원문 페이지로 존재를 확인한 것만 둔다.
- 확인 수준:
  - **지지**: 초록 · 원문이 이 표의 내용을 말한다
  - **부분**: 원문이 일부만 말한다. 내용을 원문 범위로 좁혀 적었다
  - **서지만**: 존재는 확인했고 초록 · 원문은 열지 못했다
- **선택**: 직접 다룬 연구가 없어 다른 분야 방법을 옮기거나 이 플러그인이 정한 것이다. 문턱(3줄 · 반박 2개 · 재검토 2회)과 필수 절 목록 · 패턴도 여기다.
- LLM 으로 설계를 검토하는 연구는 거의 전부 프리프린트다 (Schmid et al. 2025, arXiv:2505.16697 — 18편 대상 SLR). 판정 품질은 근거가 아니라 eval(심은 결함을 찾는가)로 확인한다.

## 1. 다른 문맥이 판정한다 — `DD-01` · `DD-02` · `DD-10`

`common-evidence-review` 의 `references/evidence-methods.md` 1 · 2 · 4절과 같다 — 외부 피드백 없는 자기 수정은 정확도를 올리지 못하고, 검증자에게 작성자의 결론을 보여 주면 판정이 끌린다.

| 출처 | 내용 | 확인 |
|---|---|---|
| He et al., "LLM-as-a-Judge for Software Engineering: Literature Review, Vision, and the Road Ahead", 2025, arXiv:2510.24367 | SE 산출물의 LLM 평가자 연구를 정리하고 평가자 자체의 검증을 과제로 든다 | 지지 · 프리프린트 |
| Fandina et al., "Automated Validation of LLM-based Evaluators for Software Engineering Artifacts", 2025, arXiv:2508.02827 | LLM 평가자를 검증하는 프레임워크 | 지지 · 프리프린트 |

## 2. 기준을 먼저 정하고 설계를 요약한다 — `DD-03` · `DD-15`

| 출처 | 내용 | 확인 |
|---|---|---|
| NASA Systems Engineering Handbook (NASA/SP-2016-6105 Rev2) 6.7 Technical Assessment | 검토마다 목적 · 목표 · 진입 기준 · 성공 기준을 정한다 | 지지 |
| Kazman, Klein, Clements, "ATAM: Method for Architecture Evaluation", CMU/SEI-2000-TR-004, 2000, DOI 10.21236/ada382629 | ATAM 의 기반과 절차. 평가 전에 아키텍처 접근과 품질 속성을 정리한다는 절차 세부는 초록에서 확인하지 못했다 | 부분 |

## 3. 논증과 반박 — `DD-04` · `DD-05`

| 출처 | 내용 | 확인 |
|---|---|---|
| OMG, Structured Assurance Case Metamodel (SACM) 2.3, 2023 — OMG 명세 formal/23-05-08 | 요구 충족 주장을 뒷받침하는 감사 가능한 주장 · 논증 · 증거의 메타모델 | 지지 |
| Weinstock 외 2명, "Measuring assurance case confidence using Baconian probabilities", ASSURE 2013, DOI 10.1109/assure.2013.6614264 | 제거된 의심(doubt)으로 보증 사례의 신뢰도를 평가한다 | 지지 |
| Viger et al., "AI-Supported Eliminative Argumentation", ISSRE 2024, DOI 10.1109/issre62328.2024.00035 | LLM 이 만든 반박(defeater)이 정보성이 있었고 약 25% 가 개발자에게 합리적 의심으로 확인됐다 | 부분 |
| Diemert et al., "Incremental Assurance Through Eliminative Argumentation", Journal of System Safety 2023, DOI 10.56094/jss.v58i1.215 | 증거가 늘어남에 따라 신뢰를 점진적으로 높이는 보증 | 지지 |
| Klein, "Performing a Project Premortem", Harvard Business Review 85(9), 2007-09 | 이미 실패했다고 가정하고 원인을 적게 해 위험을 드러낸다 | 지지 |
| Toulmin, The Uses of Argument, Cambridge University Press 2003, DOI 10.1017/cbo9780511840005 | 논증 구조 모형. 소프트웨어 설계에 쓴 연구는 찾지 못해 **선택**이다 | 지지 (이론서) |

## 4. 모순 · 용어 · 전개 — `DD-06` · `DD-14` · `DD-24`

| 출처 | 내용 | 확인 |
|---|---|---|
| Hunter, Nuseibeh, "Managing inconsistent specifications", ACM TOSEM 1998, DOI 10.1145/292182.292187 | 불일치가 있는 명세에서도 추론을 이어 가는 방법 | 지지 |
| Easterbrook, Nuseibeh, "Managing inconsistencies in an evolving specification", IEEE RE 1995, DOI 10.1109/isre.1995.512545 | 진화하는 명세의 불일치를 기록해 관리한다 | 지지 |
| Fantechi et al., "Inconsistency Detection in Natural Language Requirements using ChatGPT: a Preliminary Evaluation", IEEE RE 2023, DOI 10.1109/re57278.2023.00045 | ChatGPT 의 요구사항 불일치 검출을 측정한 예비 평가 | 지지 |
| Misra, "Terminological inconsistency analysis of natural language requirements", IST 2016, DOI 10.1016/j.infsof.2015.11.006 | 요구사항의 용어 불일치 분석 | 서지만 |
| Yang et al., "Analysing anaphoric ambiguity in natural language requirements", Requirements Engineering 2011, DOI 10.1007/s00766-011-0119-y | 요구사항의 대용어 모호성 분석 | 서지만 |
| Google, Technical Writing One (Google for Developers 기술 글쓰기 과정) | 독자 · 문단 · 명확한 문장. `DD-14` · `DD-24` 는 이것을 설계 전개에 옮긴 **선택**이다 | 지지 |

## 5. 플로우 — `DD-07` · `DD-13` · `DD-21`

| 출처 | 내용 | 확인 |
|---|---|---|
| van der Aalst et al., "Soundness of workflow nets: classification, decidability, and analysis", TU Eindhoven Computer Science Report 08-13, 2008 | 데드락 · 라이브락 같은 이상을 거르는 건전성의 정의와 판정 가능성 | 지지 |
| Knapp, Mossakowski, "Multi-view Consistency in UML", 2016, arXiv:1610.03960 | 다중 뷰 일관성 검사는 대부분 구조만 다루고 행위는 적다 | 지지 · 프리프린트 |
| Cicchetti et al., "Multi-view approaches for software and system modelling: a systematic literature review", Software and Systems Modeling 2019 (Mälardalen University 출판 목록 5387) | 40편 분석, 의미적 일관성 관리 지원이 부족하다 | 지지 |
| Newcombe et al., "How Amazon Web Services Uses Formal Methods", CACM 2015, DOI 10.1145/2699417 | TLA+ 로 설계의 미묘한 버그를 막았다. 동시성 · 분산 플로우에 모델 작성을 권하는 근거 | 부분 |
| Bornholt et al., "Using Lightweight Formal Methods to Validate a Key-Value Storage Node in Amazon S3", SOSP 2021, DOI 10.1145/3477132.3483540 | 산업 현장의 경량 형식 기법 적용 | 지지 |
| Bisharat et al., "Can LLMs Write Correct TLA+ Specifications?", ICSOFT 2026, DOI 10.5220/0015070400004088 | 자연어 → TLA+ 생성 평가. 모델을 자동 생성하지 않는 이유 | 지지 |

`DD-13` 의 단계별 기여 판정은 `common-evidence-review` `E-05`(되돌려도 깨지는 것이 없으면 불필요)를 플로우에 옮긴 **선택**이다.

## 6. 요구 적합과 결정 — `DD-08` · `DD-09` · `DD-20` · `DD-22` · `DD-23`

| 출처 | 내용 | 확인 |
|---|---|---|
| Kazman et al., "The architecture tradeoff analysis method", ICECCS 1998, DOI 10.1109/iceccs.1998.706657 | 품질 속성 간 트레이드오프를 시나리오로 분석한다 | 지지 |
| Ali Babar 외 1명, "Comparison of Scenario-Based Software Architecture Evaluation Methods", APSEC 2004, DOI 10.1109/apsec.2004.38 | 시나리오 기반 평가 방법 4개를 프레임워크로 비교한다 | 지지 |
| arc42 문서 Section 10 Quality Requirements (Tip 10-8) | 품질 시나리오로 품질 요구를 구체화해야 충족 여부를 판정할 수 있다 | 지지 |
| van Heesch et al., "Decision-Centric Architecture Reviews", IEEE Software 2014, DOI 10.1109/ms.2013.22 | 설계 결정을 단위로 평가한다 | 지지 |
| MADR 4.0.0 (Markdown Architectural Decision Records, adr GitHub 조직, 2024-09-17) | 맥락 · 고려한 선택지 · 결정(결과 · 확인) 절. `DD-20` 절 목록의 출처 | 지지 |
| Orosz, "Companies Using RFCs or Design Docs and Examples of These", The Pragmatic Engineer 블로그, 2022-06-21 (2024-02-07 갱신) | 회사별 RFC 항목. `DD-20` 절 목록의 출처 | 지지 · 기술 매체 |
| Rust RFC process — 저장소 rust-lang/rfcs 의 README.md | 단점 · 대안 서술이 평가에 영향을 준다 | 부분 |
| Thoughtworks Technology Radar, "Architectural fitness function" (Techniques, 2017-11 · 2018-05, Trial) | 설계 목표에 대한 객관적 검사. 결정의 확인 방법 | 지지 · 현재 판에는 없음 |
| ISO/IEC/IEEE 29148-2011 (IEEE SA 표준 페이지, 2018판으로 대체됨) | 좋은 요구사항의 개념과 속성 · 특성. `DD-22` 의 근거로는 약하다 | 부분 |

## 7. 남의 설계 — `DD-12`

| 출처 | 내용 | 확인 |
|---|---|---|
| Clements, "Active Reviews for Intermediate Designs", CMU/SEI-2000-TN-009, 2000 (SEI Digital Library) | 시나리오 평가와 능동 설계 리뷰를 결합해 그 설계를 쓸 사람에게 써 보게 하며 검토한다 | 지지 |
| Fagan, "Design and code inspections to reduce errors in program development", IBM Systems Journal 1976, DOI 10.1147/sj.153.0182 | 단계마다 목적을 나누고 종료 기준을 둔다 | 지지 |

## 8. 쓰지 않은 것

- 관점마다 검증자를 나누는 관점 기반 읽기(Basili et al. 1996, DOI 10.1007/bf00368702) — 초록을 확인하지 못했고 비용이 관점 수만큼 는다.
- 다중 에이전트 토론 — 실패 조건이 보고돼 있다 (Chen et al. 2025, arXiv:2510.20963, 프리프린트).
