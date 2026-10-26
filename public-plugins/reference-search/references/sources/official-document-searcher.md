# official-document-searcher 출처 카탈로그

기준일 2026-10. 제품 · 라이브러리의 공식 문서 · 릴리스 노트 · 마이그레이션 가이드와 표준 문서(RFC · W3C · ISO 등)를 찾는다.

## 언제 쓰는가

- 띄운다: API · 설정의 공식 동작, 특정 버전에서 바뀐 것, 지원 종료 일정, 업그레이드 절차, 표준 조항 · 정의 확인.
- 띄운다: 문서에 쓸 근거를 "공식" 으로 달아야 할 때 (RFC 번호 · W3C 권고 · NIST SP 번호).
- 띄우지 않는다: 실제 사용 코드 · 이슈 토론(`code-usage-searcher`), 회사 도입 사례(`company-blog-searcher`), 표준을 다룬 학술 논문(`academic-index-searcher`).

## 출처

### 제품 · 라이브러리 문서

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| 제품 공식 문서 | 제품마다 다르다 (예: `docs.python.org` · `docs.spring.io` · `kubernetes.io/docs` · `docs.oracle.com/en/java`) | API · 설정 · 동작 | 무료 | WebSearch `site:<문서 도메인> 검색어`, 버전 경로는 아래 요령 |
| 클라우드 문서 | `docs.aws.amazon.com` · `learn.microsoft.com` · `docs.cloud.google.com` | 클라우드 서비스 동작 · 한도 · 요금 단위. `cloud.google.com/docs` 가 `docs.cloud.google.com` 으로 넘어간다 | 무료 | WebSearch `site:docs.aws.amazon.com 검색어` 등 |
| GitHub 릴리스 · CHANGELOG | `github.com/<소유자>/<저장소>` | 버전별 변경 · 깨지는 변경(breaking change) | 무료 | `gh release list -R <소유자>/<저장소>` · `gh release view <태그> -R …`, WebFetch `…/blob/main/CHANGELOG.md` |
| 프로젝트 위키 · 마이그레이션 가이드 | 예: `github.com/spring-projects/spring-boot/wiki` | 메이저 버전 업그레이드 절차 | 무료 | WebSearch `"<제품명> <버전> migration guide"` · `"upgrading to <버전>"` |
| JDK 개선 제안 (JEP) | `openjdk.org/jeps` | Java 기능이 들어간 버전 · 상태 | 무료 | WebFetch `openjdk.org/jeps/0` (목록) |
| Node.js 릴리스 | `nodejs.org/en/blog/release` | 버전별 변경 · LTS 일정 | 무료 | WebFetch 해당 버전 글 |
| endoflife.date | `endoflife.date` | 제품별 지원 종료 일정 · 버전별 마지막 릴리스 (사람이 모은 자료) | 무료 | WebFetch `endoflife.date/<제품>`, API `endoflife.date/api/<제품>.json` |
| Go 패키지 문서 | `pkg.go.dev` | Go 모듈 API · 버전 | 무료 | WebFetch `pkg.go.dev/<모듈 경로>` |
| Rust 크레이트 문서 | `docs.rs` | 크레이트 API · 버전 | 무료 | WebFetch `docs.rs/<크레이트>/<버전>` |

### 웹 플랫폼 레퍼런스

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| MDN Web Docs | `developer.mozilla.org` | HTML · CSS · JS · Web API 레퍼런스, 브라우저 호환 표 | 무료 | WebSearch `site:developer.mozilla.org 검색어`, 경로 `developer.mozilla.org/en-US/docs/…` |
| DevDocs | `devdocs.io` | 여러 공식 문서를 한곳에서 검색. 원 문서의 사본이다 | 무료 | WebFetch `devdocs.io/<문서>/` (원 출처로 바꿔 인용) |
| Can I use | `caniuse.com` | 브라우저별 기능 지원 | 무료 | WebFetch `caniuse.com/<기능>` |

