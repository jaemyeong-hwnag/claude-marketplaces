# CHANGELOG

## 0.1.4

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 무효 설정 경고 없이 부하 명령이 통과하던 것 (#173, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- `docker-compose.loadtest.yml` · `Dockerfile.perftest` 를 개발용으로 보고 건너뛰던 것 — 이름에 단어로 dev · local · test 가 든 파일만 뺀다 (#124)
- `NST-01` 이 빈칸 없는 exec 형식 `command: ["nest","start","--watch"]` · `["npm","run","start:dev"]` 를 놓치던 것 (#124)
- 훅이 루트 `package.json` 만 봐서 워크스페이스 하위 앱(`cd apps/api && k6 run …`)을 놓치던 것 — 명령이 도는 디렉터리(입력의 `cwd` · 앞머리 `cd`)부터 위로 가장 가까운 `@nestjs/core` 앱을 본다 (#124)
- 훅이 `nice` · `ionice` · `stdbuf` · `xargs` · `watch` · `caffeinate` 로 감싼 부하 명령을 알아보지 못하던 것 — 값을 받는 옵션(`nice -n 10` · `xargs -I {}`)은 값까지 건너뛴다 (#124)

## 0.1.2

### Fixed
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `typescript-nestjs-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/nestjs-stress-rules.md` (`NST-01` ~ `NST-20`)
- 계측 · 마이크로벤치마크 레시피 `references/nestjs-stress-recipes.md`
- 무효 설정 탐지기 `scripts/nestjs-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 명령이면 경고)
- `nestjs-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
