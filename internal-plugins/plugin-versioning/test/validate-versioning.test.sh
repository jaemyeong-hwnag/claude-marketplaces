#!/usr/bin/env bash
# scripts/validate-versioning.sh 의 회귀 테스트.
# 이름은 plugin-naming, 디렉터리 구조는 marketplace-directory-structure,
# 배치·배포는 저장소 test/ 가 본다. 여기서는 버전만 본다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-versioning.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/versioning-tc.XXXXXX")"
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

# --- 픽스처 -----------------------------------------------------------------
# $1=버전 $2=CHANGELOG 본문 → 플러그인 경로. *-plugins/ 아래 실제 배치를 따른다.
make_plugin() {
  local d="$TMP/internal-plugins/order-sync"
  rm -rf "$d"; mkdir -p "$d/.claude-plugin"
  printf '{ "name": "order-sync", "version": %s }' "${1:-\"0.1.0\"}" > "$d/.claude-plugin/plugin.json"
  printf '%s' "${2-$'# CHANGELOG\n\n## 0.1.0\n\n- 첫 릴리즈\n'}" > "$d/CHANGELOG.md"
  printf '%s' "$d"
}
# raw plugin.json 본문을 직접 넣는다
make_plugin_raw() {
  local d="$TMP/internal-plugins/order-sync"
  rm -rf "$d"; mkdir -p "$d/.claude-plugin"
  printf '%s' "$1" > "$d/.claude-plugin/plugin.json"
  printf '%s' "${2-$'# CHANGELOG\n\n## 0.1.0\n'}" > "$d/CHANGELOG.md"
  printf '%s' "$d"
}
# $1=루트이름 $2=marketplace.json 본문 → 루트 경로
make_root() {
  local r="$TMP/$1"
  rm -rf "$r"; mkdir -p "$r/.claude-plugin"
  printf '%s' "$2" > "$r/.claude-plugin/marketplace.json"
  printf '%s' "$r"
}
# $1=루트 $2=플러그인명 $3=버전
put_plugin() {
  local d="$1/internal-plugins/$2"
  mkdir -p "$d/.claude-plugin"
  printf '{ "name": "%s", "version": "%s" }' "$2" "$3" > "$d/.claude-plugin/plugin.json"
  printf '# CHANGELOG\n\n## %s\n' "$3" > "$d/CHANGELOG.md"
}
# 태그 검사용 git 저장소. $1=이름 $2=플러그인 버전 → 루트 경로
make_git_root() {
  local r="$TMP/$1"
  rm -rf "$r"; mkdir -p "$r"
  git -C "$r" init -q 2>/dev/null
  git -C "$r" config user.email tc@example.com
  git -C "$r" config user.name tc
  mkdir -p "$r/.claude-plugin"
  printf '{ "name": "x-marketplace", "owner": { "name": "y" }, "plugins": [] }' > "$r/.claude-plugin/marketplace.json"
  put_plugin "$r" order-sync "$2"
  git -C "$r" add -A >/dev/null 2>&1
  git -C "$r" commit -qm init >/dev/null 2>&1
  printf '%s' "$r"
}
PRE_JSON() { # $1=경로 $2=content
  jq -nc --arg p "$1" --arg c "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p,content:$c}}'
}
PRE_EDIT_JSON() { # $1=경로 $2=new_string
  jq -nc --arg p "$1" --arg s "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p,old_string:"x",new_string:$s}}'
}
POST_JSON() { # $1=경로
  jq -nc --arg p "$1" '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'
}

echo "== A. 버전 값 (V-01 ~ V-03) =="

tc TC-V01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0; expect_no_out

tc TC-V02 "정상 버전은 통과한다"
run "$(make_plugin '"0.1.0"')"; expect_code 0; expect_no_out

tc TC-V03 "두 자리 버전을 막는다"
run "$(make_plugin '"1.0"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "MAJOR.MINOR.PATCH 형식이 아닙니다"; expect_out "(V-01)"

tc TC-V04 "네 자리 버전을 막는다"
run "$(make_plugin '"1.0.0.0"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "(V-01)"

tc TC-V05 "v 접두사를 막는다"
run "$(make_plugin '"v1.0.0"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "version 'v1.0.0'"; expect_out "(V-01)"

