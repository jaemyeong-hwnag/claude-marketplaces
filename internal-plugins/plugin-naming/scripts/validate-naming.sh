#!/usr/bin/env bash
# 플러그인 / 스킬 / 커맨드 / 에이전트 이름이 네이밍 규칙을 지키는지 검증한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit)  → 경로에서 이름을 뽑아 규칙 검증
#   PostToolUse(Write|Edit) → glossary.json 이 바뀐 경우 사전 구조 검증
# CLI 모드 :
#   validate-naming.sh <경로 또는 이름> ...
#   validate-naming.sh --all [루트]      저장소 전체 이름 검사
#   validate-naming.sh --glossary [경로] 사전 구조만 검사
#
# 종료 코드: 0 통과 / 2 위반(훅에서 차단) / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# 사전 해석 순서: 환경변수 → 프로젝트 사전 → 플러그인 기본 사전
if [ -n "${NAMING_GLOSSARY:-}" ]; then
  GLOSSARY="$NAMING_GLOSSARY"
elif [ -r "$PROJECT_DIR/references/glossary.json" ]; then
  GLOSSARY="$PROJECT_DIR/references/glossary.json"
else
  GLOSSARY="$PLUGIN_ROOT/references/glossary.json"
fi

KEBAB_RE='^[a-z0-9]+(-[a-z0-9]+)*$'
# 슬롯은 {대상}-{범위}-{관심사}-{목적} 네 개가 상한이다
MAX_SEGMENTS=4

ERRORS=()
WARNINGS=()

die() { echo "validate-naming: $*" >&2; exit 1; }
[ -r "$GLOSSARY" ] || die "glossary 를 찾을 수 없습니다: $GLOSSARY"
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

# deny 단어 → use / 카테고리 / 의미 조회 테이블
DENY_TABLE="$(jq -r 'to_entries[] | .key as $cat | .value[]
  | .use as $use | .meaning as $meaning
  | (.deny // [])[] | [., $use, $cat, $meaning] | @tsv' "$GLOSSARY")"
USE_WORDS="$(jq -r '.[][] | .use' "$GLOSSARY")"
# 단어 → 카테고리. 카테고리가 곧 슬롯을 정한다.
USE_CATEGORY="$(jq -r 'to_entries[] | .key as $c | .value[] | [.use, $c] | @tsv' "$GLOSSARY")"

# 슬롯 등급: 1 대상·범위 / 2 관심사 / 3 목적. 왼쪽에서 오른쪽으로 커지기만 해야 한다.
slot_rank() { # $1=단어 → 등급
  local c
  c="$(printf '%s\n' "$USE_CATEGORY" | awk -F'\t' -v w="$1" '$1 == w { print $2; exit }')"
  case "$c" in
    action|role) echo 3 ;;
    quality)     echo 2 ;;
    *)           echo 1 ;;
  esac
}
slot_label() { # $1=등급 → 이름
  case "$1" in 3) echo "목적" ;; 2) echo "관심사" ;; *) echo "대상·범위" ;; esac
}

lookup_deny() { # $1=단어 → "deny\tuse\tcat\tmeaning" 또는 빈 문자열
  printf '%s\n' "$DENY_TABLE" | awk -F'\t' -v w="$1" '$1 == w { print; exit }'
}

is_use_word() {
  printf '%s\n' "$USE_WORDS" | grep -qx -- "$1"
}

