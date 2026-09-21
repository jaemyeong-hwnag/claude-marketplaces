#!/usr/bin/env bash
# github-workflow 스크립트의 회귀 테스트 — validate-workflow.sh(훅 · CLI), branch-create.sh.
# 실제 git 저장소(임시 bare origin + 클론)로 브랜치 상태를 만든다. gh · claude 는 PATH 스텁으로 대체한다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
V="$PLUGIN_ROOT/scripts/validate-workflow.sh"
BC="$PLUGIN_ROOT/scripts/branch-create.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workflow-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$@" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_call() { [ "$TC_ON" = 1 ] || return 0; grep -qF -- "$1" "$CALLS" || fail_tc "호출에 '$1' 없음 (실제: $(tr '\n' ';' < "$CALLS"))"; }
expect_nocall() { [ "$TC_ON" = 1 ] || return 0; grep -qF -- "$1" "$CALLS" && fail_tc "'$1' 가 호출되면 안 됨"; return 0; }

# --- 스텁 --------------------------------------------------------------------
STUB="$TMP/bin"; mkdir -p "$STUB"; CALLS="$TMP/calls.log"; : > "$CALLS"; export STUB_CALLS="$CALLS"
cat > "$STUB/gh" <<'EOS'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_CALLS"
if [ "$1 $2" = "pr view" ]; then
  [ "${STUB_GH_FAIL:-0}" = 1 ] && exit 1
  echo "${STUB_HEAD:-}"; exit 0
fi
[ "$1 $2" = "release create" ] && { for a in "$@"; do case "$prev" in --notes-file) cp "$a" "$STUB_NOTES_COPY" ;; esac; prev="$a"; done; }
exit 0
EOS
cat > "$STUB/claude" <<'EOS'
#!/usr/bin/env bash
echo "claude $*" >> "$STUB_CALLS"
case "$1 $2" in
  "plugin tag")
    n="$(jq -r .name .claude-plugin/plugin.json)"; v="$(jq -r .version .claude-plugin/plugin.json)"
    git tag "$n--v$v" && git push -q origin "$n--v$v" 2>/dev/null ;;
  "plugin list") if [ "${3:-}" = "--json" ]; then [ -n "${STUB_LIST_JSON:-}" ] && cat "$STUB_LIST_JSON" || echo '[]'; else cat "${STUB_LIST:-/dev/null}"; fi ;;
  "plugin validate") echo "✔ Validation passed" ;;
  "plugin eval")
    out=""; prev=""; for x in "$@"; do [ "$prev" = "--json" ] && out="$x"; prev="$x"; done
    [ "${STUB_EVAL_NOJSON:-0}" = 1 ] && exit 1
    [ -n "$out" ] && jq -n --arg s "${STUB_EVAL_SCORE:-1}" --arg e "${STUB_EVAL_ERR:-}" \
      '{costUsd: 0.1, cases: [{name: "c", aggregates: {score: ($s | tonumber)}, arms: {with: [{error: (if $e == "" then null else $e end)}]}}]}' > "$out" ;;
esac
exit 0
EOS
chmod +x "$STUB/gh" "$STUB/claude"
export PATH="$STUB:$PATH"
export STUB_NOTES_COPY="$TMP/notes-copy.md"

# --- git 픽스처 --------------------------------------------------------------
gitq() { git -C "$@" >/dev/null 2>&1; }
mkrepo() { # $1=이름 → W(작업 클론) · O(bare origin). main 에 커밋 하나
  O="$TMP/$1.git"; W="$TMP/$1"; rm -rf "$O" "$W"
  git init -q --bare "$O"; git -C "$O" symbolic-ref HEAD refs/heads/main
  git init -q "$W"; gitq "$W" checkout -q -b main
  git -C "$W" config user.email t@example.com; git -C "$W" config user.name t
  git -C "$W" remote add origin "$O"
  echo a > "$W/a.txt"; gitq "$W" add -A; gitq "$W" commit -qm init; gitq "$W" push -q -u origin main
}
on_branch() { gitq "$W" checkout -q -b "$1"; }   # 새 브랜치로
commit_file() { echo "$2" > "$W/$1"; gitq "$W" add -A; gitq "$W" commit -qm "$1"; }
advance_main() { # origin/main 을 한 커밋 앞으로 (다른 클론에서 푸시)
  local o2="$TMP/other-$RANDOM"; git clone -q "$O" "$o2" 2>/dev/null
  git -C "$o2" config user.email t@example.com; git -C "$o2" config user.name t
  echo x > "$o2/x-$RANDOM.txt"; gitq "$o2" add -A; gitq "$o2" commit -qm other; gitq "$o2" push -q origin main
}
HOOK() { # $1=명령 $2=cwd(기본 W)
  [ "$TC_ON" = 1 ] || return 0
  OUT="$(jq -nc --arg c "$1" --arg d "${2:-$W}" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | "$V" 2>&1)"; CODE=$?
}

