#!/usr/bin/env bash
# 저장소 배치 정책 검증기(.claude/hooks/validate-plugin-scope.sh)의 회귀 테스트.
# 이름 규칙 테스트는 internal-plugins/plugin-naming/test/ 에 따로 있다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/.claude/hooks/validate-plugin-scope.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/scope-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/           /'; fi
  TC_ID=""
}
tc() { flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0; }
fail_tc() { printf '           ↳ %s\n' "$1"; TC_FAILED=1; }
run() { OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
expect_code() { [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { printf '%s' "$OUT" | grep -q -- "$1" || fail_tc "출력에 '$1' 없음"; }

make_repo() { # $1=이름 $2=plugins 배열 내용
  local r="$TMP/$1"
  rm -rf "$r"; mkdir -p "$r/.claude-plugin"
  printf '{ "name": "x-marketplace", "owner": { "name": "y" }, "plugins": [%s] }' "$2" > "$r/.claude-plugin/marketplace.json"
  printf '%s' "$r"
}
make_plugin() { # $1=루트 $2=public|internal $3=이름
  mkdir -p "$1/$2-plugins/$3/.claude-plugin"
  printf '{ "name": "%s" }' "$3" > "$1/$2-plugins/$3/.claude-plugin/plugin.json"
}

echo "== 배치 정책 =="

tc TC-S01 "현재 저장소는 통과한다"
run "$REPO_ROOT"; expect_code 0

tc TC-S02 "배치와 선언이 맞으면 통과한다"
R="$(make_repo ok '{ "name": "order-sync", "source": "./public-plugins/order-sync", "category": "public" },
                   { "name": "document-lint", "source": "./internal-plugins/document-lint", "category": "internal" }')"
make_plugin "$R" public order-sync; make_plugin "$R" internal document-lint
run "$R"; expect_code 0

tc TC-S03 "public-plugins 인데 등록되지 않으면 막는다"
R="$(make_repo missing '')"; make_plugin "$R" public order-sync
run "$R"; expect_code 2; expect_out "등록되지 않았습니다"

tc TC-S04 "internal 플러그인이 public 으로 등록되면 막는다"
R="$(make_repo cat '{ "name": "document-lint", "source": "./internal-plugins/document-lint", "category": "public" }')"
make_plugin "$R" internal document-lint
run "$R"; expect_code 2; expect_out "category 가 'public' 입니다"

tc TC-S05 "public 플러그인이 internal 로 등록되면 막는다"
R="$(make_repo cat2 '{ "name": "order-sync", "source": "./public-plugins/order-sync", "category": "internal" }')"
make_plugin "$R" public order-sync
run "$R"; expect_code 2; expect_out "category 가 'internal' 입니다"

tc TC-S06 "source 가 실제 디렉터리와 다르면 막는다"
R="$(make_repo src '{ "name": "order-sync", "source": "./internal-plugins/order-sync", "category": "public" }')"
make_plugin "$R" public order-sync
run "$R"; expect_code 2; expect_out "source 가"

tc TC-S07 "등록됐는데 디렉터리가 없으면 막는다"
R="$(make_repo ghost '{ "name": "ghost-plugin", "source": "./public-plugins/ghost-plugin", "category": "public" }')"
run "$R"; expect_code 2; expect_out "source 경로가 없습니다"

tc TC-S08 "marketplace.json 이 없으면 검사를 건너뛴다"
rm -rf "$TMP/none"; mkdir -p "$TMP/none"
run "$TMP/none"; expect_code 0

tc TC-S09 "marketplace.json 이 깨져 있으면 막는다"
rm -rf "$TMP/broken"; mkdir -p "$TMP/broken/.claude-plugin"
printf '{ "plugins": [' > "$TMP/broken/.claude-plugin/marketplace.json"
run "$TMP/broken"; expect_code 2; expect_out "JSON 파싱 실패"

tc TC-S10 "plugin.json 이 없는 디렉터리는 플러그인으로 보지 않는다"
R="$(make_repo nomanifest '')"; mkdir -p "$R/public-plugins/scratch-dir"
run "$R"; expect_code 0

flush_tc
echo
printf '통과 %d / 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
