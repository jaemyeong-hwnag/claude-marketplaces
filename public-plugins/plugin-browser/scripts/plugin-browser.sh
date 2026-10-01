#!/usr/bin/env bash
# plugin-browser — plugin-search-install 의 결과를 터미널 폭에 맞춰 그리고, 골라서 설치하게 한다.
#
#   plugin-browser.sh                          메뉴 (터미널에서)
#   plugin-browser.sh search <질의…>           기능 검색
#   plugin-browser.sh project [디렉터리]       이 프로젝트에 필요한 것
#   plugin-browser.sh related <플러그인|기능어> 연관
#   plugin-browser.sh installed                설치된 것
#   plugin-browser.sh show <플러그인>          상세
#   plugin-browser.sh facets [tag|keyword|category|marketplace|has]   관점별 개수
#   plugin-browser.sh render [파일|-]          엔진 JSON 을 그리기만
#
# 화면  --width N · --ascii · --color auto|always|never · --plain (번호 입력) · --no-pick (그리기만)
# 설치  --select 1,3-5 · --install-all · --scope project|user|local · --dry-run
# 그 밖의 옵션 (--tag · --has · --limit · --any …) 은 엔진에 그대로 넘긴다
#
# 환경  PLUGIN_SEARCH_INSTALL (엔진 경로) · PLUGIN_BROWSER_AMBIGUOUS=1|2 (모호 폭) · NO_COLOR
# 종료 코드: 0 정상 · 1 설치 일부 실패 · 2 잘못된 입력 · 엔진 없음
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDTHS="$ROOT_DIR/references/display-width.json"

die() { echo "plugin-browser: $*" >&2; exit 2; }
usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d)"
TTY_OLD=""
cleanup() {
  if [ -n "$TTY_OLD" ]; then
    printf '\033[?25h\033[?1049l' >/dev/tty 2>/dev/null
    stty "$TTY_OLD" </dev/tty 2>/dev/null
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---- 엔진 찾기 ---------------------------------------------------------------
find_engine() {
  local c v
  if [ -n "${PLUGIN_SEARCH_INSTALL:-}" ]; then
    [ -x "$PLUGIN_SEARCH_INSTALL" ] && { echo "$PLUGIN_SEARCH_INSTALL"; return 0; }
    die "PLUGIN_SEARCH_INSTALL 이 실행 파일이 아닙니다: $PLUGIN_SEARCH_INSTALL"
  fi
  c="$ROOT_DIR/../plugin-search-install/scripts/plugin-search-install.sh"     # 소스 · 디렉터리 마켓플레이스
  [ -x "$c" ] && { echo "$c"; return 0; }
  # 캐시: <마켓>/<플러그인>/<버전>/ — 가장 높은 버전
  v="$(ls -1 "$ROOT_DIR/../../plugin-search-install" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
  c="$ROOT_DIR/../../plugin-search-install/$v/scripts/plugin-search-install.sh"
  [ -n "$v" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  c="$(claude plugin list --json 2>/dev/null | jq -r '[.[] | select(.id | startswith("plugin-search-install@")) | .installPath][0] // empty' 2>/dev/null)"
  [ -n "$c" ] && [ -x "$c/scripts/plugin-search-install.sh" ] && { echo "$c/scripts/plugin-search-install.sh"; return 0; }
  die "plugin-search-install 을 찾지 못했습니다 — claude plugin install plugin-search-install@plugin-marketplace 또는 PLUGIN_SEARCH_INSTALL=<경로>"
}

# ---- 옵션 --------------------------------------------------------------------
WIDTH="" ASCII=false COLOR=auto PLAIN=false NOPICK=false SELECT="" INSTALL_ALL=false SCOPE="" DRY=false
ENGINE_ARGS=()
parse_opts() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --width) [ $# -ge 2 ] || die "--width 에 값이 필요합니다"; WIDTH="$2"; shift 2 ;;
      --ascii) ASCII=true; shift ;;
      --color) [ $# -ge 2 ] || die "--color 에 값이 필요합니다"; COLOR="$2"; shift 2 ;;
      --no-color) COLOR=never; shift ;;
      --plain) PLAIN=true; shift ;;
      --no-pick) NOPICK=true; shift ;;
      --select) [ $# -ge 2 ] || die "--select 에 값이 필요합니다"; SELECT="$SELECT,$2"; shift 2 ;;
      --install-all) INSTALL_ALL=true; shift ;;
      --scope|-s) [ $# -ge 2 ] || die "--scope 에 값이 필요합니다"; SCOPE="$2"; shift 2 ;;
      --dry-run) DRY=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) ENGINE_ARGS+=("$1"); shift ;;
    esac
  done
  case "$WIDTH" in ''|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]) ;; *) die "--width 는 1 이상의 정수: $WIDTH" ;; esac
  case "$COLOR" in auto|always|never) ;; *) die "--color 는 auto · always · never 중 하나: $COLOR" ;; esac
  case "$SCOPE" in ''|user|project|local) ;; *) die "--scope 는 user · project · local 중 하나: $SCOPE" ;; esac
}

