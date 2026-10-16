#!/usr/bin/env bash
# GitHub 개발 플로우를 검증한다 — 이슈·PR 템플릿, 브랜치 이름, main 보호, 머지 방식, 태그 위치.
# 기본 브랜치는 origin/HEAD 에서 읽는다 (없으면 origin/main → origin/master → main). 이하 main 은 기본 브랜치를 뜻한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Bash) → git · gh · claude plugin tag 명령을 보고 W-03 ~ W-10 위반이면 차단
# CLI 모드 :
#   validate-workflow.sh --templates [루트]     W-01 · W-02
#   validate-workflow.sh --branch <이름>        W-03
#   validate-workflow.sh --up-to-date [디렉터리] W-06 (로컬 origin/main 기준, fetch 하지 않음)
#   validate-workflow.sh --all [루트]           --templates 와 같다
#
# 종료 코드: 0 통과 / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/workflow-rules.md"

MAIN="main"   # detect_main 이 덮어쓴다
TYPES="feature bugfix"
BRANCH_RE='^(feature|bugfix)/[0-9]+-[a-z0-9]+(-[a-z0-9]+){0,4}$'

ERRORS=()
NOTICES=()

die() { echo "validate-workflow: $*" >&2; exit 1; }

err() { ERRORS+=("$1"); }
notice() { NOTICES+=("$1"); }

# ---- W-01 · W-02 : 템플릿 ---------------------------------------------------
check_templates() { # $1=루트
  local root="${1%/}" it="$1/.github/ISSUE_TEMPLATE" pt="$1/.github/PULL_REQUEST_TEMPLATE" t f label
  for t in $TYPES; do
    f="$it/$t.yml"
    if [ ! -r "$f" ]; then err ".github/ISSUE_TEMPLATE/$t.yml 이 없습니다 (W-01)"; continue; fi
    # labels: ["feature"] 또는 labels: feature — 한 줄 형식만 본다
    label="$(grep -E '^labels:' "$f" | head -1 | sed -E 's/^labels:[[:space:]]*//; s/[][" ]//g')"
    case ",$label," in *",$t,"*) ;; *) err ".github/ISSUE_TEMPLATE/$t.yml: labels 에 '$t' 가 없습니다 (W-01)" ;; esac
    grep -qE '^body:' "$f" || err ".github/ISSUE_TEMPLATE/$t.yml: body 가 없습니다 — YAML 이슈 폼이어야 합니다 (W-01)"
  done
  if [ -r "$it/config.yml" ]; then
    grep -qE '^blank_issues_enabled:[[:space:]]*false' "$it/config.yml" || \
      err ".github/ISSUE_TEMPLATE/config.yml: blank_issues_enabled: false 여야 합니다 (W-01)"
  else
    err ".github/ISSUE_TEMPLATE/config.yml 이 없습니다 — 빈 이슈를 막아야 합니다 (W-01)"
  fi
  for t in $TYPES; do
    f="$pt/$t.md"
    if [ ! -r "$f" ]; then err ".github/PULL_REQUEST_TEMPLATE/$t.md 가 없습니다 (W-02)"; continue; fi
    case "$t" in
      feature) grep -qF 'Closes #' "$f" || err ".github/PULL_REQUEST_TEMPLATE/feature.md: 'Closes #' 가 없습니다 (W-02)" ;;
      bugfix)  grep -qF 'Fixes #' "$f"  || err ".github/PULL_REQUEST_TEMPLATE/bugfix.md: 'Fixes #' 가 없습니다 (W-02)" ;;
    esac
  done
  for f in "$root/.github/pull_request_template.md" "$root/.github/PULL_REQUEST_TEMPLATE.md" \
           "$root/pull_request_template.md" "$root/docs/pull_request_template.md"; do
    [ -e "$f" ] && err "${f#"$root"/}: 단일 기본 PR 템플릿을 두지 않습니다 — 폴더 템플릿보다 우선해서 타입 구분이 무너집니다 (W-02)"
  done
  return 0
}

