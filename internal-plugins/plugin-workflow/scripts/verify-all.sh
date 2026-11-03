#!/usr/bin/env bash
# 플로우 5 · 6 단계 — 정적 검증과 회귀 테스트를 돌리고 한 줄씩 요약한다.
# PR 본문의 "어떻게 확인했나" 에 결과를 그대로 붙인다.
#
#   verify-all.sh [--all] [루트]
#
# 대상 (첫 줄에 알린다)
#   기본  : origin/main 과의 merge-base 대비 바뀐 파일(커밋 + 작업 트리 + 미추적)로 고른다.
#           바뀐 플러그인 + 그 플러그인을 dependencies 로 기대는 플러그인(전이 포함).
#           origin/main 이 없으면 전체로 대신한다.
#   --all : 전체
#
# 무엇을 돌리나 (경로 규칙으로 찾는다 — 특정 플러그인을 알지 않는다)
#   항상 — 플러그인 하나만 봐서는 못 잡는 저장소 정합성
#   - {루트}/*plugins/*/scripts/validate-*.sh --all {루트}
#     --no-run 을 아는 검증기는 기본 모드에서 --all --no-run (실행 검사는 아래 --since 가 바뀐 플러그인만 한다)
#   - 그중 --since 를 아는 검증기는 --since origin/main 도 (origin/main 이 있을 때)
#   - {루트}/.claude/hooks/validate-*.sh {루트}
#   - claude plugin validate marketplace.json --strict (claude 가 있을 때)
#   대상만
#   - {대상}/test/*.test.sh, claude plugin validate {대상} --strict
#   - {루트}/test/*.test.sh — --all 이거나 .claude/hooks/ · test/ · .claude-plugin/ · CLAUDE.md 가 바뀌었을 때
#
# 종료 코드: 0 전부 통과 / 1 하나라도 실패 / 2 사용법 오류
set -uo pipefail

ALL=0
case "${1:-}" in
  --all) ALL=1; shift ;;
  -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*) echo "알 수 없는 옵션: $1 (verify-all.sh [--all] [루트])" >&2; exit 2 ;;
esac
ROOT="$(cd "${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}" && pwd)"
BASE_REF=origin/main
FAILED=0
LINES=()

