# reference-search 근거

기준일 2026-10. 이 플러그인의 검색 오케스트레이션 · 출처 판정 · 검증 · 식별자 차단 설계가 기대는 연구와 문서를 원칙별로 정리한다.

- 출처는 2026-10-26 에 원문 · 메타데이터와 대조했다.
- 확인 수준 표기:
  - **원문**: 원문(초록 · 본문)을 직접 열어 확인함
  - **2차**: 검색 요약 · 보도로만 확인함
  - **실측**: 이 문서를 쓰며 API 를 직접 호출해 확인함
  - **미확인**: 원문에서 확인하지 못함. 설계 근거로 단독 사용하지 않는다
- 수치는 출처의 측정값이다. 이 플러그인의 상한 · 임계값이 출처에서 온 것이 아니면 그렇다고 적는다.
- `[n]` 은 7절 참고문헌 번호다.

## 1. 멀티 에이전트 검색 오케스트레이션

| 번호 | 원칙 | 이 플러그인에서 | 근거 |
|---|---|---|---|
| P1 | 에이전트 수 · 도구 호출 수를 요청 복잡도에 맞춘다 | 단순 확인은 에이전트 1개 · 호출 3~10회. 비교는 출처별 2~4개 · 각 10~15회. 넓은 조사는 출처 × 하위 주제로 나눠 그 이상. 상한은 이 플러그인이 정한다 (출처의 값 아님) | [1] |
| P2 | 쪼갤 수 있는 일만 병렬로 돌린다 | 출처(논문 · 기업 사례 · 공식 문서)끼리는 독립이라 병렬로 돌린다. 앞 결과가 다음 검색어를 정하는 순차 작업(스노볼링 등)은 한 에이전트 안에서 한다 | [1] [2] |
| P3 | 병렬화는 토큰을 크게 쓴다. 값어치 있는 요청에만 쓴다 | 단순 요청은 하위 에이전트 없이 처리한다. 사용자에게 에이전트 수를 알린다 | [1] |
| P4 | 하위 에이전트 지시에 목표 · 출력 형식 · 쓸 도구와 출처 · 범위 경계를 넣는다 | 지시 템플릿에 네 칸을 필수로 둔다. 경계에는 다른 에이전트가 맡은 출처 · 기간 · 하위 주제를 적어 중복을 막는다 | [1] |
| P5 | 짧고 넓은 질의로 시작해 좁힌다. 관점을 달리해 묻는다 | 첫 호출은 넓은 질의. 하위 주제 분할은 관점(이론 · 실무 · 표준) 기준으로 한다 | [1] [3] |
| P6 | 병합 · 검증은 중앙에서 한다 | 하위 에이전트는 후보 목록만 돌려준다. 병합 · 중복 제거는 조정자가, 판정은 검증 에이전트가 한다 | [1] [2] |

