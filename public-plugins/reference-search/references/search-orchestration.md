# 검색 절차

`paper-search` · `company-case-search` · `technology-usage-search` 세 스킬이 같이 쓰는 절차다. 조항은 [`reference-search-rules.md`](./reference-search-rules.md), 형식은 [`result-schema.md`](./result-schema.md), 근거 번호(`P…`)는 [`reference-search-methods.md`](./reference-search-methods.md).

## 1. 요청을 나눈다

| 항목 | 정하는 것 | 기본값 |
|---|---|---|
| 찾는 것 | 논문 · 연구 결과 / 기업 사례 / 공식 문서 · 표준 · 코드. 섞여 있으면 전부 | - |
| 분야 | 의학 · CS · 경제 … 분야에 따라 `discipline-database-searcher` 가 고를 DB 가 달라진다 | 질문에서 추론 |
| 기간 | `--from` 날짜 | 오늘에서 2년 전. "고전 · 원조 논문" 이면 제한 없음 |
| 언어 · 지역 | 국내 자료가 필요한가 | 질문이 한국어여도 영어 자료를 같이 찾는다. "국내 · 한국" 이 있으면 `regional-academic-database-searcher` · 국내 블로그 · 국내 행사 |
| 깊이 | 빠르게 · 보통 · 깊게 (2절) | 요청 복잡도로 정한다 |

## 2. 깊이와 에이전트 수 (`RS-19` · `P1` · `P3`)

| 깊이 | 언제 | 에이전트 | 에이전트당 도구 호출 | 스노볼링 | 검증 |
|---|---|---|---|---|---|
| 빠르게 | 사실 하나 · 논문 한두 편 · "있는지만" | 0 ~ 1개. 0개면 스킬이 스크립트를 직접 부른다 | 3 ~ 10 | 없음 | `reference-validate.sh` 만 |
| 보통 | 주제 하나의 대표 자료, 둘을 비교 | 2 ~ 4개 | 10 ~ 15 | 없음 | `reference-reviewer` |
| 깊게 | 문헌 조사 · 여러 관점 · "빠짐없이" | 5 ~ 10개 | 10 ~ 15 | 상위 3 ~ 5편 한 번 | `reference-reviewer` |

멀티 에이전트 검색은 단일 대화보다 토큰을 몇 배 쓴다 (`P3`). 깊이를 올릴 근거가 없으면 한 단계 낮게 시작하고, 결과가 모자라면 그때 넓힌다. 띄우기 전에 깊이와 에이전트 수를 사용자에게 한 줄로 알린다. 상한 10개는 이 플러그인이 정한 값이다 (출처 묶음 수).

### 사용자가 정하는 법

요청에 아래 표현이 있으면 1절 판단보다 앞선다.

| 표현 | 효과 |
|---|---|
| `빠르게` · `간단히` / `깊게` · `자세히` · `빠짐없이` | 깊이 |
| `에이전트 N개` · `N개로` | 에이전트 수 상한 N. 0 이면 에이전트 없이 스킬이 직접 찾는다 |
| `arXiv 만` · `국내만` · `블로그만` 처럼 출처 · 묶음 지정 | 그 에이전트만 띄운다 |
| `~ 빼고` | 그 에이전트 · 출처를 뺀다 |

환경 변수로 기본값을 둘 수 있다. 시작할 때 `echo "${REFERENCE_SEARCH_DEPTH:-} ${REFERENCE_SEARCH_MAX_AGENTS:-}"` 로 읽는다.

- `REFERENCE_SEARCH_DEPTH` — `quick` · `normal` · `deep`
- `REFERENCE_SEARCH_MAX_AGENTS` — 에이전트 수 상한 (검증 에이전트는 세지 않는다)

### 상한보다 맡을 묶음이 많을 때

고른 에이전트가 상한보다 많으면, 관련성이 낮은 묶음을 가까운 에이전트에 **카탈로그를 더 얹어** 맡긴다. 묶음을 버리지 않는다.

| 합칠 묶음 | 얹을 에이전트 |
|---|---|
| `preprint` · `research-trend` | `academic-index-searcher` |
| `discipline-database` · `regional-academic-database` | `academic-index-searcher` |
| `conference-talk` · `postmortem` | `company-blog-searcher` |
| `code-usage` | `official-document-searcher` |

얹을 때는 프롬프트에 추가 카탈로그 경로(`${CLAUDE_PLUGIN_ROOT}/references/sources/<묶음>-searcher.md`)와 늘어난 도구 호출 예산을 같이 넘긴다.

## 3. 에이전트를 고른다

