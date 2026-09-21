#!/usr/bin/env bash
# plugin-workflow 스크립트의 회귀 테스트 — validate-workflow.sh(훅 · CLI), branch-create.sh, release-plugins.sh, verify-all.sh.
# 실제 git 저장소(임시 bare origin + 클론)로 브랜치 상태를 만든다. gh · claude 는 PATH 스텁으로 대체한다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
V="$PLUGIN_ROOT/scripts/validate-workflow.sh"
BC="$PLUGIN_ROOT/scripts/branch-create.sh"
RP="$PLUGIN_ROOT/scripts/release-plugins.sh"
VA="$PLUGIN_ROOT/scripts/verify-all.sh"
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

echo "== G. 스크립트 =="

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

# 릴리즈 픽스처: main 에 플러그인 0.1.0 → 작업 브랜치에서 0.2.0 → --no-ff 머지 → origin 에 푸시
mkrel() { # $1=이름
  mkrepo "$1"; mkdir -p "$W/.claude-plugin" "$W/internal-plugins/order-sync/.claude-plugin"
  printf '{ "name": "x-marketplace" }' > "$W/.claude-plugin/marketplace.json"
  printf '{ "name": "order-sync", "version": "0.1.0" }' > "$W/internal-plugins/order-sync/.claude-plugin/plugin.json"
  printf '# CHANGELOG\n\n## 0.1.0\n\n- 첫\n' > "$W/internal-plugins/order-sync/CHANGELOG.md"
  gitq "$W" add -A; gitq "$W" commit -qm base; gitq "$W" push -q origin main
  on_branch feature/7-order-sync
  printf '{ "name": "order-sync", "version": "0.2.0" }' > "$W/internal-plugins/order-sync/.claude-plugin/plugin.json"
  printf '# CHANGELOG\n\n## 0.2.0\n\n### Added\n- 새 검사\n\n## 0.1.0\n\n- 첫\n' > "$W/internal-plugins/order-sync/CHANGELOG.md"
  gitq "$W" add -A; gitq "$W" commit -qm bump
  gitq "$W" checkout -q main; gitq "$W" merge -q --no-ff -m "Merge pull request #3" feature/7-order-sync; gitq "$W" push -q origin main
}

tc TC-W103 "release: main 이 아니면 거부한다"
mkrel rl1; gitq "$W" checkout -q feature/7-order-sync
run "$RP" --dry-run "$W"; expect_code 2; expect_out "main 에서 돌린다"

tc TC-W104 "release: 추적 중인 파일에 변경이 있으면 거부한다"
mkrel rl2; echo changed >> "$W/a.txt"
run "$RP" --dry-run "$W"; expect_code 2; expect_out "커밋하지 않은 변경"

tc TC-W114 "release: 플러그인 디렉터리의 미추적 파일은 거부한다"
mkrel rl11; echo x > "$W/internal-plugins/order-sync/stray.md"
run "$RP" --dry-run "$W"; expect_code 2; expect_out "플러그인 디렉터리가 깨끗하지 않다"

tc TC-W115 "release: 플러그인 밖 미추적 파일(.idea/ 같은)은 막지 않는다"
mkrel rl12; mkdir -p "$W/.idea"; echo x > "$W/.idea/workspace.xml"; echo x > "$W/.mcp.json"
run "$RP" --dry-run "$W"; expect_code 0; expect_out "order-sync--v0.2.0"

tc TC-W105 "release: HEAD 가 origin/main 과 다르면 거부한다"
mkrel rl3; commit_file local.txt l
run "$RP" --dry-run "$W"; expect_code 2; expect_out "git pull --ff-only"

tc TC-W106 "release: 버전이 바뀐 플러그인이 없으면 할 것이 없다"
mkrel rl4; run "$RP" --dry-run --since HEAD "$W"; expect_code 0; expect_out "릴리즈할 플러그인이 없다"

tc TC-W107 "release --dry-run: 대상을 보여주고 아무것도 하지 않는다"
mkrel rl5; : > "$CALLS"
run "$RP" --dry-run "$W"; expect_code 0; expect_out "order-sync--v0.2.0"; expect_out "아무것도 하지 않았다"
expect_nocall "plugin tag"; expect_nocall "release create"

