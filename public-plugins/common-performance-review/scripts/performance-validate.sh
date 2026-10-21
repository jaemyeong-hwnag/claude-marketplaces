#!/usr/bin/env bash
# PF-01 ~ PF-20 — 코드에서 성능 위험 패턴을 찾는다. 모두 경고다 (판정은 performance-review 스킬이 맥락을 읽고 한다).
#
#   훅:  PostToolUse(Write|Edit|MultiEdit) — 이번에 쓴 줄에서 나온 것만 additionalContext 로 알린다
#   CLI: performance-validate.sh [--strict] [--diff [<기준>]] [--include-tests] [파일|디렉터리 ...]   (기본: 현재 디렉터리)
#        --diff 는 기준(기본: origin 기본 브랜치와의 merge-base) 이후 추가 · 변경된 줄만 본다
#        경고가 있어도 exit 0, --strict 면 exit 2
#
# 줄 끝이나 바로 윗줄에 `performance-ignore` 주석이 있으면 그 줄은 보지 않는다.
set -uo pipefail

RULES="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/references/performance-rules.md"
die() { echo "performance-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"

# 확장자 → 문법 계열 (빈 문자열이면 보지 않는다)
lang_of() {
  case "$1" in
    *.py) echo py ;;
    *.java|*.kt|*.kts|*.scala|*.go|*.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx|*.cs|*.php|*.swift|*.rs) echo brace ;;
    *.sql) echo sql ;;
    *) echo "" ;;
  esac
}

is_test_path() { # $1=기준 디렉터리 안 상대 경로
  case "/$1" in
    */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/testdata/*|*/fixtures/*) return 0 ;;
    *_test.go|*.test.*|*.spec.*|*Test.java|*Tests.java|*Test.kt|*Tests.kt|*/test_*.py|*_test.py|*conftest.py) return 0 ;;
  esac
  return 1
}

