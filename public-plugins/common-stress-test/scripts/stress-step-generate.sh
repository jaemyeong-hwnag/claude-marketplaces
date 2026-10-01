#!/usr/bin/env bash
# 부하 도구 결과 파일 하나를 단계 CSV 한 줄로 바꾼다 — stress-report-generate.sh 의 입력.
#
#   stress-step-generate.sh --header
#   stress-step-generate.sh --load <목표 부하> [--tool k6|locust|jmeter|gatling] [--inflight <서버 평균 in-flight>] <결과 파일>
#
# 결과 파일
#   k6       --summary-export JSON, 또는 handleSummary 의 JSON(data)
#   locust   --csv 접두어_stats.csv (Aggregated 줄)
#   jmeter   -e -o 보고서의 statistics.json (Total). pct2 · pct3 가 95 · 99 인 기본 설정을 가정한다
#   gatling  콘솔 출력을 저장한 텍스트 ("Global Information" 블록) — 3.x 전 버전
# 종료 코드: 0 성공 / 1 오류
set -uo pipefail

COLS="load,throughput,avg_ms,p50_ms,p95_ms,p99_ms,max_ms,error_rate,dropped,inflight"
die() { echo "stress-step-generate: $*" >&2; exit 1; }

LOAD=""; TOOL=""; INFLIGHT=""; FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --header) echo "$COLS"; exit 0 ;;
    --load) LOAD="${2:-}"; shift 2 ;;
    --tool) TOOL="${2:-}"; shift 2 ;;
    --inflight) INFLIGHT="${2:-}"; shift 2 ;;
    -*) die "모르는 옵션: $1" ;;
    *) FILE="$1"; shift ;;
  esac
done
[ -n "$LOAD" ] || die "--load 가 필요하다 (open 모델이면 목표 rps, closed 모델이면 동시 사용자 수)"
[ -n "$FILE" ] && [ -r "$FILE" ] || die "결과 파일을 읽을 수 없다: ${FILE:-없음}"

if [ -z "$TOOL" ]; then
  case "$FILE" in
    *.csv) TOOL=locust ;;
    *.json)
      if jq -e '.metrics.http_reqs' "$FILE" >/dev/null 2>&1; then TOOL=k6
      elif jq -e '.Total.throughput' "$FILE" >/dev/null 2>&1; then TOOL=jmeter
      else die "JSON 형식을 모른다 — --tool 로 지정한다"; fi ;;
    *) grep -q 'Global Information' "$FILE" && TOOL=gatling || die "형식을 모른다 — --tool 로 지정한다" ;;
  esac
fi

num() { printf '%s' "${1:-}" | grep -qE '^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$' && printf '%s' "$1" || printf ''; }

case "$TOOL" in
  k6)
    command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"
    # summary-export 는 값이 지표 바로 아래, handleSummary 는 .values 아래에 있다
    ROW="$(jq -r '
      def v($m): (.metrics[$m].values // .metrics[$m]);
      [ (v("http_reqs").rate),
        (v("http_req_duration").avg),
        (v("http_req_duration")["p(50)"] // v("http_req_duration").med),
        (v("http_req_duration")["p(95)"]),
        (v("http_req_duration")["p(99)"]),
        (v("http_req_duration").max),
        (v("http_req_failed").rate // v("http_req_failed").value),
        ((v("dropped_iterations").count) // 0)
      ] | map(if . == null then "" else tostring end) | join(",")' "$FILE")" || die "k6 JSON 을 읽지 못했다"
    ;;
  locust)
    ROW="$(awk -F, '
      NR==1 { for (i=1;i<=NF;i++) h[$i]=i; next }
      $2=="Aggregated" {
        n=$h["Request Count"]; f=$h["Failure Count"]
        printf "%s,%s,%s,%s,%s,%s,%s,", $h["Requests/s"], $h["Average Response Time"], $h["50%"], $h["95%"], $h["99%"], $h["Max Response Time"], (n>0 ? f/n : 0)
        found=1
      }
      END { if (!found) exit 3 }' "$FILE")" || die "Locust stats.csv 에 Aggregated 줄이 없다"
    ;;
  jmeter)
    command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"
    ROW="$(jq -r '.Total | [ .throughput, .meanResTime, .medianResTime, .pct2ResTime, .pct3ResTime, .maxResTime, (.errorPct / 100), "" ]
      | map(if . == null then "" else tostring end) | join(",")' "$FILE")" || die "JMeter statistics.json 을 읽지 못했다"
    ;;
  gatling)
    # 3.2 형식 "> 이름   12 (OK=12 KO=-)" 와 3.16 형식 "> 이름 (ms) | 12 | 12 | -" 를 같이 읽는다 — 이름 뒤 숫자들을 순서대로 뽑는다
    g() { awk -v k="$1" '/Global Information/ { on=1 } on && index($0, k) { s=substr($0, index($0, k) + length(k)); gsub(/\((ms|rps)\)/, "", s); gsub(/[A-Za-z=()|]/, " ", s); print s; exit }' "$FILE"; }
    nth() { printf '%s' "$1" | tr -s ' ' '\n' | grep -v '^$' | sed -n "${2}p" | sed 's/^-$/0/'; }
    C="$(g 'request count')"
    [ -n "$C" ] || die "Gatling 출력에 Global Information 블록이 없다"
    TOTAL="$(nth "$C" 1)"; KO="$(nth "$C" 3)"
    THR="$(g 'mean throughput')"; [ -n "$THR" ] || THR="$(g 'mean requests/sec')"
    ERR="$(awk -v t="${TOTAL:-0}" -v k="${KO:-0}" 'BEGIN { if (t>0) print k/t; else print "" }')"
    ROW="$(nth "$THR" 1),$(nth "$(g 'mean response time')" 1),$(nth "$(g '50th percentile')" 1),$(nth "$(g '95th percentile')" 1),$(nth "$(g '99th percentile')" 1),$(nth "$(g 'max response time')" 1),$ERR,"
    ;;
  *) die "모르는 도구: $TOOL" ;;
esac

IFS=, read -r THR AVG P50 P95 P99 MAX ERR DROP <<< "$ROW"
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(num "$LOAD")" "$(num "$THR")" "$(num "$AVG")" "$(num "$P50")" "$(num "$P95")" "$(num "$P99")" "$(num "$MAX")" "$(num "$ERR")" "$(num "$DROP")" "$(num "$INFLIGHT")"