# --- 템플릿 픽스처 -----------------------------------------------------------
tpl() { # $1=루트 — 규칙을 지키는 .github 를 만든다
  mkdir -p "$1/.github/ISSUE_TEMPLATE" "$1/.github/PULL_REQUEST_TEMPLATE"
  printf 'name: 피처\nlabels: ["feature"]\nbody:\n  - type: textarea\n    id: a\n    attributes:\n      label: a\n' > "$1/.github/ISSUE_TEMPLATE/feature.yml"
  printf 'name: 버그픽스\nlabels: ["bugfix"]\nbody:\n  - type: textarea\n    id: a\n    attributes:\n      label: a\n' > "$1/.github/ISSUE_TEMPLATE/bugfix.yml"
  printf 'blank_issues_enabled: false\n' > "$1/.github/ISSUE_TEMPLATE/config.yml"
  printf '## 이슈\n\nCloses #\n' > "$1/.github/PULL_REQUEST_TEMPLATE/feature.md"
  printf '## 이슈\n\nFixes #\n' > "$1/.github/PULL_REQUEST_TEMPLATE/bugfix.md"
}

echo "== A. 템플릿 (W-01 · W-02) =="

tc TC-W01 "이 저장소의 템플릿이 통과한다"
run "$V" --templates "$REPO_ROOT"; expect_code 0

tc TC-W02 "규칙을 지킨 템플릿은 조용히 통과한다"
R="$TMP/t1"; tpl "$R"; run "$V" --templates "$R"; expect_code 0; expect_no_out

tc TC-W03 "feature.yml 이 없으면 막는다 (W-01)"
R="$TMP/t2"; tpl "$R"; rm "$R/.github/ISSUE_TEMPLATE/feature.yml"
run "$V" --templates "$R"; expect_code 2; expect_out "feature.yml 이 없습니다"

tc TC-W04 "이슈 폼 라벨이 타입과 다르면 막는다 (W-01)"
R="$TMP/t3"; tpl "$R"; sed -i '' 's/"bugfix"/"bug"/' "$R/.github/ISSUE_TEMPLATE/bugfix.yml"
run "$V" --templates "$R"; expect_code 2; expect_out "labels 에 'bugfix' 가 없습니다"

tc TC-W05 "labels 를 문자열로 적어도 읽는다"
R="$TMP/t4"; tpl "$R"; sed -i '' 's/labels: \["feature"\]/labels: feature/' "$R/.github/ISSUE_TEMPLATE/feature.yml"
run "$V" --templates "$R"; expect_code 0

tc TC-W06 "body 가 없는 템플릿(마크다운식)은 막는다 (W-01)"
R="$TMP/t5"; tpl "$R"; printf 'name: 피처\nlabels: ["feature"]\n' > "$R/.github/ISSUE_TEMPLATE/feature.yml"
run "$V" --templates "$R"; expect_code 2; expect_out "body 가 없습니다"

tc TC-W07 "config.yml 이 없으면 막는다 (W-01)"
R="$TMP/t6"; tpl "$R"; rm "$R/.github/ISSUE_TEMPLATE/config.yml"
run "$V" --templates "$R"; expect_code 2; expect_out "config.yml 이 없습니다"