# ---- W-03 : 브랜치 이름 -----------------------------------------------------
check_branch_name() { # $1=이름
  local b="${1#refs/heads/}"
  b="${b%\"}"; b="${b#\"}"; b="${b%\'}"; b="${b#\'}"
  [[ "$b" =~ $BRANCH_RE ]] && return 0
  err "브랜치 '$b': {feature|bugfix}/{이슈 번호}-{slug} 여야 합니다 — 예: feature/12-order-sync. slug 는 영문 kebab-case 1 ~ 5 단어 (W-03)"
}

# ---- git 도우미 -------------------------------------------------------------
branch_of() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# 기본 브랜치 — origin/HEAD 가 가리키는 브랜치. clone 이 아닌 저장소(init 뒤 remote add)는 origin/HEAD 가 없다
detect_main() { # $1=디렉터리
  local h b
  h="$(git -C "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
  if [ -n "$h" ]; then MAIN="${h#origin/}"; return 0; fi
  for b in main master; do
    git -C "$1" rev-parse --verify -q "refs/remotes/origin/$b" >/dev/null 2>&1 && { MAIN="$b"; return 0; }
  done
  return 0
}

# 최신 main 을 포함하는가. $1=디렉터리 $2=대상 ref $3=fetch 여부(1)
contains_main() {
  local dir="$1" ref="$2" fetch="${3:-0}"
  if [ "$fetch" = 1 ]; then
    git -C "$dir" fetch -q origin "$MAIN" >/dev/null 2>&1 || return 2
  fi
  git -C "$dir" rev-parse --verify -q "origin/$MAIN" >/dev/null || return 2
  git -C "$dir" merge-base --is-ancestor "origin/$MAIN" "$ref" 2>/dev/null
}

