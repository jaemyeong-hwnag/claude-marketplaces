#!/usr/bin/env bash
# scripts/performance-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/performance-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/performance-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
cd "$TMP" || exit 1

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
run_stdin() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
# 파일 하나를 만들어 검사한다 — $1=이름 (내용은 stdin)
scan() { [ "$TC_ON" = 1 ] || { cat >/dev/null; return 0; }; local d; d="$(mktemp -d "$TMP/s.XXXXXX")"; cat > "$d/$1"; run "$d/$1"; }
payload() { # $1=이벤트 $2=경로 $3=content
  jq -n --arg e "$1" --arg f "$2" --arg c "$3" '{hook_event_name: $e, tool_name: "Write", tool_input: {file_path: $f, content: $c}}'
}

echo "== A. 루프 안 패턴 (PF-01 ~ PF-08)"

tc TC-P01 "루프 본문의 리포지토리 호출은 PF-01, 루프 헤더의 호출은 아니다"
scan A.java <<'EOF'
class A {
  void f() {
    for (Long id : orderRepository.findAll()) {
      Order o = orderRepository.findById(id);
    }
  }
}
EOF
expect_out "4행 PF-01"; expect_not "3행 PF-01"

tc TC-P02 "루프 밖 DB 호출 · 주석 속 루프는 보지 않는다"
scan B.java <<'EOF'
class B {
  void f() {
    // for (x : xs) { repo.save(x); }
    repo.save(z);
  }
}
EOF
expect_not "PF-01"

tc TC-P03 "콜백 반복(forEach · map 람다) 안의 호출도 루프다"
scan C.java <<'EOF'
class C {
  void f() {
    ids.forEach(id -> repo.save(id));
    ids.stream().map(id -> {
      return restTemplate.getForObject(url, X.class);
    });
  }
}
EOF
expect_out "3행 PF-01"; expect_out "5행 PF-02"

tc TC-P04 "중괄호 없는 한 줄 for 본문 · 다음 줄 본문"
scan D.java <<'EOF'
class D {
  void f() {
    for (int i = 0; i < n; i++) jdbc.query("select 1");
    for (int i = 0; i < n; i++)
      jdbc.query("select 2");
    jdbc.query("select 3");
  }
}
EOF
expect_out "3행 PF-01"; expect_out "5행 PF-01"; expect_not "6행 PF-01"

tc TC-P16 "페이지 · 배치 단위로 읽는 루프의 조회는 PF-01 이 아니다"
scan P.kt <<'EOF'
fun f() {
    while (true) {
        val r = videoRepository.findByStatus(
            status = S,
            pageable = PageRequest.of(page, 100),
        )
        ids.forEach { repo.findById(it) }
    }
}
EOF
expect_not "3행 PF-01"; expect_out "7행 PF-01"

tc TC-P05 "루프가 닫힌 뒤의 줄은 루프 밖이다"
scan E.ts <<'EOF'
for (const x of xs) {
  if (x) { y(); }
}
const r = await fetch(url);
EOF
expect_not "PF-02"

tc TC-P06 "Python 들여쓰기 루프 · 컴프리헨션 · 한 줄 루프"
scan svc.py <<'EOF'
def f(ids):
    for i in ids:
        u = User.objects.get(id=i)
    users = [User.objects.get(id=i) for i in ids]
    for i in ids: Item.objects.filter(a=i)
    done = User.objects.get(id=1)
    for row in cursor.execute("select a"):
        print(row)
EOF
expect_out "3행 PF-01"; expect_out "4행 PF-01"; expect_out "5행 PF-01"; expect_not "6행 PF-01"; expect_not "7행 PF-01"

tc TC-P07 "Python 여러 줄 호출의 이어진 줄은 루프를 끝내지 않는다"
scan cont.py <<'EOF'
def f(ids):
    for i in ids:
        x = g(
  i)
        requests.post(url, timeout=1)
EOF
expect_out "5행 PF-02"

tc TC-P08 "Go range 루프의 db.QueryRow · http.Get"
scan m.go <<'EOF'
package m
func f(ids []int) {
	for _, id := range ids {
		row := db.QueryRow("select a from t where id = ?", id)
		resp, _ := http.Get(u)
	}
	ok := db.Query("select a from t")
}
EOF
expect_out "4행 PF-01"; expect_out "5행 PF-02"; expect_not "7행 PF-01"

