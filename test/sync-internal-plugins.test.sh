#!/usr/bin/env bash
# .claude/hooks/sync-internal-plugins.sh 회귀 테스트.
# 실제 claude CLI 를 호출하지 않도록 PATH 앞에 스텁을 둔다. 전역 설치 상태를 건드리지 않는다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/sync-internal-plugins.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sync-tc.XXXXXX")"
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
expect_code() { [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { printf '%s' "$OUT" | grep -q -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_noout() { printf '%s' "$OUT" | grep -q -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됨"; return 0; }
expect_call() { grep -q -- "$1" "$CALLS" || fail_tc "CLI 호출에 '$1' 없음 (실제: $(tr '\n' ';' < "$CALLS"))"; }
expect_nocall() { grep -q -- "$1" "$CALLS" && fail_tc "'$1' 가 호출되면 안 됨"; return 0; }

# claude CLI 스텁 설치
STUB_BIN="$TMP/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/claude" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_CALLS"
case "$1 $2" in
  "plugin marketplace") case "$3" in
      list) cat "$STUB_MARKETS" ;;
      add)  [ "${STUB_ADD_FAIL:-0}" = 1 ] && exit 1; exit 0 ;;
      *) exit 0 ;;
    esac ;;
  "plugin list")      if [ "${3:-}" = "--json" ]; then [ "${STUB_JSON_FAIL:-0}" = 1 ] && { echo "error: unknown option"; exit 1; }; cat "$STUB_PLUGINS"; else cat "${STUB_PLUGINS_TEXT:-/dev/null}"; fi ;;
  "plugin install")   [ "${STUB_INSTALL_FAIL:-0}" = 1 ] && exit 1; exit 0 ;;
  "plugin uninstall") exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$STUB_BIN/claude"
export PATH="$STUB_BIN:$PATH"

setup() { # $1=케이스명 → 빈 프로젝트를 만들고 전역 변수를 세팅
  P="$TMP/$1"; rm -rf "$P"; mkdir -p "$P/.claude-plugin" "$P/.claude"
  printf '{ "name": "test-marketplace", "owner": { "name": "y" }, "plugins": [] }' > "$P/.claude-plugin/marketplace.json"
  printf '{}' > "$P/.claude/settings.json"
  CALLS="$P/calls.log"; : > "$CALLS"
  export STUB_CALLS="$CALLS"
  STUB_MARKETS="$P/markets.json"; printf '[]' > "$STUB_MARKETS"; export STUB_MARKETS
  STUB_PLUGINS="$P/plugins.json"; printf '[]' > "$STUB_PLUGINS"; export STUB_PLUGINS
  STUB_PLUGINS_TEXT="$P/plugins.txt"; : > "$STUB_PLUGINS_TEXT"; export STUB_PLUGINS_TEXT
  unset STUB_ADD_FAIL STUB_INSTALL_FAIL STUB_JSON_FAIL
}
add_plugin() { # $1=프로젝트 $2=이름
  mkdir -p "$1/internal-plugins/$2/.claude-plugin"
  printf '{ "name": "%s" }' "$2" > "$1/internal-plugins/$2/.claude-plugin/plugin.json"
}
market_registered() { printf '[{"name":"test-marketplace","source":"directory"}]' > "$STUB_MARKETS"; }
market_registered_at() { # $1=설치 기준 디렉터리
  printf '[{"name":"test-marketplace","source":"directory","path":"%s"}]' "$1" > "$STUB_MARKETS"
}
register_entry() { # $1=이름 $2=category(기본 internal) $3=source 디렉터리(기본 internal-plugins)
  jq --arg n "$1" --arg c "${2:-internal}" --arg d "${3:-internal-plugins}" \
    '.plugins += [{"name":$n,"source":("./" + $d + "/" + $n),"category":$c}]' \
    "$P/.claude-plugin/marketplace.json" > "$P/m.tmp" && mv "$P/m.tmp" "$P/.claude-plugin/marketplace.json"
}
synced() { # $1=이름 — 등록·활성·설치까지 끝난 상태로 만든다 (설치본 = 작업 트리 사본)
  cp -R "$P/internal-plugins/$1" "$P/installed-$1"
  register_entry "$1"
  jq --arg id "$1@test-marketplace" '.enabledPlugins[$id] = true' "$P/.claude/settings.json" > "$P/s.tmp" && mv "$P/s.tmp" "$P/.claude/settings.json"
  jq --arg id "$1@test-marketplace" --arg p "$P/installed-$1" \
    '. + [{"id":$id,"enabled":true,"scope":"project","installPath":$p}]' "$STUB_PLUGINS" > "$P/p.tmp" && mv "$P/p.tmp" "$STUB_PLUGINS"
}
plugin_installed() { # $1=id $2=installPath
  printf '[{"id":"%s","enabled":true,"scope":"project","installPath":"%s"}]' "$1" "$2" > "$STUB_PLUGINS"
}
run_hook() { OUT="$(CLAUDE_PROJECT_DIR="$P" "$HOOK" 2>&1)"; CODE=$?; }