# ---- 터미널 ------------------------------------------------------------------
# $(…) 안에서는 stdout 이 파이프라 -t 1 이 거짓이 된다 — 시작할 때 한 번 잰다
OUT_TTY=false; [ -t 1 ] && OUT_TTY=true
interactive() { [ -t 0 ] && [ "$OUT_TTY" = true ] && [ "$NOPICK" = false ] && { : </dev/tty; } 2>/dev/null; }
tty_size() { # → "행 열" (모르면 빈 값)
  local s=""
  if { : </dev/tty; } 2>/dev/null; then s="$(stty size </dev/tty 2>/dev/null)"; fi
  case "$s" in [0-9]*' '[0-9]*) echo "$s" ;; *) echo "" ;; esac
}
term_width() {
  local s w=""
  if [ -n "$WIDTH" ]; then echo "$WIDTH"; return; fi
  if [ "$OUT_TTY" = true ]; then s="$(tty_size)"; w="${s#* }"; fi
  case "$w" in ''|*[!0-9]*) w="" ;; esac
  [ -z "$w" ] && case "${COLUMNS:-}" in ''|*[!0-9]*) ;; *) w="$COLUMNS" ;; esac
  [ -z "$w" ] && [ "$OUT_TTY" = true ] && w="$(tput cols 2>/dev/null)"
  case "$w" in ''|0|*[!0-9]*) w=80 ;; esac
  echo "$w"
}
term_rows() { local s; s="$(tty_size)"; s="${s%% *}"; case "$s" in ''|*[!0-9]*) echo 24 ;; *) echo "$s" ;; esac; }
use_color() {
  case "$COLOR" in always) return 0 ;; never) return 1 ;; esac
  [ "$OUT_TTY" = true ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]
}
use_ascii() {
  [ "$ASCII" = true ] && return 0
  local l="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  case "$l" in '') return 1 ;; *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) return 1 ;; *) return 0 ;; esac
}
# 모호 폭 글자(· … ─)를 터미널이 몇 칸으로 그리는지 커서 위치로 묻는다
AMB=""
ambiguous_width() {
  [ -n "$AMB" ] && { echo "$AMB"; return; }
  case "${PLUGIN_BROWSER_AMBIGUOUS:-}" in 1|2) AMB="$PLUGIN_BROWSER_AMBIGUOUS"; echo "$AMB"; return ;; esac
  AMB=1
  if [ "$OUT_TTY" = true ] && ! use_ascii && { : </dev/tty; } 2>/dev/null; then
    local old resp=""
    old="$(stty -g </dev/tty 2>/dev/null)"
    if [ -n "$old" ]; then
      stty -echo -icanon min 0 time 5 </dev/tty 2>/dev/null
      printf '\r\302\267\033[6n' >/dev/tty
      IFS= read -r -d R -t 1 resp </dev/tty
      stty "$old" </dev/tty 2>/dev/null
      printf '\r\033[K' >/dev/tty
      [ "${resp##*;}" = 3 ] && AMB=2
    fi
  fi
  echo "$AMB"
}

render_opts() { # $1=폭
  jq -cn --argjson width "$1" --argjson amb "$(ambiguous_width)" --argjson ascii "$(use_ascii && echo true || echo false)" \
    --argjson color "$(use_color && echo true || echo false)" '
    { width: $width, amb: $amb, ascii: $ascii, color: $color,
      ell: (if $ascii then ".." else "⋯" end), ok: (if $ascii then "*" else "✓" end),
      cursor: (if $ascii then ">" else "❯" end), sep: (if $ascii or $amb == 2 then " | " else " · " end),
      rulech: (if $ascii then "-" else "─" end) }'
}

# ---- 그리기 (jq) -------------------------------------------------------------
read -r -d '' RJQ <<'JQ'
def inr($r): . as $c
  | {lo: 0, hi: (($r | length) - 1), f: false}
  | until(.f or .lo > .hi; ((.lo + .hi) / 2 | floor) as $m
      | if $c < $r[$m][0] then .hi = $m - 1 elif $c > $r[$m][1] then .lo = $m + 1 else .f = true end)
  | .f;
def cw: if . < 32 then 0 elif . < 127 then 1 elif . < 160 then 0 elif . >= 44032 and . <= 55203 then 2
  elif inr($wt[0].zero) then 0 elif inr($wt[0].wide) then 2 elif inr($wt[0].ambiguous) then $o.amb else 1 end;
