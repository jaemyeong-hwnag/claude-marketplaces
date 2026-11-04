#!/usr/bin/env bash
# ST-01 — 부하 도구가 겨누는 호스트가 허용 목록 안인지 본다.
#
#   훅:  PreToolUse(Bash) — stdin 의 tool_input.command 를 본다. 위반이면 exit 2 (차단)
#   CLI: stress-target-validate.sh '<명령>'   위반이면 exit 2
#
# 허용: localhost · 루프백 · 사설 IPv4 · IPv6 ::1 · fc00::/7 · fe80::/10 (IP 는 표준 표기 리터럴만) · 점 없는 이름(컨테이너 · 서비스) · *.local · *.localhost · *.test · *.internal
#       · host.docker.internal · $STRESS_TEST_ALLOWED_HOSTS (쉼표 · 공백 구분, *.example.com 형태 허용)
# 종료 코드: 0 통과 / 2 위반 / 1 실행 오류
set -uo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_DIR" ]; then
  SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
  PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
fi
RULES="$PLUGIN_DIR/references/stress-test-rules.md"
# 디렉터리 검증기는 따옴표 안의 꺾쇠 닫기도 리다이렉션으로 읽는다 — 본문에 쓰지 않고 숫자 4 를 바꿔 만든다
GT=$(printf 4 | LC_ALL=C tr 0-9 ':-C')
die() { echo "stress-target-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"

MODE=cli
if [ "$#" -ge 1 ]; then
  CMD="$1"
else
  INPUT=$(cat)
  [ -n "$INPUT" ] || exit 0
  MODE=hook
  EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null)
  [ "$EVENT" = "PreToolUse" ] || exit 0
  TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
  [ "$TOOL_NAME" = "Bash" ] || exit 0
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
fi
[ -n "$CMD" ] || exit 0
BASE="${CWD:-${CLAUDE_PROJECT_DIR:-}}"
[ -n "$BASE" ] || BASE=$(pwd)

# heredoc 본문은 명령이 아니라 데이터라 \002 를 붙여 낸다 (부하 도구에 먹이는 인라인 스크립트면 아래에서 대상으로 본다). 셸에 먹이는 heredoc(sh 에 주는 것)은 명령으로 남긴다
strip_heredoc() {
  awk -v q="'" '
    d != "" { t = $0; if (dash) sub(/^\t+/, "", t); if (t == d) d = ""; else if (keep) print; else print "\002" $0; next }
    { print; s = $0; gsub(/[<][<][<]/, "\001", s)
      if (match(s, "[<][<]-?[ \t]*[\"" q "]?[A-Za-z_][A-Za-z0-9_]*")) {
        d = substr(s, RSTART, RLENGTH); dash = (d ~ /^[<][<]-/)
        sub(/^[<][<]-?[ \t]*/, "", d); gsub("[\"" q "]", "", d)
        keep = (s ~ /(^|[;&|(][ \t]*)(sudo[ \t]+)?(ba|z|da|k)?sh([ \t]+-[A-Za-z]+)*[ \t]*[<][<]/)
      } }'
}

# 부하 도구를 실행하는 구간인가 — 구간의 첫 단어(환경 변수 대입 · 래퍼 제외)나 docker 이미지로 판단한다. 도구 이름은 TOOL, 인자는 ARGS 에 남긴다
is_load_segment() {
  local seg="$1" w first="" rest opts
  TOOL=""; ARGS=""
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
      nice|ionice|stdbuf|xargs|watch|caffeinate)
        # 값을 받는 옵션 — 값까지 건너뛰어야 다음 단어가 실행할 명령이다
        case "$w" in
          nice) opts=" -n --adjustment " ;;
          ionice) opts=" -c -n -p -P -u --class --classdata " ;;
          stdbuf) opts=" -i -o -e --input --output --error " ;;
          xargs) opts=" -n -L -P -I -J -R -S -d -E -s -a " ;;
          watch) opts=" -n --interval " ;;
          caffeinate) opts=" -t -w " ;;
        esac
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -*) case "$opts" in *" $1 "*) shift ;; esac; shift ;;
            *) break ;;
          esac
        done ;;
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
  TOOL="$first"; ARGS="$rest"
  case "$first" in
    k6) case "$rest" in run*|cloud*) return 0 ;; esac ;;
    locust|jmeter|jmeter.sh|gatling|gatling.sh|wrk|wrk2|hey|oha|ab|autocannon|bombardier|siege|h2load|httperf|ghz|plow|drill) return 0 ;;
    fortio) case "$rest" in load*) return 0 ;; esac ;;
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

