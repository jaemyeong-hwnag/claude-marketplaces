#!/usr/bin/env bash
# ST-01 — 부하 도구가 겨누는 호스트가 허용 목록 안인지 본다.
#
#   훅:  PreToolUse(Bash) — stdin 의 tool_input.command 를 본다. 위반이면 exit 2 (차단)
#   CLI: stress-target-validate.sh '<명령>'   위반이면 exit 2
#
# 허용: localhost · 루프백 · 사설 IPv4 · 점 없는 이름(컨테이너 · 서비스) · *.local · *.localhost · *.test · *.internal
#       · host.docker.internal · $STRESS_TEST_ALLOWED_HOSTS (쉼표 · 공백 구분, *.example.com 형태 허용)
# 종료 코드: 0 통과 / 2 위반 / 1 실행 오류
set -uo pipefail

RULES="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/references/stress-test-rules.md"
die() { echo "stress-target-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"

MODE=cli
if [ "$#" -ge 1 ]; then
  CMD="$1"
else
  INPUT="$(cat)"
  [ -n "$INPUT" ] || exit 0
  MODE=hook
  [ "$(printf '%s' "$INPUT" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null)" = "PreToolUse" ] || exit 0
  [ "$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)" = "Bash" ] || exit 0
  CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)"
fi
[ -n "$CMD" ] || exit 0
BASE="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

# heredoc 본문은 명령이 아니라 데이터다. 셸에 먹이는 heredoc(sh <<EOF)만 명령으로 남긴다
strip_heredoc() {
  awk -v q="'" '
    d != "" { t = $0; if (dash) sub(/^\t+/, "", t); if (t == d) d = ""; else if (keep) print; next }
    { print; s = $0; gsub(/<<</, "\001", s)
      if (match(s, "<<-?[ \t]*[\"" q "]?[A-Za-z_][A-Za-z0-9_]*")) {
        d = substr(s, RSTART, RLENGTH); dash = (d ~ /^<<-/)
        sub(/^<<-?[ \t]*/, "", d); gsub("[\"" q "]", "", d)
        keep = (s ~ /(^|[;&|(][ \t]*)(sudo[ \t]+)?(ba|z|da|k)?sh([ \t]+-[A-Za-z]+)*[ \t]*<</)
      } }'
}

# 부하 도구를 실행하는 구간인가 — 구간의 첫 단어(환경 변수 대입 · 래퍼 제외)나 docker 이미지로 판단한다. 도구 이름은 TOOL 에 남긴다
is_load_segment() {
  local seg="$1" w first="" rest
  TOOL=""
  # shellcheck disable=SC2086
  set -f; set -- $seg; set +f
  while [ "$#" -gt 0 ]; do
    w="${1#[\"\'(\{]}"
    case "$w" in
      *=*|sudo|time|nohup|exec|command|env|npx|bunx|pnpx|uvx|do|then|else|elif|if|while|until|!|-*|'') shift ;;
      uv|poetry|pipenv|pdm|hatch)
        [ "${2:-}" = run ] || { first="$w"; shift; break; }
        shift 2 ;;
      python|python3|python3.*)
        [ "${2:-}" = -m ] || { first="$w"; shift; break; }
        shift 2 ;;
      timeout)
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -s|-k|--signal|--kill-after) shift 2 ;;
            -*) shift ;;
            *) break ;;
          esac
        done
        [ "$#" -gt 0 ] && shift ;;
      sh|bash|zsh|dash|ksh)
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -*c) shift; break ;;
            -*) shift ;;
            *) set -- ; break ;;
          esac
        done
        [ "$#" -gt 0 ] || { first="$w"; break; } ;;
      *) first="$w"; shift; break ;;
    esac
  done
  rest="$*"
  first="${first##*/}"
  TOOL="$first"
  case "$first" in
    k6) case "$rest" in run*|cloud*) return 0 ;; esac ;;
    locust|jmeter|jmeter.sh|gatling|gatling.sh|wrk|wrk2|hey|oha|ab|autocannon) return 0 ;;
    vegeta) case "$rest" in attack*) return 0 ;; esac ;;
    artillery) case "$rest" in run*|quick*) return 0 ;; esac ;;
    docker|podman|docker-compose)
      printf '%s' "$rest" | grep -qE '(^|[ /])(grafana/k6|locustio/locust|[a-z0-9_.-]*/?jmeter|[a-z0-9_.-]*/?gatling)(:[^ ]*)?( |$)' && return 0
      # compose 서비스 이름으로 부하기를 띄우는 경우
      printf '%s' "$first $rest" | grep -qE '(compose|docker-compose).*( run| up).* (k6|locust|jmeter|gatling)( |$)' && return 0 ;;
    mvn|mvnw|gradle|gradlew) printf '%s' "$rest" | grep -qiE 'gatling' && return 0 ;;
  esac
  return 1
}

