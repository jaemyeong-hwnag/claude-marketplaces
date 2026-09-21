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
# 규칙
#   - enabledPlugins 에 키가 없으면 true 로 추가한다. 명시적 false 는 존중한다 (끈 플러그인은 설치도 건너뛴다).
#   - internal 엔트리의 description 은 plugin.json 을 따른다.
#   - 디렉터리가 사라진 internal 엔트리는 marketplace.json · enabledPlugins 에서 지우고 설치본을 제거한다.
#   - 설치본은 **마켓플레이스 소스 디렉터리**와 비교한다. 워크트리처럼 소스가 이 작업 트리가 아니면
#     작업 트리의 변경은 머지 뒤에 반영되므로 재설치하지 않는다.
#   - 끝에 claude plugin list 의 Error 줄을 확인한다. 정적 검증이 못 잡는 로드 실패가 여기 나온다.
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

CHANGED=(); PROBLEMS=(); OK=(); NOTES=()

say() { printf '%s\n' "$*"; }
bail() { [ "$QUIET" = 1 ] || say "internal-plugins: $1"; exit 0; }

# jq 로 파일을 제자리에서 고친다. $1=파일, 나머지=jq 인자
jq_inplace() {
  local file="$1" tmp; shift
  tmp="$(mktemp)"
  if jq "$@" "$file" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then mv "$tmp" "$file"; return 0; fi
  rm -f "$tmp"; return 1
}

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

# 디렉터리가 사라진 internal 엔트리 — 3 단계에서 정리한다
GONE=()
while IFS= read -r n; do
  [ -n "$n" ] && [ ! -d "$PLUGIN_DIR/$n" ] && GONE+=("$n")
done < <(jq -r '.plugins[]? | select(.category == "internal") | select((.source | type) == "string")
                | select(.source | startswith("./internal-plugins/")) | .name' "$MARKETPLACE_FILE" 2>/dev/null)

[ "${#NAMES[@]}" -gt 0 ] || [ "${#GONE[@]}" -gt 0 ] || bail "internal-plugins/ 에 플러그인이 없습니다"

# 2. 마켓플레이스가 등록되어 있는가 (설치할 플러그인이 있을 때만)
#    등록에 쓸 소스는 settings.json 의 선언을 따른다 (github 저장소 또는 로컬 디렉터리).
SOURCE="./"
if [ -r "$SETTINGS_FILE" ]; then
  repo="$(jq -r --arg m "$MARKET" '.extraKnownMarketplaces[$m].source.repo // empty' "$SETTINGS_FILE" 2>/dev/null)"
  [ -n "$repo" ] && SOURCE="$repo"
fi

MARKETS="$(claude plugin marketplace list --json 2>/dev/null || echo '[]')"
if [ "${#NAMES[@]}" -gt 0 ] && ! printf '%s' "$MARKETS" | jq -e --arg m "$MARKET" 'any(.[]; .name == $m)' >/dev/null 2>&1; then
  if claude plugin marketplace add "$SOURCE" --scope project >/dev/null 2>&1; then
    CHANGED+=("마켓플레이스 '$MARKET' 등록 ($SOURCE)")
    MARKETS="$(claude plugin marketplace list --json 2>/dev/null || echo '[]')"
  else
    PROBLEMS+=("마켓플레이스 '$MARKET' 등록 실패 — 직접 실행: claude plugin marketplace add $SOURCE --scope project")
  fi
fi

# 설치가 실제로 복사해 오는 곳. 로컬 디렉터리 소스면 그 경로, 아니면 이 작업 트리.
SOURCE_DIR="$(printf '%s' "$MARKETS" | jq -r --arg m "$MARKET" '.[] | select(.name == $m) | .path // empty' 2>/dev/null | head -1)"
[ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ] || SOURCE_DIR="$PROJECT_DIR"
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd -P)"
ELSEWHERE=0
[ "$SOURCE_DIR" = "$(cd "$PROJECT_DIR" && pwd -P)" ] || ELSEWHERE=1

INSTALLED="$(claude plugin list --json 2>/dev/null || echo '[]')"
is_installed() { printf '%s' "$INSTALLED" | jq -e --arg id "$1" 'any(.[]; .id == $id)' >/dev/null 2>&1; }

