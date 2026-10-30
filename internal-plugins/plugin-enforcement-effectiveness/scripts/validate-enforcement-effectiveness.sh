#!/usr/bin/env bash
# 플러그인이 적어 둔 강제가 실행에서 효력을 내는지 검증한다 — 훅 · MCP 명령 사슬, 무시되는 에이전트 필드,
# 가려지는 이름, 조항 ↔ TC 연결, eval 유무, 그리고 (--all · --since 에서) 훅 · MCP 서버를 실제로 실행한다.
# 형식(plugin-authoring) · 위치(marketplace-directory-structure) · 순서(plugin-workflow)는 다루지 않는다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write)       → 쓰려는 hooks.json · plugin.json · 에이전트 · 스킬 · 커맨드 (차단)
#   PostToolUse(Write|Edit) → 그 파일이 속한 플러그인 전체 (알림만)
# CLI 모드 :
#   validate-enforcement-effectiveness.sh <플러그인 디렉터리> ...
#   validate-enforcement-effectiveness.sh --all [--no-run] [루트]
#   validate-enforcement-effectiveness.sh --since <ref> [--no-run] [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$SELF_ROOT/references/enforcement-effectiveness-rules.md"

NO_MATCHER_EVENTS="UserPromptSubmit Stop CwdChanged PostToolBatch TeammateIdle TaskCreated TaskCompleted WorktreeCreate WorktreeRemove MessageDisplay"
IGNORED_AGENT_KEYS="permissionMode hooks mcpServers initialPrompt"
EDIT_TOOLS="Write Edit MultiEdit NotebookEdit"
PROBE_TOOLS="Read Glob Grep WebSearch TodoWrite"
HOOK_TIMEOUT_DEFAULT=60
MCP_TIMEOUT="${EF_MCP_TIMEOUT:-15}"   # 테스트가 줄인다

MODE=dir        # dir | all | since | pre | post
RUN=1           # 3.2 절 실행 검사
NEW_PLUGIN=0    # since 에서 기준에 없던 플러그인
ERRORS=()
WARNINGS=()
NOTES=()

die() { echo "validate-enforcement-effectiveness: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"
command -v perl >/dev/null 2>&1 || die "perl 이 필요합니다"

err() { ERRORS+=("$1"); }
warn() { WARNINGS+=("$1"); }
note() { NOTES+=("$1"); }
# 모드에 따라 등급이 바뀌는 조항
flag_ef07() { if [ "$MODE" = since ]; then err "$1"; else warn "$1"; fi; }
flag_ef31() { if [ "$MODE" = since ] && [ "$NEW_PLUGIN" = 1 ]; then err "$1"; else warn "$1"; fi; }

in_list() { # $1=단어 $2=공백 구분 목록
  case " $2 " in *" $1 "*) return 0 ;; esac; return 1
}

# 셸 명령 문자열을 토큰으로 나눈다 (작은따옴표 · 큰따옴표 · 역슬래시). 한 줄에 하나.
tokenize() {
  perl -e '
    my $s = shift; my @t; my $cur; my $in = 0;
    while (length $s) {
      if ($s =~ s/^\s+//) { if ($in) { push @t, $cur; $cur = ""; $in = 0 } next }
      if ($s =~ s/^\x27([^\x27]*)\x27//) { $cur .= $1; $in = 1; next }
      if ($s =~ s/^"((?:[^"\\]|\\.)*)"//) { my $x = $1; $x =~ s/\\(.)/$1/g; $cur .= $x; $in = 1; next }
      if ($s =~ s/^\\(.)//) { $cur .= $1; $in = 1; next }
      $s =~ s/^([^\s\x27"\\]+)//; $cur .= $1; $in = 1;
    }
    push @t, $cur if $in;
    print "$_\n" for @t;
  ' "$1"
}

# 토큰이 플러그인 루트를 가리키면 상대 경로를, 아니면 빈 값을 낸다
plugin_root_rel() { # $1=토큰
  case "$1" in
    '${CLAUDE_PLUGIN_ROOT}/'*) printf '%s' "${1#'${CLAUDE_PLUGIN_ROOT}/'}" ;;
    '$CLAUDE_PLUGIN_ROOT/'*)   printf '%s' "${1#'$CLAUDE_PLUGIN_ROOT/'}" ;;
  esac
}

# 플러그인 상대 경로로 읽히는 토큰인가 (EF-01)
is_relative_token() { # $1=토큰
  local t="$1"
  t="$(printf '%s' "$t" | sed -E 's/^[0-9]*[<>]+&?//; s/^[A-Za-z_][A-Za-z0-9_]*=//')"
  [ -n "$t" ] || return 1
  case "$t" in
    /*|\$*|~*|-*) return 1 ;;
    *://*) return 1 ;;
    */*) return 0 ;;
  esac
  return 1
}