# 부하 구간만 모은다 — 파이프로 이어진 명령은 한 덩어리(vegeta 는 앞 단계가 대상을 준다), && · ; 로 나뉜 다른 명령은 뺀다
CMD="$(printf '%s\n' "$CMD" | strip_heredoc)"
LOAD_TXT=""; LOCUST_TXT=""
while IFS= read -r line; do
  [ -n "${line// /}" ] || continue
  hit=0
  while IFS= read -r stage; do
    [ -n "${stage// /}" ] || continue
    is_load_segment "$stage" || continue
    hit=1
    [ "$TOOL" = locust ] && LOCUST_TXT="$LOCUST_TXT
$stage"
  done < <(printf '%s\n' "$line" | tr '|' '\n')
  [ "$hit" = 1 ] && LOAD_TXT="$LOAD_TXT
$line"
done < <(printf '%s\n' "$CMD" | sed -E 's/(\|\||&&|[;&]|\$\(|`)/\n/g')
[ -n "$LOAD_TXT" ] || exit 0

# 대상이 아닌 값을 뺀다 — 출력 대상(--out · -o · > 파일)과 k6 자체 설정(K6_* 대입, -e 로 넘기는 것은 스크립트 변수라 남긴다)
drop_outputs() {
  sed -E 's/[<>]+/ & /g' | awk '
    { out = ""; skip = 0; prev = ""; n = split($0, w, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        t = w[i]; if (t == "") continue
        if (skip) { skip = 0 }
        else if (t ~ /^>+$/ || t == "--out" || t == "-o") skip = 1
        else if (t ~ /^</ || t ~ /^--out=/) ;
        else if (t ~ /^K6_[A-Z0-9_]*=/ && prev != "-e" && prev != "--env") ;
        else out = out " " t
        prev = t
      }
      print out }'
}
LOAD_TXT="$(printf '%s\n' "$LOAD_TXT" | drop_outputs)"
LOCUST_TXT="$(printf '%s\n' "$LOCUST_TXT" | drop_outputs)"