# 3. 디렉터리가 사라진 internal 엔트리 정리
for gone in ${GONE+"${GONE[@]}"}; do
  id="$gone@$MARKET"
  if jq_inplace "$MARKETPLACE_FILE" --arg n "$gone" '.plugins |= map(select(.name != $n))'; then
    CHANGED+=("marketplace.json 에서 '$gone' 제거 (디렉터리 없음)")
  else
    PROBLEMS+=("marketplace.json 에서 '$gone' 제거 실패")
  fi
  if [ -r "$SETTINGS_FILE" ] && jq -e --arg id "$id" '.enabledPlugins | has($id)' "$SETTINGS_FILE" >/dev/null 2>&1; then
    jq_inplace "$SETTINGS_FILE" --arg id "$id" 'del(.enabledPlugins[$id])' \
      && CHANGED+=("settings.json 에서 '$id' 제거") \
      || PROBLEMS+=("settings.json 에서 '$id' 제거 실패")
  fi
  if is_installed "$id"; then
    if claude plugin uninstall "$id" --scope project --prune -y >/dev/null 2>&1; then
      CHANGED+=("'$id' 설치본 제거")
    else
      PROBLEMS+=("'$id' 설치본 제거 실패 — 직접 실행: claude plugin uninstall $id --scope project --prune -y")
    fi
  fi
done


[ "$ELSEWHERE" = 1 ] && NOTES+=("설치 기준은 $SOURCE_DIR 이다 (이 작업 트리가 아님). 여기서 고친 플러그인은 머지 뒤 반영된다")

for name in ${NAMES+"${NAMES[@]}"}; do
  id="$name@$MARKET"

  # 4. marketplace.json 에 등록되어 있는가
  if ! jq -e --arg n "$name" 'any(.plugins[]?; .name == $n)' "$MARKETPLACE_FILE" >/dev/null 2>&1; then
    desc="$(jq -r '.description // ""' "$PLUGIN_DIR/$name/.claude-plugin/plugin.json" 2>/dev/null)"
    if jq_inplace "$MARKETPLACE_FILE" --arg n "$name" --arg d "$desc" \
         '.plugins += [{ name: $n, source: ("./internal-plugins/" + $n), category: "internal", description: $d }]'; then
      CHANGED+=("marketplace.json 에 '$name' 등록")
    else
      PROBLEMS+=("marketplace.json 에 '$name' 등록 실패")
    fi
  fi

  # 4-1. 엔트리 description 은 plugin.json 을 따른다 (validate-plugin-scope 가 일치를 요구한다)
  pdesc="$(jq -r '.description // ""' "$PLUGIN_DIR/$name/.claude-plugin/plugin.json" 2>/dev/null)"
  edesc="$(jq -r --arg n "$name" '.plugins[]? | select(.name == $n) | .description // ""' "$MARKETPLACE_FILE" 2>/dev/null)"
  if [ -n "$pdesc" ] && [ "$pdesc" != "$edesc" ] \
     && jq -e --arg n "$name" 'any(.plugins[]?; .name == $n and .category == "internal")' "$MARKETPLACE_FILE" >/dev/null 2>&1; then
    if jq_inplace "$MARKETPLACE_FILE" --arg n "$name" --arg d "$pdesc" \
         '.plugins |= map(if .name == $n then .description = $d else . end)'; then
      CHANGED+=("marketplace.json '$name' description 을 plugin.json 에 맞춤")
    else
      PROBLEMS+=("marketplace.json '$name' description 갱신 실패")
    fi
  fi

  # 5. settings.json — 키가 없을 때만 true 로 추가. 명시적 false 는 끈 것이다.
  state="$(jq -r --arg id "$id" 'if (.enabledPlugins // {} | has($id)) then (.enabledPlugins[$id] | tostring) else "absent" end' "$SETTINGS_FILE" 2>/dev/null || echo absent)"
  if [ "$state" = "false" ]; then
    NOTES+=("'$name' 은 settings.json 에서 꺼져 있다 — 설치를 건너뛴다")
    continue
  fi
  if [ "$state" != "true" ]; then
    [ -r "$SETTINGS_FILE" ] || printf '{}' > "$SETTINGS_FILE"
    if jq_inplace "$SETTINGS_FILE" --arg id "$id" '.enabledPlugins = ((.enabledPlugins // {}) + { ($id): true })'; then
      CHANGED+=("settings.json 에서 '$id' 활성화")
    else
      PROBLEMS+=("settings.json 에서 '$id' 활성화 실패")
    fi
  fi

  # 6. 실제로 설치되어 있는가
  src="$SOURCE_DIR/internal-plugins/$name"
  if [ ! -d "$src" ]; then
    NOTES+=("'$name' 은 설치 기준($SOURCE_DIR)에 아직 없다 — 머지 뒤 설치된다")
    continue
  fi
  if printf '%s' "$INSTALLED" | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled == true)' >/dev/null 2>&1; then
    # 설치본은 캐시로 복사된 스냅샷이다. 소스와 어긋나면 낡은 코드가 돈다.
    # claude plugin update 는 버전이 같으면 갱신하지 않으므로 재설치로 강제한다.
    installed_path="$(printf '%s' "$INSTALLED" | jq -r --arg id "$id" '.[] | select(.id == $id) | .installPath // ""')"
    if [ -n "$installed_path" ] && [ -d "$installed_path" ] \
       && ! diff -rq "$installed_path" "$src" >/dev/null 2>&1; then
      if claude plugin uninstall "$id" --scope project >/dev/null 2>&1 \
         && claude plugin install "$id" -y --scope project >/dev/null 2>&1; then
        CHANGED+=("'$id' 재설치 (설치본이 소스와 달랐습니다)")
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

