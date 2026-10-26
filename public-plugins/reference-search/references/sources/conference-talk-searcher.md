# conference-talk-searcher 출처 카탈로그

기준일 2026-10. 기술 컨퍼런스 발표의 영상 · 슬라이드 · 세션 소개를 찾는다.

## 언제 쓰는가

- 띄운다: 회사가 발표한 도입 사례 · 운영 경험, 특정 기술의 발표 영상 · 슬라이드, 특정 행사 · 연도의 세션 목록.
- 띄운다: 블로그 글이 없고 발표로만 공개된 사례를 찾을 때.
- 띄우지 않는다: 기업 블로그 글(`company-blog-searcher`), 장애 사후 분석(`postmortem-searcher`), 학회 논문 자체(`academic-index-searcher`). USENIX 처럼 논문과 발표가 같이 있는 행사는 영상 · 슬라이드만 여기서 찾는다.

## 출처

### 해외 행사

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| QCon (San Francisco · London 등) | `qconsf.com` · `qconlondon.com` · `infoq.com/qcon` | 아키텍처 · 실무 사례. 발표 영상과 정리 글이 InfoQ 에 올라온다 | 무료 일부 (영상 일부는 가입 · 기간 지난 뒤 공개) | WebSearch `site:infoq.com/presentations 검색어` |
| KubeCon + CloudNativeCon | `cncf.io/kubecon-cloudnativecon-events` | 쿠버네티스 · 클라우드 네이티브. `kubecon.io` 가 이리로 넘어간다 | 무료 (영상) | YouTube `@cncf`, 일정은 `kccnceu2026.sched.com` 처럼 회차별 sched |
| AWS re:Invent | `aws.amazon.com/events/reinvent` | AWS 서비스 · 고객 사례 세션. `reinvent.awsevents.com` 이 이리로 넘어간다 | 무료 (영상) | WebFetch `aws.amazon.com/events/reinvent/on-demand`, YouTube `@AWSEventsChannel` |
| Google I/O | `io.google` | 안드로이드 · 웹 · 클라우드 · AI. 회차별 경로 `io.google/<연도>` | 무료 | YouTube `@googledevelopers` |
| SREcon (Americas · EMEA · APAC) | `usenix.org/conference/srecon` | SRE · 운영 · 장애 대응. 회차별 `usenix.org/conference/srecon26americas` | 무료 (영상 · 슬라이드) | WebSearch `site:usenix.org/conference srecon 검색어` |
| USENIX (OSDI · NSDI · ATC · FAST · LISA) | `usenix.org/conferences` | 시스템 연구 발표. 논문 · 슬라이드 · 영상 무료 공개 | 무료 | WebSearch `site:usenix.org/conference 검색어`, YouTube `@usenix` |
| Strange Loop (종료) | `thestrangeloop.com` | 언어 · 분산 시스템. 2009~2023, 2023 이 마지막 회차 | 무료 | YouTube `@StrangeLoopConf` 에 과거 영상이 남아 있다 |
| SpringOne (이름 변경) | `springone.io` | Spring 생태계. 사이트가 VMware Explore 로 넘어간다 | 무료 일부 | WebSearch `"SpringOne" 검색어 site:youtube.com` (옛 영상) |
| GopherCon | `gophercon.com` | Go 언어 | 무료 (영상) | WebSearch `"GopherCon" 검색어 site:youtube.com` |
| Devoxx | `devoxx.com` | Java · JVM · 일반 개발 | 무료 (영상) | WebSearch `"Devoxx" 검색어 site:youtube.com` |
| NDC Conferences | `ndcconferences.com` | .NET · 일반 개발 · 아키텍처 | 무료 (영상) | WebSearch `"NDC" 검색어 site:youtube.com` |
| Tech-Verse (LY Corporation) | `tech-verse.lycorp.co.jp` | LINE 계열 서비스 기술. LINE DEVELOPER DAY 는 2021 회차가 확인된 마지막이고, 이후 LY 의 Tech-Verse 가 열린다 (대체 공식 발표는 `미확인`) | 무료 | WebFetch `tech-verse.lycorp.co.jp/<연도>/ko` (한국어판 경로 `미확인`) |

