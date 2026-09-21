#!/usr/bin/env bash
# 플러그인 파일의 내용 형식을 검증한다 — 스킬·커맨드·에이전트 프런트매터, 본문·참조 크기, README 절 구성.
# 이름(plugin-naming)·위치(marketplace-directory-structure)·버전(plugin-versioning)은 다루지 않는다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write)       → 새 SKILL.md · 커맨드 · 에이전트의 프런트매터 (A-01 ~ A-04, 차단)
#   PostToolUse(Write|Edit) → 그 파일이 속한 플러그인 전체 (알림만)
# CLI 모드 :
#   validate-authoring.sh <플러그인 디렉터리> ...
#   validate-authoring.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/authoring-rules.md"

DESC_MAX=300
SKILL_LINES_MAX=200
REF_LINES_MAX=500
TEMPLATE_ORDER="설치|의존성|포함된 스킬|포함된 에이전트|포함된 훅|주의|변경 이력"

ERRORS=()
WARNINGS=()

die() { echo "validate-authoring: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

err() { ERRORS+=("$1"); }
warn() { WARNINGS+=("$1"); }

# 인자 중 실제로 있는 파일이 하나라도 있는가 (펼쳐지지 않은 글롭은 그대로 남아 -e 가 거짓이 된다)
any_exists() { local f; for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }

# UTF-8 글자 수. 로캘과 무관하게 이어지는 바이트(10xxxxxx)를 빼고 센다.
char_count() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

# 프런트매터를 "키<TAB>값" 줄로 뽑는다. 닫히면 마지막에 __END__ 를 낸다.
# 블록 스칼라(| >)는 한 줄로 이어 붙이고, 감싼 따옴표는 벗긴다.
frontmatter() { # $1=파일
  awk '
    function flush() {
      if (key != "") {
        v = val
        if (v ~ /^".*"$/ || v ~ /^\x27.*\x27$/) v = substr(v, 2, length(v) - 2)
        print key "\t" v
      }
      key = ""; val = ""
    }
    NR == 1 { if ($0 !~ /^---[[:space:]]*$/) { print "__NOFM__"; exit } next }
    /^---[[:space:]]*$/ { flush(); print "__END__"; exit }
    /^[A-Za-z_][A-Za-z0-9_-]*:/ {
      flush()
      i = index($0, ":")
      key = substr($0, 1, i - 1); val = substr($0, i + 1); sub(/^[[:space:]]+/, "", val)
      block = (val ~ /^[|>][-+]?$/); if (block) val = ""
      next
    }
    key != "" && block { line = $0; sub(/^[[:space:]]+/, "", line); val = (val == "" ? line : val " " line); next }
    END { }
  ' "$1"
}
fm_get() { # $1=frontmatter 출력 $2=키
  printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }'
}

# ---- A-01 ~ A-05 ----------------------------------------------------------
# $1=파일 $2=종류(skill|command|agent) $3=기대 이름(없으면 빈 값) $4=라벨
check_component() {
  local file="$1" kind="$2" want="$3" label="$4" fm name desc n
  fm="$(frontmatter "$file")"
  if [ "$(printf '%s\n' "$fm" | head -1)" = "__NOFM__" ] || [ -z "$fm" ]; then
    err "$label: 프런트매터가 없습니다 — 첫 줄이 '---' 여야 합니다 (A-01)"; return
  fi
  printf '%s\n' "$fm" | grep -qx '__END__' || { err "$label: 프런트매터가 '---' 로 닫히지 않았습니다 (A-01)"; return; }

  name="$(fm_get "$fm" name)"
  desc="$(fm_get "$fm" description)"
  case "$kind" in
    skill|agent)
      if [ -z "$name" ]; then
        err "$label: name 이 없습니다 — '$want' 로 쓰세요 (A-02)"
      elif [ "$name" != "$want" ]; then
        err "$label: name 이 '$name' 입니다 — $( [ "$kind" = skill ] && echo 디렉터리명 || echo 파일명 ) '$want' 와 같아야 합니다 (A-02)"
      fi ;;
  esac
  if [ -z "$desc" ]; then
    err "$label: description 이 없습니다 (A-03)"; return
  fi
  if [ "$kind" = skill ]; then
    # "추가할 때 · 고칠 때 · 쓸 때 사용한다" — 동사는 여러 꼴이라 '때 사용한다' 를 본다
    printf '%s' "$desc" | grep -qE '때 (사용|참조)한다' || \
      err "$label: description 에 언제 쓰는가('~할 때 사용한다')가 없습니다 (A-04)"
    n="$(char_count "$desc")"
    [ "$n" -le "$DESC_MAX" ] || \
      warn "$label: description 이 ${n}자입니다 — ${DESC_MAX}자를 넘으면 매 세션 비용이 커집니다. 트리거 동의어부터 줄이세요 (A-05)"
  fi
}