# 다른 구간의 변수 대입(export BASE_URL=… && k6 run …)은 부하 명령이 읽을 수 있어 남긴다
assignments_of() {
  # shellcheck disable=SC2086
  set -f; set -- $1; set +f
  while [ "$#" -gt 0 ]; do
    case "$1" in
      export|declare|local|readonly|typeset|-*) shift ;;
      [A-Za-z_]*=*) printf '%s\n' "$1"; shift ;;
      *) break ;;
    esac
  done
}

# URL 을 위치 인자로 받는 도구의 스킴 없는 대상(example.com · host:port/path · [v6]:port) — 헤더 · 본문 · 프록시 값과 파일 이름은 뺀다
positional_targets() {
  local t
  set -f
  for t in $(printf '%s\n' "$1" | sed -E "s/(^| )(--call|-H|--header|-d|--body|-b|-D|-T|-A|-C|-m|--method|-x|-X|--proxy|-a|--auth)[ =](\"[^\"]*\"|'[^']*'|[^ ]+)/ /g" | tr -d "\"'"); do
    case "$t" in -*|*=*|*://*) continue ;; esac
    [ -e "$t" ] || [ -e "$BASE/$t" ] && continue
    printf '%s\n' "$t" | grep -E '^(\[[0-9A-Fa-f:.]+\](:[0-9]+)?|([A-Za-z0-9-]+\.)+[A-Za-z][A-Za-z0-9-]*(:[0-9]+)?|[0-9A-Fa-fxX.]+(:[0-9]+|/))(/.*)?$' \
      | grep -vE '^[^:/]*\.(js|ts|mjs|cjs|py|jmx|ya?ml|scala|java|kt|json|txt|csv|lua|log|html|xml|conf|md|sh|proto|tsv|dat|pem|crt|key)$' || true
  done
  set +f
}

# 부하 구간만 모은다 — 파이프로 이어진 명령은 한 덩어리(vegeta 는 앞 단계가 대상을 준다), && · ; 로 나뉜 다른 명령은 뺀다
CMD=$(printf '%s\n' "$CMD" | strip_heredoc)
LOAD_TXT=""; LOCUST_TXT=""; ASSIGN_TXT=""; BODY_TXT=""; BARE_TXT=""; raw_hit=0
while IFS= read -r raw; do
  case "$raw" in
    $'\002'*) [ "$raw_hit" = 1 ] && BODY_TXT="$BODY_TXT
${raw#?}"; continue ;;
  esac
  raw_hit=0
  while IFS= read -r line; do
    [ -n "${line// /}" ] || continue
    hit=0
    while IFS= read -r stage; do
      [ -n "${stage// /}" ] || continue
      is_load_segment "$stage" || continue
      hit=1
      [ "$TOOL" = locust ] && LOCUST_TXT="$LOCUST_TXT
$stage"
      case "$TOOL" in hey|oha|ab|wrk|wrk2|autocannon|bombardier|siege|h2load|ghz|plow|fortio) POSITIONAL=$(positional_targets "$ARGS"); BARE_TXT="$BARE_TXT
$POSITIONAL" ;; esac
    done < <(printf '%s\n' "$line" | tr '|' '\n')
    if [ "$hit" = 1 ]; then
      raw_hit=1
      LOAD_TXT="$LOAD_TXT
$line"
    else
      ASSIGNED=$(assignments_of "$line")
      ASSIGN_TXT="$ASSIGN_TXT
$ASSIGNED"
    fi
  done < <(printf '%s\n' "$raw" | sed -E 's/(\|\||&&|[;&]|\$\(|`)/\n/g')
done < <(printf '%s\n' "$CMD")
[ -n "$LOAD_TXT" ] || exit 0
LOAD_TXT="$LOAD_TXT
$ASSIGN_TXT"