tc TC-W108 "release: 태그를 달고 CHANGELOG 절을 노트로 릴리즈한다"
mkrel rl6; : > "$CALLS"; rm -f "$STUB_NOTES_COPY"
run "$RP" "$W"; expect_code 0; expect_out "✅ order-sync--v0.2.0"
expect_call "claude plugin tag --push"
expect_call "gh release create order-sync--v0.2.0 --verify-tag --title order-sync v0.2.0"
expect_call "--latest=false"
# 태그가 한 번도 없었으니 첫 릴리즈 — 0.1.0 절까지 담는다 (이슈 #2)
[ "$TC_ON" = 1 ] && { grep -qF "새 검사" "$STUB_NOTES_COPY" 2>/dev/null || fail_tc "노트에 0.2.0 절이 없다"; grep -qF "첫" "$STUB_NOTES_COPY" 2>/dev/null || fail_tc "첫 릴리즈인데 0.1.0 절이 빠졌다"; }

tc TC-W116 "release: 직전 태그가 있으면 그 뒤의 절만 노트에 담는다"
mkrel rl13; gitq "$W" tag order-sync--v0.1.0 main~1; gitq "$W" push -q origin order-sync--v0.1.0; rm -f "$STUB_NOTES_COPY"
run "$RP" "$W"; expect_code 0
[ "$TC_ON" = 1 ] && { grep -qF "새 검사" "$STUB_NOTES_COPY" || fail_tc "0.2.0 절이 없다"; grep -qF "첫" "$STUB_NOTES_COPY" && fail_tc "이미 릴리즈한 0.1.0 절이 들어갔다"; }; true

tc TC-W117 "release: 여러 절을 담으면 뒤 절의 제목을 남기고 첫 제목은 뺀다"
mkrel rl14; rm -f "$STUB_NOTES_COPY"; run "$RP" "$W"
[ "$TC_ON" = 1 ] && { grep -qx "## 0.1.0" "$STUB_NOTES_COPY" || fail_tc "0.1.0 제목이 없다"; grep -qx "## 0.2.0" "$STUB_NOTES_COPY" && fail_tc "첫 제목이 남았다"; }; true

tc TC-W118 "release: 날짜가 붙은 제목도 경계로 읽는다"
mkrel rl15; gitq "$W" checkout -q -b feature/9-dated
printf '# CHANGELOG\n\n## 0.3.0 - 2026-09-21\n\n- 셋째\n\n## 0.2.0 - 2026-09-18\n\n- 둘째\n\n## 0.1.0\n\n- 첫\n' > "$W/internal-plugins/order-sync/CHANGELOG.md"
printf '{ "name": "order-sync", "version": "0.3.0" }' > "$W/internal-plugins/order-sync/.claude-plugin/plugin.json"
gitq "$W" commit -qam dated; gitq "$W" checkout -q main; gitq "$W" merge -q --no-ff -m m feature/9-dated; gitq "$W" push -q origin main
gitq "$W" tag order-sync--v0.2.0 main~1; rm -f "$STUB_NOTES_COPY"
run "$RP" "$W"; expect_code 0
[ "$TC_ON" = 1 ] && { grep -qF "셋째" "$STUB_NOTES_COPY" || fail_tc "0.3.0 절이 없다"; grep -qF "둘째" "$STUB_NOTES_COPY" && fail_tc "날짜 붙은 0.2.0 경계를 못 읽었다"; }; true

tc TC-W109 "release: 설치본에 로드 에러가 있으면 거부한다 (--json 의 errors)"
mkrel rl7; printf '[{"id":"order-sync@x-marketplace","errors":["Hook load failed"]}]' > "$TMP/list.json"
STUB_LIST_JSON="$TMP/list.json" run "$RP" --dry-run "$W"; expect_code 2; expect_out "로드 실패가 있다"

tc TC-W113 "release: --json 을 못 받으면 텍스트의 Error 줄로 대신한다"
mkrel rl10; printf 'not json' > "$TMP/bad.json"; printf '  ❯ order-sync@x-marketplace\n    Error: Hook load failed\n' > "$TMP/list.txt"
STUB_LIST_JSON="$TMP/bad.json" STUB_LIST="$TMP/list.txt" run "$RP" --dry-run "$W"; expect_code 2; expect_out "로드 실패가 있다"

tc TC-W110 "release: 태그가 이미 있으면 거부한다"
mkrel rl8; gitq "$W" tag order-sync--v0.2.0
run "$RP" --dry-run "$W"; expect_code 2; expect_out "이미 있다"

tc TC-W111 "release: CHANGELOG 에 그 버전 절이 없으면 거부한다"
mkrel rl9; gitq "$W" checkout -q -b feature/8-x
printf '{ "name": "order-sync", "version": "0.3.0" }' > "$W/internal-plugins/order-sync/.claude-plugin/plugin.json"
gitq "$W" commit -qam "bump without changelog"; gitq "$W" checkout -q main; gitq "$W" merge -q --no-ff -m m feature/8-x; gitq "$W" push -q origin main
run "$RP" --dry-run "$W"; expect_code 2; expect_out "'## 0.3.0' 절이 없거나"

