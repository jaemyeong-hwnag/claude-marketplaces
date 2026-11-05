#!/usr/bin/env bash
# 문서 $4 의 DS-01 ~ DS-16 판정 줄을 낸다 ($1=모드 $2=규칙 줄 파일 $3=선택 파일) — document-slop-validate.sh 가 부른다
exec awk -v mode="$1" -v FS='\037' '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function emit(n, rule, lvl, msg) {
  if ((n SUBSEP rule) in seen) return
  seen[n SUBSEP rule] = 1
  printf "%d\037%s\037%s\037%s\n", n, rule, lvl, msg
}
function anyof(s, k,   i) { for (i = 1; i <= NP[k]; i++) if (s ~ P[k, i]) return 1; return 0 }
function firstof(s, k,   i) { for (i = 1; i <= NP[k]; i++) if (match(s, P[k, i])) return substr(s, RSTART, RLENGTH); return "" }
function has_evidence(s) { return anyof(s, "evidence") }
FILENAME == ARGV[1] {
  if ($1 == "msg") MSG[$2] = $3
  else if ($1 == "level") LVL[$2] = $3
  else if ($1 == "opt") OPT[$2] = $3
  else if ($1 == "word") WORD[$3] = 1
  else { k = ($1 == "pat") ? $2 : $1; NP[k]++; P[k, NP[k]] = $3 }
  next
}
FILENAME == ARGV[2] {
  if (mode == "text") { t = trim($0); if (t != "") WANT_TEXT[t] = 1 }
  else if (mode == "lines") { n = split($0, a, /[ ]+/); for (i = 1; i <= n; i++) if (a[i] != "") WANT_LINE[a[i]] = 1 }
  next
}
{ NL++; L[NL] = (length($0) > 4000) ? "" : $0 }
END {
  # 1차: 볼 줄 · 산문 줄 · 제목을 고른다
  fence = 0; front = 0; cmt = 0
  for (n = 1; n <= NL; n++) {
    raw = L[n]
    if (n == 1 && raw ~ /^---[ \t]*$/) { front = 1; continue }
    if (front) { if (raw ~ /^(---|\.\.\.)[ \t]*$/) front = 0; continue }
    if (raw ~ /^[ \t]*(```|~~~)/) { fence = !fence; continue }
    if (fence) continue
    if (raw ~ /^[ \t]*>/) continue
    if (raw ~ /document-slop-ignore/ || (n > 1 && L[n-1] ~ /document-slop-ignore/)) { IGN[n] = 1 }
    s = raw
    if (cmt) { if (!match(s, /-->/)) continue; s = substr(s, RSTART + 3); cmt = 0 }
    gsub(/<!--.*-->/, "", s)
    if (match(s, /<!--/)) { s = substr(s, 1, RSTART - 1); cmt = 1 }
    PROSE[n] = s
    t = trim(raw)
    if (mode == "all") W[n] = 1
    else if (mode == "text" && (t in WANT_TEXT)) W[n] = 1
    else if (mode == "lines" && (n in WANT_LINE)) W[n] = 1
    if (match(s, /^#{1,6}[ \t]/)) { HN++; HL[HN] = n; HV[HN] = RLENGTH - 1 }
  }

  distinct = 0; contrast = 0; bolds = 0; prose = 0; lead = 0
  for (n = 1; n <= NL; n++) {
    if (!(n in PROSE) || !(n in W) || (n in IGN)) continue
    s = PROSE[n]
    c = s; gsub(/`[^`]*`/, "", c)
    low = tolower(c)
    if (trim(low) == "") continue
    body = low; sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", body); sub(/^#{1,6}[ \t]+/, "", body)

    if (anyof(body, "DS-01")) emit(n, "DS-01", "block", MSG["DS-01"] " (" firstof(body, "DS-01") ")")
    nolink = low; gsub(/\[[^]]*\]\([^)]*\)/, "", nolink)
    if (anyof(nolink, "DS-02")) emit(n, "DS-02", "block", MSG["DS-02"] " (" firstof(nolink, "DS-02") ")")
    if (anyof(low, "DS-03")) emit(n, "DS-03", "block", MSG["DS-03"] " (" firstof(low, "DS-03") ")")

    rest = c
    while (match(rest, /\]\([^)]*\)/)) {
      tgt = substr(rest, RSTART + 2, RLENGTH - 3); rest = substr(rest, RSTART + RLENGTH)
      emit_link(n, tgt)
    }
    if (match(c, /^[ \t]*\[[^]]+\]:[ \t]+[^ \t]+/)) { tgt = c; sub(/^[ \t]*\[[^]]+\]:[ \t]+/, "", tgt); sub(/[ \t].*$/, "", tgt); emit_link(n, tgt) }

    if (anyof(low, "DS-05") && !has_evidence(low)) emit(n, "DS-05", "warn", MSG["DS-05"] " (" firstof(low, "DS-05") ")")
    if (anyof(body, "DS-06") && !anyof(low, "dated")) emit(n, "DS-06", "warn", MSG["DS-06"] " (" trim(firstof(body, "DS-06")) ")")
    if (anyof(low, "DS-07") && !has_evidence(low) && low !~ /^[ \t]*\|/) emit(n, "DS-07", "warn", MSG["DS-07"] " (" firstof(low, "DS-07") ")")
    if (anyof(body, "DS-08")) emit(n, "DS-08", "warn", MSG["DS-08"] " (" firstof(body, "DS-08") ")")
    if (anyof(low, "DS-12")) emit(n, "DS-12", "warn", MSG["DS-12"] " (" firstof(low, "DS-12") ")")
    if (anyof(low, "DS-13")) emit(n, "DS-13", "warn", MSG["DS-13"] " (" firstof(low, "DS-13") ")")

    # DS-10 — 어휘 묶음은 이번에 쓴 줄 전체에서 센다
    tmp = low; gsub(/[^a-z\047-]+/, " ", tmp); m = split(tmp, ws, " ")
    for (i = 1; i <= m; i++) if ((ws[i] in WORD) && !(ws[i] in VOC)) { VOC[ws[i]] = n; distinct++; vlist = vlist (vlist == "" ? "" : ", ") ws[i]; if (!vfirst) vfirst = n }
    for (i = 1; i <= NP["DS-10"]; i++) if (match(low, P["DS-10", i])) { w = substr(low, RSTART, RLENGTH); if (!(w in VOC)) { VOC[w] = n; distinct++; vlist = vlist (vlist == "" ? "" : ", ") w; if (!vfirst) vfirst = n } }

    k = 0; for (i = 1; i <= NP["DS-11"]; i++) { tc = low; k += gsub(P["DS-11", i], "", tc) }
    if (k > 0) { contrast += k; if (!cfirst) cfirst = n; clist = clist (clist == "" ? "" : ", ") n "행" }

    # DS-14 — 굵게 · 머리말 목록 · 이모지 제목
    if (low !~ /^[ \t]*\|/ && low !~ /^#{1,6}[ \t]/) { prose++; tb = c; bolds += gsub(/\*\*[^*]+\*\*/, "", tb) }
    if (c ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]+\*\*[^*]+\*\*[ \t]*(:|—|–| - )/ || c ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]+\*\*[^*]+[:：]\*\*/) { lead++; if (lead == 1) lfirst = n; if (lead == OPT["DS-14.lead_run"]) emit(lfirst, "DS-14", "warn", MSG["DS-14"] " (\"**머리말**: 설명\" 목록 " lead "줄 이상 연속)") }
    else if (c !~ /^[ \t]*$/) lead = 0
    if (c ~ /^#{1,6}[ \t]/ && (c ~ /\360\237/ || c ~ /\342\234\205|\342\235\214|\342\232\240|\342\234\250|\342\255\220/)) emit(n, "DS-14", "warn", MSG["DS-14"] " (제목에 이모지)")

    # DS-16 — 같은 문장이 다른 줄에도 있는가
    t = trim(c)
    if (length(t) >= OPT["DS-16.min_bytes"] && t !~ /^(#|\|)/) {
      for (j = 1; j <= NL; j++) if (j != n && (j in PROSE) && !(j > n && (j in W)) && trim(PROSE[j]) == trim(PROSE[n])) { emit(n, "DS-16", "warn", MSG["DS-16"] " (" j "행)"); break }
    }
  }
  if (distinct >= OPT["DS-10.min_distinct"]) emit(vfirst, "DS-10", "warn", MSG["DS-10"] " (" vlist ")")
  if (contrast >= OPT["DS-11.min_count"]) emit(cfirst, "DS-11", "warn", MSG["DS-11"] " (" clist ")")
  if (bolds >= OPT["DS-14.bold_min"] && prose > 0 && bolds / prose >= OPT["DS-14.bold_ratio"]) emit(0, "DS-14", "warn", MSG["DS-14"] " (굵게 " bolds "곳 / 산문 " prose "줄)")

  # DS-09 · DS-15 — 제목은 파일 전체로 판정하고, 이번에 쓴 줄이면 알린다
  for (h = 1; h <= HN; h++) {
    n = HL[h]
    if (!(n in W) || (n in IGN)) continue
    if (h > 1 && HV[h] > HV[h-1] + 1) emit(n, "DS-15", "warn", MSG["DS-15"] " (h" HV[h-1] " → h" HV[h] ")")
  }
  if (HN > 0) {
    n = HL[HN]; t = tolower(PROSE[n])
    sub(/^#{1,6}[ \t]+/, "", t); gsub(/\*\*|__/, "", t); sub(/^[0-9.]+[ \t]*/, "", t); gsub(/[^a-z0-9;: \200-\377-]/, "", t); gsub(/\360\237[\200-\277][\200-\277]/, "", t); t = trim(t)
    if ((n in W) && !(n in IGN) && t ~ OPT["DS-09.headings"]) emit(n, "DS-09", "warn", MSG["DS-09"] " (" t ")")
  }
}
function emit_link(n, tgt) {
  tgt = trim(tgt); sub(/^</, "", tgt); sub(/>$/, "", tgt); sub(/[ \t]+".*$/, "", tgt)
  if (tgt == "" || tgt ~ /^#/ || tgt ~ /^\// || tgt ~ /^[a-zA-Z][a-zA-Z0-9+.-]*:/ || tgt ~ /\{\{|\$/) return
  sub(/[#?].*$/, "", tgt)
  if (tgt != "") emit(n, "DS-04", "link", tgt)
}
' "$2" "$3" "$4"
