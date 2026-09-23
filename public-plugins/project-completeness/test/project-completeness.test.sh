#!/usr/bin/env bash
# project-completeness.sh 회귀 테스트. 사용: test/project-completeness.test.sh [TC 접두사]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
S="$PLUGIN/scripts/project-completeness.sh"
REF="$PLUGIN/references"
FILTER="${1:-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0

tc() { # $1=ID $2=설명 $3...=명령 (0 이면 통과)
  local id="$1" desc="$2"; shift 2
  case "$id" in "$FILTER"*) ;; *) return ;; esac
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %-7s %s\n' "$id" "$desc"
  else FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %-7s %s\n' "$id" "$desc"; fi
}

# 픽스처 — 이름으로 디렉터리를 만들고 파일을 쓴다
fx() { local d="$WORK/$1"; rm -rf "$d"; mkdir -p "$d"; echo "$d"; }
put() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
src3() { # 소스 판정이 가능하도록 소스 3개 · 2KB 이상
  local d="$1" i
  for i in 1 2 3; do printf 'export const v%s = "%s";\n' "$i" "$(printf '%0800d' 0)" > "$d/src/m$i.js"; done
}
detect() { "$S" detect "$1"; }
passed() { detect "$1" | jq -e --arg i "$2" '.passed | index($i)'; }
failed() { detect "$1" | jq -e --arg i "$2" '.failed | index($i)'; }
unknown() { detect "$1" | jq -e --arg i "$2" '.unknown | index($i)'; }
hint_is() { detect "$1" | jq -e --arg i "$2" --arg p "$3" '.hints[$i] | startswith($p)'; }
ptype() { detect "$1" | jq -e --arg t "$2" '.projectType == $t'; }
ptype_null() { detect "$1" | jq -e '.projectType == null'; }
out_has() { local p="$1" out; shift; out="$("$@" 2>&1)"; grep -Fq -- "$p" <<<"$out"; }   # 파이프로 grep -q 하면 pipefail 에서 SIGPIPE 로 흔들린다
exit_is() { local want="$1"; shift; "$@" >/dev/null 2>&1; [ $? -eq "$want" ]; }

echo "== detect: 프로젝트 타입"
D=$(fx web); echo '{"dependencies":{"react":"18"}}' > "$D/package.json"
tc TC-D01 "react 런타임 의존성 → web-frontend" ptype "$D" web-frontend
D=$(fx api); echo '{"dependencies":{"express":"4"}}' > "$D/package.json"
tc TC-D02 "express → backend-api" ptype "$D" backend-api
D=$(fx full); echo '{"dependencies":{"express":"4","react":"18"}}' > "$D/package.json"
tc TC-D03 "react + express → fullstack" ptype "$D" fullstack
D=$(fx devonly); echo '{"private":true,"dependencies":{},"devDependencies":{"express":"4","react":"18"}}' > "$D/package.json"
tc TC-D04 "devDependencies 의 서버 · UI 는 성격을 바꾸지 않는다" ptype_null "$D"
D=$(fx cli); echo '{"bin":{"x":"x.js"},"dependencies":{}}' > "$D/package.json"
tc TC-D05 "bin 엔트리 → cli" ptype "$D" cli
D=$(fx golib); printf 'module example.com/x\n\ngo 1.22\n' > "$D/go.mod"
tc TC-D06 "go.mod 에 서버 없음 → library" ptype "$D" library
D=$(fx mono); echo '{"private":true,"workspaces":["packages/*"]}' > "$D/package.json"
tc TC-D07 "JS workspaces → monorepo" ptype "$D" monorepo

D=$(fx jvmlib)
put "$D/lib/build.gradle.kts" <<'EOF'
plugins { `java-library`; `maven-publish` }
dependencies { implementation("org.springframework.boot:spring-boot-starter-web") }
EOF
echo 'package x; public class Log {}' | put "$D/lib/src/main/java/x/Log.java"
put "$D/servlet-example/build.gradle.kts" <<'EOF'
dependencies { implementation("org.springframework.boot:spring-boot-starter-web") }
EOF
echo '@SpringBootApplication public class App { public static void main(String[] a) {} }' | put "$D/servlet-example/src/main/java/x/App.java"
tc TC-D08 "java-library + 진입점 없음 → library (example 모듈의 main 은 무시)" ptype "$D" library
D=$(fx jvmapp)
put "$D/build.gradle.kts" <<'EOF'
dependencies { implementation("org.springframework.boot:spring-boot-starter-web") }
EOF
echo '@SpringBootApplication public class App {}' | put "$D/src/main/java/x/App.java"
tc TC-D09 "spring-boot-starter-web + @SpringBootApplication → backend-api" ptype "$D" backend-api
D=$(fx reactor)
put "$D/build.gradle.kts" <<'EOF'
plugins { `java-library` }
dependencies { implementation("io.projectreactor:reactor-core") }
EOF
tc TC-D10 "reactor 의존성을 react UI 로 읽지 않는다" ptype "$D" library

