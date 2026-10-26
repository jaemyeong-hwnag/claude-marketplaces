# company-blog-searcher 출처 카탈로그

기준일 2026-10. 기업 기술 블로그 · 아키텍처 사례 · 산업계 논문 · 기술 선택 동향에서 "다른 회사는 이걸 어떻게 했나" 를 찾는다.

## 언제 쓰는가

- 띄운다: 특정 기술을 실제 서비스에 쓴 회사 사례, 규모를 키우며 구조를 바꾼 이야기, 기술 선택 근거 · 도입 후기, 어떤 기술을 어느 회사가 쓰는지.
- 띄운다: 구글 · 메타 같은 회사가 낸 시스템 논문(Spanner · Borg 류)이나 VLDB · SIGMOD industry track 논문.
- 띄우지 않는다: 발표 영상 · 슬라이드(`conference-talk-searcher`), 장애 사후 분석(`postmortem-searcher`), 공식 문서 · 표준(`official-document-searcher`), 코드 사용례(`code-usage-searcher`), 학술 논문 일반(`academic-index-searcher`).

## 출처

Medium 에 올린 블로그(표에 Medium 으로 적은 것)는 WebFetch 가 403 으로 막힌다. 목록과 본문 요약은 RSS 피드 `medium.com/feed/<게시판>` (사용자 도메인이면 `<도메인>/feed`)를 연다.

### 해외 기업 블로그

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Netflix TechBlog | `netflixtechblog.com` | 스트리밍 · 데이터 플랫폼 · 카오스 엔지니어링. Medium | 무료 | WebSearch `site:netflixtechblog.com 검색어`, 목록은 `netflixtechblog.com/feed` |
| Uber Engineering | `uber.com/blog/engineering` | 대규모 마이크로서비스 · 데이터 · ML 플랫폼. 옛 글은 `eng.uber.com` | 무료 | WebSearch `site:uber.com/blog 검색어` (봇 요청은 406 이 난다) |
| Airbnb Tech Blog | `airbnb.tech` · `medium.com/airbnb-engineering` | 검색 · 결제 · 데이터(Airflow 탄생 글). 두 곳 모두 2026-10 에 새 글이 있다 | 무료 | WebSearch `site:airbnb.tech 검색어` 와 `site:medium.com/airbnb-engineering 검색어` |
| Engineering at Meta | `engineering.fb.com` | 인프라 · 데이터센터 · 프로덕션 엔지니어링 | 무료 | WebSearch `site:engineering.fb.com 검색어` |
| Google Research Blog | `research.google/blog` | 연구 결과 소개. 옛 `ai.googleblog.com` 을 이어받았다 | 무료 | WebSearch `site:research.google/blog 검색어` |
| AWS Architecture Blog | `aws.amazon.com/blogs/architecture` | AWS 위 고객 아키텍처 · 참조 설계 | 무료 | WebSearch `site:aws.amazon.com/blogs/architecture 검색어` |
| All Things Distributed | `allthingsdistributed.com` | Amazon CTO 의 분산 시스템 글 | 무료 | WebSearch `site:allthingsdistributed.com 검색어` |
| Cloudflare Blog | `blog.cloudflare.com` | 네트워크 · 엣지 · 프로토콜 · 장애 분석 | 무료 | WebSearch `site:blog.cloudflare.com 검색어`, 태그 `blog.cloudflare.com/tag/<태그>` |
| Stripe 개발자 블로그 | `stripe.dev/blog` | 결제 시스템 · API 설계. `stripe.com/blog/engineering` 이 이리로 넘어간다 | 무료 | WebSearch `site:stripe.dev/blog 검색어` |
| Discord Blog | `discord.com/blog` | 메시지 저장소(Cassandra → ScyllaDB) · Elixir · Rust. 엔지니어링 외 글이 섞인다 | 무료 | WebSearch `site:discord.com/blog 검색어 engineering` |
| Shopify Engineering | `shopify.engineering` | 모놀리스 모듈화 · Rails · 대규모 세일 트래픽 | 무료 | WebSearch `site:shopify.engineering 검색어` |
| LinkedIn Engineering | `linkedin.com/blog/engineering` | Kafka 탄생 · 데이터 인프라. `engineering.linkedin.com` 이 이리로 넘어간다 | 무료 | WebSearch `site:linkedin.com/blog/engineering 검색어` |
| Pinterest Engineering | `medium.com/pinterest-engineering` | 추천 · 광고 · 데이터. Medium | 무료 | WebSearch `site:medium.com/pinterest-engineering 검색어` |
| Spotify Engineering | `engineering.atspotify.com` | 플랫폼 엔지니어링 · Backstage · 실험 | 무료 | WebSearch `site:engineering.atspotify.com 검색어` |
| Dropbox Tech | `dropbox.tech` | 스토리지 · 동기화 엔진 · Python → Go 이전 | 무료 | WebSearch `site:dropbox.tech 검색어` |
| Slack Engineering | `slack.engineering` | 실시간 메시징 · Vitess · 배포 | 무료 | WebSearch `site:slack.engineering 검색어` |
| Figma Engineering | `figma.com/blog/engineering` | 멀티플레이어 편집 · Postgres 수평 분할 | 무료 | WebSearch `site:figma.com/blog 검색어` |
| GitHub Engineering | `github.blog/engineering` | Git 저장소 · MySQL · 코드 검색 | 무료 | WebSearch `site:github.blog/engineering 검색어` |
| Grab Tech | `engineering.grab.com` | 동남아 슈퍼앱 · 지도 · 결제 | 무료 | WebSearch `site:engineering.grab.com 검색어` |
| Datadog Engineering | `datadoghq.com/blog/engineering` | 관측성 플랫폼 내부 · 시계열 저장 | 무료 | WebSearch `site:datadoghq.com/blog/engineering 검색어` |

