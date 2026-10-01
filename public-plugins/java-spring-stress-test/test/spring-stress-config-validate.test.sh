#!/usr/bin/env bash
# scripts/spring-stress-config-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/spring-stress-config-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/spring-stress-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
# 프로젝트 디렉터리를 지정해 훅을 부른다
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처 ------------------------------------------------------------------
# 규칙을 지키는 프로젝트. TC 마다 복사해 한 곳만 깨뜨린다
CLEAN="$TMP/clean"
mkdir -p "$CLEAN/src/main/resources" "$CLEAN/src/jmh/java/demo"
cat > "$CLEAN/build.gradle" <<'G'
plugins {
  id 'org.springframework.boot' version '3.5.16'
  id 'me.champeau.jmh' version '0.7.3'
}
dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-web'
  implementation 'org.springframework.boot:spring-boot-starter-actuator'
  runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
  developmentOnly 'org.springframework.boot:spring-boot-devtools'
}
jmh {
  fork = 2
}
G
cat > "$CLEAN/src/main/resources/application.properties" <<'P'
logging.level.root=INFO
management.metrics.distribution.percentiles-histogram.http.server.requests=true
server.tomcat.mbeanregistry.enabled=true
spring.jpa.show-sql=false
P
cat > "$CLEAN/Dockerfile" <<'D'
FROM eclipse-temurin:21-jre
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app.jar"]
D
cat > "$CLEAN/src/jmh/java/demo/PriceBench.java" <<'J'
package demo;

@Fork(2)
public class PriceBench {}
J

