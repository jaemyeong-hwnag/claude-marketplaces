#!/usr/bin/env bash
# plugin-search-install — 등록된 마켓플레이스의 플러그인을 조회하고 설치한다. 화면을 모른다 — 출력은 json · tsv · ids · names.
#
#   catalog  [--refresh]                                    카탈로그 전체
#   search   <질의…>                                         기능 검색
#   related  <플러그인 | 기능어> [--by 관계,…]                 연관 조회
#   project  [디렉터리] [--only declared|missing|recommended]  프로젝트에 필요한 플러그인
#   detect   [디렉터리]                                      프로젝트 신호 · 선언 (JSON)
#   show     <플러그인>                                      한 플러그인 상세 (JSON)
#   facets   [tag|keyword|category|marketplace|has|installed] 관점별 개수 (JSON)
#   install  <플러그인…> | --from <파일|->  [--select 1,3-5,이름] [--exclude …] [--all] [--scope S] [--dry-run]
#
# 필터  --marketplace M · --tag T · --category C · --keyword K · --has skill|command|agent|hook|mcp|lsp
#       --installed · --not-installed · --min-score N          (쉼표로 여럿, 반복 가능)
# 검색  --any (OR) · --exact (동의어 · 부분 일치 · 오타 허용 끔) · --regex · --field f,… · --no-fuzzy
# 출력  --format json|tsv|ids|names · --limit N (0 = 전부) · --sort score|name|installs · --full
#
# 질의 문법은 references/search-rules.md. 종료 코드: 0 정상 · 1 설치 일부 실패 · 2 잘못된 입력
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$ROOT_DIR/references"
SYN="$REF/search-synonyms.json"
SIG="$REF/project-signals.json"
CLAUDE_BIN="${PLUGIN_SEARCH_CLAUDE:-claude}"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE_DIR="${PLUGIN_SEARCH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/plugin-search-install}"
CACHE_TTL_MIN="${PLUGIN_SEARCH_CACHE_TTL:-10}"

die() { echo "plugin-search-install: $*" >&2; exit 2; }
usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- 옵션 --------------------------------------------------------------------
FORMAT=json LIMIT=20 LIMIT_SET=false SORT=score FULL=false MODE=all EXACT=false REGEX=false FUZZY=true FIELDS=""
F_MP="" F_TAG="" F_CAT="" F_KW="" F_HAS="" F_INST="" MIN_SCORE="" REFRESH=false BY="" ONLY=""
SCOPE=project DRY=false FROM="" SELECT="" EXCLUDE="" ALL=false
ARGS=()

need() { [ "$2" -ge 2 ] || die "$1 에 값이 필요합니다"; }
parse_opts() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --format) need "$1" $#; FORMAT="$2"; shift 2 ;;
      --limit) need "$1" $#; LIMIT="$2"; LIMIT_SET=true; shift 2 ;;
      --sort) need "$1" $#; SORT="$2"; shift 2 ;;
      --full) FULL=true; shift ;;
      --any) MODE=any; shift ;;
      --exact) EXACT=true; shift ;;
      --regex) REGEX=true; shift ;;
      --no-fuzzy) FUZZY=false; shift ;;
      --field|--fields) need "$1" $#; FIELDS="$FIELDS,$2"; shift 2 ;;
      --marketplace|--mp) need "$1" $#; F_MP="$F_MP,$2"; shift 2 ;;
      --tag) need "$1" $#; F_TAG="$F_TAG,$2"; shift 2 ;;
      --category|--cat) need "$1" $#; F_CAT="$F_CAT,$2"; shift 2 ;;
      --keyword|--kw) need "$1" $#; F_KW="$F_KW,$2"; shift 2 ;;
      --has) need "$1" $#; F_HAS="$F_HAS,$2"; shift 2 ;;
      --installed) F_INST=true; shift ;;
      --not-installed) F_INST=false; shift ;;
      --min-score) need "$1" $#; MIN_SCORE="$2"; shift 2 ;;
      --refresh) REFRESH=true; shift ;;
      --by) need "$1" $#; BY="$BY,$2"; shift 2 ;;
      --only) need "$1" $#; ONLY="$2"; shift 2 ;;
      --scope|-s) need "$1" $#; SCOPE="$2"; shift 2 ;;
      --dry-run) DRY=true; shift ;;
      --from) need "$1" $#; FROM="$2"; shift 2 ;;
      --select) need "$1" $#; SELECT="$SELECT,$2"; shift 2 ;;
      --exclude) need "$1" $#; EXCLUDE="$EXCLUDE,$2"; shift 2 ;;
      --all) ALL=true; shift ;;
      -h|--help) usage; exit 0 ;;
      --) shift; while [ $# -gt 0 ]; do ARGS+=("$1"); shift; done ;;
      --*) die "모르는 옵션: $1 (--help)" ;;
      *) ARGS+=("$1"); shift ;;
    esac
  done
  case "$FORMAT" in json|tsv|ids|names) ;; *) die "--format 은 json · tsv · ids · names 중 하나: $FORMAT" ;; esac
  case "$SORT" in score|name|installs) ;; *) die "--sort 는 score · name · installs 중 하나: $SORT" ;; esac
  case "$LIMIT" in ''|*[!0-9]*) die "--limit 은 0 이상의 정수: $LIMIT" ;; esac
  case "$SCOPE" in user|project|local) ;; *) die "--scope 는 user · project · local 중 하나: $SCOPE" ;; esac
  case "$MIN_SCORE" in ''|[0-9]|[0-9]*[0-9]|[0-9]*.[0-9]*) ;; *) die "--min-score 는 숫자: $MIN_SCORE" ;; esac
  local h
  for h in $(printf '%s' "$F_HAS" | tr ',' ' '); do
    case "$h" in skill|command|agent|hook|mcp|lsp) ;; *) die "--has 는 skill · command · agent · hook · mcp · lsp 중 하나: $h" ;; esac
  done
  for h in $(printf '%s' "$BY" | tr ',' ' '); do
    case "$h" in dependency|dependent|tag|keyword|name|component|description|category) ;;
      *) die "--by 는 dependency · dependent · tag · keyword · name · component · description · category 중 하나: $h" ;; esac
  done
  case "$ONLY" in ''|declared|missing|recommended) ;; *) die "--only 는 declared · missing · recommended 중 하나: $ONLY" ;; esac
}

opts_json() {
  jq -cn --arg mode "$MODE" --argjson exact "$EXACT" --argjson regex "$REGEX" --argjson fuzzy "$FUZZY" \
    --arg fields "$FIELDS" --arg mp "$F_MP" --arg tag "$F_TAG" --arg cat "$F_CAT" --arg kw "$F_KW" --arg has "$F_HAS" \
    --arg inst "$F_INST" --arg min "$MIN_SCORE" --arg by "$BY" --arg only "$ONLY" --arg sort "$SORT" \
    --argjson limit "$LIMIT" --argjson full "$FULL" '
    def csv: split(",") | map(gsub("^\\s+|\\s+$"; "") | ascii_downcase) | map(select(length > 0));
    def alias: if . == "component" or . == "comp" then ("skill", "command", "agent", "hook", "mcp", "lsp")
      elif . == "tags" then "tag" elif . == "keywords" or . == "kw" then "keyword" elif . == "desc" then "description"
      elif . == "mp" then "marketplace" elif . == "cmd" then "command" else . end;
    { mode: $mode, exact: $exact, regex: $regex, fuzzy: $fuzzy,
      fields: ($fields | csv | if length == 0 then null else [.[] | alias] | unique end),
      mp: ($mp | csv), tag: ($tag | csv), cat: ($cat | csv), kw: ($kw | csv), has: ($has | csv),
      installed: (if $inst == "" then null else ($inst == "true") end),
      min: (if $min == "" then null else ($min | tonumber) end),
      by: ($by | csv), only: $only, sort: $sort, limit: $limit, full: $full }'
}

