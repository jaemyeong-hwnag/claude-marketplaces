# CHANGELOG

## 0.1.9

### Fixed
- Anthropic 디렉터리 검증기가 막는 표기를 같은 동작의 표기로 바꿨다 — 따옴표 안의 `>`(FAS-04 · FAS-07 awk 비교식 6곳)는 같은 뜻의 `<` 로 뒤집고, `${…}` 안에 겹친 따옴표 2곳(`is_dev` · `loc`)은 `case` 로 풀어 썼다. 판정 · 출력은 그대로다 (#281, `TC-F43`)

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
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 설정 검사 없이 통과하던 것 (#172, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- 훅이 `nice` · `ionice` · `stdbuf` · `xargs` · `watch` · `caffeinate` 로 감싼 부하 명령을 알아보지 못하던 것 — 값을 받는 옵션(`nice -n 10` · `xargs -I {}`)은 값까지 건너뛴다 (#124)

## 0.1.2

### Fixed
- `FAS-01` 이 `Makefile` 의 dev 대상 · `docker-compose.dev.yml` · CI 파일의 `--reload` 를 막던 것 — 이름에 dev · local · test 가 든 파일, Makefile 의 그 이름 대상, CI 파일(`.github/` · `.gitlab-ci.yml`)을 뺀다 (#91)
- `FAS-02` 가 `docker-compose.dev.yml` · CI 파일의 `--workers` 를 운영 워커 수로 보고 막던 것 — 같은 개발 · CI 파일을 뺀다 (#91)
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `python-fastapi-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/fastapi-stress-rules.md` (`FAS-01` ~ `FAS-13`, `FAS-20`) — 계측 레시피 · 손잡이 · 실측 요약 · 마이크로벤치마크
- 검증기 `scripts/fastapi-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행이면 알림)
- `fastapi-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