### 국내 기업 블로그

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| 토스 기술 블로그 | `toss.tech` | 금융 서비스 · 프런트엔드 · 서버 · 보안 | 무료 | WebSearch `site:toss.tech 검색어` |
| 우아한형제들 기술 블로그 | `techblog.woowahan.com` | 배달 주문 · 결제 · 대규모 트래픽 · 로봇 | 무료 | WebSearch `site:techblog.woowahan.com 검색어` |
| 카카오 기술 블로그 | `tech.kakao.com` | 메신저 · 인프라 · AI | 무료 | WebSearch `site:tech.kakao.com 검색어` |
| 카카오페이 기술 블로그 | `tech.kakaopay.com` | 결제 · 금융 서버 · 테스트 | 무료 | WebSearch `site:tech.kakaopay.com 검색어` |
| 카카오뱅크 기술 블로그 | `tech.kakaobank.com` | 은행 시스템 · 데이터 | 무료 | WebSearch `site:tech.kakaobank.com 검색어` |
| 카카오엔터프라이즈 Tech& | `tech.kakaoenterprise.com` | 클라우드 · AI | 무료 | WebSearch `site:tech.kakaoenterprise.com 검색어` |
| 네이버 D2 | `d2.naver.com` | 검색 · 플랫폼 · 프런트엔드. DEVIEW 자료도 있다 | 무료 | WebSearch `site:d2.naver.com 검색어`, 목록은 `d2.naver.com/d2.atom` |
| LY Corporation Tech Blog | `techblog.lycorp.co.jp/ko` | 메신저 LINE · 인프라. 한국어판 경로가 `/ko` | 무료 | WebSearch `site:techblog.lycorp.co.jp 검색어` |
| LINE Engineering (이름 변경) | `engineering.linecorp.com` | 2023-10 LY Corporation 으로 바뀌며 새 글이 멈췄다. 2023-09 이전 글만 있다 | 무료 | WebSearch `site:engineering.linecorp.com 검색어` (옛 글 찾을 때만) |
| 당근 기술 블로그 | `medium.com/daangn` | 지역 기반 서비스 · 검색 · 데이터. Medium | 무료 | WebSearch `site:medium.com/daangn 검색어`, 목록은 `medium.com/feed/daangn` |
| 쿠팡 엔지니어링 | `medium.com/coupang-engineering` | 커머스 · 물류 · 추천. Medium. 마지막 글 2024-10 | 무료 | WebSearch `site:medium.com/coupang-engineering 검색어` |
| 컬리 기술 블로그 | `helloworld.kurly.com` | 커머스 · 물류 · 데이터 | 무료 | WebSearch `site:helloworld.kurly.com 검색어` |
| 무신사 테크 블로그 | `medium.com/musinsa-tech` | 커머스 · 검색 · 랭킹. Medium | 무료 | WebSearch `site:medium.com/musinsa-tech 검색어` |
| 뱅크샐러드 기술 블로그 | `blog.banksalad.com/tech` | 마이데이터 · 서버 · 데이터 | 무료 | WebSearch `site:blog.banksalad.com 검색어` |
| 오늘의집 기술 블로그 | `bucketplace.com/culture/Tech` | 커머스 · 콘텐츠 · 추천 | 무료 | WebSearch `site:bucketplace.com 검색어` |
| 쏘카 기술 블로그 | `tech.socar.kr` | 모빌리티 · 데이터 · 인프라. `tech.socarcorp.kr` 이 이리로 넘어간다 | 무료 | WebSearch `site:tech.socar.kr 검색어` |
| 11번가 기술 블로그 | `11st-tech.github.io` | 커머스 · 서버 | 무료 | WebSearch `site:11st-tech.github.io 검색어` |
| 하이퍼커넥트 기술 블로그 | `hyperconnect.github.io` | 영상 통화 · ML · 모바일 | 무료 | WebSearch `site:hyperconnect.github.io 검색어` |
| 올리브영 기술 블로그 | `oliveyoung.tech` | 커머스 · 서버 | 무료 | WebSearch `site:oliveyoung.tech 검색어` |
| 데브시스터즈 기술 블로그 | `tech.devsisters.com` | 게임 서버 · 인프라 | 무료 | WebSearch `site:tech.devsisters.com 검색어` |
| 인프랩 기술 블로그 | `tech.inflab.com` | 교육 서비스 · 서버 | 무료 | WebSearch `site:tech.inflab.com 검색어` |
| SK DEVOCEAN | `devocean.sk.com` | SK 그룹 기술 블로그 · 커뮤니티 | 무료 | WebSearch `site:devocean.sk.com 검색어` |
| kt cloud 기술 블로그 | `tech.ktcloud.com` | 클라우드 · 인프라 | 무료 | WebSearch `site:tech.ktcloud.com 검색어` |
| AWS 기술 블로그 (한국어) | `aws.amazon.com/ko/blogs/tech` | 국내 고객사의 AWS 도입 사례 | 무료 | WebSearch `site:aws.amazon.com/ko/blogs/tech 검색어` |

