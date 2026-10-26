#!/usr/bin/env bash
# 문서의 DOI · arXiv ID · URL 이 실제로 있는지 확인한다. 규칙: references/reference-search-rules.md (RS-01 ~ RS-06)
#   reference-validate.sh [--urls] <파일...>   파일 전체 확인. 없는 식별자 · 404 URL 이 있으면 1
#   reference-validate.sh --hook                PreToolUse 입력(stdin)에서 새로 생기는 DOI · arXiv ID 만 확인
set -uo pipefail

[ "${REFERENCE_VALIDATE:-}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

UA="reference-search (Claude Code plugin)"
DOI_API="${REFERENCE_VALIDATE_DOI_API:-https://doi.org/api/handles}"
ARXIV_API="${REFERENCE_VALIDATE_ARXIV_API:-https://export.arxiv.org/abs}"
OPENALEX_API="${REFERENCE_VALIDATE_OPENALEX_API:-https://api.openalex.org/works}"
LIMIT="${REFERENCE_VALIDATE_LIMIT:-20}"
CACHE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/reference-validate-$(id -u)}"
CACHE="$CACHE_DIR/checked.txt"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/reference-validate.XXXXXX")" || exit 0
trap 'rm -rf "$WORK"' EXIT

# 짝이 안 맞는 닫는 괄호 · 꺾쇠를 끝에서 뗀다 — 괄호가 든 DOI(10.1016/S0140-6736(20)30183-5)는 살린다
trim_unbalanced() {
  local v="$1" o c pair
  for pair in '()' '<>'; do
    o="${pair%?}"; c="${pair#?}"
    while [ "${v%"$c"}" != "$v" ]; do
      [ "$(printf '%s' "$v" | tr -cd "$c" | wc -c)" -gt "$(printf '%s' "$v" | tr -cd "$o" | wc -c)" ] || break
      v="$(printf '%s' "${v%"$c"}" | sed -E 's/[.,;:!?]+$//')"
    done
  done
  printf '%s' "$v"
}

# 출판사 URL 에 붙은 꼬리(.pdf · /abstract · bioRxiv 버전 v1 …)를 뗀다
trim_doi() {
  local v="$1" prev=""
  while [ "$v" != "$prev" ]; do
    prev="$v"
    v="$(printf '%s' "$v" | sed -E 's/[.,;:]+$//; s#/+$##; s#(\.full)?\.pdf$##; s#\.(full|abstract)$##; s#/(abstract|full|fulltext|pdf|epdf|meta|references|figures)$##')"
    case "$v" in 10.1101/*) v="$(printf '%s' "$v" | sed -E 's/v[0-9]+$//')" ;; esac
    v="$(trim_unbalanced "$v")"
  done
  printf '%s' "$v"
}

# 코드 펜스 · 인라인 코드 안의 식별자는 예시로 보고 뺀다
strip_code() { awk '/^[[:space:]]*(```|~~~)/ { f = !f; next } !f { gsub(/`[^`]*`/, ""); print }'; }

# 본문에서 식별자를 한 줄에 "doi <값>" · "arxiv <값>" 으로 뽑는다 (소문자 DOI)
# DOI 문자는 Crossref 권장 집합에 <> · + 를 더한 것으로 제한한다 — 한국어 조사 · URL 쿼리가 꼬리에 붙지 않게
extract_ids() {
  local text raw
  text="$(printf '%s\n' "$1" | strip_code)"
  printf '%s' "$text" | LC_ALL=C grep -oE '10\.[0-9]{4,9}/[-._;()/:A-Za-z0-9<>+]+' | while IFS= read -r raw; do
    raw="$(trim_doi "$raw")"
    [ -n "${raw#*/}" ] && printf 'doi %s\n' "$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  done
  printf '%s' "$text" | LC_ALL=C grep -oiE '(arxiv:[[:space:]]?|arxiv\.org/(abs|pdf)/)([0-9]{4}\.[0-9]{4,5}|[a-z-]+(\.[a-z]{2})?/[0-9]{7})(v[0-9]+)?' \
    | sed -E 's#^[aA][rR][xX][iI][vV](:[[:space:]]?|\.org/(abs|pdf)/)##; s#^([a-zA-Z-]+)\.[a-zA-Z]{2}/#\1/#' | while IFS= read -r raw; do
      printf 'arxiv %s\n' "$raw"
    done
}

