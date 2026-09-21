#!/usr/bin/env bash
# scripts/validate-directory-structure.sh 의 회귀 테스트.
# 이름 규칙은 plugin-naming, 배치·배포 정책은 저장소 test/ 가 본다. 여기서는 위치만 본다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-directory-structure.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/structure-tc.XXXXXX")"
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
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_hook() { # $1=file_path
  [ "$TC_ON" = 1 ] || return 0
  OUT="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" | "$SCRIPT" 2>&1)"
  CODE=$?
}
run_stdin() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

make_plugin() { # $1=이름 → 경로. *-plugins/ 아래에 두는 실제 배치를 따른다
  local d="$TMP/internal-plugins/$1"
  rm -rf "$d"; mkdir -p "$d/.claude-plugin"
  printf '{ "name": "%s", "version": "0.1.0" }' "$1" > "$d/.claude-plugin/plugin.json"
  : > "$d/README.md"; : > "$d/CHANGELOG.md"
  printf '%s' "$d"
}
make_root() { # $1=이름 → 경로
  local r="$TMP/$1"
  rm -rf "$r"; mkdir -p "$r/.claude-plugin"
  printf '{ "name": "x-marketplace", "owner": { "name": "y" }, "plugins": [] }' > "$r/.claude-plugin/marketplace.json"
  : > "$r/README.md"; : > "$r/CHANGELOG.md"; : > "$r/CLAUDE.md"
  printf '%s' "$r"
}
put_plugin() { # $1=루트 $2=상대 디렉터리 $3=이름
  local d="$1/$2/$3"
  mkdir -p "$d/.claude-plugin"
  printf '{ "name": "%s" }' "$3" > "$d/.claude-plugin/plugin.json"
  : > "$d/README.md"; : > "$d/CHANGELOG.md"
}

echo "== A. 플러그인 필수 파일 =="

tc TC-D01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-D02 "필수 세 파일을 갖춘 플러그인은 통과한다"
P="$(make_plugin order-sync)"; run "$P"; expect_code 0

tc TC-D03 "plugin.json 이 없으면 막는다"
P="$(make_plugin order-sync)"; rm -f "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "plugin.json 이 없습니다"

tc TC-D04 "README.md 가 없으면 막는다"
P="$(make_plugin order-sync)"; rm -f "$P/README.md"
run "$P"; expect_code 2; expect_out "README.md 가 없습니다"

tc TC-D05 "CHANGELOG.md 가 없으면 막는다"
P="$(make_plugin order-sync)"; rm -f "$P/CHANGELOG.md"
run "$P"; expect_code 2; expect_out "CHANGELOG.md 가 없습니다"

tc TC-D06 "plugin.json 이 깨져 있으면 막는다"
P="$(make_plugin order-sync)"; printf '{ "name": ' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "JSON 파싱 실패"

tc TC-D07 "plugin.json 의 name 이 디렉터리명과 다르면 막는다"
P="$(make_plugin order-sync)"; printf '{ "name": "order-send" }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "디렉터리명과 같아야 합니다"

tc TC-D08 "plugin.json 의 hooks 가 가리키는 파일이 없으면 막는다 (P-04)"
P="$(make_plugin order-sync)"
printf '{ "name": "order-sync", "hooks": "./hooks/extra-events.json" }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "hooks 가 가리키는"

tc TC-D09 "plugin.json 의 hooks 가 표준 경로를 가리키면 막는다 (P-09)"
P="$(make_plugin order-sync)"; mkdir -p "$P/hooks"; printf '{}' > "$P/hooks/hooks.json"
printf '{ "name": "order-sync", "version": "0.1.0", "hooks": "./hooks/hooks.json" }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "자동 로드되므로 중복"; expect_out "(P-09)"

tc TC-D09a "슬래시 접두사 없이 적어도 막는다 (P-09)"
P="$(make_plugin order-sync)"; mkdir -p "$P/hooks"; printf '{}' > "$P/hooks/hooks.json"
printf '{ "name": "order-sync", "hooks": "hooks/hooks.json" }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "(P-09)"

tc TC-D09b "배열로 적은 표준 경로도 막는다 (P-09)"
P="$(make_plugin order-sync)"; mkdir -p "$P/hooks"; printf '{}' > "$P/hooks/hooks.json"
printf '{ "name": "order-sync", "hooks": ["./hooks/hooks.json"] }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "(P-09)"