tc TC-P09 "for 안의 await 는 PF-03, Promise.all(map(async)) 는 아니다"
scan a.ts <<'EOF'
export async function h(ids: string[]) {
  for (const id of ids) {
    const u = await load(id);
  }
  await Promise.all(ids.map(async (id) => await load(id)));
  for await (const c of stream) { await handle(c); }
}
EOF
expect_out "3행 PF-03"; expect_not "5행 PF-03"; expect_not "6행 PF-03"

tc TC-P14 "PF-03 은 루프마다 한 번, while · 재시도 루프 · sleep 은 제외"
scan w.py <<'EOF'
async def f(ids):
    for i in ids:
        await a(i)
        await b(i)
    for attempt in range(3):
        await call()
    while True:
        await poll()
    for i in ids:
        await asyncio.sleep(1)
EOF
expect_out "3행 PF-03"; expect_not "4행 PF-03"; expect_not "6행 PF-03"; expect_not "8행 PF-03"; expect_not "10행 PF-03"

tc TC-P15 "HTTP 세션 · 클라이언트의 get 은 PF-02 (DB 로 보지 않는다)"
scan hs.py <<'EOF'
async def f(ids):
    for i in ids:
        r = await self._session.get(url)
EOF
expect_out "3행 PF-02"; expect_not "PF-01"

tc TC-P10 "await 와 원격 호출이 한 줄이면 PF-02 만"
scan b.ts <<'EOF'
async function h(ids) {
  for (const id of ids) {
    const r = await fetch(`/u/${id}`);
  }
}
EOF
expect_out "3행 PF-02"; expect_not "PF-03"

tc TC-P11 "루프 안 정규식 컴파일 · 선형 탐색 · 문자열 누적"
scan F.java <<'EOF'
class F {
  void f() {
    for (String s : xs) {
      Pattern p = Pattern.compile("a+");
      if (seen.contains(s)) {}
      if (s.contains("lit")) {}
      out += "x";
      n += 1;
    }
  }
}
EOF
expect_out "4행 PF-04"; expect_out "5행 PF-05"; expect_not "6행 PF-05"; expect_out "7행 PF-06"; expect_not "8행 PF-06"

tc TC-P12 "루프 안 spread 누적 · reduce 의 ...acc"
scan c.ts <<'EOF'
for (const x of xs) arr = [...arr, x];
const out = ids.reduce((acc, x) => ({...acc, [x]: 1}), {});
const merged = [...a, ...b];
const rows = xs.map(r => ({ ...r, enabled }));
EOF
expect_out "1행 PF-07"; expect_out "2행 PF-07"; expect_not "3행 PF-07"; expect_not "4행 PF-07"

tc TC-P13 "루프 안 무거운 객체 · 커넥션 생성"
scan G.java <<'EOF'
class G {
  void f() {
    for (String s : xs) {
      ObjectMapper m = new ObjectMapper();
    }
    ObjectMapper once = new ObjectMapper();
  }
}
EOF
expect_out "4행 PF-08"; expect_not "6행 PF-08"

echo "== B. 파일 수준 패턴 (PF-10 ~ PF-20)"

tc TC-P20 "SELECT * · OFFSET · 앞 % LIKE · ORDER BY RAND()"
scan q.sql <<'EOF'
SELECT * FROM orders WHERE name LIKE '%kim' OFFSET 100;
SELECT id FROM orders ORDER BY RAND();
SELECT COUNT(*) FROM orders;
-- SELECT * FROM comment_only;
EOF
expect_out "1행 PF-10"; expect_out "1행 PF-11"; expect_out "1행 PF-13"; expect_out "2행 PF-14"; expect_not "3행 PF-10"; expect_not "4행"

tc TC-P21 "상한 없는 조회 · 개수에 전체 로딩"
scan h.py <<'EOF'
x = User.objects.all()
n = len(User.objects.filter(a=1))
y = User.objects.filter(a=1)[:20]
EOF
expect_out "1행 PF-12"; expect_out "2행 PF-20"; expect_not "3행"

