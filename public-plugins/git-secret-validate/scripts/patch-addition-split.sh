#!/usr/bin/env bash
# 패치(stdin)의 추가된 줄만 파일별로 $1 아래에 모은다. 지운 파일 · 바이너리는 건너뛴다 — validate-git-secret.sh 가 부른다
exec awk -v out="$1" '
    function q(s) { gsub(/\047/, "\047\\\047\047", s); return "\047" s "\047" }
    /^diff --git / { cur = ""; next }
    /^\+\+\+ / {
      p = substr($0, 5); cur = ""
      if (p == "/dev/null") next
      sub(/^b\//, "", p); sub(/\t$/, "", p)
      if (p ~ /^\// || p ~ /(^|\/)\.\.(\/|$)/) next
      cur = out "/" p
      if (!(cur in made)) { d = cur; sub(/\/[^\/]*$/, "", d); system("mkdir -p " q(d)); made[cur] = 1; printf "" > cur }
      next
    }
    /^\+/ && cur != "" { print substr($0, 2) >> cur }
  '