tc TC-D09c "표준 경로가 아닌 추가 훅 파일은 허용한다 (P-09 과잉 차단 방지)"
P="$(make_plugin order-sync)"; mkdir -p "$P/hooks"; printf '{}' > "$P/hooks/extra-events.json"
printf '{ "name": "order-sync", "hooks": "./hooks/extra-events.json" }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 0

tc TC-D09d "hooks 를 아예 안 적으면 통과한다 (P-09 과잉 차단 방지)"
P="$(make_plugin order-sync)"; mkdir -p "$P/hooks"; printf '{}' > "$P/hooks/hooks.json"
run "$P"; expect_code 0

tc TC-D09e "hooks 가 인라인 객체면 경로로 보지 않는다"
P="$(make_plugin order-sync)"
printf '{ "name": "order-sync", "hooks": { "PreToolUse": [] } }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 0

echo "== B. 파일 위치 =="

tc TC-D10 "플러그인 루트의 알 수 없는 파일을 막는다"
P="$(make_plugin order-sync)"; : > "$P/NOTES.md"
run "$P"; expect_code 2; expect_out "플러그인 루트에는"

tc TC-D11 "LICENSE 와 .gitignore 는 루트에 둘 수 있다"
P="$(make_plugin order-sync)"; : > "$P/LICENSE"; : > "$P/.gitignore"
run "$P"; expect_code 0

tc TC-D12 "알 수 없는 디렉터리를 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/docs"; : > "$P/docs/guide.md"
run "$P"; expect_code 2; expect_out "알 수 없는 디렉터리 'docs/'"

tc TC-D13 ".claude-plugin 에 plugin.json 외의 파일을 막는다"
P="$(make_plugin order-sync)"; : > "$P/.claude-plugin/marketplace.json"
run "$P"; expect_code 2; expect_out ".claude-plugin/ 에는 plugin.json 만"

tc TC-D14 "hooks/ 에 스크립트를 두면 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/hooks"; : > "$P/hooks/run.sh"
run "$P"; expect_code 2; expect_out "hooks/ 에는 *.json 만"

tc TC-D15 "scripts/ 에 문서를 두면 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/scripts"; : > "$P/scripts/guide.md"
run "$P"; expect_code 2; expect_out "scripts/ 에는 *.sh 만"

tc TC-D16 "commands/ 에 스크립트를 두면 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/commands"; : > "$P/commands/order-review.sh"
run "$P"; expect_code 2; expect_out "commands/ 에는 *.md 만"

tc TC-D17 "references/ 는 *.md 와 *.json 을 허용한다"
P="$(make_plugin order-sync)"; mkdir -p "$P/references"
: > "$P/references/order-rules.md"; : > "$P/references/glossary.json"
run "$P"; expect_code 0

tc TC-D18 "agents/ 에 *.md 가 아닌 파일을 두면 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/agents"; : > "$P/agents/order-reviewer.txt"
run "$P"; expect_code 2; expect_out "agents/ 에는 *.md 만"

tc TC-D19 "test/ 는 *.test.sh 와 README.md 만 허용한다"
P="$(make_plugin order-sync)"; mkdir -p "$P/test"
: > "$P/test/order-sync.test.sh"; : > "$P/test/README.md"
run "$P"; expect_code 0
: > "$P/test/fixture.json"
run "$P"; expect_code 2; expect_out "test/ 에는"

echo "== C. 스킬 디렉터리 =="

tc TC-D20 "스킬 디렉터리에 SKILL.md 가 없으면 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/skills/order-create"
run "$P"; expect_code 2; expect_out "SKILL.md 가 없습니다"

tc TC-D21 "skills/ 바로 아래 파일을 막는다"
P="$(make_plugin order-sync)"; mkdir -p "$P/skills"; : > "$P/skills/order-create.md"
run "$P"; expect_code 2; expect_out "스킬 디렉터리만 둡니다"

tc TC-D22 "스킬 디렉터리 안쪽 파일은 자유다"
P="$(make_plugin order-sync)"; mkdir -p "$P/skills/order-create/references"
: > "$P/skills/order-create/SKILL.md"; : > "$P/skills/order-create/references/sample.json"
run "$P"; expect_code 0

echo "== D. 마켓플레이스 루트 =="

tc TC-D30 "정상 루트는 통과한다"
R="$(make_root ok)"; put_plugin "$R" public-plugins order-sync; put_plugin "$R" internal-plugins document-lint
run --marketplace "$R"; expect_code 0

tc TC-D31 "marketplace.json 이 없으면 막는다"
R="$(make_root nomanifest)"; rm -f "$R/.claude-plugin/marketplace.json"
run --marketplace "$R"; expect_code 2; expect_out "marketplace.json 이 없습니다"