# ---- 카탈로그 ----------------------------------------------------------------
# 마켓플레이스 목록 · 설치 상태는 CLI 로, CLI 가 없으면 설정 디렉터리의 기록 파일로 읽는다.
marketplaces_json() {
  local out
  out="$("$CLAUDE_BIN" plugin marketplace list --json 2>/dev/null)"
  if jq -e 'type == "array"' >/dev/null 2>&1 <<<"$out"; then printf '%s' "$out"; return; fi
  jq -c '[to_entries[] | {name: .key, installLocation: .value.installLocation}]' "$CFG/plugins/known_marketplaces.json" 2>/dev/null || echo '[]'
}
installed_json() {
  local out
  out="$("$CLAUDE_BIN" plugin list --json --available 2>/dev/null)"
  if jq -e '.installed | type == "array"' >/dev/null 2>&1 <<<"$out"; then printf '%s' "$out"; return; fi
  out="$("$CLAUDE_BIN" plugin list --json 2>/dev/null)"
  if jq -e 'type == "array"' >/dev/null 2>&1 <<<"$out"; then jq -c '{installed: ., available: []}' <<<"$out"; return; fi
  jq -c '{installed: [(.plugins // {}) | to_entries[] | .key as $id | .value[] | {id: $id, version, scope, installPath, enabled: null}], available: []}' \
    "$CFG/plugins/installed_plugins.json" 2>/dev/null || echo '{"installed":[],"available":[]}'
}

manifest_of() { # $1=installLocation → "매니페스트\x1f루트"
  local loc="$1" root
  if [ -f "$loc" ]; then
    root="$(dirname "$loc")"; [ "$(basename "$root")" = .claude-plugin ] && root="$(dirname "$root")"
    printf '%s\037%s\n' "$loc" "$root"
  elif [ -f "$loc/.claude-plugin/marketplace.json" ]; then printf '%s\037%s\n' "$loc/.claude-plugin/marketplace.json" "$loc"
  elif [ -f "$loc/marketplace.json" ]; then printf '%s\037%s\n' "$loc/marketplace.json" "$loc"
  fi
}

# 프런트매터의 name · description → "파일\x1fname\x1fdescription"
frontmatter() {
  awk '
    function unq(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2); return s }
    function emit() { if (file != "") printf "%s\037%s\037%s\n", file, name, substr(desc, 1, 600) }
    FNR == 1 { emit(); file = FILENAME; name = ""; desc = ""; coll = 0; state = ($0 ~ /^---[ \t]*$/) ? 1 : 2; next }
    state != 1 { next }
    /^---[ \t]*$/ { state = 2; next }
    coll && /^[ \t]+[^ \t]/ { l = $0; gsub(/^[ \t]+|[ \t]+$/, "", l); desc = (desc == "") ? l : desc " " l; next }
    { coll = 0 }
    /^name:/ { v = $0; sub(/^name:/, "", v); name = unq(v); next }
    /^description:/ { v = $0; sub(/^description:/, "", v); v = unq(v); if (v == "" || v ~ /^[>|][-+]?$/) { coll = 1; desc = "" } else desc = v; next }
    END { emit() }
  ' "$@" 2>/dev/null
}

