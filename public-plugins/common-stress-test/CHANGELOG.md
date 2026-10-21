# CHANGELOG

## 0.1.2

### Fixed
- `ST-01` 이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 보지 않던 것 — 래퍼 · 셸 키워드를 건너뛰고 `sh -c` 는 인자를 다시 본다 (#90)
- `ST-01` 이 `<script.js` 로 넘긴 스크립트 안의 URL 을 보지 않던 것 — `<` · `>` 를 구분자로 읽는다 (#90)
- `ST-01` 이 hey · wrk · ab · oha 의 헤더 `-H` 를 호스트로 보고 막던 것 — `-H` 는 locust 에서만 호스트로 본다 (#90)
- `ST-01` 이 여러 줄 import 의 `from '<url>'`, 출력 대상(`--out` · `-o` · `K6_*` · `>` 파일), 같은 명령의 다른 구간(`curl … && k6 run`), heredoc 본문의 URL 을 대상으로 보던 것 — 부하 구간과 다른 구간의 변수 대입에서만 호스트를 모으고 이것들은 뺀다. 부하 명령 줄의 heredoc(`k6 run - <<EOF`)은 스크립트로 본다 (#90)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `common-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/stress-test-rules.md` (`ST-01` ~ `ST-35`), 근거 `stress-test-methods.md`, 실측한 템플릿 `stress-test-templates.md` (k6 유형 6개 · 단계 루프 · Docker Compose · Kubernetes Job)
- `stress-target-validate.sh` — 부하 도구가 허용 목록 밖 호스트를 겨누면 차단 (PreToolUse `Bash`)
- `stress-script-validate.sh` — k6 · Gatling · Locust · JMeter 스크립트의 closed 모델 · thresholds · p99 · maxVUs · sleep 경고 (PostToolUse `Write|Edit`, CLI)
- `stress-step-generate.sh` — k6 · Locust · JMeter · Gatling 결과를 단계 CSV 로
- `stress-report-generate.sh` — 단계 판정 · 지속 가능 용량 · Kneedle knee · USL · Little 정합성
- `stress-regression-validate.sh` — Mann-Whitney U(정확 · 정규 근사) + Cliff's delta 회귀 판정
- `stress-test-create` · `stress-result-review` · `stress-environment-create` 스킬, `/stress-script-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
