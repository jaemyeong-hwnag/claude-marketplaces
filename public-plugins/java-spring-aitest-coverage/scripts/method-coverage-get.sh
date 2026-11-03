#!/usr/bin/env bash
# git diff 가 건드린 메서드의 JaCoCo INSTRUCTION 커버리지를 메서드마다 출력한다.
# Usage: method-coverage-get.sh <git-ref> <jacoco-xml> <source-file> <FQN> [label]
#   source-file : 프로젝트 루트 기준 .java 경로 (라이브러리 모듈 소스일 수 있다)
#   label       : 출력에 붙일 모듈 이름 (기본: 리포트 경로)
# 변경 줄 → 메서드는 클래스 파일의 LineNumberTable(javap -p -s -l)로 구한다. javap = $AITEST_JAVAP → $JAVA_HOME/bin → PATH
# 출력: OK … / FAIL …(stderr) / NO_CHANGED_METHODS …
# 종료 코드: 0 전부 100% 또는 측정할 메서드 없음 · 1 100% 미만 또는 리포트 문제 · 2 판정 불가(javap · 클래스 파일 없음)
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

base="${1:?git ref required}"
xml="${2:?jacoco xml required}"
source_rel="${3:?source file required}"
fqn="${4:?FQN required}"
label="${5:-$xml}"

pkg="${fqn%.*}"
cls="${fqn##*.}"
[ "$pkg" = "$fqn" ] && pkg=""
pkg_path="${pkg//./\/}"

if [ ! -f "$source_rel" ]; then
  echo "NO_CHANGED_METHODS $label $fqn — source not present"
  exit 0
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/aitest-method.XXXXXX")"
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
  echo "NO_CHANGED_METHODS $label $fqn — no added/modified lines"
  exit 0
fi

if [ ! -f "$xml" ]; then
  echo "FAIL $label $fqn — missing JaCoCo XML report: $xml" >&2
  exit 1
fi