# ---- A-06 ~ A-09 ----------------------------------------------------------
check_skill_body() { # $1=SKILL.md $2=라벨
  local file="$1" label="$2" lines dir link target
  lines="$(wc -l < "$file" | tr -d ' ')"
  [ "$lines" -le "$SKILL_LINES_MAX" ] || \
    warn "$label: ${lines}줄입니다 — ${SKILL_LINES_MAX}줄을 넘으면 템플릿·예시를 references/ 로 나누세요 (A-06)"
  dir="$(dirname "$file")"
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    case "$link" in http://*|https://*|mailto:*|\#*) continue ;; esac
    target="${link%%#*}"
    [ -n "$target" ] || continue
    [ -e "$dir/$target" ] || err "$label: 링크 '$link' 가 가리키는 파일이 없습니다 (A-08)"
  done < <(awk '/^```/ { f = !f; next } !f' "$file" | grep -oE '\]\([^)[:space:]]+\)' | sed -E 's/^\]\(//; s/\)$//')
}

check_no_url() { # $1=파일 $2=라벨
  local hit
  # 프런트매터는 건너뛴다
  hit="$(awk 'NR == 1 && /^---/ { fm = 1; next } fm && /^---/ { fm = 0; next } !fm' "$1" | grep -oE 'https?://[^[:space:])>`"]+' | head -1)"
  [ -z "$hit" ] || err "$2: 외부 URL '$hit' — 오프라인에서도 동작하도록 내용을 직접 넣으세요 (A-09)"
}

