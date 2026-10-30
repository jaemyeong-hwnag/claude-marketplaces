# CHANGELOG

## 0.1.1

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 1건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.0

### Added
- 강제 사슬 `EF-01` ~ `EF-07` — 훅 · MCP 명령의 상대 경로, 가리키는 파일, 실행 권한(작업 트리 + git 인덱스), matcher 를 받지 않는 이벤트의 matcher, 차단 · 경고 조항 ID ↔ `test/*.test.sh`, 조항이 있으면 검증기 · 훅, PreToolUse · UserPromptSubmit 훅의 `onFailure: "block"` (`--all` 경고 · `--since` 차단) (#143)
- 선언 적용 `EF-10` ~ `EF-13` — 플러그인 에이전트에서 무시되는 필드, `tools` 선언, 편집 도구 경고, 커맨드 · 스킬 이름 충돌 (#143)
- 실행 검사 `EF-20` ~ `EF-22` — 훅을 무관한 입력으로 실행(경고), MCP stdio `initialize` 응답, 지시한 MCP 도구 이름 (#143)
- eval `EF-30` · `EF-31` — trigger · hook 케이스 유무, 스킬별 발동 그레이더 (`--since` 는 새 플러그인만 차단) (#143)
- 판단 `EF-40` ~ `EF-44` — `enforcement-effectiveness-reviewer` 가 재현 명령을 붙여 지적하고 `enforcement-effectiveness-review` 가 다시 실행해 확인한다 (#143)