### 표준

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| IETF RFC (RFC Editor) | `rfc-editor.org` | 인터넷 표준 원문. `rfc-editor.org/rfc/rfc<번호>`, 상태 `rfc-editor.org/info/rfc<번호>` | 무료 | `reference-search.sh rfc 제목어` |
| RFC 정오표 | `errata.rfc-editor.org` | 확인된 오류 · 수정. `rfc-editor.org/errata/rfc<번호>` 가 이리로 넘어간다 | 무료 | WebFetch `rfc-editor.org/errata/rfc<번호>` |
| IETF Datatracker | `datatracker.ietf.org` | RFC 이력 · Internet-Draft · WG 진행 상황 | 무료 | WebFetch `datatracker.ietf.org/doc/rfc<번호>/`, 초안은 `datatracker.ietf.org/doc/search/` |
| W3C | `w3.org/TR` | 웹 표준. 성숙도 WD · CR · PR · REC, WCAG (`w3.org/WAI/standards-guidelines/wcag`) | 무료 | WebSearch `site:w3.org/TR 검색어` |
| WHATWG | `spec.whatwg.org` · `html.spec.whatwg.org` | HTML · DOM · Fetch · URL 등 Living Standard | 무료 | WebFetch `spec.whatwg.org` (목록), 각 표준 하위 도메인 |
| ECMA International | `ecma-international.org` | ECMA-262(ECMAScript) · ECMA-404(JSON) 등. 해마다 판이 나온다 | 무료 | WebFetch `ecma-international.org/publications-and-standards/standards/ecma-262/` |
| TC39 ECMAScript 초안 | `tc39.es/ecma262` | 다음 판에 들어갈 내용을 담은 작업 초안 | 무료 | WebFetch `tc39.es/ecma262/` |
| ISO | `iso.org` | 국제 표준. 원문은 유료, 미리보기는 OBP(`iso.org/obp`) | 유료 (일부 무료 공개 표준 `standards.iso.org/ittf/PubliclyAvailableStandards`) | WebSearch `site:iso.org/standard "ISO/IEC <번호>"` (번호 · 판 · 상태 확인용) |
| IEC | `iec.ch` · `webstore.iec.ch` | 전기 · 전자 국제 표준 | 유료 | WebSearch `site:webstore.iec.ch IEC <번호>` |
| NIST | `csrc.nist.gov` · `nvlpubs.nist.gov` · `nist.gov` | 보안 SP 800 시리즈 · FIPS · 암호 표준. SP 800-63-4 처럼 `pages.nist.gov` 판이 있는 것도 있다 | 무료 | WebSearch `site:csrc.nist.gov "SP 800-<번호>"` |
| OWASP | `owasp.org` · `top10.owasp.org` · `asvs.owasp.org` · `cheatsheetseries.owasp.org` | Top 10 · ASVS · Cheat Sheet. `owasp.org/Top10` 이 `top10.owasp.org` 로 넘어간다 | 무료 | WebFetch 각 하위 도메인 |
| Unicode | `unicode.org` · `cldr.unicode.org` | Unicode 표준 · 기술 보고서(UAX · UTS) · 로캘 데이터 | 무료 | WebFetch `unicode.org/reports/` |
| IEEE 표준 | `standards.ieee.org` | 802 · 754 등. 일부는 IEEE GET Program 으로 무료 | 유료 (GET Program 대상은 무료) | WebSearch `site:standards.ieee.org "IEEE <번호>"` |
| ETSI | `etsi.org` | 통신 표준 | 무료 (PDF 공개) | WebSearch `site:etsi.org 검색어` |
| 국가표준 (KS) | `standard.go.kr` | 한국산업표준 검색 · 열람 | 무료 일부 (열람은 무료, 원문 구매는 유료) | WebFetch 검색 페이지 (자바스크립트라 결과가 비면 WebSearch `"KS X <번호>"`) |
| TTA 표준 | `tta.or.kr` | 국내 정보통신 단체 표준 | 무료 일부 | WebSearch `site:tta.or.kr TTAK 검색어` |
| KISA | `kisa.or.kr` | 국내 보안 가이드 · 암호 알고리즘 안내 | 무료 | WebSearch `site:kisa.or.kr 가이드 검색어` |

## 검색 문법과 요령

### 문서 버전 확인

| 확인할 것 | 방법 |
|---|---|
| 문서가 어느 버전 것인가 | URL 경로의 버전 (`docs.python.org/3.12/` · `docs.spring.io/spring-boot/<버전>/`)이나 페이지의 버전 선택기를 본다. 경로에 버전이 없으면 "현재 안정판" 이다 |
| 사용자가 쓰는 버전 문서로 | 경로의 버전을 바꿔 WebFetch 한다. 없으면 GitHub 의 해당 태그 소스에서 문서 파일을 연다 |
| 언제 바뀌었나 | CHANGELOG · 릴리스 노트에서 기능 이름을 찾는다. 문서의 "Added in" · "Changed in" · "Deprecated since" 표시를 본다 |
| 지원 중인가 | `endoflife.date/<제품>` 으로 먼저 보고, 제품 공식 지원 정책 페이지로 확인한다 |
| 깨지는 변경 | `"<제품> <버전>" "breaking changes"` · `"<제품>" "migration guide"` · GitHub 릴리스의 BREAKING 표시 |

