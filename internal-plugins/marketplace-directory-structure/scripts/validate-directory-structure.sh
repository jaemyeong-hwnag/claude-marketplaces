#!/usr/bin/env bash
# 마켓플레이스 루트와 플러그인의 디렉터리 구조를 검증한다.
# 이름 규칙(plugin-naming)·배치 정책(저장소 .claude/hooks/)은 다루지 않는다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → 그 파일을 그 위치에 둘 수 있는지 검사
# CLI 모드 :
#   validate-directory-structure.sh <플러그인 디렉터리 | 파일 경로> ...
#   validate-directory-structure.sh --all [루트]          루트 + 모든 플러그인
#   validate-directory-structure.sh --marketplace [루트]  루트만
#
# 종료 코드: 0 통과 / 2 위반(훅에서 차단) / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/directory-structure-rules.md"

# 규칙 원본은 references/directory-structure-rules.md 다. 여기는 그 기계 검증이다.
PLUGIN_ROOT_FILES="README.md CHANGELOG.md LICENSE .gitignore"
PLUGIN_DIRS=".claude-plugin skills hooks scripts commands references agents test"
MARKETPLACE_FILES="marketplace.json tags.json categories.json plugins.json keywords.json"

ERRORS=()
WARNINGS=()
SPLIT_NAME=""
SPLIT_REL=""

