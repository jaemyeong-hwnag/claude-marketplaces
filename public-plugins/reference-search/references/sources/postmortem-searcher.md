# postmortem-searcher 출처 카탈로그

기준일 2026-10. 장애 · 실패 사례의 사후 분석(postmortem · RCA · incident report)을 찾는다.

## 언제 쓰는가

- 띄운다: 특정 기술 · 구성이 실제로 어떻게 망가졌는지, 비슷한 장애를 겪은 회사가 있는지, 재발 방지책 사례.
- 띄운다: 설계 검토에서 "이 방식의 실패 사례" 근거가 필요할 때, 특정 클라우드 · SaaS 의 과거 장애 이력.
- 띄우지 않는다: 지금 진행 중인 장애 확인(각 status 페이지를 직접 연다), 성공 사례 · 도입기(`company-blog-searcher`), 버그 리포트 · 이슈(`code-usage-searcher`).

## 출처

### 사후 분석 모음

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| danluu/post-mortems | `github.com/danluu/post-mortems` | 공개 사후 분석 링크 모음. 분류(설정 · 하드웨어 · 시간 · DB 등)별. 2026-08 에도 갱신 | 무료 | WebFetch README, `reference-search.sh github-code "검색어 repo:danluu/post-mortems"` |
| The VOID | `thevoid.community` | 소프트웨어 장애 보고서 모음 · 메타데이터 검색 | 무료 | WebFetch 로 검색, WebSearch `site:thevoid.community 검색어` |
| Postmortem Metadata Index | `postmortems.app` | 공개 사후 분석에 메타데이터 · 요약을 붙인 색인 | 무료 | WebFetch `postmortems.app` |
| Kubernetes Failure Stories | `k8s.af` | 쿠버네티스 운영 실패 사례 모음 | 무료 | WebFetch `k8s.af` |
| awesome-tech-postmortems | `github.com/snakescott/awesome-tech-postmortems` | 사후 분석 링크 목록. 2019-12 이후 갱신 없음 | 무료 | 옛 사례만 WebFetch |
| Google SRE 책 | `sre.google` | 사후 분석 문화 · 작성법 (`sre.google/sre-book/postmortem-culture` · `sre.google/workbook/postmortem-culture`) | 무료 | WebFetch 해당 장 |

### 회사 status 페이지와 사후 분석

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Cloudflare | `cloudflarestatus.com` · `blog.cloudflare.com/tag/post-mortem` | 장애 이력, 큰 장애는 블로그에 상세 분석 (`/tag/outage` 도 있다) | 무료 | WebFetch `blog.cloudflare.com/tag/post-mortem`, WebSearch `site:blog.cloudflare.com outage 검색어` |
| GitHub | `githubstatus.com` · `github.blog/tag/github-availability-report` | 장애 이력, 월간 가용성 보고서 | 무료 | WebFetch `github.blog/tag/github-availability-report` |
| AWS | `health.aws.amazon.com/health/status` · `aws.amazon.com/premiumsupport/technology/pes` | 서비스 상태, 큰 장애의 Post-Event Summary | 무료 | WebFetch `aws.amazon.com/premiumsupport/technology/pes` |
| Google Cloud | `status.cloud.google.com` | 장애 이력 · 사건별 분석 (`status.cloud.google.com/summary`) | 무료 | WebFetch `status.cloud.google.com/summary`, WebSearch `site:status.cloud.google.com incident 검색어` |
| Microsoft Azure | `azure.status.microsoft` | 장애 이력 · PIR(Post Incident Review) | 무료 | WebFetch `azure.status.microsoft/en-us/status/history/` |
| Atlassian | `status.atlassian.com` | Jira · Confluence 등 장애 이력. 2022-04 장기 장애 분석은 Atlassian 블로그에 있다 | 무료 | WebSearch `site:atlassian.com post-incident review` |
| Slack | `slack-status.com` | 장애 이력 · 사건별 요약. `status.slack.com` 이 이리로 넘어간다 | 무료 | WebFetch `slack-status.com` 의 사건 페이지 |
| Anthropic (Claude) | `status.claude.com` | Claude API · 앱 장애 이력. `status.anthropic.com` 이 이리로 넘어간다 | 무료 | WebFetch `status.claude.com` |
| OpenAI | `status.openai.com` | API · 앱 장애 이력 | 무료 | WebFetch `status.openai.com` |
| StatusGator | `statusgator.com` | 여러 서비스 status 페이지의 이력 모음 | 무료 일부 | WebSearch `site:statusgator.com 서비스명 outage` |

