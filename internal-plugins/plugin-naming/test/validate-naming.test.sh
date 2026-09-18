#!/usr/bin/env bash
# plugin-naming 플러그인의 scripts/validate-naming.sh 회귀 테스트.
#
#   test/validate-naming.test.sh          전체 실행
#   test/validate-naming.test.sh TC-03    ID 접두사로 필터
#   VERBOSE=1 test/validate-naming.test.sh   통과 케이스의 출력도 표시
#
# 종료 코드: 0 전체 통과 / 1 실패 있음
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-naming.sh"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
FILTER="${1:-}"
VERBOSE="${VERBOSE:-0}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/naming-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0; SKIP=0
TC_ID=""; TC_DESC=""; TC_FAILED=0
OUT=""; CODE=0

tc() {
  flush_tc
  TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  case "$TC_ID" in
    "$FILTER"*) ;;
    *) [ -n "$FILTER" ] && { TC_ID=""; SKIP=$((SKIP + 1)); } ;;
  esac
}

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_FAILED" = 0 ]; then
    PASS=$((PASS + 1))
    printf '  \033[32mPASS\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"
    [ "$VERBOSE" = 1 ] && [ -n "$OUT" ] && printf '%s\n' "$OUT" | sed 's/^/           /'
  else
    FAIL=$((FAIL + 1))
    printf '  \033[31mFAIL\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"
    printf '%s\n' "$OUT" | sed 's/^/           /'
  fi
  TC_ID=""
  return 0
}

fail_tc() { [ -n "$TC_ID" ] && { printf '           ↳ %s\n' "$1"; TC_FAILED=1; }; return 0; }

