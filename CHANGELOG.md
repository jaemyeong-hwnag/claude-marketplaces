# CHANGELOG

## 미출시

- `marketplace-directory-structure` 내부 플러그인 추가 — 마켓플레이스 루트와 플러그인의 디렉터리 구조를 검증한다
- 루트와 각 플러그인에 `CHANGELOG.md` 추가 (구조 규칙 `R-02` · `P-01`)

## 0.1.0

- 마켓플레이스 `plugin-marketplace` 와 `public-plugins/` · `internal-plugins/` 배치 구조
- 배치 정책 검증 훅 `.claude/hooks/validate-plugin-scope.sh`
- 내부 플러그인 설치 동기화 훅 `.claude/hooks/sync-internal-plugins.sh`
- SessionStart 훅 등록과 플러그인 활성화 설정
- `plugin-naming` 내부 플러그인 추가
- 배치 정책·동기화 훅 회귀 테스트