json_each() { # $1=jq 필터, 나머지=파일. 한 번에 돌리고, 깨진 파일이 있으면 하나씩 다시 돈다
  local f="$1"; shift
  [ $# -gt 0 ] || return 0
  jq -c "$f" "$@" 2>/dev/null && return 0
  local x; for x in "$@"; do jq -c "$f" "$x" 2>/dev/null; done
  return 0
}

build_catalog() { # $1=마켓플레이스 JSON $2=설치 JSON → 카탈로그 JSON 배열
  local mps="$1" inst="$2" mp loc mf root
  : > "$TMP/entries"
  while IFS=$'\037' read -r mp loc; do
    [ -n "$loc" ] || continue
    mf=""; root=""
    IFS=$'\037' read -r mf root < <(manifest_of "$loc")
    [ -n "$mf" ] || continue
    jq -c --arg mp "$mp" --arg root "$root" '
      (.metadata.pluginRoot // "" | sub("^\\./"; "") | sub("/+$"; "")) as $pr
      | .plugins[]? | select(type == "object" and (.name | type) == "string")
      | { name, marketplace: $mp, id: (.name + "@" + $mp), description: (.description // "" | tostring), version: (.version // null),
          category: (.category // null), tags: [.tags // [] | .[]? | strings], keywords: [.keywords // [] | .[]? | strings],
          author: (if (.author | type) == "object" then .author.name else .author end),
          homepage: (.homepage // null),
          sourceType: (if (.source | type) == "string" then "path" else (.source.source? // "unknown") end),
          dependencies: [.dependencies // [] | .[]? | if type == "string" then . else .name? end | strings | sub("@.*$"; "")],
          lsp: (.lspServers // {} | if type == "object" then keys else [] end),
          mcpEntry: (.mcpServers // {} | if type == "object" then keys else [] end),
          localPath: (if (.source | type) == "string" then
              (.source | if test("^\\.{1,2}(/|$)") or $pr == "" then $root + "/" + . else $root + "/" + $pr + "/" + . end)
              | gsub("/\\./"; "/") | sub("/\\.?$"; "") | sub("/+$"; "")
            else null end) }' "$mf" >> "$TMP/entries" 2>/dev/null
  done < <(jq -r '.[] | [.name, (.installLocation // "")] | join("\u001f")' <<<"$mps")

  # 구성요소를 읽을 디렉터리 — 설치본이 있으면 설치본, 없으면 마켓플레이스 안의 소스
  : > "$TMP/dirs"
  local id lp ip d dirs=()
  while IFS=$'\037' read -r id lp ip; do
    d=""
    if [ -n "$ip" ] && [ -d "$ip" ]; then d="$ip"; elif [ -n "$lp" ] && [ -d "$lp" ]; then d="$lp"; fi
    [ -n "$d" ] || continue
    printf '%s\037%s\n' "$id" "$d" >> "$TMP/dirs"; dirs+=("$d")
  done < <(jq -rn --slurpfile e "$TMP/entries" --argjson inst "$inst" '
      ($inst.installed // [] | map({key: .id, value: (.installPath // "")}) | from_entries) as $ip
      | ([$e[].id] | unique) as $known
      | (($e[] | [.id, (.localPath // ""), ($ip[.id] // "")]),
         ($inst.installed // [] | .[] | select(.id as $i | $known | index($i) | not) | [.id, "", (.installPath // "")]))
      | join("\u001f")')

  : > "$TMP/files"
  if [ ${#dirs[@]} -gt 0 ]; then
    find "${dirs[@]}" -maxdepth 3 -type f \( -path '*/skills/*/SKILL.md' -o -path '*/commands/*.md' -o -path '*/agents/*.md' \
      -o -path '*/hooks/hooks.json' -o -path '*/.claude-plugin/plugin.json' -o -name .mcp.json \) 2>/dev/null > "$TMP/files"
  fi
  local md=() pj=() hk=() mc=() f
  while IFS= read -r f; do
    case "$f" in
      *.md) md+=("$f") ;;
      */.claude-plugin/plugin.json) pj+=("$f") ;;
      */hooks/hooks.json) hk+=("$f") ;;
      */.mcp.json) mc+=("$f") ;;
    esac
  done < "$TMP/files"
  : > "$TMP/fm"
  [ ${#md[@]} -gt 0 ] && frontmatter "${md[@]}" > "$TMP/fm"
  json_each '{f: input_filename, version: (.version // null), description: (.description // null),
      keywords: [.keywords // [] | .[]? | strings], author: (if (.author | type) == "object" then .author.name else .author end),
      dependencies: [.dependencies // [] | .[]? | if type == "string" then . else .name? end | strings | sub("@.*$"; "")],
      mcp: (.mcpServers // {} | if type == "object" then keys else [] end),
      lsp: (.lspServers // {} | if type == "object" then keys else [] end)}' ${pj+"${pj[@]}"} > "$TMP/pj"
  json_each '{f: input_filename, events: (.hooks // {} | if type == "object" then keys else [] end)}' ${hk+"${hk[@]}"} > "$TMP/hk"
  json_each '{f: input_filename, servers: ((.mcpServers // .) | if type == "object" then keys else [] end)}' ${mc+"${mc[@]}"} > "$TMP/mc"

  jq -n --slurpfile e "$TMP/entries" --argjson inst "$inst" --rawfile dirs "$TMP/dirs" --rawfile fm "$TMP/fm" \
    --slurpfile pj "$TMP/pj" --slurpfile hk "$TMP/hk" --slurpfile mc "$TMP/mc" --arg cwd "$(pwd -P)" '
    def san: tostring | gsub("[\u0001-\u001f\u007f-\u009f]+"; " ") | gsub("^ +| +$"; "");
    def cut($n): if length > $n then .[:$n] else . end;
    ($dirs | split("\n") | map(select(length > 0) | split("\u001f") | {key: .[0], value: .[1]}) | from_entries) as $dirOf
    # project · local 범위 설치는 그 프로젝트에서만 쓸 수 있다
    | def here: .scope == "user" or ((.projectPath // "") as $pp | $pp == "" or $cwd == $pp or ($cwd | startswith($pp + "/")));
      ($inst.installed // [] | group_by(.id) | map({key: .[0].id, value: .}) | from_entries) as $im
    | ($inst.available // [] | map(select(.pluginId) | {key: .pluginId, value: .installCount}) | from_entries) as $cnt
    | (reduce $pj[] as $x ({}; .[$x.f | sub("/\\.claude-plugin/plugin\\.json$"; "")] = $x)) as $pjm
    | (reduce $hk[] as $x ({}; .[$x.f | sub("/hooks/hooks\\.json$"; "")] = $x.events)) as $hkm
    | (reduce $mc[] as $x ({}; .[$x.f | sub("/\\.mcp\\.json$"; "")] = $x.servers)) as $mcm
    | (reduce ($fm | split("\n")[] | select(length > 0) | split("\u001f")) as $r ({};
        ($r[0]) as $f
        | if ($f | test("/skills/[^/]+/SKILL\\.md$")) then
            ($f | capture("^(?<d>.*)/skills/(?<n>[^/]+)/SKILL\\.md$")) as $c
            | .[$c.d].skills += [{name: (if ($r[1] // "") != "" then $r[1] else $c.n end), description: ($r[2] // "" | san | cut(300))}]
          elif ($f | test("/commands/[^/]+\\.md$")) then
            ($f | capture("^(?<d>.*)/commands/(?<n>[^/]+)\\.md$")) as $c
            | .[$c.d].commands += [{name: $c.n, description: ($r[2] // "" | san | cut(300))}]
          elif ($f | test("/agents/[^/]+\\.md$")) then
            ($f | capture("^(?<d>.*)/agents/(?<n>[^/]+)\\.md$")) as $c
            | .[$c.d].agents += [{name: (if ($r[1] // "") != "" then $r[1] else $c.n end), description: ($r[2] // "" | san | cut(300))}]
          else . end)) as $mdm
    | ([$e[].id] | unique) as $known
    | ( ($e | unique_by(.id))
        + [$inst.installed // [] | .[] | select(.id as $i | $known | index($i) | not)
           | {name: (.id | split("@")[0]), marketplace: (.id | split("@")[1:] | join("@")), id, description: "", version: null,
              category: null, tags: [], keywords: [], author: null, homepage: null, sourceType: "installed",
              dependencies: [], lsp: [], mcpEntry: [], localPath: null}] | unique_by(.id) )
    | map(. as $p
        | ($dirOf[$p.id] // null) as $dir
        | (if $dir then ($pjm[$dir] // {}) else {} end) as $x
        | ($im[$p.id] // []) as $all | [$all[] | select(here)] as $is
        | (if $dir then ($mdm[$dir] // {}) else {} end) as $m
        | { id: $p.id, name: ($p.name | san), marketplace: $p.marketplace,
            description: (if ($p.description | length) > 0 then $p.description else ($x.description // "") end | san),
            version: ($x.version // $p.version), category: ($p.category | if . == null then null else san end),
            tags: ($p.tags | map(san) | unique), keywords: (($p.keywords + ($x.keywords // [])) | map(san) | unique),
            author: ($p.author // $x.author // null | if . == null then null else san end), homepage: $p.homepage,
            sourceType: $p.sourceType,
            dependencies: (($p.dependencies + ($x.dependencies // [])) | unique),
            installed: (($is | length) > 0),
            enabled: (if ($is | length) == 0 then null else any($is[]; .enabled == true or .projectEnabled == true) end),
            scopes: ([$is[].scope | strings] | unique),
            installedVersion: ($is[0].version // null),
            installedElsewhere: [$all[] | select(here | not) | .projectPath // .scope] | unique,
            installCount: ($cnt[$p.id] // null),
            componentsKnown: ($dir != null),
            components: {
              skills: ($m.skills // [] | sort_by(.name)),
              commands: ($m.commands // [] | sort_by(.name)),
              agents: ($m.agents // [] | sort_by(.name)),
              hooks: (if $dir then ($hkm[$dir] // []) else [] end),
              mcp: ((if $dir then ($mcm[$dir] // []) else [] end) + ($x.mcp // []) + $p.mcpEntry | unique),
              lsp: (($x.lsp // []) + $p.lsp | unique) },
            path: $dir })
    | sort_by(.marketplace, .name)'
}

catalog_json() {
  if [ -n "${PLUGIN_SEARCH_CATALOG:-}" ]; then
    [ -r "$PLUGIN_SEARCH_CATALOG" ] || die "PLUGIN_SEARCH_CATALOG 를 읽을 수 없습니다: $PLUGIN_SEARCH_CATALOG"
    cat "$PLUGIN_SEARCH_CATALOG"; return
  fi
  local mps inst key cache="$CACHE_DIR/catalog.json" loc mf
  mps="$(marketplaces_json)"; inst="$(installed_json)"
  key="$( { printf '%s\n%s\n%s\n' "$(pwd -P)" "$mps" "$inst"
            while IFS= read -r loc; do
              mf=""; IFS=$'\037' read -r mf _ < <(manifest_of "$loc")
              [ -n "$mf" ] && ls -ln "$mf" 2>/dev/null
            done < <(jq -r '.[].installLocation // empty' <<<"$mps"); } | cksum | tr -d ' ')"
  if [ "$REFRESH" = false ] && [ -s "$cache" ] && [ "$(cat "$cache.key" 2>/dev/null)" = "$key" ] &&
     [ -n "$(find "$cache" -mmin -"$CACHE_TTL_MIN" 2>/dev/null)" ]; then
    cat "$cache"; return
  fi
  build_catalog "$mps" "$inst" > "$TMP/catalog.json" && [ -s "$TMP/catalog.json" ] || die "카탈로그를 만들지 못했습니다"
  if mkdir -p "$CACHE_DIR" 2>/dev/null && cp "$TMP/catalog.json" "$cache.$$" 2>/dev/null; then
    mv "$cache.$$" "$cache" && printf '%s' "$key" > "$cache.key"
  fi
  cat "$TMP/catalog.json"
}
cache_drop() { rm -f "$CACHE_DIR/catalog.json.key" 2>/dev/null; }

# ---- 검색 · 연관 · 프로젝트 (jq) ---------------------------------------------
read -r -d '' JQ_LIB <<'JQ'
def san: tostring | gsub("[\u0001-\u001f\u007f-\u009f]+"; " ") | gsub("^ +| +$"; "");
def lc: ascii_downcase;
def words: lc | [splits("[^\\p{L}\\p{N}]+")] | map(select(length > 0));
def hangul: test("\\p{Hangul}");
def absv: if . < 0 then -. else . end;
def r1: . * 10 | round / 10;
def lev($a; $b):
  ($a | explode) as $s | ($b | explode) as $t | ($t | length) as $n
  | reduce range(0; $s | length) as $i ([range(0; $n + 1)];
      . as $prev
      | reduce range(0; $n) as $j ([$i + 1];
          . + [[($prev[$j + 1] + 1), (.[$j] + 1), ($prev[$j] + (if $s[$i] == $t[$j] then 0 else 1 end))] | min]))
  | .[$n];
def cdoc($k): {k: $k, n: (.name | lc), nw: (.name | words), d: (.description | lc), dw: (.description | words)};
def ndoc($k): {k: $k, n: lc, nw: words, d: "", dw: []};
def doc:
  { name: (.name | lc), nw: (.name | words),
    tags: (.tags | map(lc)), kws: (.keywords | map(lc)), kww: ([.keywords[] | words[]] | unique),
    cat: (.category // "" | lc), mp: (.marketplace | lc), mpw: (.marketplace | words),
    desc: (.description | lc), dw: (.description | words | unique),
    comps: [ (.components.skills[] | cdoc("skill")), (.components.commands[] | cdoc("command")), (.components.agents[] | cdoc("agent")),
             (.components.hooks[] | ndoc("hook")), (.components.mcp[] | ndoc("mcp")), (.components.lsp[] | ndoc("lsp")) ] };
def prep: map(. + {_d: doc});
def fieldmap: {name: ["name"], n: ["name"], desc: ["description"], description: ["description"], d: ["description"],
  tag: ["tag"], tags: ["tag"], t: ["tag"], kw: ["keyword"], keyword: ["keyword"], keywords: ["keyword"], k: ["keyword"],
  cat: ["category"], category: ["category"], mp: ["marketplace"], marketplace: ["marketplace"],
  skill: ["skill"], skills: ["skill"], cmd: ["command"], command: ["command"], agent: ["agent"], hook: ["hook"], mcp: ["mcp"], lsp: ["lsp"],
  comp: ["skill", "command", "agent", "hook", "mcp", "lsp"], component: ["skill", "command", "agent", "hook", "mcp", "lsp"]};
def kindname: {name: "이름", tag: "태그", keyword: "키워드", category: "카테고리", marketplace: "마켓", description: "설명",
  skill: "스킬", command: "커맨드", agent: "에이전트", hook: "훅", mcp: "MCP", lsp: "LSP",
  "skill-description": "스킬 설명", "command-description": "커맨드 설명", "agent-description": "에이전트 설명"}[.] // .;
def on($fields; $f): $fields == null or ($fields | index($f)) != null;
# 단어 일치 2 · 부분 일치 1 · 없음 0. 영문은 단어 앞부분, 한글은 조사가 붙으므로 어디든.
def tmatch($words; $text; $t; $sub):
  if ($words | index($t)) != null then 2
  elif $sub and (if ($t | hangul) then ($text | contains($t)) else (($t | length) >= 3 and any($words[]; startswith($t))) end) then 1
  else 0 end;
def hits($d; $t; $sub; $fields):
  [ (if on($fields; "name") then
       if $d.name == $t then {f: "name", s: 10}
       else tmatch($d.nw; $d.name; $t; $sub) as $m
         | if $m == 2 then {f: "name", s: 7}
           elif $m == 1 or ($sub and ($t | length) >= 3 and ($d.name | contains($t))) then {f: "name", s: 4} else empty end end
     else empty end),
    (if on($fields; "tag") then
       if ($d.tags | index($t)) != null then {f: "tag", s: 6}
       elif $sub and ($t | length) >= 3 and any($d.tags[]; startswith($t)) then {f: "tag", s: 3} else empty end
     else empty end),
    (if on($fields; "keyword") then
       if ($d.kws | index($t)) != null then {f: "keyword", s: 5}
       else tmatch($d.kww; ($d.kws | join(" ")); $t; $sub) as $m | if $m == 2 then {f: "keyword", s: 4} elif $m == 1 then {f: "keyword", s: 2.5} else empty end end
     else empty end),
    (if on($fields; "category") and $d.cat != "" and $d.cat == $t then {f: "category", s: 3} else empty end),
    (if on($fields; "marketplace") and ($d.mp == $t or ($d.mpw | index($t)) != null) then {f: "marketplace", s: 2} else empty end),
    ( [$d.comps[] | select(on($fields; .k))] as $cs
      | (first($cs[] | select(.n == $t or (.nw | index($t)) != null)) | {f: .k, s: 5}),
        (if $sub then first($cs[] | select(tmatch(.nw; .n; $t; true) == 1)) | {f: .k, s: 3} else empty end),
        (first($cs[] | select(.d != "" and tmatch(.dw; .d; $t; $sub) > 0)) | {f: (.k + "-description"), s: 2}) ),
    (if on($fields; "description") then
       tmatch($d.dw; $d.desc; $t; $sub) as $m | if $m == 2 then {f: "description", s: 3} elif $m == 1 then {f: "description", s: 2} else empty end
     else empty end) ];
def rehits($d; $re; $fields):
  def t($s): ($s | test($re; "i"));
  [ (if on($fields; "name") and t($d.name) then {f: "name", s: 7} else empty end),
    (if on($fields; "tag") and any($d.tags[]; t(.)) then {f: "tag", s: 5} else empty end),
    (if on($fields; "keyword") and any($d.kws[]; t(.)) then {f: "keyword", s: 4} else empty end),
    (if on($fields; "category") and t($d.cat) then {f: "category", s: 3} else empty end),
    (if on($fields; "marketplace") and t($d.mp) then {f: "marketplace", s: 2} else empty end),
    (first($d.comps[] | select(on($fields; .k)) | select(t(.n))) | {f: .k, s: 4}),
    (first($d.comps[] | select(on($fields; .k)) | select(.d != "" and t(.d))) | {f: (.k + "-description"), s: 2}),
    (if on($fields; "description") and t($d.desc) then {f: "description", s: 2} else empty end) ];
def fuzzyhit($d; $t; $fields):
  ($t | length) as $n | (if $n >= 8 then 2 else 1 end) as $k
  | if ($t | hangul) or $n < 4 then empty else
      first( ( (if on($fields; "name") then $d.nw[] | {f: "name", w: .} else empty end),
               (if on($fields; "tag") then $d.tags[] | {f: "tag", w: .} else empty end),
               (if on($fields; "keyword") then $d.kww[] | {f: "keyword", w: .} else empty end),
               ($d.comps[] | select(on($fields; .k)) | .k as $kk | .nw[] | {f: $kk, w: .}) )
             | select(((.w | length) - $n | absv) <= $k and .w != $t and lev(.w; $t) <= $k) )
      | {f: .f, s: 2.5, via: ("오타 허용 → " + .w)} end;
def expand($t; $o; $syn):
  [{t: $t, w: 1, via: null, sub: ($o.exact | not)}]
  + (if $o.exact then [] else
      ([$syn.groups[] | select(index($t) != null) | .[] | select(. != $t)] | unique | map({t: ., w: 0.7, via: ("동의어 " + .), sub: true}))
      + (if ($t | hangul) and ($t | length) >= 3 then
           ($t | sub("(으로|에서|에게|해주는|하는|해줘|이랑|랑|을|를|이|가|은|는|의|에|로|와|과|도|만)$"; "")) as $s
           | if $s != $t and ($s | length) >= 1 then [{t: $s, w: 0.9, via: null, sub: true}] else [] end
         else [] end)
    end);
def parse($args; $o):
  [ $args[] | san | splits(" +") | select(length > 0) | . as $raw
    | test("^[-!].") as $neg | (if $neg then .[1:] else . end) as $s
    | (($s | capture("^(?<k>[a-z]+):(?<v>.+)$")) // {k: null, v: $s}) as $kv
    | if ($kv.k == "has" or $kv.k == "is" or $kv.k == "dep" or $kv.k == "depends" or $kv.k == "id") then
        {raw: $raw, neg: $neg, filter: $kv.k, v: ($kv.v | lc)}
      else
        (if $kv.k != null and (fieldmap | has($kv.k)) then {fields: fieldmap[$kv.k], v: $kv.v} else {fields: null, v: $s} end) as $fv
        | ($fv.v | test("^/.+/$")) as $re
        | {raw: $raw, neg: $neg, filter: null, fields: $fv.fields, re: ($re or $o.regex),
           t: (if $re then $fv.v[1:-1] elif $o.regex then $fv.v else ($fv.v | lc) end)}
        | .alts = (if .re then [.t] else (.t | split("|") | map(select(length > 0))) end)
      end ];
def tscore($d; $term; $o; $syn):
  ($term.fields // $o.fields) as $fields
  | ( [ $term.alts[] as $a
        | if $term.re then (rehits($d; $a; $fields)[] | . + {via: null})
          else (expand($a; $o; $syn)[] as $fm | hits($d; $fm.t; $fm.sub; $fields)[] | .s *= $fm.w | . + {via: $fm.via}) end ] ) as $h
  | if ($h | length) > 0 then
      ($h | max_by(.s)) as $b
      | {s: ($b.s + 0.5 * (($h | map(.f) | unique | length) - 1)), f: $b.f, via: $b.via, fields: ($h | map(.f) | unique)}
    elif $o.fuzzy and ($o.exact | not) and ($term.re | not) then
      ([$term.alts[] as $a | fuzzyhit($d; $a; $fields)] | first) as $z
      | if $z then $z + {fields: [$z.f]} else null end
    else null end;
def hasmap: {skill: "skills", command: "commands", agent: "agents", hook: "hooks", mcp: "mcp", lsp: "lsp"};
def qfilter($p; $q):
  ( if $q.filter == "has" then (hasmap[$q.v] // null) as $k | ($k != null and (($p.components[$k] // []) | length) > 0)
    elif $q.filter == "is" then
      ({installed: $p.installed, "not-installed": ($p.installed | not), uninstalled: ($p.installed | not),
        enabled: ($p.enabled == true), disabled: ($p.enabled == false)}[$q.v] // false)
    elif $q.filter == "id" then ($p.id | lc) == $q.v
    else ($p.dependencies | map(lc) | index($q.v)) != null end ) as $r
  | if $q.neg then ($r | not) else $r end;
def passf($p; $o):
  ($o.mp == [] or ($o.mp | index($p.marketplace | lc)) != null)
  and ($o.tag == [] or any($p.tags[]; lc as $x | $o.tag | index($x) != null))
  and ($o.cat == [] or ($o.cat | index($p.category // "" | lc)) != null)
  and ($o.kw == [] or any($p.keywords[]; lc as $x | $o.kw | index($x) != null))
  and all($o.has[]; (hasmap[.] // "") as $k | (($p.components[$k] // []) | length) > 0)
  and ($o.installed == null or $p.installed == $o.installed);
def why: [.matches[]? | "\(.term) → \(.fields | map(kindname) | join("·"))\(if .via then " (\(.via))" else "" end)"];
def counts: .components | {skills: (.skills | length), commands: (.commands | length), agents: (.agents | length),
  hooks: (.hooks | length), mcp: (.mcp | length), lsp: (.lsp | length)};
def shape($o): del(._d) | . + {componentCounts: counts} | if $o.full then . else del(.components, .path) end;
def order($o):
  if $o.sort == "name" then sort_by(.name, .marketplace)
  elif $o.sort == "installs" then sort_by(-(.installCount // 0), -(.score // 0), .name)
  else sort_by(-(.groupRank // 0), -(.matched // 0), -(.score // 0), -(.installCount // 0), .name) end;
def finish($o; $default_min):
  (if $o.min == null then $default_min else $o.min end) as $min
  | map(select((.score // 0) >= $min or .group == "declared" or .group == "dependency"))
  | order($o) | to_entries | map(.value + {rank: (.key + 1)}) as $all
  | {total: ($all | length), results: ((if $o.limit > 0 then $all[:$o.limit] else $all end) | map(shape($o)))};

def search($cat; $q; $o; $syn):
  parse($q; $o) as $terms
  | ($terms | map(select(.filter == null and (.neg | not)))) as $pos1
  | ($pos1 | map(select(.re or .fields != null or (.t as $t | $syn.stopwords | index($t) | not)))) as $pos2
  | (if ($pos2 | length) > 0 then $pos2 else $pos1 end) as $pos
  | ($terms | map(select(.filter == null and .neg))) as $negs
  | ($terms | map(select(.filter != null))) as $qf
  | [ $cat[] | select(passf(.; $o)) | . as $p | select(all($qf[]; qfilter($p; .)))
      | ._d as $d
      | select(all($negs[]; tscore($d; .; ($o + {fuzzy: false, exact: true}); $syn) == null))
      | [ $pos[] as $t | {term: $t.raw} + (tscore($d; $t; $o; $syn) // {s: 0}) ] as $ts
      | ($ts | map(select(.s > 0))) as $hit
      | select(($pos | length) == 0 or ($hit | length) > 0)
      | $p + {score: ($hit | map(.s) | add // 0 | r1), matched: ($hit | length),
              matches: ($hit | map({term, field: .f, fields, via}))} | . + {why: why} ]
  | . as $all
  | ($all | map(select(.matched == ($pos | length)))) as $strict
  | (if $o.mode == "any" then {relaxed: false, list: $all}
     elif ($strict | length) > 0 or ($pos | length) <= 1 then {relaxed: false, list: $strict}
     else {relaxed: true, list: $all} end) as $r
  | {command: "search", query: $q, terms: ($pos | map(.raw)), excluded: ($negs | map(.raw)), filters: ($qf | map(.raw)),
     mode: $o.mode, relaxed: $r.relaxed} + ($r.list | finish($o; 0));

def fix(f): def r: (f) as $n | if $n == . then . else ($n | r) end; r;
def idfs($cat):
  ($cat | length) as $N
  | def df(f): reduce ($cat[] | [f] | unique[]) as $w ({}; .[$w] += 1);
    def idf: map_values((($N + 1) / .) | log + 0.1);
  { name: (df(._d.nw[]) | idf), tag: (df(._d.tags[]) | idf), kw: (df(._d.kww[]) | idf),
    comp: (df(._d.comps[] | select(.k != "hook") | .nw[]) | idf),
    desc: (df(._d.dw[] | select((length >= 3) or hangul)) | idf) };
def inter($a; $b): [$a[] | select(. as $x | $b | index($x) != null)] | unique;
def wsum($ws; $m): [$ws[] | $m[.] // 0] | add // 0;
def relate($cat; $seed; $by; $I):
  def use($k): ($by == []) or ($by | index($k)) != null;
  ($cat | map(select(.marketplace == $seed.marketplace))) as $same
  | ($seed.dependencies | fix(. as $s | ($s + [$same[] | select(.name as $n | $s | index($n) != null) | .dependencies[]]) | unique)) as $fwd
  | ($same | map(select(.dependencies | index($seed.name) != null) | .name)
     | fix(. as $s | ($s + [$same[] | select(any(.dependencies[]; . as $x | $s | index($x) != null)) | .name]) | unique)) as $rev
  | $seed._d as $sd
  | [ $cat[] | select(.id != $seed.id) | . as $p | ._d as $d
      | [ (if use("dependency") and $p.marketplace == $seed.marketplace and ($fwd | index($p.name)) != null then
            {s: 10, r: (if ($seed.dependencies | index($p.name)) != null then "의존 (직접)" else "의존 (간접)" end)} else empty end),
          (if use("dependent") and $p.marketplace == $seed.marketplace and ($rev | index($p.name)) != null then
            {s: 8, r: (if ($p.dependencies | index($seed.name)) != null then "역의존 (직접)" else "역의존 (간접)" end)} else empty end),
          (if use("tag") then inter($sd.tags; $d.tags) as $x | if ($x | length) > 0 then {s: (wsum($x; $I.tag) * 2), r: ("태그 " + ($x | join(",")))} else empty end else empty end),
          (if use("keyword") then inter($sd.kww; $d.kww) as $x | if ($x | length) > 0 then {s: (wsum($x; $I.kw) * 1.5), r: ("키워드 " + ($x | join(",")))} else empty end else empty end),
          (if use("name") then inter($sd.nw; $d.nw) as $x | if ($x | length) > 0 then {s: (wsum($x; $I.name) * 2), r: ("이름 " + ($x | join(",")))} else empty end else empty end),
          (if use("component") then inter([$sd.comps[] | select(.k != "hook") | .nw[]]; [$d.comps[] | select(.k != "hook") | .nw[]]) as $x
             | if ($x | length) > 0 then {s: ([wsum($x; $I.comp), 6] | min), r: ("구성요소 " + ($x[:4] | join(",")))} else empty end else empty end),
          (if use("description") then inter([$sd.dw[] | select((length >= 3) or hangul)]; $d.dw) as $x
             | if ($x | length) > 0 then ([$x[] | {w: ., v: ($I.desc[.] // 0)}] | sort_by(-.v)) as $sx
               | {s: ([wsum($x; $I.desc) * 0.3, 5] | min), r: ("설명 " + ($sx[:3] | map(.w) | join(",")))} else empty end else empty end),
          (if use("category") and $seed.category != null and $p.category == $seed.category then {s: 0.5, r: ("카테고리 " + $p.category)} else empty end) ] as $rs
      | select(($rs | length) > 0)
      | $p + {score: ($rs | map(.s) | add | r1), reasons: ($rs | map(.r)), group: "related", groupRank: 0} ];
def related($cat; $q; $o; $syn):
  ($q | join(" ") | san) as $target
  | ($cat | map(select(.id == $target or .name == $target))) as $exact
  | idfs($cat) as $I
  | if ($exact | length) > 0 then
      ($exact | sort_by(if .installed then 0 else 1 end) | first) as $seed
      | [relate($cat; $seed; $o.by; $I)[] | select(passf(.; $o))] as $rel
      | {command: "related", target: $target, mode: "plugin", seed: ($seed | shape($o)),
         ambiguous: (if ($exact | length) > 1 then ($exact | map(.id)) else null end)}
        + ($rel | map(. + {why: .reasons}) | finish($o; 1.5))
    else
      search($cat; $q; ($o + {limit: 0, min: null}); $syn) as $s
      | ($s.results[:3]) as $seeds
      | ($seeds | map(.id)) as $sids
      | [ $seeds | to_entries[] | .key as $i | .value.id as $sid | ($cat[] | select(.id == $sid)) as $sp
          | relate($cat; $sp; $o.by; $I)[] | select(.id as $x | $sids | index($x) == null) | . + {score: (.score / ($i + 1)), via: $sp.name} ]
      | group_by(.id)
      | map((.[0] | del(.via)) + {score: (map(.score) | add | r1), reasons: (map("\(.via): \(.reasons | join(" · "))"))})
      | map(select(passf(.; $o)))
      | ( [ $cat[] | . as $p | select($sids | index($p.id) != null)
            | ($s.results[] | select(.id == $p.id)) as $r
            | $p + {score: $r.score, group: "match", groupRank: 1, reasons: (["직접 일치"] + $r.why)} ] ) + .
      | {command: "related", target: $target, mode: "feature", seeds: $sids, relaxed: $s.relaxed}
        + (map(. + {why: .reasons}) | finish($o; 1.5))
    end;

def project($cat; $sig; $o):
  ($sig.signals) as $S
  | ([$S[].terms[]] | unique) as $detected
  | (($sig.vocabulary // []) - $detected) as $foreign
  | ($sig.declared.enabled // {}) as $en
  | [ $en | to_entries[] | .key as $id | .value as $on
      | ($cat | map(select(.id == $id)) | first) as $p
      | ($id | split("@")) as $parts
      | (if $p == null then
           {id: $id, name: $parts[0], marketplace: ($parts[1:] | join("@")), description: "", version: null, category: null, tags: [], keywords: [],
            dependencies: [], installed: false, enabled: null, scopes: [], installCount: null, componentsKnown: false,
            components: {skills: [], commands: [], agents: [], hooks: [], mcp: [], lsp: []}}
         else $p end)
      + {group: "declared", groupRank: 3, score: 100,
         status: (if $on != true then "off" elif $p == null then
                    (if any($cat[]; .marketplace == ($parts[1:] | join("@"))) then "unknown-plugin" else "marketplace-missing" end)
                  elif ($p.installed | not) then "missing" elif $p.enabled == false then "disabled" else "ok" end)} ] as $D
  | ($D | map(select(.status != "off")) | map(.id)) as $dids
  | ([ $D[] | select(.status != "off") | . as $x
       | ($cat | map(select(.marketplace == $x.marketplace))) as $same
       | ($x.dependencies | fix(. as $s | ($s + [$same[] | select(.name as $n | $s | index($n) != null) | .dependencies[]]) | unique))[]
       | . as $n | ($same | map(select(.name == $n)) | first) as $dp
       | select($dp != null and ($dids | index($dp.id)) == null)
       | $dp + {group: "dependency", groupRank: 2, score: 50, status: (if $dp.installed then "ok" else "missing" end), requiredBy: $x.name} ]
     | unique_by(.id)) as $DEP
  | ($dids + ($DEP | map(.id))) as $taken
  | [ $cat[] | select(passf(.; $o)) | select(.id as $i | $taken | index($i) == null) | . as $p | ._d as $d
      | [ $S[] as $s
          | ([ $s.terms[] as $t | hits($d; ($t | lc); false; null)[] ] | if length > 0 then max_by(.s) else null end) as $h
          | select($h != null)
          | {s: ($s.weight * $h.s / 10), r: "\($s.label) (\($h.f | kindname))"} ] as $rs
      | select(($rs | length) > 0)
      | inter($d.nw; $foreign) as $bad
      | ($rs | map(.s) | add) as $raw
      | $p + {group: "recommended", groupRank: 1, status: (if $p.installed then "ok" else "missing" end),
              score: ((if ($bad | length) > 0 then $raw * 0.3 else $raw end) | r1),
              reasons: (($rs | map(.r)) + (if ($bad | length) > 0 then ["대상 불일치: " + ($bad | join(","))] else [] end))} ] as $R
  | ($D | map(. + {reasons: ["프로젝트 설정에 선언 (" + .status + ")"]}))
    + ($DEP | map(. + {reasons: [.requiredBy + " 가 의존"]})) + $R
  | map(select(if $o.only == "declared" then .group == "declared" or .group == "dependency"
               elif $o.only == "missing" then (.status == "missing" or .status == "marketplace-missing" or .status == "unknown-plugin")
               elif $o.only == "recommended" then .group == "recommended" else true end))
  | map(. + {why: .reasons})
  | {command: "project", root: $sig.root, signals: $S, settings: ($sig.declared.files // []),
     summary: {declared: ($D | map(select(.status != "off")) | length),
               missing: (($D + $DEP) | map(select(.status == "missing" or .status == "marketplace-missing" or .status == "unknown-plugin")) | length),
               recommended: ($R | map(select(.score >= ($o.min // 1))) | length)}}
    + finish($o; 1);
JQ

run_jq() { # $1=jq 본문 — 카탈로그 $cat · 질의 $q · 옵션 $o · 동의어 $syn
  local body="$1"; shift
  catalog_json > "$TMP/cat.json" || exit 2
  jq -n --slurpfile c "$TMP/cat.json" --argjson o "$(opts_json)" --slurpfile s "$SYN" "$@" \
    "$JQ_LIB
     (\$c[0] | prep) as \$cat | \$s[0] as \$syn | $body"
}

query_args() { if [ ${#ARGS[@]} -gt 0 ]; then printf '%s\n' "${ARGS[@]}" | jq -R . | jq -sc .; else echo '[]'; fi; }

emit() {
  case "$FORMAT" in
    json) jq '.' ;;
    ids) jq -r '.results[]?.id' ;;
    names) jq -r '.results[]?.name' ;;
    tsv) jq -r '
      def cell: tostring | gsub("[\\t\\n\\r]"; " ");
      (if .relaxed == true then "# 모든 단어에 맞는 결과가 없어 일부만 맞는 결과를 보입니다" else empty end),
      (["rank", "id", "installed", "score", "group", "status", "why", "description"] | join("\t")),
      (.results[]? | [.rank, .id, (if .installed then "yes" else "no" end), (.score // ""), (.group // ""), (.status // ""),
                      ((.why // []) | join("; ")), .description] | map(cell) | join("\t"))' ;;
  esac
}

# ---- 프로젝트 신호 -----------------------------------------------------------
detect_json() { # $1=디렉터리
  local root="${1:-.}"
  [ -d "$root" ] || die "디렉터리가 아닙니다: $root"
  root="$(cd "$root" && pwd)"
  local prune=() p
  while IFS= read -r p; do prune+=(-name "$p" -o); done < <(jq -r '.prune[]' "$SIG")
  ( cd "$root" && find . -maxdepth 8 \( ${prune+"${prune[@]}"} -false \) -prune -o -type f -print 2>/dev/null ) \
    | sed 's|^\./||' | head -50000 > "$TMP/files.idx"
  : > "$TMP/sig"
  local id kind pat path ev
  while IFS=$'\037' read -r id kind path pat; do
    ev=""
    if [ "$kind" = path ]; then
      ev="$(grep -E -m1 -- "$path" "$TMP/files.idx" 2>/dev/null)"
    else
      while IFS= read -r p; do
        if grep -Eq -- "$pat" "$root/$p" 2>/dev/null; then ev="$p"; break; fi
      done < <(grep -E -- "$path" "$TMP/files.idx" 2>/dev/null | head -40)
    fi
    [ -n "$ev" ] && printf '%s\037%s\n' "$id" "$ev" >> "$TMP/sig"
  done < <(jq -r '.signals[] | .id as $id | (((.paths // [])[] | [$id, "path", ., ""]), ((.grep // [])[] | [$id, "grep", .path, .pattern])) | join("\u001f")' "$SIG")

  # 프로젝트 설정의 선언 — settings.local.json 이 settings.json 을 덮는다
  local files=() rel=() f
  for f in .claude/settings.json .claude/settings.local.json; do
    [ -f "$root/$f" ] && { files+=("$root/$f"); rel+=("$f"); }
  done
  echo '{"enabled":{},"marketplaces":[]}' > "$TMP/decl"
  if [ ${#files[@]} -gt 0 ]; then
    jq -s '{enabled: (map(.enabledPlugins // {}) | add // {}), marketplaces: (map(.extraKnownMarketplaces // {} | keys) | add // [] | unique)}' \
      "${files[@]}" > "$TMP/decl.new" 2>/dev/null && mv "$TMP/decl.new" "$TMP/decl"
  fi
  jq -n --rawfile s "$TMP/sig" --slurpfile d "$TMP/decl" --slurpfile g "$SIG" --arg root "$root" \
    --argjson files "$(if [ ${#rel[@]} -gt 0 ]; then printf '%s\n' "${rel[@]}" | jq -R . | jq -sc .; else echo '[]'; fi)" '
    ($s | split("\n") | map(select(length > 0) | split("\u001f")) | group_by(.[0]) | map({key: .[0][0], value: .[0][1]}) | from_entries) as $hit
    | { root: $root,
        signals: [$g[0].signals[] | select($hit[.id]) | {id, label, weight, terms, exclusive, evidence: $hit[.id]}],
        vocabulary: ([$g[0].signals[] | select(.exclusive) | .terms[]] | unique),
        declared: ($d[0] + {files: $files}) }'
}

# ---- 설치 --------------------------------------------------------------------
# 선택 문법: 1,3-5,이름,이름@마켓,all,none — 번호는 목록의 rank
select_ids() { # $1=목록 [{rank,id,name}] $2=선택 $3=제외 $4=전부 → {chosen, missing}
  jq -c --arg sel "$2" --arg exc "$3" --argjson all "$4" '
    def toks($s): $s | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0));
    def pick($ts):
      . as $l
      | [ $ts[] as $t
          | if ($t | test("^[0-9]+$")) then ($l | map(select(.rank == ($t | tonumber)))) as $m | if ($m | length) > 0 then $m[] else {missing: $t} end
            elif ($t | test("^[0-9]+-[0-9]+$")) then ($t | split("-") | map(tonumber)) as $r | $l[] | select(.rank >= $r[0] and .rank <= $r[1])
            elif ($t | ascii_downcase) == "all" or $t == "*" then $l[]
            elif ($t | ascii_downcase) == "none" then empty
            else ($l | map(select(.id == $t or .name == $t))) as $m | if ($m | length) > 0 then $m[] else {missing: $t} end end ];
    (if $all then . else pick(toks($sel)) end) as $chosen
    | ([pick(toks($exc))[] | .id? // empty]) as $ex
    | { chosen: ([$chosen[] | select(.id != null) | select(.id as $i | $ex | index($i) == null)] | unique_by(.rank) | sort_by(.rank) | map(.id)),
        missing: [$chosen[] | .missing? // empty] }' <<<"$1"
}

cmd_install() {
  local list chosen raw
  if [ -n "$FROM" ]; then
    if [ "$FROM" = - ]; then raw="$(cat)"; else [ -r "$FROM" ] || die "읽을 수 없습니다: $FROM"; raw="$(cat "$FROM")"; fi
    if jq -e 'type == "object" or type == "array"' >/dev/null 2>&1 <<<"$raw"; then
      list="$(jq -c '(if type == "object" then .results // [] else . end)
        | to_entries | map(.key as $k | .value | if type == "string" then {id: ., name: (split("@")[0]), rank: null} else {id, name, rank} end
          | . + {rank: (.rank // ($k + 1))})' <<<"$raw")"
    else
      list="$(printf '%s\n' "$raw" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' | cut -f1 | jq -R . \
        | jq -sc 'to_entries | map({rank: (.key + 1), id: .value, name: (.value | split("@")[0])})')"
    fi
    if [ -z "${SELECT//,/}" ] && [ "$ALL" = false ]; then
      jq -c '{command: "install", mode: "list-only", message: "선택이 없어 조회만 했습니다 — --select 번호 또는 --all",
              results: map({rank, id, status: "listed", message: ""})}' <<<"$list" | emit_install
      return 0
    fi
  else
    [ ${#ARGS[@]} -gt 0 ] || die "설치할 플러그인이 없습니다 — install <이름…> 또는 --from <파일|->"
    list="$(query_args | jq -c 'to_entries | map({rank: (.key + 1), id: .value, name: (.value | split("@")[0])})')"
    [ -n "${SELECT//,/}" ] || ALL=true
  fi
  chosen="$(select_ids "$list" "$SELECT" "$EXCLUDE" "$ALL")"
  [ "$(jq '.missing | length' <<<"$chosen")" -eq 0 ] || die "목록에 없는 선택: $(jq -r '.missing | join(", ")' <<<"$chosen")"
  if [ "$(jq '.chosen | length' <<<"$chosen")" -eq 0 ]; then
    jq -cn '{command: "install", mode: "list-only", message: "고른 플러그인이 없습니다", results: []}' | emit_install
    return 0
  fi

  # 이름 → id. 같은 이름이 여러 마켓플레이스에 있으면 멈춘다
  catalog_json > "$TMP/cat.json" || exit 2
  local resolved bad
  resolved="$(jq -c --slurpfile c "$TMP/cat.json" '.chosen | map(. as $x
      | ($c[0] | map(select(.id == $x or (($x | contains("@") | not) and .name == $x)))) as $m
      | if ($m | length) == 1 then {id: $m[0].id, installed: $m[0].installed, scopes: $m[0].scopes}
        elif ($m | length) == 0 then {id: $x, error: "카탈로그에 없습니다 — 마켓플레이스를 추가했는지 확인하세요"}
        else {id: $x, error: ("마켓플레이스가 여럿입니다 — 이름@마켓으로 고르세요: " + ($m | map(.id) | join(", ")))} end)' <<<"$chosen")"
  bad="$(jq -r 'map(select(.error) | "\(.id): \(.error)") | join("\n")' <<<"$resolved")"
  [ -z "$bad" ] || die "$bad"

  local id inst scopes out code status msg failed=0
  : > "$TMP/results"
  while IFS=$'\037' read -r id inst scopes; do
    if [ "$inst" = true ]; then status=skipped; msg="이미 설치됨 ($scopes)"
    elif [ "$DRY" = true ]; then status=planned; msg="claude plugin install $id --scope $SCOPE"
    else
      out="$("$CLAUDE_BIN" plugin install "$id" --scope "$SCOPE" --json </dev/null 2>&1)"; code=$?
      if [ $code -eq 0 ]; then status=installed; msg="설치됨 ($SCOPE)"
      else
        status=failed; failed=1
        if printf '%s' "$out" | grep -q 'shownCommand'; then
          msg="명령 실행 확인이 필요한 플러그인 — 직접 실행: claude plugin install $id --scope $SCOPE"
        else
          msg="$(printf '%s' "$out" | jq -r '.error // .message // empty' 2>/dev/null | head -1)"
          [ -n "$msg" ] || msg="$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-300)"
        fi
      fi
    fi
    jq -cn --arg id "$id" --arg s "$status" --arg m "$msg" '{id: $id, status: $s, message: $m}' >> "$TMP/results"
  done < <(jq -r '.[] | [.id, (.installed | tostring), (.scopes | join(","))] | join("\u001f")' <<<"$resolved")

  jq -s --arg scope "$SCOPE" --argjson dry "$DRY" '{command: "install", mode: (if $dry then "dry-run" else "install" end), scope: $scope,
      results: (to_entries | map(.value + {rank: (.key + 1)})),
      summary: (group_by(.status) | map({key: .[0].status, value: length}) | from_entries),
      restartRequired: any(.[]; .status == "installed")}' "$TMP/results" | emit_install
  [ "$DRY" = true ] || cache_drop
  return $failed
}
emit_install() {
  case "$FORMAT" in
    json) jq '.' ;;
    ids|names) jq -r '.results[] | select(.status == "installed" or .status == "planned" or .status == "listed") | .id' ;;
    tsv) jq -r '(["rank", "id", "status", "message"] | join("\t")), (.results[] | [.rank, .id, .status, (.message // "")] | map(tostring) | join("\t"))' ;;
  esac
}

# ---- 진입점 ------------------------------------------------------------------
cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in ''|-h|--help|help) usage; exit 0 ;; esac
parse_opts "$@"

case "$cmd" in
  catalog)
    if [ "$FORMAT" = json ]; then catalog_json | jq '.'
    else catalog_json | jq -c '{results: (to_entries | map(.value + {rank: (.key + 1)}))}' | emit; fi ;;
  search)
    [ ${#ARGS[@]} -gt 0 ] || [ -n "$F_MP$F_TAG$F_CAT$F_KW$F_HAS$F_INST" ] || die "검색어나 필터가 필요합니다 — search <질의…>"
    run_jq 'search($cat; $q; $o; $syn)' --argjson q "$(query_args)" | emit ;;
  related)
    [ ${#ARGS[@]} -gt 0 ] || die "대상이 필요합니다 — related <플러그인 | 기능어>"
    run_jq 'related($cat; $q; $o; $syn)' --argjson q "$(query_args)" | emit ;;
  project)
    [ ${#ARGS[@]} -le 1 ] || die "project 는 디렉터리 하나만 받습니다"
    [ "$LIMIT_SET" = true ] || LIMIT=0
    detect_json "${ARGS[0]:-.}" > "$TMP/detect.json" || exit 2
    run_jq 'project($cat; $sig[0]; $o)' --slurpfile sig "$TMP/detect.json" | emit ;;
  detect)
    detect_json "${ARGS[0]:-.}" | jq '.' ;;
  show)
    [ ${#ARGS[@]} -eq 1 ] || die "플러그인 하나가 필요합니다 — show <이름|이름@마켓>"
    FULL=true
    out="$(run_jq '($cat | map(select(.id == $q[0] or .name == $q[0]))) as $m
      | if ($m | length) == 0 then null else
        $m | map(. as $p | shape($o) + {dependents: [$cat[] | select(.marketplace == $p.marketplace and (.dependencies | index($p.name)) != null) | .id]})
        | if length == 1 then .[0] else {ambiguous: map(.id), plugins: .} end end' --argjson q "$(query_args)")"
    [ "$out" != null ] || die "없는 플러그인: ${ARGS[0]}"
    printf '%s\n' "$out" ;;
  facets)
    f="${ARGS[0]:-all}"
    case "$f" in all|tag|keyword|category|marketplace|has|installed) ;; *) die "facets 는 tag · keyword · category · marketplace · has · installed 중 하나: $f" ;; esac
    run_jq '[$cat[] | select(passf(.; $o))] as $l
      | def cnt(f): [$l[] | [f] | unique[]] | group_by(.) | map({value: .[0], count: length}) | sort_by(-.count, .value);
      {total: ($l | length),
       tag: cnt(.tags[]), keyword: cnt(.keywords[] | ascii_downcase), category: cnt(.category // empty), marketplace: cnt(.marketplace),
       has: cnt(.components | to_entries[] | select((.value | length) > 0) | .key),
       installed: cnt(if .installed then "installed" else "not-installed" end)}
      | if $f == "all" then . else {total, ($f): .[$f]} end' --arg f "$f" ;;
  install)
    cmd_install ;;
  *) die "모르는 명령: $cmd (--help)" ;;
esac
