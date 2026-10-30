# CHANGELOG

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