row() { # $1=결과(0/그 외) $2=이름 $3=요약
  if [ "$1" = 0 ]; then LINES+=("✅ $2 — $3"); else LINES+=("❌ $2 — $3"); FAILED=1; fi
}
last_line() { printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*m//g' | grep -v '^[[:space:]]*$' | tail -1; }
# 실패 요약 — 첫 번째 위반 줄(" - …"), 없으면 마지막 줄
first_error() { local l; l="$(printf '%s' "$1" | grep -m1 '^[[:space:]]*- ' | sed -E 's/^[[:space:]]*- //')"; [ -n "$l" ] && printf '%s' "$l" || last_line "$1"; }
# {루트}/*plugins/* — 루트 기준 상대 경로. $1=manifest 면 plugin.json 이 있는 것만
plugin_dirs() {
  find "$ROOT" -mindepth 2 -maxdepth 2 -type d -path "$ROOT/*plugins/*" -not -path "$ROOT/.claude/*" 2>/dev/null | sort \
    | while IFS= read -r d; do [ "${1:-}" != manifest ] || [ -r "$d/.claude-plugin/plugin.json" ] && echo "${d#"$ROOT"/}"; done
}

cd "$ROOT" || exit 1

# 0. 대상 고르기 — TARGETS: 루트 기준 플러그인 디렉터리 (줄 단위), REPO_TESTS: 저장소 테스트를 돌릴지
TARGETS=""; REPO_TESTS=1
if [ "$ALL" = 1 ]; then
  TARGETS="$(plugin_dirs)"; echo "대상: 전체 (--all)"
elif ! base="$(git -C "$ROOT" merge-base "$BASE_REF" HEAD 2>/dev/null)"; then
  TARGETS="$(plugin_dirs)"; echo "대상: 전체 — $BASE_REF 이 없어 바뀐 것을 고를 수 없다"
else
  changed="$( { git -C "$ROOT" diff --relative --name-only "$base" -- 2>/dev/null
                git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null; } | sort -u)"
  printf '%s\n' "$changed" | grep -qE '^(\.claude/hooks/|test/|\.claude-plugin/|CLAUDE\.md$)' || REPO_TESTS=0
  # 바뀐 플러그인의 이름 — 지운 플러그인은 기준 커밋의 plugin.json 에서 읽어 역의존을 찾는다
  seeds="$(printf '%s\n' "$changed" | sed -nE 's#^([^/.][^/]*plugins/[^/]+)/.*#\1#p' | sort -u \
    | while IFS= read -r d; do
        if [ -r "$d/.claude-plugin/plugin.json" ]; then jq -r '.name // empty' "$d/.claude-plugin/plugin.json" 2>/dev/null
        else git -C "$ROOT" show "$base:./$d/.claude-plugin/plugin.json" 2>/dev/null | jq -r '.name // empty' 2>/dev/null; fi
      done)"
  graph="$(plugin_dirs manifest | while IFS= read -r d; do
             jq -c --arg d "$d" '{name: (.name // ""), dir: $d,
               deps: [(.dependencies // [])[] | if type == "string" then . else (.name // "") end]}' "$d/.claude-plugin/plugin.json" 2>/dev/null
           done | jq -s '.')"
  # 바뀐 것에 닿는 플러그인을 더 늘지 않을 때까지 넓힌다 → {dir, seed}
  picked="$(printf '%s' "$graph" | jq -r --arg seeds "$seeds" '
    . as $g | ($seeds | split("\n") | map(select(. != ""))) as $seed
    | ({s: $seed, done: false}
       | until(.done; .s as $s
           | ([$g[] | select(any(.deps[]; . as $v | $s | any(.[]; . == $v))) | .name] + $s | unique) as $n
           | {s: $n, done: (($n | length) == ($s | length))}))
    | .s as $s | $g[] | select(.name as $x | $s | any(.[]; . == $x))
    | "\(.dir)\u001f\(.name as $x | $seed | any(.[]; . == $x))"')"
  TARGETS="$(printf '%s\n' "$picked" | cut -d $'\x1f' -f1 | grep -v '^$')"
  direct="$(printf '%s\n' "$picked" | grep $'\x1ftrue$' | cut -d $'\x1f' -f1 | sed 's#.*/##' | paste -sd ',' - | sed 's/,/, /g')"
  n_dep="$(printf '%s\n' "$picked" | grep -c $'\x1ffalse$')"
  repo_note=""; [ "$REPO_TESTS" = 1 ] && repo_note=" · 저장소 테스트"
  if [ -z "$TARGETS" ]; then
    echo "대상: 바뀐 플러그인 없음 — 저장소 정합성만$repo_note"
  else
    printf '대상: %s' "${direct:-없음}"; [ "$n_dep" -gt 0 ] && printf ' (+역의존 %s)' "$n_dep"; echo "$repo_note"
  fi
fi

# 1. 플러그인 검증기 — 저장소 정합성이라 늘 전체
has_base=0; git -C "$ROOT" rev-parse --verify -q "$BASE_REF" >/dev/null 2>&1 && has_base=1
while IFS= read -r v; do
  rel="${v#"$ROOT"/}"; args=(--all)
  [ "$ALL" = 0 ] && [ "$has_base" = 1 ] && grep -q -- '--no-run' "$v" && args=(--all --no-run)
  out="$("$v" "${args[@]}" "$ROOT" 2>&1)"; c=$?
  row "$c" "$rel ${args[*]}" "$( [ "$c" = 0 ] && echo "exit 0" || first_error "$out")"
  if grep -q -- '--since)' "$v" && [ "$has_base" = 1 ]; then
    out="$("$v" --since "$BASE_REF" "$ROOT" 2>&1)"; c=$?
    row "$c" "$rel --since $BASE_REF" "$( [ "$c" = 0 ] && echo "exit 0" || first_error "$out")"
  fi
done < <(find "$ROOT" -mindepth 4 -maxdepth 4 -path "$ROOT/*plugins/*/scripts/validate-*.sh" -not -path "$ROOT/.claude/*" 2>/dev/null | sort)

# 2. 저장소 정책 훅
while IFS= read -r v; do
  out="$("$v" "$ROOT" 2>&1)"; c=$?
  row "$c" "${v#"$ROOT"/}" "$( [ "$c" = 0 ] && echo "exit 0" || first_error "$out")"
done < <(find "$ROOT/.claude/hooks" -maxdepth 1 -name 'validate-*.sh' 2>/dev/null | sort)

# 3. 회귀 테스트 — 저장소 테스트 + 대상 플러그인의 테스트
while IFS= read -r t; do
  [ -n "$t" ] || continue
  out="$("$t" 2>&1)"; c=$?
  row "$c" "${t#"$ROOT"/}" "$(last_line "$out")"
done < <( { [ "$REPO_TESTS" = 1 ] && find "$ROOT/test" -maxdepth 1 -name '*.test.sh' 2>/dev/null
            printf '%s\n' "$TARGETS" | while IFS= read -r d; do
              [ -n "$d" ] && find "$ROOT/$d/test" -maxdepth 1 -name '*.test.sh' 2>/dev/null; done; } | sort)

# 4. Claude Code 매니페스트 검증 — 마켓플레이스는 늘, 플러그인은 대상만
if command -v claude >/dev/null 2>&1; then
  if [ -r "$ROOT/.claude-plugin/marketplace.json" ]; then
    out="$(claude plugin validate "$ROOT/.claude-plugin/marketplace.json" --strict 2>&1)"; c=$?
    row "$c" "claude plugin validate marketplace.json --strict" "$(last_line "$out")"
  fi
  while IFS= read -r d; do
    [ -r "$ROOT/$d/.claude-plugin/plugin.json" ] || continue
    out="$(claude plugin validate "$ROOT/$d" --strict 2>&1)"; c=$?
    row "$c" "claude plugin validate $d --strict" "$(last_line "$out")"
  done < <(printf '%s\n' "$TARGETS")
fi

for l in ${LINES+"${LINES[@]}"}; do printf '%s\n' "$l"; done
echo
if [ "$FAILED" = 0 ]; then echo "전부 통과 (${#LINES[@]}건)"; else echo "실패가 있다 — 위 ❌ 줄"; fi
exit "$FAILED"