tc TC-W112 "verify-all: 전부 통과하면 0, 실패가 있으면 1 과 ❌ 줄"
R="$TMP/va"; rm -rf "$R"; mkdir -p "$R/internal-plugins/ok-sync/scripts" "$R/internal-plugins/ok-sync/test" "$R/.claude/hooks"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/internal-plugins/ok-sync/scripts/validate-ok.sh"
printf '#!/usr/bin/env bash\necho "통과 3 / 실패 0"\n' > "$R/internal-plugins/ok-sync/test/ok.test.sh"
chmod +x "$R/internal-plugins/ok-sync/scripts/validate-ok.sh" "$R/internal-plugins/ok-sync/test/ok.test.sh"
run "$VA" "$R"; expect_code 0; expect_out "✅ internal-plugins/ok-sync/test/ok.test.sh — 통과 3 / 실패 0"
printf '#!/usr/bin/env bash\necho "  - 무언가 틀렸다" >&2; exit 2\n' > "$R/.claude/hooks/validate-bad.sh"; chmod +x "$R/.claude/hooks/validate-bad.sh"
run "$VA" "$R"; expect_code 1; expect_out "❌ .claude/hooks/validate-bad.sh — 무언가 틀렸다"

echo "== H. eval 러너 =="

EA="$PLUGIN_ROOT/scripts/eval-all.sh"
mkevals() { # 플러그인 하나에 케이스 셋: 읽기 전용 · Write · scaffold(git)
  R="$TMP/ev-$1"; rm -rf "$R"; local p="$R/internal-plugins/order-sync"
  mkdir -p "$p/.claude-plugin" "$p/evals/read-case" "$p/evals/write-case" "$p/evals/git-case"
  printf '{"name":"order-sync"}' > "$p/.claude-plugin/plugin.json"
  printf -- '---\nallowed_tools: [Read, Skill]\n---\n\n질문\n' > "$p/evals/read-case/prompt.md"
  printf -- '---\nallowed_tools: [Write]\n---\n\n만들어\n' > "$p/evals/write-case/prompt.md"
  printf -- '---\nallowed_tools: [Write]\n---\n\n커밋해\n' > "$p/evals/git-case/prompt.md"
  printf 'schema_version: "1.1"\nname: git-case\ncontext:\n  scaffold_script: fixture.sh\n' > "$p/evals/git-case/case.yaml"
  printf '#!/usr/bin/env bash\ngit init -q .\n' > "$p/evals/git-case/fixture.sh"
}
call_of() { grep "plugin eval .*/$1/prompt.md" "$CALLS"; }

tc TC-W120 "eval-all: 케이스마다 따로 돌리고 게시하지 않는다"
mkevals a; : > "$CALLS"; run "$EA" "$R"; expect_code 0
[ "$TC_ON" = 1 ] && { [ "$(grep -c 'plugin eval' "$CALLS")" = 3 ] || fail_tc "케이스 셋을 따로 돌려야 한다"; grep 'plugin eval' "$CALLS" | grep -qv -- '--no-publish' && fail_tc "--no-publish 가 빠진 실행이 있다"; }

tc TC-W121 "eval-all: 읽기 전용 케이스에는 권한을 주지 않는다"
[ "$TC_ON" = 1 ] && { call_of read-case | grep -q -- '--allow-tools' && fail_tc "읽기 전용에 권한을 줬다"; }; true

tc TC-W122 "eval-all: Write 케이스에는 Write 만 준다"
[ "$TC_ON" = 1 ] && { call_of write-case | grep -q -- '--allow-tools Write' || fail_tc "Write 가 없다"; call_of write-case | grep -q 'Bash' && fail_tc "Bash 를 줬다"; }; true

tc TC-W123 "eval-all: git 을 쓰는 scaffold 케이스에는 Bash(git *) 와 --scaffold 를 준다"
[ "$TC_ON" = 1 ] && { call_of git-case | grep -qF 'Bash(git *)' || fail_tc "Bash(git *) 가 없다"; call_of git-case | grep -q -- '--scaffold' || fail_tc "--scaffold 가 없다"; call_of read-case | grep -q -- '--scaffold' && fail_tc "다른 케이스에 --scaffold"; }; true

