# CHANGELOG

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
