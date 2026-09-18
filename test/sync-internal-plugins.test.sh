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
  "plugin list")      cat "$STUB_PLUGINS" ;;
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
  unset STUB_ADD_FAIL STUB_INSTALL_FAIL
}
add_plugin() { # $1=프로젝트 $2=이름
  mkdir -p "$1/internal-plugins/$2/.claude-plugin"
  printf '{ "name": "%s" }' "$2" > "$1/internal-plugins/$2/.claude-plugin/plugin.json"
}
market_registered() { printf '[{"name":"test-marketplace","source":"directory"}]' > "$STUB_MARKETS"; }
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

flush_tc
echo
printf '통과 %d / 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
