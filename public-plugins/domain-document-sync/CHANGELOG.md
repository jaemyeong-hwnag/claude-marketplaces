# CHANGELOG

## 0.1.5

### Fixed
- `UserPromptSubmit`(`snapshot`) · `PreToolUse`(`pre-edit`) 훅에 `"onFailure": "block"` — 스크립트가 깨지면 요청 시작 기준 저장 · 편집 전 프로토콜 주입 없이 통과하던 것 (#159, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.4

### Fixed
- 메인 체크아웃 세션에서 프로젝트 아래 워크트리의 도메인 코드를 고치면 `S-01` 이 통과하고 편집 훅 주입 · 알림도 꺼지던 것 — 문서 루트가 있는 작업 트리마다 따로 판정하고, 편집 훅은 파일이 속한 작업 트리 기준 경로로 본다 (#118)
- 요청 전부터 있던 미커밋 문서 변경이 이후 요청의 `S-01` 을 계속 통과시키던 것 — 요청 시작 때 도메인별 문서 지문도 저장해 이번 요청에 문서가 바뀌었는지로 판정한다 (#118)
- 면제 · 상태 파일이 `$TMPDIR` 에 있어 Bash 샌드박스 안에서 면제를 쓸 수 없던 것 — 프로젝트 `.claude/domain-document-sync/` (스스로 ignore) 로 옮긴다 (#118)

## 0.1.3

### Fixed
- 요청 안에서 커밋한 뒤 기본 브랜치로 push 하거나 시작 HEAD 를 amend · squash 하면 `S-01` 이 꺼지던 것 — 요청 시작 HEAD 와 지금의 내용을 비교하고, 요청 시작 때의 원격을 합치거나 그 위로 리베이스했으면 그 원격과 같은 파일은 뺀다 (#93)
- `git mv` 로 옮긴 코드의 원래 도메인을 놓치던 것 — 이동은 옛 경로 · 새 경로 둘 다 본다 (#93)
- `code:` 의 중괄호 글롭(`*.{java,kt}`)을 글자 그대로 봐 그 도메인의 `S-01` 이 꺼지고 `D-08` 경고만 내던 것 — 중괄호를 펼친다 (#93)

## 0.1.2

### Fixed
- `S-01` Stop 게이트가 요청 안에서 커밋한 도메인 코드를 보지 않던 것 — 요청 시작 때의 HEAD 와 비교한다 (#72). 원격 기본 브랜치에서 받아온 커밋은 뺀다

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
