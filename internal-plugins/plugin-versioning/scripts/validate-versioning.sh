#!/usr/bin/env bash
# 플러그인 버전 값과 그 값이 남는 자리의 정합성을 검증한다.
# 이름(plugin-naming)·디렉터리 구조(marketplace-directory-structure)·배치 정책은 다루지 않는다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit)  → plugin.json 에 들어가는 version 값 검사 (V-01·V-03, 차단)
#   PostToolUse(Write|Edit) → plugin.json · CHANGELOG.md 정합성 검사 (V-06, 알림만)
# CLI 모드 :
#   validate-versioning.sh <플러그인 디렉터리> ...
#   validate-versioning.sh --all [루트]          루트 + 모든 플러그인 + 태그
#   validate-versioning.sh --marketplace [루트]  루트 엔트리만
#   validate-versioning.sh --tag [루트]          git 태그만
#
# 종료 코드: 0 통과 / 2 위반(훅에서 차단) / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/versioning-rules.md"

# 규칙 원본은 references/versioning-rules.md 다. 여기는 그 기계 검증이다.
SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
UNRELEASED='미출시'

ERRORS=()
NOTICES=()
MODE=cli

die() { echo "validate-versioning: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

err() { ERRORS+=("$1"); }
notice() { NOTICES+=("$1"); }

is_semver() { [[ "$1" =~ $SEMVER_RE ]]; }

# $1 > $2 이면 0. 세 자리 숫자만 들어온다고 가정한다.
ver_gt() {
  local a="$1" b="$2" i x y
  local -a A B
  IFS=. read -r -a A <<< "$a"
  IFS=. read -r -a B <<< "$b"
  for i in 0 1 2; do
    x="${A[$i]:-0}"; y="${B[$i]:-0}"
    ((10#$x > 10#$y)) && return 0
    ((10#$x < 10#$y)) && return 1
  done
  return 1
}

# ---- V-01 · V-03 : 버전 값 자체 -------------------------------------------
check_version_value() { # $1=버전 $2=출처 라벨
  local v="$1" label="$2"
  if [ -z "$v" ] || [ "$v" = "null" ]; then
    err "$label: version 이 없습니다 (V-02)"
    return
  fi
  if ! is_semver "$v"; then
    err "$label: version '$v' 은 MAJOR.MINOR.PATCH 형식이 아닙니다 — v 접두사·prerelease·build·선행 0 을 쓰지 않습니다 (V-01)"
    return
  fi
  case "$v" in
    0.0.*) err "$label: version '$v' — 신규 플러그인은 0.1.0 부터 시작합니다. 0.0.x 는 쓰지 않습니다 (V-03)" ;;
  esac
}

# ---- V-04 ~ V-08 : CHANGELOG ----------------------------------------------
# CHANGELOG 의 '## ' 제목만 순서대로 뽑는다. 코드펜스 안은 건너뛴다.
changelog_headings() { # $1=파일
  awk '
    /^```/ { fence = !fence; next }
    !fence && /^##[ \t]+/ { sub(/^##[ \t]+/, ""); sub(/[ \t]+$/, ""); print }
  ' "$1"
}

check_changelog() { # $1=CHANGELOG 경로 $2=현재 버전 $3=라벨
  local file="$1" cur="$2" label="$3" first h prev="" seen_ver=0 found=0
  local -a heads=()

  if [ ! -r "$file" ]; then
    err "$label: CHANGELOG.md 를 읽을 수 없습니다"
    return
  fi

  first="$(grep -m1 -v '^[[:space:]]*$' "$file" 2>/dev/null || true)"
  [ "$first" = "# CHANGELOG" ] || err "$label/CHANGELOG.md: 첫 줄은 '# CHANGELOG' 여야 합니다 (V-04)"

  while IFS= read -r h; do [ -n "$h" ] && heads+=("$h"); done < <(changelog_headings "$file")

  if [ "${#heads[@]}" -eq 0 ]; then
    err "$label/CHANGELOG.md: '## {버전}' 항목이 하나도 없습니다 (V-05)"
    return
  fi

  local -a vers=()
  local idx=0
  for h in "${heads[@]}"; do
    if [ "$h" = "$UNRELEASED" ]; then
      [ "$idx" = 0 ] || err "$label/CHANGELOG.md: '## $UNRELEASED' 는 맨 위에만 둡니다 (V-07)"
      seen_ver=1
    elif is_semver "$h"; then
      vers+=("$h")
    else
      err "$label/CHANGELOG.md: 항목 '## $h' — 제목은 '## {버전}' 또는 '## $UNRELEASED' 여야 합니다 (V-05)"
    fi
    idx=$((idx+1))
  done

  for h in ${vers+"${vers[@]}"}; do
    [ "$h" = "$cur" ] && found=1
    if [ -n "$prev" ]; then
      if [ "$h" = "$prev" ]; then
        err "$label/CHANGELOG.md: 버전 '$h' 이 두 번 나옵니다 (V-08)"
      elif ! ver_gt "$prev" "$h"; then
        err "$label/CHANGELOG.md: '## $prev' 다음에 '## $h' — 버전 항목은 내림차순이어야 합니다 (V-07)"
      fi
    fi
    prev="$h"
  done

  if [ -n "$cur" ] && is_semver "$cur" && [ "$found" = 0 ]; then
    err "$label/CHANGELOG.md: plugin.json 의 version '$cur' 에 해당하는 '## $cur' 항목이 없습니다 (V-06)"
  fi
  return 0
}

# ---- V-11 : dependencies ---------------------------------------------------
check_dependencies() { # $1=plugin.json $2=라벨
  local file="$1" label="$2" line dep ver
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    dep="${line%%$'\t'*}"; ver="${line#*$'\t'}"
    [ -n "$ver" ] && [ "$ver" != "null" ] || continue
    # ~1.0.0 · ^1.2.0 · >=1.0.0 <2.0.0 · 1.0.0 · * 를 허용한다
    if ! [[ "$ver" =~ ^([*]|([~^]|[<>]=?|=)?[0-9]+(\.[0-9]+){0,2}([[:space:]]+([<>]=?|=)?[0-9]+(\.[0-9]+){0,2})*)$ ]]; then
      err "$label: dependencies '$dep' 의 version '$ver' 은 semver 범위 문자열이 아닙니다 (V-11)"
    fi
  done < <(jq -r '(.dependencies // [])[] | select(type == "object")
                  | "\(.name // "?")\t\(.version // "")"' "$file" 2>/dev/null)
}

# ---- 플러그인 하나 ---------------------------------------------------------
validate_plugin_dir() { # $1=디렉터리
  local dir="${1%/}" name manifest ver
  name="$(basename "$dir")"
  if [ ! -d "$dir" ]; then err "$dir: 디렉터리가 없습니다"; return; fi

  manifest="$dir/.claude-plugin/plugin.json"
  if [ ! -r "$manifest" ]; then
    err "$name: .claude-plugin/plugin.json 이 없습니다"
    return
  fi
  if ! jq empty "$manifest" 2>/dev/null; then
    err "$name: plugin.json JSON 파싱 실패"
    return
  fi

  ver="$(jq -r '.version // ""' "$manifest")"
  check_version_value "$ver" "$name"
  check_dependencies "$manifest" "$name"
  check_changelog "$dir/CHANGELOG.md" "$ver" "$name"
}

# ---- V-09 · V-10 : 마켓플레이스 루트 --------------------------------------
validate_marketplace() { # $1=루트
  local root="${1%/}" file meta line name entry_ver src manifest man_ver
  file="$root/.claude-plugin/marketplace.json"
  if [ ! -r "$file" ]; then
    err "마켓플레이스 루트: .claude-plugin/marketplace.json 이 없습니다"
    return
  fi
  if ! jq empty "$file" 2>/dev/null; then
    err "marketplace.json: JSON 파싱 실패"
    return
  fi

  meta="$(jq -r '.metadata.version // ""' "$file")"
  if [ -n "$meta" ] && ! is_semver "$meta"; then
    err "marketplace.json: metadata.version '$meta' 이 MAJOR.MINOR.PATCH 형식이 아닙니다 (V-10)"
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    name="${line%%$'\t'*}"; line="${line#*$'\t'}"
    entry_ver="${line%%$'\t'*}"; src="${line#*$'\t'}"
    [ -n "$entry_ver" ] && [ "$entry_ver" != "null" ] || continue
    if ! is_semver "$entry_ver"; then
      err "marketplace.json: '$name' 엔트리의 version '$entry_ver' 이 MAJOR.MINOR.PATCH 형식이 아닙니다 (V-01)"
      continue
    fi
    case "$src" in ./*) ;; *) continue ;; esac
    manifest="$root/${src#./}/.claude-plugin/plugin.json"
    [ -r "$manifest" ] || continue
    man_ver="$(jq -r '.version // ""' "$manifest" 2>/dev/null)"
    [ -n "$man_ver" ] || continue
    [ "$man_ver" = "$entry_ver" ] || \
      err "marketplace.json: '$name' 엔트리는 '$entry_ver', plugin.json 은 '$man_ver' — 설치 시점에는 plugin.json 이 이깁니다. 엔트리를 고치세요 (V-09)"
  done < <(jq -r '(.plugins // [])[]
                  | "\(.name // "?")\t\(.version // "")\t\(if (.source|type) == "string" then .source else "" end)"' "$file" 2>/dev/null)
}

# ---- V-12 · V-13 : git 태그 ------------------------------------------------
validate_tags() { # $1=루트
  local root="${1%/}" tag name ver manifest man_ver d found
  command -v git >/dev/null 2>&1 || return 0
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 0

  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    if [[ "$tag" != *--v* ]]; then
      err "태그 '$tag': 형식은 {플러그인명}--v{버전} 입니다 (V-12)"
      continue
    fi
    name="${tag%%--v*}"
    ver="${tag#*--v}"
    if ! is_semver "$ver"; then
      err "태그 '$tag': 버전 부분 '$ver' 이 MAJOR.MINOR.PATCH 형식이 아닙니다 (V-12)"
      continue
    fi
    found=0
    for d in "$root"/*plugins/"$name"; do
      manifest="$d/.claude-plugin/plugin.json"
      [ -r "$manifest" ] || continue
      found=1
      man_ver="$(jq -r '.version // ""' "$manifest" 2>/dev/null)"
      is_semver "$man_ver" || continue
      ver_gt "$ver" "$man_ver" && \
        err "태그 '$tag': plugin.json 의 version 은 '$man_ver' 입니다 — 태그가 매니페스트보다 앞설 수 없습니다 (V-13)"
    done
    [ "$found" = 1 ] || err "태그 '$tag': '$name' 플러그인이 없습니다 (V-12)"
  done < <(git -C "$root" tag 2>/dev/null)
  return 0
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
  validate_tags "$root"
}

# 훅에서 알림만 낼 때 Claude 컨텍스트로 넘긴다
emit_notices_json() { # $1=이벤트명
  [ "${#NOTICES[@]}" -gt 0 ] || return 0
  local body n
  body="버전 정합성 알림 (plugin-versioning) — 막지 않았습니다. 이어서 맞추세요."
  for n in "${NOTICES[@]}"; do body="$body"$'\n'"- $n"; done
  body="$body"$'\n'"릴리즈 순서: plugin.json version → CHANGELOG 항목 → marketplace 엔트리 → 검증 → 커밋 → claude plugin tag --push"
  body="$body"$'\n'"기준: $RULES"
  jq -n --arg e "$1" --arg c "$body" \
    '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}'
}

report() {
  local e
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ 버전 규칙 위반 (plugin-versioning)" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

# ---- 훅 모드 ---------------------------------------------------------------
# Write 는 tool_input.content, Edit 는 tool_input.new_string 에 새 내용이 들어온다.
hook_pre() { # $1=경로 $2=payload
  local path="$1" payload="$2" body ver
  case "$path" in */.claude-plugin/plugin.json) ;; *) exit 0 ;; esac
  body="$(printf '%s' "$payload" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null)"
  [ -n "$body" ] || exit 0
  ver="$(printf '%s' "$body" | jq -r '.version // empty' 2>/dev/null)"
  if [ -z "$ver" ]; then
    # Edit 의 부분 문자열이라 JSON 이 아닐 수 있다. 한 줄에서 찾는다.
    ver="$(printf '%s' "$body" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fi
  [ -n "$ver" ] || exit 0
  check_version_value "$ver" "$(basename "$(dirname "$(dirname "$path")")")"
  report
}

hook_post() { # $1=경로
  local path="$1" dir manifest ver
  case "$path" in
    */.claude-plugin/plugin.json) dir="$(cd "$(dirname "$(dirname "$path")")" 2>/dev/null && pwd)" ;;
    */CHANGELOG.md)               dir="$(cd "$(dirname "$path")" 2>/dev/null && pwd)" ;;
    *) exit 0 ;;
  esac
  [ -n "$dir" ] || exit 0
  manifest="$dir/.claude-plugin/plugin.json"
  [ -r "$manifest" ] && [ -r "$dir/CHANGELOG.md" ] || exit 0
  jq empty "$manifest" 2>/dev/null || exit 0
  ver="$(jq -r '.version // ""' "$manifest")"
  ERRORS=()
  check_version_value "$ver" "$(basename "$dir")"
  check_changelog "$dir/CHANGELOG.md" "$ver" "$(basename "$dir")"
  NOTICES=(${ERRORS+"${ERRORS[@]}"})
  ERRORS=()
  emit_notices_json PostToolUse
  exit 0
}

main() {
  if [ "$#" -gt 0 ]; then
    case "$1" in
      --all)         validate_all "${2:-$PROJECT_DIR}" ;;
      --marketplace) validate_marketplace "${2:-$PROJECT_DIR}" ;;
      --tag)         validate_tags "${2:-$PROJECT_DIR}" ;;
      *)             for arg in "$@"; do validate_plugin_dir "$arg"; done ;;
    esac
    report
  fi

  MODE=hook
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