# 테스트 경로는 저장소 최상위(저장소가 아니면 프로젝트 디렉터리) 기준으로 본다 — 바깥 상위 디렉터리(~/test/app)의 이름에 끌려가지 않게
base_of() { # $1=디렉터리 → 기준 디렉터리 (물리 경로)
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || (cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P) || pwd -P
}
rel_of() { # $1=기준 $2=경로 → 기준 안이면 상대 경로, 아니면 그대로
  local a
  a="$(cd "$(dirname "$2")" 2>/dev/null && pwd -P)/${2##*/}" || { printf '%s\n' "$2"; return; }
  case "$a" in "$1"/*) printf '%s\n' "${a#"$1"/}" ;; *) printf '%s\n' "$2" ;; esac
}

# 파일 하나 → "줄번호 \x1f 조항 \x1f 메시지" 줄들
check_file() {
  local f="$1" lang
  lang="$(lang_of "$f")"
  [ -n "$lang" ] || return 0
  awk -v lang="$lang" -v ext="${f##*.}" '
function indent(s) { match(s, /^[ \t]*/); return RLENGTH }
# 문자열 리터럴을 비운다 — 괄호 수 · 키워드 판정용
function nostr(s) {
  gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
  gsub(/\047([^\047\\]|\\.)*\047/, "\047\047", s)
  gsub(/`[^`]*`/, "``", s)
  return s
}
function count(s, ch) { return gsub(RE[ch], "", s) }
# 줄 n 에서 시작한 괄호가 닫힐 때까지 이어 붙인다 (최대 8줄)
function call_text(n, s,   t, j, b) {
  t = s; b = count(nostr(s), "(") - count(nostr(s), ")")
  for (j = n + 1; b > 0 && j <= n + 8 && j <= NL; j++) { t = t " " L[j]; b += count(nostr(L[j]), "(") - count(nostr(L[j]), ")") }
  return t
}
function emit(n, rule, msg) {
  if ((n SUBSEP rule) in seen) return
  seen[n SUBSEP rule] = 1
  printf "%d\037%s\037%s\n", n, rule, msg
}
# 순서대로 기다리는 게 의도인 루프 — while(폴링) · 재시도 횟수(range · attempt · retry)
function serial_ok(h) { return (h ~ /(^|[^a-zA-Z0-9_])while[^a-zA-Z0-9_]/ || h ~ /in[ \t]+range\(/ || h ~ /[Aa]ttempt|[Rr]etr(y|ies)/) }
# 루프 본문 조각 s. kw = 가장 안쪽 루프가 for 이고 순서 의도가 없으면 1 (PF-03 대상). lid = 루프 시작 줄
function in_loop(n, s, kw, lid,   q) {
  q = 0
  if (s ~ /\.(execute|executeQuery|executeUpdate|executemany|query|queryForObject|queryForList|queryForMap|raw|rawQuery|createQuery|createNativeQuery)\(/ ||
      s ~ /[Rr]epo(sitory)?\.[a-zA-Z_]+\(/ || s ~ /[a-z]Repository\.[a-zA-Z_]+\(/ ||
      s ~ /\.find(By[A-Za-z]*|One|OneBy|ById|Unique|UniqueOrThrow|First|FirstOrThrow|Many)\(/ ||
      s ~ /\.objects\.[a-z_]+\(/ || s ~ /\.get_or_create\(/ || s ~ /session\.(query|execute|scalar|scalars|merge|add)\(/ ||
      s ~ /prisma\.[a-zA-Z_]+\.[a-zA-Z]+\(/ || s ~ /(^|[^a-zA-Z_])db\.(Query|QueryRow|QueryContext|QueryRowContext|Exec|ExecContext|Get|Select|First|Find|Where)\(/ ||
      s ~ /(^|[^a-zA-Z_])(em|entityManager)\.(find|persist|merge|createQuery|getReference)\(/ || s ~ /\.save\(/ || s ~ /\.(update_or_create|refresh_from_db)\(/) {
    q = 1
    # 페이지 · 배치 단위로 끊어 읽는 루프는 의도한 반복이다
    if (call_text(n, L[n]) !~ /[Pp]age|[Ll]imit|[Oo]ffset|[Cc]ursor|[Bb]atch|[Cc]hunk|last_?[Ii]d|[Aa]fter[A-Z(_ =]/)
    emit(n, "PF-01", "루프 안 DB 호출 — 반복 수만큼 왕복한다 (N+1). 한 번에 조회(IN · join fetch · select_related/prefetch_related · DataLoader)하거나 bulk 로 쓴다")
  }
  if (s ~ /(^|[^a-zA-Z_.])fetch\(/ || s ~ /axios(\.[a-z]+)?\(/ || s ~ /(requests|httpx)\.(get|post|put|patch|delete|head|request)\(/ ||
      s ~ /http\.(Get|Post|Head|PostForm|NewRequest|NewRequestWithContext)\(/ || s ~ /\.Do\(req/ ||
      s ~ /(restTemplate|webClient|restClient|RestClient|httpClient|HttpClient|okHttpClient)\./ || s ~ /urlopen\(/ ||
      s ~ /(^|[^a-zA-Z_])_?(session|client|http)\.(get|post|put|patch|delete|request)\(/ ||
      s ~ /(redis|jedis|redisTemplate|memcache)[A-Za-z]*\.(get|set|hget|hset|opsForValue|exists|del|incr|expire)\(/) {
    emit(n, "PF-02", "루프 안 원격 호출 (HTTP · 캐시 · RPC) — 반복 수만큼 왕복한다. 배치 API · MGET/pipeline · 동시성 상한을 둔 병렬로"); q = 1
  }
  if (kw && !q && !(lid in awaited) && s ~ /(^|[^a-zA-Z_])await[ \t(]/ && s !~ /for[ \t]+await|await[ \t]+(asyncio\.)?sleep|await[ \t]+new[ \t]+Promise/) {
    awaited[lid] = 1
    emit(n, "PF-03", "for/while 안의 await — 독립적인 작업도 하나씩 기다린다. Promise.all · asyncio.gather 로 묶고 동시성 상한을 둔다 (순서 · 의존이 있으면 무시)")
  }
  if (s ~ /Pattern\.compile\(|re\.compile\(|regexp\.(MustCompile|Compile)\(|new RegExp\(|(^|[^a-zA-Z_])Regex\(/ ||
      ((ext == "java" || ext == "kt") && s ~ /\.(matches|replaceAll|replaceFirst)\("/))
    emit(n, "PF-04", "루프 안 정규식 컴파일 — 반복마다 다시 컴파일한다. 루프 밖 상수로 뺀다")
  if (s ~ /\.(contains|indexOf|includes|lastIndexOf|containsValue)\([^"\047`)]/)
    emit(n, "PF-05", "루프 안 선형 탐색 — 대상이 List · 배열이면 O(n·m) 이다. Set · Map 으로 바꾼다 (이미 Set · Map 이면 무시)")
  if (s ~ /[a-zA-Z0-9_\]][ \t]*\+=[ \t]*("|\047|`|str\(|String\.valueOf|fmt\.Sprint|f"|f\047)/)
    emit(n, "PF-06", "루프 안 문자열 누적 — 불변 문자열이면 매번 복사해 O(n²) 이다. StringBuilder · join · strings.Builder 로")
  if (s ~ /\[[ \t]*\.\.\.[a-zA-Z_][a-zA-Z0-9_.]*[ \t]*,/ || s ~ /\.\.\.(acc|accumulator|memo)[^a-zA-Z0-9_]/ ||
      s ~ /=[ \t]*[a-zA-Z_][a-zA-Z0-9_]*[ \t]*\+[ \t]*\[/ || s ~ /[a-zA-Z_)\]]\.concat\(/)
    emit(n, "PF-07", "루프 안 컬렉션 복사 (spread · concat · list + [..]) — 반복마다 전체를 복사해 O(n²) 이다. push · append 로 제자리에서 늘린다")
  if (s ~ /DriverManager\.getConnection|new (ObjectMapper|Gson|HttpClient|RestTemplate|OkHttpClient|SimpleDateFormat|PrismaClient|Pool)\(|HttpClient\.(newHttpClient|newBuilder)\(|sql\.Open\(|requests\.Session\(|httpx\.(Async)?Client\(|create_engine\(|&http\.Client\{|createPool\(/)
    emit(n, "PF-08", "루프 안 무거운 객체 · 커넥션 생성 — 반복마다 만들고 버린다. 한 번 만들어 재사용한다 (커넥션은 풀로)")
}
# 줄 하나에 대한 파일 수준 규칙. s = 주석 뺀 줄, u = 대문자
function anyline(n, s, u,   j, look) {
  if (u ~ /SELECT[ \t]+(DISTINCT[ \t]+)?\*[ \t]*(FROM|$|["\047`])/ || u ~ /SELECT[ \t]+[A-Z_][A-Z0-9_]*\.\*[ \t]+FROM/)
    emit(n, "PF-10", "SELECT * — 안 쓰는 컬럼까지 읽고 커버링 인덱스를 못 쓴다. 필요한 컬럼만 적는다")
  if (u ~ /(^|[^A-Z_])OFFSET[ \t]+[:?$@#{0-9%]/ || s ~ /\.offset\(/ || s ~ /(^|[^a-zA-Z_])skip:[ \t]*[a-zA-Z_(]/)
    emit(n, "PF-11", "OFFSET 페이지네이션 — 건너뛴 행을 모두 읽어 뒤 페이지일수록 느리다. 큰 테이블은 keyset(WHERE id > :last ORDER BY id) 으로")
  if (s ~ /\.findAll\(\)/ || s ~ /\.objects\.all\(\)/ || s ~ /\.findMany\(\)/ || s ~ /\.find\(\{\}\)/ || s ~ /\.query\([^()]*\)\.all\(\)/ || s ~ /\.selectAll\(\)/)
    emit(n, "PF-12", "상한 없는 전체 조회 — 행 수만큼 메모리 · 응답이 커진다. 페이지 · limit · 스트림(iterator · Stream · cursor) 으로")
  if (u ~ /LIKE[ \t]+[\047"]%/ || u ~ /LIKE[ \t]+CONCAT\([ \t]*[\047"]%/ || s ~ /__i?contains=/ || s ~ /Containing(IgnoreCase)?\(/)
    emit(n, "PF-13", "앞에 % 가 붙는 LIKE · contains 검색 — B-tree 인덱스를 못 타고 전체를 훑는다. 접두 검색이나 전문 검색 인덱스(trigram · FTS) 로")
  if (u ~ /ORDER[ \t]+BY[ \t]+(RAND|RANDOM|NEWID)\(/)
    emit(n, "PF-14", "ORDER BY RAND() — 전체 행을 정렬한다. 키 범위에서 무작위로 고르거나 TABLESAMPLE 로")
  if (lang == "py" && s ~ /requests\.(get|post|put|patch|delete|head|request)\(/) {
    if (call_text(n, s) !~ /timeout/) emit(n, "PF-16", "requests 호출에 timeout 이 없다 — 기본값은 무한 대기다. timeout=(연결, 읽기) 를 준다")
  }
  if (ext == "go" && (s ~ /http\.(Get|Post|Head|PostForm)\(/ || s ~ /http\.Client\{[ \t]*\}/ || s ~ /http\.DefaultClient\./))
    emit(n, "PF-16", "Go 기본 HTTP 클라이언트는 타임아웃이 없다 — http.Client{Timeout: …} 이나 context 데드라인을 쓴다")
  if (s ~ /\((\?:)?(\\[a-zA-Z.]|\.|\[[^]]*\]|[a-zA-Z0-9])[*+]\)[*+{]/ || s ~ /\.\*[^"\047`]*\.\*[^"\047`]*\.\*/)
    emit(n, "PF-17", "역추적이 폭발할 수 있는 정규식 (중첩 수량자 · .* 반복) — 사용자 입력에 쓰면 ReDoS 다. 패턴을 고치거나 선형 엔진(RE2 계열) · 입력 길이 상한을 쓴다")
  if (s ~ /FetchType\.EAGER/) {
    emit(n, "PF-18", "EAGER 연관 — 엔티티를 읽을 때마다 연관까지 읽고 목록에서는 N+1 이 된다. LAZY 로 두고 필요한 곳에서 join fetch · @EntityGraph")
  } else if (s ~ /@(ManyToOne|OneToOne)([^a-zA-Z]|$)/) {
    look = s; if (n < NL && L[n+1] ~ /^[ \t]*\(/) look = call_text(n + 1, L[n+1])
    if (call_text(n, look) !~ /LAZY/) emit(n, "PF-18", "@ManyToOne · @OneToOne 의 기본 fetch 는 EAGER 다 — fetch = FetchType.LAZY 를 적는다")
  }
  if (s ~ /lru_cache\([ \t]*maxsize[ \t]*=[ \t]*None/ || s ~ /^[ \t]*@(functools\.)?cache[ \t]*$/ ||
      s ~ /static[ \t]+(final[ \t]+)?(Map|HashMap|ConcurrentHashMap|List|ArrayList|Set|HashSet)[ \t<][^=;]*=[ \t]*new[ \t]/)
    emit(n, "PF-19", "상한 없는 캐시 · static 컬렉션 — 프로세스가 사는 동안 계속 커진다. 크기 상한 · TTL 이 있는 캐시(LRU · Caffeine) 로")
  if (s ~ /len\([^)]*\.(objects\.|all\(\)|filter\(|fetchall\(\))/ || s ~ /findAll\([^)]*\)\.(size|isEmpty)\(\)/ || s ~ /\.findMany\([^)]*\)\)?\.length/ || s ~ /\.(all|list)\(\)\.(size|count|isEmpty)\(\)/)
    emit(n, "PF-20", "개수 · 존재 확인에 전체 로딩 — count() · exists() · COUNT(*) · LIMIT 1 로")
}
{ L[NR] = (length($0) > 2000) ? "" : $0 }   # 압축된 줄은 보지 않는다
END {
  NL = NR
  RE["("] = "\\("; RE[")"] = "\\)"; RE["["] = "\\["; RE["]"] = "\\]"; RE["{"] = "\\{"; RE["}"] = "\\}"
  # JS · TS 동기 IO 는 비동기 서버 코드가 있는 파일에서만 본다
  hasAsync = 0
  for (n = 1; n <= NL; n++) if (L[n] ~ /(^|[^a-zA-Z_])async[ \t(]/ || L[n] ~ /express\(|@nestjs|fastify|koa/) { hasAsync = 1; break }
  isjs = (ext == "js" || ext == "ts" || ext == "mjs" || ext == "cjs" || ext == "jsx" || ext == "tsx")
  sp = 0; asp = 0; depth = 0; pdepth = 0; pending = 0
  for (n = 1; n <= NL; n++) {
    raw = L[n]
    skip = (raw ~ /performance-ignore/ || (n > 1 && L[n-1] ~ /performance-ignore/))
    code = raw
    if (lang == "py") {
      if (code ~ /^[ \t]*#/) continue
      sub(/[ \t]+#[^"\047]*$/, "", code)
    } else if (lang == "sql") {
      if (code ~ /^[ \t]*--/) continue
    } else {
      if (code ~ /^[ \t]*(\/\/|\/\*|\*)/) continue
      sub(/[ \t]+\/\/[^"\047`]*$/, "", code)
    }
    if (code ~ /^[ \t]*$/) continue
    ns = nostr(code)
    u = toupper(code)

    if (lang == "sql") { if (!skip) anyline(n, code, u); continue }

    if (lang == "py") {
      cont = (pdepth > 0)
      if (!cont) {
        ind = indent(code)
        while (sp > 0 && LI[sp] >= ind) sp--
        while (asp > 0 && AI[asp] >= ind) asp--
      }
      if (!skip) {
        if (sp > 0) in_loop(n, code, LK[sp], LS[sp])
        # 컴프리헨션 [f(x) for x in xs] — for 앞이 반복되는 식이다
        if (ns ~ /[\[({][^\[({]*[^a-zA-Z_]for[ \t]+[a-zA-Z_][a-zA-Z0-9_, ]*[ \t]+in[ \t]/) {
          p = match(code, /[^a-zA-Z_]for[ \t]+[a-zA-Z_][a-zA-Z0-9_, ]*[ \t]+in[ \t]/)
          if (p > 0) in_loop(n, substr(code, 1, p), 0, n)
        }
        # 한 줄 루프 for x in xs: f(x)
        if (!cont && ns ~ /^[ \t]*(async[ \t]+)?(for|while)[ \t].*:[ \t]*[^ \t]/) {
          p = match(code, /:[ \t]*[^ \t:][^:]*$/); if (p > 0) in_loop(n, substr(code, p + 1), serial_ok(code) ? 0 : 1, n)
        }
        if (asp > 0 && !AS[asp] && code ~ /time\.sleep\(|requests\.[a-z]+\(|urlopen\(|subprocess\.(run|call|check_call|check_output)\(|(^|[^a-zA-Z_.])open\(/)
          emit(n, "PF-15", "async 함수 안의 블로킹 호출 — 이벤트 루프 전체가 멈춘다. asyncio.sleep · httpx.AsyncClient · aiofiles · asyncio.to_thread 로")
        anyline(n, code, u)
      }
      if (!cont) {
        if (ns ~ /^[ \t]*(async[ \t]+)?(for|while)[ \t(].*:[ \t]*$/) { sp++; LI[sp] = ind; LK[sp] = serial_ok(code) ? 0 : 1; LS[sp] = n }
        if (ns ~ /^[ \t]*async[ \t]+def[ \t]/) { asp++; AI[asp] = ind; AS[asp] = 0 }
        else if (ns ~ /^[ \t]*def[ \t]/ && asp > 0) { asp++; AI[asp] = ind; AS[asp] = 1 }
      }
      pdepth += count(ns, "(") + count(ns, "[") + count(ns, "{") - count(ns, ")") - count(ns, "]") - count(ns, "}")
      if (pdepth < 0) pdepth = 0
      continue
    }

    # 중괄호 계열
    d0 = depth
    if (pending) {
      if (ns ~ /^[ \t]*\{/) { sp++; LD[sp] = d0; LK[sp] = pkw; LS[sp] = PL; pending = 0 }
      else { pending = 0; if (!skip) in_loop(n, code, pkw, PL) }
    }
    started = 0; body = ""; kind = 0; pos = 0
    kwp = match(code, /(^|[^a-zA-Z0-9_.$])(for|while)[ \t]*(\(|[a-zA-Z_{]|$)/)
    cbp = match(code, /\.(forEach|forEachIndexed|forEachOrdered|map|mapNotNull|mapIndexed|flatMap|filter|reduce|fold|each|onEach|sumOf|associate[A-Za-z]*|groupBy)[ \t]*[({]/)
    if (kwp > 0 && (cbp == 0 || kwp < cbp)) { started = 1; kind = 1; pos = kwp }
    else if (cbp > 0) { started = 1; kind = 0; pos = cbp }
    if (started) {
      rest = substr(code, pos)
      if (kind == 1) {
        b = index(rest, "{")
        if (b > 0) body = substr(rest, b + 1)
        else if (ext != "go") { q = match(rest, /\)[ \t]*[^ \t;{)]/); if (q > 0) body = substr(rest, q + 1) }
      } else {
        b = match(rest, /(=>|->|\{)/)
        body = (b > 0) ? substr(rest, b + RLENGTH) : substr(rest, 2)
      }
    }
    kw = (kind == 1 && code !~ /for[ \t]+await/ && !serial_ok(code))
    if (!skip) {
      if (sp > 0) in_loop(n, code, LK[sp], LS[sp])
      if (started && body != "") in_loop(n, body, kw, n)
      if (hasAsync && isjs && code ~ /(readFileSync|writeFileSync|appendFileSync|readdirSync|statSync|existsSync|execSync|spawnSync|execFileSync)\(/)
        emit(n, "PF-15", "동기 IO — 끝날 때까지 이벤트 루프 전체가 멈춘다. fs/promises · 비동기 child_process 로 (시작 때 한 번 읽는 설정이면 무시)")
      anyline(n, code, u)
    }
    opens = count(ns, "{"); closes = count(ns, "}")
    if (started) {
      pre = nostr(substr(code, 1, pos - 1)); after = nostr(substr(code, pos))
      if (index(after, "{") > 0) { sp++; LD[sp] = d0 + count(pre, "{") - count(pre, "}"); LK[sp] = kw; LS[sp] = n }
      else if (kind == 1 && body == "") { pending = 1; pkw = kw; PL = n }
    }
    depth = d0 + opens - closes
    if (depth < 0) depth = 0
    while (sp > 0 && depth <= LD[sp]) sp--
  }
}
' "$f"
}

# 훅: 이번에 쓴 줄(Write 는 전체, Edit 는 new_string)에서 나온 것만
if [ "$#" -eq 0 ] && [ ! -t 0 ]; then
  INPUT="$(cat)"
  if [ -n "$INPUT" ] && printf '%s' "$INPUT" | jq -e '.hook_event_name' >/dev/null 2>&1; then
    [ "$(printf '%s' "$INPUT" | jq -r '.hook_event_name')" = "PostToolUse" ] || exit 0
    F="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')"
    [ -n "$F" ] && [ -f "$F" ] || exit 0
    [ -n "$(lang_of "$F")" ] || exit 0
    ! is_test_path "$(rel_of "$(base_of "$(dirname "$F")")" "$F")" || exit 0
    NEW="$(printf '%s' "$INPUT" | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty, (.tool_input.edits // [] | .[].new_string)] | join("\n")' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$NEW" ] || exit 0
    OUT=""; TOTAL=0
    while IFS=$'\x1f' read -r ln rule msg; do
      [ -n "$ln" ] || continue
      src="$(sed -n "${ln}p" "$F" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -n "$src" ] || continue
      printf '%s\n' "$NEW" | grep -qxF -- "$src" || continue
      TOTAL=$((TOTAL+1))
      [ "$TOTAL" -le 10 ] && OUT="${OUT}- ${ln}행 ${rule} ${msg}
"
    done <<EOF
$(check_file "$F")
EOF
    [ "$TOTAL" -gt 0 ] || exit 0
    [ "$TOTAL" -gt 10 ] && OUT="${OUT}- … 외 $((TOTAL - 10))건 — performance-validate.sh 로 전체를 본다
"
    MSG="성능 위험 패턴 (common-performance-review) — ${F##*/}
${OUT}패턴은 후보다. 호출 맥락 · 데이터 규모를 읽고 판정한다 (performance-review 스킬). 의도한 것이면 그 줄에 performance-ignore 주석.
규칙: $RULES"
    jq -n --arg c "$MSG" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
    exit 0
  fi
  # 훅 이벤트가 아닌 JSON 은 훅 입력이 깨진 것이다 — 조용히 끝낸다
  [ -n "$INPUT" ] && printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 && exit 0
fi

STRICT=0; DIFF=0; BASE=""; TESTS=0
TARGETS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --include-tests) TESTS=1 ;;
    --diff)
      DIFF=1
      if [ "$#" -gt 1 ] && [ "${2#-}" = "$2" ] && git rev-parse --verify -q "$2^{commit}" >/dev/null 2>&1; then BASE="$2"; shift; fi ;;
    -*) die "모르는 옵션: $1" ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

# 대상 파일과, 볼 줄 번호 목록 (빈 문자열이면 전체)
FILES=(); LINESETS=()
add_file() { FILES+=("$1"); LINESETS+=("$2"); }
BASE_DIR=""
want() { # $1=경로 — 볼 파일인가 (테스트 판정은 BASE_DIR 기준)
  [ -n "$(lang_of "$1")" ] || return 1
  [ "$TESTS" = 1 ] && return 0
  ! is_test_path "$(rel_of "$BASE_DIR" "$1")"
}
# 디렉터리 → 파일 목록. git 작업 트리면 .gitignore 를 따른다
list_dir() {
  local t="${1%/}"
  if git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$t" ls-files --cached --others --exclude-standard -- . | sed "s#^#$t/#" | grep -v -E '/(node_modules|vendor|dist|build|target)/|\.min\.js$' | sort -u
    return
  fi
  find "$t" -type f -size -1024k \( -name '*.py' -o -name '*.java' -o -name '*.kt' -o -name '*.kts' -o -name '*.scala' -o -name '*.go' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.cs' -o -name '*.php' -o -name '*.swift' -o -name '*.rs' -o -name '*.sql' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path "$t/.claude/*" -not -path '*/build/*' -not -path '*/target/*' -not -path '*/dist/*' \
    -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' -not -path '*/.next/*' -not -path '*/coverage/*' -not -name '*.min.js' | sort
}

if [ "$DIFF" = 1 ]; then
  TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die "--diff 는 git 저장소 안에서만 쓴다"
  if [ -z "$BASE" ]; then
    BASE="$(git -C "$TOP" merge-base HEAD origin/HEAD 2>/dev/null || git -C "$TOP" merge-base HEAD origin/main 2>/dev/null || git -C "$TOP" rev-parse HEAD)"
  fi
  BASE_DIR="$TOP"
  while IFS= read -r rel; do
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && want "$TOP/$rel" || continue
    lines="$(git -C "$TOP" diff -U0 "$BASE" -- "$rel" | awk '/^@@/ { s = $3; sub(/^\+/, "", s); k = split(s, a, ","); c = (k < 2) ? 1 : a[2]; for (i = 0; i < c; i++) printf " %d", a[1] + i }')"
    [ -n "$lines" ] && add_file "$TOP/$rel" "$lines"
  done <<EOF
$(git -C "$TOP" diff --name-only --diff-filter=AMR "$BASE")
EOF
  # 추적 안 된 새 파일은 전부 추가된 줄이다
  while IFS= read -r rel; do
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && want "$TOP/$rel" || continue
    add_file "$TOP/$rel" ""
  done <<EOF
$(git -C "$TOP" ls-files --others --exclude-standard)
EOF
else
  [ "${#TARGETS[@]}" -gt 0 ] || TARGETS=(".")
  for t in "${TARGETS[@]}"; do
    [ -e "$t" ] || die "없는 경로: $t"
    if [ -d "$t" ]; then
      BASE_DIR="$(base_of "$t")"; td="$(cd "$t" && pwd -P)"
      case "$td/" in "$BASE_DIR"/*) ;; *) BASE_DIR="$td" ;; esac
      while IFS= read -r f; do
        [ -n "$f" ] && [ -f "$f" ] && want "$f" || continue
        add_file "$f" ""
      done <<EOF
$(list_dir "$t")
EOF
    else
      add_file "$t" ""
    fi
  done
fi

N=0; W=0
for i in ${FILES+"${!FILES[@]}"}; do
  f="${FILES[$i]}"; set_="${LINESETS[$i]}"
  N=$((N+1)); OUT=""
  while IFS=$'\x1f' read -r ln rule msg; do
    [ -n "$ln" ] || continue
    if [ -n "$set_" ]; then case "$set_ " in *" $ln "*) ;; *) continue ;; esac; fi
    OUT="${OUT}  - ${ln}행 ${rule} ${msg}
"
    W=$((W+1))
  done <<EOF
$(check_file "$f")
EOF
  [ -z "$OUT" ] || { echo "⚠️  $f"; printf '%s' "$OUT"; }
done

if [ "$DIFF" = 1 ]; then SCOPE="변경 파일 ${N}개 (기준 $(git -C "$TOP" rev-parse --short "$BASE"))"; else SCOPE="파일 ${N}개"; fi
echo "${SCOPE}, 경고 ${W}건 — 패턴은 후보다. 판정은 performance-review 스킬 · 규칙: $RULES"
[ "$STRICT" = 1 ] && [ "$W" -gt 0 ] && exit 2
exit 0
