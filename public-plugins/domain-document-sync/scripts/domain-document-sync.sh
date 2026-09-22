#!/usr/bin/env bash
# domain-document-sync.sh — 3계층 도메인 문서(<루트>/_index.md → <slug>/_meta.md → concept)의 훅 겸 CLI.
#
#   session              SessionStart — 문서 루트가 있으면 카탈로그 위치와 읽기 순서를 알린다
#   snapshot             UserPromptSubmit — 요청 시작 때 도메인별 코드 지문을 저장하고 면제를 비운다
#   stop                 Stop — 이번 요청에서 코드가 바뀐 도메인에 문서 diff 가 없으면 exit 2 (S-01)
#   pre-edit             PreToolUse(Edit|Write|MultiEdit) — 문서 루트를 고칠 때 프로토콜을 주입한다
#   post-edit            PostToolUse(Edit|Write|MultiEdit) — concept 크기 · _meta 등재를 알린다
#   validate [디렉터리]   문서 트리 정합성 (D-01 ~ D-08). 위반이면 exit 2
#   map [디렉터리]        도메인 → code 글롭 → 지금 걸리는 파일 수
#
# 언어 · 프레임워크를 가정하지 않는다. 어떤 코드가 어느 도메인인지는 각 <slug>/_meta.md 프런트매터
# `code:` 글롭이 정한다. 훅 모드는 fail-open — jq · git 이 없거나 문서 루트가 없으면 조용히 통과한다.
# 규칙 원본: references/domain-document-rules.md
set -uo pipefail
# 한글 등 비ASCII 경로를 "\354…" 로 감싸지 않게 한다 — 감싸면 글롭에 안 걸린다
git() { command git -c core.quotePath=false "$@"; }

MODE="${1:-stop}"
ROOT="${DOMAIN_DOCUMENT_ROOT:-docs/domain}"
ROOT="${ROOT%/}"
MAX_LINES="${DOMAIN_DOCUMENT_MAX_LINES:-300}"

# --- 매핑 ------------------------------------------------------------------

# _meta.md 프런트매터의 code: 목록을 한 줄에 하나씩 낸다. 블록 목록 · 인라인 [a, b] · 단일 값을 읽는다.
meta_patterns() {
  awk -v q="'" '
    function emit(s) {
      sub(/[[:space:]]+#.*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      if (s ~ /^".*"$/ || (substr(s, 1, 1) == q && substr(s, length(s), 1) == q)) s = substr(s, 2, length(s) - 2)
      if (s != "") print s
    }
    NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit; fm = 1; next }
    fm && /^---[[:space:]]*$/ { exit }
    fm && /^code:/ {
      inb = 1; v = $0; sub(/^code:[[:space:]]*/, "", v)
      if (v ~ /^\[/) { gsub(/[][]/, "", v); n = split(v, a, ","); for (i = 1; i <= n; i++) emit(a[i]) }
      else if (v != "") emit(v)
      next
    }
    fm && inb && /^[[:space:]]*-/ { v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); emit(v); next }
    fm && inb && /^[^[:space:]#]/ { inb = 0 }
  ' "$1" 2>/dev/null
}

# ERE 메타 문자를 이스케이프한다 (BSD sed 는 [][…] 괄호식을 못 읽는다)
re_escape() { sed -e 's/[.+(){}|^$]/\\&/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g'; }

# 글롭 → ERE. `**/` 는 0개 이상 디렉터리, `**` 는 아무거나, `*` · `?` 는 `/` 를 넘지 않는다.
# 글롭 문자가 없으면 파일 또는 디렉터리 접두사로 본다. 끝이 `/` 면 그 아래 전부.
glob_to_regex() {
  local g="$1" e
  case "$g" in */) g="${g}**" ;; esac
  e="$(printf '%s' "$g" | re_escape)"
  case "$g" in
    *'*'*|*'?'*)
      e="$(printf '%s' "$e" | sed -e 's#\*\*/#@DS@#g' -e 's#\*\*#@DD@#g' -e 's#\*#[^/]*#g' \
        -e 's#?#[^/]#g' -e 's#@DS@#(.*/)?#g' -e 's#@DD@#.*#g')"
      printf '^%s$' "$e" ;;
    *) printf '^%s(/.*)?$' "$e" ;;
  esac
}