| 출처 | 내용 | 확인 |
|---|---|---|
| Anthropic, "How we built our multi-agent research system" (2025-06-13) [1] | Opus 4 리드 + Sonnet 4 하위 에이전트 구성이 단일 Opus 4 보다 내부 리서치 평가에서 90.2% 높았다 | 원문 |
| | BrowseComp 성능 분산의 95% 를 세 요인이 설명했다. 토큰 사용량 하나가 80% 를 설명했고 나머지는 도구 호출 수 · 모델 선택이다 | 원문 |
| | 에이전트는 채팅의 약 4배, 멀티 에이전트는 약 15배 토큰을 쓴다. "task where the value of the task is high enough to pay for the increased performance" 에만 맞는다 | 원문 |
| | 프롬프트에 넣은 규칙: 단순 사실 찾기 1개 · 호출 3~10회, 직접 비교 2~4개 · 각 10~15회, 복잡한 조사 10개 넘게 · 책임을 나눠서 | 원문 |
| | 초기 버전은 단순 질의에 하위 에이전트 50개를 띄웠다. 그래서 위 규칙을 프롬프트에 넣었다 | 원문 |
| | 하위 에이전트 지시에는 목표 · 출력 형식 · 도구와 출처 안내 · 명확한 경계가 있어야 한다. 모호하면 한 에이전트는 2021년 칩 부족을, 두 에이전트는 똑같이 2025년 공급망을 조사했다 | 원문 |
| | 리드는 하위 에이전트 3~5개를 동시에 띄우고, 하위 에이전트는 도구 3개 이상을 동시에 부른다. 복잡한 질의의 조사 시간이 최대 90% 줄었다 | 원문 |
| | "start with short, broad queries, evaluate what's available, then progressively narrow focus" | 원문 |
| | 모든 에이전트가 같은 컨텍스트를 공유해야 하는 영역, 대부분의 코딩 작업은 맞지 않는다 | 원문 |
| | 리드가 하위 에이전트 묶음을 동기로 기다려 하나가 늦으면 전체가 막힌다 | 원문 |
| | 하위 에이전트가 결과를 외부에 저장하고 가벼운 참조만 넘기면 "game of telephone" 손실과 토큰이 준다 | 원문 |
| | 조사가 끝나면 CitationAgent 가 주장마다 출처 위치를 붙인다 | 원문 |
| Kim et al., "Towards a Science of Scaling Agent Systems" (arXiv:2512.08296, v3 2026-04) [2] | 260 구성 · 벤치마크 6 · 아키텍처 5 · 모델 계열 3 을 통제 비교했다. 단일 대비 성능이 쪼갤 수 있는 금융 추론 +80.8% 에서 순차 계획 −70.0% 까지 갈렸다 | 원문 |
| | 단일 에이전트가 이미 강하면 조정의 이득이 줄고, 도구를 많이 쓰는 작업은 멀티 에이전트 부담이 크고, 중앙 검증이 없는 구조는 오류를 더 퍼뜨린다 | 원문 |
| | 독립 에이전트는 오류를 17.2배, 중앙 조정은 4.4배로 증폭했다. 단일 기준 성능 약 45% 를 넘으면 조정 이득이 줄거나 음수다 | 미확인 (v1 요약에서만 봄) |
| Shao et al., STORM (NAACL 2024, arXiv:2402.14207) [3] | 사전 조사에서 서로 다른 관점을 찾고, 관점별 작성자가 전문가에게 묻는 대화를 모의한다. 기준선 대비 조직성 +25%p, 폭 +10% | 원문 |
| | 편집자 피드백으로 "source bias transfer" 와 무관한 사실의 과잉 연결을 새 과제로 들었다 | 원문 |
| Huang et al., "Deep Research Agents: A Systematic Examination And Roadmap" (arXiv:2506.18096) [4] | 정보 획득을 API 검색 · 브라우저 탐색으로 나누고, 정적 · 동적 워크플로와 단일 · 멀티 에이전트 구성으로 분류한다. 순차 실행 비효율을 한계로 든다 | 원문 |

## 2. 인용 날조 · 참고문헌 환각

| 번호 | 원칙 | 이 플러그인에서 | 근거 |
|---|---|---|---|
| P7 | 모델이 기억으로 쓴 서지는 날조로 본다 | 하위 에이전트는 이번 검색 도구 결과에 나온 항목만 후보로 낸다. 결과 없이 쓴 서지는 버린다 | [6] [7] [8] |
| P8 | 실재하는 문헌도 메타데이터가 자주 틀린다 | 검증 에이전트는 존재뿐 아니라 제목 · 저자 · 연도를 레지스트리 메타데이터와 대조한다 | [6] [7] |
| P9 | 식별자 실재 확인은 기계로 강제한다 | 훅이 문서에 새로 쓰는 DOI · arXiv ID 를 레지스트리에 조회해 없으면 막는다 | [10] [11] [12] |
| P10 | 인용 수를 늘리면 날조도 는다 | 인용 수를 목표로 두지 않는다. 출력은 판정을 통과한 항목만 | [10] |
| P11 | 사람 심사도 날조 인용을 놓친다 | 학회 채택 · 프리프린트 게시를 실재 증거로 쓰지 않는다. 식별자 조회를 따로 한다 | [11] [12] |

