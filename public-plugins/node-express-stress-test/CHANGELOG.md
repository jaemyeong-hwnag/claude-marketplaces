# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/express-stress-rules.md` (`NEX-01` ~ `NEX-09` 무효 설정, `NEX-10` ~ `NEX-13` 계측, `NEX-20` ~ `NEX-24` 용량 손잡이)
- 계측 레시피 `references/express-instrumentation.md`, 마이크로벤치마크 절차 `references/node-microbenchmark.md`
- 무효 설정 탐지기 `scripts/express-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행 시 경고)
- `express-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