proj() { # $1=이름 → 깨끗한 프로젝트 복사본 경로
  rm -rf "$TMP/$1"; cp -R "$CLEAN" "$TMP/$1"; printf '%s' "$TMP/$1"
}
props() { printf '%s' "$1/src/main/resources/application.properties"; }
bash_payload() { jq -n --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

echo "java-spring-stress-test 회귀 테스트"

# --- A. CLI 조항 ---------------------------------------------------------------
tc TC-S01 "규칙을 지킨 프로젝트는 조용히 통과한다"
run "$CLEAN"; expect_code 0; expect_no_out

tc TC-S02 "devtools 가 implementation 이면 경고한다 (SPR-01)"
p="$(proj s02)"; sed -i.bak "s/developmentOnly 'org.springframework.boot:spring-boot-devtools'/implementation 'org.springframework.boot:spring-boot-devtools'/" "$p/build.gradle"
run "$p"; expect_code 0; expect_out "⚠️ SPR-01 build.gradle:9"

tc TC-S03 "devtools 가 developmentOnly · 주석 · Maven optional 이면 경고하지 않는다 (SPR-01 과잉 경고 방지)"
p="$(proj s03)"; printf "// implementation 'org.springframework.boot:spring-boot-devtools'\n" >> "$p/build.gradle"
cat > "$p/pom.xml" <<'X'
<project><dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <optional>true</optional>
  </dependency>
</dependencies></project>
X
run "$p"; expect_code 0; expect_not "SPR-01"

tc TC-S04 "Maven devtools 에 optional 이 없으면 경고한다 (SPR-01)"
p="$(proj s04)"; cat > "$p/pom.xml" <<'X'
<project><dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
  </dependency>
</dependencies></project>
X
run "$p"; expect_code 0; expect_out "⚠️ SPR-01 pom.xml:2"

tc TC-S05 "logging.level.root=DEBUG · TRACE 를 막는다 — properties · yml 둘 다 (SPR-02)"
p="$(proj s05)"; sed -i.bak 's/logging.level.root=INFO/logging.level.root=DEBUG/' "$(props "$p")"
run "$p"; expect_code 2; expect_out "❌ SPR-02"; expect_out "logging.level.root=DEBUG"
p="$(proj s05y)"; printf 'logging:\n  level:\n    root: "trace"   # 임시\n' > "$p/src/main/resources/application.yml"
run "$p"; expect_code 2; expect_out "❌ SPR-02 src/main/resources/application.yml"

tc TC-S06 "root 가 아닌 패키지 DEBUG · dev/local/test 프로필 · src/test 는 막지 않는다 (SPR-02 과잉 차단 방지)"
p="$(proj s06)"; printf 'logging.level.com.example=DEBUG\nlogging.level.org.springframework.web=DEBUG\n' >> "$(props "$p")"
printf 'logging.level.root=DEBUG\n' > "$p/src/main/resources/application-local.properties"
printf 'logging:\n  level:\n    root: TRACE\n' > "$p/src/main/resources/application-dev.yml"
mkdir -p "$p/src/test/resources"; printf 'logging.level.root=DEBUG\n' > "$p/src/test/resources/application.properties"
run "$p"; expect_code 0; expect_no_out

tc TC-S07 "debug=true · trace=true 를 경고한다 (SPR-03)"
p="$(proj s07)"; printf 'debug=true\n' >> "$(props "$p")"; printf 'trace: true\n' > "$p/src/main/resources/application-prod.yml"
run "$p"; expect_code 0; expect_out "⚠️ SPR-03 src/main/resources/application.properties: debug=true"; expect_out "application-prod.yml: trace=true"

tc TC-S08 "debug=false · 다른 키 아래 debug 는 경고하지 않는다 (SPR-03 과잉 경고 방지)"
p="$(proj s08)"; printf 'debug=false\n' >> "$(props "$p")"; printf 'feature:\n  debug: true\n' > "$p/src/main/resources/application.yml"
run "$p"; expect_code 0; expect_no_out

tc TC-S09 "show-sql · showSql · hibernate.show_sql 을 경고한다 (SPR-04)"
p="$(proj s09)"; sed -i.bak 's/spring.jpa.show-sql=false/spring.jpa.showSql=true/' "$(props "$p")"
printf 'spring:\n  jpa:\n    properties:\n      hibernate:\n        show_sql: true\n' > "$p/src/main/resources/application.yml"
run "$p"; expect_code 0; expect_out "⚠️ SPR-04 src/main/resources/application.properties: spring.jpa.show-sql=true"
expect_out "spring.jpa.properties.hibernate.show_sql=true"

tc TC-S10 "Prometheus 레지스트리가 있는데 히스토그램이 없으면 경고한다 (SPR-05)"
p="$(proj s10)"; sed -i.bak '/percentiles-histogram/d' "$(props "$p")"
run "$p"; expect_code 0; expect_out "⚠️ SPR-05"

tc TC-S11 "히스토그램이 all · http 접두사 · yml 로 켜졌거나 레지스트리가 없으면 경고하지 않는다 (SPR-05 과잉 경고 방지)"
p="$(proj s11)"; sed -i.bak 's/percentiles-histogram.http.server.requests=true/percentiles-histogram.all=true/' "$(props "$p")"
run "$p"; expect_not "SPR-05"
p="$(proj s11b)"; sed -i.bak '/percentiles-histogram/d' "$(props "$p")"
printf 'management:\n  metrics:\n    distribution:\n      percentiles-histogram:\n        "[http.server.requests]": true\n' > "$p/src/main/resources/application.yml"
run "$p"; expect_not "SPR-05"
p="$(proj s11c)"; sed -i.bak '/percentiles-histogram/d' "$(props "$p")"; sed -i.bak '/micrometer-registry-prometheus/d' "$p/build.gradle"
run "$p"; expect_code 0; expect_no_out

tc TC-S12 "percentiles.* 를 쓰면 경고한다 (SPR-06)"
p="$(proj s12)"; printf 'management.metrics.distribution.percentiles.http.server.requests=0.95,0.99\n' >> "$(props "$p")"
run "$p"; expect_code 0; expect_out "⚠️ SPR-06"

tc TC-S13 "slo · percentiles-histogram 는 SPR-06 으로 보지 않는다 (SPR-06 과잉 경고 방지)"
p="$(proj s13)"; printf 'management.metrics.distribution.slo.http.server.requests=100ms,300ms\n' >> "$(props "$p")"
run "$p"; expect_code 0; expect_no_out

tc TC-S14 "actuator + web 인데 mbeanregistry 가 없으면 경고한다 (SPR-07)"
p="$(proj s14)"; sed -i.bak '/mbeanregistry/d' "$(props "$p")"
run "$p"; expect_code 0; expect_out "⚠️ SPR-07"

tc TC-S15 "Jetty · WebFlux 만 · actuator 없음이면 경고하지 않는다 (SPR-07 과잉 경고 방지)"
p="$(proj s15)"; sed -i.bak '/mbeanregistry/d' "$(props "$p")"; printf "dependencies { implementation 'org.springframework.boot:spring-boot-starter-jetty' }\n" >> "$p/build.gradle"
run "$p"; expect_not "SPR-07"
p="$(proj s15b)"; sed -i.bak '/mbeanregistry/d' "$(props "$p")"; sed -i.bak 's/spring-boot-starter-web/spring-boot-starter-webflux/' "$p/build.gradle"
run "$p"; expect_not "SPR-07"
p="$(proj s15c)"; sed -i.bak '/mbeanregistry/d' "$(props "$p")"; sed -i.bak '/starter-actuator/d' "$p/build.gradle"
run "$p"; expect_not "SPR-07"

tc TC-S16 "가상 스레드 + server.tomcat.threads.max 를 경고한다 (SPR-08)"
p="$(proj s16)"; printf 'spring.threads.virtual.enabled=true\nserver.tomcat.threads.max=400\n' >> "$(props "$p")"
run "$p"; expect_code 0; expect_out "⚠️ SPR-08"

tc TC-S17 "가상 스레드만 · threads.max 만 있으면 경고하지 않는다 (SPR-08 과잉 경고 방지)"
p="$(proj s17)"; printf 'spring.threads.virtual.enabled=true\n' >> "$(props "$p")"
run "$p"; expect_no_out
p="$(proj s17b)"; printf 'server.tomcat.threads.max=400\n' >> "$(props "$p")"
run "$p"; expect_no_out

tc TC-S18 "Dockerfile 이 힙 상한 없이 java 를 띄우면 경고한다 (SPR-09)"
p="$(proj s18)"; printf 'FROM eclipse-temurin:21-jre\nENTRYPOINT ["java", "-jar", "/app.jar"]\n' > "$p/Dockerfile"
run "$p"; expect_code 0; expect_out "⚠️ SPR-09 Dockerfile"

tc TC-S19 "Xmx · JAVA_TOOL_OPTIONS 의 MaxRAMPercentage · java 없는 Dockerfile 은 경고하지 않는다 (SPR-09 과잉 경고 방지)"
p="$(proj s19)"; printf 'FROM eclipse-temurin:21-jre\nENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"\nENTRYPOINT ["java", "-jar", "/app.jar"]\n' > "$p/Dockerfile"
printf 'FROM nginx\nCMD ["nginx"]\n' > "$p/web.Dockerfile"
run "$p"; expect_code 0; expect_no_out

tc TC-S20 "JMH @Fork(0) · @Fork(value = 0) · jmh { fork = 0 } 을 막는다 (SPR-10)"
p="$(proj s20)"; printf 'package demo;\n\n@Fork(value = 0, warmups = 1)\npublic class A {}\n' > "$p/src/jmh/java/demo/A.java"
printf 'package demo;\n@Fork(0)\nclass B {}\n' > "$p/src/jmh/java/demo/B.java"
sed -i.bak 's/fork = 2/fork = 0/' "$p/build.gradle"
run "$p"; expect_code 2; expect_out "❌ SPR-10 src/jmh/java/demo/A.java:3"; expect_out "B.java:2"; expect_out "build.gradle:12"

tc TC-S21 "@Fork(1) · @Fork(10) · fork = 2 는 막지 않는다 (SPR-10 과잉 차단 방지)"
p="$(proj s21)"; printf '@Fork(1)\nclass A {}\n@Fork(value = 10)\nclass B {}\n' > "$p/src/jmh/java/demo/A.java"
run "$p"; expect_code 0; expect_no_out

tc TC-S22 "build · target · .gradle · node_modules 아래는 보지 않는다"
p="$(proj s22)"; mkdir -p "$p/build/resources/main" "$p/target/classes" "$p/.gradle/x"
printf 'logging.level.root=DEBUG\n' > "$p/build/resources/main/application.properties"
printf 'logging.level.root=DEBUG\n' > "$p/target/classes/application.properties"
run "$p"; expect_code 0; expect_no_out

tc TC-S23 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
mkdir -p "$TMP/r/.claude/worktrees"; rm -rf "$TMP/r/.claude/worktrees/w"; cp -R "$CLEAN" "$TMP/r/.claude/worktrees/w"
sed -i.bak 's/logging.level.root=INFO/logging.level.root=DEBUG/' "$TMP/r/.claude/worktrees/w/src/main/resources/application.properties"
run "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "SPR-02"
run "$TMP/r"; expect_code 0

tc TC-S24 "디렉터리가 아니면 오류 1"
run "$TMP/none"; expect_code 1

# --- B. 훅 -------------------------------------------------------------------
BAD="$(proj hookbad)"; sed -i.bak 's/logging.level.root=INFO/logging.level.root=DEBUG/' "$(props "$BAD")"

tc TC-S30 "k6 run 이면 위반을 additionalContext 로 알리고 통과한다"
run_hook "$BAD" "$(bash_payload 'cd load && k6 run --summary-export out.json script.js')"; expect_code 0
expect_out '"additionalContext"'; expect_out "SPR-02"; expect_out "java-spring-stress-test"

tc TC-S31 "다른 부하 도구와 docker run grafana/k6 도 알린다"
for c in 'locust -f locustfile.py --headless' 'jmeter -n -t plan.jmx' 'wrk -t4 -c64 -d30s http://localhost:8080/' \
  'echo "GET http://localhost:8080" | vegeta attack -rate=100 -duration=10s' 'hey -z 10s http://localhost:8080' 'ab -n 1000 http://localhost:8080/' \
  'oha -z 10s http://localhost:8080' 'npx artillery run test.yml' 'npx autocannon -d 10 http://localhost:8080' \
  './gradlew gatlingRun' 'K6_WEB_DASHBOARD=true k6 run s.js' 'docker run --rm -i --network host grafana/k6 run - <s.js'; do
  run_hook "$BAD" "$(bash_payload "$c")"
  [ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | grep -qF "SPR-02" || fail_tc "알리지 않음: $c"; }
done

tc TC-S32 "부하 도구가 아닌 명령은 조용히 통과한다"
for c in 'ls -la' 'git commit -m "k6 run 추가"' './gradlew bootJar' 'cat ab.txt' 'grep -rn wrk .' 'docker run --rm eclipse-temurin:21 java -version' 'echo hey'; do
  run_hook "$BAD" "$(bash_payload "$c")"
  [ "$TC_ON" = 1 ] && { [ "$CODE" = 0 ] && [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됨: $c → $OUT"; }
done

tc TC-S33 "부하 명령이어도 프로젝트가 깨끗하면 조용히 통과한다"
run_hook "$CLEAN" "$(bash_payload 'k6 run s.js')"; expect_code 0; expect_no_out

tc TC-S34 "Bash 가 아닌 도구 · PostToolUse 는 보지 않는다"
run_hook "$BAD" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/x/a.js","content":"k6 run"}}'; expect_code 0; expect_no_out
run_hook "$BAD" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"k6 run s.js"}}'; expect_code 0; expect_no_out

tc TC-S35 "빈 입력 · 명령 없는 입력은 통과한다"
run_hook "$BAD" ''; expect_code 0; expect_no_out
run_hook "$BAD" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}'; expect_code 0; expect_no_out

tc TC-S36 "훅은 차단 조항(SPR-10)도 막지 않고 경고로 알린다"
p="$(proj hookfork)"; printf '@Fork(0)\nclass A {}\n' > "$p/src/jmh/java/demo/A.java"
run_hook "$p" "$(bash_payload 'k6 run s.js')"; expect_code 0; expect_out "SPR-10"; expect_not '"decision"'; expect_not '"permissionDecision"'

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