has_tok() { # $1=찾을 토큰, 나머지=토큰들
  local want="$1" t; shift
  for t in "$@"; do [ "$t" = "$want" ] && return 0; done
  return 1
}
has_prefix_tok() { # $1=접두사(예: --label=) 나머지=토큰들
  local p="$1" t; shift
  for t in "$@"; do case "$t" in "$p"*) return 0 ;; esac; done
  return 1
}
unquote() { local s="$1"; s="${s%\"}"; s="${s#\"}"; s="${s%\'}"; s="${s#\'}"; printf '%s' "$s"; }
# 경로 인자 → 절대 디렉터리. 없는 곳이면 $1 그대로. $1=기준 디렉터리 $2=경로
resolve_dir() {
  local to="$2"
  case "$to" in "~") to="$HOME" ;; "~/"*) to="$HOME/${to#"~/"}" ;; esac
  case "$to" in /*) ;; *) to="$1/$to" ;; esac
  if [ -d "$to" ]; then (cd "$to" && pwd); else printf '%s' "$1"; fi
}

# ---- 명령 한 조각 검사 ------------------------------------------------------
# $1=작업 디렉터리 $2=명령 조각
check_git() { # $1=dir, 나머지=git 뒤 토큰
  local dir="$1"; shift
  local -a a=("$@")
  local i=0 sub br n t target refspecs=() nonflag=()
  # 전역 옵션: -C <path> · -c <k=v>
  while [ "$i" -lt "${#a[@]}" ]; do
    case "${a[$i]}" in
      -C) dir="$(resolve_dir "$dir" "${a[$((i+1))]:-.}")"; i=$((i+2)) ;;
      -c) i=$((i+2)) ;;
      -*) i=$((i+1)) ;;
      *) break ;;
    esac
  done
  sub="${a[$i]:-}"; a=("${a[@]:$((i+1))}")
  br="$(branch_of "$dir")"

  case "$sub" in
    commit)
      [ "$br" = "$MAIN" ] && err "$MAIN 에 직접 커밋하지 않습니다 — {feature|bugfix}/{이슈}-{slug} 브랜치에서 작업하고 PR 로 넣습니다 (W-09)" ;;
    merge)
      if [ "$br" = "$MAIN" ] && ! has_tok --ff-only ${a[@]+"${a[@]}"} && ! has_tok --abort ${a[@]+"${a[@]}"}; then
        err "$MAIN 에서 git merge 를 하지 않습니다 — PR 로 머지합니다. 받아오기만 하려면 --ff-only (W-09)"
      fi ;;
    pull)
      if [ "$br" = "$MAIN" ]; then
        if has_tok --rebase ${a[@]+"${a[@]}"} || has_tok -r ${a[@]+"${a[@]}"} || has_prefix_tok --rebase= ${a[@]+"${a[@]}"} \
           || has_tok --no-ff ${a[@]+"${a[@]}"} || has_tok --ff ${a[@]+"${a[@]}"}; then
          err "$MAIN 에서 git pull 은 --ff-only 로만 받습니다 (W-09)"
        elif ! has_tok --ff-only ${a[@]+"${a[@]}"} && [ "$(git -C "$dir" config pull.ff 2>/dev/null)" != only ]; then
          err "$MAIN 에서 git pull 은 --ff-only 로만 받습니다 — 머지 커밋이 생길 수 있습니다 (W-09)"
        fi
      fi ;;
    cherry-pick|revert|am)
      if [ "$br" = "$MAIN" ] && ! has_tok --abort ${a[@]+"${a[@]}"} && ! has_tok --quit ${a[@]+"${a[@]}"}; then
        err "$MAIN 에서 git $sub 를 하지 않습니다 — 커밋이 생깁니다. 작업 브랜치에서 하고 PR 로 넣습니다 (W-09)"
      fi ;;
    push)
      n=0
      while [ "$n" -lt "${#a[@]}" ]; do
        t="${a[$n]}"; n=$((n+1))
        case "$t" in
          --force) err "강제 푸시는 --force-with-lease 만 씁니다 (W-08)" ;;
          -o|--push-option|--repo|--receive-pack|--exec) n=$((n+1)) ;;
          --*) ;;
          -*f*) err "강제 푸시(-f)는 쓰지 않습니다 — --force-with-lease (W-08)" ;;
          -*) ;;
          +*) err "'$t' — + 로 시작하는 refspec 은 강제 푸시입니다. --force-with-lease 를 쓰세요 (W-08)"; nonflag+=("${t#+}") ;;
          *) nonflag+=("$t") ;;
        esac
      done
      # 첫 비옵션은 원격, 나머지는 refspec
      if [ "${#nonflag[@]}" -ge 2 ]; then
        for t in "${nonflag[@]:1}"; do
          target="${t##*:}"; target="${target#refs/heads/}"
          [ "$target" = "$MAIN" ] && err "$MAIN 에 직접 푸시하지 않습니다 — PR 로 넣습니다 (W-09)"
        done
      elif ! has_tok --tags ${a[@]+"${a[@]}"} && ! has_tok --delete ${a[@]+"${a[@]}"} && ! has_tok -d ${a[@]+"${a[@]}"}; then
        [ "$br" = "$MAIN" ] && err "$MAIN 에서 git push 하지 않습니다 — PR 로 넣습니다 (W-09)"
      fi ;;
    checkout|switch)
      n=0
      while [ "$n" -lt "${#a[@]}" ]; do
        case "${a[$n]}" in
          -b|-B|-c|-C) [ -n "${a[$((n+1))]:-}" ] && check_branch_name "${a[$((n+1))]}"; n=$((n+2)) ;;
          *) n=$((n+1)) ;;
        esac
      done ;;
    branch)
      # 만들기만 본다: git branch <이름> [시작점]. 옵션이 있으면 목록·삭제·이름변경 등이다
      if [ "${#a[@]}" -gt 0 ] && [[ "${a[0]}" != -* ]]; then
        check_branch_name "${a[0]}"
      fi
      n=0
      while [ "$n" -lt "${#a[@]}" ]; do
        case "${a[$n]}" in
          -m|-M) [ -n "${a[$((n+2))]:-}" ] && check_branch_name "${a[$((n+2))]}" || { [ -n "${a[$((n+1))]:-}" ] && check_branch_name "${a[$((n+1))]}"; }; break ;;
        esac
        n=$((n+1))
      done ;;
    worktree)
      if [ "${a[0]:-}" = "add" ]; then
        local path="" nb=""
        n=1
        while [ "$n" -lt "${#a[@]}" ]; do
          case "${a[$n]}" in
            -b|-B) nb="${a[$((n+1))]:-}"; n=$((n+2)) ;;
            -*) n=$((n+1)) ;;
            *) [ -z "$path" ] && path="$(unquote "${a[$n]}")"; n=$((n+1)) ;;
          esac
        done
        [ -n "$nb" ] && check_branch_name "$nb"
        case "$path" in
          .claude/worktrees/*|*/.claude/worktrees/*|"") ;;
          *) notice "워크트리 '$path' — .claude/worktrees/{이슈}-{slug} 에 두면 Claude Code 가 관리한다 (W-04)" ;;
        esac
      fi ;;
    tag)
      local create=0 t2
      for t2 in ${a[@]+"${a[@]}"}; do
        case "$t2" in
          -d|--delete|-l|--list|-v|--verify|-n*|--contains|--no-contains|--points-at|--merged|--no-merged|--sort*|--format*|--column*) create=0; break ;;
          -*) ;;
          *) create=1 ;;
        esac
      done
      if [ "$create" = 1 ] && [ "$br" != "$MAIN" ]; then
        err "태그는 $MAIN 에서만 답니다 (지금 '$br') — 리베이스가 SHA 를 바꿔 브랜치의 태그는 머지 뒤 어디에도 없는 커밋을 가리킵니다 (W-10)"
      fi ;;
  esac
}

check_gh() { # $1=dir, 나머지=gh 뒤 토큰
  local dir="$1"; shift
  local -a a=("$@")
  [ "${a[0]:-}" = "pr" ] || return 0
  local sub="${a[1]:-}"; a=("${a[@]:2}")
  local t v n label_ok=0 body_ok=0 web=0 arg="" repo="" head r
  local -a fills=()
  # 값을 받는 옵션의 값은 플래그로도 PR 번호로도 보지 않는다 — gh pr create · merge --help 기준
  case "$sub" in
    create)
      n=0
      while [ "$n" -lt "${#a[@]}" ]; do
        t="${a[$n]}"; v="${a[$((n+1))]:-}"; n=$((n+1))
        case "$t" in
          -w|--web) web=1 ;;
          -f|--fill|--fill-first|--fill-verbose) fills+=("$t") ;;
          -T|--template|-F|--body-file) body_ok=1; n=$((n+1)) ;;
          --template=*|--body-file=*) body_ok=1 ;;
          -l|--label) case ",$v," in *,feature,*|*,bugfix,*) label_ok=1 ;; esac; n=$((n+1)) ;;
          --label=*) case ",${t#--label=}," in *,feature,*|*,bugfix,*) label_ok=1 ;; esac ;;
          -a|--assignee|-B|--base|-b|--body|-H|--head|-m|--milestone|-p|--project|--recover|-r|--reviewer|-t|--title|-R|--repo) n=$((n+1)) ;;
        esac
      done
      [ "$web" = 1 ] && return 0
      for t in ${fills+"${fills[@]}"}; do
        err "gh pr create 에 $t 를 쓰지 않습니다 — 템플릿(--template feature.md · bugfix.md)으로 엽니다 (W-05)"
      done
      [ "$body_ok" = 1 ] || err "gh pr create 에 --template 또는 --body-file 이 없습니다 — 타입별 템플릿으로 엽니다 (W-05)"
      [ "$label_ok" = 1 ] || err "gh pr create 에 --label feature 또는 --label bugfix 가 없습니다 (W-05)"
      contains_main "$dir" HEAD 1; r=$?
      case "$r" in
        0) ;;
        1) err "브랜치가 최신 origin/$MAIN 을 포함하지 않습니다 — git rebase origin/$MAIN 뒤 검증·테스트를 다시 돌리고 PR 을 엽니다 (W-06)" ;;
        *) err "origin/$MAIN 과 비교할 수 없습니다 (fetch 실패) — 확인 전에는 PR 을 열지 않습니다 (W-06)" ;;
      esac ;;
    merge)
      local method=""
      n=0
      while [ "$n" -lt "${#a[@]}" ]; do
        t="${a[$n]}"; v="${a[$((n+1))]:-}"; n=$((n+1))
        case "$t" in
          -s|--squash) err "스쿼시 머지를 쓰지 않습니다 — gh pr merge --merge (W-07)" ;;
          -r|--rebase) err "리베이스 머지를 쓰지 않습니다 — 브랜치를 리베이스한 뒤 gh pr merge --merge (W-07)" ;;
          -m|--merge) method=merge ;;
          -R|--repo) repo="$v"; n=$((n+1)) ;;
          --repo=*) repo="${t#--repo=}" ;;
          -A|--author-email|-b|--body|-F|--body-file|--match-head-commit|-t|--subject) n=$((n+1)) ;;
          -*) ;;
          *) [ -z "$arg" ] && arg="$t" ;;
        esac
      done
      [ "$method" = merge ] || err "머지 방식을 --merge 로 명시합니다 (W-07)"
      head="$(cd "$dir" 2>/dev/null && gh pr view ${arg:+"$arg"} ${repo:+-R "$repo"} --json headRefName -q .headRefName 2>/dev/null)"
      if [ -z "$head" ]; then
        err "머지할 PR 의 브랜치를 알 수 없습니다 (gh pr view 실패) — 확인 전에는 머지하지 않습니다 (W-06)"
        return 0
      fi
      if ! git -C "$dir" fetch -q origin "$MAIN" "$head" >/dev/null 2>&1; then
        err "origin 에서 $MAIN · $head 를 받아올 수 없습니다 — 확인 전에는 머지하지 않습니다 (W-06)"
        return 0
      fi
      contains_main "$dir" "origin/$head" 0; r=$?
      case "$r" in
        0) ;;
        1) err "PR 브랜치 '$head' 가 최신 origin/$MAIN 을 포함하지 않습니다 — 리베이스하고 검증·테스트를 다시 돌린 뒤 머지합니다 (W-06)" ;;
        *) err "origin/$MAIN 과 비교할 수 없습니다 — 확인 전에는 머지하지 않습니다 (W-06)" ;;
      esac ;;
  esac
}

check_claude() { # $1=dir, 나머지=claude 뒤 토큰
  local dir="$1"; shift
  [ "${1:-}" = "plugin" ] && [ "${2:-}" = "tag" ] || return 0
  local br; br="$(branch_of "$dir")"
  [ -n "$br" ] && [ "$br" != "$MAIN" ] && \
    err "claude plugin tag 는 $MAIN 에서만 돌립니다 (지금 '$br') (W-10)"
  return 0
}

# 셸 명령을 단순 명령 단위로 자른다 — 한 줄에 한 명령, 토큰마다 \037 로 끝난다. 토큰 안의 줄바꿈은 \036.
# 따옴표 · 이스케이프 · $( ) · 백틱 · heredoc · 리다이렉션 · 주석을 알고, $( ) 안의 명령도 따로 낸다.
read -r -d '' LEX <<'AWK'
function emit() { if (CMD != "") print CMD; CMD = "" }
function endtok() { if (INTOK) { gsub(/\n/, "\036", TOK); CMD = CMD TOK SEP }; TOK = ""; INTOK = 0 }
function ch(o) { return substr(S, P + o, 1) }
function blanks() { while (P <= N && (ch(0) == " " || ch(0) == "\t")) P++ }
function heredocs(   i, e, line, cmp) {
  for (i = 1; i <= HD; i++) {
    while (P <= N) {
      e = index(substr(S, P), "\n")
      if (e == 0) { line = substr(S, P); P = N + 1 } else { line = substr(S, P, e - 1); P += e }
      cmp = line; if (HDTAB[i]) sub(/^\t+/, "", cmp)
      if (cmp == HDEND[i]) break
    }
  }
  HD = 0
}
function word(   w, c) {
  w = ""
  while (P <= N) {
    c = ch(0)
    if (c ~ /[ \t\n;&|()<>]/) break
    if (c == "\\") { w = w ch(1); P += 2; continue }
    if (c == "'" || c == "\"") { P++; while (P <= N && ch(0) != c) { w = w ch(0); P++ }; P++; continue }
    w = w c; P++
  }
  return w
}
function squote(   s) { s = ""; while (P <= N && ch(0) != "'") { s = s ch(0); P++ }; P++; return s }
function ansi(   s) { s = ""; while (P <= N && ch(0) != "'") { if (ch(0) == "\\") { s = s ch(1); P += 2 } else { s = s ch(0); P++ } }; P++; return s }
function arith(   d) { d = 0; while (P <= N) { if (ch(0) == "(") d++; else if (ch(0) == ")") { d--; if (d == 0) { P++; return } }; P++ } }
function braces(   d, s) { d = 0; s = ""; while (P <= N) { s = s ch(0); if (ch(0) == "{") d++; else if (ch(0) == "}") { d--; if (d == 0) { P++; return s } }; P++ }; return s }
function nested(stop,   sc, st, si) { sc = CMD; st = TOK; si = INTOK; CMD = ""; TOK = ""; INTOK = 0; lex(stop); CMD = sc; TOK = st; INTOK = si }
function dquote(   c, c2) {
  while (P <= N) {
    c = ch(0)
    if (c == "\"") { P++; return }
    if (c == "\\") { c2 = ch(1); if (c2 == "\n") { P += 2; continue }; if (c2 !~ /[$`"\\]/) TOK = TOK c; TOK = TOK c2; P += 2; continue }
    if (c == "$" && ch(1) == "(") { if (ch(2) == "(") { P++; arith(); continue }; P += 2; nested(")"); continue }
    if (c == "$" && ch(1) == "{") { P++; TOK = TOK "$" braces(); continue }
    if (c == "`") { P++; nested("`"); continue }
    TOK = TOK c; P++
  }
}
function lex(stop,   c, c2) {
  while (P <= N) {
    c = ch(0)
    if (stop != "" && c == stop) { P++; endtok(); emit(); return }
    if (c == "\\") { if (ch(1) != "\n") { TOK = TOK ch(1); INTOK = 1 }; P += 2; continue }
    if (c == "'") { P++; TOK = TOK squote(); INTOK = 1; continue }
    if (c == "\"") { P++; INTOK = 1; dquote(); continue }
    if (c == "$") {
      c2 = ch(1)
      if (c2 == "(") { INTOK = 1; if (ch(2) == "(") { P++; arith(); continue }; P += 2; nested(")"); continue }
      if (c2 == "{") { P++; TOK = TOK "$" braces(); INTOK = 1; continue }
      if (c2 == "'") { P += 2; TOK = TOK ansi(); INTOK = 1; continue }
      TOK = TOK c; INTOK = 1; P++; continue
    }
    if (c == "`") { P++; INTOK = 1; nested("`"); continue }
    if (c == " " || c == "\t") { endtok(); P++; continue }
    if (c == "\n") { endtok(); emit(); P++; heredocs(); continue }
    if (c == "#" && !INTOK) { while (P <= N && ch(0) != "\n") P++; continue }
    if (c == "&" && ch(1) == ">") { endtok(); P += 2; if (ch(0) == ">") P++; blanks(); word(); continue }
    if (c == ">" || c == "<") {
      if (INTOK && TOK ~ /^[0-9]+$/) { TOK = ""; INTOK = 0 } else endtok()
      if (substr(S, P, 3) == "<<<") { P += 3; blanks(); word(); continue }
      if (substr(S, P, 2) == "<<") { P += 2; HD++; HDTAB[HD] = 0; if (ch(0) == "-") { HDTAB[HD] = 1; P++ }; blanks(); HDEND[HD] = word(); continue }
      P++; while (P <= N && ch(0) ~ /[>&|]/) P++
      blanks(); word(); continue
    }
    if (c ~ /[;&|()]/) { endtok(); emit(); P++; continue }
    TOK = TOK c; INTOK = 1; P++
  }
  endtok(); emit()
}
{ S = (NR == 1) ? $0 : S "\n" $0 }
END { SEP = "\037"; N = length(S); P = 1; CMD = ""; TOK = ""; INTOK = 0; HD = 0; lex("") }
AWK

# 명령을 차례로 본다. cd 는 이후 명령의 디렉터리를 바꾼다. bash -c · eval 의 문자열은 다시 자른다.
check_command() { # $1=명령 $2=시작 디렉터리
  local cmd="$1" dir="$2" line base i wrap s
  local -a toks
  while IFS= read -r line; do
    IFS=$'\037' read -r -a toks <<< "$line"
    # 앞의 환경변수 대입 · 예약어 · 래퍼(command · env · sudo …)와 래퍼의 옵션을 건너뛴다
    wrap=0
    while [ "${#toks[@]}" -gt 0 ]; do
      case "${toks[0]}" in
        '{'|'}'|'!'|if|then|else|elif|do|while|until) ;;
        time|command|builtin|exec|nohup|sudo|env) wrap=1 ;;
        -*) [ "$wrap" = 1 ] || break ;;
        *) [[ "${toks[0]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || break ;;
      esac
      toks=("${toks[@]:1}")
    done
    [ "${#toks[@]}" -gt 0 ] || continue
    base="${toks[0]##*/}"
    case "$base" in
      cd|pushd) dir="$(resolve_dir "$dir" "${toks[1]:-$HOME}")" ;;
      git)    check_git "$dir" "${toks[@]:1}" ;;
      gh)     check_gh "$dir" "${toks[@]:1}" ;;
      claude) check_claude "$dir" "${toks[@]:1}" ;;
      eval)   s="${toks[*]:1}"; check_command "${s//$'\036'/$'\n'}" "$dir" ;;
      bash|sh|zsh|dash|ksh)
        for ((i = 1; i < ${#toks[@]}; i++)); do
          case "${toks[$i]}" in
            -c|-[a-z]*c) s="${toks[$((i+1))]:-}"; [ -n "$s" ] && check_command "${s//$'\036'/$'\n'}" "$dir"; break ;;
            -*) ;;
            *) break ;;
          esac
        done ;;
    esac
  done < <(printf '%s\n' "$cmd" | awk "$LEX")
}