# 대상 호스트를 모은다 — 부하 구간의 URL · --host · locust -H · 참조한 스크립트 파일 안의 URL · JMX 도메인
hosts_from_text() {
  grep -vE '^[[:space:]]*(import|from|require|//|#)|require\(' \
    | sed -E "s/(^|[^[:alnum:]_])from[[:space:]]*['\"][^'\"]*['\"]//g" \
    | grep -oE '[a-zA-Z][a-zA-Z0-9+.-]*://[^][ "'"'"'`<>(){}]+' \
    | sed -E 's#^[^:]+://##; s#^[^@/]*@##; s#[/?\#].*$##; s#:[0-9]+$##' \
    | grep -vE '^$|\$|^__ENV' || true
}
# 스킴 없는 값 → 호스트 (host:port/path · user@host)
bare_host() { sed -E 's/^["'"'"']//; s/["'"'"']$//; s#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@/]*@##; s#[/?\#].*$##; s#:[0-9]+$##' | grep -vE '^$|\$' || true; }
HOSTS="$(printf '%s\n' "$LOAD_TXT" | hosts_from_text)"
# -H 는 locust 에서만 호스트다 (hey · wrk · ab · oha · autocannon 은 헤더)
HOSTS="$HOSTS
$(printf '%s\n' "$LOAD_TXT" | grep -oE '\-\-host[= ][^ ]+' | sed -E 's/^--host[= ]//' | bare_host)
$(printf '%s\n' "$LOCUST_TXT" | grep -oE '(^| )-H [^ ]+' | sed -E 's/^ ?-H //' | bare_host)
$(printf '%s\n' "$LOAD_TXT" | grep -oE '[A-Za-z0-9_]*(URL|HOST|url|host)[A-Za-z0-9_]*=[^ ]+' | sed -E 's/^[^=]+=//' | bare_host)"

FILES=""
for tok in $(printf '%s' "$LOAD_TXT" | tr -s ' \t"'"'"'=<>' '\n\n\n\n\n\n\n'); do
  case "$tok" in *.js|*.ts|*.mjs|*.py|*.jmx|*.yml|*.yaml|*.scala|*.java|*.kt|*.json)
    for p in "$tok" "$BASE/$tok"; do [ -f "$p" ] && { FILES="$FILES
$p"; break; }; done ;;
  esac
done
[ -n "${LOCUST_TXT// /}" ] && { printf '%s' "$LOCUST_TXT" | grep -qE '(-f|--locustfile)[ =]' || { [ -f "$BASE/locustfile.py" ] && FILES="$FILES
$BASE/locustfile.py"; }; }
while IFS= read -r f; do
  [ -n "$f" ] || continue
  HOSTS="$HOSTS
$(hosts_from_text < "$f")"
  case "$f" in *.jmx) HOSTS="$HOSTS
$(grep -oE 'HTTPSampler\.domain">[^<]+' "$f" | sed 's/.*">//' | grep -vE '\$\{' || true)" ;; esac
done <<< "$FILES"

allowed() {
  local h p
  h="$(printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -E 's/^\[//; s/\]$//; s/\.$//')"
  case "$h" in
    localhost|*.localhost|::1|0.0.0.0|host.docker.internal|*.local|*.test|*.internal) return 0 ;;
    127.*|10.*|192.168.*) return 0 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[01].*) return 0 ;;
    *.*|*:*) ;;
    *) return 0 ;;
  esac
  for p in $(printf '%s' "${STRESS_TEST_ALLOWED_HOSTS:-}" | tr ',' ' '); do
    p="$(printf '%s' "$p" | tr 'A-Z' 'a-z')"
    case "$p" in
      \*.*) case "$h" in *"${p#\*}") return 0 ;; esac ;;
      *) [ "$h" = "$p" ] && return 0 ;;
    esac
  done
  return 1
}

BAD=""
while IFS= read -r h; do
  [ -n "$h" ] || continue
  allowed "$h" || case " $BAD " in *" $h "*) ;; *) BAD="$BAD $h" ;; esac
done < <(printf '%s\n' "$HOSTS" | sort -u)

[ -z "$BAD" ] && exit 0
{
  echo "❌ ST-01 부하 대상이 허용 목록 밖이다:$BAD"
  echo "  - 스트레스 테스트는 한계 너머까지 부하를 건다. 운영 · 공용 호스트에 걸면 장애가 된다"
  echo "  - 로컬 · 사설 IP · 컨테이너 이름 · *.local/*.test/*.internal 은 허용된다"
  echo "  - 전용 테스트 환경이 맞으면 STRESS_TEST_ALLOWED_HOSTS 에 넣는다 (.claude/settings.json 의 env, 예: \"staging.example.com,*.perf.example.com\")"
  echo "규칙: $RULES"
} >&2
exit 2
