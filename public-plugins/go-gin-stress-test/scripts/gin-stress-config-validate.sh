#!/usr/bin/env bash
# Go · Gin 프로젝트에서 부하 측정을 무효로 만들거나 계측을 빠뜨리는 설정을 찾는다.
#   CLI : gin-stress-config-validate.sh [디렉터리]   → 종료 0(없음 · 경고만) / 2(위반) / 1(오류)
#   훅  : PreToolUse(Bash) JSON 을 stdin 으로 받는다. 부하 도구 실행일 때만 프로젝트를 검사해 경고로 알린다 (차단하지 않는다)
# 조항: references/gin-stress-rules.md
set -uo pipefail

RULES="references/gin-stress-rules.md"
ERRORS=0
OUT=""

add() { # $1=❌|⚠️ $2=조항 $3=위치 $4=내용
  [ "$1" = "❌" ] && ERRORS=$((ERRORS+1))
  OUT="${OUT}$1 $2 $3: $4"$'\n'
}

# --- 파일 찾기 ----------------------------------------------------------------
# 의존성 · 테스트 데이터 · 워크트리는 보지 않는다. 제외는 루트 기준으로 건다
find_files() { # $1=루트 $2...=find 이름 조건
  local root="$1"; shift
  find "$root" \( -path "$root/.claude/worktrees" -o -path "$root/.git" -o -name vendor -o -name testdata \
    -o -name node_modules \) -prune -o -type f \( "$@" \) -print 2>/dev/null | sort
}

relpath() { printf '%s' "${1#"$ROOT"/}"; }

# 주석 줄을 뺀 "파일:줄:내용" — Go 는 // 줄, 그 밖은 # 줄을 뺀다
grep_go() { # $1=ERE
  [ -s "$TMPD/go" ] || return 0
  while IFS= read -r f; do
    grep -nE -- "$1" "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*//' | sed "s|^|$(relpath "$f"):|"
  done < "$TMPD/go"
}
grep_list() { # $1=목록 파일 $2=ERE
  [ -s "$1" ] || return 0
  while IFS= read -r f; do
    grep -nE -- "$2" "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' | sed "s|^|$(relpath "$f"):|"
  done < "$1"
}
has_go() { [ -n "$(grep_go "$1" | head -1)" ]; }

