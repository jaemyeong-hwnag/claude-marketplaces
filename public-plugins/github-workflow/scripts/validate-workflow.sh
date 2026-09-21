#!/usr/bin/env bash
# GitHub 개발 플로우를 검증한다 — 이슈·PR 템플릿, 브랜치 이름, main 보호, 머지 방식, 태그 위치.
# 기본 브랜치는 origin/HEAD 에서 읽는다 (없으면 main). 이하 main 은 기본 브랜치를 뜻한다.
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
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

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

# 기본 브랜치 — origin/HEAD 가 가리키는 브랜치. 없으면 main
detect_main() { # $1=디렉터리
  local h
  h="$(git -C "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
  [ -n "$h" ] && MAIN="${h#origin/}"
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

# ---- 명령 한 조각 검사 ------------------------------------------------------
# $1=작업 디렉터리 $2=명령 조각
check_git() { # $1=dir, 나머지=git 뒤 토큰
  local dir="$1"; shift
  local -a a=("$@")
  local i=0 sub br n t target refspecs=() nonflag=()
  # 전역 옵션: -C <path> · -c <k=v>
  while [ "$i" -lt "${#a[@]}" ]; do
    case "${a[$i]}" in
      -C) dir="$(cd "$dir" 2>/dev/null && cd "$(unquote "${a[$((i+1))]:-.}")" 2>/dev/null && pwd || echo "$dir")"; i=$((i+2)) ;;
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
    push)
      for t in ${a[@]+"${a[@]}"}; do
        case "$t" in
          --force|--force-if-includes) err "강제 푸시는 --force-with-lease 만 씁니다 (W-08)" ;;
          --force-with-lease*) ;;
          --*) ;;
          -*f*) err "강제 푸시(-f)는 쓰지 않습니다 — --force-with-lease (W-08)" ;;
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
  local t n label_ok=0 body_ok=0 arg="" head r
  case "$sub" in
    create)
      has_tok --web ${a[@]+"${a[@]}"} && return 0
      has_tok -w ${a[@]+"${a[@]}"} && return 0
      for t in --fill -f --fill-first --fill-verbose; do
        has_tok "$t" ${a[@]+"${a[@]}"} && err "gh pr create 에 $t 를 쓰지 않습니다 — 템플릿(--template feature.md · bugfix.md)으로 엽니다 (W-05)"
      done
      n=0
      while [ "$n" -lt "${#a[@]}" ]; do
        case "${a[$n]}" in
          -T|--template|-F|--body-file) body_ok=1; n=$((n+2)) ;;
          --template=*|--body-file=*) body_ok=1; n=$((n+1)) ;;
          -l|--label) case ",$(unquote "${a[$((n+1))]:-}")," in *,feature,*|*,bugfix,*) label_ok=1 ;; esac; n=$((n+2)) ;;
          --label=*) case ",$(unquote "${a[$n]#--label=}")," in *,feature,*|*,bugfix,*) label_ok=1 ;; esac; n=$((n+1)) ;;
          *) n=$((n+1)) ;;
        esac
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
      has_tok --squash ${a[@]+"${a[@]}"} && err "스쿼시 머지를 쓰지 않습니다 — gh pr merge --merge (W-07)"
      has_tok -s ${a[@]+"${a[@]}"} && err "스쿼시 머지(-s)를 쓰지 않습니다 — gh pr merge --merge (W-07)"
      has_tok --rebase ${a[@]+"${a[@]}"} && err "리베이스 머지를 쓰지 않습니다 — 브랜치를 리베이스한 뒤 gh pr merge --merge (W-07)"
      has_tok -r ${a[@]+"${a[@]}"} && err "리베이스 머지(-r)를 쓰지 않습니다 — gh pr merge --merge (W-07)"
      if ! has_tok --merge ${a[@]+"${a[@]}"} && ! has_tok -m ${a[@]+"${a[@]}"}; then
        err "머지 방식을 --merge 로 명시합니다 (W-07)"
      fi
      for t in ${a[@]+"${a[@]}"}; do case "$t" in -*) ;; *) arg="$(unquote "$t")"; break ;; esac; done
      head="$(cd "$dir" 2>/dev/null && gh pr view ${arg:+"$arg"} --json headRefName -q .headRefName 2>/dev/null)"
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

# 복합 명령을 조각으로 나눠 차례로 본다. cd 는 이후 조각의 디렉터리를 바꾼다.
check_command() { # $1=명령 $2=시작 디렉터리
  local cmd="$1" dir="$2" seg
  local -a toks
  while IFS= read -r seg; do
    seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$seg" ] || continue
    read -r -a toks <<< "$seg"
    # 앞의 환경변수 대입(FOO=bar cmd)은 건너뛴다
    while [ "${#toks[@]}" -gt 0 ] && [[ "${toks[0]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do toks=("${toks[@]:1}"); done
    [ "${#toks[@]}" -gt 0 ] || continue
    case "${toks[0]}" in
      cd)
        local to; to="$(unquote "${toks[1]:-$HOME}")"
        case "$to" in /*) ;; *) to="$dir/$to" ;; esac
        [ -d "$to" ] && dir="$(cd "$to" && pwd)" ;;
      git)    check_git "$dir" "${toks[@]:1}" ;;
      gh)     check_gh "$dir" "${toks[@]:1}" ;;
      claude) check_claude "$dir" "${toks[@]:1}" ;;
    esac
  done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
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
