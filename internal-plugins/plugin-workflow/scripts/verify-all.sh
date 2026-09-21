#!/usr/bin/env bash
# 플로우 5 · 6 단계 — 정적 검증과 회귀 테스트를 전부 돌리고 한 줄씩 요약한다.
# PR 본문의 "어떻게 확인했나" 에 결과를 그대로 붙인다.
#
#   verify-all.sh [루트]
#
# 무엇을 돌리나 (경로 규칙으로 찾는다 — 특정 플러그인을 알지 않는다)
#   - {루트}/*plugins/*/scripts/validate-*.sh --all {루트}
#   - 그중 --since 를 아는 검증기는 --since origin/main 도 (origin/main 이 있을 때)
#   - {루트}/.claude/hooks/validate-*.sh {루트}
#   - {루트}/test/*.test.sh, {루트}/*plugins/*/test/*.test.sh
#   - claude plugin validate --strict — 마켓플레이스와 플러그인마다 (claude 가 있을 때)
#
# 종료 코드: 0 전부 통과 / 1 하나라도 실패
set -uo pipefail

ROOT="$(cd "${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}" && pwd)"
FAILED=0
LINES=()

row() { # $1=결과(0/그 외) $2=이름 $3=요약
  if [ "$1" = 0 ]; then LINES+=("✅ $2 — $3"); else LINES+=("❌ $2 — $3"); FAILED=1; fi
}
last_line() { printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*m//g' | grep -v '^[[:space:]]*$' | tail -1; }
# 실패 요약 — 첫 번째 위반 줄(" - …"), 없으면 마지막 줄
first_error() { local l; l="$(printf '%s' "$1" | grep -m1 '^[[:space:]]*- ' | sed -E 's/^[[:space:]]*- //')"; [ -n "$l" ] && printf '%s' "$l" || last_line "$1"; }

cd "$ROOT" || exit 1

# 1. 플러그인 검증기
while IFS= read -r v; do
  rel="${v#"$ROOT"/}"
  out="$("$v" --all "$ROOT" 2>&1)"; c=$?
  row "$c" "$rel --all" "$( [ "$c" = 0 ] && echo "exit 0" || first_error "$out")"
  if grep -q -- '--since)' "$v" && git -C "$ROOT" rev-parse --verify -q origin/main >/dev/null; then
    out="$("$v" --since origin/main "$ROOT" 2>&1)"; c=$?
    row "$c" "$rel --since origin/main" "$( [ "$c" = 0 ] && echo "exit 0" || first_error "$out")"
  fi
done < <(find "$ROOT" -mindepth 4 -maxdepth 4 -path "$ROOT/*plugins/*/scripts/validate-*.sh" -not -path "$ROOT/.claude/*" 2>/dev/null | sort)

# 2. 저장소 정책 훅
while IFS= read -r v; do
  out="$("$v" "$ROOT" 2>&1)"; c=$?
  row "$c" "${v#"$ROOT"/}" "$( [ "$c" = 0 ] && echo "exit 0" || first_error "$out")"
done < <(find "$ROOT/.claude/hooks" -maxdepth 1 -name 'validate-*.sh' 2>/dev/null | sort)

# 3. 회귀 테스트
while IFS= read -r t; do
  out="$("$t" 2>&1)"; c=$?
  row "$c" "${t#"$ROOT"/}" "$(last_line "$out")"
done < <( { find "$ROOT/test" -maxdepth 1 -name '*.test.sh' 2>/dev/null
            find "$ROOT" -mindepth 4 -maxdepth 4 -path "$ROOT/*plugins/*/test/*.test.sh" -not -path "$ROOT/.claude/*" 2>/dev/null; } | sort)

# 4. Claude Code 매니페스트 검증
if command -v claude >/dev/null 2>&1; then
  if [ -r "$ROOT/.claude-plugin/marketplace.json" ]; then
    out="$(claude plugin validate "$ROOT/.claude-plugin/marketplace.json" --strict 2>&1)"; c=$?
    row "$c" "claude plugin validate marketplace.json --strict" "$(last_line "$out")"
  fi
  while IFS= read -r d; do
    out="$(claude plugin validate "$d" --strict 2>&1)"; c=$?
    row "$c" "claude plugin validate ${d#"$ROOT"/} --strict" "$(last_line "$out")"
  done < <(find "$ROOT" -mindepth 2 -maxdepth 2 -type d -path "$ROOT/*plugins/*" -not -path "$ROOT/.claude/*" 2>/dev/null | sort \
           | while IFS= read -r d; do [ -r "$d/.claude-plugin/plugin.json" ] && echo "$d"; done)
fi

for l in "${LINES[@]}"; do printf '%s\n' "$l"; done
echo
if [ "$FAILED" = 0 ]; then echo "전부 통과 (${#LINES[@]}건)"; else echo "실패가 있다 — 위 ❌ 줄"; fi
exit "$FAILED"
