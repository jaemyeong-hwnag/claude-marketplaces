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
ROOT="$(cd "$ROOT_IN" 2>/dev/null && pwd -P)" || { echo "❌ $ROOT_IN 에 들어갈 수 없다" >&2; exit 2; }
CONFIG="${CODE_EDIT_GUARDRAIL_CONFIG:-.claude/code-edit-guardrail.json}"
case "$CONFIG" in /*) ;; *) CONFIG="$ROOT/$CONFIG" ;; esac

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
state_paths() {
  local sid; sid="$(input_get .session_id)"; sid="$(printf '%s' "${sid:-nosession}" | tr -c 'A-Za-z0-9_.-' '_')"
  EDITS="${TMPDIR:-/tmp}/code-edit-guardrail-$sid.edits"
  ACK="${TMPDIR:-/tmp}/code-edit-guardrail-$sid.ack"
}
config_ok() { [ -f "$CONFIG" ] && jq -e 'type == "object"' "$CONFIG" >/dev/null 2>&1; }

rel_path() { # $1=경로 → 루트 기준 상대 경로. 루트 밖이면 빈 문자열. 아직 없는 디렉터리도 받는다
  local p="$1" d rest
  [ -n "$p" ] || return 0
  case "$p" in /*) ;; *) p="$ROOT/$p" ;; esac
  d="$(dirname "$p")"; rest="$(basename "$p")"
  while [ ! -d "$d" ]; do rest="$(basename "$d")/$rest"; d="$(dirname "$d")"; done
  d="$(cd "$d" && pwd -P)"
  case "$d/" in "$ROOT"/*) printf '%s' "${d#"$ROOT"}/$rest" | sed 's#^/##' ;; esac
}

mode_reset() {
  read_input; state_paths
  rm -f "$EDITS" "$ACK"
}

mode_track() {
  read_input; config_ok || exit 0
  state_paths
  local rel; rel="$(rel_path "$(input_get '.tool_input.file_path // .tool_input.notebook_path')")"
  [ -n "$rel" ] && printf '%s\n' "$rel" >> "$EDITS"
  return 0
}

mode_shared() {
  read_input; config_ok || exit 0
  jq -e 'has("shared")' "$CONFIG" >/dev/null 2>&1 || exit 0
  local rel content hits
  rel="$(rel_path "$(input_get .tool_input.file_path)")"
  [ -n "$rel" ] || exit 0
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
  config_ok || exit 0
  local active files viol="" codes tests name cmd out rc
  active="$(input_get .stop_hook_active)"
  files="$(sort -u "$EDITS" | jq -R . | jq -s -c .)"

  if jq -e 'has("test")' "$CONFIG" >/dev/null 2>&1; then
    codes="$(jq -r --argjson files "$files" "$JQ_LIB"'
      .test as $t | $files[] | select(globs_match($t.code) and (globs_match($t.tests) | not))' "$CONFIG" 2>/dev/null)"
    tests="$(jq -r --argjson files "$files" "$JQ_LIB"'.test as $t | $files[] | select(globs_match($t.tests))' "$CONFIG" 2>/dev/null)"
    if [ -n "$codes" ] && [ -z "$tests" ] && ! grep -Eq '^test:[[:space:]]*[^[:space:]]' "$ACK" 2>/dev/null; then
      viol="${viol}- G-01 코드를 고쳤는데 테스트를 고치지 않았다: $(printf '%s' "$codes" | paste -sd ' ' -)
  조치: 바뀐 동작을 덮는 테스트를 쓰거나 고친다. 동작이 그대로인 변경(리팩터 · 포맷 · 주석)이면 사용자에게 알리고 면제한다
        echo 'test: <사유>' >> \"$ACK\"
"
    fi
  fi

  while IFS=$'\x1f' read -r name cmd; do
    [ -n "$name" ] || continue
    out="$(cd "$ROOT" && bash -c "$cmd" 2>&1)"; rc=$?
    [ "$rc" = 0 ] && continue
    viol="${viol}- G-02 품질 lane '$name' 실패 (종료 코드 $rc): $cmd
$(printf '%s\n' "$out" | tail -n 20 | sed 's/^/    /')
"
  done <<EOF
$(jq -r --argjson files "$files" "$JQ_LIB"'
  (.quality // [])[] | . as $l | select(any($files[]; globs_match($l.paths))) | "\($l.name)\u001f\($l.command)"' "$CONFIG" 2>/dev/null)
EOF

  [ -n "$viol" ] || exit 0
  if [ "$active" = true ]; then
    { echo "⚠️ code-edit-guardrail — 완료 조건이 남았지만 한 번 되돌렸으므로 완료를 허용한다. 사용자에게 알린다:"; printf '%s' "$viol"; } >&2
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