| 출처 | 내용 | 확인 |
|---|---|---|
| Walters & Wilder, Scientific Reports (2023) [6] | 42개 주제 문헌 리뷰 84편의 인용 636개. 날조 비율 GPT-3.5 55%, GPT-4 18%. 실재 인용 중 실질 오류 GPT-3.5 43%, GPT-4 24% | 원문 |
| Bhattacharyya et al., Cureus (2023) [7] | ChatGPT-3.5 의학 글 30편의 참고문헌 115개. 날조 47%, 실재하나 부정확 46%, 정확 7%. 틀린 PMID 가 글의 93% 에 있었다 | 원문 |
| Chelli et al., JMIR (2024) [8] | 체계적 리뷰 재현 과제. 환각 비율 GPT-3.5 39.6%, GPT-4 28.6%, Bard 91.4%. 정밀도 9.4% · 13.4% · 0% | 원문 |
| Agrawal et al. (arXiv:2305.18248) [9] | 같은 참고문헌의 저자를 여러 번 물으면 날조 문헌은 답이 흔들리고 실재 문헌은 대체로 맞는다 | 원문 |
| Rao, Wong, Callison-Burch (arXiv:2604.03173, 2026-04) [10] | 모델 · 에이전트 10종의 인용 URL 중 3~13% 는 Wayback 기록도 없는 날조, 5~18% 는 열리지 않는다. deep research 에이전트는 질의당 인용이 더 많고 날조율도 더 높다 | 원문 |
| | URL 확인 도구(urlhealth)를 준 자기 수정으로 열리지 않는 인용이 6~79배 줄어 1% 미만이 됐다. 효과는 모델의 도구 사용 능력에 달렸다 | 원문 |
| Zhao et al., "LLM hallucinations in the wild" (arXiv:2605.07723, 2026-05) [11] | arXiv · bioRxiv · SSRN · PMC 논문 250만 편의 참고문헌 1.11억 개 감사. 2025년에만 날조 인용이 보수적으로 146,932개. 게시 검수 · 저널 출판은 일부만 걸렀다 | 원문 |
| GPTZero, "GPTZero finds 100 new hallucinations in NeurIPS 2025 accepted papers" (2026-01-21) [12] | 채택 논문 5,290편 중 4,841편을 스캔해 확인된 날조 인용 100개 이상. 본문은 51편, 표는 53편이라 적는다 | 원문 |
| | 유형: 실재 출처의 제목 · 저자 조합, 저자 · 제목 · DOI · 게재처 날조, `John Doe and Jane Smith` 같은 자리표시 저자, `2305.XXXX` 같은 미완성 arXiv ID | 원문 |
| | ICLR 2026 투고에서 날조 인용 50개 이상. 각각 심사자 3~5명이 놓쳤다 | 원문 |
| | ICLR 표본 300편 중 도구가 90편을 표시했고 사람 확인 뒤 50편이 남았다 | 2차 |

## 3. 체계적 문헌 검색

| 번호 | 원칙 | 이 플러그인에서 | 근거 |
|---|---|---|---|
| P12 | 검색을 재현할 수 있게 기록한다 | 결과에 출처(DB · 사이트) · 검색어 · 검색일 · 필터 · 건수(찾음 → 병합 → 통과)를 남긴다 | [13] [14] |
| P13 | 출처를 둘 이상 쓴다 | 논문은 학술 색인 둘 이상을 쓴다. 한 검색 엔진 결과만으로 끝내지 않는다 | [15] |
| P14 | 개념마다 동의어 · 약어 · 표기 변형을 OR 로, 개념끼리 AND 로 묶는다. NOT 은 피한다 | 하위 에이전트 지시에 개념별 동의어 목록을 넣는다 | [15] [18] |
| P15 | 서베이 · 체계적 리뷰부터 찾고 그 참고문헌을 본다 | 논문 에이전트의 첫 질의는 survey · review · systematic review 를 붙인다 | [15] |
| P16 | 스노볼링(참고문헌 · 피인용)을 검색과 같이 쓴다 | 핵심 문헌 몇 편을 시작 집합으로 앞뒤 인용을 한 바퀴 이상 따라간다. 순차 작업이라 한 에이전트가 한다 (P2) | [16] [17] |
| P17 | 멈춤 기준을 정한다 | 새 개념이 더 나오지 않거나(포화) 상위 N 건까지(노력 상한) 본다. N 은 이 플러그인이 정한다 | [29] |