# 도메인 slug 목록 — _meta.md 가 있는 <루트>/<slug>/ 만
domain_slugs() {
  local d
  for d in "$ROOT"/*/; do
    [ -f "$d/_meta.md" ] || continue
    d="${d%/}"; printf '%s\n' "${d##*/}"
  done
}

# stdin 파일 목록 중 도메인 $1 의 code 글롭에 걸리는 것 (`!` 글롭은 뺀다, 문서 루트는 코드가 아니다)
domain_code_files() {
  local p inc="" exc="" r
  while IFS= read -r p; do
    case "$p" in
      '!'*) r="$(glob_to_regex "${p#!}")"; exc="${exc}${exc:+|}${r}" ;;
      *) r="$(glob_to_regex "$p")"; inc="${inc}${inc:+|}${r}" ;;
    esac
  done <<EOF
$(meta_patterns "$ROOT/$1/_meta.md")
EOF
  if [ -z "$inc" ]; then cat >/dev/null; return 0; fi
  grep -E "$inc" | grep -Ev "^$(printf '%s' "$ROOT" | re_escape)/" |
    if [ -n "$exc" ]; then grep -Ev "$exc"; else cat; fi
}

# 작업 트리에서 HEAD 와 다른 파일 (tracked 변경 + untracked). 경로는 현재 디렉터리 기준
changed_files() {
  {
    git diff HEAD --name-only --relative 2>/dev/null || git diff --cached --name-only --relative 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | awk 'NF && !seen[$0]++'
}

# 파일 목록의 현재 내용 지문. 비었으면 none. 해시는 한 번에 — 파일마다 git 을 띄우면 수천 개에서 느리다
fingerprint() {
  local f list present
  list="$(sort)"
  [ -z "$list" ] && { echo none; return; }
  present="$(printf '%s\n' "$list" | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)"
  { printf '%s\n--\n%s\n--\n' "$list" "$present"
    [ -n "$present" ] && printf '%s\n' "$present" | git hash-object --stdin-paths 2>/dev/null
  } | shasum | cut -d' ' -f1
}

# --- 훅 공통 -----------------------------------------------------------------

hook_init() {
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT="$(cat 2>/dev/null || true)"
  PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  cd "$PROJ" 2>/dev/null || exit 0
  PROJ_REAL="$(pwd -P)"
  SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null || echo nosession)"
  SAFE="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9_.-' '_')"
  STATE="${TMPDIR:-/tmp}/domain-document-sync-${SAFE}.turn"
  ACK="${TMPDIR:-/tmp}/domain-document-sync-${SAFE}.ack"
}

