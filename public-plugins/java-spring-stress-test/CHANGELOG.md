# CHANGELOG

## 0.1.9

### Fixed
- Anthropic 디렉터리 검증기가 막는 표기를 같은 동작의 표기로 바꿨다 — 따옴표 안의 `>`(awk 비교식 · YAML 블록 표지 · pom.xml 태그 정규식 · SPR-01 메시지)는 같은 뜻의 `<` 로 뒤집거나 실행 때 만든 값으로, `${…}` 안에 겹친 따옴표(`relpath`)는 `case` 로 풀어 쓰고, 따옴표 옆 `$'\n'` 은 맨 위에서 만든 변수로 바꿨다. 판정 · 출력은 그대로다 (#281, `TC-S42`)

## 0.1.8

### Fixed
- 훅 스크립트를 Anthropic 디렉터리 검증기가 읽지 못하던 것 — awk 정규식의 `<<` 를 `[<][<]` 로, 따옴표 안 명령 치환 · 프로세스 치환 · 명령 치환을 담은 here-document 를 변수 대입과 줄 배열로 바꾼다. 판정은 같다 (#256)

## 0.1.7

### Fixed
- 훅이 `bombardier` · `siege` · `h2load` · `httperf` · `ghz` · `plow` · `drill` · `fortio load` 를 부하 명령으로 보지 않아 설정 점검을 알리지 않던 것 — `common-stress-test` 의 부하 명령 목록과 맞춘다 (#240)

## 0.1.6

### Changed
- `plugin.json` 에 `license`(MIT)를 적었다 — Anthropic 디렉터리 제출 조건 (#233)

## 0.1.5

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 1건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.4

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 부하 명령 점검 없이 통과하던 것 (#166, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- `SPR-02` 가 `application-loadtest` · `perftest` · `stresstest` 프로필 파일을 건너뛰던 것 — 파일도 문서 단위 판정과 같이 프로필 이름이 단어로 dev · local · test 일 때만 뺀다 (#124)
- 훅이 `nice` · `ionice` · `stdbuf` · `xargs` · `watch` · `caffeinate` 로 감싼 부하 명령을 알아보지 못하던 것 — 값을 받는 옵션(`nice -n 10` · `xargs -I {}`)은 값까지 건너뛴다 (#124)

## 0.1.2

### Fixed
- `SPR-02` 가 `application.yml` 안 `---` + `on-profile: local` 문서의 `root: DEBUG` 를 막던 것 — dev · local · test 프로필에서만 켜지는 문서(`---` · `#---`)는 건너뛴다. `!local` · `dev | prod` 문서는 본다 (#91)
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `java-spring-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/spring-stress-rules.md` (`SPR-01` ~ `SPR-15`), 계측 레시피 `spring-instrumentation-recipe.md`, JMH 절차 `jmh-benchmark.md`
- 무효 설정 탐지기 `scripts/spring-stress-config-validate.sh` — CLI(`[디렉터리]`)와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행일 때만 경고)
- `spring-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