# ---- EF-01 ~ EF-03 : 명령 하나 ---------------------------------------------
# $1=플러그인 디렉터리 $2=라벨 $3=첫 토큰이 실행 파일인가(1/0) $4=static(1이면 EF-02·03 도) 나머지=토큰
check_exec_tokens() {
  local dir="$1" label="$2" direct="$3" deep="$4" first=1 tok rel f mode
  shift 4
  for tok in "$@"; do
    if is_relative_token "$tok"; then
      err "$label: '$tok' 는 플러그인 상대 경로입니다 — 훅 · MCP 는 프로젝트 cwd 에서 돌아 찾지 못하고 조용히 통과됩니다. \"\${CLAUDE_PLUGIN_ROOT}/…\" 로 쓰세요 (EF-01)"
    fi
    rel="$(plugin_root_rel "$tok")"
    if [ "$deep" = 1 ] && [ -n "$rel" ]; then
      f="$dir/$rel"
      if [ ! -e "$f" ]; then
        err "$label: '$tok' 가 가리키는 파일이 없습니다 — 훅이 실패하고 도구 호출이 그대로 통과합니다 (EF-02)"
      elif [ "$first" = 1 ] && [ "$direct" = 1 ]; then
        if [ ! -x "$f" ]; then
          err "$label: '$rel' 에 실행 권한이 없습니다 — chmod +x 하세요 (EF-03)"
        elif git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
          mode="$(git -C "$dir" ls-files -s -- "$rel" 2>/dev/null | awk '{print $1; exit}')"
          if [ -n "$mode" ] && [ "$mode" != 100755 ]; then
            err "$label: '$rel' 의 git 인덱스 모드가 $mode 입니다 — 설치본은 실행 권한 없이 받습니다. git update-index --chmod=+x 하세요 (EF-03)"
          fi
        fi
      fi
    fi
    first=0
  done
}