# 배포 파일에서 환경 변수 값을 뽑는다 — "파일:줄:값". KEY=v · KEY: v · ENV KEY v · k8s name/value 쌍
env_values() { # $1=키
  [ -s "$TMPD/deploy" ] || return 0
  while IFS= read -r f; do
    awk -v k="$1" -v f="$(relpath "$f")" -v q="'" '
      function clean(v) { sub(/^[ \t]+/, "", v); sub(/[ \t#].*$/, "", v); gsub(/["\047]/, "", v); return v }
      { line=$0; sub(/\r$/, "", line) }
      line ~ /^[ \t]*#/ { next }
      pend && line ~ /value:/ { v=line; sub(/.*value:/, "", v); v=clean(v); if (v!="") print f ":" NR ":" v; pend=0; next }
      { pend=0 }
      line ~ ("name:[ \t]*[\"\047]?" k "[\"\047]?[ \t]*$") { pend=1; next }
      { s=line
        while ((i=index(s, k))>0) {
          pre=(i>1) ? substr(s, i-1, 1) : ""; rest=substr(s, i+length(k)); s=rest
          if (pre ~ /[A-Za-z0-9_]/ || rest ~ /^[A-Za-z0-9_]/) continue
          sub(/^["\047]/, "", rest)
          if (rest ~ /^[ \t]*[=:]/) sub(/^[ \t]*[=:]/, "", rest)
          else if (line ~ /^[ \t]*ENV[ \t]/ && rest ~ /^[ \t]+[^ \t]/) { }
          else continue
          v=clean(rest); if (v!="") print f ":" NR ":" v
        } }' "$f"
  done < "$TMPD/deploy"
}

# 첫 두 칸(파일:줄)만
loc() { printf '%s' "$1" | cut -d: -f1-2; }

# --- 검사 ----------------------------------------------------------------------
check_project() {
  ROOT="$1"
  find_files "$ROOT" -name '*.go' | grep -v '_test\.go$' > "$TMPD/go"
  find_files "$ROOT" -name 'Dockerfile*' -o -name 'Containerfile*' -o -name '*.yml' -o -name '*.yaml' \
    -o -name '.env' -o -name '.env.*' -o -name '*.env' > "$TMPD/deploy"
  find_files "$ROOT" -name 'Dockerfile*' -o -name 'Containerfile*' -o -name '*.yml' -o -name '*.yaml' > "$TMPD/image"
  find_files "$ROOT" -name 'Makefile' -o -name '*.mk' -o -name '*.sh' > "$TMPD/script"
  [ -s "$TMPD/go" ] || return 0

  local hit l v uses_gin=0 release=0
  has_go '"github\.com/gin-gonic/gin"' && uses_gin=1

  # GIN-01 · GIN-02 — 모드
  while IFS= read -r hit; do [ -n "$hit" ] && add "❌" GIN-01 "$(loc "$hit")" "Gin 을 debug 모드로 띄운다 — LoadHTML* 템플릿을 요청마다 다시 파싱한다. gin.SetMode(gin.ReleaseMode) 또는 GIN_MODE=release"
  done <<EOF
$(grep_go 'SetMode\([[:space:]]*(gin\.DebugMode|"debug")[[:space:]]*\)')
EOF
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    v="${hit##*:}"
    case "$v" in
      debug) add "❌" GIN-01 "$(loc "$hit")" "GIN_MODE=debug — 운영 모드가 아니다. GIN_MODE=release" ;;
      release) release=1 ;;
    esac
  done <<EOF
$(env_values GIN_MODE)
EOF
  has_go 'SetMode\([[:space:]]*(gin\.ReleaseMode|"release")[[:space:]]*\)' && release=1
  if [ "$uses_gin" = 1 ] && [ "$release" = 0 ] && ! printf '%s' "$OUT" | grep -q 'GIN-01'; then
    add "⚠️" GIN-02 "." "release 모드 지정이 코드(gin.SetMode(gin.ReleaseMode))에도 배포 파일(GIN_MODE=release)에도 없다 — GIN_MODE 가 비면 debug 다"
  fi

  # GIN-03 — 요청마다 접근 로그
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-03 "$(loc "$hit")" "요청마다 접근 로그를 stdout 에 쓴다 (gin.Default 는 Logger 를 붙인다). 운영과 같은 로그 설정으로 재는지 확인한다"
  done <<EOF
$(grep_go 'gin\.(Default|Logger|LoggerWithConfig|LoggerWithFormatter|LoggerWithWriter)\(')
EOF

  # GIN-04 — pprof 공개
  if has_go '_[[:space:]]+"net/http/pprof"'; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      if printf '%s' "$hit" | grep -qE 'ListenAndServe\([[:space:]]*"(127\.0\.0\.1|localhost|\[::1\]):'; then continue; fi
      if printf '%s' "$hit" | grep -qE 'ListenAndServe\([[:space:]]*"'; then
        add "❌" GIN-04 "$(loc "$hit")" "net/http/pprof 가 붙은 DefaultServeMux 를 루프백이 아닌 주소로 연다 — 127.0.0.1 에 바인드하거나 별도 mux 를 쓴다"
      else
        add "⚠️" GIN-04 "$(loc "$hit")" "net/http/pprof 가 붙은 DefaultServeMux 를 연다 — 주소가 루프백인지 확인한다"
      fi
    done <<EOF
$(grep_go 'ListenAndServe\([^,]*,[[:space:]]*nil[[:space:]]*\)')
EOF
  fi
  if has_go '"github\.com/gin-contrib/pprof"'; then
    while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-04 "$(loc "$hit")" "gin-contrib/pprof 를 엔진에 등록한다 — 앱 포트로 공개되면 누구나 프로파일을 받는다. 루프백 전용 엔진에만 등록한다"
    done <<EOF
$(grep_go 'pprof\.(Register|RouteRegister)\(')
EOF
  fi

  # GIN-05 — -race 빌드
  local race='go[[:space:]]+(build|run|install)[^#]*[[:space:]]-race([[:space:]]|$)|GOFLAGS[=:][^#]*-race'
  while IFS= read -r hit; do [ -n "$hit" ] && add "❌" GIN-05 "$(loc "$hit")" "-race 빌드로 부하를 잰다 — 실행 시간 2~20배 · 메모리 5~10배 (Go race detector 문서). -race 를 뺀 바이너리로 잰다"
  done <<EOF
$(grep_list "$TMPD/image" "$race")
EOF
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-05 "$(loc "$hit")" "-race 빌드 — 부하 측정에 쓰는 바이너리라면 -race 를 뺀다"
  done <<EOF
$(grep_list "$TMPD/script" "$race")
EOF

  # GIN-06 — GOMAXPROCS 수동 고정
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-06 "$(loc "$hit")" "GOMAXPROCS=${hit##*:} 고정 — Go 1.25+ 의 컨테이너 CPU 제한 반영과 주기적 갱신이 꺼진다. CPU 제한보다 크면 CFS 스로틀이 생긴다"
  done <<EOF
$(env_values GOMAXPROCS)
EOF
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-06 "$(loc "$hit")" "runtime.GOMAXPROCS(n) 고정 — 컨테이너 CPU 제한 반영과 주기적 갱신이 꺼진다"
  done <<EOF
$(grep_go 'runtime\.GOMAXPROCS\([[:space:]]*[^0)[:space:]]')
EOF

  # GIN-07 — go.mod 의 go 가 1.25 미만이면 컨테이너 CPU 제한을 보지 않는다
  if [ -f "$ROOT/go.mod" ] && [ -n "$(grep_list "$TMPD/image" '^[[:space:]]*FROM[[:space:]]' | head -1)" ]; then
    l="$(grep -nE '^go[[:space:]]+1\.[0-9]+' "$ROOT/go.mod" | head -1)"
    v="$(printf '%s' "$l" | sed -E 's/^[0-9]+:go[[:space:]]+1\.([0-9]+).*/\1/')"
    if [ -n "$l" ] && [ "$v" -lt 25 ] 2>/dev/null \
      && ! grep -q 'go.uber.org/automaxprocs' "$ROOT/go.mod" && [ -z "$(env_values GOMAXPROCS | head -1)" ]; then
      add "⚠️" GIN-07 "go.mod:${l%%:*}" "go 1.$v — Go 1.25 툴체인으로 빌드해도 containermaxprocs=0 이 기본이라 GOMAXPROCS 가 호스트 CPU 수다. go 1.25 이상으로 올리거나 CPU 제한에 맞춘다"
    fi
  fi

  # GIN-08 — HTTP 서버 타임아웃
  local engines f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    engines="$(grep -oE '[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:?=[[:space:]]*gin\.(New|Default)\(' "$f" | sed -E 's/[[:space:]]*:?=.*//' | sort -u)"
    for v in $engines; do
      while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-08 "$(relpath "$f"):${hit%%:*}" "$v.Run() 은 타임아웃 없는 http.Server 로 연다 — http.Server{ReadHeaderTimeout, ReadTimeout, WriteTimeout, IdleTimeout} 로 띄운다"
      done <<EOF
$(grep -nE "(^|[^A-Za-z0-9_.])$v\.Run\(" "$f" | grep -vE '^[0-9]+:[[:space:]]*//')
EOF
    done
    awk '
      /^[ \t]*\/\// { next }
      !inb && /http\.Server[ \t]*\{/ { inb=1; start=NR; depth=0; txt="" }
      inb { txt=txt $0 "\n"; o=gsub(/\{/, "{"); c=gsub(/\}/, "}"); depth+=o-c
            if (depth<=0) { if (txt !~ /ReadHeaderTimeout|ReadTimeout/) print start; inb=0 } }' "$f" | while IFS= read -r l; do
      printf '%s\n' "$l"
    done > "$TMPD/srv"
    while IFS= read -r l; do [ -n "$l" ] && add "⚠️" GIN-08 "$(relpath "$f"):$l" "http.Server 에 ReadHeaderTimeout · ReadTimeout 이 없다 — 0 이면 타임아웃이 없다"
    done < "$TMPD/srv"
  done < "$TMPD/go"
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-08 "$(loc "$hit")" "http.ListenAndServe 는 타임아웃 없는 서버다 — 앱 트래픽이면 http.Server 에 타임아웃을 둔다"
  done <<EOF
$(grep_go 'http\.ListenAndServe(TLS)?\(' | grep -vE 'ListenAndServe(TLS)?\([[:space:]]*"(127\.0\.0\.1|localhost|\[::1\]):')
EOF

  # GIN-09 — DB 커넥션 풀
  hit="$(grep_go '(sql|sqlx)\.(Open|Connect|MustOpen|MustConnect)\(|gorm\.Open\(' | head -1)"
  if [ -n "$hit" ]; then
    if ! has_go 'SetMaxOpenConns\('; then
      add "⚠️" GIN-09 "$(loc "$hit")" "SetMaxOpenConns 가 없다 — 기본 0 은 무제한이라 대기열이 DB 로 넘어간다. 목표 λ × DB 보유 시간으로 정한다"
    elif ! has_go 'SetMaxIdleConns\('; then
      add "⚠️" GIN-09 "$(loc "$hit")" "SetMaxIdleConns 가 없다 — 기본 유휴 2개라 부하 중 커넥션을 계속 새로 연다"
    fi
  fi

  # GIN-10 — 지연을 히스토그램으로
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-10 "$(loc "$hit")" "Summary Objectives 는 인스턴스 안에서 계산한 분위수라 합칠 수 없다 — 지연은 Histogram 으로 잰다"
  done <<EOF
$(grep_go '^[[:space:]]*Objectives:')
EOF
  if [ "$uses_gin" = 1 ] && ! has_go 'NewHistogram|HistogramOpts|HistogramVecOpts|Float64Histogram|Int64Histogram'; then
    add "⚠️" GIN-10 "." "서버 지연 히스토그램이 없다 — prometheus.NewHistogramVec 을 미들웨어로 붙인다"
  fi

  # GIN-11 — 라벨 카디널리티
  while IFS= read -r hit; do [ -n "$hit" ] && add "⚠️" GIN-11 "$(loc "$hit")" "메트릭 라벨에 원시 경로를 쓴다 — 경로 파라미터마다 시계열이 생긴다. c.FullPath() 를 쓴다"
  done <<EOF
$(grep_go '(WithLabelValues\(|prometheus\.Labels\{).*(URL\.Path|RequestURI|URL\.String\(\))')
EOF

  # GIN-12 — GC 끄기
  local gcoff=""
  hit="$(env_values GOGC | awk -F: '$3=="off"' | head -1)"; [ -n "$hit" ] && gcoff="$(loc "$hit")"
  hit="$(grep_go 'SetGCPercent\([[:space:]]*-1[[:space:]]*\)' | head -1)"; [ -n "$hit" ] && [ -z "$gcoff" ] && gcoff="$(loc "$hit")"
  if [ -n "$gcoff" ] && [ -z "$(env_values GOMEMLIMIT | head -1)" ] && ! has_go 'SetMemoryLimit\('; then
    add "⚠️" GIN-12 "$gcoff" "GC 를 끄고 메모리 한도가 없다 — 힙이 무한히 자란다. GOMEMLIMIT 를 같이 둔다"
  fi
  return 0
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
      if (c=="docker" && line ~ /[ \t]run[ \t]/ && line ~ /grafana\/k6/) { print "y"; exit }
    }' | grep -q y
}

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/gin-stress.XXXXXX")"
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
  msg="부하 측정 전 Go · Gin 설정 점검(go-gin-stress-test) — 아래 설정은 측정을 무효로 만들거나 계측을 빠뜨린다. 고치고 측정할지 사용자에게 알린다. 근거: ${RULES}"$'\n'"${OUT}"
  jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $m}}'
  exit 0
fi

dir="${1:-.}"
[ -d "$dir" ] || { echo "디렉터리가 아니다: $dir" >&2; exit 1; }
check_project "$(cd "$dir" && pwd)"
[ -n "$OUT" ] && printf '%s' "$OUT"
[ "$ERRORS" -gt 0 ] && { echo "위반 ${ERRORS}건 — 근거: ${RULES}"; exit 2; }
exit 0
