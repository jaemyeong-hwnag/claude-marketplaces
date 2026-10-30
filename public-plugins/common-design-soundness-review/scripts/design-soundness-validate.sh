#!/usr/bin/env bash
# 설계 건전성 — DD-20 ~ DD-24 기계 신호 · DD-30 ~ DD-32 게이트. 규칙: references/design-soundness-rules.md
#   design-soundness-validate.sh --hook                       훅 (stdin 에 훅 입력)
#   design-soundness-validate.sh [--plan] [--strict] <파일>…  설계 파일의 DD-20 ~ DD-24 신호
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$PLUGIN_ROOT/references/design-soundness-rules.md"
PATTERNS="$PLUGIN_ROOT/references/design-soundness-patterns.json"
MIN_LINES=3
REQ_ID_RE="${DESIGN_SOUNDNESS_REQUIREMENT_ID:-(R|FR|NFR|QA|REQ)-[0-9]+}"
US="$(printf '\037')"

die() { echo "design-soundness-validate: $*" >&2; exit 1; }

pat() { jq -r "$1" "$PATTERNS"; }

# $1=파일 $2=document|plan → "DD-2x<US>메시지" 줄
analyze() {
  local secs edges
  secs="$(jq -r --arg k "$2" '[.sections[$k][] | "\(.name)\u001f\(.re)"] | join("\u001e")' "$PATTERNS")"
  edges="$(mktemp "${TMPDIR:-/tmp}/design-soundness.XXXXXX")" || return 0
  # LC_ALL=C — 글자 수 · 대소문자를 awk 구현과 상관없이 바이트로 같게 센다
  LC_ALL=C awk -v secs="$secs" -v reqre="$(pat .requirement_section_re)" -v decre="$(pat .decision_section_re)" \
      -v glore="$(pat .glossary_section_re)" -v qre="$(pat .quality_words_re)" -v idre="$REQ_ID_RE" \
      -v edges="$edges" -v US="$US" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function nodeid(s) { s = trim(s); if (s ~ /^\[\*\]/) return "[*]"; if (match(s, /^[^ \t\[\(\{>:;]+/)) return substr(s, 1, RLENGTH); return "" }
    function edge_line(l,    n, parts, i, a, b, la, lb, x, y, bidi, u, v) {
      if (mtype == "state") sub(/[ \t]*:.*$/, "", l)          # A --> B : 라벨
      else { gsub(/"[^"]*"/, "", l); for (i = 0; i < 2; i++) gsub(/\[[^]]*\]|\([^)]*\)|\{[^}]*\}/, "", l) }   # 노드 라벨
      sub(/;[ \t]*$/, "", l)
      gsub(/\|[^|]*\|/, " ", l)                                # A -->|라벨| B
      bidi = (l ~ /<-+>/); gsub(/<-+>/, "\001", l)             # A <--> B
      gsub(/-\.[ \t]+[^>]*\.->/, "\001", l)                    # A -. 라벨 .-> B
      gsub(/--[ \t]+[^>]*-->/, "\001", l)                      # A -- 라벨 --> B
      gsub(/(-\.+-|==+|--+)>/, "\001", l)
      if (index(l, "\001") == 0) return
      n = split(l, parts, "\001")
      for (i = 1; i < n; i++) {
        la = split(parts[i], a, "&"); lb = split(parts[i + 1], b, "&")
        for (x = 1; x <= la; x++) for (y = 1; y <= lb; y++) {
          u = nodeid(a[x]); v = nodeid(b[y])
          if (u == "" || v == "") continue
          printf "%s\t%s\t%s\t%s\n", mstart, mtype, u, v >> edges
          if (bidi) printf "%s\t%s\t%s\t%s\n", mstart, mtype, v, u >> edges
        }
      }
    }
    function ids(l, head,    rest, lead, id) {             # DD-22 — 결정 절 밖 줄 머리의 첫 등장이 정의
      rest = l; lead = l
      gsub(/^[ \t|>*+#-]+|^[ \t]*[0-9]+\.[ \t]*/, "", lead); gsub(/[*`]/, "", lead)
      while (match(rest, "(^|[^A-Za-z0-9_])" idre)) {
        id = substr(rest, RSTART, RLENGTH); sub(/^[^A-Za-z]/, "", id)
        rest = substr(rest, RSTART + RLENGTH)
        if (!indec && index(lead, id) == 1 && !(id in def)) def[id] = NR
        else { ref[id] = ref[id] " " NR; if (indec) decref[id] = 1 }
      }
    }
    BEGIN { ns = split(secs, sl, "\036"); for (i = 1; i <= ns; i++) { split(sl[i], p, US); sname[i] = p[1]; sre[i] = p[2] } }
    NR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    {
      line = $0; skip = ign; ign = 0
      if (index(line, "design-soundness-ignore")) { skip = 1; ign = 1 }
    }
    incom { e = index(line, "-->"); if (!e) next; incom = 0; line = substr(line, e + 3) }
    /^[ \t]*(```|~~~)/ {
      if (!infence) { infence = 1; lang = line; sub(/^[ \t]*(```|~~~)[ \t]*/, "", lang); inm = (tolower(lang) ~ /^mermaid/); mstart = NR; mtype = ""; inmfm = 0 }
      else { infence = 0; inm = 0 }
      next
    }
    infence {
      if (!inm || skip) next
      t = trim(line)
      if (t == "" || t ~ /^%%/) next
      if (mtype == "") {
        if (inmfm) { if (t == "---") inmfm = 0; next }           # 다이어그램 프런트매터
        if (t == "---") { inmfm = 1; next }
        if (t ~ /^stateDiagram/) mtype = "state"; else if (t ~ /^(flowchart|graph)/) mtype = "flow"; else inm = 0
        next
      }
      if (t ~ /^(classDef|class|style|linkStyle|click|note|direction)[ \t]/) next
      edge_line(t)
      next
    }
    {
      while ((cs = index(line, "<!--"))) {                       # 줄 안의 HTML 주석만 지운다
        ce = index(substr(line, cs + 4), "-->")
        if (!ce) { incom = 1; line = substr(line, 1, cs - 1); break }
        line = substr(line, 1, cs - 1) substr(line, cs + 4 + ce + 2)
      }
      if (trim(line) == "") next
    }
    /^[ \t]*>/ { next }
    line ~ /^#{1,6}[ \t]/ {
      h = tolower(line); match(line, /^#+/); lv = RLENGTH; sub(/^#+[ \t]*/, "", h)
      if (lv == 1 && !titled) { titled = 1; if (!skip) body[NR] = line; next }   # 문서 제목은 절이 아니다
      titled = 1; hd[++nh] = h
      g = (h ~ glore); d = (!g && h ~ decre); r = (!g && h ~ reqre)
      for (k = lv; k <= 6; k++) { R[k] = D[k] = G[k] = 0 }      # 하위 제목은 상위 절을 잇는다
      R[lv] = r; D[lv] = d; G[lv] = g
      inreq = indec = inglo = 0
      for (k = 1; k <= 6; k++) { if (R[k]) inreq = 1; if (D[k]) indec = 1; if (G[k]) inglo = 1 }
      if (d && !decstart) decstart = NR; if (g && !glostart) glostart = NR
      if (!skip) { if (!inglo) body[NR] = line; ids(line) }
      next
    }
    skip { next }
    {
      if (!inglo) body[NR] = line
      ids(line)
      # DD-23 측정 기준 없는 품질 요구
      q = line; gsub(idre, "", q)
      if (inreq && tolower(q) ~ qre && q !~ /[0-9]/) printf "DD-23%s%d줄: 측정 기준(숫자 · 단위)이 없는 품질 요구 — %s\n", US, NR, trim(line)
      # DD-24 용어 정의
      if (inglo) {
        term = ""
        if (line ~ /^[ \t]*\|/ && line !~ /^[ \t]*\|[ \t:|-]+$/) { split(line, c, "|"); term = trim(c[2]) }
        else if (match(line, /^[ \t]*[-*][ \t]+\*\*[^*]+\*\*/)) { term = substr(line, RSTART, RLENGTH); sub(/^[ \t]*[-*][ \t]+\*\*/, "", term); sub(/\*\*$/, "", term) }
        gsub(/[*`]/, "", term); term = trim(term)
        if (length(term) >= 2 && tolower(term) !~ /^(용어|term|이름|name|단어|word|뜻|정의|definition)$/ && !(term in tdef)) { tdef[term] = NR; tn++; tl[tn] = term }
      }
    }
    END {
      for (i = 1; i <= ns; i++) { ok = 0; for (j = 1; j <= nh; j++) if (hd[j] ~ sre[i]) { ok = 1; break }; if (!ok) printf "DD-20%s필수 절 없음 — %s\n", US, sname[i] }
      nd = 0; for (id in def) nd++
      if (nd > 0) {
        for (id in ref) if (!(id in def)) printf "DD-22%s정의 없이 참조된 요구 ID — %s (%s줄)\n", US, id, trim(ref[id])
        for (id in def) if (!(id in decref)) printf "DD-22%s결정 절에서 참조되지 않은 요구 — %s (%d줄 정의)\n", US, id, def[id]
      }
      if (glostart && (!decstart || glostart < decstart)) for (k = 1; k <= tn; k++) { t = tl[k]
        for (j = 1; j < tdef[t]; j++) if ((j in body) && index(body[j], t)) { printf "DD-24%s정의(%d줄) 전에 쓴 용어 — %s (%d줄)\n", US, tdef[t], t, j; break }
      }
    }' "$1"
  if [ -s "$edges" ]; then
    jq -nRr --arg US "$US" '
      def reach($s; $E): def step: (. + [.[] as $x | $E[] | select(.[0] == $x) | .[1]]) | unique; $s | until((step | length) == length; step);
      [inputs | split("\t") | {g: .[0], t: .[1], a: .[2], b: .[3]}] | group_by(.g)[]
      | (.[0].g) as $g | (.[0].t) as $t
      | [.[] | [ (if .a == "[*]" then "[*]start" else .a end), (if .b == "[*]" then (if $t == "state" then "[*]end" else "[*]" end) else .b end) ]] as $E
      | ([$E[][]] | unique) as $N
      | ([$E[] | [.[1], .[0]]]) as $R
      | ($N | map(select(test("^\\[\\*\\]") | not))) as $S
      | (if any($N[]; . == "[*]start") then ($S - reach(["[*]start"]; $E)) else [] end) as $unreach
      | (if any($N[]; . == "[*]end") then ($S - reach(["[*]end"]; $R)) else
           ([$N[] as $n | select([$E[] | select(.[0] == $n)] | length == 0) | $n]) as $sinks
           | if ($sinks | length) == 0 then $S else ($S - reach($sinks; $R)) end
         end) as $stuck
      | (if ($unreach | length) > 0 then "DD-21\($US)\($g)줄 mermaid: 시작에서 닿지 않는 단계 — \($unreach | join(", "))" else empty end),
        (if ($stuck | length) > 0 then "DD-21\($US)\($g)줄 mermaid: 끝으로 못 가는 단계(출구 없는 루프) — \($stuck | join(", "))" else empty end)
    ' < "$edges" 2>/dev/null
  fi
  rm -f "$edges"
}

# ---------- 훅 ----------

state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/common-design-soundness-review}"
  mkdir -p "$d" 2>/dev/null || return 1
  echo "$d"
}

state() { # $1=훅 입력 $2=확장자
  local sid d
  sid="$(printf '%s' "$1" | jq -r '.session_id // "nosession"' | tr -cd 'A-Za-z0-9_-')"
  d="$(state_dir)" || return 1
  echo "$d/${sid:-nosession}.$2"
}

clear_state() {
  local x f
  for x in edits request design reviewed pending blocked plan plan.md alerted; do
    f="$(state "$1" "$x")" && rm -f "$f"
  done
  f="$(state "$1" seen)" && rm -rf "$f"
}

gate_on() { [ "${DESIGN_SOUNDNESS_GATE:-1}" != 0 ]; }

is_doc() {
  case "$(printf '%s' "${1##*/}" | tr '[:upper:]' '[:lower:]')" in
    requirements*.txt|constraints*.txt|*-lock.txt|cmakelists.txt|robots.txt) return 1 ;;
    *.md|*.mdx|*.markdown|*.rst|*.txt|*.adoc) return 0 ;;
  esac
  return 1
}

is_design() { # $1=절대 경로 $2=프로젝트 기준 경로
  local rel lc g old
  rel="$2"; lc="$(printf '%s' "/$rel" | tr '[:upper:]' '[:lower:]')"
  case "$lc" in *.md|*.mdx|*.markdown) ;; *) return 1 ;; esac
  if [ -f "$1" ] && head -20 "$1" 2>/dev/null | grep -qF '<!-- design-document -->'; then return 0; fi
  if [ -n "${DESIGN_SOUNDNESS_PATHS:-}" ]; then
    old="$IFS"; IFS=','
    for g in $DESIGN_SOUNDNESS_PATHS; do
      # shellcheck disable=SC2254
      case "$rel" in $g) IFS="$old"; return 0 ;; esac
    done
    IFS="$old"; return 1
  fi
  case "$lc" in
    */adr/*|*/adrs/*|*/decisions/*|*/rfc/*|*/rfcs/*|*/design/*|*/designs/*|*-design.md|*-rfc.md) return 0 ;;
  esac
  return 1
}

nonblank() { grep -c '[^[:space:]]' | tr -d ' '; }

list() { awk -F "$US" '{print "- " $1 ": " $2}'; }

hook_prompt() {
  local p f
  p="$(printf '%s' "$1" | jq -r '.prompt // ""')"
  case "$p" in ''|'<task-notification>'*) exit 0 ;; esac
  clear_state "$1"
  f="$(state "$1" request)" || exit 0
  { printf -- '--- %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"; printf '%s\n' "$p"; } > "$f"
  if printf '%s' "$p" | grep -qiE -- "$(pat .design_request_re)"; then
    f="$(state "$1" design)" && : > "$f"
  fi
  exit 0
}

hook_plan() { # PreToolUse ExitPlanMode — DD-31
  local plan path h bl rv pd pf sig rq
  gate_on && [ "${DESIGN_SOUNDNESS_PLAN_GATE:-1}" != 0 ] || exit 0
  rv="$(state "$1" reviewed)" || exit 0
  [ -e "$rv" ] && exit 0
  pd="$(state "$1" pending)"
  if [ -e "$pd" ]; then   # 백그라운드 검증자가 아직 판정 중 — 같은 계획이어도 막는다
    cat >&2 <<EOF
설계 검토 중 (common-design-soundness-review DD-31): 백그라운드로 띄운 design-soundness-reviewer 가 아직 끝나지 않았다.
완료 알림으로 판정을 받고, 결함 · 빈 곳을 계획에 반영한 뒤 다시 플랜 모드를 나간다.
규칙: $RULES
EOF
    exit 2
  fi
  plan="$(printf '%s' "$1" | jq -r '.tool_input.plan // ""')"
  path="$(printf '%s' "$1" | jq -r '.tool_input.planFilePath // ""')"
  if [ -z "$plan" ] && [ -n "$path" ] && [ -f "$path" ]; then plan="$(cat "$path")"; fi
  [ -n "$plan" ] || exit 0
  h="$(printf '%s' "$plan" | cksum | tr -d ' \t')"
  bl="$(state "$1" plan)"
  if [ -e "$bl" ] && [ "$(cat "$bl")" = "$h" ]; then exit 0; fi
  printf '%s' "$h" > "$bl"
  pf="$(state "$1" plan.md)" && printf '%s\n' "$plan" > "$pf" || pf=""
  { [ -n "$path" ] && [ -f "$path" ]; } || path="$pf"
  sig=""; [ -n "$pf" ] && sig="$(analyze "$pf" plan | list)"   # 해시와 같은 본문으로 본다
  rq="$(state "$1" request)"
  cat >&2 <<EOF
설계 검토 전 (common-design-soundness-review DD-31): 이 계획을 작성 맥락 없는 검증자가 보지 않았다.
계획 파일: $path
요청 기록: $( [ -s "$rq" ] && echo "$rq" || echo "없음 — 대화의 사용자 요청을 원문 그대로 쓴다")
기계 신호:
${sig:-- 없음}
design-soundness-review 스킬로 design-soundness-reviewer 에게 계획 파일 · 요구 출처 · 결론 없는 질문만 넘겨 판정받고, 결함 · 빈 곳을 계획에 반영한 뒤 다시 플랜 모드를 나간다.
같은 계획으로 다시 나가면 막지 않는다.
규칙: $RULES
EOF
  exit 2
}

hook_edit() {
  local f cwd tool rel before after n0 n1 n st rv pd seen key new msg al dsg
  f="$(printf '%s' "$1" | jq -r '.tool_input.file_path // ""')"
  [ -n "$f" ] || exit 0
  cwd="$(printf '%s' "$1" | jq -r '.cwd // ""')"
  tool="$(printf '%s' "$1" | jq -r '.tool_name // ""')"
  rel="$f"; [ -n "$cwd" ] && case "$f" in "$cwd"/*) rel="${f#"$cwd"/}" ;; esac

  if is_design "$f" "$rel"; then
    if gate_on && [ -n "$cwd" ] && case "$f" in "$cwd"/*) true ;; *) false ;; esac; then
      if rv="$(state "$1" reviewed)" && [ -e "$rv" ]; then   # 검토 뒤의 편집은 다시 센다 (DD-12)
        rm -f "$rv"; st="$(state "$1" edits)" && rm -f "$st"
      fi
      before="$(mktemp "${TMPDIR:-/tmp}/design-soundness.XXXXXX")" || exit 0
      after="$(mktemp "${TMPDIR:-/tmp}/design-soundness.XXXXXX")" || { rm -f "$before"; exit 0; }
      if [ "$tool" = Write ]; then
        printf '%s' "$1" | jq -r '.tool_input.content // ""' > "$after"; : > "$before"
      else
        printf '%s' "$1" | jq -r '[.tool_input.old_string // empty, (.tool_input.edits // [] | .[].old_string)] | join("\n")' > "$before"
        printf '%s' "$1" | jq -r '[.tool_input.new_string // empty, (.tool_input.edits // [] | .[].new_string)] | join("\n")' > "$after"
      fi
      n0="$(nonblank < "$before")"; n1="$(nonblank < "$after")"; rm -f "$before" "$after"
      n="$n1"; [ "$n0" -gt "$n" ] && n="$n0"
      if [ "$n" -gt 0 ] && st="$(state "$1" edits)"; then printf '%s%s%s\n' "$n" "$US" "$f" >> "$st"; fi
    fi
    [ -f "$f" ] || exit 0
    dsg="$(analyze "$f" document)"
    [ -n "$dsg" ] || exit 0
    # 같은 파일에서 이미 알린 신호는 다시 알리지 않는다
    seen="$(state "$1" seen)" && mkdir -p "$seen" 2>/dev/null
    key="$(printf '%s' "$f" | cksum | tr -d ' \t')"
    new="$(printf '%s\n' "$dsg" | { if [ -f "$seen/$key" ]; then grep -vxF -f "$seen/$key"; else cat; fi; })"
    printf '%s\n' "$dsg" > "$seen/$key"
    [ -n "$new" ] || exit 0
    msg="설계 신호 (common-design-soundness-review) — ${f##*/}
$(printf '%s\n' "$new" | list)
신호는 후보다. 의도한 미완성이면 그대로 둔다. 판정은 design-soundness-review 스킬이 한다.
규칙: $RULES"
    jq -n --arg c "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
    exit 0
  fi

  # DD-32 설계 요청 뒤 첫 코드 편집
  gate_on || exit 0
  is_doc "$f" && exit 0
  [ -n "$cwd" ] && case "$f" in "$cwd"/*) ;; *) exit 0 ;; esac
  st="$(state "$1" design)" || exit 0
  [ -e "$st" ] || exit 0
  rv="$(state "$1" reviewed)"; al="$(state "$1" alerted)"; pd="$(state "$1" pending)"
  { [ -e "$rv" ] || [ -e "$pd" ] || [ -e "$al" ]; } && exit 0
  : > "$al"
  msg="설계 검토 없이 구현 시작 (common-design-soundness-review DD-32): 이번 요청은 설계를 포함하는데 design-soundness-reviewer 가 돌지 않았다 — ${f##*/}
구현을 이어 가기 전에 design-soundness-review 스킬로 설계안을 검토한다. 설계가 없는 요청이면 무시한다. 다시 알리지 않는다.
규칙: $RULES"
  jq -n --arg c "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  exit 0
}

hook_review() { # PostToolUse Agent — 동기 실행은 끝난 것, 백그라운드 실행은 SubagentStop 까지 검토 중
  local who st
  who="$(printf '%s' "$1" | jq -r '.tool_input.subagent_type // ""')"
  case "$who" in *design-soundness-reviewer*) ;; *) exit 0 ;; esac
  if printf '%s' "$1" | jq -e '(.tool_response | objects | (.isAsync == true or .status == "async_launched")) // false' >/dev/null 2>&1; then
    st="$(state "$1" pending)" && : > "$st"
  else
    st="$(state "$1" reviewed)" && : > "$st"
  fi
  exit 0
}

hook_subagent_stop() {
  local st
  case "$(printf '%s' "$1" | jq -r '.agent_type // ""')" in
    *design-soundness-reviewer*)
      st="$(state "$1" reviewed)" && : > "$st"
      st="$(state "$1" pending)" && rm -f "$st" ;;
  esac
  exit 0
}

hook_stop() { # DD-30
  local ed rv bl rq active total files sig f
  ed="$(state "$1" edits)" || exit 0
  rv="$(state "$1" reviewed)"; bl="$(state "$1" blocked)"; rq="$(state "$1" request)"
  # 백그라운드 검증자를 기다리며 끝내는 응답 — 막지 않고 기록을 남긴다 (완료 알림 뒤 다시 판정)
  { [ ! -e "$rv" ] && [ -e "$(state "$1" pending)" ]; } && exit 0
  active="$(printf '%s' "$1" | jq -r '.stop_hook_active // false')"
  if ! gate_on || { [ "$active" = true ] && [ -e "$bl" ]; } || [ -e "$rv" ] || [ ! -s "$ed" ]; then
    clear_state "$1"; exit 0
  fi
  total="$(awk -F "$US" '{s += $1} END {print s + 0}' "$ed")"
  if [ "$total" -lt "$MIN_LINES" ]; then clear_state "$1"; exit 0; fi
  files="$(awk -F "$US" '!seen[$2]++ {print $2}' "$ed" | head -10)"
  sig=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    sig="$sig$(analyze "$f" document | awk -F "$US" -v n="${f##*/}" '{print "  - " n ": " $1 " " $2}')
"
  done <<EOF
$files
EOF
  : > "$bl"
  jq -n --arg r "완료 보류 (common-design-soundness-review DD-30): 이번 요청에서 고친 설계 문서를 작성 맥락 없는 검증자가 보지 않았다.
고친 설계 문서:
$(printf '%s\n' "$files" | sed 's/^/  - /')
요청 기록: $( [ -s "$rq" ] && echo "$rq" || echo "없음 — 대화의 사용자 요청을 원문 그대로 쓴다")
기계 신호:
$(printf '%s' "$sig" | grep . || echo '  - 없음')
design-soundness-review 스킬로 design-soundness-reviewer 에게 문서 경로 · 요구 출처 · 결론 없는 질문만 넘겨 판정받는다. common-document-slop-review 가 설치돼 있으면 그 리뷰도 같이 돌려 한 번에 끝낸다.
판정할 설계가 없는 편집(오타 · 링크)이면 그 이유를 한 줄로 말하고 끝낸다 — 다음 종료는 막지 않는다.
규칙: $RULES" '{decision: "block", reason: $r}'
  exit 0
}

if [ "${1:-}" = "--hook" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT="$(cat)"
  printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 || exit 0
  case "$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')" in
    UserPromptSubmit) hook_prompt "$INPUT" ;;
    PreToolUse)
      [ "$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')" = ExitPlanMode ] && hook_plan "$INPUT" ;;
    PostToolUse)
      case "$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')" in
        Write|Edit|MultiEdit) hook_edit "$INPUT" ;;
        Agent|Task) hook_review "$INPUT" ;;
      esac ;;
    SubagentStop) hook_subagent_stop "$INPUT" ;;
    Stop) hook_stop "$INPUT" ;;
  esac
  exit 0
fi

# ---------- CLI ----------
command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"
KIND=document; STRICT=0; FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) KIND=plan ;;
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "모르는 인자: $1" ;;
    *) FILES+=("$1") ;;
  esac
  shift
done
[ "${#FILES[@]}" -gt 0 ] || die "설계 파일 경로가 필요하다 (--help)"

N=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || die "파일이 없다: $f"
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    N=$((N+1)); echo "⚠️  $f: ${s%%"$US"*} ${s#*"$US"}"
  done <<EOF
$(analyze "$f" "$KIND")
EOF
done
echo "설계 파일 ${#FILES[@]}개, 신호 ${N}건 — 신호는 후보다. 판정은 design-soundness-review 스킬 · 규칙: $RULES"
[ "$STRICT" = 1 ] && [ "$N" -gt 0 ] && exit 2
exit 0