run()       { [ -n "$TC_ID" ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_stdin() { [ -n "$TC_ID" ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }

expect_code()  { [ -n "$TC_ID" ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out()   { [ -n "$TC_ID" ] || return 0; printf '%s' "$OUT" | grep -q -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_noout() { [ -n "$TC_ID" ] || return 0; printf '%s' "$OUT" | grep -q -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됨"; return 0; }
expect_empty() { [ -n "$TC_ID" ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됨"; }

section() { flush_tc; echo; echo "$1"; }

hook_json() { # $1=이벤트 $2=경로
  printf '{"hook_event_name":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" "$2"
}

[ -x "$SCRIPT" ] || { echo "실행 불가: $SCRIPT" >&2; exit 1; }

section "== A. 형식 (kebab-case) =="

tc TC-001 "kebab-case 정상 이름은 통과한다"
run "plugins/spring-naming/x.md"; expect_code 0

tc TC-002 "대문자가 섞이면 막는다"
run "plugins/Spring-Naming/x.md"; expect_code 2; expect_out "kebab-case 위반"

tc TC-003 "언더스코어를 쓰면 막는다"
run "plugins/spring_naming/x.md"; expect_code 2; expect_out "kebab-case 위반"

tc TC-004 "하이픈이 연속되면 막는다"
run "plugins/spring--naming/x.md"; expect_code 2; expect_out "kebab-case 위반"

tc TC-005 "하이픈으로 시작하면 막는다"
run "plugins/-naming/x.md"; expect_code 2; expect_out "kebab-case 위반"

tc TC-006 "하이픈으로 끝나면 막는다"
run "plugins/naming-/x.md"; expect_code 2; expect_out "kebab-case 위반"

tc TC-007 "단어에 숫자가 붙어도 통과한다"
run "plugins/svelte5-naming/x.md"; expect_code 0

section "== B. 구조 (단독 사용 금지) =="

tc TC-010 "언어명 단독은 막는다"
run "plugins/java/x.md"; expect_code 2; expect_out "한 단어 이름은 쓸 수 없습니다"

tc TC-011 "목록에 없던 프레임워크도 막는다 (하드코딩 목록 비의존 회귀)"
run "plugins/rails/x.md"; expect_code 2; expect_out "한 단어 이름은 쓸 수 없습니다"

tc TC-012 "처음 보는 단어도 한 단어면 막는다"
run "plugins/foobarbaz/x.md"; expect_code 2; expect_out "한 단어 이름은 쓸 수 없습니다"

tc TC-013 "범용 단어 단독은 막는다"
run "plugins/helpers/x.md"; expect_code 2; expect_out "한 단어 이름은 쓸 수 없습니다"

tc TC-014 "한 단어 스킬명도 막는다"
run ".claude/skills/coverage/SKILL.md"; expect_code 2; expect_out "skill 'coverage'"

tc TC-015 "한 단어 에이전트명도 막는다"
run ".claude/agents/reviewer.md"; expect_code 2; expect_out "agent 'reviewer'"

tc TC-016 "한 단어 커맨드명도 막는다"
run ".claude/commands/review.md"; expect_code 2; expect_out "command 'review'"

tc TC-017 "common-{관심사} 는 통과한다"
run "plugins/common-test/x.md"; expect_code 0

tc TC-018 "{역할}-standard 는 통과한다"
run "plugins/backend-standard/x.md"; expect_code 0

tc TC-019 "세 슬롯 이름도 통과한다"
run "plugins/git-branch-naming/x.md"; expect_code 0

section "== C. 맥락 중복 =="

tc TC-020 "인접한 단어 중복을 막는다"
run "plugins/spring-spring-boot-naming/x.md"; expect_code 2; expect_out "맥락 중복"

tc TC-021 "떨어져 있는 단어 중복도 막는다"
run "plugins/naming-plugin-naming/x.md"; expect_code 2; expect_out "맥락 중복"

tc TC-022 "다른 단어끼리는 중복으로 보지 않는다"
run "plugins/notion-document-sync/x.md"; expect_code 0

section "== D. glossary deny =="

tc TC-030 "deny 단어를 구성 단어로 쓰면 막고 use 를 알려준다"
run "plugins/doc-sync/x.md"; expect_code 2; expect_out "'document' 를 쓰세요"

tc TC-031 "다른 카테고리의 deny 도 막는다"
run "plugins/common-repo/x.md"; expect_code 2; expect_out "'repository' 를 쓰세요"

tc TC-032 "action 카테고리 deny 를 막는다"
run "plugins/config-check/x.md"; expect_code 2; expect_out "'validate' 를 쓰세요"

tc TC-033 "여러 단어로 된 deny 는 이름 전체와 대조해 막는다"
run "plugins/continuous-integration/x.md"; expect_code 2; expect_out "'ci' 를 쓰세요"

tc TC-034 "use 단어로 바꾸면 통과한다"
run "plugins/document-sync/x.md"; expect_code 0

tc TC-035 "위반이 여러 개면 모두 보고한다"
run "plugins/doc-repo/x.md"; expect_code 2; expect_out "'document' 를 쓰세요"; expect_out "'repository' 를 쓰세요"

section "== E. 줄임말 =="

tc TC-040 "등록되지 않은 3자 이하 단어는 경고하되 막지는 않는다"
run "plugins/abc-naming/x.md"; expect_code 0; expect_out "줄임말이면 사용 금지"

tc TC-041 "glossary 에 등록된 공식 약어는 경고하지 않는다"
run "plugins/k8s-naming/x.md"; expect_code 0; expect_noout "줄임말이면 사용 금지"

tc TC-042 "use 로 등록된 짧은 단어는 경고하지 않는다"
run "plugins/git-branch-naming/x.md"; expect_code 0; expect_noout "줄임말이면 사용 금지"

tc TC-043 "네 글자 이상은 경고 대상이 아니다"
run "plugins/notion-sync/x.md"; expect_code 0; expect_noout "줄임말이면 사용 금지"

section "== F. 경로 분류 =="

tc TC-050 "plugins/<이름> 을 플러그인으로 인식한다"
run "/any/where/plugins/java/.claude-plugin/plugin.json"; expect_code 2; expect_out "plugin 'java'"

tc TC-050b "public-plugins/ internal-plugins/ 처럼 접두사가 붙어도 인식한다"
run "/any/where/public-plugins/java/.claude-plugin/plugin.json"; expect_code 2; expect_out "plugin 'java'"
run "/any/where/internal-plugins/java/.claude-plugin/plugin.json"; expect_code 2; expect_out "plugin 'java'"

tc TC-050c "임의의 *-plugins 디렉터리도 인식한다"
run "/any/where/my-own-plugins/java/.claude-plugin/plugin.json"; expect_code 2; expect_out "plugin 'java'"

tc TC-050d "이름에 plugins 가 들어간 무관한 경로는 건드리지 않는다"
run "/any/where/src/plugins-manager/App.java"; expect_code 0; expect_empty

tc TC-051 "skills/<이름> 을 스킬로 인식한다"
run "/any/where/skills/utils/SKILL.md"; expect_code 2; expect_out "skill 'utils'"

tc TC-052 "commands/<이름>.md 를 커맨드로 인식한다"
run "/any/where/commands/utils.md"; expect_code 2; expect_out "command 'utils'"

tc TC-053 "agents/<이름>.md 를 에이전트로 인식한다"
run "/any/where/agents/utils.md"; expect_code 2; expect_out "agent 'utils'"

tc TC-054 "검사 대상이 아닌 경로는 아무 말도 하지 않는다"
run "/any/where/src/Main.java"; expect_code 0; expect_empty

tc TC-055 "한 경로에 여러 대상이 겹치면 각각 검사한다"
run "/any/where/plugins/java/skills/utils/SKILL.md"
expect_code 2; expect_out "plugin 'java'"; expect_out "skill 'utils'"

tc TC-056 "이름만 인자로 줘도 검사한다"
run "order-create"; expect_code 0

tc TC-057 "이름만 줬을 때 위반도 잡는다"
run "utils"; expect_code 2; expect_out "한 단어 이름은 쓸 수 없습니다"

section "== G. 훅 모드 (stdin JSON) =="

tc TC-060 "PreToolUse 위반이면 종료 코드 2 로 차단한다"
run_stdin "$(hook_json PreToolUse "$TMP/plugins/java/plugin.json")"; expect_code 2

tc TC-061 "PreToolUse 준수면 통과시킨다"
run_stdin "$(hook_json PreToolUse "$TMP/plugins/kotlin-naming/plugin.json")"; expect_code 0

tc TC-062 "PreToolUse 무관 파일은 통과시킨다"
run_stdin "$(hook_json PreToolUse "$TMP/README.md")"; expect_code 0; expect_empty

tc TC-063 "PostToolUse 정상 glossary 는 통과시킨다"
run_stdin "$(hook_json PostToolUse "$PLUGIN_ROOT/references/glossary.json")"; expect_code 0

tc TC-064 "PostToolUse 깨진 glossary 는 잡는다"
cat > "$TMP/glossary.json" <<'JSON'
{ "zoo": [ { "use": "Alpha", "deny": [], "meaning": "" } ] }
JSON
run_stdin "$(hook_json PostToolUse "$TMP/glossary.json")"; expect_code 2; expect_out "glossary:"

tc TC-065 "PostToolUse 무관 파일은 검사하지 않는다"
run_stdin "$(hook_json PostToolUse "$TMP/README.md")"; expect_code 0; expect_empty

tc TC-066 "stdin 이 비면 통과시킨다"
run_stdin ""; expect_code 0; expect_empty

tc TC-067 "경로가 없는 훅 입력은 통과시킨다"
run_stdin '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_code 0; expect_empty

section "== H. glossary 구조 검증 =="

tc TC-070 "현재 사전은 구조 검증을 통과한다"
run --glossary; expect_code 0

tc TC-071 "카테고리가 알파벳 순이 아니면 잡는다"
cat > "$TMP/g-order.json" <<'JSON'
{
  "zoo": [ { "use": "alpha", "deny": ["beta"], "meaning": "알파" } ],
  "action": [ { "use": "gamma", "deny": ["delta"], "meaning": "감마" } ]
}
JSON
run --glossary "$TMP/g-order.json"; expect_code 2; expect_out "카테고리를 알파벳 순으로 정렬"

tc TC-072 "카테고리 안의 use 가 정렬되지 않으면 잡는다"
cat > "$TMP/g-sort.json" <<'JSON'
{
  "action": [
    { "use": "zulu", "deny": ["zz"], "meaning": "줄루" },
    { "use": "alpha", "deny": ["aa"], "meaning": "알파" }
  ]
}
JSON
run --glossary "$TMP/g-sort.json"; expect_code 2; expect_out "use 알파벳 순으로 정렬"

tc TC-073 "use 에 대문자가 있으면 잡는다"
cat > "$TMP/g-upper.json" <<'JSON'
{ "action": [ { "use": "Alpha", "deny": ["aa"], "meaning": "알파" } ] }
JSON
run --glossary "$TMP/g-upper.json"; expect_code 2; expect_out "use 는 비어있지 않은 소문자"

tc TC-074 "deny 가 비어 있으면 잡는다"
cat > "$TMP/g-deny.json" <<'JSON'
{ "action": [ { "use": "alpha", "deny": [], "meaning": "알파" } ] }
JSON
run --glossary "$TMP/g-deny.json"; expect_code 2; expect_out "deny 는 최소 1개"

tc TC-075 "deny 에 대문자가 있으면 잡는다"
cat > "$TMP/g-denyupper.json" <<'JSON'
{ "action": [ { "use": "alpha", "deny": ["AA"], "meaning": "알파" } ] }
JSON
run --glossary "$TMP/g-denyupper.json"; expect_code 2; expect_out "소문자여야 합니다"

tc TC-076 "meaning 이 비면 잡는다"
cat > "$TMP/g-meaning.json" <<'JSON'
{ "action": [ { "use": "alpha", "deny": ["aa"], "meaning": "" } ] }
JSON
run --glossary "$TMP/g-meaning.json"; expect_code 2; expect_out "한 줄짜리 한국어 설명"

tc TC-077 "같은 단어가 여러 항목에 등록되면 잡는다"
cat > "$TMP/g-dup.json" <<'JSON'
{
  "action": [
    { "use": "alpha", "deny": ["beta"], "meaning": "알파" },
    { "use": "gamma", "deny": ["beta"], "meaning": "감마" }
  ]
}
JSON
run --glossary "$TMP/g-dup.json"; expect_code 2; expect_out "중복 등록"

tc TC-078 "use 와 deny 에 같은 단어가 있으면 잡는다"
cat > "$TMP/g-cross.json" <<'JSON'
{
  "action": [
    { "use": "alpha", "deny": ["zz"], "meaning": "알파" },
    { "use": "gamma", "deny": ["alpha"], "meaning": "감마" }
  ]
}
JSON
run --glossary "$TMP/g-cross.json"; expect_code 2; expect_out "중복 등록"

tc TC-079 "JSON 이 깨져 있으면 잡는다"
printf '{ "action": [ ' > "$TMP/g-broken.json"
run --glossary "$TMP/g-broken.json"; expect_code 2; expect_out "JSON 파싱 실패"

section "== I. 전체 검사 =="

tc TC-080 "플러그인 자신은 전체 검사를 통과한다"
run --all "$PLUGIN_ROOT"; expect_code 0

tc TC-081 "전체 검사가 plugins/ 의 위반을 찾아낸다"
rm -rf "$TMP/repo"; mkdir -p "$TMP/repo/plugins/java"
run --all "$TMP/repo"; expect_code 2; expect_out "plugin 'java'"

tc TC-082 "전체 검사가 스킬·커맨드·에이전트 위반도 찾아낸다"
rm -rf "$TMP/repo2"; mkdir -p "$TMP/repo2/.claude/skills/utils" "$TMP/repo2/.claude/commands" "$TMP/repo2/.claude/agents"
touch "$TMP/repo2/.claude/skills/utils/SKILL.md" \
      "$TMP/repo2/.claude/commands/review.md" \
      "$TMP/repo2/.claude/agents/reviewer.md"
run --all "$TMP/repo2"
expect_code 2; expect_out "skill 'utils'"; expect_out "command 'review'"; expect_out "agent 'reviewer'"

tc TC-083 "전체 검사가 사전 구조도 함께 본다"
rm -rf "$TMP/repo3"; mkdir -p "$TMP/repo3/references"
printf '{ "action": [ { "use": "Alpha", "deny": [], "meaning": "" } ] }' > "$TMP/repo3/references/glossary.json"
OUT="$(NAMING_GLOSSARY="$TMP/repo3/references/glossary.json" "$SCRIPT" --all "$TMP/repo3" 2>&1)"; CODE=$?
expect_code 2; expect_out "glossary:"

tc TC-084 "전체 검사가 접두사 붙은 *-plugins 디렉터리도 본다"
rm -rf "$TMP/repo4"; mkdir -p "$TMP/repo4/internal-plugins/utils" "$TMP/repo4/public-plugins/helpers"
run --all "$TMP/repo4"
expect_code 2; expect_out "plugin 'utils'"; expect_out "plugin 'helpers'"

section "== J. 슬롯 =="

tc TC-090 "슬롯 네 개는 통과한다"
run plugin-document-naming-review; expect_code 0

tc TC-091 "슬롯 다섯 개는 막는다"
run plugin-document-config-naming-review
expect_code 2; expect_out "{대상}-{범위}-{관심사}-{목적} 네 개까지만"

tc TC-092 "슬롯 상한 메시지가 실제 단어 수를 알려준다"
run plugin-document-config-template-naming-review
expect_code 2; expect_out "단어가 6 개입니다"

tc TC-093 "목적이 관심사보다 앞에 오면 막는다"
run review-standard
expect_code 2; expect_out "슬롯 순서 위반"; expect_out "'standard'(관심사)가 목적 뒤에"

tc TC-094 "목적이 대상보다 앞에 오면 막는다"
run glossary-update-plugin
expect_code 2; expect_out "'plugin'(대상·범위)가 목적 뒤에"

tc TC-095 "대상-관심사-목적 순서는 통과한다"
run document-naming-validate; expect_code 0

section "== K. 끝 단어 사전 강제 =="

tc TC-100 "끝 단어가 사전에 없으면 막는다"
run plugin-banana
expect_code 2; expect_out "끝 단어 'banana' 이 사전에 없습니다"

tc TC-101 "끝 단어 메시지가 glossary-update 를 안내한다"
run plugin-frobnicate; expect_code 2; expect_out "glossary-update"

tc TC-102 "끝 단어가 3자 이하면 줄임말로 안내한다"
run plugin-str; expect_code 2; expect_out "줄임말이면 전체 단어를 쓰고"

tc TC-103 "앞 단어는 사전에 없어도 통과한다 (도메인 고유명사)"
run spring-naming; expect_code 0
run notion-document-sync; expect_code 0

tc TC-104 "앞 단어의 짧은 미등록 단어는 경고만 한다"
run abc-naming; expect_code 0; expect_out "줄임말이면 사용 금지"

tc TC-105 "끝 단어가 deny 면 deny 로 안내한다"
run common-testing
expect_code 2; expect_out "deny 단어입니다"; expect_noout "끝 단어 'testing' 이 사전에 없습니다"

flush_tc

echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
echo
[ "$FAIL" = 0 ] || exit 1