| 출처 | 내용 | 확인 |
|---|---|---|
| Page et al., PRISMA 2020 (BMJ, 2021) [13] | 27개 항목 체크리스트와 흐름도. 2009 판을 대체한다 | 원문 |
| Rethlefsen et al., PRISMA-S (Systematic Reviews, 2021) [14] | 문헌 검색 보고 16개 항목. 검색의 각 요소가 재현 가능하게 보고됐는지 확인하는 용도 | 원문 |
| Lefebvre et al., Cochrane Handbook v6.5.1 4장 (2025-03) [15] | "Searching two or more databases lowers the risk of missing eligible studies." MEDLINE 하나로는 충분하지 않다 | 원문 |
| | 개념마다 넓은 검색어를 OR 로 묶고 개념끼리 AND 로 묶는다. 자유어와 주제어(MeSH · Emtree)를 같이 쓴다. NOT 은 관련 기록을 지울 수 있어 피한다 | 원문 |
| | 포함 연구와 관련 체계적 리뷰의 참고문헌을 확인한다. 핵심 문헌의 인용 검색을 보조로 쓴다 | 원문 |
| | 보고서 · 학위논문 · 학회 초록 같은 회색 문헌을 검색한다 | 원문 |
| Greenhalgh & Peacock (BMJ, 2005) [17] | 체계적 리뷰 1차 출처 495개 중 사전 프로토콜(DB · 수작업) 검색으로 찾은 것은 30%, 스노볼링 51%, 개인 지식 · 연락 24% | 원문 |
| Wohlin (EASE 2014) [16] | 스노볼링 지침과 소프트웨어공학 문헌 리뷰 재현. 첫 검색 전략으로 DB 검색의 대안이 될 수 있다 | 2차 (초록 요약) |
| Wang, Yang, Wei, Query2doc (EMNLP 2023, arXiv:2303.07678) [18] | LLM 이 만든 의사 문서로 질의를 확장하면 BM25 성능이 3~15% 오른다 | 원문 |

## 4. 출처 신뢰도

| 번호 | 원칙 | 이 플러그인에서 | 근거 |
|---|---|---|---|
| P18 | 프리프린트는 쓰되 표시하고, 출판본이 있으면 출판본을 인용한다 | 판정에 `심사 전` · `심사 후` 를 단다. arXiv 항목은 DOI 로 출판본을 찾아 있으면 바꾼다 | [19] [20] [21] |
| P19 | 철회 · 정정 여부를 인용 전에 확인한다 | 검증 에이전트가 Crossref 메타데이터의 철회 · 정정 기록을 본다. 철회면 제외하고 이유를 적는다 | [15] [22] [23] [24] [25] |
| P20 | 약탈적 저널 신호를 본다 | 게재처가 거짓 · 오도 정보, 편집 관행 이탈, 불투명, 공격적 투고 권유를 보이면 `의심` 으로 표시한다 | [26] [27] |
| P21 | 회색 문헌(기업 기술 블로그 · 보고서)은 체크리스트로 평가한다 | 기업 사례 에이전트는 작성 주체 · 방법 · 범위 · 이해관계 · 날짜를 함께 낸다. 자사 제품 홍보 글은 이해관계 있음으로 표시한다 | [28] [29] |
| P22 | 검색 순위보다 1차 출처를 앞세운다 | 지시에 "SEO 집적 사이트보다 원 저자 · 원 기관 문서" 를 넣는다 | [1] |

