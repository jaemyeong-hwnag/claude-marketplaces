# CHANGELOG

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `domain-document-sync@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/domain-document-rules.md` (`D-01` ~ `D-08` 문서 트리, `S-01` 동기 게이트)와 골격 `references/templates.md`
- 스킬 `domain-document-get` · `domain-document-create` · `domain-document-update`, 커맨드 `/domain-document-validate`
- 훅 스크립트 `scripts/domain-document-sync.sh` — SessionStart 도메인 문서 안내 · UserPromptSubmit 스냅샷 · PreToolUse 규약 주입 · PostToolUse 크기 · 등재 알림 · Stop 동기 게이트, CLI `validate` · `map`
- 도메인 ↔ 코드 매핑을 각 `_meta.md` 프런트매터 `code:` 글롭으로 — 언어 · 프레임워크 · 디렉터리 구조를 가정하지 않는다
- 도메인 ↔ 코드 매핑을 스크립트에 두지 않고 각 `_meta.md` 의 `code:` 글롭으로 둔다. 면제 파일은 이 플러그인 전용이다
