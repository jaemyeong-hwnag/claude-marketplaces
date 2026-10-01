#!/usr/bin/env bash
# ST-20 — 기준(baseline)과 후보(candidate)의 반복 측정값을 비교해 성능 회귀를 판정한다.
#
#   stress-regression-validate.sh [--higher-is-better] [--alpha 0.05] [--min-effect 0.147] <baseline> <candidate>
#     파일마다 한 줄에 값 하나 (실행 한 번의 p99 · 처리량 등). 빈 줄 · # 주석은 건너뛴다
#     기본은 값이 작을수록 좋다 (지연). 처리량이면 --higher-is-better
#
# 판정: Mann-Whitney U 양측 p < alpha 이고 |Cliff's delta| ≥ min-effect 이고 나빠진 방향이면 회귀
#       p 는 동률이 없고 n1+n2 ≤ 40 이면 정확 분포, 아니면 동률 보정 정규 근사(연속성 보정)
# 종료 코드: 0 회귀 아님 / 2 회귀 / 1 오류 (표본 5개 미만 포함)
set -uo pipefail

RULES="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/references/stress-test-rules.md"
die() { echo "stress-regression-validate: $*" >&2; exit 1; }

HIB=0; ALPHA=0.05; MINEFF=0.147; FILES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --higher-is-better) HIB=1; shift ;;
    --alpha) ALPHA="${2:-}"; shift 2 ;;
    --min-effect) MINEFF="${2:-}"; shift 2 ;;
    -*) die "모르는 옵션: $1" ;;
    *) FILES+=("$1"); shift ;;
  esac
done
[ "${#FILES[@]}" = 2 ] || die "사용법: stress-regression-validate.sh [옵션] <baseline> <candidate>"
for f in "${FILES[@]}"; do [ -r "$f" ] || die "읽을 수 없다: $f"; done