tc TC-W08 "빈 이슈를 허용하면 막는다 (W-01)"
R="$TMP/t7"; tpl "$R"; printf 'blank_issues_enabled: true\n' > "$R/.github/ISSUE_TEMPLATE/config.yml"
run "$V" --templates "$R"; expect_code 2; expect_out "blank_issues_enabled: false"

tc TC-W09 "PR 템플릿 feature.md 가 없으면 막는다 (W-02)"
R="$TMP/t8"; tpl "$R"; rm "$R/.github/PULL_REQUEST_TEMPLATE/feature.md"
run "$V" --templates "$R"; expect_code 2; expect_out "feature.md 가 없습니다"

tc TC-W10 "feature.md 에 Closes # 가 없으면 막는다 (W-02)"
R="$TMP/t9"; tpl "$R"; printf '## 이슈\n' > "$R/.github/PULL_REQUEST_TEMPLATE/feature.md"
run "$V" --templates "$R"; expect_code 2; expect_out "'Closes #'"

tc TC-W11 "bugfix.md 에 Fixes # 가 없으면 막는다 (W-02)"
R="$TMP/t10"; tpl "$R"; printf 'Closes #\n' > "$R/.github/PULL_REQUEST_TEMPLATE/bugfix.md"
run "$V" --templates "$R"; expect_code 2; expect_out "'Fixes #'"

tc TC-W12 "단일 기본 PR 템플릿이 있으면 막는다 (W-02)"
R="$TMP/t11"; tpl "$R"; : > "$R/.github/pull_request_template.md"
run "$V" --templates "$R"; expect_code 2; expect_out "단일 기본 PR 템플릿"

echo "== B. 브랜치 이름 (W-03 · W-04) =="

tc TC-W20 "feature/{번호}-{slug} 는 통과한다"
run "$V" --branch feature/12-order-sync; expect_code 0

tc TC-W21 "bugfix/{번호}-{한 단어} 는 통과한다"
run "$V" --branch bugfix/3-sync; expect_code 0

tc TC-W22 "이슈 번호가 없으면 막는다"
run "$V" --branch feature/plugin-creater-setting; expect_code 2; expect_out "(W-03)"

tc TC-W23 "develop 을 막는다"
run "$V" --branch develop; expect_code 2

tc TC-W24 "대문자를 막는다"
run "$V" --branch feature/12-Order; expect_code 2

tc TC-W25 "slug 여섯 단어를 막는다"
run "$V" --branch feature/12-a-b-c-d-e-f; expect_code 2

tc TC-W26 "slug 다섯 단어는 통과한다"
run "$V" --branch feature/12-a-b-c-d-e; expect_code 0

tc TC-W27 "hotfix/ 같은 다른 타입을 막는다"
run "$V" --branch hotfix/12-x; expect_code 2

mkrepo br

tc TC-W28 "훅: git checkout -b 잘못된 이름을 막는다"
HOOK "git checkout -b my-feature"; expect_code 2; expect_out "(W-03)"

tc TC-W29 "훅: git switch -c 올바른 이름은 통과한다"
HOOK "git switch -c feature/7-order-sync"; expect_code 0

tc TC-W30 "훅: git worktree add -b 잘못된 이름을 막는다"
HOOK "git worktree add -b wip .claude/worktrees/wip origin/main"; expect_code 2; expect_out "(W-03)"

tc TC-W31 "훅: git branch 새 이름을 검사한다"
HOOK "git branch develop"; expect_code 2

tc TC-W32 "훅: git branch 목록 · 삭제는 통과한다"
HOOK "git branch -d feature/7-order-sync"; expect_code 0
HOOK "git branch"; expect_code 0

tc TC-W33 "훅: git branch -m 새 이름을 검사한다"
HOOK "git branch -m old-name wip"; expect_code 2

tc TC-W34 "훅: 기존 브랜치로 checkout 은 통과한다"
HOOK "git checkout main"; expect_code 0

tc TC-W35 "훅: 저장소 밖 워크트리는 알리기만 한다 (W-04)"
HOOK "git worktree add -b feature/7-x ../elsewhere origin/main"; expect_code 0; expect_out "additionalContext"; expect_out "(W-04)"