die() { echo "validate-directory-structure: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

err() { ERRORS+=("$1"); }
warn() { WARNINGS+=("$1"); }

has_word() { # $1=목록 $2=단어
  case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac
}

# 경로가 플러그인 안이면 SPLIT_NAME(플러그인명) · SPLIT_REL(내부 상대경로) 에 담고 0 을 낸다.
split_plugin_path() { # $1=경로
  local p="$1" rest name sub
  [[ "$p" == *plugins/* ]] || return 1
  rest="${p##*plugins/}"
  [ -n "$rest" ] || return 1
  name="${rest%%/*}"
  sub="${rest#*/}"
  # *plugins/ 바로 아래 파일은 플러그인이 아니다 (.gitkeep 등)
  [ "$sub" != "$rest" ] || return 1
  [ -n "$name" ] && [ -n "$sub" ] || return 1
  SPLIT_NAME="$name"
  SPLIT_REL="$sub"
}

# 플러그인 안의 파일 하나가 규칙에 있는 위치인지 본다. $1=플러그인명 $2=내부 상대경로
check_location() {
  local name="$1" rel="$2" top rest
  top="${rel%%/*}"

  if [ "$top" = "$rel" ]; then
    has_word "$PLUGIN_ROOT_FILES" "$rel" && return 0
    err "$name/$rel: 플러그인 루트에는 $PLUGIN_ROOT_FILES 만 둡니다 (P-05)"
    return 0
  fi

  rest="${rel#*/}"
  if ! has_word "$PLUGIN_DIRS" "$top"; then
    err "$name/$rel: 알 수 없는 디렉터리 '$top/' — $PLUGIN_DIRS 만 씁니다 (P-06)"
    return 0
  fi

  case "$top" in
    .claude-plugin)
      [ "$rest" = "plugin.json" ] || err "$name/$rel: .claude-plugin/ 에는 plugin.json 만 둡니다 (P-02)" ;;
    skills)
      # skills/<스킬명>/... 이어야 한다. 스킬 디렉터리 안쪽은 자유다.
      [[ "$rest" == */* ]] || err "$name/$rel: skills/ 아래에는 스킬 디렉터리만 둡니다 — skills/<스킬명>/SKILL.md (P-08)" ;;
    hooks)
      case "$rest" in *.json) ;; *) err "$name/$rel: hooks/ 에는 *.json 만 둡니다 (P-07)" ;; esac ;;
    scripts)
      case "$rest" in *.sh) ;; *) err "$name/$rel: scripts/ 에는 *.sh 만 둡니다 (P-07)" ;; esac ;;
    commands)
      case "$rest" in *.md) ;; *) err "$name/$rel: commands/ 에는 *.md 만 둡니다 (P-07)" ;; esac ;;
    references)
      case "$rest" in *.md|*.json) ;; *) err "$name/$rel: references/ 에는 *.md · *.json 만 둡니다 (P-07)" ;; esac ;;
    agents)
      case "$rest" in *.md) ;; *) err "$name/$rel: agents/ 에는 *.md 만 둡니다 (P-07)" ;; esac ;;
    test)
      case "$rest" in *.test.sh|README.md) ;; *) err "$name/$rel: test/ 에는 *.test.sh 와 README.md 만 둡니다 (P-07)" ;; esac ;;
  esac
}

# 플러그인 디렉터리 하나를 통째로 검사한다. $1=디렉터리
validate_plugin_dir() {
  local dir="${1%/}" name manifest declared hooks_rel f rel s
  name="$(basename "$dir")"
  if [ ! -d "$dir" ]; then err "$dir: 디렉터리가 없습니다"; return; fi

  manifest="$dir/.claude-plugin/plugin.json"
  [ -r "$manifest" ]        || err "$name: .claude-plugin/plugin.json 이 없습니다 (P-01)"
  [ -r "$dir/README.md" ]   || err "$name: README.md 가 없습니다 (P-01)"
  [ -r "$dir/CHANGELOG.md" ]|| err "$name: CHANGELOG.md 가 없습니다 (P-01)"

  if [ -r "$manifest" ]; then
    if ! jq empty "$manifest" 2>/dev/null; then
      err "$name: plugin.json JSON 파싱 실패"
    else
      declared="$(jq -r '.name // ""' "$manifest")"
      [ "$declared" = "$name" ] || \
        err "$name: plugin.json 의 name 이 '$declared' 입니다 — 디렉터리명과 같아야 합니다 (P-03)"
      # hooks 는 문자열·배열 어느 쪽도 될 수 있다. 문자열 경로만 훑는다.
      while IFS= read -r hooks_rel; do
        [ -n "$hooks_rel" ] || continue
        case "${hooks_rel#./}" in
          hooks/hooks.json)
            err "$name: plugin.json 의 hooks 가 표준 경로 $hooks_rel 을 가리킵니다 — 자동 로드되므로 중복이 되어 훅 로딩 전체가 실패합니다. 이 필드를 지우세요 (P-09)"
            continue ;;
        esac
        case "$hooks_rel" in
          ./*) [ -r "$dir/${hooks_rel#./}" ] || \
                 err "$name: plugin.json 의 hooks 가 가리키는 $hooks_rel 이 없습니다 (P-04)" ;;
        esac
      done < <(jq -r 'if (.hooks|type) == "string" then .hooks
                      elif (.hooks|type) == "array" then (.hooks[] | select(type == "string"))
                      else empty end' "$manifest" 2>/dev/null)
    fi
  fi

  while IFS= read -r f; do
    rel="${f#"$dir"/}"
    check_location "$name" "$rel"
  done < <(find "$dir" -type f -not -path '*/.git/*' 2>/dev/null | sort)

  if [ -d "$dir/skills" ]; then
    while IFS= read -r s; do
      [ -r "$s/SKILL.md" ] || err "$name/skills/$(basename "$s"): SKILL.md 가 없습니다 (P-08)"
    done < <(find "$dir/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  fi
}

# 마켓플레이스 루트를 검사한다. $1=루트
validate_marketplace() {
  local root="${1%/}" f b d rel sub
  if [ ! -r "$root/.claude-plugin/marketplace.json" ]; then
    err "마켓플레이스 루트: .claude-plugin/marketplace.json 이 없습니다 (R-01)"
    return
  fi
  jq empty "$root/.claude-plugin/marketplace.json" 2>/dev/null || err "marketplace.json: JSON 파싱 실패"

  [ -r "$root/README.md" ]    || err "마켓플레이스 루트: README.md 가 없습니다 (R-02)"
  [ -r "$root/CHANGELOG.md" ] || err "마켓플레이스 루트: CHANGELOG.md 가 없습니다 (R-02)"
  [ -r "$root/CLAUDE.md" ]    || warn "마켓플레이스 루트: CLAUDE.md 가 없습니다 (R-05)"

  while IFS= read -r f; do
    b="$(basename "$f")"
    has_word "$MARKETPLACE_FILES" "$b" || \
      err ".claude-plugin/$b: 알 수 없는 파일 — $MARKETPLACE_FILES 만 둡니다 (R-03)"
  done < <(find "$root/.claude-plugin" -maxdepth 1 -type f 2>/dev/null | sort)

  while IFS= read -r f; do
    d="$(dirname "$(dirname "$f")")"
    rel="${d#"$root"/}"
    case "$rel" in
      public-plugins/*|internal-plugins/*)
        sub="${rel#*/}"
        [[ "$sub" == */* ]] && \
          err "$rel: 플러그인은 {public|internal}-plugins/<이름>/ 바로 아래에 둡니다 (R-04)" ;;
      *)
        err "$rel: 플러그인은 public-plugins/ 또는 internal-plugins/ 아래에 둡니다 (R-04)" ;;
    esac
  done < <(find "$root" -type f -name plugin.json -path '*/.claude-plugin/*' \
             -not -path '*/.git/*' -not -path "$root/.claude/plugins/*" -not -path "$root/.claude/worktrees/*" 2>/dev/null | sort)
}

validate_all() { # $1=루트
  local root="${1%/}" pd d
  validate_marketplace "$root"
  while IFS= read -r d; do
    [ -d "$d/.claude-plugin" ] || continue
    validate_plugin_dir "$d"
  done < <(
    find "$root" -mindepth 1 -maxdepth 1 -type d -name '*plugins' -not -path '*/.git*' 2>/dev/null \
      | while IFS= read -r pd; do find "$pd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null; done | sort
  )
}

validate_arg() { # $1=경로
  local p="${1%/}"
  if [ -d "$p" ]; then
    if [ -r "$p/.claude-plugin/plugin.json" ] || [[ "$(dirname "$p")" == *plugins ]]; then
      validate_plugin_dir "$p"
    elif [ -r "$p/.claude-plugin/marketplace.json" ]; then
      validate_all "$p"
    else
      err "$p: 플러그인 디렉터리도 마켓플레이스 루트도 아닙니다"
    fi
    return
  fi
  split_plugin_path "$p" || return 0
  check_location "$SPLIT_NAME" "$SPLIT_REL"
}

report() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 디렉터리 구조 위반 (marketplace-directory-structure)" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --all)         validate_all "${2:-$PROJECT_DIR}" ;;
      --marketplace) validate_marketplace "${2:-$PROJECT_DIR}" ;;
      *)             for arg in "$@"; do validate_arg "$arg"; done ;;
    esac
    report
  fi

  # 훅 모드
  local payload path
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
  [ -n "$path" ] || exit 0
  split_plugin_path "$path" || exit 0
  check_location "$SPLIT_NAME" "$SPLIT_REL"
  report
}

main "$@"