tc TC-W130 "eval-all: allowed_tools 의 Bash 는 git 명령으로만 좁혀 준다"
mkevals g; printf -- '---\nallowed_tools: [Bash]\n---\n\n돌려\n' > "$R/internal-plugins/order-sync/evals/read-case/prompt.md"
: > "$CALLS"; run "$EA" "$R"
[ "$TC_ON" = 1 ] && { call_of read-case | grep -qF -- '--allow-tools Bash(git *)' || fail_tc "Bash(git *) 로 좁혀지지 않았다: $(call_of read-case)"; }; true

tc TC-W124 "eval-all: 결과를 플러그인 밖에 쓴다"
[ "$TC_ON" = 1 ] && { [ -e "$R/internal-plugins/order-sync/evals/results" ] && fail_tc "플러그인 안에 results/ 가 생겼다"; grep 'plugin eval' "$CALLS" | grep -q -- "--output-dir $R" && fail_tc "출력이 저장소 안"; }; true

tc TC-W125 "eval-all: --quick 은 1회 · 기준선 없이"
mkevals b; : > "$CALLS"; run "$EA" --quick "$R"
[ "$TC_ON" = 1 ] && { grep 'plugin eval' "$CALLS" | grep -qv -- '--runs 1 --ablation none' && fail_tc "--quick 인자가 빠졌다"; }; true

tc TC-W126 "eval-all: 기준 미달이면 ❌ 와 종료 코드 1"
mkevals c; STUB_EVAL_SCORE=0.5 run "$EA" "$R"; expect_code 1; expect_out "❌"

tc TC-W127 "eval-all: Bash 샌드박스를 못 쓰는 환경은 실패가 아니라 환경 제한이다"
mkevals d; STUB_EVAL_SCORE=0 STUB_EVAL_ERR="the Bash sandbox cannot reliably exclude it — a Bash-granting evaluation cannot run here" run "$EA" "$R"
expect_code 0; expect_out "⚠️ 환경 제한"; expect_not "❌"

tc TC-W128 "eval-all: 결과 JSON 이 없으면 실행 실패다"
mkevals e; STUB_EVAL_NOJSON=1 run "$EA" "$R"; expect_code 1; expect_out "실행 실패"

tc TC-W129 "eval-all: --plugin 으로 한 플러그인만"
mkevals f; mkdir -p "$R/internal-plugins/item-sync/.claude-plugin" "$R/internal-plugins/item-sync/evals/x"; printf '{"name":"item-sync"}' > "$R/internal-plugins/item-sync/.claude-plugin/plugin.json"
printf -- '---\n---\n\nq\n' > "$R/internal-plugins/item-sync/evals/x/prompt.md"
: > "$CALLS"; run "$EA" --plugin item-sync "$R"
[ "$TC_ON" = 1 ] && { [ "$(grep -c 'plugin eval' "$CALLS")" = 1 ] || fail_tc "item-sync 하나만 돌아야 한다"; }; true

echo "== I. 워크트리 안에서 (#3) =="

tc TC-W131 "verify-all: 루트가 .claude/worktrees/ 안이어도 플러그인을 찾는다"
R="$TMP/wtroot/.claude/worktrees/wt"; rm -rf "$TMP/wtroot"; mkdir -p "$R/internal-plugins/ok-sync/scripts" "$R/internal-plugins/ok-sync/test"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R/internal-plugins/ok-sync/scripts/validate-ok.sh"
printf '#!/usr/bin/env bash\necho "통과 1 / 실패 0"\n' > "$R/internal-plugins/ok-sync/test/ok.test.sh"
chmod +x "$R/internal-plugins/ok-sync/scripts/validate-ok.sh" "$R/internal-plugins/ok-sync/test/ok.test.sh"
run "$VA" "$R"; expect_out "internal-plugins/ok-sync/scripts/validate-ok.sh"; expect_out "internal-plugins/ok-sync/test/ok.test.sh"

tc TC-W132 "eval-all: 루트가 .claude/worktrees/ 안이어도 케이스를 찾는다"
mkdir -p "$R/internal-plugins/ok-sync/.claude-plugin" "$R/internal-plugins/ok-sync/evals/c1"; printf '{"name":"ok-sync"}' > "$R/internal-plugins/ok-sync/.claude-plugin/plugin.json"
printf -- '---\n---\n\nq\n' > "$R/internal-plugins/ok-sync/evals/c1/prompt.md"
: > "$CALLS"; run "$EA" "$R"
[ "$TC_ON" = 1 ] && { grep -q 'plugin eval .*/evals/c1/prompt.md' "$CALLS" || fail_tc "케이스를 찾지 못했다"; }; true

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
printf '\n'
[ "$FAIL" = 0 ] || exit 1
