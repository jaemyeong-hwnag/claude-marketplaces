#!/usr/bin/env bash
# Spring Boot 프로젝트에서 부하 측정을 무효로 만들거나 계측을 빠뜨리는 설정을 찾는다.
#   CLI : spring-stress-config-validate.sh [디렉터리]   → 종료 0(없음 · 경고만) / 2(위반) / 1(오류)
#   훅  : PreToolUse(Bash) JSON 을 stdin 으로 받는다. 부하 도구 실행일 때만 프로젝트를 검사해 경고로 알린다 (차단하지 않는다)
# 조항: references/spring-stress-rules.md
set -uo pipefail

RULES="references/spring-stress-rules.md"
ERRORS=0
OUT=""

add() { # $1=❌|⚠️ $2=조항 $3=파일 $4=내용
  [ "$1" = "❌" ] && ERRORS=$((ERRORS+1))
  OUT="${OUT}$1 $2 $3: $4"$'\n'
}

# --- 파일 찾기 ----------------------------------------------------------------
# 빌드 산출물 · 의존성 · 워크트리는 보지 않는다. 제외는 루트 기준으로 건다
find_files() { # $1=루트 $2...=find 이름 조건
  local root="$1"; shift
  find "$root" \( -path "$root/.claude/worktrees" -o -path "$root/.git" -o -name build -o -name target \
    -o -name .gradle -o -name node_modules -o -name out \) -prune -o -type f \( "$@" \) -print 2>/dev/null | sort
}

# --- 설정 평탄화: key=value 줄로 (키는 소문자 · '-' '_' 제거 — Spring relaxed binding) ----------
flatten_props() {
  awk '
    /^[ \t]*[#!]/ || /^[ \t]*$/ { next }
    { line=$0; sub(/^[ \t]+/, "", line)
      p=index(line, "="); q=index(line, ":"); if (p==0 || (q>0 && q<p)) p=q
      if (p==0) next
      k=substr(line,1,p-1); v=substr(line,p+1)
      gsub(/[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)
      print k "=" v }' "$1"
}

flatten_yaml() {
  awk -v q="'" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function unquote(s) { if (length(s)>=2 && (substr(s,1,1)=="\"" || substr(s,1,1)==q) && substr(s,length(s))==substr(s,1,1)) return substr(s,2,length(s)-2); return s }
    /^---/ { n=0; next }
    { raw=$0; sub(/\r$/, "", raw) }
    raw ~ /^[ \t]*#/ || raw ~ /^[ \t]*$/ { next }
    { match(raw, /^ */); ind=RLENGTH; line=substr(raw, ind+1) }
    line ~ /^- / { next }
    { p=index(line, ":"); if (p==0) next
      k=trim(substr(line,1,p-1)); v=trim(substr(line,p+1))
      k=unquote(k); sub(/[ \t]+#.*$/, "", v); v=unquote(v)
      while (n>0 && ind<=si[n]) n--
      path=""; for (i=1;i<=n;i++) path=path sk[i] "."
      if (v=="" || v=="|" || v==">") { n++; si[n]=ind; sk[n]=k } else print path k "=" v }' "$1"
}

normalize() { # key=value → 정규화 키=값 (map 키의 [ ] 표기도 벗긴다)
  awk -F= '{ k=tolower($1); gsub(/[-_\[\]]/, "", k); v=$0; sub(/^[^=]*=/, "", v); print k "=" v }'
}

# 운영 측정에 쓰지 않는 프로필 파일 (dev · local · test) 은 보지 않는다
config_files() {
  find_files "$1" -name 'application*.properties' -o -name 'application*.yml' -o -name 'application*.yaml' \
    | grep -v '/src/test/' | awk -F/ '{ f=$NF; if (f ~ /^application-.*(dev|local|test)/) next; print }'
}

flat_of() {
  case "$1" in
    *.properties) flatten_props "$1" | normalize ;;
    *) flatten_yaml "$1" | normalize ;;
  esac
}

relpath() { local p="$1"; printf '%s' "${p#"$ROOT"/}"; }

# --- 검사 ----------------------------------------------------------------------
check_project() {
  ROOT="$1"
  local f rel flat val build_text="" has_hist=0 mbean=0 vt="" tmax="" vt_file="" uses_prom=0 uses_actuator=0 uses_tomcat=1

  # 빌드 파일 (SPR-01 · 의존성 판단)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="$(relpath "$f")"
    build_text="${build_text}$(cat "$f")"$'\n'
    case "$f" in
      *pom.xml)
        awk '
          /<dependency>/ { inb=1; blk=""; ln=NR }
          inb { blk=blk $0 "\n" }
          /<\/dependency>/ { if (inb && blk ~ /spring-boot-devtools/ && blk !~ /<optional>[ \t]*true[ \t]*<\/optional>/ && blk !~ /<scope>[ \t]*(test|provided)[ \t]*<\/scope>/) print ln; inb=0 }' "$f" \
          | while IFS= read -r ln; do echo "$ln"; done > "$TMPD/pom-devtools"
        while IFS= read -r ln; do
          [ -n "$ln" ] && add "⚠️" "SPR-01" "$rel:$ln" "spring-boot-devtools 에 <optional>true</optional> 이 없다 — 운영 아티팩트 · 부하 대상에 devtools 가 따라간다"
        done < "$TMPD/pom-devtools"
        ;;
      *)
        grep -n 'spring-boot-devtools' "$f" | grep -v -E '^[0-9]+:[[:space:]]*//' \
          | grep -v -E 'developmentOnly|testImplementation|testRuntimeOnly|testAndDevelopmentOnly' \
          | while IFS= read -r m; do echo "${m%%:*}"; done > "$TMPD/gradle-devtools"
        while IFS= read -r ln; do
          [ -n "$ln" ] && add "⚠️" "SPR-01" "$rel:$ln" "spring-boot-devtools 가 developmentOnly 밖에 있다 — 운영 아티팩트 · 부하 대상에 devtools 가 따라간다"
        done < "$TMPD/gradle-devtools"
        ;;
    esac
  done <<EOF
