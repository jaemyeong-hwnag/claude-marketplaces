#!/usr/bin/env bash
# Express 프로젝트에서 부하 측정을 무효로 만드는 실행 설정을 찾는다 (references/express-stress-rules.md NEX-01 ~ NEX-09).
#
# CLI 모드 : express-stress-config-validate.sh [디렉터리]   (기본: 현재 디렉터리)
# 훅 모드  : stdin 에 훅 JSON. PreToolUse(Bash) 의 command 가 부하 도구 실행일 때만 $CLAUDE_PROJECT_DIR 를 검사해
#            additionalContext 로 알린다. 막지 않는다.
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

LABEL="node-express-stress-test"
die() { echo "express-stress-config-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

ERRORS=()
WARNINGS=()
err()  { ERRORS+=("$1"); }
warn() { WARNINGS+=("$1"); }

# ---- 대상 파일 ----------------------------------------------------------------
# 실행 설정: 운영 기동 경로가 드러나는 파일만 본다. .env 는 개발용인 경우가 많아 보지 않는다.
run_config_files() { # $1=루트
  local f
  for f in "$1"/Dockerfile "$1"/Dockerfile.* "$1"/*.Dockerfile "$1"/docker-compose*.yml "$1"/docker-compose*.yaml \
           "$1"/compose*.yml "$1"/compose*.yaml "$1"/Procfile "$1"/ecosystem.config.js "$1"/ecosystem.config.cjs \
           "$1"/ecosystem.config.json; do
    [ -f "$f" ] || continue
    case "${f##*/}" in *dev*|*local*|*test*) continue ;; esac  # 개발 · 테스트용 변형은 운영 기동이 아니다
    printf '%s\n' "$f"
  done
}

source_files() { # $1=루트
  find "$1" \( -name node_modules -o -name .git -o -name dist -o -name build -o -name coverage \
               -o -name test -o -name tests -o -name __tests__ \) -prune -o \
       -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.mts' -o -name '*.cts' \) \
       ! -name '*.test.*' ! -name '*.spec.*' ! -name '*.d.ts' -print 2>/dev/null | sort
}

