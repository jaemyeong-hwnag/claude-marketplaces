#!/usr/bin/env bash
# 플러그인 사이의 의존 관계를 검증한다 — 존재 · 순환 · 층(common · 번들) · 마켓플레이스 경계 · 배치 · 범위 겹침.
# 범위 문자열의 형식은 plugin-versioning(V-11)이 본다. 이름·위치는 다루지 않는다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PostToolUse(Write|Edit) → plugin.json 을 저장하면 저장소 전체 그래프를 다시 본다 (알림만)
# CLI 모드 :
#   validate-dependency.sh --all [루트]
#   validate-dependency.sh --dependents <이름> [루트]   이 플러그인에 기대는 것 (직접 · 전이)
#   validate-dependency.sh <플러그인 디렉터리> ...        그 플러그인이 선언한 것만
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/dependency-rules.md"

ERRORS=()
WARNINGS=()

die() { echo "validate-dependency: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

# 저장소의 모든 플러그인을 JSON 배열로 모은다.
# [{name, kind, deps, components, broken}]
collect() { # $1=루트
  local root="${1%/}" pd d pj kind comp deps
  {
    while IFS= read -r d; do
      pj="$d/.claude-plugin/plugin.json"
      [ -r "$pj" ] || continue
      case "$(basename "$(dirname "$d")")" in
        public-plugins) kind=public ;; internal-plugins) kind=internal ;; *) kind=other ;;
      esac
      comp=false
      for c in skills commands agents hooks; do
        [ -n "$(find "$d/$c" -type f 2>/dev/null | head -1)" ] && comp=true
      done
      if deps="$(jq -c '.dependencies // []' "$pj" 2>/dev/null)"; then
        jq -nc --arg n "$(basename "$d")" --arg k "$kind" --argjson deps "$deps" --argjson comp "$comp" \
          '{name: $n, kind: $k, deps: $deps, components: $comp, broken: false}'
      else
        jq -nc --arg n "$(basename "$d")" --arg k "$kind" '{name: $n, kind: $k, deps: [], components: false, broken: true}'
      fi
    done < <(
      find "$root" -mindepth 1 -maxdepth 1 -type d -name '*plugins' -not -path '*/.git*' 2>/dev/null \
        | while IFS= read -r pd; do find "$pd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null; done | sort
    )
  } | jq -sc '.'
}

marketplace_info() { # $1=루트 → {names, cross}
  local f="${1%/}/.claude-plugin/marketplace.json"
  if [ -r "$f" ] && jq empty "$f" 2>/dev/null; then
    jq -c '{names: [.plugins[]?.name], cross: (.allowCrossMarketplaceDependenciesOn // [])}' "$f"
  else
    echo '{"names": [], "cross": []}'
  fi
}

