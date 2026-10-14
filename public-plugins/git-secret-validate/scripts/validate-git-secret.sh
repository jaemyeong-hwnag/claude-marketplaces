#!/usr/bin/env bash
# 커밋 · 푸시되거나 파일에 쓰이는 시크릿과, ignore 되지 않은 민감 파일을 찾는다.
# 탐지는 gitleaks 가 하고, 이 스크립트는 언제 · 무엇을 볼지와 ignore 판정만 맡는다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Bash)       → git commit · git push 에 실릴 변경에서 시크릿(GS-01) · 민감 파일(GS-02)을 찾으면 차단
#   PreToolUse(Write|Edit) → 새로 생긴 시크릿(GS-03) · 민감 파일(GS-04)이 ignore 되지 않았으면 경고
# CLI 모드 :
#   validate-git-secret.sh <파일|디렉터리> ...
#   validate-git-secret.sh --all [루트]       작업 트리 (추적 파일 + ignore 안 된 새 파일)
#   validate-git-secret.sh --history [루트]   모든 커밋 이력
#
# 엔진(GS-05): gitleaks 가 있으면 gitleaks, 없으면 내장 패턴. GIT_SECRET_ENGINE=gitleaks|builtin 으로 고정한다.
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
RULES="$PLUGIN_ROOT/references/secret-rules.md"
RULES_JSON="$PLUGIN_ROOT/references/secret-rules.json"
LABEL="git-secret-validate"
ALLOW_FILE=".git-secret-allow"
MAX_BYTES=1048576

die() { echo "validate-git-secret: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"
command -v git >/dev/null 2>&1 || die "git 이 필요합니다"
[ -f "$RULES_JSON" ] || die "규칙 파일이 없습니다: $RULES_JSON"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/git-secret.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 엔진 -------------------------------------------------------------------
ENGINE="${GIT_SECRET_ENGINE:-}"
if [ -z "$ENGINE" ]; then
  if command -v gitleaks >/dev/null 2>&1; then ENGINE=gitleaks; else ENGINE=builtin; fi
fi
case "$ENGINE" in
  gitleaks) command -v gitleaks >/dev/null 2>&1 || die "GIT_SECRET_ENGINE=gitleaks 인데 gitleaks 가 없습니다" ;;
  builtin) ;;
  *) die "GIT_SECRET_ENGINE 은 gitleaks 또는 builtin 입니다: $ENGINE" ;;
esac

# 앞 4글자만 남긴다
redact() { local s="$1"; if [ "${#s}" -gt 4 ]; then printf '%s…' "${s:0:4}"; else printf '…'; fi; }

# $1=디렉터리 $2=저장소 루트(설정 파일을 찾는다, 없으면 빈 값) → "상대 경로 \037 규칙 \037 가린 값" 줄들
scan_dir() {
  local dir="${1%/}" repo="${2:-}"
  [ -n "$(ls -A "$dir" 2>/dev/null)" ] || return 0
  if [ "$ENGINE" = gitleaks ]; then
    local cfg=()
    [ -n "$repo" ] && [ -f "$repo/.gitleaks.toml" ] && cfg=(-c "$repo/.gitleaks.toml")
    # 디렉터리 안에서 . 을 넘겨야 File 이 상대 경로로 나온다 (TMPDIR 의 // · 심볼릭 링크와 무관하게)
    ( cd "$dir" && gitleaks dir . ${cfg+"${cfg[@]}"} --no-banner --report-format json \
      --report-path "$TMP/gitleaks.json" --exit-code 0 -l error >/dev/null 2>&1 ) || die "gitleaks 실행에 실패했습니다"
    # 값은 직접 앞 4글자로 가린다 — 내장 엔진과 같은 모양이어야 편집 전후를 비교할 수 있다
    jq -r '.[] | [(.File | ltrimstr("./")), .RuleID, (.Secret // .Match)] | join("\u001f")' "$TMP/gitleaks.json" 2>/dev/null \
      | while IFS=$'\037' read -r f r s; do printf '%s\037%s\037%s\n' "$f" "$r" "$(redact "$s")"; done
    return 0
  fi
  local placeholder id flags re hit file rest line m
  placeholder="$(jq -r '.placeholder // ""' "$RULES_JSON")"
  while IFS=$'\037' read -r id flags re; do
    # grep -rnIE 의 줄 → 파일:줄번호:내용. 오탐 탈출구는 gitleaks 와 같은 gitleaks:allow
    grep -rnIE${flags:+i} -- "$re" "$dir" 2>/dev/null | grep -v 'gitleaks:allow' | while IFS= read -r hit; do
      file="${hit%%:*}"; rest="${hit#*:}"; line="${rest#*:}"
      m="$(printf '%s\n' "$line" | grep -oE${flags:+i} -m1 -- "$re" | head -1)"
      [ -n "$m" ] || continue
      if [ -n "$placeholder" ] && printf '%s' "$m" | grep -qiE -- "$placeholder"; then continue; fi
      printf '%s\037%s\037%s\n' "${file#"$dir"/}" "$id" "$(redact "$m")"
    done
  done < <(jq -r '.patterns[] | [.id, (.flags // ""), .regex] | join("\u001f")' "$RULES_JSON")
}