| 출처 | 내용 | 확인 |
|---|---|---|
| Klein et al., Int J Digit Libr (2018, arXiv:1803.09701 확장판) [19] | arXiv · bioRxiv 프리프린트와 출판본의 본문이 대체로 거의 달라지지 않았다 | 원문 |
| Brierley et al., PLOS Biology (2022) [20] | bioRxiv · medRxiv 프리프린트 → 출판본에서 초록 결론이 바뀐 비율은 비 COVID 7.2%, COVID 17.2%. 대부분 결론을 질적으로 바꾸지 않았다 | 원문 |
| Carneiro et al., Research Integrity and Peer Review (2020) [21] | 심사 논문의 보고 품질이 프리프린트보다 평균 5.0% (독립 표본) · 4.7% (짝 비교) 높았다. 차이는 작다 | 원문 |
| Hsiao & Schneider, Quantitative Science Studies (2021) [23] | PubMed 철회 논문 7,813편. 철회 뒤 인용 문맥 13,252개 중 철회를 언급한 것은 722개(5.4%) | 원문 |
| Bar-Ilan & Halevi, Scientometrics (2017) [22] | 2014년 철회 논문의 철회 뒤 인용 238건 대부분이 긍정 인용이었다. 데이터 날조로 철회된 논문도 그랬다 | 원문 |
| Cochrane Handbook 4.4.6 [15] | 포함 연구의 철회 공지 · 정오표를 확인한다. 갱신 때는 이미 포함한 연구가 그 사이 정정 · 철회됐는지 다시 찾는다 | 원문 |
| Crossref, "News: Crossref and Retraction Watch" (2023-09-12) [24] | Crossref 가 Retraction Watch DB(약 4.3만 건)를 인수해 공개했다 | 원문 |
| Crossref, "Retraction Watch retractions now in the Crossref API" (2025-01-29) [25] | 철회 정보가 REST API 에 들어간다. `source` 는 `publisher` 또는 `retraction-watch` | 원문 |
| Crossref REST API `works/10.1016/S0140-6736(97)11096-0` | 철회된 논문 레코드에 `updated-by[]` 가 있고 `type: "retraction"` · `source: "retraction-watch"` 로 나온다 | 실측 |
| Grudniewicz et al., Nature (2019) [26] | 10개국 참여자 합의 정의: 학문보다 자기 이익을 앞세우고, 거짓 · 오도 정보, 모범 편집 관행 이탈, 투명성 부족, 공격적 · 무차별 투고 권유가 특징이다 | 2차 (요약 · 재게시본) |
| Shen & Björk, BMC Medicine (2015) [27] | 약탈적 학술지 게재 논문이 2010년 5.3만 편에서 2014년 약 42만 편(활동 학술지 약 8,000개)으로 늘었다 | 원문 |
| Tyndall, AACODS checklist (Flinders University) [28] | Authority · Accuracy · Coverage · Objectivity · Date · Significance 여섯 기준. 날짜가 쉽게 보이지 않으면 "strong concern" | 원문 |
| Garousi, Felderer, Mäntylä, IST (2018, arXiv:1707.02553) [29] | 회색 문헌 품질 기준: 작성 주체 권위 · 방법 · 객관성 · 날짜 · 관련 출처와의 위치 · 새로움 · 영향 · 게재처 유형 | 원문 |
| | 객관성 항목에 이해관계를 묻는다. 예: 특정 도구 업체 직원이 쓴 도구 비교 | 원문 |
| | 게재처 등급: 1단(책 · 학위논문 · 정부 보고서 · 백서) 1점, 2단(연차 보고서 · 뉴스 · 발표 · Q&A · 위키) 0.5점, 3단(블로그 · 이메일 · 트윗) 0점 | 원문 |
| | 회색 문헌 검색 멈춤 기준 셋: 이론적 포화, 노력 상한(상위 N 건), 증거 소진. 예시 리뷰는 상위 100건까지 봤다 | 원문 |
| Anthropic [1] | 사람 평가자가 에이전트가 권위 있는 출처보다 SEO 최적화 콘텐츠 팜을 고르는 것을 잡았다. 그래서 출처 품질 휴리스틱을 프롬프트에 넣었다 | 원문 |

## 5. 생성 결과 검증

[`document-slop-methods.md`](../../common-document-slop-review/references/document-slop-methods.md) 4절과 겹치는 출처(FActScore · SAFE · CoVe · Huang)는 이 플러그인에 쓰는 부분만 적는다.