tc TC-D32 "루트 CHANGELOG.md 가 없으면 막는다"
R="$(make_root nochangelog)"; rm -f "$R/CHANGELOG.md"
run --marketplace "$R"; expect_code 2; expect_out "CHANGELOG.md 가 없습니다"

tc TC-D33 ".claude-plugin 의 알 수 없는 파일을 막는다"
R="$(make_root unknownfile)"; : > "$R/.claude-plugin/owners.json"
run --marketplace "$R"; expect_code 2; expect_out "알 수 없는 파일"

tc TC-D34 "tags.json · categories.json · plugins.json · keywords.json 은 허용한다"
R="$(make_root knownfiles)"
: > "$R/.claude-plugin/tags.json"; : > "$R/.claude-plugin/categories.json"
: > "$R/.claude-plugin/plugins.json"; : > "$R/.claude-plugin/keywords.json"
run --marketplace "$R"; expect_code 0

tc TC-D35 "CLAUDE.md 가 없으면 경고만 하고 막지 않는다"
R="$(make_root noclaude)"; rm -f "$R/CLAUDE.md"
run --marketplace "$R"; expect_code 0; expect_out "CLAUDE.md 가 없습니다"

tc TC-D36 "플러그인이 *-plugins 밖에 있으면 막는다"
R="$(make_root stray)"; put_plugin "$R" tools order-sync
run --marketplace "$R"; expect_code 2; expect_out "아래에 둡니다"

tc TC-D37 "플러그인이 한 단계 더 깊으면 막는다"
R="$(make_root deep)"; put_plugin "$R" internal-plugins/group order-sync
run --marketplace "$R"; expect_code 2; expect_out "바로 아래에 둡니다"

tc TC-D38 ".claude/worktrees/ 안의 플러그인은 R-04 로 보지 않는다"
R="$(make_root worktree)"; put_plugin "$R" .claude/worktrees/12-x/internal-plugins order-sync
run --marketplace "$R"; expect_code 0

tc TC-D39 "그 밖의 .claude/ 아래 플러그인은 여전히 막는다"
put_plugin "$R" .claude/misc order-sync
run --marketplace "$R"; expect_code 2; expect_out "(R-04)"

echo "== E. 훅 모드 =="

tc TC-D40 "위반 위치에 쓰려 하면 차단한다"
run_hook "$TMP/internal-plugins/order-sync/docs/guide.md"
expect_code 2; expect_out "알 수 없는 디렉터리 'docs/'"

tc TC-D41 "규칙에 맞는 위치는 통과시킨다"
run_hook "$TMP/internal-plugins/order-sync/skills/order-create/SKILL.md"
expect_code 0; expect_no_out

tc TC-D42 "플러그인 밖 경로에는 반응하지 않는다"
run_hook "$TMP/.agent-tasks/order/plan.md"
expect_code 0; expect_no_out

tc TC-D43 "*-plugins 바로 아래 파일에는 반응하지 않는다"
run_hook "$TMP/public-plugins/.gitkeep"
expect_code 0; expect_no_out

tc TC-D44 "stdin 이 비면 통과시킨다"
run_stdin ""; expect_code 0; expect_no_out

tc TC-D45 "경로가 없는 훅 입력은 통과시킨다"
run_stdin '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_code 0; expect_no_out

echo "== F. CLI 인자 =="

tc TC-D50 "파일 경로 하나만 줘도 위치를 검사한다"
run "$TMP/internal-plugins/order-sync/hooks/run.sh"
expect_code 2; expect_out "hooks/ 에는 *.json 만"

tc TC-D51 "올바른 파일 경로는 조용히 통과한다"
run "$TMP/internal-plugins/order-sync/scripts/run.sh"
expect_code 0; expect_no_out

tc TC-D52 "마켓플레이스 루트를 주면 루트와 플러그인을 함께 검사한다"
R="$(make_root full)"; put_plugin "$R" internal-plugins order-sync
rm -f "$R/internal-plugins/order-sync/CHANGELOG.md"
run "$R"; expect_code 2; expect_out "CHANGELOG.md 가 없습니다"

tc TC-D53 "플러그인도 루트도 아닌 디렉터리는 오류를 낸다"
mkdir -p "$TMP/plain"
run "$TMP/plain"; expect_code 2; expect_out "마켓플레이스 루트도 아닙니다"

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
printf '\n'
[ "$FAIL" = 0 ] || exit 1