# ---- A-20 ~ A-28 : README -------------------------------------------------
section_text() { # $1=README $2=제목 → 그 절의 본문
  awk -v h="$2" '
    /^## / { cur = substr($0, 4); sub(/[[:space:]]+$/, "", cur); on = (cur == h); next }
    /^# / { on = 0 }
    on
  ' "$1"
}
table_first_cells() { # stdin=절 본문 → 표의 첫 칸들 (머리행·구분행 제외)
  awk '
    /^\|/ {
      if ($0 ~ /^\|[[:space:]:|-]+\|[[:space:]]*$/) { sep = 1; next }
      if (!sep) next
      split($0, c, "|"); v = c[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); gsub(/`/, "", v)
      if (v != "") print v
      next
    }
    { sep = 0 }
  '
}

check_readme() { # $1=플러그인 디렉터리 $2=플러그인명 $3=배치(public|internal|"")
  local dir="$1" name="$2" kind="$3" readme="$1/README.md" first headings h pos last prev_pos=0 prev_h=""
  local expected actual x sec events deps d
  [ -r "$readme" ] || return 0   # 없는 것은 구조 규칙(P-01)의 몫

  first="$(grep -m1 -E '^# ' "$readme" | sed -E 's/^# +//; s/[[:space:]]+$//')"
  [ "$first" = "$name" ] || err "$name/README.md: 첫 제목이 '# ${first:-없음}' 입니다 — '# $name' 이어야 합니다 (A-20)"

  headings="$(grep -E '^## ' "$readme" | sed -E 's/^## +//; s/[[:space:]]+$//')"
  has_h() { printf '%s\n' "$headings" | grep -qxF -- "$1"; }

  for h in "설치" "의존성" "변경 이력"; do
    has_h "$h" || err "$name/README.md: '## $h' 절이 없습니다 (A-21)"
  done
  # 스킬이나 커맨드 중 하나라도 있으면. ls 에 글롭을 여럿 주면 하나만 없어도 실패하므로 파일마다 본다.
  if any_exists "$dir"/skills/*/SKILL.md "$dir"/commands/*.md; then
    has_h "포함된 스킬" || err "$name/README.md: 스킬·커맨드가 있는데 '## 포함된 스킬' 절이 없습니다 (A-22)"
  fi
  if ls "$dir"/agents/*.md >/dev/null 2>&1; then
    has_h "포함된 에이전트" || err "$name/README.md: 에이전트가 있는데 '## 포함된 에이전트' 절이 없습니다 (A-22)"
  fi
  if [ -r "$dir/hooks/hooks.json" ]; then
    has_h "포함된 훅" || err "$name/README.md: hooks/hooks.json 이 있는데 '## 포함된 훅' 절이 없습니다 (A-22)"
  fi

  # A-23 순서 — 템플릿 절끼리의 상대 순서, 그리고 변경 이력이 마지막
  IFS='|' read -r -a order <<< "$TEMPLATE_ORDER"
  for h in "${order[@]}"; do
    pos="$(printf '%s\n' "$headings" | grep -nxF -- "$h" | head -1 | cut -d: -f1)"
    [ -n "$pos" ] || continue
    if [ "$pos" -lt "$prev_pos" ]; then
      err "$name/README.md: '## $h' 가 '## $prev_h' 보다 앞에 있습니다 — 템플릿 순서를 지키세요 (A-23)"
    fi
    prev_pos="$pos"; prev_h="$h"
  done
  last="$(printf '%s\n' "$headings" | tail -1)"
  if has_h "변경 이력" && [ "$last" != "변경 이력" ]; then
    err "$name/README.md: '## 변경 이력' 뒤에 '## $last' 가 있습니다 — 변경 이력이 마지막 절입니다 (A-23)"
  fi

  # A-24 스킬 표 ↔ 실제
  if has_h "포함된 스킬"; then
    expected="$( { for x in "$dir"/skills/*/SKILL.md; do [ -r "$x" ] && basename "$(dirname "$x")"; done
                   for x in "$dir"/commands/*.md; do [ -r "$x" ] && echo "/$(basename "$x" .md)"; done; } | sort -u)"
    actual="$(section_text "$readme" "포함된 스킬" | table_first_cells | sort -u)"
    while IFS= read -r x; do [ -n "$x" ] || continue
      printf '%s\n' "$actual" | grep -qxF -- "$x" || err "$name/README.md: '## 포함된 스킬' 표에 '$x' 가 없습니다 (A-24)"
    done <<< "$expected"
    while IFS= read -r x; do [ -n "$x" ] || continue
      printf '%s\n' "$expected" | grep -qxF -- "$x" || err "$name/README.md: '## 포함된 스킬' 표의 '$x' 는 없는 스킬·커맨드입니다 (A-24)"
    done <<< "$actual"
  fi

  # A-25 에이전트 표 ↔ 실제
  if has_h "포함된 에이전트"; then
    expected="$(for x in "$dir"/agents/*.md; do [ -r "$x" ] && basename "$x" .md; done | sort -u)"
    actual="$(section_text "$readme" "포함된 에이전트" | table_first_cells | sort -u)"
    while IFS= read -r x; do [ -n "$x" ] || continue
      printf '%s\n' "$actual" | grep -qxF -- "$x" || err "$name/README.md: '## 포함된 에이전트' 표에 '$x' 가 없습니다 (A-25)"
    done <<< "$expected"
    while IFS= read -r x; do [ -n "$x" ] || continue
      printf '%s\n' "$expected" | grep -qxF -- "$x" || err "$name/README.md: '## 포함된 에이전트' 표의 '$x' 는 없는 에이전트입니다 (A-25)"
    done <<< "$actual"
  fi

  # A-26 훅 절 ↔ hooks.json 이벤트
  if has_h "포함된 훅" && [ -r "$dir/hooks/hooks.json" ]; then
    sec="$(section_text "$readme" "포함된 훅")"
    events="$(jq -r '.hooks // {} | keys[]' "$dir/hooks/hooks.json" 2>/dev/null)"
    while IFS= read -r x; do [ -n "$x" ] || continue
      printf '%s' "$sec" | grep -qF -- "$x" || err "$name/README.md: '## 포함된 훅' 에 이벤트 '$x' 가 없습니다 (A-26)"
    done <<< "$events"
  fi

  # A-27 의존성 절 ↔ dependencies
  if has_h "의존성" && [ -r "$dir/.claude-plugin/plugin.json" ]; then
    sec="$(section_text "$readme" "의존성")"
    deps="$(jq -r '(.dependencies // [])[] | if type == "string" then . else (.name // empty) end' "$dir/.claude-plugin/plugin.json" 2>/dev/null)"
    if [ -z "$deps" ]; then
      printf '%s' "$sec" | grep -qF "없음" || err "$name/README.md: 의존성이 없으면 '## 의존성' 에 '없음' 이라고 씁니다 (A-27)"
    else
      while IFS= read -r d; do [ -n "$d" ] || continue
        printf '%s' "$sec" | grep -qF -- "$d" || err "$name/README.md: '## 의존성' 에 '$d' 가 없습니다 (A-27)"
      done <<< "$deps"
    fi
  fi

  # A-28 public 설치 명령
  if [ "$kind" = public ] && has_h "설치"; then
    section_text "$readme" "설치" | grep -qF -- "$name@" || \
      err "$name/README.md: '## 설치' 에 '$name@…' 설치 명령이 없습니다 (A-28)"
  fi
}

# ---- 플러그인 하나 ---------------------------------------------------------
validate_plugin_dir() { # $1=디렉터리
  local dir="${1%/}" name kind f s
  name="$(basename "$dir")"
  [ -d "$dir" ] || { err "$dir: 디렉터리가 없습니다"; return; }
  case "$(basename "$(dirname "$dir")")" in
    public-plugins) kind=public ;; internal-plugins) kind=internal ;; *) kind="" ;;
  esac

  for f in "$dir"/skills/*/SKILL.md; do
    [ -r "$f" ] || continue
    s="$(basename "$(dirname "$f")")"
    check_component "$f" skill "$s" "$name/skills/$s/SKILL.md"
    check_skill_body "$f" "$name/skills/$s/SKILL.md"
  done
  for f in "$dir"/commands/*.md; do
    [ -r "$f" ] || continue
    check_component "$f" command "" "$name/commands/$(basename "$f")"
  done
  for f in "$dir"/agents/*.md; do
    [ -r "$f" ] || continue
    check_component "$f" agent "$(basename "$f" .md)" "$name/agents/$(basename "$f")"
  done
  while IFS= read -r f; do
    check_no_url "$f" "$name/${f#"$dir"/}"
  done < <(find "$dir/skills" "$dir/references" -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null | sort)
  while IFS= read -r f; do
    local n; n="$(wc -l < "$f" | tr -d ' ')"
    [ "$n" -le "$REF_LINES_MAX" ] || warn "$name/${f#"$dir"/}: ${n}줄입니다 — 파일당 ${REF_LINES_MAX}줄을 넘기지 않습니다 (A-07)"
  done < <(find "$dir/references" -type f 2>/dev/null | sort)

  check_readme "$dir" "$name" "$kind"
}

validate_all() { # $1=루트
  local root="${1%/}" pd d
  while IFS= read -r d; do
    [ -r "$d/.claude-plugin/plugin.json" ] || continue
    validate_plugin_dir "$d"
  done < <(
    find "$root" -mindepth 1 -maxdepth 1 -type d -name '*plugins' -not -path '*/.git*' 2>/dev/null \
      | while IFS= read -r pd; do find "$pd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null; done | sort
  )
}

report() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 작성 규칙 위반 (plugin-authoring)" >&2
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
  body="작성 규칙 알림 (plugin-authoring) — 막지 않았습니다. 이어서 맞추세요."
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
  local path="$1" payload="$2" body tmp kind want label
  [ "$(printf '%s' "$payload" | jq -r '.tool_name // ""')" = "Write" ] || exit 0
  split_plugin_path "$path" || exit 0
  case "$REL_OUT" in
    skills/*/SKILL.md) kind=skill;   want="$(basename "$(dirname "$path")")" ;;
    commands/*.md)     kind=command; want="" ;;
    agents/*.md)       kind=agent;   want="$(basename "$path" .md)" ;;
    *) exit 0 ;;
  esac
  body="$(printf '%s' "$payload" | jq -r '.tool_input.content // ""')"
  tmp="$(mktemp)"; printf '%s\n' "$body" > "$tmp"
  label="$(basename "$PLUGIN_DIR_OUT")/$REL_OUT"
  check_component "$tmp" "$kind" "$want" "$label"
  rm -f "$tmp"
  WARNINGS=()   # 길이 경고는 훅에서 막지 않는다 — 저장 뒤 PostToolUse 가 알린다
  report
}

hook_post() { # $1=경로
  split_plugin_path "$1" || exit 0
  case "$REL_OUT" in
    README.md|skills/*|commands/*.md|agents/*.md|hooks/hooks.json|.claude-plugin/plugin.json|references/*) ;;
    *) exit 0 ;;
  esac
  [ -r "$PLUGIN_DIR_OUT/.claude-plugin/plugin.json" ] || exit 0
  validate_plugin_dir "$PLUGIN_DIR_OUT"
  emit_notices_json
  exit 0
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --all) validate_all "${2:-$PROJECT_DIR}" ;;
      *)     for arg in "$@"; do validate_plugin_dir "$arg"; done ;;
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
    *)           hook_pre "$path" "$payload" ;;
  esac
  exit 0
}

main "$@"