# 훅 입력의 file_path 를 프로젝트 기준 상대 경로로
input_rel_path() {
  local fp
  fp="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  case "$fp" in
    "$PROJ"/*) fp="${fp#"$PROJ"/}" ;;
    "$PROJ_REAL"/*) fp="${fp#"$PROJ_REAL"/}" ;;
    ./*) fp="${fp#./}" ;;
  esac
  printf '%s' "$fp"
}

add_context() { # $1=이벤트 $2=메시지
  jq -cn --arg e "$1" --arg m "$2" '{ hookSpecificOutput: { hookEventName: $e, additionalContext: $m } }'
}

# --- 모드 --------------------------------------------------------------------

mode_session() {
  hook_init
  # 지난 세션의 상태 파일을 치운다 (7일)
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'domain-document-sync-*' -type f -mtime +7 -delete 2>/dev/null
  [ -f "$ROOT/_index.md" ] || exit 0
  local slugs n
  slugs="$(domain_slugs)"
  n="$(printf '%s\n' "$slugs" | awk 'NF' | wc -l | tr -d ' ')"
  slugs="$(printf '%s\n' "$slugs" | awk 'NF' | head -40 | paste -sd ',' - | sed 's/,/, /g')"
  [ "$n" -gt 40 ] && slugs="$slugs, …"
  add_context SessionStart "domain-document-sync: 이 저장소의 도메인 지식은 $ROOT 에 3계층으로 있다 — 도메인 ${n}개 (${slugs}). 업무 규칙·정책·계산·상태를 묻거나 도메인 코드를 구현·수정·리뷰하기 전에는 domain-document-get 스킬 순서(_index.md → <slug>/_meta.md → 필요한 concept 만)로 읽는다. 도메인 코드를 바꾸면 같은 요청 안에서 그 도메인 문서도 고친다 (S-01, domain-document-update)."
  exit 0
}

mode_snapshot() {
  hook_init
  rm -f "$ACK" 2>/dev/null
  [ -d "$ROOT" ] || exit 0
  git rev-parse --git-dir >/dev/null 2>&1 || exit 0
  local changed slug
  changed="$(changed_files)"
  domain_slugs | while IFS= read -r slug; do
    printf '%s %s\n' "$slug" "$(printf '%s\n' "$changed" | domain_code_files "$slug" | fingerprint)"
  done > "$STATE" 2>/dev/null
  exit 0
}

mode_stop() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "경고(domain-document-sync): jq 가 없어 문서 동기 게이트를 건너뜁니다." >&2
    exit 0
  fi
  hook_init
  [ -d "$ROOT" ] || exit 0
  git rev-parse --git-dir >/dev/null 2>&1 || exit 0
  local active changed slug code now prev acks viol=""
  active="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
  changed="$(changed_files)"
  [ -z "$changed" ] && exit 0
  acks="$(cat "$ACK" 2>/dev/null || true)"

  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    code="$(printf '%s\n' "$changed" | domain_code_files "$slug")"
    [ -z "$code" ] && continue
    # 이번 요청에서 이 도메인 코드가 바뀌지 않았으면 보지 않는다 — 질문 · 조회 응답은 막지 않는다
    now="$(printf '%s\n' "$code" | fingerprint)"
    prev="$(awk -v s="$slug" '$1 == s { print $2 }' "$STATE" 2>/dev/null)"
    [ -n "$prev" ] && [ "$prev" = "$now" ] && continue
    printf '%s\n' "$changed" | grep -q "^$ROOT/$slug/" && continue
    printf '%s\n' "$acks" | grep -Eq "^n/a([[:space:]]+${slug})?[[:space:]]*$" && continue
    viol="${viol}${viol:+
}${slug}: $(printf '%s' "$code" | head -5 | tr '\n' ' ')$([ "$(printf '%s\n' "$code" | wc -l)" -gt 5 ] && printf '…')"
  done <<EOF
$(domain_slugs)
EOF

  [ -z "$viol" ] && exit 0

  if [ "$active" = "true" ]; then
    jq -cn --arg m "domain-document-sync: 도메인 문서 동기가 안 된 채 작업이 끝났습니다 (한 번 되돌린 뒤 허용). 확인할 도메인:
$(printf '%s\n' "$viol" | sed 's/^/  - /')" '{ systemMessage: $m }'
    exit 0
  fi

  {
    echo "완료 보류(domain-document-sync S-01): 이번 요청에서 코드가 바뀐 도메인에 $ROOT 문서 변경이 없습니다."
    printf '%s\n' "$viol" | sed 's/^/  - /'
    echo "조치 (도메인마다 하나):"
    echo "  1) domain-document-update 스킬대로 $ROOT/<slug>/ concept 를 고친다 (파트·트리거가 바뀌었으면 _meta · _index 도)"
    echo "  2) 도메인 지식이 그대로인 변경(내부 리팩터 · 오타 · 테스트)이면 사용자에게 알린 뒤 면제한다:"
    echo "     echo 'n/a <slug>' >> \"$ACK\"    # 모든 도메인이면 'n/a'"
  } >&2
  exit 2
}

mode_pre_edit() {
  hook_init
  local fp rest slug note=""
  fp="$(input_rel_path)"
  case "$fp" in "$ROOT"/*) ;; *) exit 0 ;; esac
  rest="${fp#"$ROOT"/}"
  case "$rest" in
    _index.md) note="카탈로그 편집 — 도메인당 1행, 트리거는 말·식별자·경로·증상 네 갈래. 겹치는 키워드는 '겹칠 때' 표로." ;;
    */_meta.md) note="도메인 메타 편집 — 파트 표(파일 · 언제 본다)와 프런트매터 code: 글롭을 실제 파일·코드와 맞춘다. 한 줄·트리거가 바뀌면 _index.md 도." ;;
    */*.md)
      slug="${rest%%/*}"
      if [ -f "$ROOT/$slug/_meta.md" ]; then
        note="concept 편집 — 끝나면 파트 구성·트리거가 바뀐 경우만 $slug/_meta.md, 도메인 한 줄·키워드가 바뀐 경우만 _index.md 를 고친다."
      else
        note="새 도메인 '$slug' — $slug/_meta.md(파트 표 · code: 글롭)와 _index.md 카탈로그 1행을 같이 만든다 (D-02 · D-04)."
      fi ;;
    *) note="문서 루트 편집." ;;
  esac
  add_context PreToolUse "domain-document-sync: $ROOT 는 3계층이다 (_index.md → <slug>/_meta.md → concept). $note 상호 참조는 상대 경로. 절차는 domain-document-create · domain-document-update 스킬."
  exit 0
}

mode_post_edit() {
  hook_init
  local fp rest slug base lines msg=""
  fp="$(input_rel_path)"
  case "$fp" in "$ROOT"/*/*.md) ;; *) exit 0 ;; esac
  rest="${fp#"$ROOT"/}"; slug="${rest%%/*}"; base="${rest#*/}"
  case "$base" in _*|*/*) exit 0 ;; esac
  [ -f "$fp" ] || exit 0
  lines="$(wc -l < "$fp" | tr -d ' ')"
  if [ "${lines:-0}" -gt "$MAX_LINES" ]; then
    msg="D-07: $fp ${lines}줄 (> ${MAX_LINES}). 도메인 문서는 작업마다 읽히니 '언제 보는가' 기준 파트로 나누고 $slug/_meta.md 표에 등재한다 (내용 무손실, 상대 링크 유지)."
  fi
  if [ -f "$ROOT/$slug/_meta.md" ] && ! grep -Eq "\]\((\./)?$(printf '%s' "$base" | re_escape)(#[^)]*)?\)" "$ROOT/$slug/_meta.md"; then
    msg="${msg}${msg:+ }D-05: $base 가 $slug/_meta.md 파트 표에 없다 — '언제 본다' 와 함께 등재한다."
  fi
  [ -z "$msg" ] && exit 0
  add_context PostToolUse "domain-document-sync: $msg"
  exit 0
}

# 코드 블록을 뺀 본문의 상대 링크 — "파일<TAB>링크"
doc_links() {
  awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$1" |
    grep -oE '\]\([^)[:space:]]+\)' | sed -e 's/^](//' -e 's/)$//' |
    grep -vE '^(https?:|mailto:|#)' | grep -v '[{}]' | sed 's/#.*$//' | awk 'NF'
}

mode_validate() {
  local dir="${1:-.}" err=0 warn=0 n=0 slug d f base link target lines pat hits all
  cd "$dir" 2>/dev/null || { echo "❌ 디렉터리 없음: $dir" >&2; exit 2; }
  e() { printf '❌ %s\n' "$1"; err=$((err + 1)); }
  w() { printf '⚠️  %s\n' "$1"; warn=$((warn + 1)); }

  if [ ! -d "$ROOT" ]; then e "D-01 문서 루트 $ROOT 가 없다 — domain-document-create 로 만든다"; echo "❌ domain-document-validate: 위반 1건"; exit 2; fi
  [ -f "$ROOT/_index.md" ] || e "D-01 $ROOT/_index.md 카탈로그가 없다"

  all=""
  git rev-parse --git-dir >/dev/null 2>&1 && all="$({ git ls-files; git ls-files --others --exclude-standard; } 2>/dev/null)"

  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"; slug="${d##*/}"; n=$((n + 1))
    printf '%s' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || e "D-03 $d: slug 는 kebab-case"
    if [ ! -f "$d/_meta.md" ]; then e "D-02 $d: _meta.md 가 없다"; continue; fi
    if [ -f "$ROOT/_index.md" ] && ! grep -Eq "\]\((\./)?$slug/(_meta\.md)?\)" "$ROOT/_index.md"; then
      e "D-04 $slug: _index.md 카탈로그에 [$slug/]($slug/_meta.md) 행이 없다"
    fi
    for f in "$d"/*.md; do
      [ -f "$f" ] || continue
      base="${f##*/}"
      case "$base" in _*) continue ;; esac
      grep -Eq "\]\((\./)?$(printf '%s' "$base" | re_escape)(#[^)]*)?\)" "$d/_meta.md" ||
        e "D-05 $f: $slug/_meta.md 파트 표에 없다"
      lines="$(wc -l < "$f" | tr -d ' ')"
      [ "$lines" -gt "$MAX_LINES" ] && w "D-07 $f: ${lines}줄 (> ${MAX_LINES}) — 파트로 나눈다"
    done
    if [ -n "$all" ]; then
      while IFS= read -r pat; do
        [ -z "$pat" ] && continue
        case "$pat" in '!'*) continue ;; esac
        hits="$(printf '%s\n' "$all" | grep -Ec "$(glob_to_regex "$pat")")"
        [ "$hits" = 0 ] && w "D-08 $slug: code 글롭 '$pat' 에 걸리는 파일이 없다 — 코드가 옮겨졌으면 고친다"
      done <<EOF
