#!/usr/bin/env bash
# scripts/validate-dependency.sh 의 회귀 테스트.
# 범위 문자열 형식은 plugin-versioning(V-11)이 본다. 여기서는 관계만 본다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-dependency.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dependency-tc.XXXXXX")"
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
run_stdin() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_count() { [ "$TC_ON" = 1 ] || return 0; local n; n="$(printf '%s' "$OUT" | grep -cF -- "$1")"; [ "$n" = "$2" ] || fail_tc "'$1' 가 $n 번 (기대 $2)"; }

# --- 픽스처 -----------------------------------------------------------------
repo() { # $1=이름 → 빈 마켓플레이스 루트
  R="$TMP/$1"; rm -rf "$R"; mkdir -p "$R/.claude-plugin"
  printf '{ "name": "x-marketplace", "owner": { "name": "y" }, "plugins": [] }' > "$R/.claude-plugin/marketplace.json"
}
plug() { # $1=이름 $2=dependencies JSON(기본 []) $3=배치(기본 internal)
  local d="$R/${3:-internal}-plugins/$1"; mkdir -p "$d/.claude-plugin"
  jq -nc --arg n "$1" --argjson deps "${2:-[]}" '{name: $n, version: "0.1.0", dependencies: $deps}' > "$d/.claude-plugin/plugin.json"
}
ranges() { # $1=A 범위 $2=B 범위 — a-sync · b-sync 가 t-sync 를 각각의 범위로 선언
  plug t-sync; plug a-sync "$(jq -nc --arg v "$1" '[{name:"t-sync",version:$v}]')"; plug b-sync "$(jq -nc --arg v "$2" '[{name:"t-sync",version:$v}]')"
}
POST() { jq -nc --arg p "$1" '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'; }

echo "== A. 그래프 (D-01 · D-02 · D-03 · D-11) =="

tc TC-P01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-P02 "의존이 없는 저장소는 조용히 통과한다"
repo g1; plug a-sync; plug b-sync; run --all "$R"; expect_code 0; expect_no_out

tc TC-P03 "있는 플러그인에 대한 의존은 통과한다"
repo g2; plug a-sync '["b-sync"]'; plug b-sync; run --all "$R"; expect_code 0

tc TC-P04 "없는 플러그인에 의존하면 막는다 (D-01)"
repo g3; plug a-sync '["ghost-sync"]'; run --all "$R"; expect_code 2; expect_out "'ghost-sync' 플러그인이 이 마켓플레이스에 없습니다"

tc TC-P05 "marketplace.json 에만 있는 원격 플러그인에는 의존할 수 있다"
repo g4; plug a-sync '["far-sync"]'
jq '.plugins += [{"name":"far-sync","source":{"source":"github","repo":"o/r"}}]' "$R/.claude-plugin/marketplace.json" > "$R/m" && mv "$R/m" "$R/.claude-plugin/marketplace.json"
run --all "$R"; expect_code 0

tc TC-P06 "자기 자신에 의존하면 막는다 (D-02)"
repo g5; plug a-sync '["a-sync"]'; run --all "$R"; expect_code 2; expect_out "자기 자신에 의존합니다"

tc TC-P07 "둘 사이의 순환을 막는다 (D-03)"
repo g6; plug a-sync '["b-sync"]'; plug b-sync '["a-sync"]'; run --all "$R"
expect_code 2; expect_out "순환 의존: a-sync → b-sync → a-sync"

tc TC-P08 "셋 사이의 순환을 한 번만 보고한다 (D-03)"
repo g7; plug a-sync '["b-sync"]'; plug b-sync '["c-sync"]'; plug c-sync '["a-sync"]'; run --all "$R"
expect_code 2; expect_count "순환 의존" 1; expect_out "a-sync → b-sync → c-sync → a-sync"

tc TC-P09 "순환으로 들어가기만 하는 가지는 순환으로 보지 않는다"
plug d-sync '["c-sync"]'; run --all "$R"
expect_count "순환 의존" 1; expect_not "d-sync →"

