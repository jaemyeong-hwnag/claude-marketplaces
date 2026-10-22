#!/usr/bin/env bash
# NestJS 프로젝트에서 부하 측정을 무효로 만드는 설정을 찾는다 (references/nestjs-stress-rules.md NST-01 ~ NST-09).
#
# CLI 모드 : nestjs-stress-config-validate.sh [디렉터리]   (기본: 현재 디렉터리)
# 훅 모드  : stdin 에 훅 JSON. PreToolUse(Bash) 의 command 가 부하 도구 실행일 때만 명령이 도는 디렉터리의 앱을 검사해
#            additionalContext 로 알린다. 막지 않는다.
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

LABEL="typescript-nestjs-stress-test"
die() { echo "nestjs-stress-config-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

ERRORS=()
WARNINGS=()
err()  { ERRORS+=("$1"); }
warn() { WARNINGS+=("$1"); }

rel() { printf '%s' "${1#"$ROOT"/}"; }

# ---- 대상 파일 ----------------------------------------------------------------
run_config_files() { # $1=루트
  local f
  for f in "$1"/Dockerfile "$1"/Dockerfile.* "$1"/*.Dockerfile "$1"/docker-compose*.yml "$1"/docker-compose*.yaml \
           "$1"/compose*.yml "$1"/compose*.yaml "$1"/Procfile; do
    [ -f "$f" ] || continue
    # 개발 · 테스트용 변형은 운영 기동이 아니다. loadtest · perftest 처럼 단어 안에 든 것은 본다
    printf '%s\n' "${f##*/}" | tr 'A-Z' 'a-z' | grep -qE '(^|[._-])(dev|develop|development|local|test|tests|testing)([._-]|$)' && continue
    printf '%s\n' "$f"
  done
}

source_files() { # $1=루트
  find "$1" \( -name node_modules -o -name .git -o -name dist -o -name build -o -name coverage \
               -o -name test -o -name tests -o -name __tests__ -o -path "$1/.claude" \) -prune -o \
       -type f \( -name '*.ts' -o -name '*.mts' -o -name '*.cts' -o -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \) \
       ! -name '*.test.*' ! -name '*.spec.*' ! -name '*.d.ts' -print 2>/dev/null | sort
}

# 주석 줄을 뺀 "파일:줄:내용"
grep_code() { # $1=ERE $2..=파일
  local re="$1"; shift
  [ $# -gt 0 ] || return 0
  grep -nHE -- "$re" "$@" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)'
}

script_of() { jq -r --arg k "$1" '(.scripts // {})[$k] // empty' "$PKG" 2>/dev/null; }

# 기동 명령 안의 npm/yarn/pnpm 스크립트 호출을 풀어 뒤에 붙인다 (한 단계)
expand_cmd() { # $1=명령
  local cmd="$1" name
  for name in $(printf '%s' "$cmd" | tr -d '",[]' | awk '{
      for (i = 1; i <= NF; i++) {
        if (($i == "npm" || $i == "pnpm") && $(i+1) == "start") print "start"
        else if (($i == "npm" || $i == "pnpm" || $i == "yarn" || $i == "bun") && $(i+1) == "run") print $(i+2)
        else if (($i == "yarn" || $i == "pnpm") && $(i+1) ~ /^start/) print $(i+1)
      }
    }'); do
    cmd="$cmd ⟶ $(script_of "$name")"
  done
  printf '%s' "$cmd"
}

uses_framework() { # $1=package.json
  [ -f "$1" ] && jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("@nestjs/core")' "$1" >/dev/null 2>&1
}