tc TC-V06 "prerelease 접미사를 막는다"
run "$(make_plugin '"1.0.0-rc.1"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "(V-01)"

tc TC-V07 "build 접미사를 막는다"
run "$(make_plugin '"1.0.0+20260921"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "(V-01)"

tc TC-V08 "선행 0 을 막는다"
run "$(make_plugin '"01.0.0"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "(V-01)"

tc TC-V09 "가운데 자리의 선행 0 도 막는다"
run "$(make_plugin '"1.00.0"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "(V-01)"

tc TC-V10 "숫자가 아닌 버전을 막는다"
run "$(make_plugin '"alpha"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 2; expect_out "(V-01)"

tc TC-V11 "version 이 없으면 막는다 (V-02)"
run "$(make_plugin_raw '{ "name": "order-sync" }')"
expect_code 2; expect_out "version 이 없습니다"; expect_out "(V-02)"

tc TC-V12 "version 이 빈 문자열이면 막는다 (V-02)"
run "$(make_plugin '""')"
expect_code 2; expect_out "(V-02)"

tc TC-V13 "0.0.x 를 막는다 (V-03)"
run "$(make_plugin '"0.0.1"' $'# CHANGELOG\n\n## 0.0.1\n')"
expect_code 2; expect_out "0.1.0 부터 시작합니다"; expect_out "(V-03)"

tc TC-V14 "0.0.0 도 막는다 (V-03)"
run "$(make_plugin '"0.0.0"' $'# CHANGELOG\n\n## 0.0.0\n')"
expect_code 2; expect_out "(V-03)"

tc TC-V15 "0.1.0 은 통과한다 (V-03 과잉 차단 방지)"
run "$(make_plugin '"0.1.0"')"; expect_code 0

tc TC-V16 "두 자리 이상 숫자를 허용한다"
run "$(make_plugin '"10.20.30"' $'# CHANGELOG\n\n## 10.20.30\n')"
expect_code 0

tc TC-V17 "0 자리 자체는 허용한다"
run "$(make_plugin '"1.0.0"' $'# CHANGELOG\n\n## 1.0.0\n')"
expect_code 0

echo "== B. CHANGELOG (V-04 ~ V-08) =="

tc TC-V20 "첫 줄이 # CHANGELOG 가 아니면 막는다 (V-04)"
run "$(make_plugin '"0.1.0"' $'# 변경 이력\n\n## 0.1.0\n')"
expect_code 2; expect_out "첫 줄은 '# CHANGELOG'"; expect_out "(V-04)"

tc TC-V21 "첫 줄 앞의 빈 줄은 무시한다 (V-04 과잉 차단 방지)"
run "$(make_plugin '"0.1.0"' $'\n\n# CHANGELOG\n\n## 0.1.0\n')"
expect_code 0

tc TC-V22 "CHANGELOG.md 가 없으면 막는다"
P="$(make_plugin '"0.1.0"')"; rm -f "$P/CHANGELOG.md"
run "$P"; expect_code 2; expect_out "CHANGELOG.md 를 읽을 수 없습니다"

tc TC-V23 "항목이 하나도 없으면 막는다 (V-05)"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n아직 없음\n')"
expect_code 2; expect_out "항목이 하나도 없습니다"; expect_out "(V-05)"

tc TC-V24 "대괄호 형식 제목을 막는다 (V-05)"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## [0.1.0]\n')"
expect_code 2; expect_out "(V-05)"

tc TC-V25 "영문 Unreleased 를 막는다 (V-05)"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## Unreleased\n\n## 0.1.0\n')"
expect_code 2; expect_out "(V-05)"

tc TC-V26 "미출시 는 맨 위에서 허용한다 (V-05 과잉 차단 방지)"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## 미출시\n\n- 예정\n\n## 0.1.0\n')"
expect_code 0

tc TC-V27 "미출시 가 중간에 있으면 막는다 (V-07)"
run "$(make_plugin '"0.2.0"' $'# CHANGELOG\n\n## 0.2.0\n\n## 미출시\n\n## 0.1.0\n')"
expect_code 2; expect_out "맨 위에만 둡니다"; expect_out "(V-07)"

tc TC-V28 "현재 버전 항목이 없으면 막는다 (V-06)"
run "$(make_plugin '"0.2.0"' $'# CHANGELOG\n\n## 0.1.0\n')"
expect_code 2; expect_out "'## 0.2.0' 항목이 없습니다"; expect_out "(V-06)"