echo "== 내부 플러그인 동기화 =="

tc TC-Y01 "internal-plugins/ 가 없으면 조용히 끝난다"
setup no-dir; run_hook
expect_code 0; expect_out "확인할 것이 없습니다"; expect_nocall "install"

tc TC-Y02 "marketplace.json 이 없으면 끝낸다"
setup no-market; rm "$P/.claude-plugin/marketplace.json"; add_plugin "$P" order-sync; run_hook
expect_code 0; expect_out "marketplace.json 이 없습니다"

tc TC-Y03 "plugin.json 이 없는 디렉터리는 플러그인으로 세지 않는다"
setup no-manifest; mkdir -p "$P/internal-plugins/scratch-dir"; run_hook
expect_code 0; expect_out "플러그인이 없습니다"

tc TC-Y04 "마켓플레이스가 미등록이면 등록한다"
setup market-add; add_plugin "$P" order-sync; run_hook
expect_code 0; expect_call "plugin marketplace add"; expect_out "마켓플레이스 'test-marketplace' 등록"

tc TC-Y05 "settings.json 의 github repo 선언을 등록 소스로 쓴다"
setup market-github; add_plugin "$P" order-sync
printf '{"extraKnownMarketplaces":{"test-marketplace":{"source":{"source":"github","repo":"owner/repo"}}}}' > "$P/.claude/settings.json"
run_hook
expect_code 0; expect_call "marketplace add owner/repo"

tc TC-Y06 "marketplace.json 에 category internal 과 source 경로로 등록한다"
setup market-entry; add_plugin "$P" order-sync; market_registered; run_hook
expect_code 0
[ "$(jq -r '.plugins[0].category' "$P/.claude-plugin/marketplace.json")" = "internal" ] || fail_tc "category 가 internal 이 아님"
[ "$(jq -r '.plugins[0].source' "$P/.claude-plugin/marketplace.json")" = "./internal-plugins/order-sync" ] || fail_tc "source 경로가 다름"

tc TC-Y07 "settings.json 의 enabledPlugins 에 추가한다"
setup enable; add_plugin "$P" order-sync; market_registered; run_hook
expect_code 0
[ "$(jq -r '.enabledPlugins["order-sync@test-marketplace"]' "$P/.claude/settings.json")" = "true" ] || fail_tc "활성화되지 않음"

tc TC-Y08 "설치되어 있지 않으면 설치한다"
setup install; add_plugin "$P" order-sync; market_registered; run_hook
expect_code 0; expect_call "plugin install order-sync@test-marketplace -y --scope project"

