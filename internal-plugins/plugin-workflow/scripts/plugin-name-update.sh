#!/usr/bin/env bash
# 플러그인 이름을 바꾼다 — 디렉터리 · plugin.json · marketplace 엔트리 · renames · 기대는 플러그인의 dependencies · enabledPlugins 키.
#
#   plugin-name-update.sh [--dry-run] <옛 이름> <새 이름> [루트]
#
#   public   renames 에 "<옛>": "<새>" 를 더한다 — 설치한 사용자의 설정 키를 Claude Code 가 옮긴다
#   internal renames 를 쓰지 않는다 — 배포하지 않는다
#   나머지 문자열 참조(README · 스킬 접두어 · 문서 · 테스트)는 바꾸지 않고 후보만 출력한다. CHANGELOG 는 이력이라 후보에서 뺀다
#   버전 · CHANGELOG 는 쓰지 않는다 (version-update 스킬)
#
# 시작 전에 전부 확인하고, 하나라도 걸리면 아무것도 바꾸지 않는다.
#
# 종료 코드: 0 성공 / 2 확인 실패 / 1 실행 오류
set -uo pipefail

DRY=0; ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    -*) echo "plugin-name-update: 알 수 없는 옵션 $1" >&2; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[ "${#ARGS[@]}" -ge 2 ] || { echo "사용법: plugin-name-update.sh [--dry-run] <옛 이름> <새 이름> [루트]" >&2; exit 1; }
OLD="${ARGS[0]}"; NEW="${ARGS[1]}"
ROOT="$(cd "${ARGS[2]:-${CLAUDE_PROJECT_DIR:-$(pwd)}}" && pwd)" || exit 1
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
SETTINGS="$ROOT/.claude/settings.json"
fail() { echo "❌ $*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "plugin-name-update: jq 가 필요합니다" >&2; exit 1; }
cd "$ROOT" || exit 1

# 1. 확인
[ -r "$MARKETPLACE" ] || fail ".claude-plugin/marketplace.json 이 없다"
jq -e . "$MARKETPLACE" >/dev/null 2>&1 || fail ".claude-plugin/marketplace.json 이 JSON 이 아니다"
[ ! -e "$SETTINGS" ] || jq -e . "$SETTINGS" >/dev/null 2>&1 || fail ".claude/settings.json 이 JSON 이 아니다"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "git 작업 트리가 아니다"
[[ "$NEW" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "새 이름 '$NEW' 가 kebab-case 가 아니다"
[ "$OLD" != "$NEW" ] || fail "옛 이름과 새 이름이 같다"
KIND=""
for k in public internal; do [ -r "$k-plugins/$OLD/.claude-plugin/plugin.json" ] && KIND="$k"; done
[ -n "$KIND" ] || fail "'$OLD' 플러그인이 없다 (public-plugins/ · internal-plugins/)"
for k in public internal; do [ -e "$k-plugins/$NEW" ] && fail "'$k-plugins/$NEW' 가 이미 있다"; done
jq -e --arg n "$NEW" 'any(.plugins[]?; .name == $n)' "$MARKETPLACE" >/dev/null && fail "marketplace.json 에 '$NEW' 엔트리가 이미 있다"
jq -e --arg n "$NEW" '(.renames // {}) | has($n)' "$MARKETPLACE" >/dev/null && fail "'$NEW' 는 renames 에 있는 옛 이름이다 — 옛 이름은 다시 쓰지 않는다"
[ -z "$(git status --porcelain -- "$KIND-plugins/$OLD" .claude-plugin .claude/settings.json 2>/dev/null)" ] || \
  fail "'$KIND-plugins/$OLD' · .claude-plugin · .claude/settings.json 에 커밋하지 않은 변경이 있다"
MARKET="$(jq -r '.name // ""' "$MARKETPLACE")"

# 기대는 플러그인 — dependencies 에 문자열 또는 { name } 으로 선언
DEPENDENTS=()
for f in public-plugins/*/.claude-plugin/plugin.json internal-plugins/*/.claude-plugin/plugin.json; do
  [ -e "$f" ] || continue
  [ "$f" = "$KIND-plugins/$OLD/.claude-plugin/plugin.json" ] && continue
  jq -e --arg o "$OLD" 'any(.dependencies[]?; (if type == "string" then . else .name end) == $o)' "$f" >/dev/null 2>&1 && \
    DEPENDENTS+=("$(basename "$(dirname "$(dirname "$f")")")")
done
for d in ${DEPENDENTS+"${DEPENDENTS[@]}"}; do
  [ -z "$(git status --porcelain -- "public-plugins/$d/.claude-plugin/plugin.json" "internal-plugins/$d/.claude-plugin/plugin.json" 2>/dev/null)" ] || \
    fail "'$d' 의 plugin.json 에 커밋하지 않은 변경이 있다"
done

# 2. 바꾼다
CHANGED=()
jq_write() { # $1=파일, 나머지=jq 인자
  local f="$1" t; shift
  t="$(mktemp)" && jq "$@" "$f" > "$t" && mv "$t" "$f" || { rm -f "$t"; echo "plugin-name-update: '$f' 갱신 실패" >&2; exit 1; }
}
step() { CHANGED+=("$1"); }

step "git mv $KIND-plugins/$OLD $KIND-plugins/$NEW"
step "$KIND-plugins/$NEW/.claude-plugin/plugin.json: name → $NEW"
step ".claude-plugin/marketplace.json: 엔트리 name · source → $NEW"
[ "$KIND" = public ] && step ".claude-plugin/marketplace.json: renames[\"$OLD\"] = \"$NEW\""
for d in ${DEPENDENTS+"${DEPENDENTS[@]}"}; do
  [ -r "public-plugins/$d/.claude-plugin/plugin.json" ] && dk=public || dk=internal
  step "$dk-plugins/$d/.claude-plugin/plugin.json: dependencies '$OLD' → '$NEW'"
done
HAS_KEY=0
[ -r "$SETTINGS" ] && jq -e --arg id "$OLD@$MARKET" '(.enabledPlugins // {}) | has($id)' "$SETTINGS" >/dev/null 2>&1 && HAS_KEY=1
[ "$HAS_KEY" = 1 ] && step ".claude/settings.json: enabledPlugins '$OLD@$MARKET' → '$NEW@$MARKET'"

if [ "$DRY" = 0 ]; then
  git mv "$KIND-plugins/$OLD" "$KIND-plugins/$NEW" || exit 1
  jq_write "$KIND-plugins/$NEW/.claude-plugin/plugin.json" --arg n "$NEW" '.name = $n'
  jq_write "$MARKETPLACE" --arg o "$OLD" --arg n "$NEW" --arg s "./$KIND-plugins/$NEW" \
    '.plugins |= map(if .name == $o then .name = $n | .source = $s else . end)'
  [ "$KIND" = public ] && jq_write "$MARKETPLACE" --arg o "$OLD" --arg n "$NEW" '.renames = ((.renames // {}) + {($o): $n})'
  for d in ${DEPENDENTS+"${DEPENDENTS[@]}"}; do
    [ -r "public-plugins/$d/.claude-plugin/plugin.json" ] && dk=public || dk=internal
    jq_write "$dk-plugins/$d/.claude-plugin/plugin.json" --arg o "$OLD" --arg n "$NEW" \
      '.dependencies |= map(if . == $o then $n elif (type == "object" and .name == $o) then .name = $n else . end)'
  done
  [ "$HAS_KEY" = 1 ] && jq_write "$SETTINGS" --arg o "$OLD@$MARKET" --arg n "$NEW@$MARKET" \
    '.enabledPlugins |= with_entries(if .key == $o then .key = $n else . end)'
fi

# 3. 보고
[ "$DRY" = 1 ] && echo "🔎 --dry-run — 아무것도 바꾸지 않았다"
echo "✅ $KIND 플러그인 '$OLD' → '$NEW'"
for c in "${CHANGED[@]}"; do echo "  - $c"; done
echo ""
echo "버전을 올릴 플러그인 (version-update): $NEW${DEPENDENTS+ ${DEPENDENTS[*]}}"
echo ""
CANDIDATES="$(git grep -nIw -e "$OLD" -- . ':(exclude)*CHANGELOG.md' ':(exclude).claude-plugin/marketplace.json' 2>/dev/null \
  | grep -vE "^$KIND-plugins/($OLD|$NEW)/\.claude-plugin/plugin\.json:" || true)"
if [ -n "$CANDIDATES" ]; then
  echo "남은 문자열 참조 — 하나씩 보고 바꿀지 판단한다 (CHANGELOG 는 이력이라 뺐다):"
  printf '%s\n' "$CANDIDATES" | sed 's/^/  /'
else
  echo "남은 문자열 참조 없음"
fi
PATHS="$(git ls-files -- "$KIND-plugins/$OLD" "$KIND-plugins/$NEW" | sed "s#^$KIND-plugins/[^/]*/##" | grep -E "(^|[/._-])$OLD([/._-]|$)" || true)"
if [ -n "$PATHS" ]; then
  echo ""
  echo "이름에 '$OLD' 가 들어간 파일 ($KIND-plugins/$NEW/ 기준):"
  printf '%s\n' "$PATHS" | sed 's/^/  /'
fi
exit 0