def clean: tostring | gsub("[\u0001-\u001f\u007f-\u009f]+"; " ");
def dw: [explode[] | cw] | add // 0;
def sp($k): if $k > 0 then " " * $k else "" end;
def rep($s; $k): if $k > 0 then $s * $k else "" end;
def trunc($n):
  clean as $s
  | if $n <= 0 then ""
    else ([$s | explode[] | [., cw]]) as $cs
    | if ([$cs[][1]] | add // 0) <= $n then $s
      else ($o.ell | dw) as $ew
      | if $n < $ew then rep("."; $n)
        else (reduce $cs[] as $c ({w: 0, out: [], stop: false};
                if .stop then . elif .w + $c[1] > ($n - $ew) then .stop = true else .w += $c[1] | .out += [$c[0]] end))
             | (.out | implode) + $o.ell end end end;
def fit($n): trunc($n) as $t | $t + sp($n - ($t | dw));
def rfit($n): trunc($n) as $t | sp($n - ($t | dw)) + $t;
def wrap($n):
  if $n <= 0 then [] else
    reduce (clean | split(" ")[] | select(length > 0)) as $w ({lines: [], cur: "", cw: 0};
      ($w | dw) as $ww
      | if $ww > $n then
          (if .cw > 0 then .lines += [.cur] | .cur = "" | .cw = 0 else . end)
          | reduce ($w | explode[]) as $c (.; ([$c] | implode) as $ch | ($c | cw) as $k
              | if .cw + $k > $n then .lines += [.cur] | .cur = $ch | .cw = $k else .cur += $ch | .cw += $k end)
        elif .cw == 0 then .cur = $w | .cw = $ww
        elif .cw + 1 + $ww <= $n then .cur += " " + $w | .cw += 1 + $ww
        else .lines += [.cur] | .cur = $w | .cw = $ww end)
    | .lines + (if .cw > 0 then [.cur] else [] end) end;
def wrapmax($n; $m): wrap($n) as $l | if ($l | length) <= $m then $l else $l[:$m - 1] + [($l[$m - 1:] | join(" ") | trunc($n))] end;
def c($code): if $o.color then "\u001b[" + $code + "m" + . + "\u001b[0m" else . end;
def dim: c("2");
def bold: c("1");
def rule($n): ($o.rulech | dw) as $k | rep($o.rulech; ($n / $k | floor)) | dim;
def missing: .status == "missing" or .status == "unknown-plugin" or .status == "marketplace-missing";
def mark:
  if (.group == "declared" or .group == "dependency") and missing then "!" | c("31")
  elif .status == "off" or .status == "disabled" or (.installed and .enabled == false) then "-" | dim
  elif .installed then $o.ok | c("32")
  else " " end;
def why_s: (.why // []) | map(clean) | join("; ");
def tags_s: (.tags // []) | join(",");
def mp_tags: ([.marketplace] + (if (.tags // []) | length > 0 then [tags_s] else [] end)) | join($o.sep);
def glabel: {declared: "필수 · 프로젝트 설정에 선언", dependency: "필수 · 선언된 플러그인의 의존", recommended: "추천 · 파일 신호",
  match: "직접 일치", related: "연관"}[. // ""] // null;
def segments: reduce .[] as $x ([]; if length > 0 and (.[-1][0].group // "") == ($x.group // "") then .[-1] += [$x] else . + [[$x]] end);
def W: ($o.width - 1) | if . < 9 then 9 else . end;

def title:
  if .command == "search" then
    "검색 " + ((.terms // []) | join(" ")) + (if (.excluded // []) | length > 0 then " " + (.excluded | join(" ")) else "" end)
      + (if (.filters // []) | length > 0 then " " + (.filters | join(" ")) else "" end)
  elif .command == "related" then "연관 " + (.target // "") + (if .mode == "feature" then " (기능어)" else "" end)
  elif .command == "project" then "프로젝트 " + ((.root // "") | split("/") | last)
  elif .command == "installed" then "설치된 플러그인"
  else "플러그인" end;
def counts_s: (.results | length) as $n
  | if (.total // $n) > $n then "\(.total)개 중 \($n)개" else "\($n)개" end;
def subtitle:
  if .command == "project" then
    ["필수 \(.summary.declared) · 없음 \(.summary.missing) · 추천 \(.summary.recommended)",
     ("신호 " + (if (.signals | length) > 0 then (.signals | map(.label) | join($o.sep)) else "없음 — 파일로 알 수 있는 것이 없습니다" end))]
  elif .relaxed == true then ["모든 단어에 맞는 결과가 없어 일부만 맞는 결과입니다"]
  elif .ambiguous != null then ["같은 이름이 여러 마켓에 있습니다: " + (.ambiguous | join(", "))]
  else [] end;

def cols($rs; $w):
  ($rs | map(.rank | tostring | length) | max // 1) as $rw
  | ([$rs[] | .name | dw] | max // 4) as $nmax
  | ([$rs[] | .marketplace | dw] | max // 4) as $mmax
  | ([$rs[] | tags_s | dw] | max // 0) as $tmax
  | ([$rs[] | why_s | dw] | max // 0) as $ymax
  | {rw: $rw, nw: ([[$nmax, 30] | min, 4] | max), mw: ([[$mmax, 20] | min, 4] | max),
     tw: (if $o.width >= 120 and $tmax > 0 then ([[$tmax, 14] | min, 4] | max) else 0 end),
     yw: (if $o.width >= 120 and $ymax > 0 then ([[$ymax, 26] | min, 4] | max) else 0 end)}
  | .fixed = (.rw + 3 + .nw + 2 + .mw + (if .tw > 0 then .tw + 2 else 0 end) + (if .yw > 0 then .yw + 2 else 0 end) + 2)
  | if $w - .fixed < 16 and .tw > 0 then .fixed -= .tw + 2 | .tw = 0 else . end
  | if $w - .fixed < 16 and .yw > 0 then .fixed -= .yw + 2 | .yw = 0 else . end
  | .dw = ([$w - .fixed, 0] | max);
def trow($k):
  (.rank | tostring | rfit($k.rw)) + " " + mark + " " + (.name | fit($k.nw) | bold) + "  " + (.marketplace | fit($k.mw) | dim)
  + (if $k.tw > 0 then "  " + (tags_s | fit($k.tw)) else "" end)
  + (if $k.yw > 0 then "  " + (why_s | fit($k.yw) | c("36")) else "" end)
  + "  " + (.description | trunc($k.dw));
def thead($k):
  (("#" | rfit($k.rw)) + "   " + ("이름" | fit($k.nw)) + "  " + ("마켓" | fit($k.mw))
   + (if $k.tw > 0 then "  " + ("태그" | fit($k.tw)) else "" end)
   + (if $k.yw > 0 then "  " + ("이유" | fit($k.yw)) else "" end)
   + "  " + ("설명" | trunc($k.dw))) | dim;
def crow($k; $w):
  ([$k.nw, 28, ($w / 3 | floor)] | min) as $nw
  | (.rank | tostring | rfit($k.rw)) + " " + mark + " " + (.name | fit($nw) | bold) + "  "
    + (.description | trunc($w - $k.rw - 3 - $nw - 2));
def card($k; $w):
  ($k.rw + 3) as $ind
  | [ (.rank | tostring | rfit($k.rw)) + " " + mark + " " + (.name | trunc($w - $ind) | bold),
      sp($ind) + (mp_tags | trunc($w - $ind) | dim) ]
    + (if (.description | length) > 0 then [.description | wrapmax($w - $ind; 2)[] | sp($ind) + .] else [] end)
    + (if (why_s | length) > 0 then [sp($ind) + (why_s | trunc($w - $ind) | c("36"))] else [] end)
    + [""];
def lrow($k; $w):
  [ (.rank | tostring | rfit($k.rw)) + " " + mark + " " + (.name | trunc($w - $k.rw - 3) | bold) ]
  + (if $w >= 24 and (.description | length) > 0 then [sp($k.rw + 3) + (.description | trunc($w - $k.rw - 3) | dim)] else [] end);
def layout($w): if $o.width >= 100 then "table" elif $o.width >= 70 then "compact" elif $o.width >= 40 then "card" else "list" end;

def render_list:
  W as $w | (.results // []) as $rs | cols($rs; $w) as $k | layout($w) as $l | (.command == "project" or .command == "related") as $grouped
  | counts_s as $cnt
  | [ ((title | trunc($w - ($cnt | dw) - 2) | bold) + "  " + ($cnt | trunc($w - 2) | dim)),
      (subtitle[] | trunc($w) | dim),
      rule($w),
      (if ($rs | length) == 0 then "결과가 없습니다" | trunc($w) else empty end),
      (if $l == "table" and ($rs | length) > 0 then thead($k) else empty end),
      ( $rs | segments[] | . as $seg
        | (if $grouped and (.[0].group | glabel) != null then (if $l == "card" or $l == "list" then "" else empty end), ("▸ " + (.[0].group | glabel) | if $o.ascii then sub("^▸"; ">") else . end | trunc($w) | bold) else empty end),
          ( .[] | if $l == "table" then trow($k) elif $l == "compact" then crow($k; $w) elif $l == "card" then card($k; $w)[] else lrow($k; $w)[] end ) ) ]
  | .[];

def hint($w):
  [ rule($w),
    ("번호로 설치  --select 1,3-5 · 전부 --install-all · 범위 --scope user" | trunc($w) | dim) ][];

def render_show:
  W as $w | . as $p
  | def kv($k; $v): ($v | tostring) as $s | if ($s | length) == 0 then empty else
      ([$s | wrap($w - 10)[]] | to_entries[] | (if .key == 0 then ($k | fit(8) | dim) + "  " else sp(10) end) + .value) end;
    def comp($k; $label): ($p.components[$k] // []) as $cs | if ($cs | length) == 0 then empty else
      ($label + " \($cs | length)" | bold),
      ($cs[] | (if type == "string" then {n: ., d: ""} else {n: (.name // ""), d: (.description // "")} end)
        | (.n | trunc($w - 2)) as $t
        | "  " + ($t | bold) + (if .d != "" and $w - 4 - ($t | dw) > 4 then "  " + (.d | trunc($w - 4 - ($t | dw)) | dim) else "" end)) end;
  [ ((.name // "") + "@" + (.marketplace // "") | trunc($w) | bold),
    (([("v" + (.version // "?")), (if .installed then $o.ok + " 설치됨 (" + (.scopes | join(",")) + ")" else "설치 안 됨" end)]
      + (if .installCount then ["설치 수 \(.installCount)"] else [] end)) | join($o.sep) | trunc($w) | dim),
    rule($w),
    (.description | wrap($w)[]),
    "",
    kv("태그"; (.tags // []) | join(", ")),
    kv("키워드"; (.keywords // []) | join(", ")),
    kv("카테고리"; .category // ""),
    kv("의존"; (.dependencies // []) | join(", ")),
    kv("역의존"; (.dependents // []) | join(", ")),
    kv("제작"; .author // ""),
    kv("홈"; .homepage // ""),
    (if .componentsKnown == false then "구성요소를 모릅니다 — 원격 소스이고 설치 전" | trunc($w) | dim else empty end),
    comp("skills"; "스킬"), comp("commands"; "커맨드"), comp("agents"; "에이전트"),
    comp("hooks"; "훅"), comp("mcp"; "MCP"), comp("lsp"; "LSP") ] | .[];

def render_facets:
  W as $w | . as $f
  | [ ("관점별 개수 · 플러그인 \(.total)개" | trunc($w) | bold), rule($w),
      ( ["tag", "category", "marketplace", "has", "installed", "keyword"][] as $k | select($f[$k] != null) | $f[$k] as $vs
        | {tag: "태그", category: "카테고리", marketplace: "마켓", has: "구성요소", installed: "설치", keyword: "키워드"}[$k] as $label
        | "", ($label | bold),
          ( ($vs | to_entries | map({n: (.key + 1), t: ((.value.value | clean) + " " + (.value.count | tostring))})) as $items
            | ([$items[] | .t | dw] | max // 1) as $cw
            | ([(($w) / ($cw + 6) | floor), 1] | max) as $ncol
            | [range(0; ($items | length); $ncol) as $i | $items[$i:$i + $ncol]]
            | .[] | "  " + (map(("\(.n)" | rfit(3)) + " " + (.t | fit($cw))) | join("  ")) | trunc($w) ) ) ] | .[];

def render_install:
  W as $w
  | [ ((if .mode == "dry-run" then "설치 계획" elif .mode == "list-only" then "조회만" else "설치 결과" end) + (if .scope then " · 범위 " + .scope else "" end) | trunc($w) | bold),
      rule($w),
      ( .results[] | (if .status == "installed" then $o.ok | c("32") elif .status == "failed" then "x" | c("31") elif .status == "skipped" then "-" | dim else " " end)
          + " " + (.id | fit([30, ($w / 2 | floor)] | min) | bold) + "  "
          + (({installed: "설치됨", skipped: "건너뜀", failed: "실패", planned: "예정", listed: "조회"}[.status] // .status) + " " + (.message // "") | trunc($w - 3 - ([30, ($w / 2 | floor)] | min) - 2)) ),
      (if .restartRequired then "", ("Claude Code 를 다시 시작해야 새 플러그인이 로드됩니다" | trunc($w) | c("33")) else empty end),
      (if .message then .message | trunc($w) | dim else empty end) ] | .[];

# 대화형 선택용 — 항목마다 R(한 줄) 과 D(상세 줄들)
def pickrows($w):
  (.results // []) as $rs | cols($rs; $w) as $k
  | $rs[]
  | ($w - 8) as $cw
  | (if $cw >= 90 then (.name | fit([$k.nw, 30] | min) | bold) + "  " + (.marketplace | fit([$k.mw, 18] | min) | dim) + "  " + (.description | trunc($cw - ([$k.nw, 30] | min) - ([$k.mw, 18] | min) - 4))
     elif $cw >= 34 then ([$k.nw, 26, ($cw / 2 | floor)] | min) as $nw | (.name | fit($nw) | bold) + "  " + (.description | trunc($cw - $nw - 2))
     else .name | trunc($cw) | bold end) as $row
  | "R\t" + mark + " " + $row,
    ( [ (.description | wrapmax($w - 2; 2)[]),
        (if (why_s | length) > 0 then why_s | trunc($w - 2) | c("36") else empty end),
        (([.id] + (if (.tags // []) | length > 0 then [tags_s] else [] end)) | join($o.sep) | trunc($w - 2) | dim) ][] | "D\t  " + . );
JQ

render() { # $1=jq 진입점 $2=폭, 입력은 stdin
  jq -r --slurpfile wt "$WIDTHS" --argjson o "$(render_opts "$2")" "$RJQ
$1"
}

# ---- 엔진 호출 ---------------------------------------------------------------
ENGINE=""
engine() { [ -n "$ENGINE" ] || ENGINE="$(find_engine)" || exit 2; "$ENGINE" "$@"; }
run_query() { # $1=명령, 나머지=엔진 인자 → $TMP/res.json
  local cmd="$1"; shift
  local err="$TMP/err"
  if ! engine "$cmd" "$@" --format json > "$TMP/res.json" 2> "$err"; then
    sed 's/^plugin-search-install: //' "$err" >&2
    return 2
  fi
}

# ---- 설치 --------------------------------------------------------------------
do_install() { # $1=선택 (번호 목록 또는 all) $2=범위
  local args=(install --from "$TMP/res.json" --scope "${2:-project}" --format json) code
  if [ "$1" = all ]; then args+=(--all); else args+=(--select "$1"); fi
  [ "$DRY" = true ] && args+=(--dry-run)
  engine "${args[@]}" > "$TMP/inst.json" 2> "$TMP/err"; code=$?
  if [ $code -eq 2 ]; then sed 's/^plugin-search-install: //' "$TMP/err" >&2; return 2; fi
  render render_install "$(term_width)" < "$TMP/inst.json"
  return $code
}

ask() { # $1=프롬프트 → 답 (stdout)
  local a=""
  printf '%s' "$1" >/dev/tty
  IFS= read -r a </dev/tty || a="q"
  printf '%s' "$a"
}
ask_scope() {
  [ -n "$SCOPE" ] && { echo "$SCOPE"; return 0; }
  local a; a="$(ask "범위 — Enter: project (팀 공유) · u: user (나만) · l: local · q: 취소 › ")"
  case "$a" in ''|p|project) echo project ;; u|user) echo user ;; l|local) echo local ;; *) return 1 ;; esac
}
confirm_install() { # $1=선택
  local w names scope
  w="$(term_width)"
  if [ "$1" = all ]; then names="$(jq -r '.results[] | .id' "$TMP/res.json")"
  else names="$(engine install --from "$TMP/res.json" --select "$1" --dry-run --format ids 2>/dev/null)"; fi
  [ -n "$names" ] || { echo "고른 플러그인이 없습니다 — 조회만 했습니다"; return 0; }
  printf '\n설치할 플러그인 %s개\n' "$(printf '%s\n' "$names" | wc -l | tr -d ' ')"
  printf '%s\n' "$names" | jq -R . | jq -sc '{results: map({id: ., name: (split("@")[0]), marketplace: (split("@")[1:] | join("@")), rank: 0, description: ""})}' \
    | render '(.results[] | "  " + (.id | trunc(W - 2)))' "$w"
  scope="$(ask_scope)" || { echo "취소했습니다"; return 0; }
  do_install "$1" "$scope"
}

# 번호 입력 모드 — 작은 창 · --plain
numbered_pick() {
  local a
  while :; do
    a="$(ask "설치할 번호 (예: 1,3-5 · a = 전부 · Enter = 조회만) › ")"
    case "$a" in
      '') return 0 ;;
      q|Q) return 0 ;;
      a|A|all) confirm_install all; return $? ;;
      *[!0-9,\ -]*) echo "번호 · 쉼표 · 하이픈만 쓸 수 있습니다" ;;
      *) if engine install --from "$TMP/res.json" --select "${a// /}" --dry-run --format ids >/dev/null 2> "$TMP/err"; then
           confirm_install "${a// /}"; return $?
         fi
         sed 's/^plugin-search-install: //' "$TMP/err" ;;
    esac
  done
}

# ---- 대화형 선택 -------------------------------------------------------------
ROWS=() DETAILS=() SEL=() RANKS=() N=0 CUR=0 TOP=0 PW=0
load_pick() { # $1=폭
  ROWS=() DETAILS=() RANKS=()
  local kind line i=-1
  while IFS=$'\t' read -r kind line; do
    if [ "$kind" = R ]; then i=$((i + 1)); ROWS[$i]="$line"; DETAILS[$i]=""
    else DETAILS[$i]="${DETAILS[$i]}${line}"$'\036'; fi
  done < <(render "pickrows($(( $1 - 1 )))" "$1" < "$TMP/res.json")
  while IFS= read -r line; do RANKS+=("$line"); done < <(jq -r '.results[].rank' "$TMP/res.json")
  N=${#ROWS[@]}
}
draw() { # $1=행 $2=열
  local h="$1" w=$(( $2 - 1 )) frame="" i line detail_h=0 list_h sel_n=0 title cur_mark on off
  [ "$h" -ge 14 ] && detail_h=4
  list_h=$(( h - 4 - (detail_h > 0 ? detail_h + 1 : 0) ))
  [ $CUR -lt $TOP ] && TOP=$CUR
  [ $CUR -ge $((TOP + list_h)) ] && TOP=$((CUR - list_h + 1))
  for i in ${SEL+"${SEL[@]}"}; do [ "$i" = 1 ] && sel_n=$((sel_n + 1)); done
  title="선택 $sel_n / $N"
  on='[x]' off='[ ]'
  frame+=$'\033[H'"$(printf '%s' "$TITLE_LINE")"$'\033[K\n'
  frame+="$title"$'\033[K\n'
  frame+="$RULE"$'\033[K\n'
  for ((i = TOP; i < TOP + list_h; i++)); do
    if [ $i -lt $N ]; then
      if [ $i -eq $CUR ]; then cur_mark="$CURSOR "; else cur_mark="  "; fi
      if [ "${SEL[$i]}" = 1 ]; then line="$cur_mark$on ${ROWS[$i]}"; else line="$cur_mark$off ${ROWS[$i]}"; fi
      if [ $i -eq $CUR ] && use_color; then line=$'\033[7m'"$line"$'\033[0m'; fi
      frame+="$line"
    fi
    frame+=$'\033[K\n'
  done
  if [ $detail_h -gt 0 ]; then
    frame+="$RULE"$'\033[K\n'
    local d="${DETAILS[$CUR]:-}" k=0
    while [ $k -lt $detail_h ]; do
      line="${d%%$'\036'*}"
      if [ -n "$d" ]; then frame+="$line"; d="${d#*$'\036'}"; fi
      frame+=$'\033[K\n'; k=$((k + 1))
    done
  fi
  frame+="$HELP_LINE"$'\033[K'
  printf '%s' "$frame" >/dev/tty
}
pick() { # 결과: PICKED (번호 목록) · 반환 0 확정 · 1 취소
  local size rows cols prev="" key k2 rc dirty=1 i t0 eofs=0
  PICKED=""
  TTY_OLD="$(stty -g </dev/tty 2>/dev/null)"
  stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null
  printf '\033[?1049h\033[?25l' >/dev/tty
  local total; total="$(jq '.results | length' "$TMP/res.json")"
  SEL=(); for ((i = 0; i < total; i++)); do SEL[$i]=0; done
  # 프로젝트 조회면 필수 중 없는 것을 미리 고른다
  i=0; while IFS= read -r k2; do [ "$k2" = true ] && SEL[$i]=1; i=$((i + 1)); done \
    < <(jq -r '.results[] | ((.group == "declared" or .group == "dependency") and .status == "missing") | tostring' "$TMP/res.json")
  CUR=0 TOP=0
  while :; do
    size="$(tty_size)"; rows="${size%% *}"; cols="${size#* }"
    case "$rows$cols" in ''|*[!0-9]*) rows=24 cols=80 ;; esac
    [ -n "$WIDTH" ] && cols="$WIDTH"
    if [ "$size" != "$prev" ]; then
      prev="$size"; dirty=1
      if [ "$rows" -lt 8 ] || [ "$cols" -lt 24 ]; then
        printf '\033[?25h\033[?1049l' >/dev/tty; stty "$TTY_OLD" </dev/tty; TTY_OLD=""
        return 2
      fi
      load_pick "$cols"
      TITLE_LINE="$(render '(title + "  " + counts_s) | trunc(W) | bold' "$cols" < "$TMP/res.json")"
      RULE="$(render 'rule(W)' "$cols" <<<'null')"
      CURSOR="$(render '$o.cursor' "$cols" <<<'null')"
      HELP_LINE="$(render '"↑↓ 이동 · Space 선택 · a 전부 · n 해제 · i 반전 · Enter 설치 · q 취소" | if $o.ascii then gsub("↑↓"; "j/k") else . end | trunc(W) | dim' "$cols" <<<'null')"
      printf '\033[2J' >/dev/tty
    fi
    [ $dirty -eq 1 ] && { draw "$rows" "$cols"; dirty=0; }
    # bash 3.2 는 시간 초과와 EOF 가 둘 다 1 이다 — 곧바로 돌아오면 EOF 로 본다
    key=""; t0=$SECONDS; IFS= read -rsn1 -t 1 key </dev/tty; rc=$?
    if [ $rc -ne 0 ] && [ -z "$key" ]; then
      if [ $rc -le 128 ] && [ $SECONDS -eq $t0 ]; then eofs=$((eofs + 1)); [ $eofs -ge 3 ] && break; else eofs=0; fi
      continue
    fi
    eofs=0 dirty=1
    case "$key" in
      $'\033')
        k2=""; IFS= read -rsn2 -t 1 k2 </dev/tty
        case "$k2" in
          '[A'|'OA') [ $CUR -gt 0 ] && CUR=$((CUR - 1)) ;;
          '[B'|'OB') [ $CUR -lt $((N - 1)) ] && CUR=$((CUR + 1)) ;;
          '[5') IFS= read -rsn1 -t 1 _ </dev/tty; CUR=$((CUR - rows + 6)); [ $CUR -lt 0 ] && CUR=0 ;;
          '[6') IFS= read -rsn1 -t 1 _ </dev/tty; CUR=$((CUR + rows - 6)); [ $CUR -ge $N ] && CUR=$((N - 1)) ;;
          '[H'|'OH') CUR=0 ;;
          '[F'|'OF') CUR=$((N - 1)) ;;
          '') break ;;
        esac ;;
      k) [ $CUR -gt 0 ] && CUR=$((CUR - 1)) ;;
      j) [ $CUR -lt $((N - 1)) ] && CUR=$((CUR + 1)) ;;
      g) CUR=0 ;;
      G) CUR=$((N - 1)) ;;
      ' ') if [ "${SEL[$CUR]}" = 1 ]; then SEL[$CUR]=0; else SEL[$CUR]=1; fi ;;
      a) for ((i = 0; i < N; i++)); do SEL[$i]=1; done ;;
      n) for ((i = 0; i < N; i++)); do SEL[$i]=0; done ;;
      i) for ((i = 0; i < N; i++)); do if [ "${SEL[$i]}" = 1 ]; then SEL[$i]=0; else SEL[$i]=1; fi; done ;;
      ''|$'\n'|$'\r')
        for ((i = 0; i < N; i++)); do [ "${SEL[$i]}" = 1 ] && PICKED="$PICKED,${RANKS[$i]}"; done
        PICKED="${PICKED#,}"
        printf '\033[?25h\033[?1049l' >/dev/tty; stty "$TTY_OLD" </dev/tty; TTY_OLD=""
        return 0 ;;
      q|Q) break ;;
    esac
  done
  printf '\033[?25h\033[?1049l' >/dev/tty; stty "$TTY_OLD" </dev/tty; TTY_OLD=""
  return 1
}

# ---- 결과 보이기 --------------------------------------------------------------
show_results() { # 엔진 결과($TMP/res.json)를 그리고, 설치 방식을 고른다
  local w n
  w="$(term_width)"
  n="$(jq '.results | length' "$TMP/res.json")"
  if [ -n "${SELECT//,/}" ] || [ "$INSTALL_ALL" = true ]; then
    render render_list "$w" < "$TMP/res.json"; echo
    if [ "$INSTALL_ALL" = true ]; then do_install all "${SCOPE:-project}"; else do_install "${SELECT#,}" "${SCOPE:-project}"; fi
    return $?
  fi
  if [ "$n" -eq 0 ] || ! interactive; then
    render render_list "$w" < "$TMP/res.json"
    [ "$n" -gt 0 ] && render 'hint(W)' "$w" <<<'null'
    return 0
  fi
  if [ "$PLAIN" = false ]; then
    pick; case $? in
      0) if [ -n "$PICKED" ]; then confirm_install "$PICKED"; return $?; fi
         echo "고른 플러그인이 없습니다 — 조회만 했습니다"; return 0 ;;
      1) echo "취소했습니다 — 조회만 했습니다"; return 0 ;;
    esac
  fi
  render render_list "$w" < "$TMP/res.json"
  echo
  numbered_pick
}

# ---- 메뉴 --------------------------------------------------------------------
menu() {
  local a q w
  while :; do
    w="$(term_width)"
    jq -n '[ "플러그인 찾기", "", "  1  이 프로젝트에 필요한 플러그인", "  2  기능으로 검색", "  3  연관 플러그인 (플러그인 이름 또는 기능어)",
             "  4  태그로 둘러보기", "  5  설치된 플러그인", "  q  끝내기" ]' | render '.[0] as $t | ($t | trunc(W) | bold), rule(W), (.[1:][] | trunc(W))' "$w"
    a="$(ask "› ")"
    case "$a" in
      1) run_query project . ${ENGINE_ARGS+"${ENGINE_ARGS[@]}"} && show_results ;;
      2) q="$(ask "검색어 (예: 테스트 커버리지 · tag:spring · -java) › ")"
         [ -n "$q" ] && { set -f; run_query search $q ${ENGINE_ARGS+"${ENGINE_ARGS[@]}"}; local c=$?; set +f; [ $c -eq 0 ] && show_results; } ;;
      3) q="$(ask "플러그인 이름 또는 기능어 › ")"
         [ -n "$q" ] && { set -f; run_query related $q ${ENGINE_ARGS+"${ENGINE_ARGS[@]}"}; local c=$?; set +f; [ $c -eq 0 ] && show_results; } ;;
      4) engine facets tag > "$TMP/facets.json" 2>/dev/null || { echo "태그를 읽지 못했습니다"; continue; }
         render render_facets "$w" < "$TMP/facets.json"
         q="$(ask "태그 번호 › ")"
         case "$q" in ''|*[!0-9]*) ;; *)
           q="$(jq -r --argjson n "$q" '.tag[$n - 1].value // empty' "$TMP/facets.json")"
           [ -n "$q" ] && run_query search --tag "$q" --limit 0 && show_results ;; esac ;;
      5) run_query search --installed --sort name --limit 0 && show_results ;;
      q|Q|'') return 0 ;;
      *) echo "1 ~ 5 또는 q" ;;
    esac
    echo
  done
}

# ---- 진입점 ------------------------------------------------------------------
cmd="${1:-}"
case "$cmd" in -h|--help|help) usage; exit 0 ;; -*) cmd="" ;; *) [ $# -gt 0 ] && shift ;; esac
parse_opts "$@"
AMB="$(ambiguous_width)"
W_NOW="$(term_width)"

case "$cmd" in
  '')
    if interactive; then menu; exit $?; fi
    usage; exit 0 ;;
  search|related)
    [ ${#ENGINE_ARGS[@]} -gt 0 ] || die "$cmd 에 질의가 필요합니다"
    run_query "$cmd" "${ENGINE_ARGS[@]}" || exit 2
    show_results ;;
  project)
    run_query project ${ENGINE_ARGS+"${ENGINE_ARGS[@]}"} || exit 2
    show_results ;;
  installed)
    run_query search --installed --sort name --limit 0 ${ENGINE_ARGS+"${ENGINE_ARGS[@]}"} || exit 2
    show_results ;;
  show)
    [ ${#ENGINE_ARGS[@]} -gt 0 ] || die "show 에 플러그인이 필요합니다"
    engine show "${ENGINE_ARGS[@]}" > "$TMP/show.json" 2> "$TMP/err" || { sed 's/^plugin-search-install: //' "$TMP/err" >&2; exit 2; }
    if jq -e '.ambiguous' "$TMP/show.json" >/dev/null; then
      jq '.plugins[0]' "$TMP/show.json" > "$TMP/one.json"
      render render_show "$W_NOW" < "$TMP/one.json"
      echo "같은 이름: $(jq -r '.ambiguous | join(", ")' "$TMP/show.json") — 이름@마켓 으로 고르세요"
    else render render_show "$W_NOW" < "$TMP/show.json"; fi ;;
  facets)
    engine facets ${ENGINE_ARGS+"${ENGINE_ARGS[@]}"} > "$TMP/facets.json" 2> "$TMP/err" || { sed 's/^plugin-search-install: //' "$TMP/err" >&2; exit 2; }
    render render_facets "$W_NOW" < "$TMP/facets.json" ;;
  render)
    src="${ENGINE_ARGS[0]:--}"
    if [ "$src" = - ]; then cat > "$TMP/res.json"; else [ -r "$src" ] || die "읽을 수 없습니다: $src"; cp "$src" "$TMP/res.json"; fi
    jq -e . "$TMP/res.json" >/dev/null 2>&1 || die "JSON 이 아닙니다"
    if jq -e '.command == "install"' "$TMP/res.json" >/dev/null; then render render_install "$W_NOW" < "$TMP/res.json"
    elif jq -e 'has("results")' "$TMP/res.json" >/dev/null; then render render_list "$W_NOW" < "$TMP/res.json"
    elif jq -e 'has("total") and has("tag")' "$TMP/res.json" >/dev/null; then render render_facets "$W_NOW" < "$TMP/res.json"
    else render render_show "$W_NOW" < "$TMP/res.json"; fi ;;
  *) die "모르는 명령: $cmd (--help)" ;;
esac
