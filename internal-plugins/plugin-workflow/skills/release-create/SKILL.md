---
name: release-create
description: 플러그인 PR 이 머지된 뒤 릴리즈할 때 사용한다. main 에서의 설치 확인, 버전이 바뀐 플러그인의 태그·GitHub 릴리즈를 할 때 적용한다. 트리거 — "릴리즈해", "태그 달아", "배포", "플러그인 릴리즈". 설치 확인 뒤에만, main 에서만 태그를 단다.
---

# 설치 확인 → 태그 · 릴리즈

규칙 원본: [`references/workflow-rules.md`](../../references/workflow-rules.md) — 9 · 10 단계

머지와 정리는 `pull-request-merge`(github-workflow)가 한다. 이 스킬은 **머지와 정리 사이**에 들어간다.

**태그 푸시 · 릴리즈는 원격에 남고 되돌리기 어렵다. 각 단계 전에 사용자에게 확인받는다.**

## 9. 설치 확인 — 메인 체크아웃에서

워크트리에서 작업했다면 여기서부터는 **메인 체크아웃**으로 간다 (`git worktree list` 의 첫 줄).

```bash
git switch main && git pull --ff-only
.claude/hooks/sync-internal-plugins.sh
claude plugin list | grep -n 'Error:'
```

`Error:` 가 있으면 **태그를 달지 않는다.** bugfix 이슈를 연다 (`issue-create`).

## 10. 태그 + 릴리즈

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/release-plugins.sh" --dry-run   # 먼저 보여준다
"${CLAUDE_PLUGIN_ROOT}/scripts/release-plugins.sh"             # 확인받고 실행
```

- 머지 커밋의 첫 부모와 비교해 `version` 이 바뀐 플러그인만 고른다
- 플러그인마다 `claude plugin tag --push` (`{name}--v{version}`) → `gh release create --verify-tag --latest=false`
- 노트는 **직전 태그 이후의 CHANGELOG 절 전부**다. 태그가 없었으면(첫 릴리즈) 끝까지 담는다
- 여러 플러그인을 처음 한꺼번에 릴리즈할 때는 기준을 준다: `--since {그 플러그인들이 없던 커밋}` — 기본값(머지 커밋의 첫 부모)은 이번 머지에서 버전이 바뀐 것만 고른다
- `--latest=false` 를 줘도 GitHub 는 명시적으로 Latest 인 릴리즈가 없으면 가장 최근 것을 Latest 로 잡는다. 플러그인별 릴리즈라 Latest 표시는 의미가 없다 — 무시한다
- 시작 전에 main · 깨끗한 트리 · origin/main 과 같음 · 로드 에러 없음 · 태그 중복 없음 · CHANGELOG 절 있음을 모두 확인하고, 하나라도 걸리면 아무것도 하지 않는다
- 마켓플레이스 자체(루트)는 릴리즈하지 않는다 — 루트 CHANGELOG `## 미출시` 에 쌓는다

그다음 정리는 `pull-request-merge` 8 단계로 돌아간다.