$(meta_patterns "$d/_meta.md")
EOF
    fi
  done

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      target="$(dirname "$f")/$link"
      [ -e "$target" ] || e "D-06 $f: 링크 대상 없음 → $link"
    done <<EOF
$(doc_links "$f")
EOF
  done <<EOF
$(find "$ROOT" -name '*.md' -type f 2>/dev/null | sort)
EOF

  if [ "$err" -gt 0 ]; then echo "❌ domain-document-validate: 도메인 ${n}개, 위반 ${err}건, 경고 ${warn}건"; exit 2; fi
  echo "✅ domain-document-validate: 도메인 ${n}개, 위반 없음, 경고 ${warn}건"
  exit 0
}

mode_map() {
  local dir="${1:-.}" slug pat all hits
  cd "$dir" 2>/dev/null || { echo "❌ 디렉터리 없음: $dir" >&2; exit 2; }
  [ -d "$ROOT" ] || { echo "문서 루트 $ROOT 가 없다"; exit 0; }
  all="$({ git ls-files; git ls-files --others --exclude-standard; } 2>/dev/null)"
  domain_slugs | while IFS= read -r slug; do
    printf '%s\n' "$slug"
    pat="$(meta_patterns "$ROOT/$slug/_meta.md")"
    if [ -z "$pat" ]; then echo "  (code 없음 — 동기 게이트 대상 아님)"; continue; fi
    printf '%s\n' "$pat" | while IFS= read -r p; do printf '  %s\n' "$p"; done
    hits="$(printf '%s\n' "$all" | domain_code_files "$slug" | awk 'NF' | wc -l | tr -d ' ')"
    printf '  → 파일 %s개\n' "$hits"
  done
}

case "$MODE" in
  session) mode_session ;;
  snapshot) mode_snapshot ;;
  stop) mode_stop ;;
  pre-edit) mode_pre_edit ;;
  post-edit) mode_post_edit ;;
  validate) shift; mode_validate "$@" ;;
  map) shift; mode_map "$@" ;;
  *) echo "사용: $0 {session|snapshot|stop|pre-edit|post-edit|validate [디렉터리]|map [디렉터리]}" >&2; exit 1 ;;
esac