tc TC-P22 "Python async 안 블로킹 — 안쪽 동기 함수는 제외"
scan as.py <<'EOF'
import time
async def handler():
    time.sleep(1)
    def inner():
        time.sleep(1)
def sync():
    time.sleep(1)
EOF
expect_out "3행 PF-15"; expect_not "5행 PF-15"; expect_not "7행 PF-15"

tc TC-P23 "JS 동기 IO 는 비동기 코드가 있는 파일에서만"
scan s1.ts <<'EOF'
export async function h() { const s = fs.readFileSync('a'); }
EOF
expect_out "1행 PF-15"
scan s2.js <<'EOF'
const cfg = fs.readFileSync('config.json');
EOF
expect_not "PF-15"

tc TC-P24 "requests timeout — 다음 줄의 timeout 은 인정한다"
scan t.py <<'EOF'
requests.get(url)
requests.get(url,
    timeout=3)
EOF
expect_out "1행 PF-16"; expect_not "2행 PF-16"

tc TC-P25 "Go 기본 HTTP 클라이언트"
scan c.go <<'EOF'
package c
func f() {
	c := &http.Client{}
	ok := &http.Client{Timeout: 3 * time.Second}
}
EOF
expect_out "3행 PF-16"; expect_not "4행 PF-16"

tc TC-P26 "중첩 수량자 정규식은 PF-17, 평범한 정규식은 아니다"
scan r.ts <<'EOF'
const bad = /^(a+)+$/;
const ok = /^[a-z]+$/;
const sep = /^K200(_[A-Z0-9]+)*$/;
EOF
expect_out "1행 PF-17"; expect_not "2행 PF-17"; expect_not "3행 PF-17"

tc TC-P27 "EAGER · LAZY 없는 @ManyToOne, LAZY 면 통과"
scan J.java <<'EOF'
class J {
  @ManyToOne
  Customer c;
  @ManyToOne(fetch = FetchType.LAZY)
  Customer d;
  @OneToMany(fetch = FetchType.EAGER)
  List<Item> items;
}
EOF
expect_out "2행 PF-18"; expect_not "4행 PF-18"; expect_out "6행 PF-18"

tc TC-P28 "상한 없는 캐시 · static 컬렉션"
scan k.py <<'EOF'
@lru_cache(maxsize=None)
def f(): pass
@lru_cache(maxsize=128)
def g(): pass
EOF
expect_out "1행 PF-19"; expect_not "3행 PF-19"

echo "== C. 억제 · 범위"

tc TC-P40 "performance-ignore 는 그 줄과 다음 줄만 끈다"
scan I.java <<'EOF'
class I {
  void f() {
    for (Long id : ids) {
      repo.save(id); // performance-ignore
      // performance-ignore
      repo.save(id);
      repo.save(id);
    }
  }
}
EOF
expect_not "4행 PF-01"; expect_not "6행 PF-01"; expect_out "7행 PF-01"

tc TC-P41 "디렉터리 검사는 node_modules · 테스트 경로를 건너뛴다, --include-tests 면 본다"
if [ "$TC_ON" = 1 ]; then
  D="$TMP/dir"; mkdir -p "$D/src" "$D/node_modules/x" "$D/tests"
  printf 'x = User.objects.all()\n' > "$D/src/a.py"
  printf 'x = User.objects.all()\n' > "$D/node_modules/x/b.py"
  printf 'x = User.objects.all()\n' > "$D/tests/test_c.py"
  printf 'x = User.objects.all()\n' > "$D/README.md"
fi
run "$D"; expect_out "src/a.py"; expect_not "node_modules"; expect_not "test_c.py"; expect_out "파일 1개"
run --include-tests "$D"; expect_out "test_c.py"

tc TC-P42 "--strict 는 경고가 있으면 exit 2, 없으면 0"
if [ "$TC_ON" = 1 ]; then
  printf 'x = User.objects.all()\n' > "$TMP/bad.py"; printf 'x = 1\n' > "$TMP/good.py"
fi
run --strict "$TMP/bad.py"; expect_code 2
run --strict "$TMP/good.py"; expect_code 0
run "$TMP/bad.py"; expect_code 0