# 그래프 검사 — "E<TAB>선언한 플러그인<TAB>메시지" / "W<TAB>…" 줄을 낸다
read -r -d '' ANALYZE <<'JQ'
# ---- semver 구간 -----------------------------------------------------------
def num: if . == null or . == "x" or . == "X" or . == "*" then null else tonumber end;
def partial: split(".") | map(num) | . + [null, null, null] | .[0:3];
def fill0: map(. // 0);
def bump($i): if $i == 0 then [.[0] + 1, 0, 0] elif $i == 1 then [.[0], .[1] + 1, 0] else [.[0], .[1], .[2] + 1] end;
def full: [.[0:3][] | select(. != null)] | length == 3;
def depth: [.[0:3][] | select(. != null)] | length;
def all_range: {lo: [0,0,0], loInc: true, hi: null, hiInc: false};
# partial 이 덮는 구간 — 1 → [1.0.0, 2.0.0), 1.2 → [1.2.0, 1.3.0), 1.2.3 → [1.2.3, 1.2.3]
def cover:
  if depth == 0 then all_range
  elif full then {lo: ., loInc: true, hi: ., hiInc: true}
  else {lo: fill0, loInc: true, hi: (fill0 | bump(depth - 1)), hiInc: false} end;
def token_interval:
  capture("^(?<op>~|\\^|<=|>=|<|>|=)?(?<v>.+)$") as $m
  | ($m.v | partial) as $p
  | ($m.op // "=") as $op
  | if $op == "=" then ($p | cover)
    elif $op == "~" then
      if ($p | depth) <= 1 then ($p | cover)
      else {lo: ($p | fill0), loInc: true, hi: ($p | fill0 | bump(1)), hiInc: false} end
    elif $op == "^" then
      ($p | fill0) as $f
      | if ($p | depth) == 0 then all_range
        elif $f[0] > 0 or ($p | depth) == 1 then {lo: $f, loInc: true, hi: ($f | bump(0)), hiInc: false}
        elif $f[1] > 0 or ($p | depth) == 2 then {lo: $f, loInc: true, hi: ($f | bump(1)), hiInc: false}
        else {lo: $f, loInc: true, hi: ($f | bump(2)), hiInc: false} end
    elif $op == ">=" then {lo: ($p | fill0), loInc: true, hi: null, hiInc: false}
    elif $op == ">" then
      if ($p | full) then {lo: $p, loInc: false, hi: null, hiInc: false}
      else {lo: ($p | fill0 | bump(($p | depth) - 1)), loInc: true, hi: null, hiInc: false} end
    elif $op == "<" then {lo: [0,0,0], loInc: true, hi: ($p | fill0), hiInc: false}
    else  # <=
      if ($p | full) then {lo: [0,0,0], loInc: true, hi: $p, hiInc: true}
      else {lo: [0,0,0], loInc: true, hi: ($p | fill0 | bump(($p | depth) - 1)), hiInc: false} end
    end;
def intersect($a; $b):
  (if $a.lo > $b.lo then {lo: $a.lo, loInc: $a.loInc}
   elif $b.lo > $a.lo then {lo: $b.lo, loInc: $b.loInc}
   else {lo: $a.lo, loInc: ($a.loInc and $b.loInc)} end) as $l
  | (if $a.hi == null then {hi: $b.hi, hiInc: $b.hiInc}
     elif $b.hi == null then {hi: $a.hi, hiInc: $a.hiInc}
     elif $a.hi < $b.hi then {hi: $a.hi, hiInc: $a.hiInc}
     elif $b.hi < $a.hi then {hi: $b.hi, hiInc: $b.hiInc}
     else {hi: $a.hi, hiInc: ($a.hiInc and $b.hiInc)} end) as $h
  | $l + $h;
def empty_interval:
  .hi != null and (.lo > .hi or (.lo == .hi and ((.loInc and .hiInc) | not)));
# 판정할 수 있는 범위만 구간으로. 못 하면 null.
# 토큰이 모두 "연산자 + 숫자·x·* 부분 버전" 일 때만 판정한다 — ||, 하이픈 범위, prerelease 는 여기서 걸러진다.
def range_interval:
  gsub("(?<op><=|>=|<|>|=|~|\\^)\\s+"; "\(.op)")
  | [splits("\\s+") | select(length > 0)]
  | if length == 0 then null
    elif all(test("^(~|\\^|<=|>=|<|>|=)?(\\*|[xX]|[0-9]+)(\\.(\\*|[xX]|[0-9]+)){0,2}$")) then
      reduce (.[] | token_interval) as $t (all_range; intersect(.; $t))
    else null end;
def exact_pin: test("^=?\\s*[0-9]+\\.[0-9]+\\.[0-9]+$");

# ---- 그래프 ----------------------------------------------------------------
def dep_name: if type == "string" then . else (.name // "") end;
def graph: map({key: .name, value: [.deps[] | dep_name | select(. != "")]}) | from_entries;
def path_to($g; $from; $to; $seen):
  if (($g[$from] // []) | index($to)) != null then [$from, $to]
  else first(($g[$from] // [])[] as $n | select(($seen | index($n)) == null)
             | path_to($g; $n; $to; $seen + [$n]) | select(. != null) | [$from] + .) // null   # [$from] + null 은 [$from] 이 된다 — null 을 먼저 거른다
  end;
def rotate_min: (. [0:-1]) as $c | ($c | index($c | min)) as $i | ($c[$i:] + $c[:$i]) | . + [.[0]];

. as $P
| ($P | map({key: .name, value: .}) | from_entries) as $by
| ($P | graph) as $g
| $market as $m
| [
    # 깨진 plugin.json
    ($P[] | select(.broken) | ["E", .name, "plugin.json 을 읽을 수 없습니다"]),

    ($P[] | . as $p | .deps as $deps
      | ($deps | map(dep_name)) as $names
      | (
          # D-11 중복 선언
          ($names | group_by(.) | map(select(length > 1) | .[0])[] | ["E", $p.name, "'\(.)' 를 두 번 선언했습니다 (D-11)"]),
          ($deps[] | . as $d | (dep_name) as $n
            | (
                (if $n == "" then ["E", $p.name, "이름 없는 의존 항목이 있습니다 (D-01)"] else empty end),
                (if $n == $p.name then ["E", $p.name, "자기 자신에 의존합니다 (D-02)"] else empty end),
                (if $n != "" and $n != $p.name and ($by[$n] == null) and (($m.names | index($n)) == null) and (($d | type) == "string" or ($d.marketplace == null))
                   then ["E", $p.name, "'\($n)' 플러그인이 이 마켓플레이스에 없습니다 (D-01)"] else empty end),
                (if ($d | type) == "object" and $d.marketplace != null
                   then ["E", $p.name, "'\($n)' 를 다른 마켓플레이스 '\($d.marketplace)' 에서 가져옵니다 — 이 저장소는 마켓플레이스 밖에 의존하지 않습니다 (D-07)"] else empty end),
                (if ($p.name | startswith("common-")) then ["E", $p.name, "common 플러그인은 어떤 플러그인에도 의존하지 않습니다 — '\($n)' (D-04)"] else empty end),
                (if ($p.name | endswith("-standard")) and ($n | endswith("-standard"))
                   then ["E", $p.name, "번들이 다른 번들 '\($n)' 에 의존합니다 (D-05)"] else empty end),
                (if $p.kind == "public" and ($by[$n].kind // "") == "internal"
                   then ["E", $p.name, "배포용(public) 플러그인이 내부(internal) 플러그인 '\($n)' 에 의존합니다 — 배포본을 설치하면 내부 플러그인이 딸려갑니다 (D-08)"] else empty end),
                (if ($d | type) == "object" and (($d.version // "") | type) == "string" and ($d.version // "" | exact_pin)
                   then ["W", $p.name, "'\($n)' 를 '\($d.version)' 로 정확히 고정했습니다 — auto-update 가 멈춥니다 (D-10)"] else empty end)
              )
          ),
          # D-06 번들은 의존성만
          (if ($p.name | endswith("-standard")) and $p.components
             then ["E", $p.name, "번들은 dependencies 만 가집니다 — skills · commands · agents · hooks 를 두지 않습니다 (D-06)"] else empty end)
        )
    ),

    # D-07 교차 마켓플레이스 허용 목록
    (if ($m.cross | length) > 0 then ["E", "marketplace.json", "allowCrossMarketplaceDependenciesOn 을 두지 않습니다 — 이 저장소는 마켓플레이스 밖에 의존하지 않습니다 (D-07)"] else empty end),

    # D-03 순환 — 사이클마다 한 번
    ([$P[].name | . as $n | path_to($g; $n; $n; [$n]) | select(. != null) | rotate_min] | unique[]
      | ["E", .[0], "순환 의존: \(join(" → ")) (D-03)"]),

    # D-09 같은 대상에 대한 범위 겹침
    ([$P[] | .name as $from | .deps[] | select(type == "object" and (.version // "") != "")
       | {target: .name, from: $from, range: .version, iv: (.version | range_interval)}]
     | group_by(.target)[] | select(length > 1)
     | map(select(.iv != null)) | select(length > 1)
     | . as $cs
     | (reduce $cs[].iv as $i ({lo: [0,0,0], loInc: true, hi: null, hiInc: false}; intersect(.; $i))) as $x
     | select($x | empty_interval)
     | ["E", ($cs | map(.from) | join(", ")),
        "'\($cs[0].target)' 에 대한 버전 범위가 겹치지 않습니다 — \($cs | map("\(.from): \(.range)") | join(" / ")). 나중에 설치하는 쪽이 range-conflict 로 실패합니다 (D-09)"])
  ]
| .[] | @tsv
JQ

analyze() { # $1=루트 $2=필터할 플러그인(없으면 전체)
  local root="$1" only="${2:-}" plugins market line kind from msg
  plugins="$(collect "$root")"
  market="$(marketplace_info "$root")"
  while IFS=$'\t' read -r kind from msg; do
    [ -n "$kind" ] || continue
    if [ -n "$only" ]; then
      case ", $from, " in *", $only, "*) ;; *) continue ;; esac
    fi
    case "$kind" in
      E) ERRORS+=("$from: $msg") ;;
      W) WARNINGS+=("$from: $msg") ;;
    esac
  done < <(printf '%s' "$plugins" | jq -r --argjson market "$market" "$ANALYZE" 2>&1)
}

dependents() { # $1=이름 $2=루트 — 이 플러그인에 기대는 것. 직접 · 전이
  local name="$1" root="$2"
  collect "$root" | jq -r --arg t "$name" '
    def dep_name: if type == "string" then . else (.name // "") end;
    (map({key: .name, value: [.deps[] | dep_name]}) | from_entries) as $g
    | [$g | to_entries[] | select(.value | index($t)) | .key] as $direct
    # 거꾸로 따라가는 고정점: t 에 닿는 것들의 집합을 더 늘지 않을 때까지 넓힌다
    | ({s: [$t], done: false}
       | until(.done;
           .s as $s
           | ([$g | to_entries[] | select(any(.value[]; . as $v | $s | index($v))) | .key] + $s | unique) as $n
           | {s: $n, done: (($n | length) == ($s | length))}))
    | (.s - [$t]) as $all
    | "직접: \(if ($direct | length) == 0 then "없음" else ($direct | join(", ")) end)",
      "전이 포함: \(if ($all | length) == 0 then "없음" else ($all | join(", ")) end)"'
}

report() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 의존성 규칙 위반 (plugin-dependency)" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

emit_notices_json() {
  local body n
  [ "${#ERRORS[@]}" -gt 0 ] || [ "${#WARNINGS[@]}" -gt 0 ] || return 0
  body="의존성 알림 (plugin-dependency) — 막지 않았습니다. 이어서 맞추세요."
  for n in ${ERRORS+"${ERRORS[@]}"}; do body="$body"$'\n'"- $n"; done
  for n in ${WARNINGS+"${WARNINGS[@]}"}; do body="$body"$'\n'"- (경고) $n"; done
  body="$body"$'\n'"판단할 것: 가운데 층(언어별 ↔ 워크플로우)의 방향, common 의 멱등성·범위 — dependency-update 스킬"
  body="$body"$'\n'"기준: $RULES"
  jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --all) analyze "${2:-$PROJECT_DIR}" ;;
      --dependents)
        [ -n "${2:-}" ] || die "--dependents 에는 플러그인 이름이 필요합니다"
        dependents "$2" "${3:-$PROJECT_DIR}"; exit 0 ;;
      *)
        for arg in "$@"; do
          arg="${arg%/}"
          [ -r "$arg/.claude-plugin/plugin.json" ] || { ERRORS+=("$arg: 플러그인 디렉터리가 아닙니다"); continue; }
          analyze "$(cd "$arg/../.." && pwd)" "$(basename "$arg")"
        done ;;
    esac
    report
  fi

  local payload event path root
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)"
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
  [ "$event" = "PostToolUse" ] || exit 0
  case "$path" in */*plugins/*/.claude-plugin/plugin.json) ;; *) exit 0 ;; esac
  root="$(cd "$(dirname "$path")/../../.." 2>/dev/null && pwd)" || exit 0
  analyze "$root"
  emit_notices_json
  exit 0
}

main "$@"