# 6-1. enabledPlugins 키를 정렬해 둔다.
#      재설치(uninstall → install)는 키를 지웠다가 맨 뒤에 다시 넣는다. 그대로 두면 플러그인을
#      고칠 때마다 settings.json 에 순서만 바뀐 diff 가 생긴다.
if [ -r "$SETTINGS_FILE" ] && ! jq -e '(.enabledPlugins // {} | keys_unsorted) == (.enabledPlugins // {} | keys)' "$SETTINGS_FILE" >/dev/null 2>&1; then
  jq_inplace "$SETTINGS_FILE" '.enabledPlugins |= (to_entries | sort_by(.key) | from_entries)' || true
fi

# 7. 로드 확인 — 설치는 됐는데 훅·매니페스트 로드가 실패한 것
#    claude plugin list --json 의 errors 필드를 본다 (훅 로드 실패는 errorDetails[].type = hook-load-failed).
#    JSON 을 못 받으면 텍스트 출력의 "❯ id" 다음 "Error:" 줄로 대신한다.
LISTJSON="$(claude plugin list --json 2>/dev/null)"
if printf '%s' "$LISTJSON" | jq -e 'type == "array"' >/dev/null 2>&1; then
  load_errors() {
    # 이 마켓플레이스인지는 아래 루프가 JSON · 텍스트 경로 모두에 대해 거른다
    printf '%s' "$LISTJSON" | jq -r '.[] | select((.errors // []) | length > 0) | "\(.id)\t\(.errors[0])"'
  }
else
  load_errors() {
    claude plugin list 2>/dev/null | awk '
      /❯/ { id = $NF; next }
      /^[[:space:]]*Error:/ { sub(/^[[:space:]]*Error:[[:space:]]*/, ""); if (id != "") print id "\t" $0 }
    '
  }
fi
while IFS=$'\t' read -r eid emsg; do
  [ -n "$eid" ] || continue
  case "$eid" in *"@$MARKET") ;; *) continue ;; esac
  PROBLEMS+=("'$eid' 로드 실패 — $emsg")
done < <(load_errors)

# 8. 보고
if [ "${#CHANGED[@]}" -gt 0 ] || [ "${#PROBLEMS[@]}" -gt 0 ]; then
  say "internal-plugins 동기화 (${#NAMES[@]}개 대상)"
  for c in ${CHANGED+"${CHANGED[@]}"}; do say "  + $c"; done
  for p in ${PROBLEMS+"${PROBLEMS[@]}"}; do say "  ! $p"; done
  for n in ${NOTES+"${NOTES[@]}"}; do say "  · $n"; done
  [ "${#CHANGED[@]}" -gt 0 ] && say "  새로 설치·활성화된 플러그인은 다음 세션부터 적용된다."
elif [ "$QUIET" = 0 ]; then
  say "internal-plugins: ${#OK[@]}/${#NAMES[@]} 설치됨 (${OK[*]:-})"
  for n in ${NOTES+"${NOTES[@]}"}; do say "  · $n"; done
fi

exit 0
