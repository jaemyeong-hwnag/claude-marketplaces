#!/usr/bin/env bash
# java-spring-aitest-coverage 스크립트 회귀 테스트 — method-coverage-get.sh · diff-coverage-validate.sh ·
# aitest-coverage-validate.sh(훅). 임시 git 저장소 + 손으로 만든 JaCoCo XML 로 돈다. ./gradlew · javap 는 스텁이다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
M="$PLUGIN_ROOT/scripts/method-coverage-get.sh"
D="$PLUGIN_ROOT/scripts/diff-coverage-validate.sh"
H="$PLUGIN_ROOT/scripts/aitest-coverage-validate.sh"
E_TMPL="$PLUGIN_ROOT/skills/aitest-environment-create/templates/scripts/ensure-docker-for-aitest.sh.tmpl"
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
  class_file "${out%%/build/reports/*}" "$pkg" "$cls"
}

# javap 스텁 — 클래스 파일 자리에 둔 실제 javap 출력을 그대로 낸다 (JDK 없이 결정적으로 돈다)
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\ncat "${@: -1}"\n' > "$TMP/bin/javap"
chmod +x "$TMP/bin/javap"
export AITEST_JAVAP="$TMP/bin/javap"

# 실제 javap 출력 (JDK 21, javac -g → javap -p -s -l). $1=픽스처
javap_of() {
  case "$1" in
    controller) cat <<'JAVAP'
Compiled from "FooController.java"
public class com.ex.app.FooController {
  public com.ex.app.FooController();
    descriptor: ()V
    LineNumberTable:
      line 3: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/FooController;

  public int bar(int);
    descriptor: (I)I
    LineNumberTable:
      line 6: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/app/FooController;
          0       4     1     x   I

  public int baz();
    descriptor: ()I
    LineNumberTable:
      line 10: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       2     0  this   Lcom/ex/app/FooController;
}
JAVAP
    ;;
    lambda) cat <<'JAVAP'
Compiled from "FooController.java"
public class com.ex.app.FooController {
  public com.ex.app.FooController();
    descriptor: ()V
    LineNumberTable:
      line 5: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/FooController;

  public int bar(java.util.List<java.lang.Integer>, java.util.List<java.lang.Integer>);
    descriptor: (Ljava/util/List;Ljava/util/List;)I
    LineNumberTable:
      line 8: 0
      line 15: 12
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      14     0  this   Lcom/ex/app/FooController;
          0      14     1    xs   Ljava/util/List;
          0      14     2    ys   Ljava/util/List;

  private static void lambda$bar$1(java.util.List, java.lang.Integer);
    descriptor: (Ljava/util/List;Ljava/lang/Integer;)V
    LineNumberTable:
      line 9: 0
      line 10: 5
      line 11: 16
      line 12: 22
      line 14: 31
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      32     0    ys   Ljava/util/List;
          0      32     1     x   Ljava/lang/Integer;
          5      27     2     y   I

  private static void lambda$bar$0(java.lang.Integer);
    descriptor: (Ljava/lang/Integer;)V
    LineNumberTable:
      line 10: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       8     0     z   Ljava/lang/Integer;
}
JAVAP
    ;;
    nested) cat <<'JAVAP'
Compiled from "FooController.java"
class com.ex.app.FooController$Rule {
  com.ex.app.FooController$Rule();
    descriptor: ()V
    LineNumberTable:
      line 12: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/FooController$Rule;

  int apply(int);
    descriptor: (I)I
    LineNumberTable:
      line 14: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/app/FooController$Rule;
          0       4     1     x   I
}
JAVAP
    ;;
  esac
}
# 클래스 파일 자리에 javap 출력을 둔다. $1=모듈 디렉터리 $2=패키지 경로 $3=클래스 [$4=픽스처]
class_file() {
  local dir="$1/build/classes/java/main/$2" fix="${4:-}"
  mkdir -p "$dir"
  if [ -n "$fix" ]; then javap_of "$fix" > "$dir/$3.class"
  else javap_of controller | sed "s/com\.ex\.app\.FooController/${2//\//.}.$3/g; s#com/ex/app/FooController#$2/$3#g" > "$dir/$3.class"; fi
}

