# CHANGELOG

## 0.3.0

### Added
- `P-06` 에 `evals/` 허용, `P-07` 에 케이스 디렉터리만, 새 조항 `P-10` — 케이스에는 `prompt.md` 나 `case.yaml`
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다

### Changed
- `plugin-directory-create` 는 위치 결정만 맡는다. 생성 절차 전체는 `plugin-create`(`plugin-workflow`) — 트리거 겹침을 없앴다

## 0.2.3

### Changed
- 규칙 문서의 루트 트리에 `.github/` 를 적는다 (검사는 그대로 — 열거되지 않은 루트 항목은 막지 않는다)

## 0.2.2

### Changed
- README 를 작성 규칙 템플릿으로 개편
- `plugin-directory-create` 스킬이 README 를 템플릿(`document-create`)으로 안내하고, 검증 단계에 작성 규칙 검사를 넣는다

## 0.2.1

- `R-04` 가 `.claude/worktrees/` 안을 보지 않는다. Claude Code 가 워크트리를 저장소 안에 만들어서, 워크트리가 하나만 있어도 `--all` 이 깨졌다
- 회귀 테스트 TC 2건 추가 (45 → 47)

## 0.2.0

- `P-09` 추가 — `plugin.json` 의 `hooks` 로 표준 경로 `hooks/hooks.json` 을 가리키면 막는다. 문자열·배열 표기 모두 잡고, 표준 경로가 아닌 추가 훅 파일은 허용한다
- `plugin.json` 에서 `"hooks": "./hooks/hooks.json"` 제거 — 표준 경로는 자동 로드되므로 중복으로 판정돼 **훅 로딩 전체가 실패하고 있었다** (`claude plugin list` 에 `Hook load failed: Duplicate hooks file detected`). 이 버전부터 훅이 실제로 동작한다
- `plugin-directory-create` 스킬에 `P-09` 와 설치 후 `claude plugin list` 확인 단계 추가
- `TC-D08` 이 `P-04` 를 검사하면서 결함 패턴(`./hooks/hooks.json`)을 예시로 쓰던 것을 추가 훅 파일 경로로 교체
- 회귀 테스트 TC 6건 추가 (39 → 45)

## 0.1.0

- 디렉터리 구조 규칙 원본 `references/directory-structure-rules.md` 추가 (루트 `R-01`~`R-05`, 플러그인 `P-01`~`P-08`)
- 구조 검증기 `scripts/validate-directory-structure.sh` 추가 — 훅 모드(위치 검사)와 CLI 모드(`--all` · `--marketplace` · 경로)
- `Write`/`Edit` PreToolUse 훅 연결
- `plugin-directory-create` 스킬, `/directory-structure-validate` 커맨드 추가
- 회귀 테스트 TC 39건 추가