tc TC-V29 "현재 버전 항목이 맨 아래에 있어도 통과한다 (V-06)"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## 0.3.0\n\n## 0.2.0\n\n## 0.1.0\n')"
expect_code 0

tc TC-V30 "오름차순이면 막는다 (V-07)"
run "$(make_plugin '"0.2.0"' $'# CHANGELOG\n\n## 0.1.0\n\n## 0.2.0\n')"
expect_code 2; expect_out "내림차순"; expect_out "(V-07)"

tc TC-V31 "MAJOR 자리 역전을 잡는다 (V-07)"
run "$(make_plugin '"2.0.0"' $'# CHANGELOG\n\n## 2.0.0\n\n## 10.0.0\n')"
expect_code 2; expect_out "(V-07)"

tc TC-V32 "PATCH 자리 역전을 잡는다 (V-07)"
run "$(make_plugin '"1.0.1"' $'# CHANGELOG\n\n## 1.0.1\n\n## 1.0.9\n')"
expect_code 2; expect_out "(V-07)"

tc TC-V33 "두 자리 숫자를 문자열로 비교하지 않는다 (V-07 오탐 방지)"
run "$(make_plugin '"0.10.0"' $'# CHANGELOG\n\n## 0.10.0\n\n## 0.9.0\n')"
expect_code 0

tc TC-V34 "같은 버전이 두 번 나오면 막는다 (V-08)"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## 0.1.0\n\n## 0.1.0\n')"
expect_code 2; expect_out "두 번 나옵니다"; expect_out "(V-08)"

tc TC-V35 "코드펜스 안의 ## 은 항목으로 세지 않는다"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## 0.1.0\n\n```markdown\n## 9.9.9\n```\n')"
expect_code 0

tc TC-V36 "코드펜스 안의 잘못된 제목도 무시한다"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## 0.1.0\n\n```\n## [1.0.0]\n```\n')"
expect_code 0

tc TC-V37 "### 하위 제목은 항목으로 세지 않는다"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n## 0.1.0\n\n### 추가\n\n- x\n')"
expect_code 0

tc TC-V38 "제목 뒤 공백을 다듬어 비교한다"
run "$(make_plugin '"0.1.0"' $'# CHANGELOG\n\n##   0.1.0   \n')"
expect_code 0

echo "== C. marketplace 엔트리 (V-09 ~ V-11) =="

MK_OK='{ "name": "x-marketplace", "owner": { "name": "y" }, "metadata": { "version": "0.1.0" }, "plugins": [ { "name": "order-sync", "source": "./internal-plugins/order-sync", "version": "0.2.0" } ] }'
MK_NOVER='{ "name": "x-marketplace", "owner": { "name": "y" }, "plugins": [ { "name": "order-sync", "source": "./internal-plugins/order-sync" } ] }'

tc TC-V40 "엔트리와 plugin.json 버전이 같으면 통과한다"
R="$(make_root mk1 "$MK_OK")"; put_plugin "$R" order-sync 0.2.0
run --marketplace "$R"; expect_code 0

tc TC-V41 "엔트리와 plugin.json 버전이 다르면 막는다 (V-09)"
R="$(make_root mk2 "$MK_OK")"; put_plugin "$R" order-sync 0.3.0
run --marketplace "$R"; expect_code 2; expect_out "(V-09)"; expect_out "엔트리를 고치세요"

tc TC-V42 "엔트리가 version 을 생략하면 검사하지 않는다 (V-09 과잉 차단 방지)"
R="$(make_root mk3 "$MK_NOVER")"; put_plugin "$R" order-sync 0.3.0
run --marketplace "$R"; expect_code 0

tc TC-V43 "엔트리의 version 형식도 검사한다 (V-01)"
R="$(make_root mk4 '{ "name": "x", "owner": { "name": "y" }, "plugins": [ { "name": "order-sync", "source": "./internal-plugins/order-sync", "version": "v0.2.0" } ] }')"
put_plugin "$R" order-sync 0.2.0
run --marketplace "$R"; expect_code 2; expect_out "엔트리의 version 'v0.2.0'"