| 번호 | 원칙 | 이 플러그인에서 | 근거 |
|---|---|---|---|
| P23 | 검증은 초안을 보지 않는 별도 컨텍스트에서 한다 | 검증 에이전트는 후보 목록(식별자 · 제목 · 저자 · 연도 · 뒷받침할 주장)만 받는다. 검색 대화는 넘기지 않는다 | [30] [33] |
| P24 | 외부 근거 없이 스스로 고치게 하지 않는다 | 판정은 레지스트리 응답 · 원문 열람 결과로만 한다. 모델의 확신은 판정 근거가 아니다 | [9] [10] [33] |
| P25 | 주장을 원자 단위로 쪼개 하나씩 대조한다 | 문헌 하나가 뒷받침한다는 주장을 각각 따로 판정한다 | [31] [32] |
| P26 | 인용이 실재해도 주장을 뒷받침하는지 따로 본다 | 판정을 `존재` 와 `지지` 두 칸으로 낸다. 초록 · 본문에서 해당 문장을 찾지 못하면 `지지 미확인` | [5] [34] [35] |

| 출처 | 내용 | 확인 |
|---|---|---|
| Dhuliawala et al., CoVe (ACL Findings 2024) [30] | 초안 → 검증 질문 계획 → 질문에 독립적으로 답함 → 최종 답. 다른 답에 치우치지 않게 따로 답하는 것이 핵심 | 원문 |
| Huang et al. (ICLR 2024) [33] | 외부 피드백 없는 자기 수정은 추론 성능을 못 올리고 때로 떨어뜨린다 | 원문 |
| Min et al., FActScore (EMNLP 2023) [31] | 원자 사실로 쪼개 신뢰 출처가 뒷받침하는 비율을 잰다. ChatGPT 전기 58% | 원문 |
| Wei et al., SAFE (NeurIPS 2024) [32] | 사실마다 검색해 판정한다. 사실 약 1.6만 개에서 사람과 72% 일치, 불일치 100건 중 76% 는 SAFE 가 맞았고 20배 넘게 싸다 | 원문 |
| Liu, Zhang, Liang (Findings of EMNLP 2023) [35] | 생성형 검색 엔진 4종. 인용이 완전히 뒷받침하는 문장 51.5%, 문장을 뒷받침하는 인용 74.5% | 원문 |
| Gao et al., ALCE (EMNLP 2023) [34] | ELI5 에서 최고 모델도 50% 는 인용 뒷받침이 완전하지 않았다 | 원문 |
| Li et al., ReportBench (arXiv:2508.15804) [5] | 인용 문헌의 품질 · 관련성과 문장의 충실성을 따로 평가한다. 인용 내용을 원문과 대조하고 인용 없는 주장은 웹으로 확인한다 | 원문 |

## 6. 식별자 확인 (훅)

| 번호 | 원칙 | 이 플러그인에서 | 근거 |
|---|---|---|---|
| P27 | DOI 는 DOI 레지스트리, arXiv ID 는 arXiv 에 직접 묻는다 | 훅이 새로 쓰인 식별자만 뽑아 조회한다. 없으면 차단, 네트워크 실패면 차단하지 않고 알린다 (이 플러그인의 선택) | 아래 실측 |
| P28 | arXiv 는 3초에 1회 · 연결 1개로 묻는다 | 훅은 arXiv 조회를 순차로 하고 사이에 3초를 둔다. 429 면 재시도 뒤 OpenAlex 로 대체 조회한다 | [36] |

| 확인한 것 | 결과 | 확인 |
|---|---|---|
| `doi.org/api/handles/<DOI>` 에 실재 DOI | HTTP 200 | 실측 |
| 같은 경로에 실재 DOI [6] 의 끝 번호를 바꾼 없는 DOI | HTTP 404, 본문 `"responseCode":100` | 실측 |
| `export.arxiv.org/abs/<ID>` 에 실재 ID | HTTP 200 | 실측 |
| 같은 경로에 월이 13 인 없는 ID | HTTP 404 | 실측 |
| `export.arxiv.org/api/query` 를 3초 간격으로 4건 호출 | 3건이 빈 응답이었다. 같은 ID 의 `abs` 조회는 3초 간격 12건 모두 200 | 실측 |
| arXiv, "Terms of Use for arXiv APIs" [36] | "make no more than one request every three seconds, and limit requests to a single connection at a time." | 원문 |