ids_of() { extract_ids "$1" | sort -u; }

# 캐시 한 줄은 "kind id 상태" — 있다고 확인된 것만 남긴다 (철회 여부 포함)
cached() { mine && [ -f "$CACHE" ] && awk -v k="$1" 'index($0, k " ") == 1 && length($0) > length(k) + 1 { v = substr($0, length(k) + 2) } END { if (v != "") print v }' "$CACHE"; }
# 남이 만든 디렉터리의 캐시는 믿지도 쓰지도 않는다 (공유 /tmp)
mine() { [ -d "$CACHE_DIR" ] && [ -O "$CACHE_DIR" ] && [ ! -L "$CACHE" ]; }
remember() { { [ -d "$CACHE_DIR" ] || mkdir -p -m 700 "$CACHE_DIR" 2>/dev/null; } && mine && printf '%s\n' "$1" >> "$CACHE"; }

enc() { printf '%s' "$1" | sed 's/</%3C/g; s/>/%3E/g'; }

# 결과: found · missing · unknown (+ retracted 는 별도 줄)
check_one() {
  local kind="$1" id="$2" out="$3" code hit body="$WORK/body.$$.$RANDOM"
  hit="$(cached "$kind $id")"
  if [ -n "$hit" ]; then printf '%s\n' "$hit" | tr ',' '\n' > "$out"; return; fi
  case "$kind" in
    doi)   code="$(curl -s -m 8 -A "$UA" -o "$body" -w '%{http_code}' "$DOI_API/$(enc "$id")" 2>/dev/null)" ;;
    arxiv) code="$(curl -s -L -m 8 -A "$UA" -o "$body" -w '%{http_code}' "$ARXIV_API/$id" 2>/dev/null)" ;;
  esac
  # arXiv 가 한도(429)에 걸리면 모든 arXiv 논문에 붙는 DataCite DOI 로 다시 본다
  if [ "$kind" = arxiv ] && [ "$code" != 200 ] && [ "$code" != 404 ]; then
    code="$(curl -s -m 8 -A "$UA" -o "$body" -w '%{http_code}' "$DOI_API/10.48550/arxiv.$(printf '%s' "$id" | sed -E 's/v[0-9]+$//')" 2>/dev/null)"
  fi
  case "$code" in
    200) echo found > "$out" ;;
    404) echo missing > "$out" ;;
    *)   echo unknown > "$out" ;;
  esac
  if [ "$kind" = doi ] && [ "$code" = 200 ]; then
    code="$(curl -s -m 8 -A "$UA" -o "$body" -w '%{http_code}' "$OPENALEX_API/doi:$(enc "$id")" 2>/dev/null)"
    [ "$code" = 200 ] && [ "$(jq -r '.is_retracted // false' "$body" 2>/dev/null)" = true ] && echo retracted >> "$out"
  fi
  [ "$(head -1 "$out")" = found ] && remember "$kind $id $(paste -sd ',' "$out")"
  rm -f "$body"
}

# 식별자 목록(파일)을 병렬로 확인해 "kind id status[,retracted]" 를 낸다
check_all() {
  local list="$1" n=0 kind id
  while IFS=' ' read -r kind id; do
    [ -n "$id" ] || continue
    n=$((n+1))
    if [ "$n" -gt "$LIMIT" ]; then echo "$kind $id skipped"; continue; fi
    check_one "$kind" "$id" "$WORK/r.$n" &
    printf '%s %s\n' "$kind" "$id" > "$WORK/k.$n"
  done < "$list"
  wait
  local i=1
  while [ "$i" -le "$n" ] && [ "$i" -le "$LIMIT" ]; do
    printf '%s %s\n' "$(cat "$WORK/k.$i")" "$(paste -sd ',' "$WORK/r.$i" 2>/dev/null || echo unknown)"
    i=$((i+1))
  done
}

label() { [ "$1" = doi ] && echo DOI || echo "arXiv ID"; }

