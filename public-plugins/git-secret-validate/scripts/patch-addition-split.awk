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
