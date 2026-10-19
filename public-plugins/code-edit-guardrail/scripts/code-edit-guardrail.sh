#!/usr/bin/env bash
# 코드 편집 가드레일 — 훅 네 모드 + CLI. 규칙 원본은 references/code-edit-guardrail-rules.md.
#
#   code-edit-guardrail.sh reset            UserPromptSubmit — 이번 요청의 편집 기록 · 면제를 비운다
#   code-edit-guardrail.sh track            PostToolUse      — 고친 파일을 기록한다
#   code-edit-guardrail.sh shared           PreToolUse       — 공유자원 편집을 사용자 확인으로 돌린다 (G-03)
#   code-edit-guardrail.sh stop             Stop             — 테스트 동반 (G-01) · 품질 lane (G-02)
#   code-edit-guardrail.sh validate [루트]  CLI              — 설정 검증 (C-01 ~ C-05)
#
# 설정이 없거나 jq 가 없으면 훅은 아무것도 하지 않는다 (fail-open).
# 종료 코드: 0 통과 / 2 차단 · 위반 / 1 사용법 오류
set -uo pipefail

MODE="${1:-}"
command -v jq >/dev/null 2>&1 || { [ "$MODE" = validate ] && { echo "❌ jq 가 필요하다" >&2; exit 2; }; exit 0; }

if [ "$MODE" = validate ] && [ -n "${2:-}" ]; then ROOT_IN="$2"; else ROOT_IN="${CLAUDE_PROJECT_DIR:-$(pwd)}"; fi
# 훅 모드에서 exit 2 는 프롬프트 · 편집을 막는다 — 들어갈 수 없는 프로젝트는 fail-open
ROOT="$(cd "$ROOT_IN" 2>/dev/null && pwd -P)" || { [ "$MODE" = validate ] || exit 0; echo "❌ $ROOT_IN 에 들어갈 수 없다" >&2; exit 2; }
CONFIG_IN="${CODE_EDIT_GUARDRAIL_CONFIG:-.claude/code-edit-guardrail.json}"
config_of() { case "$CONFIG_IN" in /*) printf '%s' "$CONFIG_IN" ;; *) printf '%s' "$1/$CONFIG_IN" ;; esac; } # $1=루트
CONFIG="$(config_of "$ROOT")"

# 글롭 → 정규식. `/` 가 있으면 루트 기준, 없으면 어느 깊이든. 끝 `/` 는 그 아래 전부, `!` 는 제외
JQ_LIB='
def glob_re:
  endswith("/") as $dir
  | rtrimstr("/") as $core
  | ($core | contains("/")) as $anchored
  | ($core | ltrimstr("./") | ltrimstr("/") | if $dir then . + "/**" else . end) as $g
  | "^" + (if $anchored then "" else "(.*/)?" end)
    + ($g
      | gsub("(?<c>[.+^$(){}|\\[\\]\\\\])"; "\\\(.c)")
      | gsub("\\*\\*/"; "\u0001") | gsub("\\*\\*"; "\u0002")
      | gsub("\\*"; "[^/]*") | gsub("\\?"; "[^/]")
      | gsub("\u0001"; "(.*/)?") | gsub("\u0002"; ".*"))
    + "$";
def globs_match($globs):
  . as $f
  | [$globs[] | select(startswith("!") | not) | glob_re] as $in
  | [$globs[] | select(startswith("!")) | ltrimstr("!") | glob_re] as $out
  | any($in[]; . as $r | $f | test($r)) and (any($out[]; . as $r | $f | test($r)) | not);
'

read_input() { INPUT="$(cat 2>/dev/null || true)"; }
input_get() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null || true; }
# 상태는 프로젝트 안에 둔다 — Bash 샌드박스 안의 Claude 가 면제 파일에 쓸 수 있어야 한다
STATE_REL=".claude/code-edit-guardrail"
STATE_DIR="${CODE_EDIT_GUARDRAIL_STATE_DIR:-$ROOT/$STATE_REL}"
state_paths() {
  local sid; sid="$(input_get .session_id)"; sid="$(printf '%s' "${sid:-nosession}" | tr -c 'A-Za-z0-9_.-' '_')"
  EDITS="$STATE_DIR/$sid.edits"
  ACK="$STATE_DIR/$sid.ack"
}
state_init() { # 스스로 ignore 해서 git status 를 더럽히지 않는다
  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  [ -f "$STATE_DIR/.gitignore" ] || printf '*\n' > "$STATE_DIR/.gitignore"
}
config_ok() { [ -f "$1" ] && jq -e 'type == "object"' "$1" >/dev/null 2>&1; } # $1=설정 파일