### 기술 블로그의 incident 글

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| 기업 기술 블로그 | `company-blog-searcher` 표의 도메인 | 회사가 직접 쓴 장애 분석 (예: Meta 2021-10 BGP 장애는 `engineering.fb.com`) | 무료 | WebSearch `site:<블로그 도메인> outage OR incident OR postmortem` |
| incident.io 블로그 | `incident.io/blog` | 장애 대응 실무 · 사례 해설. 장애 관리 도구 회사 | 무료 | WebSearch `site:incident.io/blog 검색어` |
| The Pragmatic Engineer | `newsletter.pragmaticengineer.com` | 큰 장애의 경위 정리 | 무료 일부 (유료 구독) | WebSearch `site:newsletter.pragmaticengineer.com outage 검색어` |
| Hacker News | `news.ycombinator.com` | 사후 분석 글에 붙은 토론 · 현업자 반론 | 무료 | `reference-search.sh hackernews "postmortem 검색어"` |

### 국내 사례

| 사례 | 공개 자료가 있는 곳 | 찾는 방법 |
|---|---|---|
| 카카오 판교 데이터센터 화재 (2022-10-15) | `kakaocorp.com` "우리의 재발 방지 계획", if(kakao) dev 2022 발표 (2022-12) | WebSearch `site:kakaocorp.com 재발 방지`, `"if kakao 2022" 장애` |
| KT 전국 유 · 무선 인터넷 장애 (2021-10-25) | 과학기술정보통신부 원인 분석 발표 (`msit.go.kr`) | WebSearch `site:msit.go.kr KT 네트워크 장애 원인` |
| 정부 행정전산망 장애 (2023-11) | 행정안전부 발표 · 언론 보도 | WebSearch `행정전산망 장애 원인 발표 2023` |
| 국가정보자원관리원 대전 화재 (2025-09-26) | 정부 발표 · 언론 보도. 최종 원인 조사 결과는 `미확인` | WebSearch `국가정보자원관리원 화재 원인 조사 결과` |
| 기업 기술 블로그의 장애 회고 | `company-blog-searcher` 의 국내 블로그 도메인 | WebSearch `site:<블로그 도메인> 장애 회고` · `장애 대응기` |

## 검색 문법과 요령

| 하고 싶은 것 | 검색어 |
|---|---|
| 영어 사후 분석 | `"<기술명>" postmortem` · `"<기술명>" "incident report"` · `"<기술명>" RCA` · `"root cause analysis" <서비스명>` |
| 큰 장애 | `"<서비스명>" outage <연도>` · `"post-incident review" <서비스명>` · `"post-event summary" <AWS 서비스명>` |
| 원인 종류로 | `postmortem "DNS"` · `postmortem "certificate expired"` · `postmortem "leap second"` · `postmortem "config push"` · `postmortem "thundering herd"` |
| 국내 | `<기술명> 장애 회고` · `<기술명> 장애 대응기` · `<기술명> 장애 원인` · `<서비스명> 장애 사후 분석` |
| 모음 안에서 | `gh search code "<키워드>" --repo danluu/post-mortems` |

요령:

- 회사 status 페이지는 짧은 요약만 남기는 경우가 많다. 큰 장애는 같은 날짜 근처에 블로그 · PES · PIR 로 긴 분석이 따로 나온다. 날짜로 다시 찾는다.
- 장애 날짜를 먼저 확정한다. 같은 서비스에 비슷한 장애가 여러 번 있다.
- 사후 분석 원문이 없고 언론 보도만 있으면 그렇게 적는다. 언론 보도의 원인 설명은 초기 추정일 수 있다.
- danluu 목록의 링크는 끊긴 것이 있다. 끊기면 WebSearch 로 제목을 다시 찾거나 웹 아카이브(`web.archive.org`)를 연다.
- 원인 종류로 찾을 때는 "그 기술을 쓰다 난 장애" 와 "그 기술 때문에 난 장애" 를 구분해 적는다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 공식 사후 분석 | 장애를 겪은 회사가 직접 낸 분석 (블로그 · PES · PIR · status 페이지) |
| 공식 요약 | status 페이지의 짧은 사건 기록. 원인 설명이 한두 줄이다 |
| 규제 기관 발표 | 정부 부처 · 감독 기관이 낸 원인 분석 |
| 제3자 분석 | 언론 · 뉴스레터 · 장애 관리 도구 회사의 해설 |
| 모음 요약 | VOID · postmortems.app · danluu 목록의 요약만 봤다. 원문 확인 전 |

주의:

- 작성 날짜: 장애 날짜와 분석 공개 날짜를 둘 다 적는다. 초기 분석은 나중에 갱신되기도 한다.
- 회사 규모: 대형 클라우드의 장애 원인(전역 설정 배포 등)은 작은 시스템에 그대로 옮겨지지 않는다.
- 홍보성: 공식 분석은 책임 범위를 좁게 쓰는 경향이 있다. 고객 영향 범위 · 시간은 status 이력과 맞춰 본다.
- 지금도 유효한지: 재발 방지책이 실제로 적용됐는지는 분석 문서만으로 알 수 없다. 이후 같은 원인의 장애가 있었는지 찾는다.
- 수사 · 소송이 걸린 국내 사례는 원인이 확정되지 않았을 수 있다. 확정 전이면 `미확인` 으로 적는다.