# ---- 검사 --------------------------------------------------------------------
check_project() { # $1=루트
  ROOT="$1"
  PKG="$ROOT/package.json"
  uses_framework "$PKG" || return 0
  local deps
  deps="$(jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' "$PKG" 2>/dev/null)"

  local cfgs=() f line loc cmd
  while IFS= read -r f; do cfgs+=("$f"); done < <(run_config_files "$ROOT")

  # 운영 기동 명령 — 배포 설정이 있으면 그것, 없으면 start:prod (없으면 start)
  local starts="$TMP/starts"; : > "$starts"
  for f in ${cfgs+"${cfgs[@]}"}; do
    case "$f" in
      */Procfile) grep -nE '^[a-z]+:' "$f" ;;
      *) grep -nE '^[[:space:]]*(CMD|ENTRYPOINT|command:|-[[:space:]]*command:)' "$f" ;;
    esac | while IFS= read -r line; do
      printf '%s:%s\x1f%s\n' "$(rel "$f")" "${line%%:*}" "${line#*:}"
    done >> "$starts"
  done
  if [ ! -s "$starts" ]; then
    local key=start:prod
    [ -n "$(script_of start:prod)" ] || key=start
    [ -n "$(script_of "$key")" ] && printf 'package.json:scripts.%s\x1f%s\n' "$key" "$(script_of "$key")" >> "$starts"
  fi

  : > "$TMP/nll"  # NEST_LOG_LEVEL 값<US>위치
  while IFS=$'\x1f' read -r loc cmd; do
    # exec 형식 ["nest","start"] 을 단어 사이가 빈칸인 셸 형식으로 편다
    cmd="$(printf '%s' "$cmd" | sed -E 's/\[[[:space:]]*"/ /; s/"[[:space:]]*\][[:space:]]*$/ /; s/"[[:space:]]*,[[:space:]]*"/ /g')"
    cmd="$(expand_cmd "$cmd")"
    # NST-01 — nest start (--watch · --debug 포함)
    if printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_/-])nest[[:space:]]+start'; then
      err "NST-01 $loc: 운영 기동이 'nest start' — 빌드 · 감시 프로세스를 거친 개발 실행이다. 'nest build' 후 'node dist/main' 으로 띄운다"
    fi
    # NST-02 — TypeScript 런타임 로더
    if printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_/-])(ts-node|ts-node-dev|tsx|swc-node)([^[:alnum:]_-]|$)|ts-node/register|@swc-node/register|[^[:alnum:]_/-]src/main\.ts'; then
      warn "NST-02 $loc: 운영 기동이 ts-node · tsx 로 .ts 를 직접 실행한다 — 기동 시 컴파일 · 로더 훅이 붙는다. 'node dist/main' 으로 잰다"
    fi
    printf '%s' "$cmd" | sed -nE 's/.*NEST_LOG_LEVEL=["'"'"']?([^"'"'"'[:space:]]+).*/\1/p' | while IFS= read -r v; do printf '%s\x1f%s\n' "$v" "$loc"; done >> "$TMP/nll"
  done < "$starts"
  for f in ${cfgs+"${cfgs[@]}"}; do
    grep -nE 'NEST_LOG_LEVEL["'"'"']?[[:space:]]*[:=]' "$f" | grep -vE '^[0-9]+:[[:space:]]*(CMD|ENTRYPOINT|command:|-[[:space:]]*command:)' | while IFS= read -r line; do
      printf '%s\x1f%s:%s\n' "$(printf '%s' "$line" | sed -nE 's/.*NEST_LOG_LEVEL["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?([^"'"'"'[:space:]]+).*/\1/p')" "$(rel "$f")" "${line%%:*}"
    done >> "$TMP/nll"
  done

  local srcs=()
  while IFS= read -r f; do srcs+=("$f"); done < <(source_files "$ROOT")
  [ ${#srcs[@]} -gt 0 ] || return 0

  # NST-03 — Nest Logger 레벨. 명시한 logger 옵션 · useLogger 가 NEST_LOG_LEVEL 보다 앞선다
  local mains=()
  for f in "${srcs[@]}"; do grep -qE 'NestFactory\.create' "$f" && mains+=("$f"); done
  for f in ${mains+"${mains[@]}"}; do
    grep_code "(logger[[:space:]]*:|useLogger[[:space:]]*\(|setLogLevels[[:space:]]*\(|logLevels[[:space:]]*:).*['\"](debug|verbose)['\"]" "$f" | while IFS= read -r line; do
      printf '%s\n' "NST-03 $(rel "${line%%:*}"):$(printf '%s' "$line" | cut -d: -f2): Nest 로그 레벨에 debug · verbose 가 있다 — 운영 레벨(['error','warn','log'] 등)로 잰다"
    done
  done > "$TMP/w03"
  while IFS= read -r line; do warn "$line"; done < "$TMP/w03"
  if [ ${#mains[@]} -gt 0 ] && ! grep -qE 'logger[[:space:]]*:|useLogger[[:space:]]*\(' "${mains[@]}"; then
    if [ -s "$TMP/nll" ]; then
      while IFS=$'\x1f' read -r v loc; do
        # ">debug" 는 log 이상이라 제외한다
        printf '%s' "$v" | tr 'A-Z' 'a-z' | grep -qE '(^|,|>=)[[:space:]]*(debug|verbose)|^>[[:space:]]*verbose' \
          && warn "NST-03 $loc: NEST_LOG_LEVEL=$v — debug 로그를 켠 채 잰다"
      done < "$TMP/nll"
    else
      local dbg
      dbg="$(grep_code '\.(debug|verbose)[[:space:]]*\(' "${srcs[@]}" | head -1)"
      if [ -n "$dbg" ]; then
        warn "NST-03 $(rel "${mains[0]}"): NestFactory.create 에 logger 옵션이 없다 — 기본 레벨이 6개 전부라 $(rel "${dbg%%:*}"):$(printf '%s' "$dbg" | cut -d: -f2) 의 debug · verbose 로그가 요청마다 찍힌다"
      fi
    fi
  fi

  # NST-04 · NST-05 — Fastify 어댑터
  for f in "${srcs[@]}"; do
    grep -qE 'new[[:space:]]+FastifyAdapter' "$f" || continue
    local ln flat
    ln="$(grep -nE 'new[[:space:]]+FastifyAdapter' "$f" | head -1 | cut -d: -f1)"
    flat="$(tr '\n' ' ' < "$f")"
    if printf '%s' "$flat" | grep -qE 'new[[:space:]]+FastifyAdapter[[:space:]]*\([[:space:]]*\{[^)]*logger[[:space:]]*:[[:space:]]*(true|\{)' \
       && ! printf '%s' "$flat" | grep -qE 'disableRequestLogging[[:space:]]*:[[:space:]]*true'; then
      warn "NST-04 $(rel "$f"):$ln: FastifyAdapter 에 logger 를 켰다 — Fastify 가 요청마다 시작 · 완료 로그를 쓴다. 끄거나 disableRequestLogging: true"
    fi
    grep_code '\.listen[[:space:]]*\(' "$f" | while IFS= read -r line; do
      local args="${line#*listen}"
      printf '%s' "$args" | grep -qE ',|host' && continue
      printf '%s\n' "NST-05 $(rel "$f"):$(printf '%s' "$line" | cut -d: -f2): Fastify 어댑터의 listen 에 호스트가 없다 — 기본이 127.0.0.1 이라 컨테이너 밖 부하기가 붙지 못한다. listen(port, '0.0.0.0')"
    done
  done > "$TMP/w45" 2>/dev/null
  while IFS= read -r line; do warn "$line"; done < "$TMP/w45"

  # NST-06 — 요청 지연에 Summary
  grep_code 'makeSummaryProvider[[:space:]]*\(|new[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*\.)?Summary[[:space:]]*(<[^>]*>)?\(' "${srcs[@]}" | while IFS= read -r line; do
    printf '%s\n' "NST-06 $(rel "${line%%:*}"):$(printf '%s' "$line" | cut -d: -f2): Summary — 분위수를 프로세스가 계산해 인스턴스 사이에 합칠 수 없다. makeHistogramProvider · Histogram 을 쓴다"
  done > "$TMP/w06"
  while IFS= read -r line; do warn "$line"; done < "$TMP/w06"

  # NST-07 · NST-08 — 지연 히스토그램 · in-flight 게이지
  if ! printf '%s\n' "$deps" | grep -qE '^@opentelemetry/(sdk-node|sdk-metrics)$'; then
    if ! grep -qE 'makeHistogramProvider[[:space:]]*\(|new[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*\.)?Histogram[[:space:]]*(<[^>]*>)?\(' "${srcs[@]}"; then
      warn "NST-07 $(rel "$PKG"): 서버 측 지연 히스토그램이 없다 — 부하기 수치만으로는 서버 · 네트워크 · 부하기 중 어디서 늦는지 가를 수 없다"
    fi
    if ! grep -qE 'makeGaugeProvider[[:space:]]*\(|new[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*\.)?Gauge[[:space:]]*(<[^>]*>)?\(' "${srcs[@]}"; then
      warn "NST-08 $(rel "$PKG"): in-flight 요청 게이지가 없다 — 단계마다 Little's Law(L = λW)를 맞춰 볼 수 없다"
    fi
  fi

  # NST-09 — 요청 스코프 프로바이더
  awk '
    FNR == 1 { split("", buf) }
    { buf[FNR] = $0 }
    /scope[[:space:]]*:[[:space:]]*Scope\.REQUEST/ && $0 !~ /^[[:space:]]*(\/\/|\*)/ { hit[FILENAME ":" FNR] = FNR; file[FILENAME ":" FNR] = FILENAME }
    /durable[[:space:]]*:[[:space:]]*true/ { dur[FILENAME ":" FNR] = 1 }
    END {
      for (k in hit) {
        n = hit[k]; f = file[k]; ok = 0
        for (d = n - 2; d <= n + 2; d++) if ((f ":" d) in dur) ok = 1
        if (!ok) print f ":" n
      }
    }' "${srcs[@]}" | sort > "$TMP/w09"
  while IFS= read -r line; do
    warn "NST-09 $(rel "${line%:*}"):${line##*:}: Scope.REQUEST — 요청마다 인스턴스를 만들고, 이것에 기대는 컨트롤러 · 프로바이더도 요청 스코프가 된다. 기본(싱글턴)과 비교해 잰다"
  done < "$TMP/w09"
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
# --- 부하 도구 명령 판별 (훅) — common-stress-test 의 stress-target-validate.sh 와 같은 규칙 ---------------
# heredoc 본문은 명령이 아니라 데이터다. 셸에 먹이는 heredoc(sh <<EOF)만 명령으로 남긴다
strip_heredoc() {
  awk -v q="'" '
    d != "" { t = $0; if (dash) sub(/^\t+/, "", t); if (t == d) d = ""; else if (keep) print; next }
    { print; s = $0; gsub(/<<</, "\001", s)
      if (match(s, "<<-?[ \t]*[\"" q "]?[A-Za-z_][A-Za-z0-9_]*")) {
        d = substr(s, RSTART, RLENGTH); dash = (d ~ /^<<-/)
        sub(/^<<-?[ \t]*/, "", d); gsub("[\"" q "]", "", d)
        keep = (s ~ /(^|[;&|(][ \t]*)(sudo[ \t]+)?(ba|z|da|k)?sh([ \t]+-[A-Za-z]+)*[ \t]*<</)
      } }'
}

# 부하 도구를 실행하는 구간인가 — 구간의 첫 단어(환경 변수 대입 · 래퍼 제외)나 docker 이미지로 판단한다. 도구 이름은 TOOL 에 남긴다
is_load_segment() {
  local seg="$1" w first="" rest opts
  TOOL=""
  # shellcheck disable=SC2086
  set -f; set -- $seg; set +f
  while [ "$#" -gt 0 ]; do
    w="${1#[\"\'(\{]}"
    case "$w" in
      *=*|sudo|time|nohup|exec|command|env|npx|bunx|pnpx|uvx|do|then|else|elif|if|while|until|!|-*|'') shift ;;
      uv|poetry|pipenv|pdm|hatch)
        [ "${2:-}" = run ] || { first="$w"; shift; break; }
        shift 2 ;;
      python|python3|python3.*)
        [ "${2:-}" = -m ] || { first="$w"; shift; break; }
        shift 2 ;;
      timeout)
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -s|-k|--signal|--kill-after) shift 2 ;;
            -*) shift ;;
            *) break ;;
          esac
        done
        [ "$#" -gt 0 ] && shift ;;
      nice|ionice|stdbuf|xargs|watch|caffeinate)
        # 값을 받는 옵션 — 값까지 건너뛰어야 다음 단어가 실행할 명령이다
        case "$w" in
          nice) opts=" -n --adjustment " ;;
          ionice) opts=" -c -n -p -P -u --class --classdata " ;;
          stdbuf) opts=" -i -o -e --input --output --error " ;;
          xargs) opts=" -n -L -P -I -J -R -S -d -E -s -a " ;;
          watch) opts=" -n --interval " ;;
          caffeinate) opts=" -t -w " ;;
        esac
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -*) case "$opts" in *" $1 "*) shift ;; esac; shift ;;
            *) break ;;
          esac
        done ;;
      sh|bash|zsh|dash|ksh)
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -*c) shift; break ;;
            -*) shift ;;
            *) set -- ; break ;;
          esac
        done
        [ "$#" -gt 0 ] || { first="$w"; break; } ;;
      *) first="$w"; shift; break ;;
    esac
  done
  rest="$*"
  first="${first##*/}"
  TOOL="$first"
  case "$first" in
    k6) case "$rest" in run*|cloud*) return 0 ;; esac ;;
    locust|jmeter|jmeter.sh|gatling|gatling.sh|wrk|wrk2|hey|oha|ab|autocannon) return 0 ;;
    vegeta) case "$rest" in attack*) return 0 ;; esac ;;
    artillery) case "$rest" in run*|quick*) return 0 ;; esac ;;
    docker|podman|docker-compose)
      printf '%s' "$rest" | grep -qE '(^|[ /])(grafana/k6|locustio/locust|[a-z0-9_.-]*/?jmeter|[a-z0-9_.-]*/?gatling)(:[^ ]*)?( |$)' && return 0
      # compose 서비스 이름으로 부하기를 띄우는 경우
      printf '%s' "$first $rest" | grep -qE '(compose|docker-compose).*( run| up).* (k6|locust|jmeter|gatling)( |$)' && return 0 ;;
    mvn|mvnw|gradle|gradlew) printf '%s' "$rest" | grep -qiE 'gatling' && return 0 ;;
  esac
  return 1
}

