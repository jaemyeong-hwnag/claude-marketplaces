# CHANGELOG

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