tc TC-V44 "metadata.version 형식을 검사한다 (V-10)"
R="$(make_root mk5 '{ "name": "x", "owner": { "name": "y" }, "metadata": { "version": "1.0" }, "plugins": [] }')"
run --marketplace "$R"; expect_code 2; expect_out "metadata.version '1.0'"; expect_out "(V-10)"

tc TC-V45 "metadata.version 이 없으면 검사하지 않는다"
R="$(make_root mk6 '{ "name": "x", "owner": { "name": "y" }, "plugins": [] }')"
run --marketplace "$R"; expect_code 0

tc TC-V46 "marketplace.json 이 없으면 막는다"
R="$(make_root mk7 '{}')"; rm -f "$R/.claude-plugin/marketplace.json"
run --marketplace "$R"; expect_code 2; expect_out "marketplace.json 이 없습니다"

tc TC-V47 "marketplace.json 이 깨져 있으면 막는다"
R="$(make_root mk8 '{ "name": ')"
run --marketplace "$R"; expect_code 2; expect_out "JSON 파싱 실패"

tc TC-V48 "원격 소스 엔트리는 plugin.json 과 대조하지 않는다"
R="$(make_root mk9 '{ "name": "x", "owner": { "name": "y" }, "plugins": [ { "name": "far", "source": { "source": "github", "repo": "a/b" }, "version": "9.9.9" } ] }')"
run --marketplace "$R"; expect_code 0

tc TC-V50 "dependencies 의 물결 범위를 허용한다 (V-11)"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ { "name": "a-sync", "version": "~1.0.0" } ] }')"
expect_code 0

tc TC-V51 "dependencies 의 캐럿 범위를 허용한다 (V-11)"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ { "name": "a-sync", "version": "^1.2.0" } ] }')"
expect_code 0

tc TC-V52 "dependencies 의 부등호 범위를 허용한다 (V-11)"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ { "name": "a-sync", "version": ">=1.0.0 <2.0.0" } ] }')"
expect_code 0

tc TC-V53 "dependencies 의 * 를 허용한다 (V-11)"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ { "name": "a-sync", "version": "*" } ] }')"
expect_code 0

tc TC-V54 "dependencies 의 latest 를 막는다 (V-11)"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ { "name": "a-sync", "version": "latest" } ] }')"
expect_code 2; expect_out "semver 범위 문자열이 아닙니다"; expect_out "(V-11)"

tc TC-V55 "문자열만 적은 dependencies 는 검사하지 않는다 (V-11 과잉 차단 방지)"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ "a-sync" ] }')"
expect_code 0

tc TC-V56 "dependencies 에 version 이 없으면 검사하지 않는다"
run "$(make_plugin_raw '{ "name": "order-sync", "version": "0.1.0", "dependencies": [ { "name": "a-sync" } ] }')"
expect_code 0

echo "== D. 태그 (V-12 ~ V-13) =="

tc TC-V60 "형식에 맞는 태그는 통과한다"
R="$(make_git_root gt1 0.2.0)"; git -C "$R" tag order-sync--v0.1.0
run --tag "$R"; expect_code 0

tc TC-V61 "매니페스트와 같은 버전의 태그를 허용한다 (V-13)"
R="$(make_git_root gt2 0.2.0)"; git -C "$R" tag order-sync--v0.2.0
run --tag "$R"; expect_code 0

tc TC-V62 "태그가 매니페스트보다 앞서면 막는다 (V-13)"
R="$(make_git_root gt3 0.2.0)"; git -C "$R" tag order-sync--v0.3.0
run --tag "$R"; expect_code 2; expect_out "태그가 매니페스트보다 앞설 수 없습니다"; expect_out "(V-13)"

tc TC-V63 "구분자가 없는 태그를 막는다 (V-12)"
R="$(make_git_root gt4 0.2.0)"; git -C "$R" tag v0.1.0
run --tag "$R"; expect_code 2; expect_out "{플러그인명}--v{버전}"; expect_out "(V-12)"

tc TC-V64 "하이픈 하나짜리 태그를 막는다 (V-12)"
R="$(make_git_root gt5 0.2.0)"; git -C "$R" tag order-sync-v0.1.0
run --tag "$R"; expect_code 2; expect_out "(V-12)"