# 명령을 && · || · ; · & · | · $( · ` 로 나눈 구간 중 하나라도 부하 도구 실행이면 참
is_load_command() { # $1=명령
  local seg
  while IFS= read -r seg; do
    [ -n "${seg// /}" ] || continue
    is_load_segment "$seg" && return 0
  done < <(printf '%s\n' "$1" | strip_heredoc | sed -E 's/(\|\||&&|[;&|]|\$\(|`)/\n/g')
  return 1
}

# 명령이 도는 디렉터리 — 입력의 cwd(없으면 프로젝트)에 앞머리 cd 를 적용한다
target_dir() { # $1=입력 JSON $2=명령
  local base d
  base="$(printf '%s' "$1" | jq -r '.cwd // empty' 2>/dev/null)"
  [ -n "$base" ] || base="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  d="$(printf '%s\n' "$2" | sed -nE '1s/^[[:space:]]*cd[[:space:]]+([^;&|[:space:]]+).*/\1/p' | tr -d "\"'")"
  case "$d" in '') d="$base" ;; /*) ;; *) d="$base/$d" ;; esac
  [ -d "$d" ] && d="$(cd "$d" && pwd)"
  printf '%s' "$d"
}

# 워크스페이스 하위 앱 — 대상 디렉터리부터 위로 @nestjs/core 를 쓰는 가장 가까운 package.json. 없으면 그대로 둔다
app_root() { # $1=디렉터리
  local d="$1"
  while [ -n "$d" ]; do
    uses_framework "$d/package.json" && { printf '%s' "$d"; return 0; }
    [ "$d" = / ] && break
    d="$(dirname "$d")"
  done
  printf '%s' "$1"
}

hook_mode() { # $1=입력 JSON
  local event tool cmd
  event="$(printf '%s' "$1" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  tool="$(printf '%s' "$1" | jq -r '.tool_name // empty' 2>/dev/null)"
  cmd="$(printf '%s' "$1" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  [ "$event" = PreToolUse ] && [ "$tool" = Bash ] && [ -n "$cmd" ] || return 0
  is_load_command "$cmd" || return 0
  check_project "$(app_root "$(target_dir "$1" "$cmd")")"
  [ $((${#ERRORS[@]} + ${#WARNINGS[@]})) -gt 0 ] || return 0
  local body x
  body="[$LABEL] 부하 측정 전에 대상 NestJS 앱의 실행 설정을 확인하세요 — 이대로 잰 수치는 운영을 대표하지 않을 수 있습니다."
  for x in ${ERRORS+"${ERRORS[@]}"}; do body="$body
- 위반 $x"; done
  for x in ${WARNINGS+"${WARNINGS[@]}"}; do body="$body
- 경고 $x"; done
  body="$body
규칙: references/nestjs-stress-rules.md · 적용 절차: nestjs-stress-test-apply 스킬"
  jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  return 0
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/nestjs-stress.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

if [ $# -eq 0 ] && [ ! -t 0 ]; then
  INPUT="$(cat)"
  [ -n "$INPUT" ] && hook_mode "$INPUT"
  exit 0
fi

case "${1:-}" in
  -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
esac
DIR="${1:-.}"
[ -d "$DIR" ] || die "디렉터리가 아닙니다: $DIR"
check_project "$(cd "$DIR" && pwd)"
report_cli
exit $?
