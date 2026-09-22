#!/usr/bin/env bash
# java-spring-aitest-coverage 스크립트 회귀 테스트 — method-coverage-get.sh · diff-coverage-validate.sh ·
# aitest-coverage-validate.sh(훅). 임시 git 저장소 + 손으로 만든 JaCoCo XML 로 돈다. ./gradlew 는 스텁이다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
M="$PLUGIN_ROOT/scripts/method-coverage-get.sh"
D="$PLUGIN_ROOT/scripts/diff-coverage-validate.sh"
H="$PLUGIN_ROOT/scripts/aitest-coverage-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aitest-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmpdir"; mkdir -p "$TMPDIR"

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
on() { [ "$TC_ON" = 1 ]; }
fail_tc() { on || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { on || return 0; OUT="$("$@" 2>&1)"; CODE=$?; }
run_in() { on || return 0; local input="$1"; shift; OUT="$(printf '%s' "$input" | "$@" 2>&1)"; CODE=$?; }
expect_code() { on || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { on || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { on || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_empty() { on || return 0; [ -z "$OUT" ] || fail_tc "출력이 없어야 합니다"; }

# --- 픽스처 ---------------------------------------------------------------------
# 대상 클래스: bar(5~7) · baz(9~11). 실행 줄 6 · 10.
controller_src() { # $1=패키지 $2=클래스 $3=bar 반환식
  cat <<EOF
package $1;

public class $2 {

    public int bar(int x) {
        return $3;
    }

    public int baz() {
        return 2;
    }
}
EOF
}

# JaCoCo XML 한 줄. $1=출력 $2=패키지 경로 $3=클래스 이름 $4=bar missed $5=baz missed (covered 는 10 - missed)
jacoco_xml() {
  local out="$1" pkg="$2" cls="$3" bm="$4" zm="$5"
  mkdir -p "$(dirname "$out")"
  printf '%s' "<?xml version=\"1.0\"?><report name=\"t\"><package name=\"$pkg\"><class name=\"$pkg/$cls\" sourcefilename=\"$cls.java\"><method name=\"bar\" desc=\"(I)I\" line=\"5\"><counter type=\"INSTRUCTION\" missed=\"$bm\" covered=\"$((10 - bm))\"/></method><method name=\"baz\" desc=\"()I\" line=\"9\"><counter type=\"INSTRUCTION\" missed=\"$zm\" covered=\"$((10 - zm))\"/></method></class><sourcefile name=\"$cls.java\"><line nr=\"6\" mi=\"$bm\" ci=\"$((10 - bm))\" mb=\"0\" cb=\"0\"/><line nr=\"10\" mi=\"$zm\" ci=\"$((10 - zm))\" mb=\"0\" cb=\"0\"/></sourcefile></package></report>" > "$out"
}

REPORT="build/reports/jacoco/aiTestCoverageReport/aiTestCoverageReport.xml"

# 새 저장소. $1=이름 → 경로 출력. 기본 구성: 멀티 모듈 app(aiTestModules) + core, 환경 있음.
repo() {
  local r="$TMP/$1"
  rm -rf "$r"; mkdir -p "$r"
  (
    cd "$r" || exit 1
    git init -q -b main . && git config user.email t@t && git config user.name t
    mkdir -p gradle app/src/main/java/com/ex/app app/src/test/java/com/ex/app core/src/main/java/com/ex/core
    echo "// ai-test" > gradle/ai-test.gradle
    printf "ext.aiTestModules = ['app']\n" > build.gradle
    controller_src com.ex.app FooController 'x + 1' > app/src/main/java/com/ex/app/FooController.java
    controller_src com.ex.core PriceCalculator 'x + 1' > core/src/main/java/com/ex/core/PriceCalculator.java
    printf 'build/\n' > .gitignore
    cat > gradlew <<'EOS'
#!/usr/bin/env bash
echo "$*" >> "${GRADLEW_CALLS:-/dev/null}"
exit "${GRADLEW_RC:-0}"
EOS
    chmod +x gradlew
    git add -A && git commit -qm init
  ) >/dev/null
  echo "$r"
}
change_bar() { controller_src "$2" "$3" 'x + 2' > "$1"; }   # bar 의 6번째 줄만 바꾼다
aitest_for() { # $1=경로 $2=본문에 넣을 단어
  mkdir -p "$(dirname "$1")"
  printf 'package com.ex.app;\n\n@AiTest\nclass %s {\n    // %s\n}\n' "$(basename "$1" .java)" "$2" > "$1"
}
fresh_report() { sleep 1; jacoco_xml "$@"; }                 # mtime 이 소스보다 확실히 뒤가 되게

hook_in() { printf '{"session_id":"%s","stop_hook_active":%s}' "$1" "${2:-false}"; }

flush_tc; echo "== method-coverage-get.sh"

tc TC-M01 "변경 메서드가 100% 면 OK"
if on; then
  R="$(repo m01)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 10
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 0; expect_out "OK app com.ex.app.FooController#bar(I)I line 5 → 100% (10/10)"; expect_not "baz"
fi

tc TC-M02 "변경 메서드가 100% 미만이면 FAIL"
if on; then
  R="$(repo m02)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 3 0
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 1; expect_out "FAIL app com.ex.app.FooController#bar(I)I line 5 → 70% (7/10)"
fi

tc TC-M03 "바뀌지 않은 메서드는 0% 여도 판정하지 않는다"
if on; then
  R="$(repo m03)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 10
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController
  expect_code 0; expect_not "FAIL"
fi

tc TC-M04 "untracked 새 파일은 전 줄을 변경으로 본다"
if on; then
  R="$(repo m04)"; controller_src com.ex.app BarService 'x' > "$R/app/src/main/java/com/ex/app/BarService.java"
  jacoco_xml "$R/app/$REPORT" com/ex/app BarService 0 4
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/BarService.java com.ex.app.BarService
  expect_code 1; expect_out "OK "; expect_out "#baz()I line 9 → 60%"
fi

tc TC-M05 "리포트가 없으면 FAIL"
if on; then
  R="$(repo m05)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController
  expect_code 1; expect_out "missing JaCoCo XML report"
fi

tc TC-M06 "클래스가 리포트에 없으면 측정 대상 아님"
if on; then
  R="$(repo m06)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/other Other 0 0
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController
  expect_code 0; expect_out "class not in report"
fi

tc TC-M07 "같은 이름 클래스가 다른 패키지에 있어도 섞지 않는다"
if on; then
  R="$(repo m07)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/other FooController 5 5
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController
  expect_code 0; expect_out "class not in report"
fi

flush_tc; echo "== diff-coverage-validate.sh"

tc TC-D01 "diff 가 없으면 OK"
if on; then R="$(repo d01)"; CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "no diff"; fi

tc TC-D02 "main Java · mapper · AiTest 밖의 변경만 있으면 OK"
if on; then
  R="$(repo d02)"; echo x > "$R/README.md"
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "no main Java/mapper/AiTest diff"
fi

tc TC-D03 "변경 Controller 에 AiTest 가 없으면 막는다 (C-01)"
if on; then
  R="$(repo d03)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "FooController (com.ex.app.FooController) 을 다루는 *AiTest* 가 없음"
fi

tc TC-D04 "파일명이 <Controller>AiTest 면 인정한다 (C-01)"
if on; then
  R="$(repo d04)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" "MockMvc"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0; expect_out "check-only OK"
fi

tc TC-D05 "본문에 클래스명이 단어로 나오면 인정한다 (C-01)"
if on; then
  R="$(repo d05)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/ApiAiTest.java" "검증 대상: FooController.bar"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0
fi

tc TC-D06 "부분 문자열(FooControllerHelper)은 인정하지 않는다 (C-01)"
if on; then
  R="$(repo d06)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/ApiAiTest.java" "FooControllerHelper"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1
fi

tc TC-D07 "report-only: 리포트가 없으면 막는다 (C-03)"
if on; then
  R="$(repo d07)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "app: JaCoCo 리포트 없음"
fi

tc TC-D08 "report-only: 리포트가 diff 보다 오래되면 막는다 (C-03)"
if on; then
  R="$(repo d08)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 0
  sleep 1; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "FooController.java 가 리포트보다 최신"
fi

tc TC-D09 "report-only: 최신 리포트 + 100% 면 통과한다"
if on; then
  R="$(repo d09)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 10
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "PASS (1 class(es), 1 module(s)"
fi

tc TC-D10 "report-only: 변경 메서드가 100% 미만이면 막는다 (C-02)"
if on; then
  R="$(repo d10)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 2 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "changed method JaCoCo below 100%"; expect_out "80%"
fi

tc TC-D11 "aiTestModules 에 없는 모듈의 main 변경은 판정 대상이 아니다"
if on; then
  R="$(repo d11)"; change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "no verifiable module diff"
fi

tc TC-D12 "libraryModules: 라이브러리 변경을 소비 모듈 리포트로 판정한다"
if on; then
  R="$(repo d12)"; mkdir -p "$R/.claude"; echo '{"libraryModules":{"core":["app"]}}' > "$R/.claude/java-spring-aitest-coverage.json"
  change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  fresh_report "$R/app/$REPORT" com/ex/core PriceCalculator 1 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "FAIL app com.ex.core.PriceCalculator#bar(I)I line 5 → 90%"
fi

tc TC-D13 "libraryModules: 라이브러리 소스가 소비 모듈 리포트보다 새로우면 막는다"
if on; then
  R="$(repo d13)"; mkdir -p "$R/.claude"; echo '{"libraryModules":{"core":["app"]}}' > "$R/.claude/java-spring-aitest-coverage.json"
  jacoco_xml "$R/app/$REPORT" com/ex/core PriceCalculator 0 0
  sleep 1; change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "PriceCalculator.java 가 리포트보다 최신"
fi

tc TC-D14 "단일 모듈 — aiTestModules 가 없으면 루트를 모듈로 본다"
if on; then
  R="$TMP/d14"; rm -rf "$R"; mkdir -p "$R/src/main/java/com/ex" "$R/src/test/java/com/ex" "$R/gradle"
  ( cd "$R" && git init -q -b main . && git config user.email t@t && git config user.name t
    echo "// x" > gradle/ai-test.gradle; echo "plugins { id 'java' }" > build.gradle
    controller_src com.ex FooController 'x + 1' > src/main/java/com/ex/FooController.java
    git add -A && git commit -qm init ) >/dev/null
  change_bar "$R/src/main/java/com/ex/FooController.java" com.ex FooController
  aitest_for "$R/src/test/java/com/ex/FooControllerAiTest.java" x
  fresh_report "$R/$REPORT" com/ex FooController 0 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "OK . com.ex.FooController#bar"
fi

tc TC-D15 "중첩 모듈(apps:api) — 디렉터리 apps/api/ 로 찾는다"
if on; then
  R="$(repo d15)"; mkdir -p "$R/apps/api/src/main/java/com/ex/api"
  printf "ext.aiTestModules = ['apps:api']\n" > "$R/build.gradle"
  controller_src com.ex.api FooController 'x + 1' > "$R/apps/api/src/main/java/com/ex/api/FooController.java"
  ( cd "$R" && git add -A && git commit -qm nested ) >/dev/null
  change_bar "$R/apps/api/src/main/java/com/ex/api/FooController.java" com.ex.api FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "apps:api: FooController"
fi

tc TC-D16 "설정 .modules 가 build.gradle 보다 우선한다"
if on; then
  R="$(repo d16)"; mkdir -p "$R/.claude"; echo '{"modules":["core"]}' > "$R/.claude/java-spring-aitest-coverage.json"
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0; expect_out "no verifiable module diff"
fi

tc TC-D17 "AiTest 만 바뀌면 report-only 는 리포트 최신만 본다"
if on; then
  R="$(repo d17)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "report-only PASS (AiTest-only diff"
fi

tc TC-D18 "실행: main 이 바뀐 모듈은 aiTest 전체를 돌린다"
if on; then
  R="$(repo d18)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  export GRADLEW_CALLS="$TMP/d18.calls"; : > "$GRADLEW_CALLS"
  CLAUDE_PROJECT_DIR="$R" run "$D" HEAD; expect_code 0
  grep -q ':app:compileAiTestJava :app:aiTest' "$GRADLEW_CALLS" || fail_tc "gradlew 호출: $(cat "$GRADLEW_CALLS")"
  grep -q -- '--tests' "$GRADLEW_CALLS" && fail_tc "main 변경인데 --tests 로 좁혔다"
  unset GRADLEW_CALLS
fi

tc TC-D19 "실행: AiTest 만 바뀌면 그 클래스만 --tests 로 돌린다"
if on; then
  R="$(repo d19)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  export GRADLEW_CALLS="$TMP/d19.calls"; : > "$GRADLEW_CALLS"
  CLAUDE_PROJECT_DIR="$R" run "$D" HEAD; expect_code 0
  grep -q -- ':app:aiTest --tests com.ex.app.FooControllerAiTest' "$GRADLEW_CALLS" || fail_tc "gradlew 호출: $(cat "$GRADLEW_CALLS")"
  unset GRADLEW_CALLS
fi

tc TC-D20 "실행: gradlew 가 실패하면 실패로 끝난다"
if on; then
  R="$(repo d20)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  GRADLEW_RC=1 CLAUDE_PROJECT_DIR="$R" run "$D" HEAD; [ "$CODE" != 0 ] || fail_tc "종료 코드 0"
fi

tc TC-D21 "설정 파일이 JSON 이 아니면 실행 오류(2)"
if on; then
  R="$(repo d21)"; mkdir -p "$R/.claude"; echo '{' > "$R/.claude/java-spring-aitest-coverage.json"
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 2; expect_out "파싱 실패"
fi

tc TC-D22 "macOS 기본 bash 3.2 로도 돈다"
if on; then
  if [ -x /bin/bash ] && /bin/bash -c '[ "${BASH_VERSINFO[0]}" -lt 4 ]'; then
    R="$(repo d22)"; mkdir -p "$R/.claude"; echo '{"libraryModules":{"core":["app"]}}' > "$R/.claude/java-spring-aitest-coverage.json"
    change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
    change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
    aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
    fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
    CLAUDE_PROJECT_DIR="$R" run /bin/bash "$D" --report-only HEAD; expect_code 0; expect_out "class not in report"
  else
    OUT="bash 3.2 없음 — 건너뜀"
  fi
fi

flush_tc; echo "== aitest-coverage-validate.sh (훅)"

tc TC-H01 "git 저장소가 아니면 조용히 통과한다"
if on; then mkdir -p "$TMP/nogit"; CLAUDE_PROJECT_DIR="$TMP/nogit" run_in "$(hook_in h01)" "$H"; expect_code 0; expect_empty; fi

tc TC-H02 "이번 요청에서 diff 가 그대로면 막지 않는다 (C-05)"
if on; then
  R="$(repo h02)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h02)" "$H" snapshot
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h02)" "$H"; expect_code 0; expect_empty
fi

tc TC-H03 "요청 중 Controller 를 바꾸고 AiTest 가 없으면 막는다 (C-01)"
if on; then
  R="$(repo h03)"; CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h03)" "$H" snapshot
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h03)" "$H"; expect_code 2; expect_out "완료 보류(java-spring-aitest-coverage)"; expect_out "aitest: skip"
fi

tc TC-H04 "최신 리포트 + 100% 면 통과한다"
if on; then
  R="$(repo h04)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h04)" "$H"; expect_code 0; expect_empty
fi

tc TC-H05 "stop_hook_active 면 허용하고 systemMessage 로 남긴다 (C-08)"
if on; then
  R="$(repo h05)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h05 true)" "$H"; expect_code 0; expect_out '"systemMessage"'; expect_out "트랩 방지"
fi

tc TC-H06 "ACK 면제가 있으면 통과한다 (C-07)"
if on; then
  R="$(repo h06)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  echo 'aitest: skip 주석만 수정' > "$TMPDIR/claude-aitest-h06.ack"
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h06)" "$H"; expect_code 0; expect_empty
fi

tc TC-H07 "환경이 없으면 막지 않고 세션당 한 번만 알린다 (C-06)"
if on; then
  R="$(repo h07)"; rm -f "$R/gradle/ai-test.gradle"; ( cd "$R" && git add -A && git commit -qm noenv ) >/dev/null
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h07)" "$H"; expect_code 0; expect_out "게이트가 꺼져 있습니다"
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h07)" "$H"; expect_code 0; expect_empty
fi

