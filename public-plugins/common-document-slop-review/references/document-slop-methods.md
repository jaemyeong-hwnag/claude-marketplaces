# 근거

[`document-slop-rules.md`](document-slop-rules.md) 의 조항이 기대는 출처다.

- 출처는 2026-10-21 에 원문과 대조했다.
- 확인 수준 표기:
  - **원문**: 원문을 직접 열어 확인함
  - **2차**: 보도 · 인용으로만 확인함
- 수치는 출처의 측정값이다. 이 플러그인의 임계값은 출처가 정한 것이 아니다 (5절).

## 1. slop 의 정의

| 출처 | 내용 | 확인 |
|---|---|---|
| Merriam-Webster, 2025 올해의 단어 "slop" (2025-12-15) | "digital content of low quality that is produced usually in quantity by means of artificial intelligence" | 2차 |
| Macquarie Dictionary, 2025 올해의 단어 "AI slop" (2025-11-25) | "low-quality content created by generative AI, often containing errors, and not requested by the user" | 2차 |
| American Dialect Society, 2025 올해의 단어 "slop" (2026-01-09) | 대개 생성형 AI 가 만드는 저품질 · 대량 콘텐츠 | 원문 |
| Simon Willison, "Slop is the new name for unwanted AI-generated content" (2024-05-08) | 생각 없이 생성돼 요청하지 않은 사람에게 떠안겨진 것. spam 과 같은 쓰임 | 원문 |
| Shaib, Chakrabarty, Garcia-Olano, Wallace, "Measuring AI 'Slop' in Text" (arXiv 2509.19163) | 분류 체계(아래)를 제시한다. 이진 판정은 주관적이다. 제로샷 LLM 판정기(GPT-5 · DeepSeek-V3 · o3-mini)와 사람 주석의 일치도(κ)는 거의 0 이었다 | 원문 |
| Kommers et al., "Why Slop Matters" (ACM AI Letters, 2025-12) | 원형적 특징 셋: superficial competence, asymmetric effort, mass producibility | 원문 |
| Niederhoffer, Hancock et al., "AI-Generated Workslop Is Destroying Productivity" (HBR, 2025-09-22) | 좋은 작업물로 위장했지만 과제를 진척시킬 실질이 없는 콘텐츠. 사무직 40% 가 한 달 안에 받았다. 건당 약 2시간, 1인당 월 $186 | 원문 · 2차 |

Shaib 분류와 이 플러그인 조항의 대응:

| Shaib 차원 | 조항 |
|---|---|
| Density | `DS-21` |
| Relevance | `DS-22` |
| Factuality | `DS-05` ~ `DS-07` · `DS-20` |
| Repetition | `DS-16` · `DS-23` |
| Templatedness | `DS-08` · `DS-11` |
| Verbosity | `DS-13` · `DS-21` |
| Tone | `DS-12` |
| Coherence | `DS-24` |

## 2. 차단 조항 `DS-01` ~ `DS-04`

| 출처 | 내용 | 확인 |
|---|---|---|
| Wikipedia, 빠른 삭제 기준 G15 (2025-08 신설) | 아래 셋 중 하나가 있으면 AI 생성 문서를 바로 지운다. **일반적인 LLM 문체 신호만으로는 적용하지 않는다** | 원문 |
| | 1. 사용자에게 하는 말 · 빈 플레이스홀더 | |
| | 2. 존재하지 않거나 엉뚱한 참고문헌 | |
| | 3. 챗봇 인용 토큰 같은 기술적 흔적 | |
| Wikipedia, Signs of AI writing (WikiProject AI Cleanup) | `oaicite` · `contentReference` · `turn0search0` · `utm_source=chatgpt.com` 같은 흔적과 협업 투 문구를 표지로 든다 | 원문 |
| GitLab Documentation Style Guide, "AI-generated content" | "Do not invent command syntax, API parameters, or UI element names." | 원문 |

## 3. 경고 조항 `DS-05` ~ `DS-16`

