# CHANGELOG

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `python-fastapi-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/fastapi-stress-rules.md` (`FAS-01` ~ `FAS-13`, `FAS-20`) — 계측 레시피 · 손잡이 · 실측 요약 · 마이크로벤치마크
- 검증기 `scripts/fastapi-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행이면 알림)
- `fastapi-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