tc TC-V65 "태그의 버전 부분 형식을 검사한다 (V-12)"
R="$(make_git_root gt6 0.2.0)"; git -C "$R" tag order-sync--v1.0
run --tag "$R"; expect_code 2; expect_out "버전 부분 '1.0'"

tc TC-V66 "없는 플러그인의 태그를 막는다 (V-12)"
R="$(make_git_root gt7 0.2.0)"; git -C "$R" tag ghost-sync--v0.1.0
run --tag "$R"; expect_code 2; expect_out "플러그인이 없습니다"

tc TC-V67 "태그가 하나도 없으면 통과한다"
R="$(make_git_root gt8 0.2.0)"
run --tag "$R"; expect_code 0; expect_no_out

tc TC-V68 "git 저장소가 아니면 조용히 통과한다"
R="$(make_root gt9 '{ "name": "x", "owner": { "name": "y" }, "plugins": [] }')"
run --tag "$R"; expect_code 0; expect_no_out

tc TC-V69 "--all 이 태그까지 검사한다"
R="$(make_git_root gt10 0.2.0)"; git -C "$R" tag order-sync--v9.9.9
run --all "$R"; expect_code 2; expect_out "(V-13)"

echo "== E. PreToolUse 훅 (차단) =="

tc TC-V70 "plugin.json 에 0.0.x 를 쓰려 하면 차단한다"
P="$(make_plugin)/.claude-plugin/plugin.json"
run_stdin "$(PRE_JSON "$P" '{"name":"order-sync","version":"0.0.1"}')"
expect_code 2; expect_out "(V-03)"

tc TC-V71 "plugin.json 에 v 접두사를 쓰려 하면 차단한다"
run_stdin "$(PRE_JSON "$P" '{"name":"order-sync","version":"v1.0.0"}')"
expect_code 2; expect_out "(V-01)"

tc TC-V72 "정상 버전은 통과시킨다"
run_stdin "$(PRE_JSON "$P" '{"name":"order-sync","version":"0.3.0"}')"
expect_code 0; expect_no_out

tc TC-V73 "Edit 의 new_string 조각에서도 버전을 찾는다"
run_stdin "$(PRE_EDIT_JSON "$P" '  "version": "1.0",')"
expect_code 2; expect_out "(V-01)"

tc TC-V74 "Edit 의 정상 버전 조각은 통과시킨다"
run_stdin "$(PRE_EDIT_JSON "$P" '  "version": "1.2.3",')"
expect_code 0; expect_no_out

tc TC-V75 "version 이 없는 조각에는 반응하지 않는다"
run_stdin "$(PRE_EDIT_JSON "$P" '  "description": "x",')"
expect_code 0; expect_no_out

tc TC-V76 "plugin.json 이 아닌 경로에는 반응하지 않는다"
run_stdin "$(PRE_JSON "$TMP/internal-plugins/order-sync/README.md" '{"version":"0.0.1"}')"
expect_code 0; expect_no_out

tc TC-V77 "이름이 비슷한 다른 파일에는 반응하지 않는다"
run_stdin "$(PRE_JSON "$TMP/internal-plugins/order-sync/plugin.json" '{"version":"0.0.1"}')"
expect_code 0; expect_no_out

tc TC-V78 "stdin 이 비면 통과시킨다"
run_stdin ""; expect_code 0; expect_no_out

tc TC-V79 "경로가 없는 훅 입력은 통과시킨다"
run_stdin '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_code 0; expect_no_out

echo "== F. PostToolUse 훅 (알림) =="

tc TC-V80 "CHANGELOG 항목이 없으면 알린다"
P="$(make_plugin '"0.2.0"' $'# CHANGELOG\n\n## 0.1.0\n')"
run_stdin "$(POST_JSON "$P/.claude-plugin/plugin.json")"
expect_code 0; expect_out "(V-06)"; expect_out "additionalContext"

tc TC-V81 "알림은 막지 않는다 (종료 코드 0)"
expect_code 0

tc TC-V82 "알림 출력이 올바른 JSON 이다"
[ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null || fail_tc "JSON 구조가 아님"; }

tc TC-V83 "알림에 릴리즈 순서가 들어 있다"
P="$(make_plugin '"0.2.0"' $'# CHANGELOG\n\n## 0.1.0\n')"
run_stdin "$(POST_JSON "$P/.claude-plugin/plugin.json")"
expect_out "릴리즈 순서"