# JaCoCo XML 은 한 줄이다. 태그마다 줄을 나눠 이 소스 파일에서 나온 모든 클래스(중첩 · 익명 포함)의 메서드와 소스 줄을 뽑는다.
# 메서드: M|클래스|이름|desc|missed|covered|시작 줄 · 줄: L|번호
sed 's/></>\
</g' "$xml" | awk -v target_pkg="$pkg_path" -v target_source="${cls}.java" '
function attr(s, name,    pos, v) {
  pos = index(s, " " name "=\"")
  if (pos == 0) return ""
  v = substr(s, pos + length(name) + 3)
  sub(/".*/, "", v)
  return v
}
/^<package / { in_pkg = (attr($0, "name") == target_pkg); next }
/^<\/package>/ { in_pkg = 0; next }
/^<class / { in_class = in_pkg && (attr($0, "sourcefilename") == target_source); c_name = attr($0, "name"); next }
/^<\/class>/ { in_class = 0; next }
in_class && /^<method / {
  in_method = 1; m_name = attr($0, "name"); m_desc = attr($0, "desc"); m_line = attr($0, "line")
  gsub(/&lt;/, "<", m_name); gsub(/&gt;/, ">", m_name)
  m_missed = 0; m_covered = 0; next
}
in_method && /^<counter type="INSTRUCTION"/ { m_missed = attr($0, "missed") + 0; m_covered = attr($0, "covered") + 0; next }
in_method && /^<\/method>/ {
  if (m_missed + m_covered > 0) print "M|" c_name "|" m_name "|" m_desc "|" m_missed "|" m_covered "|" m_line
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
    # 클래스가 리포트에 아예 없다 — 이 모듈 aiTest 가 이 클래스를 측정하지 않는다
    echo "NO_CHANGED_METHODS $label $fqn — class not in report"
  else
    echo "NO_CHANGED_METHODS $label $fqn — changed lines are not executable"
  fi
  exit 0
fi

if [ ! -s "$measured" ]; then
  echo "FAIL $label $fqn — no JaCoCo methods found" >&2
  exit 1
fi

# --- 줄 표: 클래스마다 javap -p -s -l → 클래스|이름|desc|줄 ----------------------------
# 시작 줄 정렬로는 람다 본문 · 중첩 클래스의 줄이 앞 메서드로 잘못 간다 — 메서드마다 실제 줄 집합으로 고른다
javap_bin=""
if [ -n "${AITEST_JAVAP:-}" ]; then
  [ -x "$AITEST_JAVAP" ] && javap_bin="$AITEST_JAVAP"
elif [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javap" ]; then
  javap_bin="$JAVA_HOME/bin/javap"
else
  javap_bin="$(command -v javap 2>/dev/null || true)"
fi
if [ -z "$javap_bin" ]; then
  echo "UNDECIDABLE $label $fqn — javap 이 없어 변경 줄을 메서드로 옮길 수 없습니다 (JDK · JAVA_HOME · 설정 javaVersion 확인)" >&2
  exit 2
fi

class_dir="${source_rel%%src/main/java/*}build/classes/java/main"
: > "$line_table"
for c in $(cut -d'|' -f1 "$measured" | sort -u); do
  class_file="$class_dir/$c.class"
  if [ ! -f "$class_file" ]; then
    echo "UNDECIDABLE $label $fqn — 클래스 파일 없음: $class_file (aiTest 를 다시 돌려 컴파일한다)" >&2
    exit 2
  fi
  if ! "$javap_bin" -p -s -l "$class_file" > "$tmp_dir/javap.out" 2>"$tmp_dir/javap.err"; then
    echo "UNDECIDABLE $label $fqn — javap 실패: $(head -1 "$tmp_dir/javap.err")" >&2
    exit 2
  fi
  awk -v cls="$c" '
  BEGIN { dotted = cls; gsub(/\//, ".", dotted) }
  /^  [^ ].*;$/ {
    name = ""; desc = ""
    if ($0 ~ /^  static \{\};$/) { name = "<clinit>"; next }
    p = index($0, "(")
    if (p == 0) next
    n = split(substr($0, 3, p - 3), w, " ")
    name = w[n]
    if (name == dotted) name = "<init>"
    next
  }
  name != "" && /^    descriptor: / { desc = $2; next }
  name != "" && desc != "" && /^      line [0-9]+: / { l = $2; sub(/:$/, "", l); print cls "|" name "|" desc "|" l }
  ' "$tmp_dir/javap.out" >> "$line_table"
done

# 변경 실행 줄마다 그 줄을 가진 메서드 중 리포트에 명령이 있는 것(JaCoCo 가 걸러내지 않은 것)
awk -F'|' '
FILENAME == ARGV[1] { measured[$1 "|" $2 "|" $3] = $0; next }
FILENAME == ARGV[2] { k = $1 "|" $2 "|" $3; if (k in measured) at[$4] = at[$4] SUBSEP k; next }
{ n = split(at[$1], ks, SUBSEP); for (i = 2; i <= n; i++) chosen[ks[i]] = 1 }
END { for (k in chosen) print measured[k] }
' "$measured" "$line_table" "$changed_exec_lines" | sort -t'|' -k1,1 -k6,6n -u > "$selected"

if [ ! -s "$selected" ]; then
  echo "NO_CHANGED_METHODS $label $fqn — executable changes are outside methods"
  exit 0
fi

fail=0
while IFS='|' read -r c name desc missed covered line; do
  total=$((missed + covered))
  pct=$((covered * 100 / total))
  text="$label ${c//\//.}#${name}${desc} line ${line} → ${pct}% (${covered}/${total})"
  if [ "$missed" -eq 0 ]; then
    echo "OK $text"
  else
    echo "FAIL $text" >&2
    fail=1
  fi
done < "$selected"

exit "$fail"