tc TC-H08 "@interface AiTest 만 있어도 환경으로 본다"
if on; then
  R="$(repo h08)"; rm -f "$R/gradle/ai-test.gradle"; mkdir -p "$R/ts/src/main/java/x"
  echo 'public @interface AiTest {}' > "$R/ts/src/main/java/x/AiTest.java"; ( cd "$R" && git add -A && git commit -qm iface ) >/dev/null
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h08)" "$H"; expect_code 2
fi

tc TC-H09 "소비 모듈을 모르는 main 변경에 AiTest diff 가 없으면 막는다 (C-04)"
if on; then
  R="$(repo h09)"; change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h09)" "$H"; expect_code 2; expect_out "소비 모듈을 특정할 수 없는"; expect_out "libraryModules"
fi

tc TC-H10 "소비 모듈을 모르는 main 변경이어도 AiTest diff 가 있으면 통과한다 (C-04)"
if on; then
  R="$(repo h10)"; change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  aitest_for "$R/app/src/test/java/com/ex/app/PriceAiTest.java" PriceCalculator
  fresh_report "$R/app/$REPORT" com/ex/core PriceCalculator 0 0
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h10)" "$H"; expect_code 0
fi

tc TC-H11 "테스트만 바뀌면 막지 않는다"
if on; then
  R="$(repo h11)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h11)" "$H"; expect_code 0; expect_empty
fi

tc TC-H12 "하위 디렉터리에서 호출해도 저장소 루트 기준으로 본다"
if on; then
  R="$(repo h12)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R/app" run_in "$(hook_in h12)" "$H"; expect_code 2
fi

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
echo
[ "$FAIL" = 0 ] || exit 1