tc TC-V84 "CHANGELOG.md 를 저장해도 같은 검사를 한다"
run_stdin "$(POST_JSON "$P/CHANGELOG.md")"
expect_code 0; expect_out "(V-06)"

tc TC-V85 "정합하면 아무것도 내지 않는다"
P="$(make_plugin '"0.1.0"')"
run_stdin "$(POST_JSON "$P/.claude-plugin/plugin.json")"
expect_code 0; expect_no_out

tc TC-V86 "PostToolUse 는 버전 값 위반도 알림으로만 낸다"
P="$(make_plugin '"0.0.1"' $'# CHANGELOG\n\n## 0.0.1\n')"
run_stdin "$(POST_JSON "$P/.claude-plugin/plugin.json")"
expect_code 0; expect_out "(V-03)"

tc TC-V87 "무관한 경로에는 반응하지 않는다"
run_stdin "$(POST_JSON "$TMP/internal-plugins/order-sync/README.md")"
expect_code 0; expect_no_out

tc TC-V88 "CHANGELOG 가 없는 디렉터리에는 반응하지 않는다"
P="$(make_plugin)"; rm -f "$P/CHANGELOG.md"
run_stdin "$(POST_JSON "$P/.claude-plugin/plugin.json")"
expect_code 0; expect_no_out

tc TC-V89 "plugin.json 이 깨져 있으면 조용히 넘어간다"
P="$(make_plugin_raw '{ "name": ')"
run_stdin "$(POST_JSON "$P/.claude-plugin/plugin.json")"
expect_code 0; expect_no_out

echo "== G. CLI 인자 =="

tc TC-V90 "--all 이 모든 플러그인을 훑는다"
R="$(make_root all1 '{ "name": "x", "owner": { "name": "y" }, "plugins": [] }')"
put_plugin "$R" order-sync 0.1.0; put_plugin "$R" item-sync 0.0.1
run --all "$R"; expect_code 2; expect_out "item-sync"; expect_out "(V-03)"

tc TC-V91 "--all 은 정상 저장소를 조용히 통과시킨다"
R="$(make_root all2 '{ "name": "x", "owner": { "name": "y" }, "plugins": [] }')"
put_plugin "$R" order-sync 0.1.0
run --all "$R"; expect_code 0; expect_no_out

tc TC-V92 "인자 없는 --all 은 CLAUDE_PROJECT_DIR 을 쓴다"
[ "$TC_ON" = 1 ] && { OUT="$(CLAUDE_PROJECT_DIR="$REPO_ROOT" "$SCRIPT" --all 2>&1)"; CODE=$?; }
expect_code 0

tc TC-V93 "없는 디렉터리는 오류를 낸다"
run "$TMP/nope"; expect_code 2; expect_out "디렉터리가 없습니다"

tc TC-V94 "plugin.json 이 없으면 막는다"
mkdir -p "$TMP/bare"; run "$TMP/bare"
expect_code 2; expect_out "plugin.json 이 없습니다"

tc TC-V95 "plugin.json 이 깨져 있으면 막는다"
run "$(make_plugin_raw '{ "name": ')"
expect_code 2; expect_out "JSON 파싱 실패"

tc TC-V96 "여러 경로를 한 번에 받는다"
A="$(make_plugin '"0.1.0"')"
mkdir -p "$TMP/internal-plugins/item-sync/.claude-plugin"
printf '{ "name": "item-sync", "version": "0.0.5" }' > "$TMP/internal-plugins/item-sync/.claude-plugin/plugin.json"
printf '# CHANGELOG\n\n## 0.0.5\n' > "$TMP/internal-plugins/item-sync/CHANGELOG.md"
run "$A" "$TMP/internal-plugins/item-sync"
expect_code 2; expect_out "item-sync"; expect_not "order-sync:"

tc TC-V97 "끝의 슬래시를 허용한다"
run "$(make_plugin '"0.1.0"')/"; expect_code 0

tc TC-V98 "위반 출력이 규칙 원본 경로를 알려준다"
run "$(make_plugin '"0.0.1"' $'# CHANGELOG\n\n## 0.0.1\n')"
expect_out "versioning-rules.md"

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
printf '\n'
[ "$FAIL" = 0 ] || exit 1
