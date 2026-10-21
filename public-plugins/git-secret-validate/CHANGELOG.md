# CHANGELOG

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