### 블로그 모음

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| engineering-blogs | `github.com/kilimchoi/engineering-blogs` | 해외 회사 · 개인 기술 블로그 목록. 마지막 갱신 2024-08 | 무료 | `reference-search.sh github-repository engineering blogs`, WebFetch 로 README |
| awesome 목록 | `github.com` | 주제별 큐레이션 목록 (`awesome-scalability` 등) | 무료 | `reference-search.sh github-repository awesome <주제>` |
| Engineering.fyi | `engineering.fyi` | 해외 엔지니어링 블로그 모음 · 검색 | 무료 | WebFetch 로 검색 |
| TechBlogPosts | `techblogposts.com` | 국내 기업 기술 블로그 새 글 모음. 한국어판 `/ko` | 무료 | WebFetch `techblogposts.com/ko` |
| Velopers | `velopers.kr` | 국내 기업 기술 블로그를 RSS 로 모아 분류 · 검색 | 무료 | WebFetch 로 검색 |
| GeekNews | `news.hada.io` | 국내 개발자가 고른 기술 글 · 토론 | 무료 | WebSearch `site:news.hada.io 검색어` |
| awesome-devblog (보관됨) | `github.com/sarojaba/awesome-devblog` | 국내 기술 블로그 목록. 2021-12 에 보관(archived)됐다 | 무료 | 옛 목록을 볼 때만 WebFetch |
| Hacker News | `news.ycombinator.com` | 기업 블로그 글에 붙은 토론 · 반론 | 무료 | `reference-search.sh hackernews 검색어` |