tc TC-P43 "--diff 는 기준 이후 추가된 줄과 추적 안 된 새 파일만 본다"
if [ "$TC_ON" = 1 ]; then
  R="$TMP/repo"; mkdir -p "$R"
  ( cd "$R" && git init -q -b main . && printf 'old = User.objects.all()\n' > a.py && git add a.py && git commit -qm init
    printf 'old = User.objects.all()\nnew = Item.objects.all()\n' > a.py
    printf 'z = len(Order.objects.filter(a=1))\n' > b.py )
fi
OUT="$(cd "$R" && "$SCRIPT" --diff HEAD 2>&1)"; CODE=$?
expect_out "a.py"; expect_out "2행 PF-12"; expect_not "1행 PF-12"; expect_out "1행 PF-20"; expect_out "변경 파일 2개"

tc TC-P44 "모르는 옵션 · 없는 경로는 오류(1)"
run --nope; expect_code 1
run "$TMP/none.py"; expect_code 1

tc TC-P45 "git 작업 트리는 .gitignore 를 따른다"
if [ "$TC_ON" = 1 ]; then
  G="$TMP/gitdir"; mkdir -p "$G/gen"
  ( cd "$G" && git init -q -b main . && printf 'gen/\n' > .gitignore
    printf 'x = User.objects.all()\n' > a.py; printf 'x = User.objects.all()\n' > gen/b.py )
fi
run "$G"; expect_out "a.py"; expect_not "gen/b.py"; expect_out "파일 1개"

echo "== D. 훅"

tc TC-P50 "PostToolUse Write — additionalContext 로 알린다"
if [ "$TC_ON" = 1 ]; then printf 'def f(ids):\n    for i in ids:\n        User.objects.get(id=i)\n' > "$TMP/h.py"; fi
run_stdin "$(payload PostToolUse "$TMP/h.py" "$(cat "$TMP/h.py" 2>/dev/null)")"
expect_code 0; expect_out "additionalContext"; expect_out "PF-01"; expect_out "performance-review"

tc TC-P51 "Edit — 이번에 쓴 줄에서 나온 것만 알린다"
if [ "$TC_ON" = 1 ]; then printf 'x = User.objects.all()\ny = 1\n' > "$TMP/e.py"; fi
EDIT="$(jq -n --arg f "$TMP/e.py" '{hook_event_name: "PostToolUse", tool_name: "Edit", tool_input: {file_path: $f, old_string: "y = 2", new_string: "y = 1"}}')"
run_stdin "$EDIT"; expect_code 0; expect_no_out
EDIT="$(jq -n --arg f "$TMP/e.py" '{hook_event_name: "PostToolUse", tool_name: "Edit", tool_input: {file_path: $f, old_string: "x = 1", new_string: "x = User.objects.all()"}}')"
run_stdin "$EDIT"; expect_out "PF-12"

tc TC-P52 "PreToolUse · 비대상 파일 · 테스트 파일 · 빈 입력은 조용하다"
if [ "$TC_ON" = 1 ]; then mkdir -p "$TMP/tests"; printf 'x = User.objects.all()\n' > "$TMP/tests/test_x.py"; printf 'x = User.objects.all()\n' > "$TMP/n.md"; fi
run_stdin "$(payload PreToolUse "$TMP/h.py" "x")"; expect_code 0; expect_no_out
run_stdin "$(payload PostToolUse "$TMP/n.md" "x = User.objects.all()")"; expect_code 0; expect_no_out
run_stdin "$(payload PostToolUse "$TMP/tests/test_x.py" "x = User.objects.all()")"; expect_code 0; expect_no_out
run_stdin "{}"; expect_code 0; expect_no_out

tc TC-P53 "훅은 경고를 10건으로 자른다"
if [ "$TC_ON" = 1 ]; then : > "$TMP/many.py"; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf 'x%s = User.objects.all()\n' "$i" >> "$TMP/many.py"; done; fi
run_stdin "$(payload PostToolUse "$TMP/many.py" "$(cat "$TMP/many.py" 2>/dev/null)")"
expect_out "외 2건"; expect_not "12행"

flush_tc
echo ""
echo "통과 $PASS / 실패 $FAIL$([ "$SKIP" -gt 0 ] && echo " / 건너뜀 $SKIP")"
[ "$FAIL" = 0 ]