# 이름 하나 검증. $1=종류(plugin|skill|command|agent) $2=이름
validate_name() {
  local kind="$1" name="$2" seg hit use cat meaning
  local label="$kind '$name'"

  if ! [[ "$name" =~ $KEBAB_RE ]]; then
    ERRORS+=("$label: kebab-case 위반 — 소문자와 하이픈만 사용하세요")
    return
  fi

  local -a segs=()
  local rest="$name"
  while [ -n "$rest" ]; do
    segs+=("${rest%%-*}")
    [ "$rest" = "${rest#*-}" ] && break
    rest="${rest#*-}"
  done

  # 슬롯 상한: {대상}-{범위}-{관심사}-{목적}
  if [ "${#segs[@]}" -gt "$MAX_SEGMENTS" ]; then
    ERRORS+=("$label: 단어가 ${#segs[@]} 개입니다 — {대상}-{범위}-{관심사}-{목적} 네 개까지만 쓰세요")
  fi

  # 단독 사용 금지: 한 단어짜리 이름은 종류를 불문하고 막는다.
  # 언어·프레임워크·범용 단어를 목록으로 열거하지 않아도 구조로 전부 걸린다.
  if [ "${#segs[@]}" -lt 2 ]; then
    ERRORS+=("$label: 한 단어 이름은 쓸 수 없습니다 — {대상}-{범위}-{관심사}-{목적} 중 최소 두 슬롯을 쓰세요 (예: ${name}-naming)")
  fi

  # 맥락 중복
  local i j
  for ((i = 0; i < ${#segs[@]}; i++)); do
    for ((j = i + 1; j < ${#segs[@]}; j++)); do
      if [ "${segs[$i]}" = "${segs[$j]}" ]; then
        ERRORS+=("$label: 맥락 중복 — '${segs[$i]}' 가 두 번 나옵니다")
      fi
    done
  done

  # 검사 대상 = 구성 단어 + (두 단어 이상일 때만) 이름 전체
  local -a targets=("${segs[@]}")
  [ "${#segs[@]}" -ge 2 ] && targets+=("$name")

  # glossary deny 검사: 전체 이름 + 각 구성 단어
  for seg in "${targets[@]}"; do
    hit="$(lookup_deny "$seg")"
    [ -n "$hit" ] || continue
    use="$(printf '%s' "$hit" | cut -f2)"
    cat="$(printf '%s' "$hit" | cut -f3)"
    meaning="$(printf '%s' "$hit" | cut -f4)"
    ERRORS+=("$label: '$seg' 은 glossary 의 deny 단어입니다 → '$use' 를 쓰세요 ($cat: $meaning)")
  done

  # 끝 단어는 {관심사} 또는 {목적} 이므로 반드시 사전에 등록돼 있어야 한다.
  # 앞 단어({대상}·{범위})는 도메인 고유명사(spring, notion, order)라 사전이 통제하지 않는다.
  if [ "${#segs[@]}" -ge 2 ]; then
    local last="${segs[${#segs[@]}-1]}"
    if ! is_use_word "$last" && ! [[ "$last" =~ ^[0-9]+$ ]] && [ -z "$(lookup_deny "$last")" ]; then
      if [ "${#last}" -le 3 ]; then
        ERRORS+=("$label: 끝 단어 '$last' 이 사전에 없습니다 — 줄임말이면 전체 단어를 쓰고, 공식 약어라면 glossary 에 등록하세요")
      else
        ERRORS+=("$label: 끝 단어 '$last' 이 사전에 없습니다 — 끝 단어는 {관심사} 또는 {목적} 이므로 glossary-update 스킬로 먼저 등록하세요")
      fi
    fi
  fi

  # 슬롯 순서: {대상}-{범위}-{관심사}-{목적} 순으로만 놓을 수 있다
  local prev_rank=0 cur_rank i2
  for ((i2 = 0; i2 < ${#segs[@]}; i2++)); do
    cur_rank="$(slot_rank "${segs[$i2]}")"
    if [ "$cur_rank" -lt "$prev_rank" ]; then
      ERRORS+=("$label: 슬롯 순서 위반 — '${segs[$i2]}'($(slot_label "$cur_rank"))가 $(slot_label "$prev_rank") 뒤에 왔습니다. {대상}-{범위}-{관심사}-{목적} 순으로 쓰세요")
      break
    fi
    prev_rank="$cur_rank"
  done

  # 앞 단어의 줄임말 의심은 경고로만 남긴다
  local idx
  for ((idx = 0; idx < ${#segs[@]} - 1; idx++)); do
    seg="${segs[$idx]}"
    if [ "${#seg}" -le 3 ] && ! is_use_word "$seg" && ! [[ "$seg" =~ ^[0-9]+$ ]]; then
      WARNINGS+=("$label: '$seg' 이 줄임말이면 사용 금지입니다 — 공식 약어라면 glossary 에 등록하세요")
    fi
  done
}

# 경로에서 검증 대상 이름을 뽑는다
validate_path() {
  local path="${1%/}"
  local matched=0
  # 이름이 plugins 로 끝나는 디렉터리(plugins/, public-plugins/, internal-plugins/ …)를 플러그인 위치로 본다
  if [[ "$path" =~ (^|/)([a-z0-9]+-)*plugins/([^/]+) ]]; then
    validate_name plugin "${BASH_REMATCH[3]}"; matched=1
  fi
  if [[ "$path" =~ (^|/)skills/([^/]+) ]]; then
    validate_name skill "${BASH_REMATCH[2]}"; matched=1
  fi
  if [[ "$path" =~ (^|/)commands/(.+)\.md$ ]]; then
    validate_name command "$(basename "${BASH_REMATCH[2]}")"; matched=1
  fi
  if [[ "$path" =~ (^|/)agents/([^/]+)\.md$ ]]; then
    validate_name agent "${BASH_REMATCH[2]}"; matched=1
  fi
  return $((1 - matched))
}

# glossary.json 구조 검증
validate_glossary() {
  local file="${1:-$GLOSSARY}" out
  if ! jq empty "$file" 2>/dev/null; then
    ERRORS+=("glossary: JSON 파싱 실패 — $file")
    return
  fi

  out="$(jq -r 'if (keys_unsorted) == (keys_unsorted | sort) then empty
    else "카테고리를 알파벳 순으로 정렬하세요" end' "$file")"
  [ -n "$out" ] && ERRORS+=("glossary: $out")

  out="$(jq -r 'to_entries[] | select([.value[].use] != ([.value[].use] | sort))
    | "\(.key) 카테고리의 항목을 use 알파벳 순으로 정렬하세요"' "$file")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("glossary: $l"); done <<< "$out"

  out="$(jq -r 'to_entries[] | .key as $c | .value[]
    | select((.use | type) != "string" or .use != (.use | ascii_downcase) or (.use | length) == 0)
    | "\($c): use 는 비어있지 않은 소문자 문자열이어야 합니다 (\(.use))"' "$file")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("glossary: $l"); done <<< "$out"

  out="$(jq -r 'to_entries[] | .key as $c | .value[]
    | select((.deny | type) != "array" or (.deny | length) < 1)
    | "\($c): \(.use) 의 deny 는 최소 1개의 배열이어야 합니다"' "$file")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("glossary: $l"); done <<< "$out"

  out="$(jq -r 'to_entries[] | .key as $c | .value[] | .use as $u | (.deny // [])[]
    | select(. != (. | ascii_downcase)) | "\($c): \($u) 의 deny 단어 \(.) 는 소문자여야 합니다"' "$file")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("glossary: $l"); done <<< "$out"

  out="$(jq -r 'to_entries[] | .key as $c | .value[]
    | select((.meaning | type) != "string" or (.meaning | length) == 0 or (.meaning | test("\n")))
    | "\($c): \(.use) 의 meaning 은 한 줄짜리 한국어 설명이어야 합니다"' "$file")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("glossary: $l"); done <<< "$out"

  out="$(jq -r '[.[][] | .use] + [.[][] | (.deny // [])[]]
    | group_by(.) | map(select(length > 1) | .[0])[]
    | "\(.) 가 여러 항목·카테고리에 중복 등록되어 있습니다"' "$file")"
  [ -n "$out" ] && while IFS= read -r l; do ERRORS+=("glossary: $l"); done <<< "$out"
}

report() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 네이밍 규칙 위반 (plugin-naming)" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "규칙: $PLUGIN_ROOT/references/naming-rules.md" >&2
    echo "사전: $GLOSSARY" >&2
    exit 2
  fi
  exit 0
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --glossary) validate_glossary "${2:-$GLOSSARY}" ;;
      --all)
        local root="${2:-$PROJECT_DIR}" d f
        # 이름이 *plugins 로 끝나는 디렉터리를 플러그인 디렉터리로 본다.
        while IFS= read -r d; do validate_name plugin "$d"; done < <(
          find "$root" -mindepth 1 -maxdepth 1 -type d -name '*plugins' -not -path '*/.git*' 2>/dev/null \
            | while IFS= read -r pd; do
                find "$pd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
                  | while IFS= read -r x; do basename "$x"; done
              done | sort -u
        )
        while IFS= read -r d; do validate_name skill "$(basename "$d")"; done \
          < <(find "$root" -type d -name skills -not -path '*/.git/*' \
              -exec find {} -mindepth 1 -maxdepth 1 -type d \; 2>/dev/null)
        while IFS= read -r f; do validate_name command "$(basename "$f" .md)"; done \
          < <(find "$root" -type f -path '*/commands/*.md' -not -path '*/.git/*' 2>/dev/null)
        while IFS= read -r f; do validate_name agent "$(basename "$f" .md)"; done \
          < <(find "$root" -type f -path '*/agents/*.md' -not -path '*/.git/*' 2>/dev/null)
        validate_glossary "$GLOSSARY"
        ;;
      *) for arg in "$@"; do
           if [[ "$arg" == */* || "$arg" == *.md ]]; then
             validate_path "$arg" || true
           else
             validate_name name "$arg"
           fi
         done ;;
    esac
    report
  fi

  # 훅 모드
  local payload event path
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)"
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
  [ -n "$path" ] || exit 0

  case "$event" in
    PostToolUse)
      case "$path" in
        */references/glossary.json|*/glossary.json) validate_glossary "$path" ;;
        *) exit 0 ;;
      esac
      ;;
    *) validate_path "$path" || exit 0 ;;
  esac
  report
}

main "$@"