tc TC-P10 "다이아몬드는 순환이 아니다"
repo g8; plug a-sync '["b-sync","c-sync"]'; plug b-sync '["d-sync"]'; plug c-sync '["d-sync"]'; plug d-sync
run --all "$R"; expect_code 0

tc TC-P11 "같은 이름을 두 번 선언하면 막는다 (D-11)"
repo g9; plug b-sync; plug a-sync '["b-sync","b-sync"]'; run --all "$R"; expect_code 2; expect_out "'b-sync' 를 두 번 선언했습니다"

tc TC-P12 "문자열과 객체로 섞어 두 번 선언해도 잡는다 (D-11)"
repo g10; plug b-sync; plug a-sync '["b-sync",{"name":"b-sync","version":"~1.0.0"}]'; run --all "$R"; expect_code 2; expect_out "(D-11)"

tc TC-P13 "깨진 plugin.json 을 보고한다"
repo g11; plug a-sync; printf '{ "name": ' > "$R/internal-plugins/a-sync/.claude-plugin/plugin.json"
run --all "$R"; expect_code 2; expect_out "a-sync: plugin.json 을 읽을 수 없습니다"

echo "== B. 층 (D-04 · D-05 · D-06) =="

tc TC-P20 "common 플러그인이 의존하면 막는다 (D-04)"
repo l1; plug b-sync; plug common-naming '["b-sync"]' public; run --all "$R"
expect_code 2; expect_out "common 플러그인은 어떤 플러그인에도 의존하지 않습니다"

tc TC-P21 "common 에 의존하는 것은 괜찮다"
repo l2; plug common-naming '[]' public; plug spring-naming '["common-naming"]' public; run --all "$R"; expect_code 0

tc TC-P22 "번들이 다른 번들에 의존하면 막는다 (D-05)"
repo l3; plug frontend-standard '[]' public; plug backend-standard '["frontend-standard"]' public; run --all "$R"
expect_code 2; expect_out "번들이 다른 번들 'frontend-standard' 에 의존합니다"

tc TC-P23 "번들이 일반 플러그인에 의존하는 것은 괜찮다"
repo l4; plug spring-naming '[]' public; plug backend-standard '["spring-naming"]' public; run --all "$R"; expect_code 0

tc TC-P24 "번들에 스킬이 있으면 막는다 (D-06)"
mkdir -p "$R/public-plugins/backend-standard/skills/x"; printf -- '---\n---\n' > "$R/public-plugins/backend-standard/skills/x/SKILL.md"
run --all "$R"; expect_code 2; expect_out "번들은 dependencies 만 가집니다"

tc TC-P25 "번들에 빈 디렉터리만 있으면 괜찮다"
rm -rf "$R/public-plugins/backend-standard/skills"; mkdir -p "$R/public-plugins/backend-standard/hooks"
run --all "$R"; expect_code 0

tc TC-P26 "번들이 아닌 플러그인은 구성요소를 가져도 된다"
repo l5; plug order-sync; mkdir -p "$R/internal-plugins/order-sync/hooks"; printf '{}' > "$R/internal-plugins/order-sync/hooks/hooks.json"
run --all "$R"; expect_code 0

echo "== C. 경계 (D-07 · D-08) =="

tc TC-P30 "다른 마켓플레이스 의존을 막는다 (D-07)"
repo b1; plug a-sync '[{"name":"audit-logger","marketplace":"acme-shared"}]'; run --all "$R"
expect_code 2; expect_out "다른 마켓플레이스 'acme-shared'"; expect_not "(D-01)"

tc TC-P31 "allowCrossMarketplaceDependenciesOn 을 막는다 (D-07)"
repo b2; plug a-sync
jq '.allowCrossMarketplaceDependenciesOn = ["acme-shared"]' "$R/.claude-plugin/marketplace.json" > "$R/m" && mv "$R/m" "$R/.claude-plugin/marketplace.json"
run --all "$R"; expect_code 2; expect_out "allowCrossMarketplaceDependenciesOn"

tc TC-P32 "public 이 internal 에 의존하면 막는다 (D-08)"
repo b3; plug inner-sync; plug outer-sync '["inner-sync"]' public; run --all "$R"
expect_code 2; expect_out "배포용(public) 플러그인이 내부(internal) 플러그인 'inner-sync'"