report() {
  local e
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 개발 플로우 위반 (github-workflow)" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

emit_notices_json() {
  [ "${#NOTICES[@]}" -gt 0 ] || return 0
  local body n
  body="개발 플로우 알림 (github-workflow)"
  for n in "${NOTICES[@]}"; do body="$body"$'\n'"- $n"; done
  jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in --templates|--all|--up-to-date) detect_main "${2:-$PROJECT_DIR}" ;; esac
    case "$1" in
      --templates|--all) check_templates "${2:-$PROJECT_DIR}" ;;
      --branch) [ -n "${2:-}" ] || die "--branch 에는 이름이 필요합니다"; check_branch_name "$2" ;;
      --up-to-date)
        contains_main "${2:-$PROJECT_DIR}" HEAD 0
        case $? in
          0) ;;
          1) err "HEAD 가 origin/$MAIN 을 포함하지 않습니다 — git fetch origin && git rebase origin/$MAIN (W-06)" ;;
          *) err "origin/$MAIN 이 없습니다 — git fetch origin 먼저 (W-06)" ;;
        esac ;;
      *) die "알 수 없는 인자: $1" ;;
    esac
    report
  fi

  local payload tool cmd cwd
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  # 기본 브랜치 보호 가드라 확인할 수 없으면 막는다 — exit 1 은 Claude Code 에서 통과다
  if ! command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | grep -qE '(^|[^[:alnum:]_-])(git|gh|claude)[[:space:]]' || exit 0
    echo "validate-workflow: jq 가 없어 git · gh 명령을 검사할 수 없습니다 — jq 를 설치하세요" >&2
    exit 2
  fi
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)"
  [ "$tool" = "Bash" ] || exit 0
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  [ -n "$cmd" ] || exit 0
  # 빠른 탈출 — 관심 있는 명령이 아니면 git 을 부르지 않는다
  printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_-])(git|gh|claude)[[:space:]]' || exit 0
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)"
  [ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PROJECT_DIR"
  detect_main "$cwd"
  check_command "$cmd" "$cwd"
  if [ "${#ERRORS[@]}" -gt 0 ]; then report; fi
  emit_notices_json
  exit 0
}

main "$@"