tc TC-W36 "훅: .claude/worktrees/ 워크트리는 조용하다"
HOOK "git worktree add -b feature/7-x .claude/worktrees/7-x origin/main"; expect_code 0; expect_no_out

echo "== C. main 보호 (W-08 · W-09) =="

mkrepo mn   # main 에 있다

tc TC-W40 "main 에서 git commit 을 막는다"
HOOK "git commit -m x"; expect_code 2; expect_out "main 에 직접 커밋하지 않습니다"

tc TC-W41 "main 에서 git merge 를 막는다"
HOOK "git merge feature/7-x"; expect_code 2; expect_out "(W-09)"

tc TC-W42 "main 에서 --ff-only 는 통과한다"
HOOK "git merge --ff-only origin/main"; expect_code 0
HOOK "git pull --ff-only"; expect_code 0

tc TC-W43 "main 에서 refspec 없는 git push 를 막는다"
HOOK "git push"; expect_code 2; expect_out "main 에서 git push 하지 않습니다"

tc TC-W44 "main 에서 태그만 푸시하는 것은 통과한다"
HOOK "git push origin --tags"; expect_code 0
HOOK "git push origin plugin-naming--v1.0.0"; expect_code 0

tc TC-W45 "원격 develop 을 지우는 푸시는 통과한다"
HOOK "git push origin --delete develop"; expect_code 0

mkrepo fb; on_branch feature/7-order-sync

tc TC-W46 "작업 브랜치에서 git commit 은 통과한다"
HOOK "git commit -m x"; expect_code 0

tc TC-W47 "어디서든 git push origin main 을 막는다"
HOOK "git push origin main"; expect_code 2; expect_out "main 에 직접 푸시하지 않습니다"

tc TC-W48 "HEAD:main · refs/heads/main 도 막는다"
HOOK "git push origin HEAD:main"; expect_code 2
HOOK "git push origin feature/7-order-sync:refs/heads/main"; expect_code 2

tc TC-W49 "작업 브랜치 푸시는 통과한다"
HOOK "git push -u origin feature/7-order-sync"; expect_code 0

tc TC-W50 "--force 를 막는다 (W-08)"
HOOK "git push --force origin feature/7-order-sync"; expect_code 2; expect_out "--force-with-lease"

tc TC-W51 "-f 와 -uf 를 막는다 (W-08)"
HOOK "git push -f origin feature/7-order-sync"; expect_code 2
HOOK "git push -uf origin feature/7-order-sync"; expect_code 2

tc TC-W52 "--force-with-lease 는 통과한다"
HOOK "git push --force-with-lease -u origin HEAD"; expect_code 0

tc TC-W53 "+refspec 을 막는다 (W-08)"
HOOK "git push origin +feature/7-order-sync"; expect_code 2

echo "== D. 태그 (W-10) =="

tc TC-W60 "작업 브랜치에서 git tag 를 막는다"
HOOK "git tag plugin-naming--v1.0.0"; expect_code 2; expect_out "태그는 main 에서만"

tc TC-W61 "작업 브랜치에서 태그 목록 · 삭제는 통과한다"
HOOK "git tag"; expect_code 0
HOOK "git tag -l"; expect_code 0
HOOK "git tag -d plugin-naming--v1.0.0"; expect_code 0

tc TC-W62 "main 에서 git tag 는 통과한다"
HOOK "git tag plugin-naming--v1.0.0" "$TMP/mn"; expect_code 0

tc TC-W63 "작업 브랜치에서 claude plugin tag 를 막는다"
HOOK "claude plugin tag --push"; expect_code 2; expect_out "(W-10)"

tc TC-W64 "main 에서 claude plugin tag 는 통과한다"
HOOK "claude plugin tag --push" "$TMP/mn"; expect_code 0

echo "== E. PR · 머지 (W-05 · W-06 · W-07) =="

mkrepo pr; on_branch feature/7-order-sync; commit_file f.txt f

tc TC-W70 "--fill 을 막는다 (W-05)"
HOOK "gh pr create --fill --label feature"; expect_code 2; expect_out "--fill"