tc TC-P33 "internal 이 public 에 의존하는 것은 괜찮다"
repo b4; plug outer-sync '[]' public; plug inner-sync '["outer-sync"]'; run --all "$R"; expect_code 0

tc TC-P34 "public 끼리는 괜찮다"
repo b5; plug a-sync '[]' public; plug b-sync '["a-sync"]' public; run --all "$R"; expect_code 0

echo "== D. 범위 (D-09 · D-10) =="

tc TC-P40 "범위가 겹치면 통과한다"
repo r1; ranges '^2.0' '>=2.1'; run --all "$R"; expect_code 0

tc TC-P41 "범위가 겹치지 않으면 막고 두 선언자를 모두 보인다 (D-09)"
repo r2; ranges '~2.1' '~3.0'; run --all "$R"
expect_code 2; expect_out "'t-sync' 에 대한 버전 범위가 겹치지 않습니다"; expect_out "a-sync: ~2.1"; expect_out "b-sync: ~3.0"

tc TC-P42 "^0.x 는 MINOR 자리까지만 넓힌다"
repo r3; ranges '^0.2.3' '~0.3.0'; run --all "$R"; expect_code 2; expect_out "(D-09)"

tc TC-P43 "배타 경계와 포함 경계가 한 점에서 만나면 겹치지 않는다"
repo r4; ranges '>1.2.3' '<=1.2.3'; run --all "$R"; expect_code 2

tc TC-P44 "포함 경계끼리 한 점에서 만나면 겹친다"
repo r5; ranges '>=1.2.3' '<=1.2.3'; run --all "$R"; expect_code 0

tc TC-P53 "상한이 같고 한쪽만 배타면 겹치지 않는다"
repo r14; plug t-sync; plug a-sync '[{"name":"t-sync","version":">=1.3.0"}]'; plug b-sync '[{"name":"t-sync","version":"<1.3.0"}]'; plug c-sync '[{"name":"t-sync","version":"<=1.3.0"}]'
run --all "$R"; expect_code 2; expect_out "(D-09)"

tc TC-P54 "하한이 같고 한쪽만 배타면 겹치지 않는다"
repo r15; plug t-sync; plug a-sync '[{"name":"t-sync","version":">1.2.3"}]'; plug b-sync '[{"name":"t-sync","version":">=1.2.3"}]'; plug c-sync '[{"name":"t-sync","version":"<=1.2.3"}]'
run --all "$R"; expect_code 2; expect_out "(D-09)"

tc TC-P45 "부분 버전 '>1.2' 는 '>=1.3.0' 이다"
repo r6; ranges '>1.2' '<1.3.0'; run --all "$R"; expect_code 2

tc TC-P46 "|| 가 섞인 범위는 판정하지 않는다"
repo r7; ranges '^1.0.0 || ^2.0.0' '~3.0'; run --all "$R"; expect_code 0

tc TC-P47 "prerelease 가 섞인 범위는 판정하지 않는다"
repo r8; ranges '^2.0.0-0' '~1.0'; run --all "$R"; expect_code 0

tc TC-P48 "셋 중 하나라도 어긋나면 충돌이다"
repo r9; ranges '^1.0.0' '>=1.2.0'; plug c-sync '[{"name":"t-sync","version":"<1.1.0"}]'; run --all "$R"
expect_code 2; expect_out "c-sync: <1.1.0"

tc TC-P49 "한 곳만 범위를 두면 판정하지 않는다"
repo r10; plug t-sync; plug a-sync '[{"name":"t-sync","version":"~2.1"}]'; plug b-sync '["t-sync"]'; run --all "$R"; expect_code 0

tc TC-P50 "=x.y.z 로 고정하면 경고만 한다 (D-10)"
repo r11; plug t-sync; plug a-sync '[{"name":"t-sync","version":"=1.2.3"}]'; run --all "$R"
expect_code 0; expect_out "정확히 고정했습니다"

