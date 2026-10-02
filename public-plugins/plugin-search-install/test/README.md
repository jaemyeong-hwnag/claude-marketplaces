# plugin-search-install 테스트

`scripts/plugin-search-install.sh` 의 회귀 테스트.

## catalog

| ID | 케이스 |
|---|---|
| TC-C01 | 마켓플레이스 둘의 엔트리를 모두 읽는다 (없는 위치는 건너뜀) |
| TC-C02 | 스킬 · 커맨드 · 훅 이벤트를 읽는다 |
| TC-C03 | 여러 줄 description (>) 을 한 줄로 읽는다 |
| TC-C04 | plugin.json 의 dependencies (문자열 · 객체) 를 이름으로 |
| TC-C05 | 설치 상태 · 범위 · 설치 수 |
| TC-C06 | installCount 를 붙인다 |
| TC-C07 | 깨진 plugin.json 이 있어도 .mcp.json 은 읽는다 |
| TC-C08 | 설명의 제어 문자(ESC · BEL)를 지운다 |
| TC-C09 | metadata.pluginRoot 를 상대 source 앞에 붙인다 |
| TC-C10 | 원격 source 는 구성요소 모름으로 표시 |
| TC-C15 | 다른 프로젝트의 project 범위 설치는 여기서 설치 안 됨 |
| TC-C16 | 이름 · id 의 제어 문자를 지운다 (ESC · BEL) |
| TC-C17 | 설명의 NUL 도 지운다 |
| TC-C18 | 캐시 파일 이름에 지문을 넣는다 (키 · 내용 짝이 어긋나지 않게) |
| TC-C11 | plugin.json keywords 를 엔트리 keywords 와 합친다 |
| TC-C12 | claude CLI 가 없으면 설정 디렉터리의 기록 파일로 읽는다 |
| TC-C13 | 지문이 같으면 캐시를 쓴다 |
| TC-C14 | PLUGIN_SEARCH_CATALOG 로 카탈로그를 주입한다 |

## search

| ID | 케이스 |
|---|---|
| TC-Q01 | 이름 단어 일치가 맨 위 |
| TC-Q02 | 한글 동의어 (네이밍 → naming) |
| TC-Q03 | 한글 조사를 떼고 찾는다 (커버리지를) |
| TC-Q04 | 오타 허용 (covrage → coverage) |
| TC-Q05 | --exact 는 오타 · 동의어를 끈다 |
| TC-Q06 | -단어 는 제외한다 |
| TC-Q07 | 필드 지정 (tag:spring) |
| TC-Q08 | has:agent 필터 |
| TC-Q09 | is:installed 필터 |
| TC-Q10 | /정규식/ |
| TC-Q11 | a\|b 는 둘 중 하나 |
| TC-Q12 | 모든 단어에 맞는 게 없으면 완화하고 relaxed 로 알린다 |
| TC-Q13 | --any 는 완화 표시 없이 OR |
| TC-Q14 | 불용어(플러그인 · 찾아줘)는 무시한다 |
| TC-Q15 | --tag · --has · --installed 옵션 필터 |
| TC-Q16 | 스킬 이름으로 찾는다 (skill:issue-create) |
| TC-Q17 | MCP 서버 이름으로 찾는다 |
| TC-Q18 | dep: 는 의존하는 플러그인 |
| TC-Q19 | --limit 과 total |
| TC-Q20 | tsv 는 헤더 + 줄마다 탭 8칸 |
| TC-Q21 | --sort installs |
| TC-Q22 | why 에 일치 이유 |
| TC-Q23 | 검색어 · 필터가 없으면 2 |
| TC-Q24 | 모르는 옵션 · 잘못된 값은 2 |
| TC-Q26 | 이름의 일부(하이픈 포함)로 찾는다 |
| TC-Q27 | --min-score 가 숫자가 아니면 jq 오류가 아니라 안내로 멈춘다 |
| TC-Q28 | 잘못된 정규식은 jq 오류가 아니라 안내와 2 |
| TC-Q25 | 공백이 든 인자는 단어로 나눈다 |

