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

# 부하 도구를 실행하는 구간인가 — 구간의 첫 단어(환경 변수 대입 · 래퍼 제외)나 docker 이미지로 판단한다
is_load_segment() {
  local seg="$1" w first="" rest
  # shellcheck disable=SC2086
  set -f; set -- $seg; set +f
  while [ "$#" -gt 0 ]; do
    w="$1"
    case "$w" in
      *=*|sudo|time|nohup|exec|command|env|npx|bunx|pnpx|-*) shift ;;
      *) first="$w"; shift; break ;;
    esac
  done
  rest="$*"
  first="${first##*/}"
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

LOAD=0
while IFS= read -r seg; do
  [ -n "${seg// /}" ] || continue
  is_load_segment "$seg" && { LOAD=1; break; }
done < <(printf '%s\n' "$CMD" | sed -E 's/(\|\||&&|[;|&]|\$\(|`)/\n/g')
[ "$LOAD" = 1 ] || exit 0

# 대상 호스트를 모은다 — 명령 안의 URL · --host · 참조한 스크립트 파일 안의 URL · JMX 도메인
hosts_from_text() {
  grep -vE '^[[:space:]]*(import|from|require|//|#)|require\(' \
    | grep -oE '[a-zA-Z][a-zA-Z0-9+.-]*://[^][ "'"'"'`<>(){}]+' \
    | sed -E 's#^[^:]+://##; s#^[^@/]*@##; s#[/?\#].*$##; s#:[0-9]+$##' \
    | grep -vE '^$|\$|^__ENV' || true
}
# 스킴 없는 값 → 호스트 (host:port/path · user@host)
bare_host() { sed -E 's/^["'"'"']//; s/["'"'"']$//; s#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@/]*@##; s#[/?\#].*$##; s#:[0-9]+$##' | grep -vE '^$|\$' || true; }
HOSTS="$(printf '%s\n' "$CMD" | hosts_from_text)"
HOSTS="$HOSTS
$(printf '%s\n' "$CMD" | grep -oE '(--host[= ]|-H )[^ ]+' | sed -E 's/^(--host[= ]|-H )//' | bare_host)
$(printf '%s\n' "$CMD" | grep -oE '[A-Za-z0-9_]*(URL|HOST|url|host)[A-Za-z0-9_]*=[^ ]+' | sed -E 's/^[^=]+=//' | bare_host)"

FILES=""
for tok in $(printf '%s' "$CMD" | tr -s ' \t"'"'"'=' '\n\n\n\n'); do
  case "$tok" in *.js|*.ts|*.mjs|*.py|*.jmx|*.yml|*.yaml|*.scala|*.java|*.kt|*.json)
    for p in "$tok" "$BASE/$tok"; do [ -f "$p" ] && { FILES="$FILES
$p"; break; }; done ;;
  esac
done
case "$CMD" in *locust*) printf '%s' "$CMD" | grep -qE '(-f|--locustfile)[ =]' || { [ -f "$BASE/locustfile.py" ] && FILES="$FILES
$BASE/locustfile.py"; } ;; esac
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