| 찾는 것 | 기본 묶음 |
|---|---|
| 논문 · 연구 결과 | `academic-index-searcher` · `preprint-searcher` + 분야가 뚜렷하면 `discipline-database-searcher` + 국내면 `regional-academic-database-searcher` + "요즘 · 동향 · 화제" 면 `research-trend-searcher` | <!-- document-slop-ignore -->
| 기업 사례 | `company-blog-searcher` + 발표 자료가 도움이 되면 `conference-talk-searcher` + 장애 · 실패 사례면 `postmortem-searcher`. 산업계 논문이 있을 만한 주제면 `academic-index-searcher` |
| 기술 레퍼런스 | `official-document-searcher` + 실제 사용 · 알려진 문제가 필요하면 `code-usage-searcher` |

## 4. 검색어를 만든다

- 영어 핵심어 + 동의어 2 ~ 3개. 약어는 풀어 쓴 것도 같이 넣는다 (`RAG` · `retrieval-augmented generation`)
- 논문은 서베이 · 리뷰 · 메타분석 검색어를 하나 넣어 분야 지도를 먼저 잡는다
- 지역 DB 는 그 나라 말로 옮긴다
- 에이전트마다 같은 검색어를 그대로 돌리지 않는다. 출처에 맞게 고친 후보를 넘긴다

## 5. 병렬로 띄운다 (`RS-20` · `P2` · `P4`)

고른 에이전트를 **한 메시지에서 동시에** 띄운다. 출처끼리는 서로 독립이라 병렬로 나눈다. 스노볼링처럼 앞 결과에 기대는 일은 한 에이전트 안에서 순서대로 한다. 프롬프트에는 아래를 모두 넣는다.

```
주제: <한 문장>
검색어 후보: <출처에 맞게 고친 것>
기간: --from <YYYY-MM-DD>
언어 · 지역: <…>
결과 개수: <N, 기본 8>
도구 호출 예산: <2절 표>
맡는 범위: <이 에이전트가 볼 것. 다른 에이전트가 맡은 것은 보지 않는다>
멈춤 기준: <결과 개수를 채우거나, 새 검색어가 새 결과를 더 내지 않으면 멈춘다>
추가 카탈로그: <얹은 묶음이 있으면 경로>
```

## 6. 병합한다 (`RS-14`)

1. 식별자로 중복을 합친다: DOI → arXiv ID → 소문자로 바꾼 제목 + 연도
2. 프리프린트와 출판본은 한 행으로 합치고 출판본을 앞에 둔다
3. 관련성 순으로 정렬하고, 상태(심사 완료 · 프리프린트 · 기업 블로그 …)를 같이 보이게 둔다
4. 에이전트가 적은 검색어 · 실패 출처와 건수(찾음 → 병합 뒤 → 검증 통과)를 모은다 — 최종 출력 맨 위에 쓴다 (`RS-12` · `P12`)

## 7. 스노볼링 — 깊게만

병합 결과의 핵심 논문 3 ~ 5편의 DOI 로 `academic-index-searcher` 를 한 번 더 띄운다. 프롬프트에 "스노볼링: 이 DOI 들의 참고문헌과 인용한 논문 중 주제 관련 상위 N개" 를 넣는다. 결과를 6절로 다시 병합한다.

## 8. 검증한다 (`RS-18` · `P23` · `P26`)

- 빠르게: 결과 표를 임시 파일로 저장하고 `"${CLAUDE_PLUGIN_ROOT}/scripts/reference-validate.sh" <파일>` 을 돌린다
- 보통 · 깊게: `reference-reviewer` 에게 **병합한 표만** 넘긴다. 검색 과정 · 의도는 넘기지 않는다
- 판정대로 고친다 — 존재 `없음` 은 뺀다. `불일치` 는 바른 값으로 고친다. 지지 `아님` 은 요지를 고치거나 빼고, `부분` 은 요지를 원문 범위로 좁힌다. `철회` · `미확인` 은 표시하고 남긴다

## 9. 출력한다

- 대화로 낸다. 사용자가 문서를 원하면 프로젝트의 산출물 위치 규약을 따라 `.md` 로 쓰고, 규약이 없으면 위치를 묻는다
- 맨 위: 기준일 · 검색 범위(기간 · 언어 · 깊이 · 띄운 에이전트 수) · 실패하거나 빠진 출처
- 본문: 상태별 또는 주제별로 묶은 표 (`result-schema.md`)
- 끝: 요청에 대한 답. 무엇이 확인됐고 무엇이 `미확인` 인지 나눠 쓴다 (`RS-15`)
- `.md` 에 쓰는 DOI · arXiv ID 는 훅이 다시 확인한다 (`RS-01` · `RS-02`)