| 조항 | 출처 | 내용 | 확인 |
|---|---|---|---|
| `DS-05` | Wikipedia Signs of AI writing | 모호한 출처 표현 ("Experts argue") | 원문 |
| `DS-05` | Liang et al., ICML 2024 (학회 심사문 연구) | "et al." 인용이 없는 심사문에서 LLM 수정 비율이 더 높았다 | 원문 |
| `DS-05` · `DS-07` | Grafana Writers' Toolkit, AI quick reference | 제품 동작 · 기본값 주장은 출처 파일 · 페이지로 뒷받침한다. 검증하지 못하면 `[UNVERIFIED]` 로 표시한다 | 원문 |
| `DS-06` | Anthropic, Skill authoring best practices | 시점에 따라 달라지는 정보를 쓰지 않는다 | 원문 |
| `DS-07` | Vectara Hallucination Leaderboard (2026-10-16 갱신) | 원문을 주고 요약만 시켜도 모델에 따라 1.8 ~ 24.2% 를 지어낸다 | 원문 |
| `DS-07` | Microsoft Azure AI Content Safety, Groundedness detection | 제품명 · 버전은 릴리즈 노트 같은 원천과 대조한다 | 원문 |
| `DS-08` · `DS-09` | Anthropic, Prompting Claude Opus 5 | "do not pad with filler sections, redundant summaries, or boilerplate" | 원문 |
| `DS-08` · `DS-09` | GitLab 스타일 가이드 "Repetition" | "Do not summarize what was just explained. Do not restate the title or introduction in the first paragraph." | 원문 |
| `DS-08` · `DS-13` | Vale 패키지 ai-tells (v1.37.0, 규칙 137개) | Metacommentary · StructureAnnouncements · WrapUpHeadings · StackedHedges · ContrastiveNegation | 원문 |
| `DS-10` | Kobak et al., Science Advances 11(27) (2025-07) | 2024 PubMed 초록의 최소 13.5% 가 LLM 을 거쳤다. 기대 빈도 대비 `delves` 28.0배, `underscores` 13.8배, `showcasing` 10.7배 | 원문 |
| `DS-10` | Liang et al., ICML 2024 | 심사문에서 `meticulous` 34.7배, `intricate` 11.2배, `commendable` 9.8배 | 원문 |
| `DS-10` | Wikipedia Signs of AI writing | 단어 한두 개는 우연일 수 있다. 여러 개가 몰리면 강한 신호다. 과용 어휘는 시기마다 바뀐다 | 원문 |
| `DS-10` | Lee, "An LLM-Associated Register Shift in Korean Journal Abstracts" (arXiv 2609.07447, 2026-09) | KCI 초록 398,296편. `시사하다` 출현 비율이 2026년 21.4% 로, 추세 예상치 5.3% 보다 높다 | 원문 |
| `DS-10` | Paech et al., "Antislop" (ICLR 2026) | 일부 slop 패턴은 사람 글보다 1,000배 넘게 자주 나온다. 단순 토큰 금지는 목록이 2,000개에 이르면 출력을 쓸 수 없게 만든다 | 원문 |
| `DS-11` · `DS-12` | Wikipedia Signs of AI writing | 부정 병렬 (`Not just X, but Y`), 홍보성 언어 (`boasts` · `nestled` · `renowned`), 중요성 과장 | 원문 |
| `DS-14` | Anthropic, claude.ai 시스템 프롬프트 (Opus 5.5, 2026-09) | 보고서 · 문서 · 기술 문서는 불릿 · 번호 목록 · 과한 굵게 없이 산문으로 쓴다 | 원문 |
| `DS-14` | Wikipedia Signs of AI writing | 굵게 남용, 인라인 머리말 목록, 이모지 제목 | 원문 |
| `DS-15` | markdownlint MD001 heading-increment | 제목 수준은 한 단계씩 내려간다 | 원문 |
| `DS-16` | GitLab 스타일 가이드 "Repetition" | "Each section should add new information." | 원문 |

## 4. 판단 리뷰 `DS-20` ~ `DS-27` 과 게이트 `DS-30`

