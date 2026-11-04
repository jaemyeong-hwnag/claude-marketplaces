#!/usr/bin/env bash
# 설계 파일 $9 의 DD-20 · DD-22 ~ DD-24 신호를 내고 mermaid 간선을 $7 에 쓴다 — design-soundness-validate.sh 가 부른다
exec awk -v secs="$1" -v reqre="$2" -v decre="$3" \
    -v glore="$4" -v qre="$5" -v idre="$6" \
    -v edges="$7" -v US="$8" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function nodeid(s) { s = trim(s); if (s ~ /^\[\*\]/) return "[*]"; if (match(s, /^[^ \t\[\(\{>:;]+/)) return substr(s, 1, RLENGTH); return "" }
    function edge_line(l,    n, parts, i, a, b, la, lb, x, y, bidi, u, v) {
      if (mtype == "state") sub(/[ \t]*:.*$/, "", l)          # A --> B : 라벨
      else { gsub(/"[^"]*"/, "", l); for (i = 0; i < 2; i++) gsub(/\[[^]]*\]|\([^)]*\)|\{[^}]*\}/, "", l) }   # 노드 라벨
      sub(/;[ \t]*$/, "", l)
      gsub(/\|[^|]*\|/, " ", l)                                # A -->|라벨| B
      bidi = (l ~ /<-+>/); gsub(/<-+>/, "\001", l)             # A <--> B
      gsub(/-\.[ \t]+[^>]*\.->/, "\001", l)                    # A -. 라벨 .-> B
      gsub(/--[ \t]+[^>]*-->/, "\001", l)                      # A -- 라벨 --> B
      gsub(/(-\.+-|==+|--+)>/, "\001", l)
      if (index(l, "\001") == 0) return
      n = split(l, parts, "\001")
      for (i = 1; i < n; i++) {
        la = split(parts[i], a, "&"); lb = split(parts[i + 1], b, "&")
        for (x = 1; x <= la; x++) for (y = 1; y <= lb; y++) {
          u = nodeid(a[x]); v = nodeid(b[y])
          if (u == "" || v == "") continue
          printf "%s\t%s\t%s\t%s\n", mstart, mtype, u, v >> edges
          if (bidi) printf "%s\t%s\t%s\t%s\n", mstart, mtype, v, u >> edges
        }
      }
    }
    function ids(l, head,    rest, lead, id) {             # DD-22 — 결정 절 밖 줄 머리의 첫 등장이 정의
      rest = l; lead = l
      gsub(/^[ \t|>*+#-]+|^[ \t]*[0-9]+\.[ \t]*/, "", lead); gsub(/[*`]/, "", lead)
      while (match(rest, "(^|[^A-Za-z0-9_])" idre)) {
        id = substr(rest, RSTART, RLENGTH); sub(/^[^A-Za-z]/, "", id)
        rest = substr(rest, RSTART + RLENGTH)
        if (!indec && index(lead, id) == 1 && !(id in def)) def[id] = NR
        else { ref[id] = ref[id] " " NR; if (indec) decref[id] = 1 }
      }
    }
    BEGIN { ns = split(secs, sl, "\036"); for (i = 1; i <= ns; i++) { split(sl[i], p, US); sname[i] = p[1]; sre[i] = p[2] } }
    NR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    {
      line = $0; skip = ign; ign = 0
      if (index(line, "design-soundness-ignore")) { skip = 1; ign = 1 }
    }
    incom { e = index(line, "-->"); if (!e) next; incom = 0; line = substr(line, e + 3) }
    /^[ \t]*(```|~~~)/ {
      if (!infence) { infence = 1; lang = line; sub(/^[ \t]*(```|~~~)[ \t]*/, "", lang); inm = (tolower(lang) ~ /^mermaid/); mstart = NR; mtype = ""; inmfm = 0 }
      else { infence = 0; inm = 0 }
      next
    }
    infence {
      if (!inm || skip) next
      t = trim(line)
      if (t == "" || t ~ /^%%/) next
      if (mtype == "") {
        if (inmfm) { if (t == "---") inmfm = 0; next }           # 다이어그램 프런트매터
        if (t == "---") { inmfm = 1; next }
        if (t ~ /^stateDiagram/) mtype = "state"; else if (t ~ /^(flowchart|graph)/) mtype = "flow"; else inm = 0
        next
      }
      if (t ~ /^(classDef|class|style|linkStyle|click|note|direction)[ \t]/) next
      edge_line(t)
      next
    }
    {
      while ((cs = index(line, "<!--"))) {                       # 줄 안의 HTML 주석만 지운다
        ce = index(substr(line, cs + 4), "-->")
        if (!ce) { incom = 1; line = substr(line, 1, cs - 1); break }
        line = substr(line, 1, cs - 1) substr(line, cs + 4 + ce + 2)
      }
      if (trim(line) == "") next
    }
    /^[ \t]*>/ { next }
    line ~ /^#{1,6}[ \t]/ {
      h = tolower(line); match(line, /^#+/); lv = RLENGTH; sub(/^#+[ \t]*/, "", h)
      if (lv == 1 && !titled) { titled = 1; if (!skip) body[NR] = line; next }   # 문서 제목은 절이 아니다
      titled = 1; hd[++nh] = h
      g = (h ~ glore); d = (!g && h ~ decre); r = (!g && h ~ reqre)
      for (k = lv; k <= 6; k++) { R[k] = D[k] = G[k] = 0 }      # 하위 제목은 상위 절을 잇는다
      R[lv] = r; D[lv] = d; G[lv] = g
      inreq = indec = inglo = 0
      for (k = 1; k <= 6; k++) { if (R[k]) inreq = 1; if (D[k]) indec = 1; if (G[k]) inglo = 1 }
      if (d && !decstart) decstart = NR; if (g && !glostart) glostart = NR
      if (!skip) { if (!inglo) body[NR] = line; ids(line) }
      next
    }
    skip { next }
    {
      if (!inglo) body[NR] = line
      ids(line)
      # DD-23 측정 기준 없는 품질 요구
      q = line; gsub(idre, "", q)
      if (inreq && tolower(q) ~ qre && q !~ /[0-9]/) printf "DD-23%s%d줄: 측정 기준(숫자 · 단위)이 없는 품질 요구 — %s\n", US, NR, trim(line)
      # DD-24 용어 정의
      if (inglo) {
        term = ""
        if (line ~ /^[ \t]*\|/ && line !~ /^[ \t]*\|[ \t:|-]+$/) { split(line, c, "|"); term = trim(c[2]) }
        else if (match(line, /^[ \t]*[-*][ \t]+\*\*[^*]+\*\*/)) { term = substr(line, RSTART, RLENGTH); sub(/^[ \t]*[-*][ \t]+\*\*/, "", term); sub(/\*\*$/, "", term) }
        gsub(/[*`]/, "", term); term = trim(term)
        if (length(term) >= 2 && tolower(term) !~ /^(용어|term|이름|name|단어|word|뜻|정의|definition)$/ && !(term in tdef)) { tdef[term] = NR; tn++; tl[tn] = term }
      }
    }
    END {
      for (i = 1; i <= ns; i++) { ok = 0; for (j = 1; j <= nh; j++) if (hd[j] ~ sre[i]) { ok = 1; break }; if (!ok) printf "DD-20%s필수 절 없음 — %s\n", US, sname[i] }
      nd = 0; for (id in def) nd++
      if (nd > 0) {
        for (id in ref) if (!(id in def)) printf "DD-22%s정의 없이 참조된 요구 ID — %s (%s줄)\n", US, id, trim(ref[id])
        for (id in def) if (!(id in decref)) printf "DD-22%s결정 절에서 참조되지 않은 요구 — %s (%d줄 정의)\n", US, id, def[id]
      }
      if (glostart && (!decstart || glostart < decstart)) for (k = 1; k <= tn; k++) { t = tl[k]
        for (j = 1; j < tdef[t]; j++) if ((j in body) && index(body[j], t)) { printf "DD-24%s정의(%d줄) 전에 쓴 용어 — %s (%d줄)\n", US, tdef[t], t, j; break }
      }
    }' "$9"