mode_hook() {
  local input tool file new old cur
  input="$(cat)"
  tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
  case "$file" in *.md|*.markdown) ;; *) exit 0 ;; esac
  cur=""; [ -f "$file" ] && cur="$(cat "$file")"
  case "$tool" in
    Write) new="$(printf '%s' "$input" | jq -r '.tool_input.content // empty')"; old="" ;;
    Edit)  new="$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty')"
           old="$(printf '%s' "$input" | jq -r '.tool_input.old_string // empty')" ;;
    MultiEdit) new="$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.new_string] | join("\n")')"
               old="$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.old_string] | join("\n")')" ;;
    *) exit 0 ;;
  esac
  ids_of "$new" > "$WORK/new"
  [ -s "$WORK/new" ] || exit 0
  { ids_of "$old"; ids_of "$cur"; } | sort -u > "$WORK/known"
  comm -23 "$WORK/new" "$WORK/known" > "$WORK/added"
  [ -s "$WORK/added" ] || exit 0

  check_all "$WORK/added" > "$WORK/result"
  local missing="" retracted="" unknown="" kind id st
  while IFS=' ' read -r kind id st; do
    case "$st" in
      missing*) missing="$missing
  - $(label "$kind") $id" ;;
      found,retracted*) retracted="$retracted
  - DOI $id" ;;
      unknown*|skipped) unknown="$unknown $id" ;;
    esac
  done < "$WORK/result"

  if [ -n "$missing" ]; then
    jq -n --arg r "reference-search: 등록되지 않은 식별자 (RS-01 · RS-02)$missing
검색 결과나 원문에서 식별자를 다시 확인한다. 찾지 못하면 그 인용을 지우거나 \`미확인\` 으로 표시한다. 지어내지 않는다" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
    exit 0
  fi
  local ctx=""
  [ -n "$retracted" ] && ctx="reference-search: 철회된 논문 (RS-03)$retracted
문서에 철회 사실을 같이 적는다."
  [ -n "$unknown" ] && ctx="${ctx:+$ctx
}reference-search: 확인하지 못한 식별자 (RS-04 — 네트워크 · 한도):$unknown. 나중에 /reference-validate 로 다시 확인한다."
  [ -n "$ctx" ] && jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  exit 0
}

check_url() {
  curl -s -L -m 10 -A "$UA" -o /dev/null -w '%{http_code}' "$1" 2>/dev/null
}

mode_files() {
  local urls=0 f fail=0 kind id st code u
  [ "${1:-}" = "--urls" ] && { urls=1; shift; }
  [ $# -gt 0 ] || { echo "사용법: reference-validate.sh [--urls] <파일...>" >&2; exit 64; }
  LIMIT=1000000
  for f in "$@"; do
    [ -f "$f" ] || { echo "❌ $f — 파일이 없다"; fail=1; continue; }
    echo "== $f"
    ids_of "$(cat "$f")" > "$WORK/ids"
    if [ -s "$WORK/ids" ]; then
      check_all "$WORK/ids" > "$WORK/result"
      while IFS=' ' read -r kind id st; do
        case "$st" in
          found,retracted*) echo "⚠️  RS-03 $(label "$kind") $id — 철회됨" ;;
          found*)   echo "✅ $(label "$kind") $id" ;;
          missing*) echo "❌ $( [ "$kind" = doi ] && echo RS-01 || echo RS-02 ) $(label "$kind") $id — 등록되지 않음"; fail=1 ;;
          *)        echo "❓ RS-04 $(label "$kind") $id — 확인 못 함" ;;
        esac
      done < "$WORK/result"
    fi
    if [ "$urls" = 1 ]; then
      LC_ALL=C grep -oE 'https?://[^][:space:]<>"`]+' "$f" | sed -E 's/[.,;:!?]+$//' | while IFS= read -r u; do trim_unbalanced "$u"; echo; done | sort -u | while IFS= read -r u; do
        code="$(check_url "$u")"
        case "$code" in
          2??|3??) echo "✅ $code $u" ;;
          404|410) echo "❌ RS-05 $code $u"; echo fail > "$WORK/url-fail" ;;
          000)     echo "❓ RS-04 응답 없음 $u" ;;
          *)       echo "⚠️  RS-06 $code $u — 접근 제한일 수 있다 (유료 장벽 · 봇 차단)" ;;
        esac
      done
      [ -f "$WORK/url-fail" ] && fail=1
    fi
  done
  exit "$fail"
}

case "${1:-}" in
  --hook) mode_hook ;;
  *) mode_files "$@" ;;
esac
