---
name: pull-request-merge
description: PR 을 머지하고 마무리할 때 사용한다. 머지 직전 최신 확인, 머지 커밋, 기본 브랜치 받아오기, 워크트리·브랜치 정리, 이슈 닫힘 확인을 할 때 적용한다. 트리거 — "머지해", "PR 머지", "머지하고 정리", "워크트리 정리". 머지 커밋과 리베이스된 브랜치만 머지하는 것을 강제한다.
---

# 머지 → 받아오기 · 정리

규칙 원본: [`references/workflow-rules.md`](../../references/workflow-rules.md) — 7 · 8 단계

**머지는 원격에 남고 되돌리기 어렵다. 처음이면 사용자에게 확인받는다.**

## 7. 머지

기본 브랜치가 그새 움직였으면 PR 브랜치를 다시 리베이스하고 검증 · 테스트를 다시 돌린다 (`pull-request-create` 5 단계).

```bash
gh pr merge {번호} --merge
```

- 머지 커밋만 (`W-07`). PR 하나를 `git revert -m 1` 로 통째로 되돌릴 수 있다
- 훅이 PR 브랜치가 최신 `origin/main` 을 포함하는지 확인하고, 아니면 막는다 (`W-06`)

## 8. 받아오기 · 정리 — 메인 체크아웃에서

워크트리에서 작업했다면 여기서부터는 **메인 체크아웃**으로 간다 (`git worktree list` 의 첫 줄).

```bash
git pull --ff-only origin main
git worktree remove .claude/worktrees/{이슈}-{slug}
git branch -d {타입}/{이슈}-{slug}
git push origin --delete {타입}/{이슈}-{slug}    # GitHub 가 지우지 않았으면
gh issue view {이슈} --json state -q .state     # CLOSED 여야 한다 — Closes/Fixes 가 닫는다
```

- `git branch -D` 는 쓰지 않는다. `-d` 가 거부하면 머지되지 않은 것이다
- 프로젝트가 머지 뒤 단계(설치 확인 · 태그 · 릴리즈)를 정했으면 정리 전에 한다. 태그는 `main` 에서만 (`W-10`)
- 이슈가 열려 있으면 PR 본문의 `Closes #` · `Fixes #` 를 확인한다