### 아키텍처 사례

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| InfoQ | `infoq.com` | 아키텍처 기사 · QCon 발표 정리 · 인터뷰 | 무료 일부 (일부 자료는 가입) | WebSearch `site:infoq.com 검색어` |
| ByteByteGo | `blog.bytebytego.com` · `bytebytego.com` | 시스템 설계 해설 · 회사 사례 요약. 뉴스레터는 Substack | 무료 일부 (유료 구독 글이 있다) | WebSearch `site:blog.bytebytego.com 검색어` |
| High Scalability | `highscalability.com` | 회사별 아키텍처 정리 글(2007~). 갱신 간격이 크다 | 무료 | WebSearch `site:highscalability.com 검색어` |
| The Pragmatic Engineer | `newsletter.pragmaticengineer.com` · `blog.pragmaticengineer.com` | 회사 내부 엔지니어링 문화 · 사례 | 무료 일부 (유료 구독) | WebSearch `site:newsletter.pragmaticengineer.com 검색어` |
| The New Stack | `thenewstack.io` | 클라우드 네이티브 기술 기사 | 무료 | WebSearch `site:thenewstack.io 검색어` |

### 산업계 논문

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Google Research 출판물 | `research.google/pubs` | Spanner · Borg · Bigtable 같은 시스템 논문 | 무료 | WebSearch `site:research.google/pubs 검색어`, 메타데이터는 `reference-search.sh openalex 제목` |
| Meta Research 출판물 | `research.facebook.com/publications` | TAO · 데이터센터 · ML 시스템 논문 | 무료 | WebSearch `site:research.facebook.com/publications 검색어` |
| VLDB (PVLDB) | `vldb.org` | 데이터베이스. Industrial track 논문을 따로 모은다 | 무료 (PVLDB 는 오픈 액세스) | WebSearch `site:vldb.org/pvldb 검색어 industrial` |
| SIGMOD | `sigmod.org` | 데이터베이스. Industry track | 무료 일부 (ACM DL) | `reference-search.sh openalex "SIGMOD 검색어"` 또는 `reference-search.sh crossref 검색어` |
| USENIX (OSDI · NSDI · ATC) | `usenix.org` | 시스템 논문. 발표 영상 · 논문 무료 공개 | 무료 | WebSearch `site:usenix.org/conference 검색어` |

### 기술 선택 동향

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Thoughtworks Technology Radar | `thoughtworks.com/radar` | 기법 · 도구 · 플랫폼 · 언어를 Adopt · Trial · Assess · Hold 로 분류. 1년에 두 번 | 무료 | WebFetch `thoughtworks.com/radar`, 이전 판은 `thoughtworks.com/radar/archive` |
| CNCF Landscape | `landscape.cncf.io` | 클라우드 네이티브 프로젝트 · 성숙도(Sandbox · Incubating · Graduated) | 무료 | WebFetch `landscape.cncf.io` |
| Stack Overflow Developer Survey | `survey.stackoverflow.co` | 언어 · 프레임워크 · DB 사용률. 해마다 | 무료 | WebFetch `survey.stackoverflow.co/<연도>` (2025 판 확인) |
| State of JS | `stateofjs.com` | JS 프레임워크 · 도구 사용률 · 만족도 | 무료 | WebFetch `<연도>.stateofjs.com` (2025 판 확인) |
| StackShare | `stackshare.io` | 회사별 기술 스택. 2024-08 FOSSA 가 인수, 무료 공개 사이트는 유지 | 무료 | WebSearch `site:stackshare.io 회사명 stack` (봇 요청은 429 가 잦다) |
| 채용 공고 | `wanted.co.kr` · `linkedin.com/jobs` | 회사가 실제로 쓰는 스택 (자격 요건 · 우대 사항) | 무료 | WebSearch `site:wanted.co.kr 회사명 백엔드` |