# 대상이 아닌 값을 뺀다 — 출력 대상(--out · -o · > 파일)과 k6 자체 설정(K6_* 대입, -e 로 넘기는 것은 스크립트 변수라 남긴다)
drop_outputs() {
  sed -E "s/[<$GT]+/ & /g" | awk -v gt="$GT" '
    { out = ""; skip = 0; prev = ""; n = split($0, w, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        t = w[i]; if (t == "") continue
        if (skip) { skip = 0 }
        else if (t ~ ("^" gt "+$") || t == "--out" || t == "-o") skip = 1
        else if (t ~ /^</ || t ~ /^--out=/) ;
        else if (t ~ /^K6_[A-Z0-9_]*=/ && prev != "-e" && prev != "--env") ;
        else out = out " " t
        prev = t
      }
      print out }'
}
LOAD_TXT=$(printf '%s\n' "$LOAD_TXT" | drop_outputs)
LOCUST_TXT=$(printf '%s\n' "$LOCUST_TXT" | drop_outputs)

# 대상 호스트를 모은다 — 부하 구간의 URL · --host · locust -H · 참조한 스크립트 파일 안의 URL · JMX 도메인
hosts_from_text() {
  grep -vE '^[[:space:]]*(import|from|require|//|#)|require\(' \
    | sed -E "s/(^|[^[:alnum:]_])from[[:space:]]*['\"][^'\"]*['\"]//g" \
    | grep -oE '[a-zA-Z][a-zA-Z0-9+.-]*://([^][ "'"'"'`<'"$GT"'(){}/@]*@)?(\[[0-9A-Fa-f:.]+\]|[^][ "'"'"'`<'"$GT"'(){}]+)' \
    | sed -E 's#^[^:]+://##; s#^[^@/]*@##; s#[/?\#].*$##; s#^(\[[^]]*\]):[0-9]+$#\1#; s#^([^]:]*):[0-9]+$#\1#' \
    | grep -vE '^$|\$|^__ENV' || true
}
# 스킴 없는 값 → 호스트 (host:port/path · user@host)
bare_host() { sed -E 's/^["'"'"']//; s/["'"'"']$//; s#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@/]*@##; s#[/?\#].*$##; s#^(\[[^]]*\]):[0-9]+$#\1#; s#^([^]:]*):[0-9]+$#\1#' | grep -vE '^$|\$' || true; }
# 스크립트 파일 — 줄 끝 주석(앞이 공백인 // · #)을 지운다. URL 의 :// 와 #fragment 는 앞이 공백이 아니라 남는다
strip_comments() { sed -E 's/[[:space:]]+(\/\/|#).*$//'; }
# k6 의 __ENV.BASE_URL || 'host' 기본값 — 스킴 없이 쓰면 URL 검사에 안 걸린다
env_defaults() { strip_comments | grep -vE '^[[:space:]]*(//|#)' | grep -oE '__ENV\.[A-Za-z0-9_]*(URL|HOST|url|host)[A-Za-z0-9_]*[[:space:]]*(\|\||\?\?)[[:space:]]*['"'"'"`][^'"'"'"`]+' | sed -E 's/^[^|?]*(\|\||\?\?)[[:space:]]*.//' | bare_host; }
H_LOAD=$(printf '%s\n' "$LOAD_TXT" | hosts_from_text)
H_BODY=$(printf '%s\n' "$BODY_TXT" | strip_comments | hosts_from_text)
H_BODY_ENV=$(printf '%s\n' "$BODY_TXT" | env_defaults)
HOSTS="$H_LOAD
$H_BODY
$H_BODY_ENV"
# -H 는 locust 에서만 호스트다 (hey · wrk · ab · oha · autocannon 은 헤더)
H_FLAG=$(printf '%s\n' "$LOAD_TXT" | grep -oE '\-\-(host|server)[= ][^ ]+' | sed -E 's/^--(host|server)[= ]//' | bare_host)
H_BARE=$(printf '%s\n' "$BARE_TXT" | bare_host)
H_LOCUST=$(printf '%s\n' "$LOCUST_TXT" | grep -oE '(^| )-H [^ ]+' | sed -E 's/^ ?-H //' | bare_host)
H_ASSIGN=$(printf '%s\n' "$LOAD_TXT" | grep -oE '[A-Za-z0-9_]*(URL|HOST|url|host)[A-Za-z0-9_]*=[^ ]+' | sed -E 's/^[^=]+=//' | bare_host)
HOSTS="$HOSTS
$H_FLAG
$H_BARE
$H_LOCUST
$H_ASSIGN"