### 국내 행사

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| if(kakao) | `if.kakao.com` | 카카오 계열 서비스 기술 · AI. 회차별 `if.kakao.com/<연도>` (2024 는 if(kakaoAI)2024, 2026 회차 사이트 있음) | 무료 | WebFetch 회차 페이지의 세션 목록, YouTube `@kakaotech` |
| DEVIEW (종료 · 통합) | `deview.kr` | 네이버 개발자 행사(2008~). 2023-02 회차가 마지막이고 2024 부터 DAN 에 통합됐다. 회차별 `deview.kr/<연도>` 아카이브 | 무료 | WebFetch `deview.kr/2023`, 자료는 `d2.naver.com` |
| DAN (TEAM NAVER CONFERENCE) | `dan.naver.com` | 네이버 기술 · 비즈니스. DAN 24 · DAN25 확인. 회차별 `dan.naver.com/<두 자리 연도>` | 무료 | WebFetch `dan.naver.com/25`, 영상은 네이버 클립 `clip.naver.com/@devrel_d2` (`tv.naver.com/naverd2` 가 이리로 넘어간다) |
| 우아콘 (우아한테크콘퍼런스) | `woowacon.com` | 배달의민족 서비스 기술 · 로봇 · AI. 2020 부터, 2026 회차 사이트 있음 | 무료 | WebFetch `woowacon.com`, YouTube `@woowatech` |
| SLASH (토스) | `toss.im/slash-24` | 토스 개발자 행사. 2021~2024. 2025 는 직군 통합 행사 토스 메이커스 컨퍼런스(TMC 25)로 열렸다. 2026 회차는 `미확인` | 무료 | WebFetch `toss.im/slash-<두 자리 연도>`, YouTube `@toss_tech` |
| FEConf | `feconf.kr` | 프런트엔드. 회차별 `<연도>.feconf.kr` (2025 · 2026 확인) | 무료 일부 (영상 공개 시점이 늦다) | WebFetch `2026.feconf.kr`, YouTube `@FEConf` |
| 인프콘 (INFCON) | `inflearn.com/conf` | 인프런 주최, 개발 전반. 2022~2024 확인, 2025 이후 회차는 `미확인` | 무료 일부 (다시보기 강의) | WebFetch `inflearn.com/conf/infcon-2024`, YouTube `@inflearn` |
| NHN FORWARD | `forward.nhn.com` | NHN 기술. 2022 회차까지 확인, 이후 개최 `미확인`. 사이트는 YouTube `@NHNCloud` 로 넘어간다 | 무료 | YouTube `@NHNCloud`, 기술 글은 `meetup.nhncloud.com` |
| PyCon Korea | `pycon.kr` | 파이썬. 회차별 `<연도>.pycon.kr` (2026 확인) | 무료 | WebFetch 회차 사이트의 발표 목록 |
| JSConf Korea | `jsconf.kr` | 자바스크립트. 사이트가 `2022.jsconf.kr` 로 넘어간다. 이후 회차 `미확인` | 무료 | WebFetch `2022.jsconf.kr` |

