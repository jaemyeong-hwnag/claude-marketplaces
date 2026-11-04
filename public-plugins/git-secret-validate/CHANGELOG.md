# CHANGELOG

## 0.1.9

### Fixed
- Anthropic 디렉터리 검증기 차단 3건을 같은 동작의 표기로 풀었다 — 판정 · 출력은 그대로다 (#275, `TC-S77`)
  - here-document 로 넣던 셸 명령 분해 awk 프로그램을 `scripts/shell-command-split.sh`, 패치를 파일별로 나누는 awk 프로그램을 `scripts/patch-addition-split.sh` 로 옮겼다 — 훅 스크립트가 bash 로 부른다
  - 따옴표 안의 `>`(jq · awk 비교, 사용법 문구)를 없앴다 — 검증기가 출력 리다이렉션으로 읽는다
  - 따옴표 · `${…}` 안의 `$'…'` 제어 문자를 맨 위에서 만든 변수로 바꾸고, `${…}` 안에 따옴표를 겹친 7곳을 풀었다

## 0.1.8

### Fixed
- Anthropic 디렉터리 검증기가 훅 스크립트를 끝까지 읽을 수 있게 here-string · 프로세스 치환 입력 · 따옴표 안 명령 치환 · awk 문자열의 `<<` 비교를 같은 뜻의 표기로 바꿨다 — 판정은 그대로다. Bash 훅의 commit · push 검사가 쓰는 임시 파일을 만들 수 없으면 검사를 건너뛰지 않고 막는다 (#257, `TC-S64` · `TC-S65`)

## 0.1.7

### Fixed
- `bash -c '…'` · `sh -c` · `zsh -c` · `eval` 로 감싼 `git commit` · `git push` 를 검사 없이 통과시키던 것 — 래퍼 안의 commit · push · add 도 직접 실행과 같게 본다 (#239, `GS-01`)

## 0.1.6

### Changed
- `plugin.json` 에 `license`(MIT)를 적었다 — Anthropic 디렉터리 제출 조건 (#233)

## 0.1.5

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 2건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.4

### Fixed
- `PreToolUse` 훅 두 개(`Bash` · `Write|Edit|MultiEdit`)에 `"onFailure": "block"` — 스크립트가 깨지면 git commit · push 와 파일 작성을 검사 없이 통과시키던 것 (#156, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- 명령 중간의 `cd` · 서브셸 `( … )` 안 `cd` · `git -C ~/…` 로 바뀐 커밋 대상 저장소를 보지 않고 cwd 만 봐 시크릿 커밋을 통과시키던 것 — 단순 명령마다 `cd` · `-C` 를 따라간다 (#117, `GS-01`)
- `cd "$R"` · `git -C "$(…)"` 처럼 대상을 알 수 없으면 통과시키던 것 — commit · push 를 막는다. `cd "$(git rev-parse --show-toplevel)"` 는 그 저장소 루트로 푼다 (#117)

## 0.1.2

### Fixed
- 같은 명령에 `git add <경로>` 가 있으면 경로와 상관없이 바뀐 파일 전체를 봐 커밋 대상이 아닌 `.env` 로 막던 것 — `.` · `-A` · `-u` 가 아니면 그 경로만 본다 (#94, `GS-02`)
- `git -C "<공백 든 경로>" commit` · `git -c user.name="A B" commit` 처럼 전역 옵션 값에 따옴표가 있으면 commit 으로 알아보지 못해 통과시키던 것 (#94)
- 내장 엔진이 값 어디든 `$` 뒤에 글자가 오면 플레이스홀더로 건너뛰어 `Tr0ub4dor$horse` 같은 비밀번호를 놓치던 것 — 값이 `${…}` · `$VAR` 로 시작할 때만 건너뛴다 (#94, `GS-01`)
- `/usr/bin/git commit` 처럼 경로로 부른 git 을 알아보지 못해 통과시키던 것 (#94)
- `git add "$F" && git commit` 처럼 경로에 변수 · 명령 치환이 있으면 바뀐 파일 전체를 본다 (#94)
- jq 가 없으면 실행 오류(exit 1)로 끝나 git commit · push 를 통과시키던 것 — commit · push 로 보이는 명령은 막는다 (#94)

## 0.1.1

### Fixed
- gitleaks 실행이 실패하면 커밋을 통과시키던 것 — 내장 패턴으로 다시 보고 알린다 (#73, `GS-05`). 실패 처리가 파이프 서브셸 안이라 빈 결과로 exit 0 이었다
- `git commit <경로>` · `--only` · `-i` 가 커밋하는 작업 트리 내용을 보지 않던 것 (#73)

## 0.1.0

### Added
- 규칙 원본 `references/secret-rules.md` (`GS-01` ~ `GS-05`) 와 내장 패턴 · 민감 파일 목록 `references/secret-rules.json`
- 검증기 `scripts/validate-git-secret.sh` — 훅 모드(PreToolUse `Bash` 의 `git commit` · `git push` 차단, `Write|Edit|MultiEdit` 경고)와 CLI 모드(`<파일|디렉터리>` · `--all` · `--history`). 탐지는 gitleaks, 없으면 내장 패턴
- `secret-review` 스킬, `/secret-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