# ---- 민감 파일 · 예외 ---------------------------------------------------------
DENY=(); ALLOW=()
while IFS= read -r g; do DENY+=("$g"); done < <(jq -r '.sensitive_files.deny[]' "$RULES_JSON")
while IFS= read -r g; do ALLOW+=("$g"); done < <(jq -r '.sensitive_files.allow[]' "$RULES_JSON")

# 글롭이 / 를 가지면 경로 전체, 아니면 파일 이름과 맞춘다
glob_match() { # $1=상대 경로 $2=글롭
  local base="${1##*/}"
  case "$2" in
    */*) [[ "$1" == $2 ]] ;;
    *) [[ "$base" == $2 ]] ;;
  esac
}
is_sensitive() { # $1=상대 경로
  local g hit=1
  for g in "${DENY[@]}"; do glob_match "$1" "$g" && { hit=0; break; }; done
  [ "$hit" = 0 ] || return 1
  for g in "${ALLOW[@]}"; do glob_match "$1" "$g" && return 1; done
  return 0
}
# 저장소의 .git-secret-allow — 사용자가 일부러 둔 파일(테스트용 키 등)
is_allowed() { # $1=저장소 $2=상대 경로
  local g
  [ -f "$1/$ALLOW_FILE" ] || return 1
  while IFS= read -r g || [ -n "$g" ]; do
    g="${g%%#*}"; g="${g%"${g##*[![:space:]]}"}"; g="${g#"${g%%[![:space:]]*}"}"
    [ -n "$g" ] || continue
    glob_match "$2" "$g" && return 0
    [[ "$2" == $g/* ]] && return 0
  done < "$1/$ALLOW_FILE"
  return 1
}
# 경로를 따옴표 없이 · a/ b/ 접두사로 받는다 — 사용자 설정(core.quotepath · diff.noprefix)에 따라 패치 모양이 바뀌지 않게
g() { git -c core.quotepath=false -c diff.noprefix=false -c diff.mnemonicprefix=false "$@"; }
is_ignored() { git -C "$1" check-ignore -q --no-index -- "$2" 2>/dev/null; }
is_tracked() { git -C "$1" ls-files --error-unmatch -- "$2" >/dev/null 2>&1; }

# ---- 내용 모으기 ---------------------------------------------------------------
# 패치(stdin)의 추가된 줄만 파일별로 $1 아래에 모은다. 지운 파일 · 바이너리는 건너뛴다
patch_to_dir() { # $1=출력 디렉터리
  awk -v out="$1" '
    function q(s) { gsub(/\047/, "\047\\\047\047", s); return "\047" s "\047" }
    /^diff --git / { cur = ""; next }
    /^\+\+\+ / {
      p = substr($0, 5); cur = ""
      if (p == "/dev/null") next
      sub(/^b\//, "", p); sub(/\t$/, "", p)
      if (p ~ /^\// || p ~ /(^|\/)\.\.(\/|$)/) next
      cur = out "/" p
      if (!(cur in made)) { d = cur; sub(/\/[^\/]*$/, "", d); system("mkdir -p " q(d)); made[cur] = 1; printf "" > cur }
      next
    }
    /^\+/ && cur != "" { print substr($0, 2) >> cur }
  '
}
# 작업 트리 파일 하나를 통째로 넣는다. 바이너리 · 큰 파일은 건너뛴다
copy_file() { # $1=저장소(또는 기준 디렉터리) $2=상대 경로 $3=출력 디렉터리
  local src="$1/$2" size
  [ -f "$src" ] || return 0
  size="$(wc -c < "$src" 2>/dev/null | tr -d ' ')"
  [ "${size:-0}" -gt 0 ] && [ "$size" -le "$MAX_BYTES" ] || return 0
  grep -Iq . "$src" 2>/dev/null || return 0
  mkdir -p "$3/$(dirname "$2")" && cat "$src" >> "$3/$2"
}

# $1=저장소 $2=탐지 결과 파일 $3=조항 — 예외를 빼고 ERRORS 에 넣는다
collect_findings() {
  local f r s
  while IFS=$'\037' read -r f r s; do
    [ -n "$f" ] || continue
    is_allowed "$1" "$f" && continue
    ERRORS+=("[$3] $f — $r: $s")
  done < "$2"
}
# $1=저장소 $2=경로 목록 파일 — 민감 파일이면 GS-02
collect_sensitive() {
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    is_sensitive "$p" || continue
    is_allowed "$1" "$p" && continue
    ERRORS+=("[GS-02] $p — 민감 파일이 커밋에 들어간다")
  done < <(sort -u "$2")
}

engine_note() {
  [ "$ENGINE" = builtin ] && echo "  ℹ️ gitleaks 가 없어 내장 패턴으로 봤다 (GS-05). 설치하면 더 많이 잡는다: brew install gitleaks" >&2
  return 0
}

# ---- 훅: Bash ------------------------------------------------------------------
# 명령에서 git 하위 명령이 있는지 — git -C dir · git -c k=v 같은 전역 옵션을 건너뛴다
has_git_sub() { # $1=명령 $2=하위 명령
  printf '%s' "$1" | grep -qE "(^|[;&|(\`[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+$2([[:space:]]|\$|[;&|)])"
}
# 하위 명령 뒤 인자 — 다음 셸 구분자까지
git_sub_args() { # $1=명령 $2=하위 명령
  printf '%s' "$1" | tr '\n' ' ' | sed -nE "s/.*git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+$2([[:space:]]+([^;&|]*))?.*/\\3/p" | head -1
}
# 명령이 작업할 디렉터리 — 앞쪽 cd X && 와 git -C X 를 따른다
command_dir() { # $1=명령 $2=훅 cwd
  local d="$2" c x
  c="$(printf '%s' "$1" | sed -nE 's/^[[:space:]]*cd[[:space:]]+("([^"]+)"|'"'"'([^'"'"']+)'"'"'|([^[:space:];&|]+)).*/\2\3\4/p' | head -1)"
  if [ -n "$c" ]; then case "$c" in /*) d="$c" ;; "~"*) d="$HOME${c#\~}" ;; *) d="$d/$c" ;; esac; fi
  x="$(printf '%s' "$1" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|([^[:space:]]+)).*/\2\3/p' | head -1)"
  if [ -n "$x" ]; then case "$x" in /*) d="$x" ;; *) d="$d/$x" ;; esac; fi
  printf '%s' "$d"
}

hook_commit() { # $1=저장소 $2=명령
  local repo="$1" cmd="$2" scan="$TMP/commit" paths="$TMP/commit-paths" add_args commit_args worktree=0 has_head=1 tok
  mkdir -p "$scan"; : > "$paths"
  g -C "$repo" rev-parse -q --verify HEAD >/dev/null 2>&1 || has_head=0
  commit_args="$(git_sub_args "$cmd" commit)"
  # git add 가 같은 명령에 있으면 아직 스테이징 전이다 — 바뀐 파일 전체를 본다
  if has_git_sub "$cmd" add; then worktree=1; fi
  if printf ' %s ' "$commit_args" | grep -qE '[[:space:]](-[A-Za-z]*a[A-Za-z]*|--all)[[:space:]]'; then worktree=1; fi

  {
    g -C "$repo" diff --cached -U0 --no-color --no-ext-diff 2>/dev/null
    if [ "$worktree" = 1 ]; then
      if [ "$has_head" = 1 ]; then g -C "$repo" diff HEAD -U0 --no-color --no-ext-diff 2>/dev/null
      else g -C "$repo" diff -U0 --no-color --no-ext-diff 2>/dev/null; fi
    fi
  } | patch_to_dir "$scan"
  g -C "$repo" diff --cached --name-only --diff-filter=ACMR 2>/dev/null >> "$paths"

  if [ "$worktree" = 1 ]; then
    g -C "$repo" diff --name-only --diff-filter=ACMR 2>/dev/null >> "$paths"
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      echo "$tok" >> "$paths"; copy_file "$repo" "$tok" "$scan"
    done < <(g -C "$repo" ls-files -o --exclude-standard 2>/dev/null)
    # git add -f 는 ignore 된 파일도 넣는다 — 이름을 적은 파일을 따로 본다
    add_args="$(git_sub_args "$cmd" add)"
    if printf ' %s ' "$add_args" | grep -qE '[[:space:]](-[A-Za-z]*f[A-Za-z]*|--force)[[:space:]]'; then
      for tok in $add_args; do
        case "$tok" in -*) continue ;; esac
        tok="${tok%\"}"; tok="${tok#\"}"; tok="${tok%\'}"; tok="${tok#\'}"
        while IFS= read -r p; do
          [ -n "$p" ] || continue
          echo "$p" >> "$paths"; copy_file "$repo" "$p" "$scan"
        done < <(g -C "$CMD_DIR" ls-files --full-name -co -- "$tok" 2>/dev/null)
      done
    fi
  fi

  scan_dir "$scan" "$repo" | sort -u > "$TMP/found"
  collect_findings "$repo" "$TMP/found" GS-01
  collect_sensitive "$repo" "$paths"
}

hook_push() { # $1=저장소
  local repo="$1" scan="$TMP/push"
  mkdir -p "$scan"
  g -C "$repo" rev-parse -q --verify HEAD >/dev/null 2>&1 || return 0
  # 아직 어떤 원격에도 없는 커밋
  [ "$(g -C "$repo" rev-list --count HEAD --not --remotes 2>/dev/null || echo 0)" -gt 0 ] || return 0
  g -C "$repo" log -p -U0 --no-color --no-ext-diff --format= HEAD --not --remotes 2>/dev/null | patch_to_dir "$scan"
  g -C "$repo" log --name-only --diff-filter=ACMR --format= HEAD --not --remotes 2>/dev/null > "$TMP/push-paths"
  scan_dir "$scan" "$repo" | sort -u > "$TMP/found"
  collect_findings "$repo" "$TMP/found" GS-01
  collect_sensitive "$repo" "$TMP/push-paths"
}

hook_bash() { # $1=payload
  local cmd cwd repo what=""
  cmd="$(printf '%s' "$1" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  [ -n "$cmd" ] || exit 0
  has_git_sub "$cmd" commit && what="commit"
  has_git_sub "$cmd" push && what="$what push"
  [ -n "$what" ] || exit 0
  cwd="$(printf '%s' "$1" | jq -r '.cwd // ""' 2>/dev/null)"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  CMD_DIR="$(command_dir "$cmd" "$cwd")"
  repo="$(g -C "$CMD_DIR" rev-parse --show-toplevel 2>/dev/null)" || exit 0
  case "$what" in *commit*) hook_commit "$repo" "$cmd" ;; esac
  case "$what" in *push*) hook_push "$repo" ;; esac

  if [ "${#ERRORS[@]}" -gt 0 ]; then
    local e
    echo "❌ 시크릿이 저장소에 들어간다 ($LABEL) —${what}" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    engine_note
    echo "시크릿은 코드에서 빼고 환경 변수나 ignore 된 파일로 옮겨라. 민감 파일은 git rm --cached 로 빼고 .gitignore 에 넣어라." >&2
    echo "이미 커밋 · 푸시된 키는 폐기해야 한다 — secret-review 스킬을 따른다. 오탐 처리(gitleaks:allow · $ALLOW_FILE)는 사용자에게 확인받고 한다. 규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

# ---- 훅: Write · Edit ------------------------------------------------------------
# 편집 뒤 내용을 만든다. Write 는 content, Edit 는 현재 파일에 치환을 적용한다.
# jq 의 index 는 버전에 따라 바이트 · 글자 기준이 갈리므로 split 으로 첫 번째만 바꾼다.
after_content() { # $1=payload $2=현재 파일(없으면 빈 파일)
  printf '%s' "$1" | jq -j --rawfile cur "$2" '
    def rep($s; $o; $n; $all):
      if $o == "" then $s
      elif $all then ($s | split($o) | join($n))
      else ($s | split($o)) as $p | if ($p | length) < 2 then $s else $p[0] + $n + ($p[1:] | join($o)) end
      end;
    .tool_input as $t
    | if ($t.content | type) == "string" then $t.content
      elif ($t.edits | type) == "array" then reduce $t.edits[] as $e ($cur; rep(.; $e.old_string // ""; $e.new_string // ""; $e.replace_all // false))
      else rep($cur; $t.old_string // ""; $t.new_string // ""; $t.replace_all // false)
      end'
}

# 아직 없는 경로도 실제 경로로 — 있는 조상까지 올라가 pwd -P 하고 나머지를 붙인다 (macOS /tmp → /private/tmp)
physical_path() { # $1=절대 경로
  local d="$1" rest=""
  while [ ! -d "$d" ]; do rest="/${d##*/}$rest"; d="${d%/*}"; [ -n "$d" ] || d="/"; done
  printf '%s%s' "$(cd "$d" && pwd -P)" "$rest"
}

hook_file() { # $1=payload
  local path abs repo rel before after
  path="$(printf '%s' "$1" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
  [ -n "$path" ] || exit 0
  case "$path" in /*) ;; *) path="${CLAUDE_PROJECT_DIR:-$(pwd)}/$path" ;; esac
  abs="$(physical_path "$path")"
  local d="${abs%/*}"
  while [ ! -d "$d" ]; do d="${d%/*}"; [ -n "$d" ] || d="/"; done
  repo="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || exit 0
  repo="$(cd "$repo" && pwd -P)"
  rel="${abs#"$repo"/}"
  [ "$rel" != "$abs" ] || exit 0
  case "/$rel" in */.git/*) exit 0 ;; esac
  is_allowed "$repo" "$rel" && exit 0

  local exposed=1 why="ignore 되지 않았다"
  if is_tracked "$repo" "$rel"; then why="이미 git 이 추적하는 파일이다"
  elif is_ignored "$repo" "$rel"; then exposed=0; fi
  [ "$exposed" = 1 ] || exit 0

  # GS-04 민감 파일
  if is_sensitive "$rel"; then
    WARNINGS+=("[GS-04] $rel — 민감 파일인데 $why. 커밋되기 전에 .gitignore 에 넣어라")
  fi

  # GS-03 새로 생긴 시크릿 — 편집 전과 뒤를 같은 경로로 두고 (규칙 · 가린 값) 개수로 비교한다
  before="$TMP/before"; after="$TMP/after"
  mkdir -p "$before/$(dirname "$rel")" "$after/$(dirname "$rel")"
  : > "$before/$rel"
  [ -f "$abs" ] && cat "$abs" > "$before/$rel"
  after_content "$1" "$before/$rel" > "$after/$rel" || exit 0
  scan_dir "$before" "$repo" | cut -d$'\037' -f2,3 > "$TMP/scan-before"
  scan_dir "$after" "$repo" | cut -d$'\037' -f2,3 > "$TMP/scan-after"
  local r s
  while IFS=$'\037' read -r r s; do
    [ -n "$r" ] || continue
    WARNINGS+=("[GS-03] $rel — $r: $s 를 쓴다. 파일이 $why — 커밋되면 노출된다")
  done < <(awk 'FILENAME == ARGV[1] { seen[$0]++; next } seen[$0]-- > 0 { next } { print }' "$TMP/scan-before" "$TMP/scan-after")

  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    local w body
    body="시크릿 경고 ($LABEL) — 막지 않았다. 시크릿은 환경 변수나 ignore 된 파일(.env 등)로 옮기고, 민감 파일은 .gitignore 에 넣어라."
    for w in "${WARNINGS[@]}"; do body="$body"$'\n'"- $w"; done
    [ "$ENGINE" = builtin ] && body="$body"$'\n'"(gitleaks 가 없어 내장 패턴으로 봤다 — GS-05)"
    body="$body"$'\n'"규칙: $RULES"
    jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  fi
  exit 0
}

hook() {
  local payload event tool
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null)"
  [ "$event" = PreToolUse ] || exit 0
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)"
  case "$tool" in
    Bash) hook_bash "$payload" ;;
    Write|Edit|MultiEdit) hook_file "$payload" ;;
  esac
  exit 0
}

# ---- CLI --------------------------------------------------------------------
report() { # $1=검사한 범위
  local e w
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "❌ 시크릿 · 민감 파일 ($LABEL, 엔진 $ENGINE) — $1" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    engine_note
    echo "규칙: $RULES" >&2
    exit 2
  fi
  echo "✅ 시크릿 · 민감 파일 없음 ($LABEL, 엔진 $ENGINE) — $1"
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w"; done
  engine_note
  exit 0
}

# 작업 트리 — 추적 파일과 ignore 안 된 새 파일. 저장소가 아니면 파일 전체
check_tree() { # $1=디렉터리
  local root repo scan="$TMP/tree" p prefix=""
  root="$(cd "$1" && pwd -P)" || die "디렉터리가 없습니다: $1"
  mkdir -p "$scan"; : > "$TMP/tree-paths"
  if repo="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"; then
    repo="$(cd "$repo" && pwd -P)"
    [ "$root" = "$repo" ] || prefix="${root#"$repo"/}/"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$p" in .claude/worktrees/*) continue ;; esac
      echo "$p" >> "$TMP/tree-paths"; copy_file "$repo" "$p" "$scan"
    done < <(g -C "$root" ls-files --full-name -co --exclude-standard -- . 2>/dev/null)
    scan_dir "$scan" "$repo" | sort -u > "$TMP/found"
    collect_findings "$repo" "$TMP/found" GS-01
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      is_sensitive "$p" || continue
      is_allowed "$repo" "$p" && continue
      if is_tracked "$repo" "$p"; then ERRORS+=("[GS-02] $p — 민감 파일을 git 이 추적한다")
      else ERRORS+=("[GS-04] $p — 민감 파일이 ignore 되지 않았다"); fi
    done < "$TMP/tree-paths"
  else
    while IFS= read -r p; do
      p="${p#"$root"/}"; copy_file "$root" "$p" "$scan"
    done < <(find "$root" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)
    scan_dir "$scan" "" | sort -u > "$TMP/found"
    collect_findings "$root" "$TMP/found" GS-01
  fi
}

check_history() { # $1=디렉터리
  local repo scan="$TMP/history"
  repo="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || die "git 저장소가 아닙니다: $1"
  mkdir -p "$scan"
  g -C "$repo" log -p -U0 --no-color --no-ext-diff --format= --all 2>/dev/null | patch_to_dir "$scan"
  scan_dir "$scan" "$repo" | sort -u > "$TMP/found"
  collect_findings "$repo" "$TMP/found" GS-01
  g -C "$repo" log --all --name-only --diff-filter=A --format= 2>/dev/null > "$TMP/history-paths"
  collect_sensitive "$repo" "$TMP/history-paths"
}

check_paths() { # $@=파일 · 디렉터리
  local a scan="$TMP/paths" base
  mkdir -p "$scan"
  for a in "$@"; do
    if [ -d "$a" ]; then check_tree "$a"
    elif [ -f "$a" ]; then
      base="$(cd "$(dirname "$a")" && pwd -P)"
      copy_file "$base" "$(basename "$a")" "$scan"
    else die "파일이 없습니다: $a"
    fi
  done
  scan_dir "$scan" "" | sort -u > "$TMP/found-paths"
  collect_findings "/nonexistent" "$TMP/found-paths" GS-01
}

if [ "$#" -eq 0 ]; then
  if [ -t 0 ]; then die "사용법: validate-git-secret.sh <파일|디렉터리>... | --all [루트] | --history [루트]"; fi
  hook
fi

case "$1" in
  --all) check_tree "${2:-.}"; report "작업 트리 ${2:-.}" ;;
  --history) check_history "${2:-.}"; report "커밋 이력 ${2:-.}" ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) check_paths "$@"; report "$*" ;;
esac
