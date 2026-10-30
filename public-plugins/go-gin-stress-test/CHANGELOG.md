# CHANGELOG

## 0.1.4

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 부하 명령이 점검 없이 통과하던 것 (#165, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- 훅이 `nice` · `ionice` · `stdbuf` · `xargs` · `watch` · `caffeinate` 로 감싼 부하 명령을 알아보지 못하던 것 — 값을 받는 옵션(`nice -n 10` · `xargs -I {}`)은 값까지 건너뛴다 (#124)

## 0.1.2

### Fixed
- `GIN-01` · `GIN-05` 가 `.env.local` · `docker-compose.dev.yml` 의 `GIN_MODE=debug`, CI 워크플로의 `go build -race` 를 운영 설정으로 보고 막던 것 — 이름에 dev · local · test 가 든 파일과 CI 파일(`.github/` · `.gitlab-ci.yml`)을 뺀다 (#91)
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `go-gin-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/gin-stress-rules.md` (`GIN-01` ~ `GIN-12` 기계 판정, `GIN-20` ~ `GIN-26` AI 판단)
- 계측 레시피 `references/gin-instrumentation-recipe.md`, 마이크로벤치마크 절차 `references/go-microbenchmark.md`
- 무효 설정 탐지기 `scripts/gin-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행 때 경고)
- `gin-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
