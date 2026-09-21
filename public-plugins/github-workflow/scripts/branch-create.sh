#!/usr/bin/env bash
# 플로우 2 단계 — origin/main 에서 {타입}/{이슈}-{slug} 브랜치와 워크트리를 만든다.
#
#   branch-create.sh <feature|bugfix> <이슈 번호> <slug> [루트]
#
# 워크트리 위치: {루트}/.claude/worktrees/{이슈}-{slug}  (W-04)
# 종료 코드: 0 성공 / 2 규칙 위반·확인 실패 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$#" -ge 3 ] || { echo "사용법: branch-create.sh <feature|bugfix> <이슈 번호> <slug> [루트]" >&2; exit 1; }
TYPE="$1"; ISSUE="$2"; SLUG="$3"
ROOT="$(cd "${4:-${CLAUDE_PROJECT_DIR:-$(pwd)}}" && pwd)"
BRANCH="$TYPE/$ISSUE-$SLUG"
WT="$ROOT/.claude/worktrees/$ISSUE-$SLUG"

"$SCRIPT_DIR/validate-workflow.sh" --branch "$BRANCH" || exit 2
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { echo "❌ $ROOT 는 git 저장소가 아니다" >&2; exit 2; }
[ -e "$WT" ] && { echo "❌ $WT 가 이미 있다" >&2; exit 2; }
git -C "$ROOT" rev-parse -q --verify "refs/heads/$BRANCH" >/dev/null && { echo "❌ 브랜치 $BRANCH 가 이미 있다" >&2; exit 2; }
git -C "$ROOT" fetch -q origin main || { echo "❌ origin 에서 main 을 받아올 수 없다" >&2; exit 2; }
git -C "$ROOT" worktree add -q -b "$BRANCH" "$WT" origin/main || { echo "❌ 워크트리를 만들지 못했다" >&2; exit 2; }

echo "✅ $BRANCH"
echo "   워크트리: $WT"
echo "   기준: origin/main ($(git -C "$ROOT" rev-parse --short origin/main))"
echo "   다음: 이 워크트리에서 작업 → pull-request-create"
