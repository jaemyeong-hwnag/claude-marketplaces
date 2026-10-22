#!/usr/bin/env bash
# git diff 가 건드린 Kotlin 메서드의 JaCoCo INSTRUCTION 커버리지를 메서드마다 출력한다.
# Usage: method-coverage-get.sh <git-ref> <jacoco-xml> <source-file> [label]
#   source-file : Gradle 루트 기준 .kt 경로 (src/main/kotlin · src/main/java, 라이브러리 모듈 소스일 수 있다)
#   label       : 출력에 붙일 모듈 이름 (기본: 리포트 경로)
# 변경 줄 → 메서드는 클래스 파일의 LineNumberTable(javap -p -s -l)로 구한다. javap = $AITEST_JAVAP → $JAVA_HOME/bin → PATH
# 출력: OK … / FAIL …(stderr) / NO_CHANGED_METHODS …
# 종료 코드: 0 전부 100% 또는 측정할 메서드 없음 · 1 100% 미만 또는 리포트 없음 · 2 판정 불가(javap · 클래스 파일 없음)
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

base="${1:?git ref required}"
xml="${2:?jacoco xml required}"
source_rel="${3:?source file required}"
label="${4:-$xml}"

if [ ! -f "$source_rel" ]; then
  echo "NO_CHANGED_METHODS $label $source_rel — source not present"
  exit 0
fi

file_name="$(basename "$source_rel")"
pkg="$(sed -nE 's/^[[:space:]]*package[[:space:]]+([A-Za-z0-9_.`]+).*/\1/p' "$source_rel" | head -1 | tr -d '`')"
pkg_path="${pkg//.//}"
where="${pkg_path:+$pkg_path/}$file_name"
case "$source_rel" in
  *src/main/kotlin/*) mod_prefix="${source_rel%%src/main/kotlin/*}" ;;
  *src/main/java/*) mod_prefix="${source_rel%%src/main/java/*}" ;;
  *) mod_prefix="" ;;
esac
class_dir="${mod_prefix}build/classes/kotlin/main"
# internal 멤버는 이름 뒤에 $<Kotlin 모듈 이름>(Gradle 프로젝트 이름, group 이 붙기도 한다)이 붙는다 — 표시할 때만 뗀다
if [ -n "$mod_prefix" ]; then
  module_name="$(basename "$mod_prefix")"
else
  module_name="$(sed -nE 's/^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' settings.gradle.kts 2>/dev/null | head -1)"
  [ -n "$module_name" ] || module_name="$(basename "$(pwd -P)")"
fi
file_lines="$(awk 'END { print NR }' "$source_rel")"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kt-aitest-method.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
changed_lines="$tmp_dir/changed-lines"
exec_lines="$tmp_dir/exec-lines"
changed_exec_lines="$tmp_dir/changed-exec-lines"
measured="$tmp_dir/measured"
line_table="$tmp_dir/line-table"
selected="$tmp_dir/selected"

if ! git ls-files --error-unmatch -- "$source_rel" >/dev/null 2>&1; then
  # untracked 신규 파일은 git diff 에 나오지 않는다 — 전 줄을 변경으로 본다
  awk '{ print NR }' "$source_rel" > "$changed_lines"
else
  git diff "$base" --unified=0 -- "$source_rel" | awk '
  /^@@ / {
    range = $0
    sub(/^.* \+/, "", range)
    sub(/ @@.*$/, "", range)
    split(range, a, ",")
    start = a[1] + 0
    count = (a[2] == "" ? 1 : a[2] + 0)
    for (i = 0; i < count; i++) print start + i
  }' | sort -n -u > "$changed_lines"
fi

if [ ! -s "$changed_lines" ]; then
  echo "NO_CHANGED_METHODS $label $where — no added/modified lines"
  exit 0
fi

if [ ! -f "$xml" ]; then
  echo "FAIL $label $where — missing JaCoCo XML report: $xml" >&2
  exit 1
fi

# JaCoCo XML 은 한 줄이다. 태그마다 줄을 나눠 이 소스 파일에서 나온 모든 클래스의 메서드와 소스 줄을 뽑는다.
# 메서드: M|클래스|이름|desc|missed|covered|시작 줄 (명령 0 = JaCoCo 가 걸러낸 것은 뺀다) · 줄: L|번호
sed 's/></>\
</g' "$xml" | awk -v target_pkg="$pkg_path" -v target_source="$file_name" '
function attr(s, name,    pos, v) {
  pos = index(s, " " name "=\"")
  if (pos == 0) return ""
  v = substr(s, pos + length(name) + 3)
  sub(/".*/, "", v)
  return v
}
/^<package / { in_pkg = (attr($0, "name") == target_pkg); next }
/^<\/package>/ { in_pkg = 0; next }
/^<class / { in_class = in_pkg && (attr($0, "sourcefilename") == target_source); cls = attr($0, "name"); next }
/^<\/class>/ { in_class = 0; next }
in_class && /^<method / {
  in_method = 1; m_name = attr($0, "name"); m_desc = attr($0, "desc"); m_line = attr($0, "line")
  gsub(/&lt;/, "<", m_name); gsub(/&gt;/, ">", m_name)
  m_missed = 0; m_covered = 0; next
}
in_method && /^<counter type="INSTRUCTION"/ { m_missed = attr($0, "missed") + 0; m_covered = attr($0, "covered") + 0; next }
in_method && /^<\/method>/ {
  if (m_missed + m_covered > 0) print "M|" cls "|" m_name "|" m_desc "|" m_missed "|" m_covered "|" m_line
  in_method = 0; next
}
in_pkg && /^<sourcefile / { in_src = (attr($0, "name") == target_source); next }
/^<\/sourcefile>/ { in_src = 0; next }
in_src && /^<line / { if (attr($0, "mi") + attr($0, "ci") > 0) print "L|" attr($0, "nr"); next }
' > "$tmp_dir/xml-items"