tc TC-Y09 "이미 설치·동기 상태면 아무것도 바꾸지 않는다 (멱등)"
setup idem; add_plugin "$P" order-sync; market_registered
cp -R "$P/internal-plugins/order-sync" "$P/installed"
plugin_installed "order-sync@test-marketplace" "$P/installed"
jq '.plugins += [{"name":"order-sync","source":"./internal-plugins/order-sync","category":"internal"}]' \
  "$P/.claude-plugin/marketplace.json" > "$P/m.tmp" && mv "$P/m.tmp" "$P/.claude-plugin/marketplace.json"
printf '{"enabledPlugins":{"order-sync@test-marketplace":true}}' > "$P/.claude/settings.json"
run_hook
expect_code 0; expect_out "1/1 설치됨"; expect_nocall "plugin install"; expect_nocall "plugin uninstall"

tc TC-Y10 "설치본이 작업 트리와 다르면 재설치한다"
setup drift; add_plugin "$P" order-sync; market_registered
cp -R "$P/internal-plugins/order-sync" "$P/installed"
echo "낡은 내용" > "$P/installed/stale.txt"
plugin_installed "order-sync@test-marketplace" "$P/installed"
jq '.plugins += [{"name":"order-sync","source":"./internal-plugins/order-sync","category":"internal"}]' \
  "$P/.claude-plugin/marketplace.json" > "$P/m.tmp" && mv "$P/m.tmp" "$P/.claude-plugin/marketplace.json"
printf '{"enabledPlugins":{"order-sync@test-marketplace":true}}' > "$P/.claude/settings.json"
run_hook
expect_code 0; expect_out "재설치"; expect_call "plugin uninstall"; expect_call "plugin install"

tc TC-Y11 "설치에 실패해도 세션을 막지 않고 복구 명령을 알려준다"
setup fail; add_plugin "$P" order-sync; market_registered
export STUB_INSTALL_FAIL=1; run_hook; unset STUB_INSTALL_FAIL
expect_code 0; expect_out "설치 실패"; expect_out "직접 실행"

tc TC-Y12 "마켓플레이스 등록에 실패해도 세션을 막지 않는다"
setup addfail; add_plugin "$P" order-sync
export STUB_ADD_FAIL=1; run_hook; unset STUB_ADD_FAIL
expect_code 0; expect_out "등록 실패"

tc TC-Y13 "플러그인이 여럿이면 모두 처리한다"
setup many; add_plugin "$P" order-sync; add_plugin "$P" document-lint; market_registered; run_hook
expect_code 0; expect_out "2개 대상"
expect_call "plugin install order-sync@test-marketplace"
expect_call "plugin install document-lint@test-marketplace"

tc TC-Y14 "--quiet 는 변경이 없을 때 아무것도 출력하지 않는다"
setup quiet; add_plugin "$P" order-sync; market_registered
cp -R "$P/internal-plugins/order-sync" "$P/installed"
plugin_installed "order-sync@test-marketplace" "$P/installed"
jq '.plugins += [{"name":"order-sync","source":"./internal-plugins/order-sync","category":"internal"}]' \
  "$P/.claude-plugin/marketplace.json" > "$P/m.tmp" && mv "$P/m.tmp" "$P/.claude-plugin/marketplace.json"
printf '{"enabledPlugins":{"order-sync@test-marketplace":true}}' > "$P/.claude/settings.json"
OUT="$(CLAUDE_PROJECT_DIR="$P" "$HOOK" --quiet 2>&1)"; CODE=$?
expect_code 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됨: $OUT"

echo "== 끄기 · 정리 =="

tc TC-Y15 "명시적 false 는 true 로 되돌리지 않는다"
setup keep-false; add_plugin "$P" order-sync; market_registered; register_entry order-sync
printf '{"enabledPlugins":{"order-sync@test-marketplace":false}}' > "$P/.claude/settings.json"
run_hook
expect_code 0
[ "$(jq -r '.enabledPlugins["order-sync@test-marketplace"]' "$P/.claude/settings.json")" = "false" ] || fail_tc "false 가 true 로 바뀜"