# 람다 픽스처 — bar 안 바깥 람다(9~14)가 안쪽 람다(10)를 품는다. 12번째 줄은 바깥 람다의 if 본문이다
lambda_src() { # $1=12번째 줄의 더할 값
  cat <<EOF
package com.ex.app;

import java.util.List;

public class FooController {

    public int bar(List<Integer> xs, List<Integer> ys) {
        xs.forEach(x -> {
            int y = x;
            ys.forEach(z -> System.out.println(z));
            if (y > 100) {
                System.out.println(y + $1);
            }
        });
        return 0;
    }
}
EOF
}
# 위 소스를 실제 JaCoCo 0.8.15 로 잰 리포트. $1=출력 $2=12번째 줄 missed(0 = if 본문까지 실행 · 5 = 실행 안 함)
lambda_xml() {
  local out="$1" m="$2"
  mkdir -p "$(dirname "$out")"
  printf '%s' "<?xml version=\"1.0\"?><report name=\"t\"><package name=\"com/ex/app\"><class name=\"com/ex/app/FooController\" sourcefilename=\"FooController.java\"><method name=\"&lt;init&gt;\" desc=\"()V\" line=\"5\"><counter type=\"INSTRUCTION\" missed=\"0\" covered=\"3\"/></method><method name=\"bar\" desc=\"(Ljava/util/List;Ljava/util/List;)I\" line=\"8\"><counter type=\"INSTRUCTION\" missed=\"0\" covered=\"6\"/></method><method name=\"lambda\$bar\$1\" desc=\"(Ljava/util/List;Ljava/lang/Integer;)V\" line=\"9\"><counter type=\"INSTRUCTION\" missed=\"$m\" covered=\"$((15 - m))\"/></method><method name=\"lambda\$bar\$0\" desc=\"(Ljava/lang/Integer;)V\" line=\"10\"><counter type=\"INSTRUCTION\" missed=\"0\" covered=\"4\"/></method></class><sourcefile name=\"FooController.java\"><line nr=\"5\" mi=\"0\" ci=\"3\" mb=\"0\" cb=\"0\"/><line nr=\"8\" mi=\"0\" ci=\"4\" mb=\"0\" cb=\"0\"/><line nr=\"9\" mi=\"0\" ci=\"3\" mb=\"0\" cb=\"0\"/><line nr=\"10\" mi=\"0\" ci=\"7\" mb=\"0\" cb=\"0\"/><line nr=\"11\" mi=\"0\" ci=\"3\" mb=\"$((m > 0 ? 1 : 0))\" cb=\"$((m > 0 ? 1 : 2))\"/><line nr=\"12\" mi=\"$m\" ci=\"$((5 - m))\" mb=\"0\" cb=\"0\"/><line nr=\"14\" mi=\"0\" ci=\"1\" mb=\"0\" cb=\"0\"/><line nr=\"15\" mi=\"0\" ci=\"2\" mb=\"0\" cb=\"0\"/></sourcefile></package></report>" > "$out"
  class_file "${out%%/build/reports/*}" com/ex/app FooController lambda
}
# 람다 픽스처를 커밋하고 12번째 줄만 바꾼 저장소. $1=이름 → 경로 출력
lambda_repo() {
  local r; r="$(repo "$1")"
  ( cd "$r" && lambda_src 1 > app/src/main/java/com/ex/app/FooController.java && git commit -qam lambda && lambda_src 2 > app/src/main/java/com/ex/app/FooController.java ) >/dev/null
  echo "$r"
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
# 모노레포 — 기본 구성을 backend/ 아래로 옮긴다 (git 루트 ≠ Gradle 루트). $1=이름 → 저장소 경로 출력
mono_repo() {
  local r; r="$(repo "$1")"
  ( cd "$r" && mkdir backend && git mv app core gradle build.gradle gradlew .gitignore backend/ && git commit -qm mono ) >/dev/null
  echo "$r"
}
change_bar() { controller_src "$2" "$3" 'x + 2' > "$1"; }   # bar 의 6번째 줄만 바꾼다
aitest_for() { # $1=경로 $2=본문에 넣을 단어
  mkdir -p "$(dirname "$1")"
  printf 'package com.ex.app;\n\n@AiTest\nclass %s {\n    // %s\n}\n' "$(basename "$1" .java)" "$2" > "$1"
}
fresh_report() { sleep 1; jacoco_xml "$@"; }                 # mtime 이 소스보다 확실히 뒤가 되게

hook_in() { printf '{"session_id":"%s","stop_hook_active":%s}' "$1" "${2:-false}"; }
# jq 만 뺀 PATH — PATH 의 각 디렉터리를 앞에서부터 링크해 같은 이름은 먼저 것이 이긴다
nojq_path() {
  local d nj="$TMP/nojq"
  if [ ! -d "$nj" ]; then
    mkdir -p "$nj"
    local IFS=:; for d in $PATH; do [ -d "$d" ] && ln -s "$d"/* "$nj"/ 2>/dev/null; done
    rm -f "$nj/jq"
  fi
  echo "$nj"
}

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

tc TC-M08 "람다 본문의 변경 줄은 안쪽 람다 뒤에 있어도 그 람다로 판정한다 — 실행되지 않았으면 FAIL (C-02)"
if on; then
  R="$(lambda_repo m08)"; lambda_xml "$R/app/$REPORT" 5
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 1; expect_out "FAIL app com.ex.app.FooController#lambda\$bar\$1(Ljava/util/List;Ljava/lang/Integer;)V line 9 → 66% (10/15)"
  expect_not "lambda\$bar\$0"
fi

tc TC-M09 "람다 본문의 변경 줄을 테스트가 실행해 람다가 100% 면 OK"
if on; then
  R="$(lambda_repo m09)"; lambda_xml "$R/app/$REPORT" 0
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 0; expect_out "OK app com.ex.app.FooController#lambda\$bar\$1(Ljava/util/List;Ljava/lang/Integer;)V line 9 → 100% (15/15)"
fi

tc TC-M10 "중첩 클래스의 변경 줄은 그 클래스의 메서드로 판정한다 (C-02)"
if on; then
  R="$(repo m10)"; F="$R/app/src/main/java/com/ex/app/FooController.java"
  { controller_src com.ex.app FooController 'x + 1' | sed '$d'; printf '    static class Rule {\n        int apply(int x) {\n            return x * 2;\n        }\n    }\n}\n'; } > "$F.new"
  mv "$F.new" "$F"; git -C "$R" commit -qam nested; sed -i.bak 's/x \* 2/x * 3/' "$F"; rm -f "$F.bak"
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 0
  sed -i.bak 's#</class><sourcefile#</class><class name="com/ex/app/FooController$Rule" sourcefilename="FooController.java"><method name="apply" desc="(I)I" line="14"><counter type="INSTRUCTION" missed="4" covered="0"/></method></class><sourcefile#; s#</sourcefile>#<line nr="14" mi="4" ci="0" mb="0" cb="0"/></sourcefile>#' "$R/app/$REPORT"; rm -f "$R/app/$REPORT.bak"
  class_file "$R/app" com/ex/app 'FooController$Rule' nested
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 1; expect_out "FAIL app com.ex.app.FooController\$Rule#apply(I)I line 14 → 0% (0/4)"; expect_not "#bar"
fi

tc TC-M11 "javap 이 없으면 판정 불가(2)로 끝난다 (C-09)"
if on; then
  R="$(repo m11)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 0
  AITEST_JAVAP="$TMP/no-javap" CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 2; expect_out "javap 이 없어"
fi

tc TC-M12 "리포트에 나온 클래스의 클래스 파일이 없으면 판정 불가(2)로 끝난다 (C-09)"
if on; then
  R="$(repo m12)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 0; rm -f "$R/app/build/classes/java/main/com/ex/app/FooController.class"
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/FooController.java com.ex.app.FooController app
  expect_code 2; expect_out "클래스 파일 없음"
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
  class_file "$R/core" com/ex/core PriceCalculator
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

tc TC-D23 "git 루트 ≠ Gradle 루트 — 변경 메서드가 100% 미만이면 막는다 (C-02)"
if on; then
  R="$(mono_repo d23)"; B="$R/backend"
  change_bar "$B/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$B/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$B/app/$REPORT" com/ex/app FooController 10 0
  CLAUDE_PROJECT_DIR="$B" run "$D" --report-only HEAD; expect_code 1; expect_out "FAIL app com.ex.app.FooController#bar(I)I"
fi

tc TC-D24 "git 루트 ≠ Gradle 루트 — 최신 리포트 + 100% 면 통과한다"
if on; then
  R="$(mono_repo d24)"; B="$R/backend"
  change_bar "$B/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$B/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$B/app/$REPORT" com/ex/app FooController 0 0
  CLAUDE_PROJECT_DIR="$B" run "$D" --report-only HEAD; expect_code 0; expect_out "changed method coverage 100%"
fi

tc TC-D25 "지운 Controller 는 C-01 대상이 아니다"
if on; then
  R="$(repo d25)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  ( cd "$R" && git add -A && git commit -qm t && git rm -q app/src/main/java/com/ex/app/FooController.java app/src/test/java/com/ex/app/FooControllerAiTest.java ) >/dev/null
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_not "FAIL"
fi

tc TC-D26 "Controller 를 지우며 다른 Controller 를 바꾸면 그 Controller 는 막는다 (C-01)"
if on; then
  R="$(repo d26)"; controller_src com.ex.app BarController 'x' > "$R/app/src/main/java/com/ex/app/BarController.java"
  ( cd "$R" && git add -A && git commit -qm bar && git rm -q app/src/main/java/com/ex/app/FooController.java ) >/dev/null
  change_bar "$R/app/src/main/java/com/ex/app/BarController.java" com.ex.app BarController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "BarController"; expect_not "FooController"
fi

tc TC-D27 "모듈 디렉터리에서 연 세션도 Gradle 루트 기준으로 보고 100% 미만을 막는다 (C-02)"
if on; then
  R="$(repo d27)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 10 0
  CLAUDE_PROJECT_DIR="$R/app" run "$D" --report-only HEAD; expect_code 1; expect_out "FAIL app com.ex.app.FooController#bar(I)I"
fi

tc TC-D28 "--also: 그 ref 와 같은 파일은 보지 않는다"
if on; then
  R="$(repo d28)"; git -C "$R" branch other
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qam remote; git -C "$R" branch -f other HEAD; git -C "$R" reset -q --hard HEAD~1; git -C "$R" merge -q --no-ff --no-edit other
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only --also other HEAD~1; expect_code 0; expect_out "no diff vs HEAD~1"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD~1; expect_code 1; expect_out "FooController"
fi

tc TC-D29 "판정 도구(javap)가 없으면 실행 오류(2)로 끝난다 (C-09)"
if on; then
  R="$(repo d29)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  AITEST_JAVAP="$TMP/no-javap" CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 2; expect_out "변경 메서드를 판정할 수 없습니다 (C-09)"
fi

tc TC-D30 "report-only: 람다 본문의 변경 줄을 실행하지 않았으면 막고, 실행해 100% 면 통과한다 (C-02)"
if on; then
  R="$(lambda_repo d30)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  sleep 1; lambda_xml "$R/app/$REPORT" 5
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "lambda\$bar\$1"
  sleep 1; lambda_xml "$R/app/$REPORT" 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "PASS (1 class(es), 1 module(s)"
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

tc TC-H13 "요청 안에서 커밋한 Controller 변경도 본다 (C-05)"
if on; then
  R="$(repo h13)"; CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h13)" "$H" snapshot
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qam change
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h13)" "$H"; expect_code 2; expect_out "완료 보류(java-spring-aitest-coverage)"
fi

tc TC-H14 "요청 시작 때 원격 기본 브랜치에 있던 커밋은 요청 안에서 합쳐도 이번 변경이 아니다 (C-05)"
if on; then
  R="$(repo h14)"; git init -q --bare -b main "$TMP/h14-origin.git"
  git -C "$R" remote add origin "$TMP/h14-origin.git"; git -C "$R" push -q -u origin main
  git clone -q -b main "$TMP/h14-origin.git" "$TMP/h14-other"
  change_bar "$TMP/h14-other/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$TMP/h14-other" -c user.email=o@o -c user.name=o commit -qam other; git -C "$TMP/h14-other" push -q origin main
  git -C "$R" fetch -q
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h14)" "$H" snapshot
  git -C "$R" merge -q --ff-only origin/main
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h14)" "$H"; expect_code 0; expect_empty
fi

tc TC-H15 "요청 안에서 커밋하고 원격 기본 브랜치로 push 해도 막는다 (C-05)"
if on; then
  R="$(repo h15)"; git -C "$R" update-ref refs/remotes/origin/main HEAD
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h15)" "$H" snapshot
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qam change; git -C "$R" update-ref refs/remotes/origin/main HEAD
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h15)" "$H"; expect_code 2; expect_out "완료 보류(java-spring-aitest-coverage)"
fi

tc TC-H16 "요청 시작 HEAD 를 amend 해도 막는다 (C-05)"
if on; then
  R="$(repo h16)"; echo y > "$R/README"; git -C "$R" add README; git -C "$R" commit -qm second
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h16)" "$H" snapshot
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qa --amend -m second2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h16)" "$H"; expect_code 2; expect_out "완료 보류(java-spring-aitest-coverage)"
fi

tc TC-H17 "amend 가 대상 경로를 건드리지 않으면 막지 않는다 (C-05)"
if on; then
  R="$(repo h17)"; echo y > "$R/README"; git -C "$R" add README; git -C "$R" commit -qm second
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h17)" "$H" snapshot
  git -C "$R" commit -q --amend -m second2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h17)" "$H"; expect_code 0; expect_empty
fi

tc TC-H18 "git 루트 ≠ Gradle 루트 — Gradle 루트의 환경으로 게이트를 켜고 0% 를 막는다 (C-02 · C-06)"
if on; then
  R="$(mono_repo h18)"; B="$R/backend"
  CLAUDE_PROJECT_DIR="$B" run_in "$(hook_in h18)" "$H" snapshot
  change_bar "$B/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$B/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$B/app/$REPORT" com/ex/app FooController 10 0
  CLAUDE_PROJECT_DIR="$B" run_in "$(hook_in h18)" "$H"; expect_code 2; expect_out "below 100%"
fi

tc TC-H19 "Controller 와 그 AiTest 를 지우면 막지 않는다 (C-01)"
if on; then
  R="$(repo h19)"; aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  git -C "$R" add -A; git -C "$R" commit -qm t
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h19)" "$H" snapshot
  git -C "$R" rm -q app/src/main/java/com/ex/app/FooController.java app/src/test/java/com/ex/app/FooControllerAiTest.java
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h19)" "$H"; expect_code 0; expect_empty
fi

tc TC-H20 "모듈 디렉터리에서 연 세션이 그 밖의 모듈을 고쳐도 본다 (C-04)"
if on; then
  R="$(repo h20)"; CLAUDE_PROJECT_DIR="$R/app" run_in "$(hook_in h20)" "$H" snapshot
  change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  CLAUDE_PROJECT_DIR="$R/app" run_in "$(hook_in h20)" "$H"; expect_code 2; expect_out "core/src/main/java/com/ex/core/PriceCalculator.java"
fi

tc TC-H21 "요청 전에 커밋한 Controller 를 요청 안에서 메시지만 amend 하면 막지 않는다 (C-05)"
if on; then
  R="$(repo h21)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qam before; git -C "$R" update-ref refs/remotes/origin/main HEAD~1
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h21)" "$H" snapshot
  git -C "$R" commit -q --amend -m before2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h21)" "$H"; expect_code 0; expect_empty
fi

tc TC-H22 "요청 전 Controller 커밋을 amend 하며 대상 밖 파일만 더하면 막지 않는다 (C-05)"
if on; then
  R="$(repo h22)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qam before; git -C "$R" update-ref refs/remotes/origin/main HEAD~1
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h22)" "$H" snapshot
  echo r > "$R/README"; git -C "$R" add README; git -C "$R" commit -q --amend -m before2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h22)" "$H"; expect_code 0; expect_empty
fi

tc TC-H23 "요청 전 받아둔 원격 위로 요청 안에서 리베이스하면 원격 변경도 이전 커밋도 막지 않는다 (C-05)"
if on; then
  R="$(repo h23)"; git -C "$R" checkout -qb feat
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController; git -C "$R" commit -qam feat
  git -C "$R" checkout -q main; change_bar "$R/core/src/main/java/com/ex/core/PriceCalculator.java" com.ex.core PriceCalculator
  git -C "$R" commit -qam remote; git -C "$R" update-ref refs/remotes/origin/main HEAD; git -C "$R" checkout -q feat
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h23)" "$H" snapshot
  git -C "$R" rebase -q origin/main
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h23)" "$H"; expect_code 0; expect_empty
fi

tc TC-H24 "요청 전 받아둔 원격을 요청 안에서 merge 커밋으로 합쳐도 원격 변경은 막지 않는다 (C-05)"
if on; then
  R="$(repo h24)"; git -C "$R" checkout -qb feat; git -C "$R" commit -q --allow-empty -m e; git -C "$R" checkout -q main
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  git -C "$R" commit -qam remote; git -C "$R" update-ref refs/remotes/origin/main HEAD; git -C "$R" checkout -q feat
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h24)" "$H" snapshot
  git -C "$R" merge -q --no-edit origin/main
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h24)" "$H"; expect_code 0; expect_empty
fi

tc TC-H25 "jq 가 없어도 막는다"
if on; then
  R="$(repo h25)"; NJ="$(nojq_path)"; PATH="$NJ" command -v jq >/dev/null && fail_tc "PATH 에 jq 가 남아 있음"
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h25)" "$H" snapshot
  change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h25)" "$H"; expect_code 2; expect_out "완료 보류(java-spring-aitest-coverage)"
fi

tc TC-H26 "jq 가 없어도 stop_hook_active 를 읽고 systemMessage 를 올바른 JSON 으로 낸다 (C-08)"
if on; then
  R="$(repo h26)"; NJ="$(nojq_path)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in '{ "session_id" : "h26", "stop_hook_active" : true }' "$H"; expect_code 0
  printf '%s' "$OUT" | jq -er .systemMessage | grep -qF "트랩 방지" || fail_tc "systemMessage JSON 이 아니거나 내용이 다름"
  rm -f "$R/gradle/ai-test.gradle"; ( cd "$R" && git add -A gradle && git commit -qm noenv ) >/dev/null
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h26)" "$H"; expect_code 0
  printf '%s' "$OUT" | jq -er .systemMessage | grep -qF '"AiTest 환경 만들어줘"' || fail_tc "환경 없음 systemMessage 의 따옴표가 깨짐"
fi

tc TC-H27 "판정 도구(javap)가 없으면 막는다 (C-09)"
if on; then
  R="$(repo h27)"; change_bar "$R/app/src/main/java/com/ex/app/FooController.java" com.ex.app FooController
  aitest_for "$R/app/src/test/java/com/ex/app/FooControllerAiTest.java" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  AITEST_JAVAP="$TMP/no-javap" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h27)" "$H"; expect_code 2; expect_out "C-09"
fi

tc TC-H28 "훅 스크립트에 디렉터리 검증기가 막는 표기가 없다 — here-document · \$'…' · 리다이렉션이 아닌 > · 큰따옴표 안 \${…} 안의 겹친 따옴표"
if on; then
  body="$(grep -n '' "$H" | grep -v '^[0-9]*:[[:space:]]*#')"
  bad="$(printf '%s\n' "$body" | grep -E '<<-?[[:space:]]*['"'"'"]?[A-Za-z_]' || true)"
  [ -z "$bad" ] || fail_tc "here-document: $bad"
  bad="$(printf '%s\n' "$body" | grep -E "(^|[^A-Za-z0-9_])\\\$'" | grep -v '^[0-9]*:C_TAB=' || true)"
  [ -z "$bad" ] || fail_tc "\$'…': $bad"
  bad="$(printf '%s\n' "$body" | sed -E 's/[0-9]?>&[0-9]//g; s#[0-9]?>>?[[:space:]]*/dev/null##g; s#[0-9]?>>?[[:space:]]*"\$[A-Za-z0-9_{]##g' | grep '>' || true)"
  [ -z "$bad" ] || fail_tc "리다이렉션이 아닌 >: $bad"
  bad="$(printf '%s\n' "$body" | grep -E '"\$\{[^}]*"|"\$\(.*\$\{[^}]*"' || true)"
  [ -z "$bad" ] || fail_tc "큰따옴표 안 \${…} 안 따옴표: $bad"
fi

flush_tc; echo "== ensure-docker-for-aitest.sh (템플릿)"

# 템플릿을 채우고 docker · colima · open 을 호출만 남기는 스텁으로 바꾼다. $1=이름 $2=데몬이 처음부터 떠 있으면 1 → 디렉터리 출력
ensure_env() {
  local e="$TMP/$1"
  rm -rf "$e"; mkdir -p "$e/bin" "$e/home"
  sed 's/{{IMAGES}}/  "mysql:8.0"/' "$E_TMPL" > "$e/ensure.sh"; chmod +x "$e/ensure.sh"
  [ "${2:-0}" = 1 ] && : > "$e/up"
  printf '#!/bin/sh\necho "docker $*" >> "%s/calls"\ncase "$1" in info) [ -f "%s/up" ];; *) exit 0;; esac\n' "$e" "$e" > "$e/bin/docker"
  printf '#!/bin/sh\necho "colima $*" >> "%s/calls"\ncase "$1" in status) exit 1;; start) : > "%s/up";; esac\n' "$e" "$e" > "$e/bin/colima"
  printf '#!/bin/sh\necho "open $*" >> "%s/calls"\n' "$e" > "$e/bin/open"
  chmod +x "$e/bin/"*
  echo "$e"
}

tc TC-E01 "데몬이 이미 응답하면 기동 · context 변경 · ~/.testcontainers.properties 수정을 하지 않는다"
if on; then
  E="$(ensure_env e01 1)"
  HOME="$E/home" PATH="$E/bin:$PATH" AITEST_DOCKER_WAIT_SEC=4 run "$E/ensure.sh"; expect_code 0
  OUT="$(cat "$E/calls")"; expect_not "colima start"; expect_not "docker context"; expect_not "open "; expect_out "docker run --rm hello-world"
  [ -e "$E/home/.testcontainers.properties" ] && fail_tc "~/.testcontainers.properties 가 생겼음"
fi

tc TC-E02 "데몬이 없으면 colima 를 띄우고 reuse 설정을 만든다"
if on; then
  E="$(ensure_env e02 0)"
  HOME="$E/home" PATH="$E/bin:$PATH" AITEST_DOCKER_WAIT_SEC=4 run "$E/ensure.sh"; expect_code 0
  grep -q 'reuse.enable=true' "$E/home/.testcontainers.properties" 2>/dev/null || fail_tc "reuse 설정이 없음"
  OUT="$(cat "$E/calls")"; expect_out "colima start"; expect_out "docker context use colima"
fi

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
echo
[ "$FAIL" = 0 ] || exit 1
