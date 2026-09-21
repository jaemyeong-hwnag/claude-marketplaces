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
expect_noout() { printf '%s' "$OUT" | grep -q -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됨"; return 0; }

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

echo "== 이름 중복 =="

tc TC-S11 "같은 이름이 둘이면 이름 중복으로 보고한다"
R="$(make_repo dup '{ "name": "order-sync", "source": "./public-plugins/order-sync", "category": "public" },
                    { "name": "order-sync", "source": "./internal-plugins/order-sync", "category": "internal" }')"
make_plugin "$R" public order-sync; make_plugin "$R" internal order-sync
run "$R"; expect_code 2; expect_out "이름 'order-sync' 이 둘 이상"

tc TC-S12 "중복일 때 엉뚱한 source · category 메시지를 내지 않는다"
expect_noout "source 가"; expect_noout "category 가"

echo "== 카테고리 =="

catalog() { # $1=루트 $2=파일명 $3=내용
  printf '%s' "$3" > "$1/.claude-plugin/$2"
}
CATS='[{"name":"internal","description":"내부"},{"name":"public","description":"배포"}]'

tc TC-S13 "categories.json 이 있으면 거기 있는 값만 허용한다"
R="$(make_repo cat3 '{ "name": "order-sync", "source": "./public-plugins/order-sync", "category": "public" }')"
make_plugin "$R" public order-sync; catalog "$R" categories.json '[{"name":"internal","description":"내부"}]'
run "$R"; expect_code 2; expect_out "category 'public' 가 categories.json 에 없습니다"

tc TC-S14 "categories.json 에 있으면 통과한다"
catalog "$R" categories.json "$CATS"; run "$R"; expect_code 0

tc TC-S15 "categories.json 이 정렬되지 않았으면 막는다"
catalog "$R" categories.json '[{"name":"public","description":"배포"},{"name":"internal","description":"내부"}]'
run "$R"; expect_code 2; expect_out "정렬"

tc TC-S16 "categories.json 항목에 description 이 없으면 막는다"
catalog "$R" categories.json '[{"name":"internal"},{"name":"public","description":"배포"}]'
run "$R"; expect_code 2; expect_out "description 이 필요합니다"

echo "== 태그 =="

TAGS='[{"name":"development","kind":"domain","description":"개발"},{"name":"security","kind":"domain","description":"보안"},{"name":"spring","kind":"technology","description":"Spring"}]'
tag_repo() { # $1=이름 $2=tags JSON 배열 → 루트
  local r; r="$(make_repo "$1" "{ \"name\": \"order-sync\", \"source\": \"./public-plugins/order-sync\", \"category\": \"public\", \"tags\": $2 }")"
  make_plugin "$r" public order-sync; catalog "$r" categories.json "$CATS"; catalog "$r" tags.json "$TAGS"; printf '%s' "$r"
}

tc TC-S17 "tags.json 에 있는 태그는 통과한다"
run "$(tag_repo tg1 '["development"]')"; expect_code 0

tc TC-S18 "tags.json 에 없는 태그를 막는다"
run "$(tag_repo tg2 '["springboot"]')"; expect_code 2; expect_out "tag 'springboot' 가 tags.json 에 없습니다"

tc TC-S19 "태그 3개를 막는다"
run "$(tag_repo tg3 '["development","security","spring"]')"; expect_code 2; expect_out "2개까지"

tc TC-S20 "태그 2개가 둘 다 domain 이면 막는다"
run "$(tag_repo tg4 '["development","security"]')"; expect_code 2; expect_out "domain 1 + technology 1"

tc TC-S21 "domain 1 + technology 1 은 통과한다"
run "$(tag_repo tg5 '["development","spring"]')"; expect_code 0

tc TC-S22 "tags.json 없이 tags 를 쓰면 막는다"
R="$(tag_repo tg6 '["development"]')"; rm "$R/.claude-plugin/tags.json"
run "$R"; expect_code 2; expect_out "tags.json 이 있어야"

tc TC-S23 "tags.json 의 kind 가 틀리면 막는다"
R="$(tag_repo tg7 '["development"]')"; catalog "$R" tags.json '[{"name":"development","kind":"area","description":"개발"}]'
run "$R"; expect_code 2; expect_out "kind 는 domain 또는 technology"

tc TC-S24 "tags.json 의 대문자 이름을 막는다"
R="$(tag_repo tg8 '["development"]')"; catalog "$R" tags.json '[{"name":"Spring","kind":"technology","description":"s"},{"name":"development","kind":"domain","description":"개발"}]'
run "$R"; expect_code 2; expect_out "소문자"

echo "== description · common · author =="

tc TC-S25 "엔트리 description 이 plugin.json 과 다르면 막는다"
R="$(make_repo desc '{ "name": "order-sync", "source": "./public-plugins/order-sync", "category": "public", "description": "엔트리 설명" }')"
make_plugin "$R" public order-sync; printf '{ "name": "order-sync", "description": "매니페스트 설명" }' > "$R/public-plugins/order-sync/.claude-plugin/plugin.json"
run "$R"; expect_code 2; expect_out "description 이 plugin.json 과 다릅니다"

tc TC-S26 "엔트리 description 이 같으면 통과한다"
printf '{ "name": "order-sync", "description": "엔트리 설명" }' > "$R/public-plugins/order-sync/.claude-plugin/plugin.json"
run "$R"; expect_code 0

tc TC-S27 "common 플러그인이 internal 이면 막는다"
R="$(make_repo common1 '{ "name": "common-naming", "source": "./internal-plugins/common-naming", "category": "internal" }')"
make_plugin "$R" internal common-naming
run "$R"; expect_code 2; expect_out "common 플러그인은 배포가 목적"

tc TC-S28 "common 플러그인이 public 이면 통과한다"
R="$(make_repo common2 '{ "name": "common-naming", "source": "./public-plugins/common-naming", "category": "public" }')"
make_plugin "$R" public common-naming
run "$R"; expect_code 0

tc TC-S29 "엔트리의 author 는 경고만 한다"
R="$(make_repo author '{ "name": "order-sync", "source": "./public-plugins/order-sync", "category": "public", "author": { "name": "z" } }')"
make_plugin "$R" public order-sync
run "$R"; expect_code 0; expect_out "author 는 plugin.json 에"

flush_tc
echo
printf '통과 %d / 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