$(find_files "$ROOT" -name 'build.gradle' -o -name 'build.gradle.kts' -o -name 'pom.xml')
EOF

  printf '%s' "$build_text" | grep -q 'micrometer-registry-prometheus' && uses_prom=1
  printf '%s' "$build_text" | grep -q 'spring-boot-starter-actuator' && uses_actuator=1
  printf '%s' "$build_text" | grep -q -E 'spring-boot-starter-web([^a-z-]|$)' || uses_tomcat=0
  printf '%s' "$build_text" | grep -q -E 'spring-boot-starter-(jetty|undertow)' && uses_tomcat=0

  # 설정 파일 (SPR-02 ~ SPR-08)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="$(relpath "$f")"
    flat="$(flat_of "$f")"
    val="$(printf '%s\n' "$flat" | awk -F= '$1=="logging.level.root" {print $2}' | tail -1)"
    case "$(printf '%s' "$val" | tr '[:lower:]' '[:upper:]')" in
      DEBUG|TRACE|ALL) add "❌" "SPR-02" "$rel" "logging.level.root=$val — 모든 로거가 요청마다 로그를 쓴다. INFO 이상으로 두고 측정한다" ;;
    esac
    for k in debug trace; do
      val="$(printf '%s\n' "$flat" | awk -F= -v k="$k" '$1==k {print $2}' | tail -1)"
      [ "$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')" = "true" ] && add "⚠️" "SPR-03" "$rel" "$k=true — 핵심 로거(내장 컨테이너 · Hibernate · Spring)의 로그 수준을 올린다. 측정 전에 끈다"
    done
    for k in spring.jpa.showsql spring.jpa.properties.hibernate.showsql; do
      val="$(printf '%s\n' "$flat" | awk -F= -v k="$k" '$1==k {print $2}' | tail -1)"
      [ "$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')" = "true" ] && { shown="spring.jpa.show-sql"; [ "$k" = spring.jpa.showsql ] || shown="spring.jpa.properties.hibernate.show_sql"; add "⚠️" "SPR-04" "$rel" "$shown=true — SQL 문마다 콘솔에 쓴다. 측정 전에 끈다"; }
    done
    printf '%s\n' "$flat" | awk -F= '
      index($1, "management.metrics.distribution.percentileshistogram.")==1 {
        m=substr($1, length("management.metrics.distribution.percentileshistogram.")+1)
        if ((m=="all" || index("http.server.requests", m)==1) && tolower($2)=="true") print "y" }' | grep -q y && has_hist=1
    printf '%s\n' "$flat" | awk -F= 'index($1, "management.metrics.distribution.percentiles.")==1 {print $1}' \
      | while IFS= read -r k; do echo "$k"; done > "$TMPD/pct"
    while IFS= read -r k; do
      [ -n "$k" ] && add "⚠️" "SPR-06" "$rel" "${k} — 앱이 계산한 분위수는 인스턴스 사이에 합칠 수 없다. percentiles-histogram 으로 버킷을 낸다"
    done < "$TMPD/pct"
    [ "$(printf '%s\n' "$flat" | awk -F= '$1=="server.tomcat.mbeanregistry.enabled" {print tolower($2)}' | tail -1)" = "true" ] && mbean=1
    val="$(printf '%s\n' "$flat" | awk -F= '$1=="spring.threads.virtual.enabled" {print tolower($2)}' | tail -1)"
    [ "$val" = "true" ] && { vt="true"; vt_file="$rel"; }
    val="$(printf '%s\n' "$flat" | awk -F= 'index($1, "server.tomcat.threads.")==1 {print $1}' | head -1)"
    [ -n "$val" ] && tmax="$val"
  done <<EOF
