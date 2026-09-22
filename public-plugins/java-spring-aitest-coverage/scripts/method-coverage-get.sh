#!/usr/bin/env bash
# git diff 가 건드린 메서드의 JaCoCo INSTRUCTION 커버리지를 메서드마다 출력한다.
# Usage: method-coverage-get.sh <git-ref> <jacoco-xml> <source-file> <FQN> [label]
#   source-file : 프로젝트 루트 기준 .java 경로 (라이브러리 모듈 소스일 수 있다)
#   label       : 출력에 붙일 모듈 이름 (기본: 리포트 경로)
# 출력: OK … / FAIL …(stderr) / NO_CHANGED_METHODS …
# 종료 코드: 0 전부 100% 또는 측정할 메서드 없음 · 1 100% 미만 또는 리포트 문제
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
class_name="${pkg_path:+$pkg_path/}${cls}"

if [ ! -f "$source_rel" ]; then
  echo "NO_CHANGED_METHODS $label $fqn — source not present"
  exit 0
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/aitest-method.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
changed_lines="$tmp_dir/changed-lines"
exec_lines="$tmp_dir/exec-lines"
changed_exec_lines="$tmp_dir/changed-exec-lines"
methods="$tmp_dir/methods"
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

# JaCoCo XML 은 한 줄이다. 태그마다 줄을 나눠 대상 클래스의 메서드와 소스 줄만 뽑는다.
sed 's/></>\
</g' "$xml" | awk -v target_class="$class_name" -v target_pkg="$pkg_path" -v target_source="${cls}.java" '
function attr(s, name,    pos, v) {
  pos = index(s, " " name "=\"")
  if (pos == 0) return ""
  v = substr(s, pos + length(name) + 3)
  sub(/".*/, "", v)
  return v
}
/^<package / { in_pkg = (attr($0, "name") == target_pkg); next }
/^<\/package>/ { in_pkg = 0; next }
/^<class / { in_class = in_pkg && (attr($0, "name") == target_class); next }
/^<\/class>/ { in_class = 0; next }
in_class && /^<method / {
  in_method = 1; m_name = attr($0, "name"); m_desc = attr($0, "desc"); m_line = attr($0, "line")
  m_missed = 0; m_covered = 0; next
}
in_method && /^<counter type="INSTRUCTION"/ { m_missed = attr($0, "missed") + 0; m_covered = attr($0, "covered") + 0; next }
in_method && /^<\/method>/ {
  if (m_line != "" && m_missed + m_covered > 0) print m_line "|" m_name "|" m_desc "|" m_missed "|" m_covered
  in_method = 0; next
}
in_pkg && /^<sourcefile / { in_src = (attr($0, "name") == target_source); next }
/^<\/sourcefile>/ { in_src = 0; next }
in_src && /^<line / { if (attr($0, "mi") + attr($0, "ci") > 0) print attr($0, "nr"); next }
' > "$tmp_dir/xml-items"

awk -F'|' 'NF == 1 { print $1 }' "$tmp_dir/xml-items" | sort -n -u > "$exec_lines"
awk -F'|' 'NF >= 5 { print }' "$tmp_dir/xml-items" | sort -t'|' -k1,1n > "$methods"
awk 'NR == FNR { executable[$1] = 1; next } executable[$1]' "$exec_lines" "$changed_lines" > "$changed_exec_lines"

if [ ! -s "$changed_exec_lines" ]; then
  if [ ! -s "$methods" ] && [ ! -s "$exec_lines" ]; then
    # 클래스가 리포트에 아예 없다 — 이 모듈 aiTest 가 이 클래스를 측정하지 않는다
    echo "NO_CHANGED_METHODS $label $fqn — class not in report"
  else
    echo "NO_CHANGED_METHODS $label $fqn — changed lines are not executable"
  fi
  exit 0
fi

if [ ! -s "$methods" ]; then
  echo "FAIL $label $fqn — no JaCoCo methods found" >&2
  exit 1
fi

# 변경 줄이 속한 메서드 = 시작 줄이 변경 줄 이하인 메서드 중 다음 메서드 시작 전까지
awk -F'|' '
NR == FNR { changed[$1] = 1; next }
{ n++; start[n] = $1 + 0; row[n] = $0 }
END {
  for (line in changed) {
    for (i = 1; i <= n; i++) {
      next_start = 2147483647
      for (j = i + 1; j <= n; j++) if (start[j] > start[i]) { next_start = start[j]; break }
      if (line + 0 >= start[i] && line + 0 < next_start) selected[row[i]] = 1
    }
  }
  for (i = 1; i <= n; i++) if (selected[row[i]]) print row[i]
}' "$changed_exec_lines" "$methods" > "$selected"

if [ ! -s "$selected" ]; then
  echo "NO_CHANGED_METHODS $label $fqn — executable changes are outside methods"
  exit 0
fi

fail=0
while IFS='|' read -r line name desc missed covered; do
  total=$((missed + covered))
  pct=$((covered * 100 / total))
  name="$(printf '%s' "$name" | sed 's/&lt;/</g; s/&gt;/>/g')"   # <init> · <clinit>
  text="$label $fqn#${name}${desc} line ${line} → ${pct}% (${covered}/${total})"
  if [ "$missed" -eq 0 ]; then
    echo "OK $text"
  else
    echo "FAIL $text" >&2
    fail=1
  fi
done < "$selected"

exit "$fail"
