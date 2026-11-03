# CHANGELOG

## 0.1.8

### Fixed
- Anthropic 디렉터리 검증기가 문서의 백틱으로 감싼 느낌표를 스킬 · 커맨드 실행 줄로 읽어 COMMAND_PATH_COMPUTED 로 차단하던 것 — 느낌표를 백틱 없이 적었다. 뜻은 그대로다 (#270)

## 0.1.7

### Fixed
- 훅 스크립트 `scripts/code-edit-guardrail.sh` 를 Anthropic 디렉터리 검증기가 읽을 수 있게 따옴표 안 명령 치환 · here-document · here-string 을 변수 · 줄 단위 루프로 바꿨다. 판정은 그대로다 (#258)

## 0.1.6

### Changed
- 규칙 원본의 "다루지 않는 것" 에서 지운 플러그인 `project-completeness` 이름을 뺐다 (#251)

## 0.1.5

### Changed
- README 에 면제는 `test:<사유>` 줄만 보고 사용자 동의는 확인하지 않는다고 적었다 (#249)

## 0.1.4

### Changed
- `plugin.json` 에 `license`(MIT)를 적었다 — Anthropic 디렉터리 제출 조건 (#233)

## 0.1.3

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 2건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.2

### Fixed
- `UserPromptSubmit`(`reset`) · `PreToolUse`(`shared`) 훅에 `"onFailure": "block"` — 스크립트가 깨지면 편집 기록 초기화 · 공유자원 확인(`G-03`) 없이 통과하던 것 (#157, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.1

### Fixed
- 세션 루트 아래 워크트리(`.claude/worktrees/<id>/…`)의 파일을 고치면 기록 경로가 루트 기준 글롭에 안 걸려 `G-01` · `G-02` 가 통과하던 것 — 프로젝트 아래의 다른 git 작업 트리에 있는 파일은 그 작업 트리에 설정이 있으면 그 작업 트리를 루트로 설정 · 상대 경로 · lane 실행 위치를 정한다 (#95). `G-03` 도 같은 루트로 본다

## 0.1.0

### Added
- 규칙 원본 `references/code-edit-guardrail-rules.md` — 설정 `.claude/code-edit-guardrail.json` 형식과 글롭, 게이트 `G-01` 테스트 동반 · `G-02` 품질 lane · `G-03` 공유자원 확인, 설정 검증 `C-01` ~ `C-05` (#51)
- 훅 스크립트 `scripts/code-edit-guardrail.sh` — UserPromptSubmit 기록 초기화 · PreToolUse 공유자원 확인 · PostToolUse 편집 기록 · Stop 게이트, CLI `validate`. 편집 기록 · 면제 파일은 프로젝트의 `.claude/code-edit-guardrail/` (스스로 ignore)
- 스킬 `code-edit-guardrail-apply` — 스택 감지로 설정 초안을 쓰고 공유자원은 사용자가 확정한다