## 검색 문법과 요령

| 하고 싶은 것 | 검색어 |
|---|---|
| 한 회사의 한 기술 | `site:<블로그 도메인> <기술명>` |
| 기술을 쓰는 회사 찾기 (영어) | `"<기술명>" "at scale" engineering blog` · `"how we" "<기술명>"` · `"migrating to <기술명>"` |
| 기술을 쓰는 회사 찾기 (국내) | `"<기술명>" 도입기` · `"<기술명>" 적용기` · `"<기술명>" 전환기` · `"<기술명>" 기술 블로그` |
| 그만 쓰게 된 이유 | `"moving away from <기술명>"` · `"why we left <기술명>"` · `"<기술명>" 걷어내기` |
| 규모 수치 | `"<기술명>" "requests per second"` · `"<기술명>" "petabytes"` |
| 여러 블로그 한 번에 | `site:A OR site:B <기술명>` (WebSearch 가 OR 를 무시하면 따로 부른다) |

요령:

- 회사 이름만 알고 블로그 도메인을 모르면 `<회사명> engineering blog` · `<회사명> 기술 블로그` 로 도메인부터 확인한다. 위 표에 없는 도메인은 지어내지 않는다.
- Medium 블로그는 WebFetch 대신 RSS 피드를 연다. 피드는 새 글 10건 정도만 담는다. 그 이전 글은 WebSearch 로 찾는다.
- 기업 블로그 글을 찾으면 같은 제목으로 `reference-search.sh hackernews` 를 돌려 토론 · 반론이 있는지 본다.
- 산업계 논문은 블로그 소개 글보다 원 논문을 우선한다. 원 논문은 `reference-search.sh openalex` 나 `crossref` 로 DOI 를 확인한다.
- 동향 자료(Radar · 설문)는 판(연도 · Volume)을 꼭 적는다. 판마다 분류가 바뀐다.
- 채용 공고는 게시 날짜를 같이 적는다. 내려간 공고는 근거로 쓰지 않는다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 기업 블로그 | 회사가 운영하는 블로그의 글. 글쓴이 · 작성일을 같이 적는다 |
| 산업계 논문 | 심사를 거친 학회 · 저널 논문 (OSDI · VLDB · SIGMOD 등) |
| 기술 매체 | InfoQ · ByteByteGo · The New Stack 같은 제3자 정리 글. 원 출처가 있으면 원 출처로 바꾼다 |
| 동향 자료 | Radar · 설문 · Landscape. 판 · 연도를 적는다 |
| 커뮤니티 | GeekNews · Hacker News 토론, 모음 서비스의 요약 |
| 채용 공고 | 스택 근거로만 쓴다. 게시 날짜를 적는다 |

주의:

- 작성 날짜: 3년이 넘은 글은 "작성 연도" 를 붙이고, 그 뒤 구조가 바뀌었는지 같은 블로그에서 후속 글을 찾는다.
- 회사 규모: 초당 수백만 요청을 다루는 회사의 해법은 작은 서비스에 맞지 않을 수 있다. 회사 규모 · 트래픽 수치를 결과에 같이 적는다.
- 홍보성: 채용 · 자사 제품 홍보 목적의 글이 섞인다. 클라우드 업체 블로그의 고객 사례는 그 업체 제품을 쓰는 쪽으로 쓰인다.
- 생존 편향: 성공한 도입기만 글이 된다. "그만 쓴 이유" 검색을 같이 돌린다.
- 지금도 유효한지: 이름이 바뀐 블로그(LINE → LY)나 멈춘 블로그(쿠팡 2024-10 이후 새 글 없음)의 글은 당시 기준으로 적는다.
- 수치: 블로그의 성능 수치는 측정 조건이 빠져 있는 경우가 많다. 조건이 없으면 "조건 미기재" 로 적는다.
