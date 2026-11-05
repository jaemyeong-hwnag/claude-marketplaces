#!/usr/bin/env bash
# 셸 명령(stdin)을 단순 명령 단위로 자른다 — validate-workflow.sh 가 부른다. 출력 형식은 그 스크립트의 check_command 위 주석을 본다
read -r -d '' LEX <<'AWK'
function emit() { if (CMD != "") print CMD; CMD = "" }
function endtok() { if (INTOK) { gsub(/\n/, "\036", TOK); CMD = CMD TOK SEP }; TOK = ""; INTOK = 0 }
function ch(o) { return substr(S, P + o, 1) }
function blanks() { while (P <= N && (ch(0) == " " || ch(0) == "\t")) P++ }
function heredocs(   i, e, line, cmp) {
  for (i = 1; i <= HD; i++) {
    while (P <= N) {
      e = index(substr(S, P), "\n")
      if (e == 0) { line = substr(S, P); P = N + 1 } else { line = substr(S, P, e - 1); P += e }
      cmp = line; if (HDTAB[i]) sub(/^\t+/, "", cmp)
      if (cmp == HDEND[i]) break
    }
  }
  HD = 0
}
function word(   w, c) {
  w = ""
  while (P <= N) {
    c = ch(0)
    if (c ~ /[ \t\n;&|()<>]/) break
    if (c == "\\") { w = w ch(1); P += 2; continue }
    if (c == "'" || c == "\"") { P++; while (P <= N && ch(0) != c) { w = w ch(0); P++ }; P++; continue }
    w = w c; P++
  }
  return w
}
function squote(   s) { s = ""; while (P <= N && ch(0) != "'") { s = s ch(0); P++ }; P++; return s }
function ansi(   s) { s = ""; while (P <= N && ch(0) != "'") { if (ch(0) == "\\") { s = s ch(1); P += 2 } else { s = s ch(0); P++ } }; P++; return s }
function arith(   d) { d = 0; while (P <= N) { if (ch(0) == "(") d++; else if (ch(0) == ")") { d--; if (d == 0) { P++; return } }; P++ } }
function braces(   d, s) { d = 0; s = ""; while (P <= N) { s = s ch(0); if (ch(0) == "{") d++; else if (ch(0) == "}") { d--; if (d == 0) { P++; return s } }; P++ }; return s }
function nested(stop,   sc, st, si) { sc = CMD; st = TOK; si = INTOK; CMD = ""; TOK = ""; INTOK = 0; lex(stop); CMD = sc; TOK = st; INTOK = si }
function dquote(   c, c2) {
  while (P <= N) {
    c = ch(0)
    if (c == "\"") { P++; return }
    if (c == "\\") { c2 = ch(1); if (c2 == "\n") { P += 2; continue }; if (c2 !~ /[$`"\\]/) TOK = TOK c; TOK = TOK c2; P += 2; continue }
    if (c == "$" && ch(1) == "(") { if (ch(2) == "(") { P++; arith(); continue }; P += 2; nested(")"); continue }
    if (c == "$" && ch(1) == "{") { P++; TOK = TOK "$" braces(); continue }
    if (c == "`") { P++; nested("`"); continue }
    TOK = TOK c; P++
  }
}
function lex(stop,   c, c2) {
  while (P <= N) {
    c = ch(0)
    if (stop != "" && c == stop) { P++; endtok(); emit(); return }
    if (c == "\\") { if (ch(1) != "\n") { TOK = TOK ch(1); INTOK = 1 }; P += 2; continue }
    if (c == "'") { P++; TOK = TOK squote(); INTOK = 1; continue }
    if (c == "\"") { P++; INTOK = 1; dquote(); continue }
    if (c == "$") {
      c2 = ch(1)
      if (c2 == "(") { INTOK = 1; if (ch(2) == "(") { P++; arith(); continue }; P += 2; nested(")"); continue }
      if (c2 == "{") { P++; TOK = TOK "$" braces(); INTOK = 1; continue }
      if (c2 == "'") { P += 2; TOK = TOK ansi(); INTOK = 1; continue }
      TOK = TOK c; INTOK = 1; P++; continue
    }
    if (c == "`") { P++; INTOK = 1; nested("`"); continue }
    if (c == " " || c == "\t") { endtok(); P++; continue }
    if (c == "\n") { endtok(); emit(); P++; heredocs(); continue }
    if (c == "#" && !INTOK) { while (P <= N && ch(0) != "\n") P++; continue }
    if (c == "&" && ch(1) == ">") { endtok(); P += 2; if (ch(0) == ">") P++; blanks(); word(); continue }
    if (c == ">" || c == "<") {
      if (INTOK && TOK ~ /^[0-9]+$/) { TOK = ""; INTOK = 0 } else endtok()
      if (substr(S, P, 3) ~ /^[<][<][<]$/) { P += 3; blanks(); word(); continue }
      if (substr(S, P, 2) ~ /^[<][<]$/) { P += 2; HD++; HDTAB[HD] = 0; if (ch(0) == "-") { HDTAB[HD] = 1; P++ }; blanks(); HDEND[HD] = word(); continue }
      P++; while (P <= N && ch(0) ~ /[>&|]/) P++
      blanks(); word(); continue
    }
    if (c ~ /[;&|()]/) { endtok(); emit(); P++; continue }
    TOK = TOK c; INTOK = 1; P++
  }
  endtok(); emit()
}
{ S = (NR == 1) ? $0 : S "\n" $0 }
END { SEP = "\037"; N = length(S); P = 1; CMD = ""; TOK = ""; INTOK = 0; HD = 0; lex("") }
AWK
exec awk "$LEX"