echo "== detect: 구조 판정"
D=$(fx lint); echo '{"private":true}' > "$D/package.json"
put "$D/.github/workflows/ci.yml" <<'EOF'
on: [pull_request]
jobs: { l: { runs-on: ubuntu-latest, steps: [ { run: npx eslint . } ] } }
EOF
tc TC-D11 "CI 에 eslint → code.lint-ci 통과" passed "$D" code.lint-ci
tc TC-D12 "PR 트리거 · 실패 허용 없음 → code.quality-gate 통과" passed "$D" code.quality-gate
D=$(fx nolint); echo '{"private":true}' > "$D/package.json"
put "$D/.github/workflows/ci.yml" <<'EOF'
on: [pull_request]
jobs: { t: { runs-on: ubuntu-latest, continue-on-error: true, steps: [ { run: npm test } ] } }
EOF
tc TC-D13 "린터가 어디에도 없으면 code.lint-ci 미통과" failed "$D" code.lint-ci
tc TC-D14 "continue-on-error: true 면 code.quality-gate 미통과" failed "$D" code.quality-gate

D=$(fx secret-ci); echo x > "$D/README.md"
put "$D/.github/workflows/s.yml" <<'EOF'
jobs: { s: { steps: [ { run: gitleaks detect } ] } }
EOF
tc TC-D15 "시크릿 스캔이 CI 에만 있으면 미통과" failed "$D" security.secret-scan
printf 'repos:\n  - repo: local\n    hooks: [{ id: gitleaks, entry: gitleaks protect }]\n' > "$D/.pre-commit-config.yaml"
tc TC-D16 "pre-commit + CI 양쪽이면 통과" passed "$D" security.secret-scan

D=$(fx tsext); echo '{"private":true}' > "$D/package.json"
echo '{"extends":"@tsconfig/strictest/tsconfig.json"}' > "$D/tsconfig.json"
tc TC-D17 "tsconfig 가 strict 설정을 extends 로 상속 → code.type-strict 통과" passed "$D" code.type-strict
echo '{"extends":"@tsconfig/strictest/tsconfig.json","compilerOptions":{"strict":false}}' > "$D/tsconfig.json"
tc TC-D18 "상속해도 strict: false 로 끄면 미통과" failed "$D" code.type-strict

D=$(fx noiac); echo x > "$D/README.md"
tc TC-D19 "IaC 가 없으면 security.iac-scan 은 판정 보류" unknown "$D" security.iac-scan
echo 'FROM alpine' > "$D/Dockerfile"
tc TC-D20 "Dockerfile 이 있는데 스캔이 없으면 미통과" failed "$D" security.iac-scan

echo "== detect: 흔적"
D=$(fx hintsrc); mkdir -p "$D/src"; src3 "$D"
echo 'export function refund() {}' > "$D/src/pay.js"
tc TC-D21 "소스에 refund → service.payment-failure 흔적 있음" hint_is "$D" service.payment-failure "흔적 있음"
D=$(fx hintdata); mkdir -p "$D/src" "$D/fixtures"; src3 "$D"
echo 'export const words = ["refund"];' > "$D/fixtures/words.js"
tc TC-D22 "fixtures 안의 패턴은 흔적으로 세지 않는다" hint_is "$D" service.payment-failure "흔적 없음"
D=$(fx hinttest); mkdir -p "$D/src"; src3 "$D"
echo 'refund()' > "$D/src/pay.test.js"
tc TC-D23 "테스트 파일 안의 패턴은 소스 흔적이 아니다" hint_is "$D" service.payment-failure "흔적 없음"
D=$(fx tiny); mkdir -p "$D/src"; echo 'refund()' > "$D/src/a.js"
tc TC-D24 "소스가 적으면 흔적 대신 판정 보류" unknown "$D" service.payment-failure