# 주석 줄을 뺀 "파일:줄:내용"
grep_code() { # $1=ERE $2..=파일
  local re="$1"; shift
  [ $# -gt 0 ] || return 0
  grep -nHE -- "$re" "$@" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*|#)'
}

rel() { printf '%s' "${1#"$ROOT"/}"; }
loc() { printf '%s' "$1" | cut -d: -f1-2; }  # "파일:줄:내용" → "파일:줄"

# DEBUG 값의 네임스페이스 중 Express 내부(express:* · router · router:*)나 전체(*)가 있는가
debug_hits_express() { # $1=줄
  printf '%s' "$1" | tr -d "\"'" | sed -nE 's/.*DEBUG[[:space:]]*[:=][[:space:]]*([^[:space:]]*).*/\1/p' | tr ',' '\n' \
    | grep -qE '^(express(:.*)?|router(:.*)?|\*)$'
}

# ---- 검사 --------------------------------------------------------------------
check_project() { # $1=루트
  ROOT="$1"
  local pkg="$ROOT/package.json"
  [ -f "$pkg" ] || return 0
  jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("express")' "$pkg" >/dev/null 2>&1 || return 0

  local cfgs=() line f
  while IFS= read -r f; do cfgs+=("$f"); done < <(run_config_files "$ROOT")

  # 운영 기동 명령: package.json 의 start 계열 스크립트 + Dockerfile CMD/ENTRYPOINT + compose command + Procfile
  local starts="$TMP/starts"; : > "$starts"
  jq -r '(.scripts // {}) | to_entries[] | select(.key | test("^(start|start:prod|prod|serve)$")) | "package.json:scripts.\(.key):\(.value)"' "$pkg" >> "$starts"
  for f in ${cfgs+"${cfgs[@]}"}; do
    case "$f" in
      */Procfile) grep -nE '^[a-z]+:' "$f" | sed "s|^|$(rel "$f"):|" >> "$starts" ;;
      */ecosystem.config.*) ;;
      *) grep -nE '^[[:space:]]*(CMD|ENTRYPOINT|command:|-[[:space:]]*command:)' "$f" | sed "s|^|$(rel "$f"):|" >> "$starts" ;;
    esac
  done

  # NEX-01 · NEX-02 — NODE_ENV
  local envs="$TMP/envs"; : > "$envs"
  grep -oE 'NODE_ENV=[A-Za-z_-]+' "$starts" | sed 's/NODE_ENV=//' >> "$envs"
  for f in ${cfgs+"${cfgs[@]}"}; do
    grep -nE 'NODE_ENV' "$f" | grep -vE '^[0-9]+:[[:space:]]*(#|//|CMD|ENTRYPOINT|command:|-[[:space:]]*command:)' | while IFS= read -r line; do
      local v
      v="$(printf '%s' "$line" | sed -nE 's/.*NODE_ENV["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?([A-Za-z_-]+).*/\1/p; s/.*NODE_ENV[[:space:]]+([A-Za-z_-]+).*/\1/p' | head -1)"
      [ -n "$v" ] && printf '%s\t%s:%s\n' "$v" "$(rel "$f")" "${line%%:*}"
    done >> "$TMP/envlocs"
  done
  [ -f "$TMP/envlocs" ] && cut -f1 "$TMP/envlocs" >> "$envs"
  while IFS= read -r line; do
    case "$line" in *NODE_ENV=*) ;; *) continue ;; esac
    v="$(printf '%s' "$line" | sed -nE 's/.*NODE_ENV=([A-Za-z_-]+).*/\1/p')"
    [ "$v" = production ] || err "NEX-01 $(loc "$line"): 운영 기동에서 NODE_ENV=$v — production 이 아니면 Express 가 뷰 캐시를 끄고 오류 응답에 스택을 싣는다"
  done < "$starts"
  if [ -f "$TMP/envlocs" ]; then
    while IFS=$'\t' read -r v loc; do
      case "$loc" in */ecosystem.config.*) continue ;; esac  # PM2 는 env · env_production 을 나눠 쓰므로 값 하나로 판정하지 않는다
      [ "$v" = production ] || err "NEX-01 $loc: NODE_ENV=$v — 운영 기동 설정에서 production 이 아니다"
    done < "$TMP/envlocs"
  fi
  grep -qx production "$envs" || warn "NEX-02 package.json start · Dockerfile · compose · Procfile · ecosystem 어디에도 NODE_ENV=production 이 없다 — 기동 환경에서 넣는지 확인한다 (Express 기본값은 development)"

  # NEX-03 — 자동 리로드
  while IFS= read -r line; do
    printf '%s' "$line" | grep -qE '(^|[^[:alnum:]_-])(nodemon|ts-node-dev|node-dev|supervisor)([^[:alnum:]_-]|$)|--watch([=[:space:]"]|$)|--watch-path|tsx[[:space:]]+watch' \
      && err "NEX-03 $(loc "$line"): 운영 기동에 자동 리로드(nodemon · --watch · tsx watch) — 파일 변경 시 재시작해 진행 중 요청이 끊긴다"
  done < "$starts"
  for f in ${cfgs+"${cfgs[@]}"}; do
    case "$f" in */ecosystem.config.*)
      grep_code "watch[\"']?[[:space:]]*:[[:space:]]*true" "$f" | while IFS= read -r line; do
        printf '%s\n' "NEX-03 $(rel "${line%%:*}"):$(printf '%s' "$line" | cut -d: -f2): PM2 watch: true — 파일 변경 시 재시작한다"
      done >> "$TMP/e03"
    esac
  done
  [ -f "$TMP/e03" ] && while IFS= read -r line; do err "$line"; done < "$TMP/e03"

  # NEX-04 · NEX-05 — 프로파일러 · 인스펙터
  while IFS= read -r line; do
    printf '%s' "$line" | grep -qE -- '--(prof|cpu-prof|heap-prof|trace-sync-io|trace-gc|trace-deopt|trace-opt)([^[:alnum:]-]|$)|(^|[[:space:]:"])(0x|clinic)[[:space:]"]' \
      && err "NEX-04 $(loc "$line"): 운영 기동에 프로파일러 · 추적 플래그 — 측정 대상이 운영과 다른 실행 모드다"
    printf '%s' "$line" | grep -qE -- '--inspect(-brk|-wait)?([=[:space:]]|$)' \
      && warn "NEX-05 $(loc "$line"): 운영 기동에 --inspect — 디버거가 붙으면 측정이 무효다. 0.0.0.0 바인딩은 원격 코드 실행 위험"
  done < "$starts"

  # NEX-06 — DEBUG 로 Express · router 내부 로그
  local dbg="$TMP/dbg"; : > "$dbg"
  grep -nE 'DEBUG' "$starts" | sed 's/^[0-9]*://' >> "$dbg"
  for f in ${cfgs+"${cfgs[@]}"}; do grep -nE '(^|[^_[:alnum:]])DEBUG["'"'"']?[[:space:]]*[:=]' "$f" | sed "s|^|$(rel "$f"):|" >> "$dbg"; done
  while IFS= read -r line; do
    debug_hits_express "$line" && err "NEX-06 $(loc "$line"): DEBUG 가 express:* · router · * 를 켠다 — 요청마다 stderr 에 쓴다 (파일 · TTY 로 가면 동기 쓰기)"
  done < "$dbg"

  # 소스
  local srcs=()
  while IFS= read -r f; do srcs+=("$f"); done < <(source_files "$ROOT")
  [ ${#srcs[@]} -gt 0 ] || return 0

  # NEX-07 — 뷰 캐시를 끔
  grep_code "\.(disable\([[:space:]]*['\"]view cache['\"]|set\([[:space:]]*['\"]view cache['\"][[:space:]]*,[[:space:]]*false)" "${srcs[@]}" > "$TMP/e07"
  while IFS= read -r line; do err "NEX-07 $(rel "${line%%:*}"):$(printf '%s' "$line" | cut -d: -f2): view cache 를 끈다 — 요청마다 템플릿을 다시 읽고 컴파일한다"; done < "$TMP/e07"

  # NEX-08 — 요청 지연에 Summary
  local promsrc=()
  for f in "${srcs[@]}"; do grep -qE "prom-client" "$f" && promsrc+=("$f"); done
  if [ ${#promsrc[@]} -gt 0 ]; then
    grep_code 'new[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*\.)?Summary[[:space:]]*(<[^>]*>)?\(' "${promsrc[@]}" > "$TMP/w08"
    while IFS= read -r line; do warn "NEX-08 $(rel "${line%%:*}"):$(printf '%s' "$line" | cut -d: -f2): prom-client Summary — 분위수를 앱이 계산해 인스턴스 · 워커 사이에 합칠 수 없다. Histogram 을 쓴다"; done < "$TMP/w08"
  fi

  # NEX-09 — 라우트 파일 안의 동기 API
  for f in "${srcs[@]}"; do
    grep -qE '\b(app|router|route)\.(get|post|put|patch|delete|all|use)[[:space:]]*\(' "$f" || continue
    grep_code '\b[A-Za-z]+Sync[[:space:]]*\(' "$f" | while IFS= read -r line; do
      printf '%s\n' "NEX-09 $(rel "${line%%:*}"):$(printf '%s' "$line" | cut -d: -f2): 라우트 파일에서 $(printf '%s' "$line" | grep -oE '[A-Za-z]+Sync' | head -1)() — 요청 경로에서 부르면 이벤트 루프를 막는다 (기동 시 1회면 무관)"
    done
  done > "$TMP/w09"
  while IFS= read -r line; do warn "$line"; done < "$TMP/w09"
}

report_cli() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w"; done
  for e in ${ERRORS+"${ERRORS[@]}"}; do echo "❌ $e"; done
  if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "부하 측정 무효 설정 ($LABEL) — 위반 ${#ERRORS[@]} · 경고 ${#WARNINGS[@]}"
    return 2
  fi
  return 0
}

# ---- 훅 모드 ------------------------------------------------------------------
# 명령을 ; & | 로 나눠 각 조각의 첫 실행 파일이 부하 도구인지 본다
is_load_command() { # $1=명령
  printf '%s\n' "$1" | tr ';&|\n' '\n\n\n\n' | awk '
    {
      n = split($0, w, /[[:space:]]+/); i = 1
      while (i <= n && (w[i] == "" || w[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[i] ~ /^(sudo|time|exec|nohup|npx|bunx|env|command)$/ || w[i] ~ /^-/)) i++
      if (i > n) next
      t = w[i]; sub(/.*\//, "", t); a = (i < n) ? w[i+1] : ""
      if (t == "k6" && (a == "run" || a == "cloud")) { found = 1 }
      else if (t == "vegeta" && a == "attack") { found = 1 }
      else if (t == "artillery" && (a == "run" || a == "quick")) { found = 1 }
      else if (t ~ /^(locust|jmeter|jmeter\.sh|gatling\.sh|wrk|wrk2|hey|ab|oha|autocannon)$/) { found = 1 }
      else if (t == "docker" && $0 ~ /grafana\/k6/) { found = 1 }
      else if ((t == "mvn" || t == "mvnw" || t == "gradlew" || t == "gradle") && $0 ~ /gatling/) { found = 1 }
    }
    END { exit found ? 0 : 1 }'
}

hook_mode() { # $1=입력 JSON
  local event tool cmd
  event="$(printf '%s' "$1" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  tool="$(printf '%s' "$1" | jq -r '.tool_name // empty' 2>/dev/null)"
  cmd="$(printf '%s' "$1" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  [ "$event" = PreToolUse ] && [ "$tool" = Bash ] && [ -n "$cmd" ] || return 0
  is_load_command "$cmd" || return 0
  check_project "${CLAUDE_PROJECT_DIR:-$(pwd)}"
  [ $((${#ERRORS[@]} + ${#WARNINGS[@]})) -gt 0 ] || return 0
  local body x
  body="[$LABEL] 부하 측정 전에 대상 Express 앱의 실행 설정을 확인하세요 — 이대로 잰 수치는 운영을 대표하지 않을 수 있습니다."
  for x in ${ERRORS+"${ERRORS[@]}"}; do body="$body
- 위반 $x"; done
  for x in ${WARNINGS+"${WARNINGS[@]}"}; do body="$body
- 경고 $x"; done
  body="$body
규칙: references/express-stress-rules.md · 적용 절차: express-stress-test-apply 스킬"
  jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  return 0
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/express-stress.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

if [ $# -eq 0 ] && [ ! -t 0 ]; then
  INPUT="$(cat)"
  if [ -n "$INPUT" ]; then
    hook_mode "$INPUT"
    exit 0
  fi
  exit 0
fi

case "${1:-}" in
  -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
esac
DIR="${1:-.}"
[ -d "$DIR" ] || die "디렉터리가 아닙니다: $DIR"
check_project "$(cd "$DIR" && pwd)"
report_cli
exit $?
