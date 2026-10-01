#!/usr/bin/env bash
# ST-02 ~ ST-06 — 부하 스크립트(k6 · Gatling · Locust · JMeter)의 측정 설계를 본다. 모두 경고다.
#
#   훅:  PostToolUse(Write|Edit) — 저장된 파일이 부하 스크립트면 additionalContext 로 알린다
#   CLI: stress-script-validate.sh [--strict] [파일|디렉터리 ...]   (기본: 현재 디렉터리)
#        경고가 있어도 exit 0, --strict 면 exit 2
#
# 의도한 closed 모델이면 파일에 `stress-test: closed-model` 주석을 둔다 — ST-02 를 건너뛴다.
set -uo pipefail

RULES="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/references/stress-test-rules.md"
die() { echo "stress-script-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"

# 부하 스크립트 종류 — 아니면 빈 문자열
kind_of() {
  local f="$1"
  case "$f" in
    *.jmx) echo jmeter; return ;;
    *.js|*.mjs|*.ts) grep -qE "from ['\"]k6(/[a-z/-]+)?['\"]|require\(['\"]k6" "$f" 2>/dev/null && echo k6; return ;;
    *.py) grep -qE '^[[:space:]]*(from locust |import locust)' "$f" 2>/dev/null && echo locust; return ;;
    *.scala|*.java|*.kt) grep -qE 'extends Simulation|: Simulation\(\)|Simulation\(\)[[:space:]]*\{' "$f" 2>/dev/null && echo gatling; return ;;
  esac
}

# 파일 하나 → "ST-xx 메시지" 줄들
check_file() {
  local f="$1" k has
  k="$(kind_of "$f")"
  [ -n "$k" ] || return 0
  # 주석을 뺀 본문으로 판정한다
  local body
  body="$(sed -E 's#^[[:space:]]*(//|\#).*$##' "$f")"
  local closed_ok=0
  grep -q 'stress-test: closed-model' "$f" && closed_ok=1
  case "$k" in
    k6)
      if ! printf '%s' "$body" | grep -q 'arrival-rate'; then
        [ "$closed_ok" = 1 ] || echo "ST-02 closed 모델(VU 고정)이다 — 서버가 느려지면 부하도 줄어 꼬리 지연을 과소 측정한다. executor 를 constant-arrival-rate · ramping-arrival-rate 로"
      else
        printf '%s' "$body" | grep -q 'maxVUs' || echo "ST-05 arrival-rate 인데 maxVUs 가 없다 — 기본값이 preAllocatedVUs 라 서버가 느려지면 요청을 못 보내고 dropped_iterations 로 버린다"
        printf '%s' "$body" | grep -qE '(^|[^.a-zA-Z_])sleep\(' && echo "ST-06 arrival-rate 에 sleep() 이 있다 — 도착률은 executor 가 정한다. sleep 은 VU 만 묶어 dropped_iterations 를 늘린다"
      fi
      printf '%s' "$body" | grep -q 'thresholds' || echo "ST-03 thresholds 가 없다 — 합격 기준 없이 돌면 종료 코드가 늘 0 이다. 예: http_req_duration: ['p(99)<300'], http_req_failed: ['rate<0.01']"
      printf '%s' "$body" | grep -q 'p(99' || echo "ST-04 p(99) 가 없다 — k6 기본 요약은 avg,min,med,max,p(90),p(95) 뿐이다. summaryTrendStats 나 thresholds 에 p(99) 를 넣는다"
      ;;
    gatling)
      if printf '%s' "$body" | grep -qE 'constantConcurrentUsers|rampConcurrentUsers|injectClosed'; then
        [ "$closed_ok" = 1 ] || echo "ST-02 closed 주입(동시 사용자 고정)이다 — open 주입(constantUsersPerSec · rampUsersPerSec)으로"
      fi
      printf '%s' "$body" | grep -q 'assertions' || echo "ST-03 assertions 가 없다 — 예: global().responseTime().percentile(99.0).lt(300), global().failedRequests().percent().lt(1.0)"
      ;;
    locust)
      [ "$closed_ok" = 1 ] || echo "ST-02 Locust 사용자는 응답을 받아야 다음 요청을 보내는 closed 루프다 (wait_time 이 constant_throughput 이어도 응답이 늦으면 못 보낸다). 결과에 closed 모델이라고 적고 꼬리 지연은 open 도구로 확인한다"
      ;;
    jmeter)
      [ "$closed_ok" = 1 ] || echo "ST-02 JMeter 스레드 그룹은 closed 루프다 (Throughput Timer 도 응답이 늦으면 못 보낸다). 결과에 closed 모델이라고 적고 꼬리 지연은 open 도구로 확인한다"
      ;;
  esac
}

if [ "$#" -eq 0 ] && [ ! -t 0 ]; then
  INPUT="$(cat)"
  if [ -n "$INPUT" ] && printf '%s' "$INPUT" | jq -e '.hook_event_name' >/dev/null 2>&1; then
    [ "$(printf '%s' "$INPUT" | jq -r '.hook_event_name')" = "PostToolUse" ] || exit 0
    F="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    [ -n "$F" ] && [ -f "$F" ] || exit 0
    OUT="$(check_file "$F")"
    [ -n "$OUT" ] || exit 0
    MSG="부하 스크립트 측정 설계 경고 (common-stress-test) — ${F##*/}
$(printf '%s\n' "$OUT" | sed 's/^/- /')
규칙: $RULES"
    jq -n --arg c "$MSG" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
    exit 0
  fi
fi

STRICT=0
TARGETS=()
for a in "$@"; do
  case "$a" in --strict) STRICT=1 ;; *) TARGETS+=("$a") ;; esac
done
[ "${#TARGETS[@]}" -gt 0 ] || TARGETS=(".")

N=0; W=0
for t in "${TARGETS[@]}"; do
  [ -e "$t" ] || die "없는 경로: $t"
  while IFS= read -r f; do
    [ -n "$(kind_of "$f")" ] || continue
    N=$((N+1))
    OUT="$(check_file "$f")"
    if [ -n "$OUT" ]; then
      echo "⚠️  $f ($(kind_of "$f"))"
      printf '%s\n' "$OUT" | sed 's/^/  - /'
      W=$((W + $(printf '%s\n' "$OUT" | wc -l)))
    fi
  done < <(if [ -d "$t" ]; then find "$t" -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.ts' -o -name '*.py' -o -name '*.jmx' -o -name '*.scala' -o -name '*.java' -o -name '*.kt' \) \
             -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path "${t%/}/.claude/*" -not -path '*/build/*' -not -path '*/target/*' -not -path '*/.venv/*' | sort; else echo "$t"; fi)
done

echo "부하 스크립트 ${N}개, 경고 ${W}건 — 규칙: $RULES"
[ "$STRICT" = 1 ] && [ "$W" -gt 0 ] && exit 2
exit 0
