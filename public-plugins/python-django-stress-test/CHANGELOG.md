# CHANGELOG

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
