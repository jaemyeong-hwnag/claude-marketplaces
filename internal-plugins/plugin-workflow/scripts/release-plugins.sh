#!/usr/bin/env bash
# 플로우 11 단계 — 머지 뒤 main 에서, 버전이 바뀐 플러그인마다 태그를 달고 GitHub 릴리즈를 만든다.
#
#   release-plugins.sh [--dry-run] [--since <ref>] [루트]
#
#   --since <ref>  이 ref 와 비교해 version 이 바뀐 플러그인을 고른다 (기본: HEAD^1 — 머지 커밋의 첫 부모)
#   --dry-run      무엇을 할지만 보여준다. 태그·푸시·릴리즈를 하지 않는다
#
# 시작 전에 전부 확인하고, 하나라도 걸리면 아무것도 하지 않는다.
#   main 인가 · 작업 트리가 깨끗한가 · origin/main 과 같은가 · 설치본에 Error 가 없는가 ·
#   태그가 이미 있지 않은가 · CHANGELOG 에 그 버전 절이 있는가
#
# 종료 코드: 0 성공(또는 할 것 없음) / 2 확인 실패 / 1 실행 오류
set -uo pipefail

DRY=0; SINCE=""; ROOT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    -*) echo "release-plugins: 알 수 없는 옵션 $1" >&2; exit 1 ;;
    *) ROOT="$1"; shift ;;
  esac
done
ROOT="$(cd "${ROOT:-${CLAUDE_PROJECT_DIR:-$(pwd)}}" && pwd)"
MAIN="main"
fail() { echo "❌ $*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "release-plugins: jq 가 필요합니다" >&2; exit 1; }
cd "$ROOT" || exit 1

# 1. 자리 확인
[ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$MAIN" ] || fail "main 에서 돌린다 (W-10) — 지금 '$(git rev-parse --abbrev-ref HEAD 2>/dev/null)'"
[ -z "$(git status --porcelain 2>/dev/null)" ] || fail "작업 트리가 깨끗하지 않다 — claude plugin tag 는 깨끗한 트리를 요구한다"
git fetch -q origin "$MAIN" 2>/dev/null || [ "$DRY" = 1 ] || fail "origin 에서 main 을 받아올 수 없다"
if git rev-parse --verify -q "origin/$MAIN" >/dev/null; then
  [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$MAIN")" ] || fail "HEAD 가 origin/main 과 다르다 — git pull --ff-only 먼저"
fi
SINCE="${SINCE:-HEAD^1}"
git rev-parse --verify -q "$SINCE^{commit}" >/dev/null || fail "비교 기준 '$SINCE' 를 찾을 수 없다"

MARKET="$(jq -r '.name // ""' .claude-plugin/marketplace.json 2>/dev/null)"

# 2. 대상 — version 이 바뀐 플러그인
TARGETS=()
while IFS= read -r pj; do
  rel="${pj#./}"; dir="$(dirname "$(dirname "$rel")")"
  new="$(jq -r '.version // ""' "$rel" 2>/dev/null)"; name="$(jq -r '.name // ""' "$rel" 2>/dev/null)"
  old="$(git show "$SINCE:$rel" 2>/dev/null | jq -r '.version // ""' 2>/dev/null)"
  [ -n "$new" ] && [ -n "$name" ] && [ "$new" != "$old" ] && TARGETS+=("$name|$new|$dir")
done < <(find . -mindepth 4 -maxdepth 4 -path './*plugins/*/.claude-plugin/plugin.json' -not -path './.claude/*' | sort)

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "릴리즈할 플러그인이 없다 — $SINCE 이후 version 이 바뀐 플러그인이 없다"
  exit 0
fi

# 3. 사전 확인
NOTES_DIR="$(mktemp -d)"; trap 'rm -rf "$NOTES_DIR"' EXIT
LOADERR=""
if command -v claude >/dev/null 2>&1; then
  # --json 의 errors 필드 우선, 못 받으면 텍스트의 Error: 줄
  LJ="$(claude plugin list --json 2>/dev/null)"
  if printf '%s' "$LJ" | jq -e 'type == "array"' >/dev/null 2>&1; then
    LOADERR="$(printf '%s' "$LJ" | jq -r '.[] | select((.errors // []) | length > 0) | "\(.id) Error: \(.errors[0])"')"
  else
    LOADERR="$(claude plugin list 2>/dev/null | awk '/❯/ { id = $NF; next } /^[[:space:]]*Error:/ { sub(/^[[:space:]]*/, ""); print id " " $0 }')"
  fi
fi
for t in "${TARGETS[@]}"; do
  IFS='|' read -r name ver dir <<< "$t"
  tag="$name--v$ver"
  printf '%s\n' "$LOADERR" | grep -q "^$name@$MARKET " && \
    fail "'$name@$MARKET' 로드 실패가 있다 — 설치 확인(10 단계)을 통과하지 못한 버전은 릴리즈하지 않는다: $(printf '%s\n' "$LOADERR" | grep "^$name@$MARKET " | head -1)"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "태그 '$tag' 가 이미 있다"
  # '## 0.2.0' 또는 '## 0.2.0 - 2026-09-18' (V-05)
  awk -v v="$ver" '/^```/ { f2 = !f2 } ($0 == "## " v || index($0, "## " v " - ") == 1) && !f2 { f = 1; next } /^## / && !f2 { if (f) exit } f' "$dir/CHANGELOG.md" > "$NOTES_DIR/$name.md" 2>/dev/null
  [ -n "$(grep -v '^[[:space:]]*$' "$NOTES_DIR/$name.md")" ] || fail "$dir/CHANGELOG.md 에 '## $ver' 절이 없거나 비어 있다"
done

# 4. 실행
echo "릴리즈 대상 (${#TARGETS[@]}개, 기준 $SINCE)"
for t in "${TARGETS[@]}"; do
  IFS='|' read -r name ver dir <<< "$t"
  tag="$name--v$ver"
  if [ "$DRY" = 1 ]; then
    echo "  · $tag — gh release \"$name v$ver\" (노트 $(grep -cv '^[[:space:]]*$' "$NOTES_DIR/$name.md")줄)"
    continue
  fi
  ( cd "$dir" && claude plugin tag --push ) >/dev/null 2>&1 || fail "$tag: claude plugin tag --push 실패 — 여기서 멈춘다. 앞의 플러그인은 이미 릴리즈됐다"
  gh release create "$tag" --verify-tag --title "$name v$ver" --notes-file "$NOTES_DIR/$name.md" --latest=false >/dev/null 2>&1 \
    || fail "$tag: gh release create 실패 — 태그는 푸시됐다. gh release create $tag --verify-tag --notes-file … 로 다시"
  echo "  ✅ $tag"
done
[ "$DRY" = 1 ] && echo "(--dry-run — 아무것도 하지 않았다)"
exit 0