awk -v hib="$HIB" -v alpha="$ALPHA" -v mineff="$MINEFF" -v rules="$RULES" '
function norm_cdf(z,    t, y, s) {
  # Abramowitz-Stegun 7.1.26 (오차 < 1.5e-7)
  s = (z < 0) ? -1 : 1; z = (z < 0 ? -z : z) / sqrt(2)
  t = 1 / (1 + 0.3275911 * z)
  y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z)
  return 0.5 * (1 + s * y)
}
function median(arr, m,    i, j, t, c) {
  for (i = 1; i <= m; i++) c[i] = arr[i]
  for (i = 2; i <= m; i++) for (j = i; j > 1 && c[j-1] > c[j]; j--) { t = c[j]; c[j] = c[j-1]; c[j-1] = t }
  return (m % 2) ? c[(m + 1) / 2] : (c[m / 2] + c[m / 2 + 1]) / 2
}
FNR == 1 { fi++ }
/^[ \t]*(#|$)/ { next }
{
  v = $1
  if (v !~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) { printf "stress-regression-validate: 숫자가 아니다 (%s:%d): %s\n", FILENAME, FNR, v > "/dev/stderr"; bad = 1; exit 1 }
  if (fi == 1) a[++n1] = v + 0; else b[++n2] = v + 0
}
END {
  if (bad) exit 1
  if (n1 < 5 || n2 < 5) { printf "stress-regression-validate: 표본이 각각 5개 이상이어야 한다 (기준 %d · 후보 %d)\n", n1, n2 > "/dev/stderr"; exit 1 }
  # 순위 (동률은 평균 순위)
  N = n1 + n2
  for (i = 1; i <= n1; i++) { val[i] = a[i]; grp[i] = 1 }
  for (i = 1; i <= n2; i++) { val[n1 + i] = b[i]; grp[n1 + i] = 2 }
  for (i = 1; i <= N; i++) idx[i] = i
  for (i = 2; i <= N; i++) for (j = i; j > 1 && val[idx[j-1]] > val[idx[j]]; j--) { t = idx[j]; idx[j] = idx[j-1]; idx[j-1] = t }
  ties = 0; tsum = 0; i = 1
  while (i <= N) {
    j = i; while (j < N && val[idx[j+1]] == val[idx[i]]) j++
    r = (i + j) / 2; for (k = i; k <= j; k++) rank[idx[k]] = r
    c = j - i + 1; if (c > 1) { ties = 1; tsum += c^3 - c }
    i = j + 1
  }
  R1 = 0; for (i = 1; i <= n1; i++) R1 += rank[i]
  U1 = R1 - n1 * (n1 + 1) / 2; U2 = n1 * n2 - U1
  # Cliff delta = P(후보 > 기준) - P(후보 < 기준)
  gt = lt = 0
  for (i = 1; i <= n1; i++) for (j = 1; j <= n2; j++) { if (b[j] > a[i]) gt++; else if (b[j] < a[i]) lt++ }
  d = (gt - lt) / (n1 * n2)
  if (!ties && N <= 40) {
    # 정확 분포 — cnt[u] = U 가 u 가 되는 배열 수 (동적 계획법)
    method = "정확"
    for (i = 0; i <= n1; i++) for (j = 0; j <= n2; j++) for (u = 0; u <= i * j; u++) f[i, j, u] = 0
    for (j = 0; j <= n2; j++) f[0, j, 0] = 1
    for (i = 1; i <= n1; i++) { f[i, 0, 0] = 1; for (j = 1; j <= n2; j++) for (u = 0; u <= i * j; u++) f[i, j, u] = ((u - j >= 0) ? f[i - 1, j, u - j] : 0) + ((u <= i * (j - 1)) ? f[i, j - 1, u] : 0) }
    tot = 0; for (u = 0; u <= n1 * n2; u++) tot += f[n1, n2, u]
    um = (U1 < U2) ? U1 : U2; lo = 0; for (u = 0; u <= um; u++) lo += f[n1, n2, u]
    p = 2 * lo / tot; if (p > 1) p = 1
  } else {
    method = "정규 근사"
    mu = n1 * n2 / 2
    sd = sqrt(n1 * n2 / 12 * ((N + 1) - tsum / (N * (N - 1))))
    if (sd == 0) p = 1
    else { z = ((U1 > mu ? U1 - mu : mu - U1) - 0.5) / sd; if (z < 0) z = 0; p = 2 * (1 - norm_cdf(z)); if (p > 1) p = 1 }
  }
  ma = median(a, n1); mb = median(b, n2)
  chg = (ma != 0) ? (mb - ma) / (ma < 0 ? -ma : ma) * 100 : 0
  ad = (d < 0) ? -d : d
  mag = (ad < 0.147) ? "무시할 만함" : (ad < 0.33) ? "작음" : (ad < 0.474) ? "중간" : "큼"
  worse = hib ? (d < 0) : (d > 0)
  printf "기준 n=%d 중앙값 %.4g · 후보 n=%d 중앙값 %.4g · 변화 %+.1f%% (%s)\n", n1, ma, n2, mb, chg, (hib ? "클수록 좋음" : "작을수록 좋음")
  printf "Mann-Whitney U=%g · p=%.4g (%s, 양측) · Cliff delta=%+.3f (%s)\n", U1, p, method, d, mag
  if (p < alpha && ad >= mineff) {
    if (worse) { printf "❌ ST-20 회귀 — 유의(p < %s)하고 효과 크기가 %s 이상이며 나빠졌다\n규칙: %s\n", alpha, mineff, rules; exit 2 }
    printf "✅ 개선 — 유의하게 좋아졌다\n"; exit 0
  }
  printf "✅ 유의한 회귀 없음 — %s\n", (p >= alpha ? "p ≥ " alpha " (차이를 노이즈와 구분할 수 없다. 표본을 늘리면 달라질 수 있다)" : "효과 크기가 " mineff " 미만")
}' "${FILES[0]}" "${FILES[1]}"