tc TC-Y16 "끈 플러그인은 설치하지 않고 알린다"
expect_nocall "plugin install"; expect_out "꺼져 있다"

tc TC-Y17 "디렉터리가 사라진 internal 엔트리를 marketplace.json 에서 지운다"
setup gone; add_plugin "$P" order-sync; market_registered; synced order-sync
register_entry ghost-sync
jq '.enabledPlugins["ghost-sync@test-marketplace"] = true' "$P/.claude/settings.json" > "$P/s.tmp" && mv "$P/s.tmp" "$P/.claude/settings.json"
jq '. + [{"id":"ghost-sync@test-marketplace","enabled":true,"scope":"project","installPath":"/nowhere"}]' "$STUB_PLUGINS" > "$P/p.tmp" && mv "$P/p.tmp" "$STUB_PLUGINS"
run_hook
expect_code 0; expect_out "'ghost-sync' 제거"
jq -e 'any(.plugins[]; .name == "ghost-sync")' "$P/.claude-plugin/marketplace.json" >/dev/null && fail_tc "엔트리가 남아 있음"
jq -e 'any(.plugins[]; .name == "order-sync")' "$P/.claude-plugin/marketplace.json" >/dev/null || fail_tc "살아 있는 엔트리까지 지움"

tc TC-Y18 "사라진 플러그인의 enabledPlugins 키도 지운다"
jq -e '.enabledPlugins | has("ghost-sync@test-marketplace")' "$P/.claude/settings.json" >/dev/null && fail_tc "키가 남아 있음"
jq -e '.enabledPlugins["order-sync@test-marketplace"] == true' "$P/.claude/settings.json" >/dev/null || fail_tc "살아 있는 키까지 지움"

tc TC-Y19 "사라진 플러그인의 설치본을 --prune 으로 제거한다"
expect_call "plugin uninstall ghost-sync@test-marketplace --scope project --prune -y"

tc TC-Y20 "public 엔트리는 디렉터리가 없어도 건드리지 않는다"
setup gone-public; add_plugin "$P" order-sync; market_registered; synced order-sync
register_entry far-sync public public-plugins
run_hook
expect_code 0
jq -e 'any(.plugins[]; .name == "far-sync")' "$P/.claude-plugin/marketplace.json" >/dev/null || fail_tc "public 엔트리를 지움"
expect_nocall "uninstall far-sync"

tc TC-Y21 "플러그인이 전부 사라져도 정리는 한다"
setup all-gone; mkdir -p "$P/internal-plugins"; market_registered; register_entry ghost-sync
run_hook
expect_code 0; expect_out "'ghost-sync' 제거"
[ "$(jq '.plugins | length' "$P/.claude-plugin/marketplace.json")" = "0" ] || fail_tc "엔트리가 남음"

tc TC-Y22 "설치된 적 없는 사라진 플러그인은 uninstall 을 부르지 않는다"
expect_nocall "plugin uninstall"

echo "== 설치 기준 (워크트리) =="

tc TC-Y23 "설치 기준이 다른 디렉터리면 작업 트리 변경으로 재설치하지 않는다"
setup worktree; add_plugin "$P" order-sync
M="$TMP/worktree-main"; rm -rf "$M"; mkdir -p "$M/internal-plugins"; cp -R "$P/internal-plugins/order-sync" "$M/internal-plugins/"
market_registered_at "$M"; synced order-sync
echo "워크트리에서 고친 내용" > "$P/internal-plugins/order-sync/new-rule.md"
run_hook
expect_code 0; expect_nocall "plugin uninstall"; expect_nocall "plugin install"

tc TC-Y24 "설치 기준이 다르면 그 사실을 알린다"
OUT="$(CLAUDE_PROJECT_DIR="$P" "$HOOK" 2>&1)"
expect_out "머지 뒤 반영"

