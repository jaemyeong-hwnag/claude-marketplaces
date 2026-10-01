#!/usr/bin/env bash
# 단계 CSV(stress-step-generate.sh 출력)를 판정한다 — 단계별 SLO · 지속 가능 용량 · knee · USL · Little 정합성.
#
#   stress-report-generate.sh [옵션] <steps.csv>
#     --model open|closed     load 의 뜻. open = 목표 도착률(rps), closed = 동시 사용자 수 (기본 open)
#     --slo-p99 <ms>          단계 합격 기준 p99 (없으면 p99 판정 생략)
#     --slo-error <비율>       단계 합격 기준 에러율 (기본 0.01)
#     --sustain <비율>         open 모델에서 처리량 ≥ 목표 × 비율이어야 부하를 견딘 것 (기본 0.95)
#     --think-ms <ms>         closed 모델 think time — Little 검사에 쓴다 (기본 0)
#     --little-tolerance <비율> Little 불일치 경고 폭 (기본 0.1)
#     --target <load>         이 부하 단계가 합격해야 exit 0. 아니면 exit 2
# 열 이름으로 읽는다: load,throughput 는 필수. avg_ms,p50_ms,p95_ms,p99_ms,max_ms,error_rate,dropped,inflight 는 있으면 쓴다.
# 종료 코드: 0 통과(또는 --target 없음) / 2 --target 단계 불합격 / 1 오류
set -uo pipefail

RULES="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/references/stress-test-rules.md"
die() { echo "stress-report-generate: $*" >&2; exit 1; }

MODEL=open; SLO_P99=""; SLO_ERR=0.01; SUSTAIN=0.95; THINK=0; LTOL=0.1; TARGET=""; FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift 2 ;;
    --slo-p99) SLO_P99="${2:-}"; shift 2 ;;
    --slo-error) SLO_ERR="${2:-}"; shift 2 ;;
    --sustain) SUSTAIN="${2:-}"; shift 2 ;;
    --think-ms) THINK="${2:-}"; shift 2 ;;
    --little-tolerance) LTOL="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    -*) die "모르는 옵션: $1" ;;
    *) FILE="$1"; shift ;;
  esac
done
case "$MODEL" in open|closed) ;; *) die "--model 은 open 또는 closed" ;; esac
[ -n "$FILE" ] && [ -r "$FILE" ] || die "단계 CSV 를 읽을 수 없다: ${FILE:-없음}"

awk -F, -v model="$MODEL" -v slo_p99="$SLO_P99" -v slo_err="$SLO_ERR" -v sustain="$SUSTAIN" \
    -v think="$THINK" -v ltol="$LTOL" -v target="$TARGET" -v rules="$RULES" '
