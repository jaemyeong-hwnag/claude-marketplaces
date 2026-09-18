#!/usr/bin/env bash
# 이 저장소의 플러그인 배치·배포 정책을 검증한다. 이름 규칙은 다루지 않는다 (plugin-naming 플러그인의 몫).
#
#   public-plugins/<이름>/   → marketplace.json source "./public-plugins/<이름>",   category "public"
#   internal-plugins/<이름>/ → marketplace.json source "./internal-plugins/<이름>", category "internal"
#
#   .claude/hooks/validate-plugin-scope.sh [루트]
#
# 종료 코드: 0 통과 / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}}"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"

ERRORS=()

command -v jq >/dev/null 2>&1 || { echo "validate-plugin-scope: jq 가 필요합니다" >&2; exit 1; }

if [ ! -r "$MARKETPLACE" ]; then
  exit 0
fi
if ! jq empty "$MARKETPLACE" 2>/dev/null; then
  echo "❌ marketplace.json: JSON 파싱 실패" >&2
  exit 2
fi

# 1. 디렉터리 → 선언
for kind in public internal; do
  dir="$ROOT/$kind-plugins"
  [ -d "$dir" ] || continue
  while IFS= read -r d; do
    [ -r "$d/.claude-plugin/plugin.json" ] || continue
    name="$(basename "$d")"
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
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
done

# 2. 선언 → 디렉터리
while IFS= read -r line; do
  n="${line%%	*}"; sp="${line#*	}"
  case "$sp" in
    ./*) [ -d "$ROOT/${sp#./}" ] || ERRORS+=("marketplace.json '$n': source 경로가 없습니다 ($sp)") ;;
  esac
done < <(jq -r '.plugins[]? | select((.source | type) == "string") | "\(.name)\t\(.source)"' "$MARKETPLACE")

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "" >&2
  echo "❌ 플러그인 배치 정책 위반 (CLAUDE.md '디렉터리 구분')" >&2
  for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
  echo "" >&2
  echo "public-plugins/ 는 배포용(category public), internal-plugins/ 는 이 저장소 전용(category internal)입니다." >&2
  exit 2
fi
exit 0