$(config_files "$ROOT")
EOF

  if [ "$uses_prom" = 1 ] && [ "$has_hist" = 0 ]; then
    add "⚠️" "SPR-05" "(설정)" "micrometer-registry-prometheus 를 쓰는데 management.metrics.distribution.percentiles-histogram.http.server.requests=true 가 없다 — 지연 히스토그램 버킷이 나오지 않는다"
  fi
  if [ "$uses_actuator" = 1 ] && [ "$uses_tomcat" = 1 ] && [ "$mbean" = 0 ]; then
    add "⚠️" "SPR-07" "(설정)" "server.tomcat.mbeanregistry.enabled=true 가 없다 — tomcat.threads.busy 같은 Tomcat 지표가 나오지 않는다"
  fi
  if [ "$vt" = "true" ] && [ -n "$tmax" ]; then
    add "⚠️" "SPR-08" "$vt_file" "spring.threads.virtual.enabled=true 이면 ${tmax} 는 효과가 없다 — 동시성 상한은 커넥션 풀 등 다른 자원이 된다"
  fi

  # Dockerfile (SPR-09)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="$(relpath "$f")"
    if grep -q -E '^[[:space:]]*(ENTRYPOINT|CMD).*java' "$f" && ! grep -q -E 'MaxRAMPercentage|MaxRAM=|-Xmx|InitialRAMPercentage' "$f"; then
      add "⚠️" "SPR-09" "$rel" "java 를 힙 상한 없이 띄운다 — 컨테이너 메모리의 25% 만 힙으로 쓴다 (-XX:MaxRAMPercentage 또는 -Xmx)"
    fi
  done <<EOF