## related

| ID | 케이스 |
|---|---|
| TC-R01 | 의존 (직접 · 간접) |
| TC-R02 | 역의존 (직접 · 간접) |
| TC-R03 | --by tag 는 태그만 |
| TC-R04 | 이름 단어 공유 (naming) |
| TC-R05 | 같은 이름이 여러 마켓이면 ambiguous 로 알린다 |
| TC-R06 | 기능어면 검색 일치를 앞에, 연관을 뒤에 |
| TC-R08 | 기능어의 직접 일치는 최소 점수에 걸려도 남는다 |
| TC-R07 | 모르는 --by 는 2 |

## project

| ID | 케이스 |
|---|---|
| TC-P01 | 신호: java · spring · gradle |
| TC-P02 | 선언됨 + 설치됨 → ok |
| TC-P03 | 선언됨 + 미설치 → missing |
| TC-P04 | false 로 끈 선언 → off |
| TC-P05 | 마켓플레이스가 없는 선언 → marketplace-missing |
| TC-P06 | 선언의 의존 폐포 → dependency (beta-coverage) |
| TC-P07 | 신호로 추천 (java-spring-test) |
| TC-P08 | 감지 안 된 언어 대상은 깎는다 (kotlin) |
| TC-P09 | --only missing |
| TC-P10 | --only recommended 는 선언을 뺀다 |
| TC-P13 | 깨진 설정 파일은 건너뛰고 알린다 — 다른 파일의 선언은 남는다 (공백 경로) |
| TC-P11 | 신호 · 선언이 없으면 빈 결과 |
| TC-P12 | node_modules 는 보지 않는다 |

## show · facets

| ID | 케이스 |
|---|---|
| TC-F01 | show 는 구성요소 목록과 역의존 |
| TC-F02 | 없는 플러그인은 2 |
| TC-F03 | facets tag 개수 |
| TC-F04 | facets has 는 구성요소 종류별 |

## install

| ID | 케이스 |
|---|---|
| TC-I01 | dry-run 은 설치하지 않는다 |
| TC-I02 | dry-run 뒤 호출 기록이 없다 |
| TC-I03 | 이미 설치된 것은 건너뛴다 |
| TC-I04 | 설치는 --scope 와 --json 으로 부른다 |
| TC-I05 | 호출 인자 |
| TC-I06 | 같은 이름이 여러 마켓이면 설치 전에 멈춘다 |
| TC-I07 | --from 에 선택이 없으면 조회만 |
| TC-I08 | --select 번호 · 범위 |
| TC-I09 | --exclude 로 뺀다 |
| TC-I10 | --all 은 목록 전부 |
| TC-I11 | 목록에 없는 번호는 2 |
| TC-I12 | stdin 의 id 줄 목록 |
| TC-I13 | 하나라도 실패하면 1, 나머지는 계속 |
| TC-I14 | 실패 메시지를 결과에 남긴다 |
| TC-I15 | 카탈로그에 없는 이름은 2 |
| TC-I16 | 모르는 --scope 는 2 |
| TC-I17 | --format ids 는 설치된 것만 |
| TC-I18 | --select 이름이 여러 마켓에 있으면 설치 전에 멈춘다 |
| TC-I19 | 범위 일부가 목록 밖이면 아무것도 고르지 않고 2 |
| TC-I20 | 거꾸로 된 범위는 2 |
| TC-I21 | 같은 대상을 두 번 주면 한 번만 |
| TC-I22 | tsv 출력을 --from 으로 다시 읽는다 |
| TC-I23 | 쉼표만 준 선택은 조회만 — ids 출력이 비어 있다 |
| TC-I24 | 공백만 준 선택은 아무것도 고르지 않는다 |
