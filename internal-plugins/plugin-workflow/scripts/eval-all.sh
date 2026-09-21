#!/usr/bin/env bash
# 플러그인 eval 스위트를 전부 돌리고 요약한다 — 수동 TC(스킬 발동 · 훅 차단)를 대신한다.
#
#   eval-all.sh [--quick] [--plugin <이름>] [--case <glob>] [--max-cost-usd <n>] [--threshold <0..1>] [루트]
#
#   --quick          케이스당 1회, 기준선(플러그인 없음) 없이 — 케이스를 고칠 때
#   (기본)           케이스당 3회, 기준선과 비교해 Δ 를 낸다
#
# 모델을 실제로 부른다 — 비용이 든다. 결과는 플러그인 밖({TMPDIR}/plugin-evals/<시각>.XXXX/)에 쓴다.
# 플러그인 안에 results/ 가 생기면 설치본과 달라져 sync 훅이 재설치한다.
# 리포트는 게시하지 않는다(--no-publish).
#
# 종료 코드: 0 모든 케이스가 기준 이상 / 1 기준 미달 또는 실행 실패
set -uo pipefail

QUICK=0; ONLY=""; CASE=""; COST=""; THRESHOLD="1.0"; ROOT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick) QUICK=1; shift ;;
    --plugin) ONLY="${2:-}"; shift 2 ;;
    --case) CASE="${2:-}"; shift 2 ;;
    --max-cost-usd) COST="${2:-}"; shift 2 ;;
    --threshold) THRESHOLD="${2:-}"; shift 2 ;;
    -*) echo "eval-all: 알 수 없는 옵션 $1" >&2; exit 1 ;;
    *) ROOT="$1"; shift ;;
  esac
done
ROOT="$(cd "${ROOT:-${CLAUDE_PROJECT_DIR:-$(pwd)}}" && pwd)"
command -v claude >/dev/null 2>&1 || { echo "eval-all: claude 가 필요합니다" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "eval-all: jq 가 필요합니다" >&2; exit 1; }

# 실행마다 고유한 디렉터리 — 시각만 쓰면 같은 초의 두 실행이 결과를 섞는다
mkdir -p "${TMPDIR:-/tmp}/plugin-evals"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/plugin-evals/$(date +%Y%m%d-%H%M%S).XXXX")"
FAILED=0; LIMITED=0; TOTAL_COST=0
printf '%-32s %-24s %6s %6s %7s %s\n' "플러그인" "케이스" "점수" "Δ" "비용" "비고"

# 케이스 단위로 돈다 — 권한(--allow-tools)은 실행 전체에 적용되므로, 케이스마다 필요한 것만 준다.
# prompt.md 의 allowed_tools 중 읽기 전용이 아닌 것(Write · Edit · Bash)을 뽑는다. Bash 는 git 명령만.
grants_for() { # $1=케이스 디렉터리
  local t
  t="$(awk '/^---/{c++; next} c==1 && /^allowed_tools:/{sub(/^allowed_tools:[[:space:]]*/, ""); gsub(/[][,]/, " "); print}' "$1/prompt.md" 2>/dev/null)"
  for x in $t; do
    case "$x" in Write|Edit) printf '%s\n' "$x" ;; Bash) printf '%s\n' "Bash(git *)" ;; esac
  done
  grep -q '^  *scaffold_script:' "$1/case.yaml" 2>/dev/null && grep -q 'git ' "$1"/*.sh 2>/dev/null && printf '%s\n' "Bash(git *)"
}

while IFS= read -r c; do
  cdir="$(dirname "$c")"; case_name="$(basename "$cdir")"
  plugin_dir="${cdir%%/evals/*}"; name="$(basename "$plugin_dir")"
  [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue
  if [ -n "$CASE" ]; then case "$case_name" in $CASE) ;; *) continue ;; esac; fi
  target="$cdir/prompt.md"; [ -r "$target" ] || target="$cdir/case.yaml"
  tag="$name.$case_name"
  args=("$target" --no-publish --trust-plugin --threshold "$THRESHOLD"
        --output-dir "$OUT/$tag" --report "$OUT/$tag/report.html" --json "$OUT/$tag.json")
  g=(); while IFS= read -r x; do [ -n "$x" ] && g+=("$x"); done < <(grants_for "$cdir" | sort -u)
  [ "${#g[@]}" -gt 0 ] && args+=(--allow-tools "${g[@]}")
  [ -r "$cdir/case.yaml" ] && grep -q 'scaffold_script:' "$cdir/case.yaml" && args+=(--scaffold)
  [ "$QUICK" = 1 ] && args+=(--runs 1 --ablation none)
  [ -n "$COST" ] && args+=(--max-cost-usd "$COST")
  ( cd "$plugin_dir" && claude plugin eval "${args[@]}" ) >"$OUT/$tag.log" 2>&1
  if [ ! -s "$OUT/$tag.json" ]; then
    printf '%-32s %-24s %6s %6s %7s %s\n' "$name" "$case_name" "-" "-" "-" "❌ 실행 실패 — $OUT/$tag.log"; FAILED=1; continue
  fi
  IFS=$'\t' read -r score delta err < <(jq -r '.cases[0] | [(.aggregates.score | tostring | .[0:4]), ((.aggregates.delta // "-") | tostring | .[0:5]),
                  ([.arms.with[]?.error // empty] | first // "")] | @tsv' "$OUT/$tag.json")
  cost="$(jq -r '.costUsd // 0' "$OUT/$tag.json")"
  TOTAL_COST="$(awk -v a="$TOTAL_COST" -v b="$cost" 'BEGIN { printf "%.2f", a + b }')"
  case "$err" in
    *"Bash sandbox cannot"*|*"cannot run here"*)
      mark="⚠️ 환경 제한 — 이 머신에서 Bash 샌드박스를 쓸 수 없다"; LIMITED=1; err="" ;;
    *)
      mark="✅"; awk -v s="$score" -v t="$THRESHOLD" 'BEGIN { exit !(s + 0 < t + 0) }' && { mark="❌"; FAILED=1; } ;;
  esac
  printf '%-32s %-24s %6s %6s %7s %s\n' "$name" "$case_name" "$score" "$delta" "\$$(printf '%.2f' "$cost")" "$mark${err:+ $err}"
done < <(find "$ROOT" -mindepth 5 -path "$ROOT/*plugins/*/evals/*" \( -name prompt.md -o -name case.yaml \) -type f -not -path '*/results/*' -not -path "$ROOT/.claude/*" 2>/dev/null \
         | while IFS= read -r f; do d="$(dirname "$f")"; [ -r "$d/prompt.md" ] && [ "$(basename "$f")" = case.yaml ] && continue; echo "$f"; done | sort)

echo
echo "비용 합계 약 \$$TOTAL_COST · 결과 $OUT"
[ "$LIMITED" = 1 ] && echo "⚠️ 환경 제한으로 돌지 못한 케이스가 있다 — 실패로 세지 않는다"
[ "$FAILED" = 0 ] && echo "전부 기준($THRESHOLD) 이상" || echo "기준 미달 또는 실패가 있다 — 위 ❌ 줄, 자세한 것은 결과 디렉터리의 .json · .log"
exit "$FAILED"
