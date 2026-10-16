# CHANGELOG

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