### 영상 · 슬라이드 찾는 곳

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| YouTube | `youtube.com` | 행사 공식 채널 영상 | 무료 | WebSearch `site:youtube.com "<행사명>" 검색어`, 채널 핸들은 위 표 |
| InfoQ Presentations | `infoq.com/presentations` | QCon 등 발표 영상 · 녹취록 | 무료 일부 | WebSearch `site:infoq.com/presentations 검색어` |
| Speaker Deck | `speakerdeck.com` | 발표 슬라이드. 국내 발표자도 많이 올린다 | 무료 | WebFetch `speakerdeck.com/search?q=검색어`, WebSearch `site:speakerdeck.com 검색어` |
| SlideShare | `slideshare.net` | 발표 슬라이드. Scribd 소유. 봇 요청은 확인 페이지로 막힌다 | 무료 일부 (내려받기 가입) | WebSearch `site:slideshare.net 검색어` |
| 네이버 클립 (D2) | `clip.naver.com/@devrel_d2` | DEVIEW · DAN 영상 | 무료 | WebFetch 프로필 페이지 |
| 행사 일정 (sched) | `sched.com` | 회차별 세션 목록 · 슬라이드 첨부. KubeCon 등이 쓴다 | 무료 | WebSearch `site:sched.com "<행사명>" 검색어` |

## 검색 문법과 요령

| 하고 싶은 것 | 검색어 |
|---|---|
| 회사 발표 찾기 | `"<회사명>" "<기술명>" talk` · `"<회사명>" <기술명> 발표` |
| 특정 행사 · 연도 | `"<행사명> <연도>" <기술명>` (예: `"KubeCon 2025" "multi-cluster"`) |
| 슬라이드만 | `site:speakerdeck.com <기술명>` · `<기술명> filetype:pdf <행사명>` |
| 국내 발표 | `<기술명> 우아콘` · `<기술명> if kakao` · `<기술명> DEVIEW` · `<기술명> FEConf` |
| 행사 없이 영상 | `site:youtube.com "<기술명>" "in production"` |

요령:

- 행사 사이트는 회차마다 경로가 바뀐다 (`<연도>.feconf.kr` · `if.kakao.com/<연도>` · `dan.naver.com/<두 자리 연도>`). 연도를 바꿔 WebFetch 하고, 404 면 그 회차가 없거나 사이트가 내려간 것이다.
- 세션 목록 페이지는 자바스크립트로 그려져 WebFetch 결과가 빌 때가 있다. 그때는 YouTube 재생목록이나 `site:` 검색으로 돌아간다.
- 영상에 슬라이드 링크가 없으면 발표 제목으로 Speaker Deck 을 따로 찾는다.
- 발표 내용을 블로그 글로 다시 정리한 경우가 많다. 같은 제목으로 `company-blog-searcher` 의 블로그 도메인을 찾으면 인용하기 쉬운 글이 나온다.
- 학회 발표(USENIX · OSDI)는 논문이 원본이다. 논문 메타데이터는 `reference-search.sh openalex 제목` 으로 확인한다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 발표 (행사명 연도) | 행사 공식 채널 · 아카이브에서 확인한 발표. 발표자 소속을 같이 적는다 |
| 발표 (학회) | USENIX · SREcon 처럼 심사를 거친 발표 |
| 슬라이드만 | 영상 없이 Speaker Deck · SlideShare 에서 찾았다. 행사 · 날짜를 슬라이드 안에서 확인한다 |
| 종료된 행사 | Strange Loop · DEVIEW · SLASH(2024 까지) 처럼 더 열리지 않는 행사의 발표 |

주의:

- 작성 날짜: 발표 연도를 꼭 적는다. 3년이 넘은 발표는 그 회사가 지금도 같은 구조인지 후속 발표 · 블로그를 찾는다.
- 회사 규모: 대형 서비스의 사례는 트래픽 · 조직 규모가 다르다. 발표에 나온 수치를 같이 적는다.
- 홍보성: 스폰서 세션 · 벤더 발표는 자사 제품을 쓰는 쪽으로 쓰인다. 세션 분류에 "Sponsored" 가 있으면 적는다.
- 영상 공개 시점: 행사 직후에는 영상이 없을 수 있다. 공개 안 된 발표는 "세션 소개만" 으로 적는다.
- 슬라이드만으로는 맥락이 빠진다. 슬라이드의 수치 · 그래프를 인용할 때는 원 발표를 확인했는지 적는다.