## 7. 참고문헌

확인 방법: `DOI` 는 doi.org 핸들 API 200 과 OpenAlex 메타데이터(제목 · 저자 · 연도 · 게재처) 대조, `arXiv` 는 export.arxiv.org abs 200 과 페이지 메타데이터 대조, `열람` 은 웹 원문을 열어 확인함.

| 번호 | 저자 | 연도 | 제목 | 게재처 | 식별자 | 확인 방법 |
|---|---|---|---|---|---|---|
| 1 | Hadfield, Zhang, Lien, Scholz, Fox, Ford | 2025 | How we built our multi-agent research system | Anthropic Engineering 블로그 (2025-06-13) | - | 열람 |
| 2 | Kim, Gu, Park, … Liu | 2025 | Towards a Science of Scaling Agent Systems | arXiv (v3 2026-04-08) | arXiv:2512.08296 | arXiv |
| 3 | Shao, Jiang, Kanell, Xu, Khattab, Lam | 2024 | Assisting in Writing Wikipedia-like Articles From Scratch with Large Language Models | NAACL 2024 | arXiv:2402.14207 | arXiv |
| 4 | Huang, Chen, Zhang, … Wang | 2025 | Deep Research Agents: A Systematic Examination And Roadmap | arXiv | arXiv:2506.18096 | arXiv |
| 5 | Li, Zeng, Cheng, Ma, Jia | 2025 | ReportBench: Evaluating Deep Research Agents via Academic Survey Tasks | arXiv | arXiv:2508.15804 | arXiv |
| 6 | Walters, Wilder | 2023 | Fabrication and errors in the bibliographic citations generated by ChatGPT | Scientific Reports | 10.1038/s41598-023-41032-5 | DOI |
| 7 | Bhattacharyya, Miller, Bhattacharyya, Miller | 2023 | High Rates of Fabricated and Inaccurate References in ChatGPT-Generated Medical Content | Cureus | 10.7759/cureus.39238 | DOI |
| 8 | Chelli, Descamps, Lavoué, … Ruetsch-Chelli | 2024 | Hallucination Rates and Reference Accuracy of ChatGPT and Bard for Systematic Reviews: Comparative Analysis | J Med Internet Res | 10.2196/53164 | DOI |
| 9 | Agrawal, Suzgun, Mackey, Kalai | 2023 | Do Language Models Know When They're Hallucinating References? | arXiv (v3 2024-03) | arXiv:2305.18248 | arXiv |
| 10 | Rao, Wong, Callison-Burch | 2026 | Detecting and Correcting Reference Hallucinations in Commercial LLMs and Deep Research Agents | arXiv | arXiv:2604.03173 | arXiv |
| 11 | Zhao, Wang, Stuart, De Vaan, Ginsparg, Yin | 2026 | LLM hallucinations in the wild: Large-scale evidence from non-existent citations | arXiv | arXiv:2605.07723 | arXiv |
| 12 | Shmatko (GPTZero) | 2026 | GPTZero finds 100 new hallucinations in NeurIPS 2025 accepted papers | GPTZero 블로그 (2026-01-21) | - | 열람 |
| 13 | Page, McKenzie, Bossuyt, … | 2021 | The PRISMA 2020 statement: an updated guideline for reporting systematic reviews | BMJ | 10.1136/bmj.n71 | DOI |
| 14 | Rethlefsen, Kirtley, Waffenschmidt, Ayala, Moher, Page | 2021 | PRISMA-S: an extension to the PRISMA Statement for Reporting Literature Searches in Systematic Reviews | Systematic Reviews | 10.1186/s13643-020-01542-z | DOI |
| 15 | Lefebvre, Glanville, Briscoe, … Wieland | 2025 | Chapter 4: Searching for and selecting studies | Cochrane Handbook for Systematic Reviews of Interventions v6.5.1 (2025-03) | - | 열람 |
| 16 | Wohlin | 2014 | Guidelines for snowballing in systematic literature studies and a replication in software engineering | EASE 2014 | 10.1145/2601248.2601268 | DOI (본문 미열람) |
| 17 | Greenhalgh, Peacock | 2005 | Effectiveness and efficiency of search methods in systematic reviews of complex evidence: audit of primary sources | BMJ | 10.1136/bmj.38636.593461.68 | DOI |
| 18 | Wang, Yang, Wei | 2023 | Query2doc: Query Expansion with Large Language Models | EMNLP 2023 | arXiv:2303.07678 | arXiv |
| 19 | Klein, Broadwell, Farb, Grappone | 2018 | Comparing published scientific journal articles to their pre-print versions | Int J Digit Libr | 10.1007/s00799-018-0234-1 · arXiv:1803.09701 | DOI · arXiv |
| 20 | Brierley, Nanni, Polka, Dey, Pálfy, Fraser, … | 2022 | Tracking changes between preprint posting and journal publication during a pandemic | PLOS Biology | 10.1371/journal.pbio.3001285 | DOI |
| 21 | Carneiro, Queiroz, Moulin, … | 2020 | Comparing quality of reporting between preprints and peer-reviewed articles in the biomedical literature | Research Integrity and Peer Review | 10.1186/s41073-020-00101-3 | DOI |
| 22 | Bar-Ilan, Halevi | 2017 | Post retraction citations in context: a case study | Scientometrics | 10.1007/s11192-017-2242-0 | DOI |
| 23 | Hsiao, Schneider | 2021 | Continued use of retracted papers: Temporal trends in citations and (lack of) awareness of retractions shown in citation contexts in biomedicine | Quantitative Science Studies | 10.1162/qss_a_00155 | DOI |
| 24 | Hendricks, Lammey, Ofiesh, Bilder, Pentz | 2023 | News: Crossref and Retraction Watch | Crossref 블로그 (2023-09-12) | - | 열람 |
| 25 | Rittman | 2025 | Retraction Watch retractions now in the Crossref API | Crossref 블로그 (2025-01-29) | - | 열람 |
| 26 | Grudniewicz, Moher, Cobey, … | 2019 | Predatory journals: no definition, no defence | Nature | 10.1038/d41586-019-03759-y | DOI (본문은 2차) |
| 27 | Shen, Björk | 2015 | 'Predatory' open access: a longitudinal study of article volumes and market characteristics | BMC Medicine | 10.1186/s12916-015-0469-2 | DOI |
| 28 | Tyndall | 2010 | AACODS Checklist | Flinders University | - | 열람 (연도는 2차, PDF 메타데이터는 2011) |
| 29 | Garousi, Felderer, Mäntylä | 2018 | Guidelines for including grey literature and conducting multivocal literature reviews in software engineering | Information and Software Technology | 10.1016/j.infsof.2018.09.006 · arXiv:1707.02553 | DOI · arXiv · 본문 열람 |
| 30 | Dhuliawala, Komeili, Xu, Raileanu, … | 2024 | Chain-of-Verification Reduces Hallucination in Large Language Models | Findings of ACL 2024 | 10.18653/v1/2024.findings-acl.212 · arXiv:2309.11495 | DOI · arXiv |
| 31 | Min, Krishna, Lyu, Lewis, … | 2023 | FActScore: Fine-grained Atomic Evaluation of Factual Precision in Long Form Text Generation | EMNLP 2023 | arXiv:2305.14251 | arXiv |
| 32 | Wei, Yang, Song, Lu, … | 2024 | Long-form factuality in large language models | NeurIPS 2024 | arXiv:2403.18802 | arXiv |
| 33 | Huang, Chen, Mishra, Zheng, … | 2024 | Large Language Models Cannot Self-Correct Reasoning Yet | ICLR 2024 | arXiv:2310.01798 | arXiv |
| 34 | Gao, Yen, Yu, Chen | 2023 | Enabling Large Language Models to Generate Text with Citations | EMNLP 2023 | arXiv:2305.14627 | arXiv |
| 35 | Liu, Zhang, Liang | 2023 | Evaluating Verifiability in Generative Search Engines | Findings of EMNLP 2023 | arXiv:2304.09848 | arXiv |
| 36 | arXiv | - | Terms of Use for arXiv APIs | arXiv 도움말 | - | 열람 |