function has(c, i) { return (c in col) && $col[c] != "" }
function get(c) { return (c in col) ? $col[c] : "" }
function f(x, d) { return x == "" ? "-" : sprintf("%." d "f", x) }
function abs(x) { return x < 0 ? -x : x }
# Kneedle (Satopaa 2011) 오프라인 — 정규화한 차이 곡선의 최대점. concave=1 이면 증가 후 꺾이는 곡선(처리량), 0 이면 볼록 곡선(지연)
function kneedle(xs, ys, n, concave,    i, xmin, xmax, ymin, ymax, d, best, bi) {
  xmin = xs[1]; xmax = xs[n]; ymin = ys[1]; ymax = ys[1]
  for (i = 1; i <= n; i++) { if (ys[i] < ymin) ymin = ys[i]; if (ys[i] > ymax) ymax = ys[i] }
  if (xmax == xmin || ymax == ymin) return 0
  best = -1; bi = 0
  for (i = 1; i <= n; i++) {
    xn = (xs[i] - xmin) / (xmax - xmin); yn = (ys[i] - ymin) / (ymax - ymin)
    d = concave ? yn - xn : xn - yn
    if (d > best) { best = d; bi = i }
  }
  if (best <= 0 || bi == n || bi == 1) return 0
  return bi
}
function usl_sse(a, b, x1,    i, N, p, s) {
  s = 0
  for (i = 1; i <= n; i++) { N = L[i]; p = x1 * N / (1 + a * (N - 1) + b * N * (N - 1)); s += (X[i] - p)^2 }
  return s
}
NR == 1 {
  for (i = 1; i <= NF; i++) { gsub(/^[ \t"]+|[ \t"\r]+$/, "", $i); col[$i] = i }
  if (!("load" in col) || !("throughput" in col)) { print "stress-report-generate: load,throughput 열이 필요하다" > "/dev/stderr"; bad = 1; exit 1 }
  next
}
{
  for (i = 1; i <= NF; i++) gsub(/^[ \t"]+|[ \t"\r]+$/, "", $i)
  if ($col["load"] == "" || $col["throughput"] == "") next
  n++
  L[n] = $col["load"] + 0; X[n] = $col["throughput"] + 0
  A[n] = get("avg_ms"); P50[n] = get("p50_ms"); P95[n] = get("p95_ms"); P99[n] = get("p99_ms"); MX[n] = get("max_ms")
  E[n] = get("error_rate"); D[n] = get("dropped"); IN[n] = get("inflight")
}
END {
  if (bad) exit 1
  if (n == 0) { print "stress-report-generate: 단계가 없다" > "/dev/stderr"; exit 1 }
  # load 오름차순 정렬
  for (i = 2; i <= n; i++) for (j = i; j > 1 && L[j-1] > L[j]; j--) {
    t=L[j];L[j]=L[j-1];L[j-1]=t; t=X[j];X[j]=X[j-1];X[j-1]=t; t=A[j];A[j]=A[j-1];A[j-1]=t
    t=P50[j];P50[j]=P50[j-1];P50[j-1]=t; t=P95[j];P95[j]=P95[j-1];P95[j-1]=t; t=P99[j];P99[j]=P99[j-1];P99[j-1]=t
    t=MX[j];MX[j]=MX[j-1];MX[j-1]=t; t=E[j];E[j]=E[j-1];E[j-1]=t; t=D[j];D[j]=D[j-1];D[j-1]=t; t=IN[j];IN[j]=IN[j-1];IN[j-1]=t
  }
  nw = 0
  printf "# 스트레스 테스트 판정 (%s 모델, 단계 %d개)\n\n", model, n
  printf "기준: p99 %s · 에러율 < %s%s\n\n", (slo_p99 == "" ? "미지정" : "< " slo_p99 " ms"), slo_err, (model == "open" ? " · 처리량 ≥ 목표 × " sustain : "")
  printf "| load | 처리량 | avg | p50 | p95 | p99 | max | 에러율 | dropped | 판정 |\n|---|---|---|---|---|---|---|---|---|---|\n"
  cap = ""; allok = 1; tgt_found = 0; tgt_ok = 0; p99miss = 0
  for (i = 1; i <= n; i++) {
    why = ""
    if (slo_p99 != "") { if (P99[i] == "") p99miss = 1; else if (P99[i] + 0 >= slo_p99 + 0) why = why " p99✗" }
    if (E[i] != "" && E[i] + 0 >= slo_err + 0) why = why " 에러✗"
    if (model == "open" && X[i] < L[i] * sustain) why = why " 미달✗"
    if (D[i] != "" && D[i] + 0 > 0) why = why " dropped✗"
    ok = (why == "")
    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", L[i], f(X[i], 1), f(A[i], 1), f(P50[i], 1), f(P95[i], 1), f(P99[i], 1), f(MX[i], 1), (E[i] == "" ? "-" : sprintf("%.4f", E[i])), (D[i] == "" ? "-" : D[i]), (ok ? "✅" : "❌" why)
    if (ok && allok) cap = L[i]; else allok = 0
    if (target != "" && L[i] + 0 == target + 0) { tgt_found = 1; tgt_ok = ok }
  }
  printf "\n## 지속 가능 용량\n\n"
  if (cap == "") printf "- 첫 단계부터 불합격이다 — 부하를 낮춰 다시 잰다\n"
  else printf "- **%s** (%s) — 이 단계와 그 아래 모든 단계가 합격한 최대 부하\n", cap, (model == "open" ? "rps" : "동시 사용자")
  if (cap != "" && cap == L[n]) printf "- 마지막 단계까지 합격했다 — 한계를 찾으려면 부하를 더 올린다\n"

  printf "\n## knee (Kneedle)\n\n"
  if (n < 6) { printf "- 단계가 %d개라 계산하지 않는다 (ST-11: 6단계 이상)\n", n; warn[++nw] = "ST-11 단계가 6개 미만이다 — knee · USL 을 계산하지 않았다" }
  else {
    for (i = 1; i <= n; i++) { xs[i] = L[i]; ys[i] = X[i] }
    k = kneedle(xs, ys, n, 1)
    if (k) printf "- 처리량 곡선의 knee: load **%s** (처리량 %s)\n", L[k], f(X[k], 1); else printf "- 처리량 곡선에 knee 가 없다 (측정 범위 안에서 꺾이지 않음)\n"
    m = 0; for (i = 1; i <= n; i++) if (P99[i] != "") { m++; xs[m] = L[i]; ys[m] = P99[i] + 0 }
    if (m >= 6) { k = kneedle(xs, ys, m, 0); if (k) printf "- p99 곡선의 knee: load **%s** (p99 %s ms)\n", xs[k], f(ys[k], 1); else printf "- p99 곡선에 knee 가 없다\n" }
    printf "- knee 는 효율이 꺾이는 점이다. 운영 상한은 SLO 를 넘지 않는 지속 가능 용량과 같이 본다\n"
  }

  if (model == "closed" && n >= 6) {
    printf "\n## USL (closed 모델)\n\n"
    # X(1) — N=1 이 없으면 가장 작은 N 의 처리량을 N 으로 나눠 추정한다
    x1 = (L[1] == 1) ? X[1] : X[1] / L[1]
    suu = suv = svv = suy = svy = 0
    for (i = 1; i <= n; i++) {
      N = L[i]; if (N <= 0 || X[i] <= 0) continue
      y = N / (X[i] / x1) - 1; u = N - 1; v = N * (N - 1)
      suu += u*u; suv += u*v; svv += v*v; suy += u*y; svy += v*y
    }
    det = suu * svv - suv * suv
    if (det == 0) printf "- 피팅할 수 없다 (N 이 서로 달라야 한다)\n"
    else {
      a = (suy * svv - svy * suv) / det; b = (suu * svy - suv * suy) / det
      if (a < 0) { a = 0; b = (svv > 0) ? svy / svv : 0 }
      if (b < 0) { b = 0; a = (suu > 0) ? suy / suu : 0 }
      if (a < 0) a = 0
      # 선형화는 큰 N 의 오차를 키운다 — 처리량 공간의 제곱오차로 다듬는다 (α, β ≥ 0 패턴 탐색)
      ssr = usl_sse(a, b, x1); sa = (a > 0 ? a : 0.01) / 2; sb = (b > 0 ? b : 0.0001) / 2
      for (it = 0; it < 200 && (sa > 1e-9 || sb > 1e-12); it++) {
        moved = 0
        for (dir = -1; dir <= 1; dir += 2) {
          na = a + dir * sa; if (na >= 0 && (s = usl_sse(na, b, x1)) < ssr) { a = na; ssr = s; moved = 1 }
          nb = b + dir * sb; if (nb >= 0 && (s = usl_sse(a, nb, x1)) < ssr) { b = nb; ssr = s; moved = 1 }
        }
        if (!moved) { sa /= 2; sb /= 2 }
      }
      sst = mean = 0
      for (i = 1; i <= n; i++) mean += X[i]; mean /= n
      for (i = 1; i <= n; i++) sst += (X[i] - mean)^2
      r2 = (sst > 0) ? 1 - ssr / sst : 0
      printf "- α(경합) = %.5f · β(일관성) = %.6f · γ = X(1) = %.2f%s · R² = %.3f\n", a, b, x1, (L[1] == 1 ? "" : " (N=" L[1] " 에서 추정)"), r2
      if (b > 0) { nmax = sqrt((1 - a) / b); printf "- N_max = √((1−α)/β) = **%.1f** — 이 동시성을 넘으면 처리량이 줄어든다\n", nmax; printf "- 예측 최대 처리량 %.1f\n", x1 * nmax / (1 + a * (nmax - 1) + b * nmax * (nmax - 1)) }
      else if (a > 0) printf "- β = 0 — Amdahl 형태. 처리량 상한 ≈ X(1)/α = %.1f\n", x1 / a
      else printf "- α = β = 0 — 측정 범위 안에서 선형 확장\n"
      if (r2 < 0.9) { printf "- R² 가 낮다 — 단계가 정상 상태가 아니었거나 모델과 다른 병목(고정 상한 등)이다\n"; warn[++nw] = "USL 적합도가 낮다 (R² " sprintf("%.3f", r2) ")" }
    }
  }

  lc = 0
  for (i = 1; i <= n; i++) if (A[i] != "" && (model == "closed" || IN[i] != "")) lc++
  if (lc > 0) {
    printf "\n## Little (L = λW)\n\n| load | 측정 L | λ·W | 비율 |\n|---|---|---|---|\n"
    for (i = 1; i <= n; i++) {
      if (A[i] == "") continue
      if (model == "closed") { Lm = L[i]; Lp = X[i] * (A[i] + think) / 1000 }
      else { if (IN[i] == "") continue; Lm = IN[i] + 0; Lp = X[i] * A[i] / 1000 }
      # 측정 L 이 0 인데 λW 가 있으면 게이지가 대기 요청을 못 보는 것이다 — 가장 큰 불일치로 센다
      if (Lm > 0) { r = Lp / Lm; printf "| %s | %.2f | %.2f | %.2f |\n", L[i], Lm, Lp, r; if (abs(r - 1) > ltol) bad_l++ }
      else { printf "| %s | %.2f | %.2f | ∞ |\n", L[i], Lm, Lp; if (Lp > 0) bad_l++ }
    }
    if (bad_l) { printf "\n- %d 단계가 ±%s 를 벗어난다 — 측정 경계가 다르다 (큐 대기 · 실패 요청 · 램프 구간이 섞였는지 본다)\n", bad_l, ltol; warn[++nw] = "ST-13 Little 불일치 " bad_l "단계" }
  }

  for (i = 1; i <= n; i++) if (D[i] != "" && D[i] + 0 > 0) { warn[++nw] = "ST-12 load " L[i] " 에서 dropped " D[i] " — 부하기가 목표 도착률을 못 냈다. 이 단계의 지연은 과소 측정이다"; }
  if (p99miss) warn[++nw] = "ST-04 p99 가 없는 단계가 있다"
  if (nw) { printf "\n## 경고\n\n"; for (i = 1; i <= nw; i++) printf "- %s\n", warn[i] }
  printf "\n규칙: %s\n", rules
  if (target != "") {
    if (!tgt_found) { printf "\n❌ --target %s 단계가 CSV 에 없다\n", target; exit 1 }
    if (!tgt_ok) { printf "\n❌ 목표 부하 %s 불합격\n", target; exit 2 }
    printf "\n✅ 목표 부하 %s 합격\n", target
  }
}' "$FILE"
