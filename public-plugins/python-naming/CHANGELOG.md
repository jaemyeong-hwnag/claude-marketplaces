# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/python-naming-rules.md` (`PY-01` ~ `PY-06`)
- 검증기 `scripts/validate-python-naming.sh` — 훅 모드(PreToolUse `Write|Edit` 에서 새로 생긴 위반만 차단)와 CLI 모드(`<파일|디렉터리>` · `--all`). 줄 끝 `# noqa` · `# noqa: N8xx` 는 그 줄을 건너뛴다
- `python-name-create` 스킬, `/python-naming-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