tc TC-P51 "연산자 없는 x.y.z 도 정확히 고정이다 (D-10)"
repo r12; plug t-sync; plug a-sync '[{"name":"t-sync","version":"1.2.3"}]'; run --all "$R"; expect_code 0; expect_out "(D-10)"

tc TC-P52 "^x.y.z 는 고정이 아니다"
repo r13; plug t-sync; plug a-sync '[{"name":"t-sync","version":"^1.2.3"}]'; run --all "$R"; expect_code 0; expect_no_out

echo "== E. 역참조 =="

tc TC-P60 "직접과 전이 역참조를 모두 보인다"
repo d1; plug c-sync; plug b-sync '["c-sync"]'; plug a-sync '["b-sync"]'; plug x-sync '[{"name":"c-sync","version":"~1.0.0"}]'
run --dependents c-sync "$R"; expect_code 0; expect_out "직접: b-sync, x-sync"; expect_out "전이 포함: a-sync, b-sync, x-sync"

tc TC-P61 "기대는 것이 없으면 없음"
run --dependents a-sync "$R"; expect_out "직접: 없음"; expect_out "전이 포함: 없음"

tc TC-P62 "--dependents 에 이름이 없으면 실행 오류다"
run --dependents; expect_code 1; expect_out "이름이 필요합니다"

tc TC-P63 "순환이 있어도 역참조가 끝난다"
repo d2; plug a-sync '["b-sync"]'; plug b-sync '["a-sync"]'
run --dependents a-sync "$R"; expect_code 0; expect_out "전이 포함: b-sync"

echo "== F. 훅 =="

tc TC-P70 "plugin.json 을 저장하면 위반을 알린다 (막지 않는다)"
repo h1; plug a-sync '["b-sync"]'; plug b-sync '["a-sync"]'
run_stdin "$(POST "$R/internal-plugins/a-sync/.claude-plugin/plugin.json")"; expect_code 0; expect_out "additionalContext"; expect_out "(D-03)"

tc TC-P71 "알림 출력이 올바른 JSON 이다"
[ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null || fail_tc "JSON 구조가 아님"; }

tc TC-P72 "알림에 AI 판단 항목이 들어 있다"
expect_out "판단할 것"

tc TC-P73 "정합하면 아무것도 내지 않는다"
repo h2; plug a-sync '["b-sync"]'; plug b-sync
run_stdin "$(POST "$R/internal-plugins/a-sync/.claude-plugin/plugin.json")"; expect_code 0; expect_no_out

tc TC-P74 "plugin.json 이 아닌 파일에는 반응하지 않는다"
repo h3; plug a-sync '["a-sync"]'
run_stdin "$(POST "$R/internal-plugins/a-sync/README.md")"; expect_code 0; expect_no_out

tc TC-P75 "PreToolUse 에는 반응하지 않는다"
run_stdin "$(jq -nc --arg p "$R/internal-plugins/a-sync/.claude-plugin/plugin.json" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p,content:"{}"}}')"
expect_code 0; expect_no_out

tc TC-P76 "stdin 이 비면 통과시킨다"
run_stdin ""; expect_code 0; expect_no_out

echo "== G. CLI =="

tc TC-P80 "플러그인 단위로 주면 그 플러그인이 선언한 것만 본다"
repo c1; plug a-sync '["ghost-sync"]'; plug b-sync '["other-ghost"]'
run "$R/internal-plugins/a-sync"; expect_code 2; expect_out "ghost-sync"; expect_not "other-ghost"

tc TC-P81 "플러그인 디렉터리가 아니면 오류를 낸다"
run "$TMP/nope"; expect_code 2; expect_out "플러그인 디렉터리가 아닙니다"

tc TC-P82 "위반 출력이 규칙 원본 경로를 알려준다"
repo c2; plug a-sync '["a-sync"]'; run --all "$R"; expect_out "dependency-rules.md"

tc TC-P83 "경고만 있으면 종료 코드 0 이다"
repo c3; plug t-sync; plug a-sync '[{"name":"t-sync","version":"=1.0.0"}]'; run --all "$R"; expect_code 0; expect_out "⚠️"

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
printf '\n'
[ "$FAIL" = 0 ] || exit 1
