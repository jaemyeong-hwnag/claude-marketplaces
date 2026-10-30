# CHANGELOG

## 0.2.1

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 1건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.2.0

### Changed
- 커맨드 `/workflow-validate` 를 `/github-workflow-validate` 로 바꿨다 (#198). 무엇의 workflow 인지 이름만으로 알 수 없었다 — 이제 `/github-workflow:github-workflow-validate` 로 부른다

## 0.1.6

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 `W-*` 차단 없이 통과하던 것 (#158, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.5

### Fixed
- `branch-create.sh` — 루트를 메인 체크아웃(`--git-common-dir` 의 상위)으로 정한다 (#84). 워크트리 안에서 부르면 워크트리 안에 워크트리를 중첩해, 바깥 워크트리를 지울 때 안쪽이 커밋 안 된 변경째 지워졌다
- 훅이 풀 수 없는 `cd` · `-C` 대상(지금 없는 디렉터리 · 변수 경로)을 시작 디렉터리로 바꿔 판정하던 것을 고쳤다 (#84) — 시작 디렉터리가 `main` 이면 다른 임시 저장소의 커밋도 `W-09` 로 막혔다. 이제 그 뒤 조각은 브랜치를 모르는 것으로 본다. `cd` 의 옵션(`-P` · `--`)은 건너뛴다

## 0.1.4

### Fixed
- `branch-create.sh` — 워크트리 디렉터리가 무시되지 않는 저장소면 `.git/info/exclude` 에 `/.claude/worktrees/` 를 넣는다 (#76). `git add -A` 가 워크트리를 gitlink 로 넣었다

## 0.1.3

### Fixed
- `W-09` — 기본 브랜치에서 `git push origin HEAD` · `@` 를 막는다 (#74). 대상이 문자열 `HEAD` 라 `main` 과 달라 통과했다

## 0.1.2

### Fixed
- 훅이 명령을 공백으로만 나눠 따옴표 · heredoc 안의 글자를 옵션으로 읽던 것을 고쳤다 (#59) — 제목의 `-w` 가 `W-05` · `W-06` 을 끄고, 제목 · 본문의 `--fill` · `git push` 가 막혔다. 따옴표 · `$( )` · heredoc · 리다이렉션을 아는 토큰화로 바꿨다
- `gh pr create` · `gh pr merge` 를 옵션 스펙대로 읽는다 — `--subject` 같은 값이 PR 번호로 읽혀 머지가 막히지 않는다. `-R` 은 PR 조회에 넘긴다
- `W-08` — `--force-with-lease --force-if-includes` 를 막지 않는다
- `W-09` — 기본 브랜치에서 `--ff-only` 가 아닌 `git pull`(`pull.ff=only` 면 통과)과 `cherry-pick` · `revert` · `am` 을 막는다
- 서브셸 · `{ }` · `/usr/bin/git` · `command` · `env` · `bash -c` · `eval` · `$( )` 안의 명령도 본다. `cd ~` 를 홈으로 푼다
- `origin/HEAD` 가 없으면 `origin/main` → `origin/master` 순으로 기본 브랜치를 찾는다 (훅 · `branch-create.sh`)
- `jq` 가 없으면 `git` · `gh` · `claude` 명령을 막는다 — 전에는 exit 1 이라 통과했다

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `github-workflow@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- `plugin-workflow`(internal) 에서 GitHub 플로우를 떼어 public 으로 (#12). 규칙 원본 `W-01` ~ `W-10` 과 TC 를 그대로 옮겼다
- `validate-workflow.sh` — `PreToolUse(Bash)` 훅. 브랜치 이름 · 기본 브랜치 보호 · 머지 방식 · 최신 확인 · 태그 위치 · PR 템플릿 · 라벨. CLI `--templates` · `--branch` · `--up-to-date`
- 기본 브랜치를 `origin/HEAD` 에서 읽는다 (없으면 `main`) — 훅과 `branch-create.sh` 모두
- `branch-create.sh`, `/workflow-validate`
- 스킬 `github-template-create`(기본 템플릿 포함) · `issue-create` · `pull-request-create` · `pull-request-merge`
- eval 케이스 — PR 스킬 발동 · main 커밋 차단