tc TC-W71 "템플릿 · body-file 이 없으면 막는다 (W-05)"
HOOK "gh pr create --title x --label feature"; expect_code 2; expect_out "--template 또는 --body-file"

tc TC-W72 "라벨이 없으면 막는다 (W-05)"
HOOK "gh pr create --title x --body-file /tmp/pr.md"; expect_code 2; expect_out "--label feature 또는 --label bugfix"

tc TC-W73 "템플릿 · 라벨이 있고 최신이면 통과한다"
HOOK "gh pr create --base main --title x --label=bugfix --body-file /tmp/pr.md"; expect_code 0
HOOK "gh pr create -T feature.md -l feature"; expect_code 0

tc TC-W74 "브랜치가 최신 origin/main 을 포함하지 않으면 막는다 (W-06)"
advance_main
HOOK "gh pr create --template feature.md --label feature"; expect_code 2; expect_out "git rebase origin/main"

tc TC-W75 "리베이스하면 통과한다"
gitq "$W" fetch -q origin; gitq "$W" rebase -q origin/main
HOOK "gh pr create --template feature.md --label feature"; expect_code 0

tc TC-W76 "--web 은 검사하지 않는다"
HOOK "gh pr create --web"; expect_code 0

tc TC-W77 "스쿼시 머지를 막는다 (W-07)"
export STUB_HEAD=feature/7-order-sync
HOOK "gh pr merge 3 --squash"; expect_code 2; expect_out "스쿼시"

tc TC-W78 "리베이스 머지(-r)를 막는다 (W-07)"
HOOK "gh pr merge 3 -r"; expect_code 2; expect_out "리베이스 머지"

tc TC-W79 "머지 방식이 없으면 막는다 (W-07)"
HOOK "gh pr merge 3"; expect_code 2; expect_out "--merge 로 명시"

tc TC-W80 "PR 브랜치가 최신이면 --merge 는 통과한다"
gitq "$W" push -q -u origin feature/7-order-sync
HOOK "gh pr merge 3 --merge --delete-branch"; expect_code 0

tc TC-W81 "PR 브랜치가 오래됐으면 막는다 (W-06)"
advance_main
HOOK "gh pr merge 3 --merge"; expect_code 2; expect_out "PR 브랜치 'feature/7-order-sync' 가 최신 origin/main 을 포함하지 않습니다"

tc TC-W82 "PR 을 조회할 수 없으면 막는다 (W-06)"
export STUB_GH_FAIL=1; HOOK "gh pr merge 3 --merge"; unset STUB_GH_FAIL
expect_code 2; expect_out "gh pr view 실패"

echo "== F. 명령 파싱 =="

tc TC-W90 "cd 로 main 저장소에 들어가서 커밋하면 막는다"
HOOK "cd $TMP/mn && git commit -m x" "$TMP"; expect_code 2

tc TC-W91 "git -C 로 main 저장소를 가리키면 막는다"
HOOK "git -C $TMP/mn commit -m x" "$TMP"; expect_code 2

tc TC-W92 "앞의 환경변수 대입을 건너뛰고 git 명령을 본다"
HOOK "GIT_AUTHOR_NAME=x git commit -m y" "$TMP/mn"; expect_code 2; expect_out "(W-09)"

tc TC-W93 "; 로 이은 두 번째 명령도 본다"
HOOK "git status; git push origin main"; expect_code 2

tc TC-W94 "echo 안의 git 은 명령이 아니다"
HOOK "echo git commit" "$TMP/mn"; expect_code 0

tc TC-W95 "관심 없는 명령은 조용히 통과한다"
HOOK "ls -la"; expect_code 0; expect_no_out

tc TC-W96 "Bash 가 아닌 도구에는 반응하지 않는다"
run bash -c "printf '%s' '{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"x\"}}' | '$V'"; expect_code 0; expect_no_out

tc TC-W97 "stdin 이 비면 통과시킨다"
run bash -c "printf '' | '$V'"; expect_code 0; expect_no_out

echo "== G. branch-create =="

mkrepo sc