| 출처 | 내용 | 확인 |
|---|---|---|
| Min et al., FActScore (EMNLP 2023) | 장문을 원자 사실로 쪼개 뒷받침되는 비율을 잰다. ChatGPT 전기의 점수는 58% 였다 | 원문 |
| Wei et al., SAFE (NeurIPS 2024) | 사실마다 검색으로 검증한다. 사람과 72% 일치했고, 불일치 가운데 76% 는 SAFE 가 맞았다 | 원문 |
| Dhuliawala et al., Chain-of-Verification (ACL Findings 2024) | 초안을 보지 않고 검증 질문에 답하는 방식(factored · two-step)이 joint 보다 낫다. 전기 FActScore 55.9 → 71.4 | 원문 |
| Huang et al., "LLMs Cannot Self-Correct Reasoning Yet" (ICLR 2024) | 외부 피드백 없이 스스로 고치면 효과가 없거나 오히려 나빠진다 | 원문 |
| Zhang, Das, Zhang, "Verbosity ≠ Veracity" (2024-11) | 14개 모델 모두 장황해지는 경향을 보였다. GPT-4 는 50.40%. 장황한 답일수록 불확실성이 높았다 | 원문 |
| Gloaguen et al., "Evaluating AGENTS.md" (arXiv 2602.11988, v3 2026-09) | 컨텍스트 파일은 성공률을 대체로 높이지 못하고, 추론 비용을 평균 20% 넘게 늘린다 | 원문 |
| Claude Code, Best practices | CLAUDE.md 는 줄마다 "Would removing this cause Claude to make mistakes?" 를 묻는다. 지시는 권고이고 강제는 훅이 한다 | 원문 |
| Zheng et al., MT-Bench (NeurIPS 2023) | LLM 판정기에는 위치 · 장황함 · 자기 선호 편향이 있다 | 원문 |
| Sharma et al., "Towards Understanding Sycophancy" (ICLR 2024) | 사람과 선호 모델 모두 설득력 있게 쓴 틀린 답을 고르기도 한다 | 원문 |
| OpenAI Model Spec | "avoid writing uninformative or redundant text". "Don't be sycophantic" | 원문 |
| Diátaxis (Daniele Procida) | tutorial · how-to · reference · explanation 네 유형을 나눈다 | 원문 |
| Vercel, "AGENTS.md outperforms skills in our agent evals" (2026-01-27) | 평가 케이스의 56% 에서 스킬이 아예 호출되지 않았다 | 원문 |
| Giskard Phare (2025-04-30) | "짧게 답하라"는 지시로 환각 저항이 최대 20% 떨어졌다 | 원문 |
| Liang et al., "GPT detectors are biased against non-native English writers" (Patterns, 2023-07) | 탐지기 7종이 TOEFL 에세이에 낸 오탐률은 평균 61.22% 였다 | 원문 |

## 5. 임계값

| 값 | 위치 | 근거 |
|---|---|---|
| `DS-10` 서로 다른 단어 3개 | `document-slop-patterns.json` `min_distinct` | Wikipedia 의 "몰려 있을 때" 를 수로 정했다. 출처가 정한 값은 아니다 |
| `DS-11` 2회 | `min_count` | 한 번은 정상 문장에도 나온다 |
| `DS-14` 굵게 8곳 · 비율 0.5, 머리말 목록 6줄 | `bold_min` · `bold_ratio` · `lead_run` | 이 저장소 문서 340개로 맞췄다. 사람이 다듬은 체크리스트가 걸리지 않게 했다 |
| `DS-16` 40 바이트 | `min_bytes` | 짧은 반복 문구(`없음` 등)를 빼려는 값 |
| `DS-30` 3줄 | 스크립트 `GATE_MIN_LINES` | 오탈자 수정까지 리뷰를 요구하지 않으려는 값 |

이 저장소 문서 340개에 돌린 결과(2026-10-21)는 차단 0건, 경고 93건이었다. 그 가운데 `DS-10` ~ `DS-13` 은 0건이다.