# $1=경로 → "파일 루트 \037 그 기준 상대 경로". 프로젝트 밖이면 빈 문자열. 아직 없는 디렉터리도 받는다
# 파일 루트는 프로젝트 아래의 다른 작업 트리(워크트리 · 중첩 저장소)면 그 작업 트리, 아니면 프로젝트 루트다
rel_path() {
  local p="$1" d rest top root="$ROOT"
  [ -n "$p" ] || return 0
  case "$p" in /*) ;; *) p="$ROOT/$p" ;; esac
  d="$(dirname "$p")"; rest="$(basename "$p")"
  while [ ! -d "$d" ]; do rest="$(basename "$d")/$rest"; d="$(dirname "$d")"; done
  d="$(cd "$d" && pwd -P)"
  case "$d/" in "$ROOT"/*) ;; *) return 0 ;; esac
  if top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" && top="$(cd "$top" && pwd -P)"; then
    case "$top/" in "$ROOT"/?*) root="$top" ;; esac
  fi
  printf '%s\037%s' "$root" "$(printf '%s' "${d#"$root"}/$rest" | sed 's#^/##')"
}

mode_reset() {
  read_input; state_paths
  rm -f "$EDITS" "$ACK"
}

mode_track() {
  read_input
  local loc root rel
  loc="$(rel_path "$(input_get '.tool_input.file_path // .tool_input.notebook_path')")"
  [ -n "$loc" ] || return 0
  root="${loc%%$'\037'*}"; rel="${loc#*$'\037'}"
  config_ok "$(config_of "$root")" || exit 0
  state_paths
  case "$rel" in "$STATE_REL"/*) return 0 ;; esac
  state_init && printf '%s\n' "$loc" >> "$EDITS"
  return 0
}

mode_shared() {
  read_input
  local loc rel content hits
  loc="$(rel_path "$(input_get .tool_input.file_path)")"
  [ -n "$loc" ] || exit 0
  rel="${loc#*$'\037'}"; CONFIG="$(config_of "${loc%%$'\037'*}")"
  config_ok "$CONFIG" || exit 0
  jq -e 'has("shared")' "$CONFIG" >/dev/null 2>&1 || exit 0
  content="$(printf '%s' "$INPUT" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null || true)"
  hits="$(jq -r --arg f "$rel" --arg c "$content" "$JQ_LIB"'
    .shared as $s
    | (if (($s.paths // []) | length) > 0 and ($f | globs_match($s.paths)) then "경로 \($f)" else empty end),
      (($s.content // [])[] as $re | select(try ($c | test($re)) catch false) | "내용 /\($re)/")' "$CONFIG" 2>/dev/null | paste -sd ',' - | sed 's/,/, /g')"
  [ -n "$hits" ] || exit 0
  jq -n --arg r "G-03 공유자원 편집 — [$hits]. 다른 팀 · 서비스가 같이 쓰는 자원이다. 영향을 사용자에게 확인받고 진행한다" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
}

mode_stop() {
  read_input; state_paths
  [ -s "$EDITS" ] || exit 0
  local active edits roots root where files viol="" codes tests name cmd out rc
  active="$(input_get .stop_hook_active)"
  # 기록 한 줄은 "루트 \037 상대 경로" — 루트마다 그 루트의 설정으로 보고 lane 도 거기서 돌린다
  edits="$(jq -R -s -c --arg root "$ROOT" '
    [split("\n")[] | select(length > 0) | split("\u001f") | if length > 1 then {r: .[0], f: .[1]} else {r: $root, f: .[0]} end]' "$EDITS")"
  roots="$(printf '%s' "$edits" | jq -r '[.[].r] | unique[]')"
  while IFS= read -r root <&3; do
    CONFIG="$(config_of "$root")"
    config_ok "$CONFIG" || continue
    where=""; [ "$root" = "$ROOT" ] || where="${root#"$ROOT"/}/"
    files="$(printf '%s' "$edits" | jq -c --arg r "$root" '[.[] | select(.r == $r) | .f] | unique')"

    if jq -e 'has("test")' "$CONFIG" >/dev/null 2>&1; then
      codes="$(jq -r --argjson files "$files" --arg w "$where" "$JQ_LIB"'
        .test as $t | $files[] | select(globs_match($t.code) and (globs_match($t.tests) | not)) | $w + .' "$CONFIG" 2>/dev/null)"
      tests="$(jq -r --argjson files "$files" "$JQ_LIB"'.test as $t | $files[] | select(globs_match($t.tests))' "$CONFIG" 2>/dev/null)"
      if [ -n "$codes" ] && [ -z "$tests" ] && ! grep -Eq '^test:[[:space:]]*[^[:space:]]' "$ACK" 2>/dev/null; then
        viol="${viol}- G-01 코드를 고쳤는데 테스트를 고치지 않았다: $(printf '%s' "$codes" | paste -sd ' ' -)
  조치: 바뀐 동작을 덮는 테스트를 쓰거나 고친다. 동작이 그대로인 변경(리팩터 · 포맷 · 주석)이면 사용자에게 알리고 면제한다
        echo 'test: <사유>' >> \"$ACK\"
"
      fi
    fi

    # 줄 단위로 읽지 않는다 — 여러 줄 command 가 첫 줄만 돌게 된다
    local lanes n i=0
    lanes="$(jq -c --argjson files "$files" "$JQ_LIB"'
      [(.quality // [])[] | . as $l | select(any($files[]; globs_match($l.paths))) | {name, command}]' "$CONFIG" 2>/dev/null)"
    n="$(printf '%s' "${lanes:-[]}" | jq 'length' 2>/dev/null || echo 0)"
    while [ "$i" -lt "${n:-0}" ]; do
      name="$(printf '%s' "$lanes" | jq -r ".[$i].name")"; cmd="$(printf '%s' "$lanes" | jq -r ".[$i].command")"; i=$((i+1))
      # lane 이 입력을 기다리며 멈추지 않게
      out="$(cd "$root" && bash -c "$cmd" 2>&1 </dev/null)"; rc=$?
      [ "$rc" = 0 ] && continue
      viol="${viol}- G-02 품질 lane '$name'${where:+ ($where)} 실패 (종료 코드 $rc): $cmd
$(printf '%s\n' "$out" | tail -n 20 | sed 's/^/    /')
"
    done
  done 3<<< "$roots"

  [ -n "$viol" ] || exit 0
  if [ "$active" = true ]; then
    # exit 0 의 stderr 는 아무도 못 본다 — systemMessage 로 사용자에게 보인다
    jq -n --arg m "⚠️ code-edit-guardrail — 완료 조건이 남았지만 한 번 되돌렸으므로 완료를 허용했다:
$viol" '{systemMessage: $m}'
    exit 0
  fi
  { echo "❌ code-edit-guardrail — 완료 보류"; printf '%s' "$viol"; } >&2
  exit 2
}

mode_validate() {
  [ -f "$CONFIG" ] || { echo "❌ C-01 설정 파일이 없다: $CONFIG" >&2; exit 2; }
  jq -e . "$CONFIG" >/dev/null 2>&1 || { echo "❌ C-01 올바른 JSON 이 아니다: $CONFIG" >&2; exit 2; }
  local findings files errs warns
  findings="$(jq -r --arg q "'" '
    def strarr: type == "array" and length > 0 and all(.[]; type == "string" and length > 0);
    def e: "E\u001f" + .;
    if type != "object" then "C-02 최상위는 객체여야 한다" | e else
      ((keys - ["test", "quality", "shared"])[] | "C-02 알 수 없는 키 \($q)\(.)\($q) — test · quality · shared 만 쓴다" | e),
      (if has("test") then .test
        | if type != "object" then "C-03 test 는 객체여야 한다" | e else
            ((keys - ["code", "tests"])[] | "C-03 test 에 알 수 없는 키 \($q)\(.)\($q)" | e),
            (if (.code | strarr) then empty else "C-03 test.code 는 비지 않은 문자열 배열이어야 한다" | e end),
            (if (.tests | strarr) then empty else "C-03 test.tests 는 비지 않은 문자열 배열이어야 한다" | e end)
          end
      else empty end),
      (if has("quality") then .quality
        | if type != "array" or length == 0 then "C-03 quality 는 비지 않은 배열이어야 한다" | e else
            (to_entries[] | .key as $i | .value
              | if type != "object" then "C-03 quality[\($i)] 는 객체여야 한다" | e else
                  ((keys - ["name", "paths", "command"])[] | "C-03 quality[\($i)] 에 알 수 없는 키 \($q)\(.)\($q)" | e),
                  (if (.name | type) == "string" and (.name | test("^[a-z0-9]+(-[a-z0-9]+)*$")) then empty else "C-03 quality[\($i)].name 은 kebab-case 문자열이어야 한다" | e end),
                  (if (.paths | strarr) then empty else "C-03 quality[\($i)].paths 는 비지 않은 문자열 배열이어야 한다" | e end),
                  (if (.command | type) == "string" and (.command | length) > 0 then empty else "C-03 quality[\($i)].command 는 비지 않은 문자열이어야 한다" | e end)
                end),
            ([.[] | objects | .name | strings] | group_by(.)[] | select(length > 1) | "C-03 quality name \($q)\(.[0])\($q) 이 겹친다" | e)
          end
      else empty end),
      (if has("shared") then .shared
        | if type != "object" then "C-03 shared 는 객체여야 한다" | e else
            ((keys - ["paths", "content"])[] | "C-03 shared 에 알 수 없는 키 \($q)\(.)\($q)" | e),
            (if (has("paths") or has("content")) | not then "C-03 shared 에 paths · content 중 하나는 있어야 한다" | e else empty end),
            (if has("paths") and ((.paths | strarr) | not) then "C-03 shared.paths 는 비지 않은 문자열 배열이어야 한다" | e else empty end),
            (if has("content") and ((.content | strarr) | not) then "C-03 shared.content 는 비지 않은 문자열 배열이어야 한다" | e
             else ((.content // [])[] | . as $re | try ("" | test($re) | empty) catch ("C-04 shared.content /\($re)/ 는 올바른 정규식이 아니다" | e)) end)
          end
      else empty end)
    end' "$CONFIG")"

  if ! printf '%s\n' "$findings" | grep -q '^E'; then
    if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
      files="$(git -C "$ROOT" ls-files -co --exclude-standard 2>/dev/null)"
    else
      files="$(cd "$ROOT" && find . -type f -not -path './.git/*' -not -path '*/node_modules/*' | sed 's#^\./##')"
    fi
    findings="$findings
$(printf '%s\n' "$files" | jq -R . | jq -s -r --arg q "'" --slurpfile cfg "$CONFIG" "$JQ_LIB"'
  . as $files | $cfg[0]
  | [(.test.code // [])[] | ["test.code", .]]
    + [(.test.tests // [])[] | ["test.tests", .]]
    + [(.quality // [])[] | .name as $n | .paths[] | ["quality \($q)\($n)\($q)", .]]
    + [(.shared.paths // [])[] | ["shared.paths", .]]
  | .[] | select(.[1] | startswith("!") | not)
  | .[1] as $g | ($g | glob_re) as $r
  | select(any($files[]; test($r)) | not)
  | "W\u001fC-05 \(.[0]) 의 \($q)\($g)\($q) 에 걸리는 파일이 없다"')"
  fi

  errs="$(printf '%s\n' "$findings" | grep '^E' | cut -c3-)"
  warns="$(printf '%s\n' "$findings" | grep '^W' | cut -c3-)"
  [ -n "$warns" ] && { echo "⚠️ 경고"; printf '%s\n' "$warns" | sed 's/^/  - /'; }
  if [ -n "$errs" ]; then
    { echo "❌ code-edit-guardrail 설정 위반 ($CONFIG)"; printf '%s\n' "$errs" | sed 's/^/  - /'; } >&2
    exit 2
  fi
  echo "✅ code-edit-guardrail 설정 통과 — $(jq -r '[(if has("test") then "test" else empty end), (if has("quality") then "quality \(.quality | length) lane" else empty end), (if has("shared") then "shared" else empty end)] | join(" · ")' "$CONFIG")"
}

case "$MODE" in
  reset) mode_reset ;;
  track) mode_track ;;
  shared) mode_shared ;;
  stop) mode_stop ;;
  validate) mode_validate ;;
  *) echo "사용법: code-edit-guardrail.sh <reset|track|shared|stop|validate [루트]>" >&2; exit 1 ;;
esac