### 표준 찾기

| 하고 싶은 것 | 방법 |
|---|---|
| 주제로 RFC 찾기 | `reference-search.sh rfc <제목어>` (제목 부분 일치). 결과의 `std_level` 로 Proposed Standard · Internet Standard · Informational 을 가린다 |
| RFC 가 아직 유효한가 | `rfc-editor.org/info/rfc<번호>` 의 "Obsoleted by" · "Updated by" 를 본다. 대체됐으면 새 번호로 다시 인용한다 |
| 진행 중인 초안 | `datatracker.ietf.org/doc/search/` 에서 `draft-` 이름으로. 초안은 6개월마다 만료되며 "work in progress" 로만 인용한다 |
| W3C 문서 상태 | 문서 머리의 상태(W3C Recommendation · Candidate Recommendation · Working Draft · Editor's Draft)를 적는다. Editor's Draft 는 표준이 아니다 |
| HTML · DOM 동작 | W3C 가 아니라 WHATWG Living Standard 가 기준이다. 커밋 날짜(스냅숏)를 같이 적는다 |
| ISO 표준 판 | `iso.org/standard/<번호>` 페이지의 판(Edition) · 상태(Published · Withdrawn · Under review). 원문을 못 열면 "원문 미열람" 으로 적는다 |
| NIST 문서 | 최종판(Final)과 초안(Draft · Initial Public Draft)을 구분한다. 개정판 번호(Rev. 5 등)를 적는다 |

### 문서와 실제 동작이 다를 때 소스로 넘기는 기준

아래 중 하나면 문서 대신 소스(`code-usage-searcher` 의 GitHub 코드 검색 · 해당 태그의 소스)를 근거로 삼는다.

- 문서에 없는 기본값 · 한도 · 예외 동작을 물었다.
- 문서 설명과 사용자가 본 동작이 다르다고 보고됐다.
- 문서의 버전과 사용자가 쓰는 버전이 다르고, 그 버전 문서가 없다.
- 같은 동작을 두고 이슈 트래커에 "문서 오류" 이슈가 열려 있다 (`reference-search.sh github-issue "<기능> documentation incorrect"`).
- 표준과 구현이 다르다 (예: 브라우저가 명세와 다르게 동작). 이때는 구현 쪽 버그 트래커와 MDN 호환 표를 같이 본다.

소스를 근거로 쓸 때는 저장소 · 태그(또는 커밋) · 파일 경로 · 줄 번호를 적는다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 공식 문서 (버전) | 제품을 만든 쪽이 낸 문서. 문서 버전을 적는다 |
| 릴리스 노트 | 버전별 변경 기록. 버전 · 날짜를 적는다 |
| 표준 (상태) | RFC 의 std_level, W3C 성숙도, ISO 판 · 상태, NIST 최종판 · 초안 |
| 표준 초안 | Internet-Draft · Editor's Draft · NIST Draft. 인용은 되지만 확정 아님 |
| 2차 레퍼런스 | MDN · DevDocs · endoflife.date. 원 출처가 있으면 원 출처로 바꾼다 |
| 소스 확인 | 문서 대신 소스 코드로 확인했다. 저장소 · 태그 · 경로 |

주의:

- 작성 날짜 · 버전: 버전 없는 문서 링크는 시간이 지나면 다른 내용을 가리킨다. 버전 경로가 있으면 그것으로 인용한다.
- 대체 · 폐기: RFC 의 Obsoleted by, ISO 의 Withdrawn, W3C 의 Superseded · Discontinued 를 확인하지 않은 인용은 쓰지 않는다.
- 홍보성: 벤더 문서의 성능 수치 · 비교표는 벤더 측 측정이다. 측정 조건을 같이 적는다.
- 유료 표준: 원문을 열지 못했으면 표준 번호 · 제목 · 판까지만 적고 조항 내용은 `미확인` 으로 둔다.
- 2차 자료 사본(DevDocs)은 원 문서보다 늦게 갱신될 수 있다.
