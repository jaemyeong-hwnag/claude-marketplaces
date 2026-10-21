# CHANGELOG

## 0.1.2

### Fixed
- `DJ-01` 이 CI 워크플로의 `runserver` 를, `DJ-06` 이 `docker-compose.dev.yml` 의 `--workers` 를 막던 것 — CI 파일(`.github/` · `.gitlab-ci.yml`)을 개발용으로 보고, `DJ-06` 도 dev · local · test 파일을 뺀다 (#91)
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `python-django-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/django-stress-rules.md` (`DJ-01` ~ `DJ-15`, `DJ-20`) — 근거와 실측 버전 포함
- 계측 레시피 `references/django-instrumentation-recipe.md` (django-prometheus · in-flight 미들웨어 · 멀티프로세스 모드 · Little 경계), 마이크로벤치마크 절차 `references/django-microbenchmark.md` (pyperf · pytest-benchmark)
- 무효 설정 탐지기 `scripts/django-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 가 부하 도구 실행이면 경고, 막지 않음)
- `django-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