awk -F'|' '$1 == "L" { print $2 }' "$tmp_dir/xml-items" | sort -n -u > "$exec_lines"
awk -F'|' '$1 == "M" { print substr($0, 3) }' "$tmp_dir/xml-items" > "$measured"
awk 'NR == FNR { executable[$1] = 1; next } executable[$1]' "$exec_lines" "$changed_lines" > "$changed_exec_lines"

if [ ! -s "$changed_exec_lines" ]; then
  if [ ! -s "$measured" ] && [ ! -s "$exec_lines" ]; then
    # 이 파일의 클래스가 리포트에 아예 없다 — 이 모듈 aiTest 가 이 파일을 측정하지 않는다
    echo "NO_CHANGED_METHODS $label $where — class not in report"
  else
    echo "NO_CHANGED_METHODS $label $where — changed lines are not executable"
  fi
  exit 0
fi

# --- 줄 표: 클래스마다 javap -p -s -l → 클래스|이름|desc|static|줄 ----------------
javap_bin=""
if [ -n "${AITEST_JAVAP:-}" ]; then
  [ -x "$AITEST_JAVAP" ] && javap_bin="$AITEST_JAVAP"
elif [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javap" ]; then
  javap_bin="$JAVA_HOME/bin/javap"
else
  javap_bin="$(command -v javap 2>/dev/null || true)"
fi
if [ -z "$javap_bin" ]; then
  echo "UNDECIDABLE $label $where — javap 이 없어 변경 줄을 메서드로 옮길 수 없습니다 (JDK · JAVA_HOME · 설정 jdkVersion 확인)" >&2
  exit 2
fi

: > "$line_table"
for cls in $(cut -d'|' -f1 "$measured" | sort -u); do
  class_file="$class_dir/$cls.class"
  if [ ! -f "$class_file" ]; then
    echo "UNDECIDABLE $label $where — 클래스 파일 없음: $class_file (aiTest 를 다시 돌려 컴파일한다)" >&2
    exit 2
  fi
  if ! "$javap_bin" -p -s -l "$class_file" > "$tmp_dir/javap.out" 2>"$tmp_dir/javap.err"; then
    echo "UNDECIDABLE $label $where — javap 실패: $(head -1 "$tmp_dir/javap.err")" >&2
    exit 2
  fi
  # 인라인된 코드는 파일 길이를 넘는 가짜 줄(SMAP)로 남는다 — 버린다
  awk -v cls="$cls" -v max="$file_lines" '
  BEGIN { dotted = cls; gsub(/\//, ".", dotted) }
  /^  [^ ].*;$/ {
    name = ""; desc = ""; is_static = 0
    if ($0 ~ /^  static \{\};$/) { name = "<clinit>"; is_static = 1; next }
    p = index($0, "(")
    if (p == 0) next
    head = substr($0, 3, p - 3)
    n = split(head, w, " ")
    name = w[n]
    if (name == dotted) name = "<init>"
    for (i = 1; i < n; i++) if (w[i] == "static") is_static = 1
    next
  }
  name != "" && /^    descriptor: / { desc = $2; next }
  name != "" && desc != "" && /^      line [0-9]+: / {
    l = $2; sub(/:$/, "", l)
    if (l + 0 <= max) print cls "|" name "|" desc "|" is_static "|" l
  }
  ' "$tmp_dir/javap.out" | sort -u >> "$line_table"
done

# --- 변경 실행 줄마다 메서드를 고른다 -------------------------------------------------
# 측정된 메서드만 후보다. 합성 메서드는 아래 순서로 빼고, 다 빠지면 되살린다 (@JvmStatic 브리지는 되살리지 않는다)
awk -F'|' '
FILENAME == ARGV[1] { measured[$1 "|" $2 "|" $3] = 1; next }
FILENAME == ARGV[2] {
  key = $1 "|" $2 "|" $3
  lines[key] = lines[key] " " $5
  nlines[key]++
  static[key] = $4
  at[$5] = at[$5] " " key
  methods[key] = 1
  next
}
{ changed[$1] = 1 }
function base_of(k,    a) { split(k, a, "|"); return a[1] "|" substr(a[2], 1, length(a[2]) - 8) }
function is_accessor(k, L,    a) { split(k, a, "|"); return a[2] ~ /^(get|set|is)[A-Z_]/ && nlines[k] == 1 && lines[k] == " " L }
END {
  # @JvmStatic 브리지 — 바깥 클래스의 static 메서드 중 <클래스>$Companion 에 같은 이름 · desc 가 있는 것
  for (k in methods) {
    split(k, a, "|")
    if (static[k] == 1 && ((a[1] "$Companion|" a[2] "|" a[3]) in methods)) bridge[k] = 1
  }
  for (L in changed) {
    n = split(at[L], ks, " ")
    delete cand; delete kept; c = 0
    for (i = 1; i <= n; i++) if ((ks[i] in measured) && !(ks[i] in bridge)) { cand[ks[i]] = 1; c++ }
    if (c == 0) continue
    for (k in cand) kept[k] = 1
    # name$default — 같은 줄에 name 이 있으면 뺀다
    for (k in cand) {
      split(k, a, "|")
      if (a[2] ~ /\$default$/) for (o in cand) { split(o, b, "|"); if ((b[1] "|" b[2]) == base_of(k)) delete kept[k] }
    }
    # <init>(…, DefaultConstructorMarker) — 같은 줄에 다른 <init> 이 있으면 뺀다
    for (k in cand) {
      split(k, a, "|")
      if (a[2] == "<init>" && a[3] ~ /Lkotlin\/jvm\/internal\/DefaultConstructorMarker;/)
        for (o in cand) { split(o, b, "|"); if (o != k && b[1] == a[1] && b[2] == "<init>") delete kept[k] }
    }
    # 이 줄에만 있는 get · set · is 접근자 — 같은 줄에 접근자 아닌 메서드가 남아 있으면 뺀다
    other = 0
    for (k in kept) if (!is_accessor(k, L)) other = 1
    if (other) for (k in cand) if ((k in kept) && is_accessor(k, L)) delete kept[k]
    left = 0
    for (k in kept) left++
    if (left == 0) for (k in cand) kept[k] = 1
    for (k in kept) chosen[k] = 1
  }
  for (k in chosen) print k
}' "$measured" "$line_table" "$changed_exec_lines" | sort -u > "$selected"

if [ ! -s "$selected" ]; then
  echo "NO_CHANGED_METHODS $label $where — executable changes are outside methods"
  exit 0
fi

fail=0
while IFS='|' read -r cls name desc; do
  row="$(awk -F'|' -v c="$cls" -v n="$name" -v d="$desc" '$1 == c && $2 == n && $3 == d { print; exit }' "$measured")"
  IFS='|' read -r _c _n _d missed covered line <<< "$row"
  total=$((missed + covered))
  pct=$((covered * 100 / total))
  shown="$name"
  case "$shown" in
    "<"*) ;;
    *) shown="${shown%%-*}"
       case "${shown##*\$}" in "$module_name" | *"_$module_name") shown="${shown%\$*}" ;; esac ;;
  esac
  text="$label ${cls//\//.}#${shown}${desc} line ${line} → ${pct}% (${covered}/${total})"
  if [ "$missed" -eq 0 ]; then
    echo "OK $text"
  else
    echo "FAIL $text" >&2
    fail=1
  fi
done < "$selected"

exit "$fail"
