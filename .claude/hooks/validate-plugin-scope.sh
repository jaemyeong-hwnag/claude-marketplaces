#!/usr/bin/env bash
# 이 저장소의 플러그인 배치·등록 정책을 검증한다. 이름 규칙은 다루지 않는다 (plugin-naming 플러그인의 몫).
#
#   public-plugins/<이름>/   → marketplace.json source "./public-plugins/<이름>",   category "public"
#   internal-plugins/<이름>/ → marketplace.json source "./internal-plugins/<이름>", category "internal"
#
#   등록 메타데이터
#     - 엔트리 이름은 하나씩만
#     - category 는 .claude-plugin/categories.json 에 있어야 한다 (파일이 없으면 public · internal)
#     - tags 는 .claude-plugin/tags.json 에 있어야 하고 2개 이하, 2개면 domain 1 + technology 1
#     - 엔트리 description 은 plugin.json description 과 같다
#     - common-* 플러그인은 public-plugins/ 에 둔다
#
#   .claude/hooks/validate-plugin-scope.sh [루트]
#
# 종료 코드: 0 통과 / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}}"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
CATEGORIES="$ROOT/.claude-plugin/categories.json"
TAGS="$ROOT/.claude-plugin/tags.json"

ERRORS=()
WARNINGS=()

command -v jq >/dev/null 2>&1 || { echo "validate-plugin-scope: jq 가 필요합니다" >&2; exit 1; }

if [ ! -r "$MARKETPLACE" ]; then
  exit 0
fi
if ! jq empty "$MARKETPLACE" 2>/dev/null; then
  echo "❌ marketplace.json: JSON 파싱 실패" >&2
  exit 2
fi

# 0. 이름 중복 — 먼저 본다. 중복이면 아래 검사의 한 이름 조회가 두 줄을 돌려받아 엉뚱한 메시지가 난다.
DUPS="$(jq -r '[.plugins[]?.name] | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$MARKETPLACE")"
while IFS= read -r n; do
  [ -n "$n" ] && ERRORS+=("marketplace.json: 플러그인 이름 '$n' 이 둘 이상 등록되어 있습니다 — 이름은 하나씩만")
done <<< "$DUPS"
is_dup() { printf '%s\n' "$DUPS" | grep -qxF -- "$1"; }