echo "== detect: 경계"
D=$(fx empty)
tc TC-D25 "빈 디렉터리 → 종료 2" exit_is 2 "$S" detect "$D"
tc TC-D26 "디렉터리가 아니면 → 종료 2" exit_is 2 "$S" detect "$WORK/none"
D=$(fx wt); echo x > "$D/README.md"
put "$D/.claude/worktrees/1-x/build.gradle.kts" <<'EOF'
dependencies { implementation("org.springframework.boot:spring-boot-starter-web") }
EOF
tc TC-D27 ".claude/ 아래 워크트리 사본은 보지 않는다" ptype_null "$D"
D=$(fx sp\ ace한글); echo '{"dependencies":{"express":"4"}}' > "$D/package.json"
tc TC-D28 "경로에 공백 · 한글이 있어도 동작한다" ptype "$D" backend-api
consistency() { # 자동 방식 항목은 전부 detect 가 내고, 그 밖은 내지 않는다
  local d; d="$(fx cons)"; echo x > "$d/README.md"
  detect "$d" > "$WORK/cons.json"
  jq -e --slurpfile r "$WORK/cons.json" '
    ($r[0] | .passed + .failed + .unknown + (.hints | keys)) as $det
    | [.categories[].items[]] as $all
    | ([$all[] | select(.mode == "auto") | .id] | sort) == ($det | sort)' "$REF/completeness-checklist.json"
}
tc TC-D29 "체크리스트의 ⚡ 자동 항목 = detect 가 내는 항목" consistency

echo "== scope"
na_count() { jq --arg t "$1" '.projectTypes[$t].na | length' "$REF/completeness-checklist.json"; }
scope_rows() { [ "$("$S" scope --type "$1" | grep -c '^- \[x\]')" -eq $((69 - $(na_count "$1"))) ]; }
tc TC-S01 "--type library 는 N/A 를 뺀 항목만 보인다" scope_rows library
tc TC-S02 "모르는 타입 → 종료 2" exit_is 2 "$S" scope --type spaceship
tc TC-S03 "레시피가 있는 항목에 표시" out_has '`security.secret-scan` 🔑 시크릿 스캔이 pre-commit과 CI 양쪽에 있는가 · 레시피' "$S" scope
tc TC-S04 "--na 로 선언한 항목은 빠진다" eval 'out=$("$S" scope --na code.adr); ! grep -Fq "code.adr" <<<"$out"'

echo "== score"
ALL="$(jq -r '[.categories[].items[].id] | join(",")' "$REF/completeness-checklist.json")"
CRIT="$(jq -r '[.categories[].items[] | select(.critical) | .id] | join(",")' "$REF/completeness-checklist.json")"
tc TC-C01 "전부 통과 → 🟢 안전 · 🏆 포괄" eval 'out=$("$S" score --pass "$ALL"); grep -Fq "🟢 안전" <<<"$out" && grep -Fq "🏆" <<<"$out"'
tc TC-C02 "아무것도 없으면 → 🔴 위험 · ⬜ 최소" eval 'out=$("$S" score); grep -Fq "🔴 위험" <<<"$out" && grep -Fq "⬜ 최소" <<<"$out"'
tc TC-C03 "핵심만 통과 → 🟢 안전 이지만 실천 범위는 좁다" eval 'out=$("$S" score --pass "$CRIT"); grep -Fq "🟢 안전" <<<"$out" && grep -Fq "⬜ 최소" <<<"$out"'
tc TC-C04 "모르는 id → 종료 2" exit_is 2 "$S" score --pass code.typo
tc TC-C05 "사용자 선언 N/A 는 따로 표시한다" out_has "사용자 선언 1개" "$S" score --type library --na code.ai-provenance
tc TC-C06 "타입 N/A 와 겹치는 선언은 사용자 선언으로 세지 않는다" eval 'out=$("$S" score --type library --na ops.slo); ! grep -Fq "사용자 선언" <<<"$out"'
LIBCRIT="$(jq -r '.projectTypes.library.na as $na | [.categories[].items[] | select(.critical) | .id | select(. as $i | $na | index($i) | not)] | join(",")' "$REF/completeness-checklist.json")"
tc TC-C07 "N/A 인 핵심 항목은 위험도에 넣지 않는다 (library)" out_has "🟢 안전" "$S" score --type library --pass "$LIBCRIT"
tc TC-C08 "공백 쉼표 · 앞뒤 공백을 견딘다" out_has "핵심 1/12" "$S" score --pass " code.lint-ci ,,"