# hooks.json 내용을 검사한다. $1=플러그인 디렉터리 $2=JSON 파일 $3=라벨 $4=deep(1/0)
check_hooks_json() {
  local dir="$1" file="$2" label="$3" deep="$4" ev has_m type cmd args_json of i
  jq -e . "$file" >/dev/null 2>&1 || return 0   # JSON 오류는 validate --strict 의 몫
  while IFS=$'\x1f' read -r ev has_m type cmd args_json of; do
    [ -n "$ev" ] || continue
    if [ "$has_m" = 1 ] && in_list "$ev" "$NO_MATCHER_EVENTS"; then
      err "$label: $ev 는 matcher 를 받지 않습니다 — 조용히 무시돼 훅이 매번 돕니다. matcher 를 지우세요 (EF-04)"
    fi
    [ "$type" = command ] || continue
    local -a toks=()
    while IFS= read -r i; do toks+=("$i"); done < <(tokenize "$cmd")
    while IFS= read -r i; do toks+=("$i"); done < <(printf '%s' "$args_json" | jq -r '.[]?' 2>/dev/null)
    [ "${#toks[@]}" -gt 0 ] && check_exec_tokens "$dir" "$label $ev" 1 "$deep" "${toks[@]}"
    if { [ "$ev" = PreToolUse ] || [ "$ev" = UserPromptSubmit ]; } && [ "$of" != block ] && [ "$deep" = 1 ]; then
      flag_ef07 "$label $ev: '$cmd' 에 \"onFailure\": \"block\" 이 없습니다 — 스크립트가 깨지면 막지 않고 통과합니다 (EF-07)"
    fi
  done < <(jq -r '
    (.hooks // {}) | to_entries[] | .key as $e | .value[]? |
    (if has("matcher") then "1" else "0" end) as $m |
    (.hooks // [])[] |
    [$e, $m, (.type // ""), (.command // ""), ((.args // []) | tojson), (.onFailure // "")] | join("\u001f")
  ' "$file" 2>/dev/null)
}

# MCP stdio 서버 정의를 "이름<US>command<US>args JSON" 으로 낸다. $1=플러그인 디렉터리 $2=plugin.json 대체 내용 파일(없으면 디스크)
mcp_servers() {
  local dir="$1" pj="${2:-$1/.claude-plugin/plugin.json}" ref
  {
    if [ -r "$pj" ]; then
      ref="$(jq -r 'if (.mcpServers | type) == "string" then .mcpServers else empty end' "$pj" 2>/dev/null)"
      if [ -n "$ref" ]; then
        ref="${ref#./}"; [ -r "$dir/$ref" ] && jq -c '.mcpServers // .' "$dir/$ref" 2>/dev/null
      else
        jq -c 'if (.mcpServers | type) == "object" then .mcpServers else empty end' "$pj" 2>/dev/null
      fi
    fi
    [ -r "$dir/.mcp.json" ] && jq -c '.mcpServers // .' "$dir/.mcp.json" 2>/dev/null
  } | jq -r 'to_entries[] | select(.value | type == "object") | select(.value.command) |
      [.key, .value.command, ((.value.args // []) | tojson)] | join("\u001f")' 2>/dev/null
}

check_mcp_static() { # $1=플러그인 디렉터리 $2=라벨 $3=deep $4=plugin.json 대체
  local dir="$1" label="$2" deep="$3" name cmd args i
  while IFS=$'\x1f' read -r name cmd args; do
    [ -n "$name" ] || continue
    local -a toks=("$cmd")
    while IFS= read -r i; do toks+=("$i"); done < <(printf '%s' "$args" | jq -r '.[]?' 2>/dev/null)
    check_exec_tokens "$dir" "$label mcpServers.$name" 1 "$deep" "${toks[@]}"
  done < <(mcp_servers "$dir" "${4:-}")
}

# ---- EF-10 ~ EF-12 : 에이전트 프런트매터 ---------------------------------
# 프런트매터의 최상위 키를 한 줄씩 낸다. 닫히지 않으면 아무것도 내지 않는다 (형식은 plugin-authoring 의 몫).
fm_keys() { awk 'NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit; next } /^---[[:space:]]*$/ { exit } /^[A-Za-z_][A-Za-z0-9_-]*:/ { sub(/:.*/, ""); print }' "$1"; }
# tools 값을 한 줄에 하나씩 (쉼표 문자열 · 흐름 목록 · 블록 목록)
fm_tools() {
  awk '
    NR == 1 { next } /^---[[:space:]]*$/ { exit }
    /^tools:/ { on = 1; v = $0; sub(/^tools:[[:space:]]*/, "", v); gsub(/[][]/, "", v); n = split(v, a, ","); for (i = 1; i <= n; i++) { x = a[i]; gsub(/^[[:space:]"\x27]+|[[:space:]"\x27]+$/, "", x); if (x != "") print x } next }
    on && /^[[:space:]]+-/ { x = $0; sub(/^[[:space:]]+-[[:space:]]*/, "", x); gsub(/^["\x27]+|["\x27]+$/, "", x); if (x != "") print x; next }
    { on = 0 }
  ' "$1"
}
fm_value() { # $1=파일 $2=키
  awk -v k="$2" 'NR == 1 { next } /^---[[:space:]]*$/ { exit } index($0, k ":") == 1 { v = substr($0, length(k) + 2); gsub(/^[[:space:]"\x27]+|[[:space:]"\x27]+$/, "", v); print v; exit }' "$1"
}

check_agent() { # $1=파일 $2=라벨 $3=경고도 낼까(1/0)
  local f="$1" label="$2" warns="$3" keys k t
  keys="$(fm_keys "$f")"
  [ -n "$keys" ] || return 0
  for k in $IGNORED_AGENT_KEYS; do
    printf '%s\n' "$keys" | grep -qx -- "$k" && \
      err "$label: '$k' 는 플러그인 에이전트에서 무시됩니다 — 걸릴 거라 믿은 제약이 실행에서 없습니다. 지우세요 (EF-10)"
  done
  if ! printf '%s\n' "$keys" | grep -qx tools; then
    err "$label: tools 가 없습니다 — 생략하면 모든 도구를 물려받습니다. 필요한 도구만 적으세요 (EF-11)"
  elif [ "$warns" = 1 ]; then
    while IFS= read -r t; do
      in_list "$t" "$EDIT_TOOLS" && warn "$label: tools 에 편집 도구 '$t' 가 있습니다 — 검토 · 검색 에이전트라면 빼세요 (EF-12)"
    done < <(fm_tools "$f")
  fi
}

# ---- EF-05 · EF-06 : 조항 ↔ TC ----------------------------------------------
# 규칙 원본 표에서 판정 · 검증 열이 차단 · 경고인 조항 ID
enforced_ids() { # $@=references/*.md
  awk -F'|' '
    /^\|/ {
      if (!intab) { intab = 1; col = 0; for (i = 2; i < NF; i++) { g = $i; gsub(/[[:space:]*`]/, "", g); if (g == "판정" || g == "검증") col = i } next }
      if ($0 ~ /^\|[-:[:space:]|]+\|[[:space:]]*$/) next
      id = $2; gsub(/[[:space:]`*]/, "", id)
      if (col && id ~ /^[A-Z]+-[0-9]+[a-z]?$/ && $col ~ /차단|경고/) print id
      next
    }
    { intab = 0; col = 0 }
  ' "$@" 2>/dev/null | sort -u
}

check_clause_links() { # $1=플러그인 디렉터리 $2=플러그인명
  local dir="$1" name="$2" ids id
  any_file "$dir"/references/*.md || return 0
  ids="$(enforced_ids "$dir"/references/*.md)"
  [ -n "$ids" ] || return 0
  while IFS= read -r id; do
    any_file "$dir"/test/*.test.sh && grep -qE "(^|[^A-Za-z0-9])$id([^0-9a-z]|\$)" "$dir"/test/*.test.sh 2>/dev/null && continue
    err "$name: 규칙 원본의 '$id' 는 차단 · 경고 조항인데 test/*.test.sh 에 ID 가 없습니다 — 그 조항을 막는 TC 설명에 ID 를 다세요 (EF-05)"
  done <<< "$ids"
  any_file "$dir"/scripts/validate-*.sh "$dir"/hooks/hooks.json || \
    err "$name: 규칙 원본에 차단 · 경고 조항이 있는데 scripts/validate-*.sh 도 hooks/hooks.json 도 없습니다 — 규칙이 문서에만 있습니다 (EF-06)"
}

any_file() { local f; for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }

# ---- EF-13 : 커맨드 · 스킬 이름 ----------------------------------------------
check_name_clash() { # $1=플러그인 디렉터리 $2=플러그인명
  local dir="$1" name="$2" s
  for s in "$dir"/skills/*/; do
    [ -d "$s" ] || continue
    s="$(basename "$s")"
    [ -e "$dir/commands/$s.md" ] && \
      err "$name: skills/$s 와 commands/$s.md 의 이름이 같습니다 — /$name:$s 로 하나만 닿습니다. 하나의 이름을 바꾸세요 (EF-13)"
  done
}

# ---- EF-30 · EF-31 : eval -------------------------------------------------
case_tags() { # stdin 없음 $1=prompt.md 또는 case.yaml → 태그 한 줄씩
  awk '
    /^tags:/ { v = $0; sub(/^tags:[[:space:]]*/, "", v); gsub(/[][]/, "", v); n = split(v, a, ","); for (i = 1; i <= n; i++) { x = a[i]; gsub(/^[[:space:]"\x27]+|[[:space:]"\x27]+$/, "", x); if (x != "") print x } on = 1; next }
    on && /^[[:space:]]+-/ { x = $0; sub(/^[[:space:]]+-[[:space:]]*/, "", x); gsub(/["\x27]/, "", x); print x; next }
    { on = 0 }
  ' "$1"
}
has_case_tag() { # $1=플러그인 디렉터리 $2=태그
  local f
  while IFS= read -r f; do
    case_tags "$f" | grep -qx -- "$2" && return 0
  done < <(find "$1/evals" -type f \( -name prompt.md -o -name case.yaml \) 2>/dev/null)
  return 1
}

# 그레이더 정규식을 문자열에 적용한다. 0 맞음 / 1 안 맞음 / 3 정규식 오류
regex_match() { # $1=정규식 $2=문자열
  if command -v node >/dev/null 2>&1; then
    node -e 'try { process.exit(new RegExp(process.argv[1]).test(process.argv[2]) ? 0 : 1) } catch (e) { process.exit(3) }' "$1" "$2"
    return $?
  fi
  case "$1" in *'(?'[a-z]*) return 3 ;; esac
  perl -e 'my ($r, $s) = @ARGV; my $ok = eval { $s =~ /$r/ }; exit(defined $ok ? ($ok ? 0 : 1) : 3)' "$1" "$2"
}

skill_graders() { # $1=플러그인 디렉터리 → tool: Skill 그레이더의 input_match (없으면 __ANY__ — 아무 스킬에나 맞는다)
  local g
  while IFS= read -r g; do
    awk '/^---/ { c++; next } c == 1' "$g" | grep -qE '^tool:[[:space:]]*"?Skill"?[[:space:]]*$' || continue
    awk '/^---/ { c++; next } c == 1 && /^input_match:/ { sub(/^input_match:[[:space:]]*/, ""); print; f = 1 } END { if (!f) print "__ANY__" }' "$g" \
      | perl -ne 's/\s+$//; if (/^\x27(.*)\x27$/) { ($_ = $1) =~ s/\x27\x27/\x27/g } elsif (/^"(.*)"$/) { ($_ = $1) =~ s/\\(.)/$1/g } print "$_\n"'
  done < <(find "$1/evals" -path '*/graders/*.md' -type f 2>/dev/null | sort)
}

check_evals() { # $1=플러그인 디렉터리 $2=플러그인명
  local dir="$1" name="$2" f s graders re hit rc
  if any_file "$dir"/skills/*/SKILL.md && ! has_case_tag "$dir" trigger; then
    err "$name: 스킬이 있는데 evals/ 에 tags: [trigger] 케이스가 없습니다 — 스킬이 발동하는지 아무도 재지 않습니다 (EF-30)"
  fi
  if [ -r "$dir/hooks/hooks.json" ] && ! has_case_tag "$dir" hook; then
    err "$name: hooks/hooks.json 이 있는데 evals/ 에 tags: [hook] 케이스가 없습니다 — 훅이 실제로 막는지 아무도 재지 않습니다 (EF-30)"
  fi
  graders="$(skill_graders "$dir")"
  for f in "$dir"/skills/*/SKILL.md; do
    [ -r "$f" ] || continue
    s="$(basename "$(dirname "$f")")"
    [ "$(fm_value "$f" disable-model-invocation)" = true ] && continue
    hit=0
    if [ -n "$graders" ]; then
      while IFS= read -r re; do
        [ "$re" = __ANY__ ] && { hit=1; break; }
        [ -n "$re" ] || continue
        regex_match "$re" "{\"skill\": \"$name:$s\"}"; rc=$?
        if [ "$rc" = 3 ]; then
          flag_ef31 "$name: 그레이더 input_match '$re' 가 JS 정규식으로 읽히지 않습니다 — eval 에서 grader threw 로 실패합니다 (EF-31)"
          continue
        fi
        [ "$rc" = 0 ] && { hit=1; break; }
      done <<< "$graders"
    fi
    [ "$hit" = 1 ] || flag_ef31 "$name: 스킬 '$s' 에 발동 그레이더(tool: Skill, input_match 가 \"$name:$s\" 에 맞는 것)가 없습니다 (EF-31)"
  done
}

# ---- EF-20 : 훅 실행 --------------------------------------------------------
# matcher 에 맞지 않는 도구 이름. 모두 맞으면 빈 값
probe_tool() { # $1=matcher
  local m="$1" t
  case "$m" in ""|"*") echo Read; return ;; esac
  for t in $PROBE_TOOLS; do
    perl -e 'my ($m, $t) = @ARGV; my $ok = eval { $t =~ /^(?:$m)$/ }; exit($ok ? 0 : 1)' "$m" "$t" || { echo "$t"; return; }
  done
}

run_with_timeout() { # $1=초 나머지=명령 → stdout 은 그대로, 시간 초과면 142 (macOS 에는 timeout 이 없다)
  perl -e 'my $s = shift; my $pid = fork;
    if (!$pid) { setpgrp(0, 0); exec @ARGV or exit 127 }
    $SIG{ALRM} = sub { kill "KILL", -$pid; waitpid($pid, 0); exit 142 }; alarm $s;
    waitpid($pid, 0); exit($? >> 8)' "$@"
}

run_hooks() { # $1=플러그인 디렉터리 $2=플러그인명
  local dir="$1" name="$2" file="$1/hooks/hooks.json" ev m cmd to tool input tmp out code
  [ -r "$file" ] || return 0
  jq -e . "$file" >/dev/null 2>&1 || return 0
  while IFS=$'\x1f' read -r ev m cmd to; do
    [ -n "$ev" ] || continue
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/ef-hook.XXXXXX")"
    case "$ev" in
      PreToolUse|PostToolUse)
        tool="$(probe_tool "$m")"
        if [ -z "$tool" ]; then note "$name $ev [$m]: matcher 가 시험 도구를 모두 받아 실행 안 함 (EF-20)"; rm -rf "$tmp"; continue; fi
        input="$(jq -nc --arg e "$ev" --arg c "$tmp" --arg t "$tool" '{hook_event_name:$e, session_id:"ef-probe", cwd:$c, transcript_path:($c+"/none.jsonl"), tool_name:$t, tool_input:{file_path:($c+"/none.txt"), pattern:"x", query:"x", todos:[]}} + (if $e == "PostToolUse" then {tool_response:{}} else {} end)')" ;;
      UserPromptSubmit) input="$(jq -nc --arg c "$tmp" '{hook_event_name:"UserPromptSubmit", session_id:"ef-probe", cwd:$c, transcript_path:($c+"/none.jsonl"), prompt:"안녕"}')" ;;
      Stop)             input="$(jq -nc --arg c "$tmp" '{hook_event_name:"Stop", session_id:"ef-probe", cwd:$c, transcript_path:($c+"/none.jsonl"), stop_hook_active:false}')" ;;
      SessionStart)     input="$(jq -nc --arg c "$tmp" '{hook_event_name:"SessionStart", session_id:"ef-probe", cwd:$c, transcript_path:($c+"/none.jsonl"), source:"startup"}')" ;;
      *) note "$name $ev: 시험 입력이 없는 이벤트라 실행 안 함 (EF-20)"; rm -rf "$tmp"; continue ;;
    esac
    out="$(cd "$tmp" && printf '%s' "$input" | CLAUDE_PLUGIN_ROOT="$dir" CLAUDE_PROJECT_DIR="$tmp" TMPDIR="$tmp" \
           run_with_timeout "${to:-$HOOK_TIMEOUT_DEFAULT}" bash -c "$cmd" 2>/dev/null)"; code=$?
    rm -rf "$tmp"
    if [ "$code" = 142 ]; then
      warn "$name $ev: '$cmd' 가 무관한 입력에 timeout ${to:-$HOOK_TIMEOUT_DEFAULT}초 안에 끝나지 않습니다 (EF-20)"
    elif [ "$code" != 0 ]; then
      warn "$name $ev: '$cmd' 가 무관한 입력(${tool:-$ev})에 exit $code 입니다 — 상관없는 작업을 막거나 오류를 냅니다 (EF-20)"
    elif printf '%s' "$out" | grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"|"decision"[[:space:]]*:[[:space:]]*"block"'; then
      warn "$name $ev: '$cmd' 가 무관한 입력(${tool:-$ev})을 deny · block 합니다 (EF-20)"
    fi
    tool=""
  done < <(jq -r '(.hooks // {}) | to_entries[] | .key as $e | .value[]? | (.matcher // "") as $m |
      (.hooks // [])[] | select(.type == "command") | [$e, $m, .command, ((.timeout // "") | tostring)] | join("\u001f")' "$file" 2>/dev/null)
}

# ---- EF-21 · EF-22 : MCP 실행 -----------------------------------------------
# 서버를 띄워 initialize → initialized → tools/list. 첫 줄 OK 또는 FAIL 사유, 다음 줄부터 도구 이름
mcp_probe() { # $1=플러그인 디렉터리 $2=command $3=args JSON
  local dir="$1" cmd="${2//\$\{CLAUDE_PLUGIN_ROOT\}/$1}" tmp
  local -a argv=("$cmd")
  while IFS= read -r a; do argv+=("${a//\$\{CLAUDE_PLUGIN_ROOT\}/$dir}"); done < <(printf '%s' "$3" | jq -r '.[]?' 2>/dev/null)
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/ef-mcp.XXXXXX")"
  (cd "$tmp" && CLAUDE_PLUGIN_ROOT="$dir" CLAUDE_PROJECT_DIR="$tmp" perl -e '
    use IPC::Open2; my $t = shift; my ($out, $in);
    my $pid = eval { open2($out, $in, @ARGV) } or do { print "FAIL 실행하지 못했습니다\n"; exit };
    $SIG{PIPE} = "IGNORE";
    local $SIG{ALRM} = sub { print "FAIL ${t}초 안에 응답이 없습니다\n"; kill "KILL", $pid; exit };
    alarm $t; select((select($in), $| = 1)[0]);
    print $in q({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"ef-probe","version":"0"}}}), "\n";
    my $ok = 0;
    while (my $l = <$out>) { if ($l =~ /"id"\s*:\s*1\b/ && $l =~ /"result"/) { $ok = 1; last } }
    if (!$ok) { print "FAIL initialize 응답이 없습니다\n"; kill "KILL", $pid; exit }
    print "OK\n";
    print $in q({"jsonrpc":"2.0","method":"notifications/initialized"}), "\n";
    print $in q({"jsonrpc":"2.0","id":2,"method":"tools/list"}), "\n";
    while (my $l = <$out>) { if ($l =~ /"id"\s*:\s*2\b/) { print "TOOLS\n", $l; last } }
    kill "TERM", $pid;
  ' "$MCP_TIMEOUT" "${argv[@]}" 2>/dev/null)
  rm -rf "$tmp"
}

run_mcp() { # $1=플러그인 디렉터리 $2=플러그인명
  local dir="$1" name="$2" srv cmd args res tools used u
  while IFS=$'\x1f' read -r srv cmd args; do
    [ -n "$srv" ] || continue
    res="$(mcp_probe "$dir" "$cmd" "$args")"
    case "$(printf '%s\n' "$res" | head -1)" in
      OK) ;;
      *) err "$name mcpServers.$srv: $(printf '%s\n' "$res" | head -1 | sed 's/^FAIL //') — 서버가 뜨지 않으면 도구가 조용히 빠집니다 (EF-21)"; continue ;;
    esac
    tools="$(printf '%s\n' "$res" | sed -n '/^TOOLS$/{n;p;}' | jq -r '.result.tools[]?.name' 2>/dev/null)"
    used="$(grep -rhoE "mcp__plugin_${name}_${srv}__[A-Za-z0-9_-]+" "$dir/skills" "$dir/commands" "$dir/agents" "$dir/references" 2>/dev/null | sort -u)"
    while IFS= read -r u; do
      [ -n "$u" ] || continue
      printf '%s\n' "$tools" | grep -qxF -- "${u##*__}" || \
        err "$name: '$u' 는 서버 $srv 의 tools/list 에 없습니다 — 모델이 부를 수 없는 도구를 지시합니다 (EF-22)"
    done <<< "$used"
  done < <(mcp_servers "$dir")
}

# ---- 플러그인 하나 ---------------------------------------------------------
validate_plugin_dir() { # $1=디렉터리
  local dir="${1%/}" name f
  [ -d "$dir" ] || die "'$dir' 디렉터리가 없습니다"
  dir="$(cd "$dir" && pwd)"
  name="$(basename "$dir")"
  [ -r "$dir/hooks/hooks.json" ] && check_hooks_json "$dir" "$dir/hooks/hooks.json" "$name/hooks/hooks.json" 1
  check_mcp_static "$dir" "$name/.claude-plugin/plugin.json" 1
  for f in "$dir"/agents/*.md; do
    [ -r "$f" ] && check_agent "$f" "$name/agents/$(basename "$f")" 1
  done
  check_name_clash "$dir" "$name"
  check_clause_links "$dir" "$name"
  check_evals "$dir" "$name"
  if [ "$RUN" = 1 ] && { [ "$MODE" = all ] || [ "$MODE" = since ]; }; then
    run_hooks "$dir" "$name"
    run_mcp "$dir" "$name"
  fi
}

list_plugins() { # $1=루트
  local root="$1" pd d
  find "$root" -mindepth 1 -maxdepth 1 -type d -name '*plugins' -not -path "$root/.git*" 2>/dev/null | sort \
    | while IFS= read -r pd; do find "$pd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort; done \
    | while IFS= read -r d; do [ -r "$d/.claude-plugin/plugin.json" ] && echo "$d"; done
}

validate_all() { # $1=루트
  local root d n=0
  [ -d "$1" ] || die "--all: '$1' 디렉터리가 없습니다"
  root="$(cd "$1" && pwd)"
  while IFS= read -r d; do n=$((n + 1)); validate_plugin_dir "$d"; done < <(list_plugins "$root")
  [ "$n" -gt 0 ] || die "--all: '$root' 에서 플러그인을 하나도 찾지 못했습니다 — 마켓플레이스 루트(*-plugins/ 를 가진 디렉터리)를 주세요"
}

# ref 와의 merge-base 이후 파일이 바뀐 플러그인만. 기준에 plugin.json 이 없던 플러그인은 새 플러그인이다.
validate_since() { # $1=ref $2=루트
  local ref="$1" root d rel base
  [ -d "$2" ] || die "--since: '$2' 디렉터리가 없습니다"
  root="$(cd "$2" && pwd)"
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || die "--since: $root 는 git 저장소가 아닙니다"
  git -C "$root" rev-parse --verify -q "$ref^{commit}" >/dev/null || die "--since: '$ref' 를 찾을 수 없습니다"
  base="$(git -C "$root" merge-base "$ref" HEAD 2>/dev/null)" || base="$ref"
  while IFS= read -r d; do
    rel="${d#"$root"/}"
    if git -C "$root" diff --quiet "$base" -- "$rel" 2>/dev/null \
       && [ -z "$(git -C "$root" ls-files --others --exclude-standard -- "$rel" 2>/dev/null)" ]; then
      continue
    fi
    if git -C "$root" cat-file -e "$base:$rel/.claude-plugin/plugin.json" 2>/dev/null; then NEW_PLUGIN=0; else NEW_PLUGIN=1; fi
    validate_plugin_dir "$d"
  done < <(list_plugins "$root")
  NEW_PLUGIN=0
}

report() {
  local x
  for x in ${NOTES+"${NOTES[@]}"}; do echo "ℹ️  $x" >&2; done
  for x in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $x" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 강제 실효성 위반 (plugin-enforcement-effectiveness)" >&2
    for x in "${ERRORS[@]}"; do echo "  - $x" >&2; done
    echo "" >&2
    echo "규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

emit_notices_json() {
  local body n
  [ "${#ERRORS[@]}" -gt 0 ] || [ "${#WARNINGS[@]}" -gt 0 ] || return 0
  body="강제 실효성 알림 (plugin-enforcement-effectiveness) — 막지 않았습니다. 이어서 맞추세요."
  for n in ${ERRORS+"${ERRORS[@]}"}; do body="$body"$'\n'"- $n"; done
  for n in ${WARNINGS+"${WARNINGS[@]}"}; do body="$body"$'\n'"- (경고) $n"; done
  body="$body"$'\n'"기준: $RULES"
  jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
}

# 경로 → 플러그인 디렉터리와 내부 상대경로. 플러그인 밖이면 1
split_plugin_path() { # $1=경로 → PLUGIN_DIR_OUT · REL_OUT
  local p="$1" rest name
  [[ "$p" == *plugins/* ]] || return 1
  rest="${p##*plugins/}"; name="${rest%%/*}"
  [ "$rest" != "$name" ] && [ -n "$name" ] || return 1
  PLUGIN_DIR_OUT="${p%"$rest"}$name"; REL_OUT="${rest#*/}"
}

hook_pre() { # $1=경로 $2=payload
  local path="$1" payload="$2" tmp name s
  [ "$(printf '%s' "$payload" | jq -r '.tool_name // ""')" = Write ] || exit 0
  split_plugin_path "$path" || exit 0
  name="$(basename "$PLUGIN_DIR_OUT")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/ef-pre.XXXXXX")"
  printf '%s' "$payload" | jq -r '.tool_input.content // ""' > "$tmp"
  case "$REL_OUT" in
    hooks/hooks.json)          check_hooks_json "$PLUGIN_DIR_OUT" "$tmp" "$name/hooks/hooks.json" 0 ;;
    .claude-plugin/plugin.json) check_mcp_static "$PLUGIN_DIR_OUT" "$name/.claude-plugin/plugin.json" 0 "$tmp" ;;
    agents/*.md)               check_agent "$tmp" "$name/$REL_OUT" 0 ;;
    skills/*/SKILL.md)
      s="$(basename "$(dirname "$path")")"
      [ -e "$PLUGIN_DIR_OUT/commands/$s.md" ] && \
        err "$name: skills/$s 를 만들려는데 commands/$s.md 가 있습니다 — /$name:$s 로 하나만 닿습니다 (EF-13)" ;;
    commands/*.md)
      s="$(basename "$path" .md)"
      [ -d "$PLUGIN_DIR_OUT/skills/$s" ] && \
        err "$name: commands/$s.md 를 만들려는데 skills/$s 가 있습니다 — /$name:$s 로 하나만 닿습니다 (EF-13)" ;;
  esac
  rm -f "$tmp"
  WARNINGS=()   # Pre 의 exit 0 stderr 는 모델이 보지 못한다 — 경고는 Post 가 알린다
  report
}

hook_post() { # $1=경로
  split_plugin_path "$1" || exit 0
  case "$REL_OUT" in
    hooks/*|.claude-plugin/plugin.json|.mcp.json|agents/*|skills/*|commands/*|references/*|test/*|evals/*|scripts/*) ;;
    *) exit 0 ;;
  esac
  [ -r "$PLUGIN_DIR_OUT/.claude-plugin/plugin.json" ] || exit 0
  MODE=post
  validate_plugin_dir "$PLUGIN_DIR_OUT"
  emit_notices_json
  exit 0
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --all)
        MODE=all; shift
        [ "${1:-}" = --no-run ] && { RUN=0; shift; }
        validate_all "${1:-$PROJECT_DIR}" ;;
      --since)
        [ -n "${2:-}" ] || die "--since 에는 ref 가 필요합니다 (예: --since origin/main)"
        MODE=since; local ref="$2"; shift 2
        [ "${1:-}" = --no-run ] && { RUN=0; shift; }
        validate_since "$ref" "${1:-$PROJECT_DIR}" ;;
      *) MODE=dir; for arg in "$@"; do validate_plugin_dir "$arg"; done ;;
    esac
    report
  fi
  local payload event path
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)"
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
  [ -n "$path" ] || exit 0
  case "$event" in
    PostToolUse) hook_post "$path" ;;
    *)           MODE=pre; hook_pre "$path" "$payload" ;;
  esac
  exit 0
}

main "$@"