# 카테고리 목록 — 파일이 있으면 거기서, 없으면 두 배치값
check_catalog_file() { # $1=파일 $2=라벨 $3=kind 검사 여부
  local f="$1" label="$2" out
  jq empty "$f" 2>/dev/null || { ERRORS+=("$label: JSON 파싱 실패"); return 1; }
  jq -e 'type == "array"' "$f" >/dev/null || { ERRORS+=("$label: 배열이어야 합니다"); return 1; }
  out="$(jq -r '.[] | select((.name | type) != "string" or (.description | type) != "string" or (.description | length) == 0)
                | "\(.name // "?"): name · description 이 필요합니다"' "$f")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("$label: $l"); done <<< "$out"
  out="$(jq -r '.[].name | strings | select(test("^[a-z0-9]+(-[a-z0-9]+)*$") | not) | "\(.): 소문자·숫자·하이픈만 씁니다"' "$f")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("$label: $l"); done <<< "$out"
  out="$(jq -r '[.[].name] | group_by(.) | map(select(length > 1) | .[0]) | .[] | "\(.): 중복입니다"' "$f")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("$label: $l"); done <<< "$out"
  jq -e '[.[].name] == ([.[].name] | sort)' "$f" >/dev/null || ERRORS+=("$label: name 알파벳 순으로 정렬해야 합니다")
  if [ "$3" = 1 ]; then
    out="$(jq -r '.[] | select(.kind != "domain" and .kind != "technology") | "\(.name): kind 는 domain 또는 technology 입니다"' "$f")"
    [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("$label: $l"); done <<< "$out"
  fi
  return 0
}

CATEGORY_NAMES="public
internal"
if [ -r "$CATEGORIES" ]; then
  check_catalog_file "$CATEGORIES" "categories.json" 0 && CATEGORY_NAMES="$(jq -r '.[].name // empty' "$CATEGORIES")"
fi
TAG_OK=0
if [ -r "$TAGS" ]; then
  check_catalog_file "$TAGS" "tags.json" 1 && TAG_OK=1
fi

# 1. 디렉터리 → 선언
for kind in public internal; do
  dir="$ROOT/$kind-plugins"
  [ -d "$dir" ] || continue
  while IFS= read -r d; do
    [ -r "$d/.claude-plugin/plugin.json" ] || continue
    name="$(basename "$d")"
    is_dup "$name" && continue
    entry="$(jq -r --arg n "$name" '.plugins[]? | select(.name == $n) | "\(.source)\t\(.category // "")"' "$MARKETPLACE")"
    if [ -z "$entry" ]; then
      ERRORS+=("$kind-plugins/$name: marketplace.json 에 등록되지 않았습니다 — category \"$kind\" 로 등록하세요")
      continue
    fi
    src="$(printf '%s' "$entry" | cut -f1)"
    ccat="$(printf '%s' "$entry" | cut -f2)"
    [ "$src" = "./$kind-plugins/$name" ] || \
      ERRORS+=("$kind-plugins/$name: source 가 '$src' 입니다 — './$kind-plugins/$name' 이어야 합니다")
    [ "$ccat" = "$kind" ] || \
      ERRORS+=("$kind-plugins/$name: category 가 '$ccat' 입니다 — '$kind' 이어야 합니다")
    case "$name" in
      common-*) [ "$kind" = "public" ] || \
        ERRORS+=("$kind-plugins/$name: common 플러그인은 배포가 목적이므로 public-plugins/ 에 둡니다") ;;
    esac
    # 엔트리 description = plugin.json description
    edesc="$(jq -r --arg n "$name" '.plugins[]? | select(.name == $n) | .description // ""' "$MARKETPLACE")"
    if [ -n "$edesc" ]; then
      pdesc="$(jq -r '.description // ""' "$d/.claude-plugin/plugin.json" 2>/dev/null)"
      [ "$edesc" = "$pdesc" ] || \
        ERRORS+=("$kind-plugins/$name: 엔트리 description 이 plugin.json 과 다릅니다 — 같은 플러그인이 /plugin 과 details 에서 다르게 설명됩니다")
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
done

# 2. 선언 → 디렉터리 · 메타데이터
# 구분자는 \x1f 다. 탭은 IFS 공백이라 빈 칸이 합쳐져 뒤 칸이 앞으로 밀린다.
while IFS=$'\x1f' read -r n sp ccat tags author; do
  [ -n "$n" ] || continue
  case "$sp" in
    ./*) [ -d "$ROOT/${sp#./}" ] || ERRORS+=("marketplace.json '$n': source 경로가 없습니다 ($sp)") ;;
  esac
  if [ -n "$ccat" ] && ! printf '%s\n' "$CATEGORY_NAMES" | grep -qxF -- "$ccat"; then
    ERRORS+=("marketplace.json '$n': category '$ccat' 가 categories.json 에 없습니다")
  fi
  if [ -n "$tags" ]; then
    count="$(printf '%s' "$tags" | jq 'length')"
    [ "$count" -le 2 ] || ERRORS+=("marketplace.json '$n': tags 는 2개까지입니다 (지금 $count 개)")
    if [ "$TAG_OK" = 1 ]; then
      while IFS= read -r t; do
        jq -e --arg t "$t" 'any(.[]; .name == $t)' "$TAGS" >/dev/null || \
          ERRORS+=("marketplace.json '$n': tag '$t' 가 tags.json 에 없습니다")
      done < <(printf '%s' "$tags" | jq -r '.[]')
      if [ "$count" = 2 ]; then
        kinds="$(printf '%s' "$tags" | jq -r --slurpfile T "$TAGS" '[.[] as $t | ($T[0][] | select(.name == $t) | .kind)] | sort | join(",")')"
        [ "$kinds" = "domain,technology" ] || \
          ERRORS+=("marketplace.json '$n': tags 가 2개면 domain 1 + technology 1 이어야 합니다 (지금 ${kinds:-?})")
      fi
    elif [ ! -r "$TAGS" ]; then
      ERRORS+=("marketplace.json '$n': tags 를 쓰려면 .claude-plugin/tags.json 이 있어야 합니다")
    fi
  fi
  [ "$author" = "1" ] && WARNINGS+=("marketplace.json '$n': author 는 plugin.json 에 둡니다 — 엔트리에 두면 어긋날 자리만 늘어납니다")
done < <(jq -r '.plugins[]? | select((.source | type) == "string")
               | [.name, .source, (.category // ""), (if .tags then (.tags | tojson) else "" end), (if has("author") then "1" else "" end)]
               | join("\u001f")' "$MARKETPLACE")

for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "" >&2
  echo "❌ 플러그인 배치·등록 정책 위반 (CLAUDE.md '디렉터리 구분')" >&2
  for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
  echo "" >&2
  echo "public-plugins/ 는 배포용(category public), internal-plugins/ 는 이 저장소 전용(category internal)입니다." >&2
  exit 2
fi
exit 0