tc TC-Y25 "설치 기준에 아직 없는 플러그인은 설치하지 않고 알린다"
setup worktree-new; add_plugin "$P" order-sync; add_plugin "$P" brand-new
M="$TMP/worktree-main2"; rm -rf "$M"; mkdir -p "$M/internal-plugins"; cp -R "$P/internal-plugins/order-sync" "$M/internal-plugins/"
market_registered_at "$M"; synced order-sync
run_hook
expect_code 0; expect_nocall "install brand-new"; expect_out "'brand-new' 은 설치 기준"

tc TC-Y26 "설치 기준 쪽이 설치본과 다르면 재설치한다"
setup worktree-drift; add_plugin "$P" order-sync
M="$TMP/worktree-main3"; rm -rf "$M"; mkdir -p "$M/internal-plugins"; cp -R "$P/internal-plugins/order-sync" "$M/internal-plugins/"
market_registered_at "$M"; synced order-sync
echo "main 에 머지된 변경" > "$M/internal-plugins/order-sync/merged.md"
run_hook
expect_code 0; expect_call "plugin uninstall order-sync"; expect_call "plugin install order-sync"

tc TC-Y27 "설치 기준 경로가 이 작업 트리면 지금처럼 작업 트리와 비교한다"
setup same-path; add_plugin "$P" order-sync; market_registered_at "$P"; synced order-sync
echo "고침" > "$P/internal-plugins/order-sync/changed.md"
run_hook
expect_code 0; expect_call "plugin uninstall order-sync"; expect_noout "머지 뒤 반영"

echo "== 로드 확인 =="

plugin_error() { # $1=id $2=메시지 — 설치 목록(JSON)의 그 항목에 errors 를 단다
  jq --arg id "$1" --arg e "$2" 'map(if .id == $id then . + {errors: [$e]} else . end)' "$STUB_PLUGINS" > "$P/p.tmp" && mv "$P/p.tmp" "$STUB_PLUGINS"
}

tc TC-Y28 "claude plugin list --json 의 errors 를 로드 실패로 보고한다"
setup load-error; add_plugin "$P" order-sync; market_registered; synced order-sync
plugin_error order-sync@test-marketplace "Hook load failed: Duplicate hooks file detected"
run_hook
expect_code 0; expect_out "'order-sync@test-marketplace' 로드 실패"; expect_out "Duplicate hooks file"

tc TC-Y29 "다른 마켓플레이스 플러그인의 errors 는 무시한다"
setup load-error-other; add_plugin "$P" order-sync; market_registered; synced order-sync
jq '. + [{"id":"other@else-marketplace","enabled":true,"errors":["boom"]}]' "$STUB_PLUGINS" > "$P/p.tmp" && mv "$P/p.tmp" "$STUB_PLUGINS"
run_hook
expect_code 0; expect_noout "로드 실패"; expect_out "1/1 설치됨"

tc TC-Y30 "errors 는 그 플러그인에만 붙인다"
setup load-error-order; add_plugin "$P" order-sync; add_plugin "$P" item-sync; market_registered; synced order-sync; synced item-sync
plugin_error order-sync@test-marketplace "bad manifest"
run_hook
expect_out "'order-sync@test-marketplace' 로드 실패"; expect_noout "'item-sync@test-marketplace' 로드 실패"

tc TC-Y36 "--json 을 못 받으면 텍스트의 Error 줄로 대신한다"
setup load-error-text; add_plugin "$P" order-sync; market_registered; synced order-sync
printf '  ❯ order-sync@test-marketplace\n    Version: 0.1.0\n    Error: Hook load failed\n' > "$STUB_PLUGINS_TEXT"
export STUB_JSON_FAIL=1; run_hook; unset STUB_JSON_FAIL
expect_code 0; expect_out "'order-sync@test-marketplace' 로드 실패"; expect_out "Hook load failed"