FILES=""
for tok in $(printf '%s' "$LOAD_TXT" | tr -s ' \t"'"'"'=<'"$GT" '\n\n\n\n\n\n\n'); do
  case "$tok" in *.js|*.ts|*.mjs|*.py|*.jmx|*.yml|*.yaml|*.scala|*.java|*.kt|*.json|*.txt)
    for p in "$tok" "$BASE/$tok"; do [ -f "$p" ] && { FILES="$FILES
$p"; break; }; done ;;
  esac
done
[ -n "${LOCUST_TXT// /}" ] && { printf '%s' "$LOCUST_TXT" | grep -qE '(-f|--locustfile)[ =]' || { [ -f "$BASE/locustfile.py" ] && FILES="$FILES
$BASE/locustfile.py"; }; }
OLD_IFS="$IFS"; set -f; IFS='
'
FILE_LIST=($FILES)
IFS="$OLD_IFS"; set +f
for f in ${FILE_LIST+"${FILE_LIST[@]}"}; do
  [ -n "$f" ] || continue
  H_FILE=$(strip_comments < "$f" | hosts_from_text)
  H_FILE_ENV=$(env_defaults < "$f")
  HOSTS="$HOSTS
$H_FILE
$H_FILE_ENV"
  case "$f" in *.jmx)
    H_JMX=$(grep -oE 'HTTPSampler\.domain"'"$GT"'[^<]+' "$f" | sed 's/.*"'"$GT"'//' | grep -vE '\$\{' || true)
    HOSTS="$HOSTS
$H_JMX" ;; esac
done

# 표준 표기(점 넷 · 0~255 · 앞 0 없음) IPv4 가 루프백 · 사설 · 0.0.0.0 인가
private_ipv4() {
  local a b c d r
  printf '%s' "$1" | grep -qE '^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}$' || return 1
  a="${1%%.*}"; r="${1#*.}"; b="${r%%.*}"; r="${r#*.}"; c="${r%%.*}"; d="${r#*.}"
  [ "$a" -le 255 ] && [ "$b" -le 255 ] && [ "$c" -le 255 ] && [ "$d" -le 255 ] || return 1
  [ "$a" = 127 ] || [ "$a" = 10 ] || [ "$1" = 0.0.0.0 ] || { [ "$a" = 192 ] && [ "$b" = 168 ]; } \
    || { [ "$a" = 172 ] && [ "$b" -ge 16 ] && [ "$b" -le 31 ]; }
}

allowed() {
  local h p
  h=$(printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -E 's/^\[//; s/\]$//; s/\.$//')
  case "$h" in
    localhost|*.localhost|host.docker.internal|*.local|*.test|*.internal) return 0 ;;
    # IPv6 — ::1 · fc00::/7 · fe80::/10 만 사설이다
    *:*) case "$h" in ::1|f[cd][0-9a-f][0-9a-f]:*|fe[89ab][0-9a-f]:*) return 0 ;; esac ;;
    # 숫자 · 16진만으로 된 이름은 IPv4 다. 정수(167772161) · 16진 · 8진 · 줄인 표기는 도구마다 해석이 달라 사설로 보지 않는다
    *)
      if printf '%s' "$h" | grep -qE '^(0x[0-9a-f]*|[0-9]+)(\.(0x[0-9a-f]*|[0-9]+))*$'; then
        private_ipv4 "$h" && return 0
      else
        case "$h" in *.*) ;; *) return 0 ;; esac
      fi ;;
  esac
  for p in $(printf '%s' "${STRESS_TEST_ALLOWED_HOSTS:-}" | tr ',' ' '); do
    p=$(printf '%s' "$p" | tr 'A-Z' 'a-z')
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