$(find_files "$ROOT" -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.Dockerfile')
EOF

  # JMH fork 0 (SPR-10)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="$(relpath "$f")"
    grep -n -E '@Fork\([[:space:]]*(value[[:space:]]*=[[:space:]]*)?0[[:space:]]*[,)]' "$f" | while IFS= read -r m; do echo "${m%%:*}"; done > "$TMPD/fork"
    while IFS= read -r ln; do
      [ -n "$ln" ] && add "❌" "SPR-10" "$rel:$ln" "@Fork(0) — JMH 는 fork 없는 실행을 디버깅용으로만 쓰라고 경고한다. @Fork 1 이상"
    done < "$TMPD/fork"
  done <<EOF
$(find_files "$ROOT" -name '*.java' -o -name '*.kt')
EOF
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="$(relpath "$f")"
    awk '/^[[:space:]]*jmh[[:space:]]*\{/ {inj=1} inj && /^[[:space:]]*fork(s)?[[:space:]]*(=|\.set\()?[[:space:]]*0[[:space:]]*\)?[[:space:]]*$/ {print NR} inj && /^\}/ {inj=0}' "$f" > "$TMPD/gfork"
    while IFS= read -r ln; do
      [ -n "$ln" ] && add "❌" "SPR-10" "$rel:$ln" "jmh { fork = 0 } — JMH 는 fork 없는 실행을 디버깅용으로만 쓰라고 경고한다. fork 1 이상"
    done < "$TMPD/gfork"
  done <<EOF
$(find_files "$ROOT" -name 'build.gradle' -o -name 'build.gradle.kts')
EOF
}

# --- 부하 도구 명령 판별 (훅) -------------------------------------------------------
is_load_command() { # $1=명령 문자열
  printf '%s\n' "$1" | tr ';&|()' '\n\n\n\n\n' | awk '
    { line=$0; sub(/^[ \t]+/, "", line)
      n=split(line, w, /[ \t]+/); i=1
      while (i<=n && (w[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[i]=="sudo" || w[i]=="time" || w[i]=="exec" || w[i]=="npx" || w[i]=="nohup" || w[i]=="command")) i++
      if (i>n) next
      c=w[i]; sub(/^.*\//, "", c); a=(i<n) ? w[i+1] : ""
      if (c=="k6" && a=="run") { print "y"; exit }
      if (c=="vegeta" && a=="attack") { print "y"; exit }
      if (c=="artillery" && (a=="run" || a=="quick")) { print "y"; exit }
      if (c ~ /^(locust|jmeter|jmeter\.sh|gatling|gatling\.sh|wrk|wrk2|hey|ab|oha|autocannon)$/) { print "y"; exit }
      if (c ~ /^(gradle|gradlew)$/ && line ~ /gatlingRun/) { print "y"; exit }
      if (c ~ /^(mvn|mvnw)$/ && line ~ /gatling:test/) { print "y"; exit }
      if (c=="docker" && line ~ /[ \t]run[ \t]/ && line ~ /grafana\/k6/) { print "y"; exit }
    }' | grep -q y
}

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/spring-stress.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT

if [ $# -eq 0 ] && [ ! -t 0 ]; then
  INPUT="$(cat)"
  [ -n "$INPUT" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  event="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  tool="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  [ "$event" = "PreToolUse" ] && [ "$tool" = "Bash" ] || exit 0
  cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  [ -n "$cmd" ] && is_load_command "$cmd" || exit 0
  proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$INPUT" | jq -r '.cwd // empty')}"
  [ -n "$proj" ] && [ -d "$proj" ] || exit 0
  check_project "$(cd "$proj" && pwd)"
  [ -n "$OUT" ] || exit 0
  msg="부하 측정 전 Spring 설정 점검(java-spring-stress-test) — 아래 설정은 측정을 무효로 만들거나 계측을 빠뜨린다. 고치고 측정할지 사용자에게 알린다. 근거: ${RULES}"$'\n'"${OUT}"
  jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $m}}'
  exit 0
fi

dir="${1:-.}"
[ -d "$dir" ] || { echo "디렉터리가 아니다: $dir" >&2; exit 1; }
check_project "$(cd "$dir" && pwd)"
[ -n "$OUT" ] && printf '%s' "$OUT"
[ "$ERRORS" -gt 0 ] && { echo "위반 ${ERRORS}건 — 근거: ${RULES}"; exit 2; }
exit 0