echo "== health"
tc TC-H01 "인자 없으면 18지표 목록" eval '[ "$("$S" health | grep -c "^| \`")" -eq 18 ]'
tc TC-H02 "낮을수록 좋은 지표 — cfr 5 → 최상" out_has "🟢 최상 5% 이하" "$S" health cfr=5
tc TC-H03 "낮을수록 좋은 지표 — cfr 16 → 위험" out_has "🔴 위험" "$S" health cfr=16
tc TC-H04 "높을수록 좋은 지표 — slo_attain 94 → 위험" out_has "🔴 위험 SLO 무의미" "$S" health slo_attain=94
tc TC-H05 "높을수록 좋은 지표 — slo_attain 99.5 → 양호" out_has "🔵 양호 근소 미달" "$S" health slo_attain=99.5
tc TC-H06 "모르는 지표 → 종료 2" exit_is 2 "$S" health nope=1
tc TC-H07 "숫자가 아니면 → 종료 2" exit_is 2 "$S" health cfr=abc
tc TC-H08 "재지 않은 지표를 알린다" out_has "재지 않은 지표 17개" "$S" health cfr=5

echo "== recipe"
tc TC-R01 "항목 id 로 찾는다 — 파일 머리말과 함께" eval 'out=$("$S" recipe security.secret-scan); grep -Fq "## gitleaks" <<<"$out" && grep -Fq "# 공통 레시피" <<<"$out"'
tc TC-R02 "이름은 대소문자를 가리지 않는다" out_has "## Knip" "$S" recipe KNIP
tc TC-R03 "없으면 종료 1" exit_is 1 "$S" recipe no-such-tool
tc TC-R05 "머리말에 구분선(---)을 끌고 오지 않는다" eval 'out=$("$S" recipe security.secret-scan); ! grep -qx -- "---" <<<"$out"'
tc TC-R04 "--list 는 레시피마다 한 줄" eval '[ "$("$S" recipe --list | wc -l | tr -d " ")" -eq "$(grep -h "메우는 항목\*\*:" "$REF"/recipe-*.md | wc -l | tr -d " ")" ]'

echo "== 데이터 정합성"
ids_ok() {
  jq -e '[.categories[].items[].id] | length == (unique | length)' "$REF/completeness-checklist.json" &&
  jq -e '[.categories[].items[].id] as $all | [.projectTypes[].na[]] - $all == []' "$REF/completeness-checklist.json"
}
tc TC-X01 "항목 id 가 겹치지 않고 N/A 가 모두 있는 id 다" ids_ok
recipe_ids_ok() {
  local ids; ids="$(grep -h '메우는 항목\*\*:' "$REF"/recipe-*.md | grep -oE '`[a-z]+\.[a-z0-9-]+`' | tr -d '`' | sort -u | jq -R . | jq -sc .)"
  jq -e --argjson r "$ids" '[.categories[].items[].id] as $all | $r - $all == []' "$REF/completeness-checklist.json"
}
tc TC-X02 "레시피가 메운다고 한 id 가 모두 체크리스트에 있다" recipe_ids_ok
recipe_fields_ok() {
  local f
  for f in "$REF"/recipe-*.md; do
    awk '/^## /{ if (n && !(m && v && r)) bad = 1; n = 1; m = v = r = 0 }
         /메우는 항목\*\*:/{ m = 1 } /\*\*검증/{ v = 1 } /\*\*롤백/{ r = 1 }
         END { if (n && !(m && v && r)) bad = 1; exit bad }' "$f" || return 1
  done
}
tc TC-X03 "모든 레시피에 메우는 항목 · 검증 · 롤백이 있다" recipe_fields_ok
crit_doc_ok() {
  local doc json
  doc="$(sed -n '/^### 핵심 항목/,/^핵심 통과율/p' "$REF/completeness-rules.md" | grep -oE '`[a-z]+\.[a-z0-9-]+`' | tr -d '`' | sort | tr '\n' ,)"
  json="$(jq -r '[.categories[].items[] | select(.critical) | .id] | sort | join(",")' "$REF/completeness-checklist.json"),"
  [ "$doc" = "$json" ]
}
tc TC-X04 "규칙 원본의 핵심 항목 = 체크리스트의 critical" crit_doc_ok

echo
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]