tc TC-W100 "branch-create 는 잘못된 이름을 거부한다"
run "$BC" feature x order-sync "$W"; expect_code 2; expect_out "(W-03)"

tc TC-W101 "branch-create 는 (받아온) origin/main 에서 브랜치와 워크트리를 만든다 — 로컬 main 이 뒤처져 있어도"
advance_main   # 원격이 앞서 나갔고 로컬은 아직 모른다
run "$BC" feature 12 order-sync "$W"; expect_code 0
[ "$TC_ON" = 1 ] && { [ "$(git -C "$W/.claude/worktrees/12-order-sync" rev-parse HEAD)" != "$(git -C "$W" rev-parse main)" ] || fail_tc "로컬 main 에서 땄다 — origin/main 을 받아와서 따야 한다"; }
[ "$TC_ON" = 1 ] && {
  [ -d "$W/.claude/worktrees/12-order-sync" ] || fail_tc "워크트리가 없다"
  [ "$(git -C "$W/.claude/worktrees/12-order-sync" rev-parse --abbrev-ref HEAD)" = "feature/12-order-sync" ] || fail_tc "브랜치가 다르다"
  [ "$(git -C "$W/.claude/worktrees/12-order-sync" rev-parse HEAD)" = "$(git -C "$W" rev-parse origin/main)" ] || fail_tc "origin/main 기준이 아니다"
}

tc TC-W102 "branch-create 는 이미 있는 워크트리를 거부한다"
run "$BC" feature 12 order-sync "$W"; expect_code 2; expect_out "이미 있다"

echo "== H. 기본 브랜치 (origin/HEAD) =="

mktrunk() { # origin 의 기본 브랜치가 trunk 인 저장소. origin/HEAD 를 받아 둔다
  O="$TMP/trunk.git"; W="$TMP/trunk"; rm -rf "$O" "$W" "$TMP/trunk-seed"
  git init -q --bare "$O"; git -C "$O" symbolic-ref HEAD refs/heads/trunk
  git init -q "$TMP/trunk-seed"; gitq "$TMP/trunk-seed" checkout -q -b trunk
  git -C "$TMP/trunk-seed" config user.email t@example.com; git -C "$TMP/trunk-seed" config user.name t
  echo a > "$TMP/trunk-seed/a.txt"; gitq "$TMP/trunk-seed" add -A; gitq "$TMP/trunk-seed" commit -qm init
  gitq "$TMP/trunk-seed" push -q "$O" trunk
  git clone -q "$O" "$W" 2>/dev/null
  git -C "$W" config user.email t@example.com; git -C "$W" config user.name t
}
mktrunk

tc TC-W140 "기본 브랜치가 trunk 면 trunk 에서 커밋을 막는다 (W-09)"
HOOK "git commit -m x"; expect_code 2; expect_out "trunk 에 직접 커밋하지"

tc TC-W141 "기본 브랜치가 trunk 면 main 이라는 이름의 작업 브랜치는 막지 않는다"
gitq "$W" checkout -q -b main; HOOK "git commit -m x"; expect_code 0; gitq "$W" checkout -q trunk

tc TC-W142 "기본 브랜치가 trunk 면 git push origin trunk 를 막는다 (W-09)"
HOOK "git push origin trunk"; expect_code 2; expect_out "(W-09)"

tc TC-W143 "기본 브랜치가 trunk 면 origin/trunk 기준으로 최신을 본다 (W-06)"
gitq "$W" checkout -q -b feature/1-x; commit_file b.txt b
run "$V" --up-to-date "$W"; expect_code 0
gitq "$W" checkout -q trunk

tc TC-W144 "branch-create 는 origin/HEAD 가 가리키는 브랜치에서 딴다"
run "$BC" feature 13 trunk-base "$W"; expect_code 0; expect_out "origin/trunk"
[ "$TC_ON" = 1 ] && { [ "$(git -C "$W/.claude/worktrees/13-trunk-base" rev-parse HEAD)" = "$(git -C "$W" rev-parse origin/trunk)" ] || fail_tc "origin/trunk 기준이 아니다"; }; true

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
printf '\n'
[ "$FAIL" = 0 ] || exit 1