tc TC-Y37 "텍스트로 대신할 때도 Error 는 바로 위 플러그인에 붙인다"
setup load-error-text2; add_plugin "$P" order-sync; add_plugin "$P" item-sync; market_registered; synced order-sync; synced item-sync
printf '  ❯ item-sync@test-marketplace\n    Status: enabled\n  ❯ order-sync@test-marketplace\n    Error: bad\n' > "$STUB_PLUGINS_TEXT"
export STUB_JSON_FAIL=1; run_hook; unset STUB_JSON_FAIL
expect_noout "'item-sync@test-marketplace' 로드 실패"; expect_out "'order-sync@test-marketplace' 로드 실패"

echo "== 엔트리 description =="

tc TC-Y31 "internal 엔트리 description 을 plugin.json 에 맞춘다"
setup desc-sync; add_plugin "$P" order-sync; market_registered; synced order-sync
printf '{ "name": "order-sync", "description": "새 설명" }' > "$P/internal-plugins/order-sync/.claude-plugin/plugin.json"
cp "$P/internal-plugins/order-sync/.claude-plugin/plugin.json" "$P/installed-order-sync/.claude-plugin/plugin.json"
run_hook
expect_code 0; expect_out "description 을 plugin.json 에 맞춤"
[ "$(jq -r '.plugins[] | select(.name=="order-sync") | .description' "$P/.claude-plugin/marketplace.json")" = "새 설명" ] || fail_tc "갱신되지 않음"

tc TC-Y32 "public 엔트리 description 은 건드리지 않는다"
setup desc-public; add_plugin "$P" order-sync; market_registered; synced order-sync
mkdir -p "$P/public-plugins/far-sync/.claude-plugin"; printf '{ "name": "far-sync", "description": "원본" }' > "$P/public-plugins/far-sync/.claude-plugin/plugin.json"
jq '.plugins += [{"name":"far-sync","source":"./public-plugins/far-sync","category":"public","description":"다른 설명"}]' "$P/.claude-plugin/marketplace.json" > "$P/m.tmp" && mv "$P/m.tmp" "$P/.claude-plugin/marketplace.json"
run_hook
[ "$(jq -r '.plugins[] | select(.name=="far-sync") | .description' "$P/.claude-plugin/marketplace.json")" = "다른 설명" ] || fail_tc "public 을 고침"

tc TC-Y33 "plugin.json 에 description 이 없으면 엔트리를 비우지 않는다"
setup desc-empty; add_plugin "$P" order-sync; market_registered; synced order-sync
jq '.plugins |= map(.description = "기존 설명")' "$P/.claude-plugin/marketplace.json" > "$P/m.tmp" && mv "$P/m.tmp" "$P/.claude-plugin/marketplace.json"
run_hook
[ "$(jq -r '.plugins[0].description' "$P/.claude-plugin/marketplace.json")" = "기존 설명" ] || fail_tc "비워짐"

echo "== settings.json 안정성 =="

tc TC-Y34 "enabledPlugins 키 순서를 정렬해 둔다"
setup key-order; add_plugin "$P" order-sync; add_plugin "$P" item-sync; market_registered; synced order-sync; synced item-sync
printf '{"enabledPlugins":{"order-sync@test-marketplace":true,"item-sync@test-marketplace":true}}' > "$P/.claude/settings.json"
run_hook
[ "$(jq -r '.enabledPlugins | keys_unsorted | join(",")' "$P/.claude/settings.json")" = "item-sync@test-marketplace,order-sync@test-marketplace" ] || fail_tc "정렬되지 않음"

tc TC-Y35 "이미 정렬돼 있으면 파일을 다시 쓰지 않는다"
before="$(stat -f %m "$P/.claude/settings.json" 2>/dev/null || stat -c %Y "$P/.claude/settings.json")"; sleep 1
run_hook
after="$(stat -f %m "$P/.claude/settings.json" 2>/dev/null || stat -c %Y "$P/.claude/settings.json")"
[ "$before" = "$after" ] || fail_tc "파일을 다시 썼다"

flush_tc
echo
printf '통과 %d / 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
