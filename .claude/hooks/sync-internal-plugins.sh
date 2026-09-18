#!/usr/bin/env bash
# internal-plugins/ 하위 플러그인이 모두 등록·활성·설치되어 있는지 확인하고, 빠진 것을 채운다.
#
# SessionStart 훅으로 실행된다. 수동 실행도 가능하다.
#   .claude/hooks/sync-internal-plugins.sh
#   .claude/hooks/sync-internal-plugins.sh --quiet    변경이 있을 때만 출력
#
# 마켓플레이스 소스는 .claude/settings.json 의 extraKnownMarketplaces 선언을 따른다.
# github 소스일 때는 푸시된 커밋만 읽으므로, 로컬 변경은 커밋·푸시해야 반영된다.
#
# 세션을 막지 않는다. 어떤 실패에도 종료 코드 0 으로 끝나고 상황만 보고한다.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MARKETPLACE_FILE="$PROJECT_DIR/.claude-plugin/marketplace.json"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"
PLUGIN_DIR="$PROJECT_DIR/internal-plugins"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

CHANGED=(); PROBLEMS=(); OK=()

say() { printf '%s\n' "$*"; }
bail() { [ "$QUIET" = 1 ] || say "internal-plugins: $1"; exit 0; }

command -v jq >/dev/null 2>&1 || bail "jq 가 없어 확인을 건너뜁니다"
[ -d "$PLUGIN_DIR" ] || bail "internal-plugins/ 가 없어 확인할 것이 없습니다"
[ -r "$MARKETPLACE_FILE" ] || bail ".claude-plugin/marketplace.json 이 없습니다"

MARKET="$(jq -r '.name // empty' "$MARKETPLACE_FILE")"
[ -n "$MARKET" ] || bail "marketplace.json 에 name 이 없습니다"

# 1. internal-plugins/ 의 플러그인 목록
NAMES=()
while IFS= read -r d; do
  [ -r "$d/.claude-plugin/plugin.json" ] || continue
  NAMES+=("$(basename "$d")")
done < <(find "$PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

[ "${#NAMES[@]}" -gt 0 ] || bail "internal-plugins/ 에 플러그인이 없습니다"

# 2. 마켓플레이스가 등록되어 있는가
#    등록에 쓸 소스는 settings.json 의 선언을 따른다 (github 저장소 또는 로컬 디렉터리).
SOURCE="./"
if [ -r "$SETTINGS_FILE" ]; then
  repo="$(jq -r --arg m "$MARKET" '.extraKnownMarketplaces[$m].source.repo // empty' "$SETTINGS_FILE" 2>/dev/null)"
  [ -n "$repo" ] && SOURCE="$repo"
fi

if ! claude plugin marketplace list --json 2>/dev/null | jq -e --arg m "$MARKET" 'any(.[]; .name == $m)' >/dev/null 2>&1; then
  if claude plugin marketplace add "$SOURCE" --scope project >/dev/null 2>&1; then
    CHANGED+=("마켓플레이스 '$MARKET' 등록 ($SOURCE)")
  else
    PROBLEMS+=("마켓플레이스 '$MARKET' 등록 실패 — 직접 실행: claude plugin marketplace add $SOURCE --scope project")
  fi
fi

INSTALLED="$(claude plugin list --json 2>/dev/null || echo '[]')"

for name in "${NAMES[@]}"; do
  id="$name@$MARKET"

  # 3. marketplace.json 에 등록되어 있는가
  if ! jq -e --arg n "$name" 'any(.plugins[]?; .name == $n)' "$MARKETPLACE_FILE" >/dev/null 2>&1; then
    desc="$(jq -r '.description // ""' "$PLUGIN_DIR/$name/.claude-plugin/plugin.json" 2>/dev/null)"
    tmp="$(mktemp)"
    if jq --arg n "$name" --arg d "$desc" \
         '.plugins += [{ name: $n, source: ("./internal-plugins/" + $n), category: "internal", description: $d }]' \
         "$MARKETPLACE_FILE" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      mv "$tmp" "$MARKETPLACE_FILE"
      CHANGED+=("marketplace.json 에 '$name' 등록")
    else
      rm -f "$tmp"
      PROBLEMS+=("marketplace.json 에 '$name' 등록 실패")
    fi
  fi

  # 4. settings.json 에서 활성화되어 있는가
  if ! jq -e --arg id "$id" '.enabledPlugins[$id] == true' "$SETTINGS_FILE" >/dev/null 2>&1; then
    tmp="$(mktemp)"
    if jq --arg id "$id" '.enabledPlugins = ((.enabledPlugins // {}) + { ($id): true })' \
         "$SETTINGS_FILE" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      mv "$tmp" "$SETTINGS_FILE"
      CHANGED+=("settings.json 에서 '$id' 활성화")
    else
      rm -f "$tmp"
      PROBLEMS+=("settings.json 에서 '$id' 활성화 실패")
    fi
  fi

  # 5. 실제로 설치되어 있는가
  if printf '%s' "$INSTALLED" | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled == true)' >/dev/null 2>&1; then
    # 설치본은 캐시로 복사된 스냅샷이다. 작업 트리와 어긋나면 낡은 코드가 돈다.
    # claude plugin update 는 버전이 같으면 갱신하지 않으므로 재설치로 강제한다.
    installed_path="$(printf '%s' "$INSTALLED" | jq -r --arg id "$id" '.[] | select(.id == $id) | .installPath // ""')"
    if [ -n "$installed_path" ] && [ -d "$installed_path" ] \
       && ! diff -rq "$installed_path" "$PLUGIN_DIR/$name" >/dev/null 2>&1; then
      if claude plugin uninstall "$id" --scope project >/dev/null 2>&1 \
         && claude plugin install "$id" -y --scope project >/dev/null 2>&1; then
        CHANGED+=("'$id' 재설치 (설치본이 작업 트리와 달랐습니다)")
      else
        PROBLEMS+=("'$id' 재설치 실패 — 설치본이 낡았습니다. 직접 실행: claude plugin uninstall $id --scope project && claude plugin install $id -y --scope project")
      fi
    else
      OK+=("$name")
    fi
  elif claude plugin install "$id" -y --scope project >/dev/null 2>&1; then
    CHANGED+=("'$id' 설치")
  else
    PROBLEMS+=("'$id' 설치 실패 — 직접 실행: claude plugin install $id -y --scope project")
  fi
done

# 6. 보고
if [ "${#CHANGED[@]}" -gt 0 ] || [ "${#PROBLEMS[@]}" -gt 0 ]; then
  say "internal-plugins 동기화 (${#NAMES[@]}개 대상)"
  for c in ${CHANGED+"${CHANGED[@]}"}; do say "  + $c"; done
  for p in ${PROBLEMS+"${PROBLEMS[@]}"}; do say "  ! $p"; done
  [ "${#CHANGED[@]}" -gt 0 ] && say "  새로 설치·활성화된 플러그인은 다음 세션부터 적용된다."
elif [ "$QUIET" = 0 ]; then
  say "internal-plugins: ${#OK[@]}/${#NAMES[@]} 설치됨 (${OK[*]})"
fi

exit 0
