#!/usr/bin/env bash
# scripts/domain-document-sync.sh 의 회귀 테스트. TC 명세는 test/README.md.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/domain-document-sync.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/domain-document-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/state"; mkdir -p "$TMPDIR"
unset DOMAIN_DOCUMENT_ROOT DOMAIN_DOCUMENT_MAX_LINES

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
section() { flush_tc; echo "── $1"; }
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
hook() { # $1=모드 $2=입력 JSON — 프로젝트는 $REPO
  [ "$TC_ON" = 1 ] || return 0
  OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$REPO" "$SCRIPT" "$1" 2>&1)"; CODE=$?
}
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다"; }

# --- 픽스처: 모든 규칙을 지키는 저장소 — 언어가 셋 섞여 있다 --------------------
S='{"session_id":"tc"}'
ACTIVE='{"session_id":"tc","stop_hook_active":true}'
ACK_FILE="$TMPDIR/domain-document-sync-tc.ack"

make_repo() {
  REPO="$TMP/repo"; rm -rf "$REPO"; mkdir -p "$REPO"; cd "$REPO" || exit 1
  git init -q . && git config user.email tc@example.com && git config user.name tc
  mkdir -p src/main/java/com/shop/order web/src/features/order services/billing docs/domain/order docs/domain/billing docs/domain/glossary
  echo 'class Order {}' > src/main/java/com/shop/order/Order.java
  echo 'export const a = 1' > web/src/features/order/cart.ts
  echo 'test' > web/src/features/order/cart.test.ts
  echo 'def pay(): pass' > services/billing/pay.py
  echo 'x' > README.md
  cat > docs/domain/_index.md <<'EOF'
# 도메인 카탈로그

| 도메인 | 한 줄 | 트리거 | 경로 |
|---|---|---|---|
| **주문 (order)** | 주문 | **말**: 주문 | [order/](order/_meta.md) |
| **결제 (billing)** | 결제 | **말**: 결제 | [billing/](billing/_meta.md) |
| **용어 (glossary)** | 용어 | **말**: 용어 | [glossary/](glossary/_meta.md) |

```markdown
| {자리표시자} | [{slug}/]({slug}/_meta.md) | [깨진 예시](nope.md) |
```
EOF
  cat > docs/domain/order/_meta.md <<'EOF'
---
code:
  - "src/main/java/**/order/**"
  - web/src/features/order/   # 끝 / 는 디렉터리 전체
  - "!**/*.test.*"
---

# 주문 (order) — 도메인 메타

| 파트 | 파일 | 언제 본다 |
|---|---|---|
| 엔티티 | [entities.md](entities.md) | 필드 · 상태 |

관계: [결제](../billing/_meta.md)
EOF
  printf '# 주문 — 엔티티\n\n[결제 흐름](../billing/_meta.md#흐름)\n' > docs/domain/order/entities.md
  printf -- "---\ncode: ['services/billing/**']\n---\n\n# 결제 (billing)\n\n작은 도메인은 메타 하나로 끝난다.\n" > docs/domain/billing/_meta.md
  printf '# 용어 (glossary)\n\n코드 없는 도메인.\n' > docs/domain/glossary/_meta.md
  git add -A && git commit -qm init
  rm -f "$TMPDIR"/domain-document-sync-tc.*
}

make_repo

section "A. validate (D-01 ~ D-08)"

tc TC-A01 "모든 규칙을 지킨 저장소는 통과한다 — 경고 없음"
run validate "$REPO"; expect_code 0; expect_out "도메인 3개, 위반 없음, 경고 0건"

tc TC-A02 "문서 루트가 없으면 막는다 (D-01)"
mkdir -p "$TMP/empty"; run validate "$TMP/empty"; expect_code 2; expect_out "D-01"

tc TC-A03 "_index.md 가 없으면 막는다 (D-01)"
make_repo; rm docs/domain/_index.md; run validate "$REPO"; expect_code 2; expect_out "D-01"

tc TC-A04 "_meta.md 없는 도메인 디렉터리를 막는다 (D-02)"
make_repo; mkdir docs/domain/stock; echo '# s' > docs/domain/stock/items.md; run validate "$REPO"; expect_code 2; expect_out "D-02 docs/domain/stock"

tc TC-A05 "kebab-case 가 아닌 slug 를 막는다 (D-03)"
make_repo; mkdir docs/domain/Stock_Item; echo '# s' > docs/domain/Stock_Item/_meta.md; run validate "$REPO"; expect_code 2; expect_out "D-03"

tc TC-A06 "카탈로그에 없는 도메인을 막는다 (D-04)"
make_repo; mkdir docs/domain/stock; echo '# s' > docs/domain/stock/_meta.md; run validate "$REPO"; expect_code 2; expect_out "D-04 stock"

tc TC-A07 "메타 파트 표에 없는 concept 을 막는다 (D-05)"
make_repo; echo '# f' > docs/domain/order/flows.md; git add -A; run validate "$REPO"; expect_code 2; expect_out "D-05 docs/domain/order/flows.md"

tc TC-A08 "./ 로 시작하거나 #앵커가 붙은 링크도 등재로 본다 (D-05 과잉 차단 방지)"
make_repo; echo '# f' > docs/domain/order/flows.md; echo '- [흐름](./flows.md#1) · [x](flows.md)' >> docs/domain/order/_meta.md
run validate "$REPO"; expect_code 0

tc TC-A09 "깨진 상대 링크를 막는다 (D-06)"
make_repo; echo '[x](../nowhere/_meta.md)' >> docs/domain/order/entities.md; run validate "$REPO"; expect_code 2; expect_out "D-06"

tc TC-A10 "코드 블록 · {} 자리표시자 · 외부 URL · 앵커 링크는 보지 않는다 (D-06 과잉 차단 방지)"
make_repo; printf '[a](https://example.com/x.md) [b](#top) [c](mailto:a@b)\n' >> docs/domain/order/entities.md
run validate "$REPO"; expect_code 0; expect_not "nope.md"

tc TC-A11 "concept 이 300줄을 넘으면 경고만 한다 (D-07)"
make_repo; seq 1 301 >> docs/domain/order/entities.md; run validate "$REPO"; expect_code 0; expect_out "D-07"

tc TC-A12 "DOMAIN_DOCUMENT_MAX_LINES 로 상한을 바꾼다"
make_repo; OUT="$(DOMAIN_DOCUMENT_MAX_LINES=2 "$SCRIPT" validate "$REPO" 2>&1)"; CODE=$?; expect_code 0; expect_out "D-07"

tc TC-A13 "걸리는 파일이 없는 code 글롭을 경고한다 (D-08)"
make_repo; git rm -rq services; git commit -qm rm; run validate "$REPO"; expect_code 0; expect_out "D-08 billing"

tc TC-A14 "DOMAIN_DOCUMENT_ROOT 로 문서 루트를 바꾼다"
make_repo; mkdir -p kb; git mv -k docs/domain kb/domains; git commit -qm mv
OUT="$(DOMAIN_DOCUMENT_ROOT=kb/domains "$SCRIPT" validate "$REPO" 2>&1)"; CODE=$?; expect_code 0; expect_out "도메인 3개"

section "B. code 글롭 (map)"

tc TC-B01 "블록 목록 · 인라인 목록 · 디렉터리 글롭 · ! 제외를 읽는다"
make_repo; run map "$REPO"
expect_out "src/main/java/**/order/**"; expect_out "services/billing/**"; expect_out "!**/*.test.*"
[ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | awk '/^order$/{o=1} o && /→/{print; exit}' | grep -q "파일 2개" || fail_tc "order 는 2개 (Java 1 + TS 1, 테스트 제외)"; }

tc TC-B02 "code 가 없는 도메인은 게이트 대상이 아니라고 표시한다"
run map "$REPO"; expect_out "code 없음"

tc TC-B03 "* 는 / 를 넘지 않는다 — 한 단계 글롭이 깊은 파일을 잡지 않는다"
make_repo; printf -- '---\ncode:\n  - "services/*"\n---\n# 결제\n' > docs/domain/billing/_meta.md
mkdir -p services/billing/deep; echo x > services/billing/deep/a.py
run map "$REPO"
[ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | awk '/^billing$/{o=1} o && /→/{print; exit}' | grep -q "파일 0개" || fail_tc "services/* 는 services/billing/pay.py 를 잡지 않아야 한다"; }

section "C. 동기 게이트 (S-01)"

tc TC-C01 "코드가 안 바뀐 요청(질문 · 조회)은 막지 않는다"
make_repo; hook snapshot "$S"; hook stop "$S"; expect_code 0; expect_no_out

tc TC-C02 "Java 도메인 코드만 바뀌면 막는다"
make_repo; hook snapshot "$S"; echo 'class Order { int total; }' > src/main/java/com/shop/order/Order.java
hook stop "$S"; expect_code 2; expect_out "S-01"; expect_out "order: src/main/java/com/shop/order/Order.java"; expect_not "billing"

tc TC-C03 "TypeScript 새 파일(untracked)도 잡는다"
make_repo; hook snapshot "$S"; echo 'export const b = 2' > web/src/features/order/checkout.ts
hook stop "$S"; expect_code 2; expect_out "web/src/features/order/checkout.ts"

tc TC-C04 "Python 도메인(인라인 code 목록)도 잡는다"
make_repo; hook snapshot "$S"; echo 'def refund(): pass' >> services/billing/pay.py
hook stop "$S"; expect_code 2; expect_out "billing: services/billing/pay.py"

tc TC-C05 "지운 파일도 변경으로 본다"
make_repo; hook snapshot "$S"; rm services/billing/pay.py; hook stop "$S"; expect_code 2; expect_out "billing"

tc TC-C06 "그 도메인 문서도 바뀌었으면 통과한다"
make_repo; hook snapshot "$S"; echo 'class Order { int total; }' > src/main/java/com/shop/order/Order.java
echo '- total 추가' >> docs/domain/order/entities.md; hook stop "$S"; expect_code 0

tc TC-C07 "다른 도메인 문서만 바뀌면 막는다"
make_repo; hook snapshot "$S"; echo 'class Order { int total; }' > src/main/java/com/shop/order/Order.java
echo '- x' >> docs/domain/billing/_meta.md; hook stop "$S"; expect_code 2; expect_out "order"

tc TC-C08 "! 로 뺀 테스트 파일만 바뀌면 막지 않는다"
make_repo; hook snapshot "$S"; echo more >> web/src/features/order/cart.test.ts; hook stop "$S"; expect_code 0

tc TC-C09 "어느 도메인에도 안 걸리는 코드는 막지 않는다"
make_repo; hook snapshot "$S"; echo y >> README.md; hook stop "$S"; expect_code 0

tc TC-C10 "요청 전부터 있던 변경은 이번 요청에서 안 바뀌었으면 막지 않는다"
make_repo; echo 'class Order { int a; }' > src/main/java/com/shop/order/Order.java
hook snapshot "$S"; hook stop "$S"; expect_code 0

tc TC-C11 "요청 전부터 있던 변경을 이번 요청에서 또 바꾸면 막는다"
make_repo; echo 'class Order { int a; }' > src/main/java/com/shop/order/Order.java
hook snapshot "$S"; echo 'class Order { int b; }' > src/main/java/com/shop/order/Order.java; hook stop "$S"; expect_code 2

tc TC-C12 "스냅샷이 없으면(설치 직후) 변경이 있는 도메인을 본다"
make_repo; echo 'class Order { int a; }' > src/main/java/com/shop/order/Order.java; hook stop "$S"; expect_code 2

tc TC-C13 "면제 'n/a <slug>' 는 그 도메인만 통과시킨다"
make_repo; hook snapshot "$S"; echo 'class Order { int a; }' > src/main/java/com/shop/order/Order.java; echo 'def r(): pass' >> services/billing/pay.py
echo 'n/a order' > "$ACK_FILE"; hook stop "$S"; expect_code 2; expect_out "billing"; expect_not "order:"

tc TC-C14 "면제 'n/a' 는 모든 도메인을 통과시킨다"
echo 'n/a' > "$ACK_FILE"; hook stop "$S"; expect_code 0

tc TC-C15 "면제는 다음 요청(snapshot)에서 지워진다"
hook snapshot "$S"; [ "$TC_ON" = 1 ] && [ -e "$ACK_FILE" ] && fail_tc "면제 파일이 남았다"

tc TC-C16 "차단 메시지에 면제 파일 경로가 나온다"
make_repo; hook snapshot "$S"; echo 'class Order { int a; }' > src/main/java/com/shop/order/Order.java
hook stop "$S"; expect_code 2; expect_out "$ACK_FILE"

tc TC-C17 "한 번 되돌린 뒤(stop_hook_active)에는 막지 않고 systemMessage 로 알린다"
hook stop "$ACTIVE"; expect_code 0; expect_out '"systemMessage"'; expect_out "order"

tc TC-C18 "문서 루트가 없는 저장소에서는 아무것도 하지 않는다"
make_repo; rm -rf docs; hook snapshot "$S"; echo 'class Order { int a; }' > src/main/java/com/shop/order/Order.java
hook stop "$S"; expect_code 0; expect_no_out

tc TC-C19 "git 저장소가 아니면 아무것도 하지 않는다"
mkdir -p "$TMP/nogit/docs/domain"; OUT="$(printf '%s' "$S" | CLAUDE_PROJECT_DIR="$TMP/nogit" "$SCRIPT" stop 2>&1)"; CODE=$?
expect_code 0; expect_no_out

tc TC-C20 "프로젝트가 저장소 하위 디렉터리여도 경로를 프로젝트 기준으로 본다"
make_repo; mkdir -p app; git mv -k docs src web services app/; git commit -qm sub
OUT="$(printf '%s' "$S" | CLAUDE_PROJECT_DIR="$REPO/app" "$SCRIPT" snapshot 2>&1)"
echo 'class Order { int a; }' > app/src/main/java/com/shop/order/Order.java
OUT="$(printf '%s' "$S" | CLAUDE_PROJECT_DIR="$REPO/app" "$SCRIPT" stop 2>&1)"; CODE=$?; expect_code 2; expect_out "order: src/main/java"

section "D. 편집 훅 (pre-edit · post-edit)"
make_repo

tc TC-D01 "문서 루트 밖 편집에는 아무것도 하지 않는다"
hook pre-edit "{\"tool_input\":{\"file_path\":\"$REPO/src/main/java/com/shop/order/Order.java\"}}"; expect_code 0; expect_no_out

tc TC-D02 "카탈로그 편집에 네 갈래 트리거를 주입한다"
hook pre-edit "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/_index.md\"}}"; expect_out "additionalContext"; expect_out "네 갈래"

tc TC-D03 "기존 도메인 concept 편집에 메타 · 카탈로그 동기를 주입한다"
hook pre-edit "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/order/entities.md\"}}"; expect_out "order/_meta.md"

tc TC-D04 "새 도메인 파일이면 _meta · _index 를 같이 만들라고 한다 (D-02 · D-04)"
hook pre-edit "{\"tool_input\":{\"file_path\":\"docs/domain/stock/items.md\"}}"; expect_out "새 도메인 'stock'"

tc TC-D05 "300줄을 넘긴 concept 을 알린다 (D-07)"
seq 1 301 >> docs/domain/order/entities.md
hook post-edit "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/order/entities.md\"}}"; expect_out "D-07"; expect_not "D-05"

tc TC-D06 "메타에 없는 새 concept 을 알린다 (D-05)"
echo '# f' > docs/domain/order/flows.md
hook post-edit "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/order/flows.md\"}}"; expect_out "D-05"; expect_not "D-07"

tc TC-D07 "_meta · _index 편집 뒤에는 알리지 않는다"
hook post-edit "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/order/_meta.md\"}}"; expect_no_out
hook post-edit "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/_index.md\"}}"; expect_no_out

tc TC-D08 "jq 가 없으면 훅은 조용히 통과한다 (fail-open)"
mkdir -p "$TMP/nojq"; for b in bash cat git sed awk grep tr cut sort shasum wc head dirname find mktemp rm; do
  p="$(command -v "$b")" && ln -sf "$p" "$TMP/nojq/$b"; done
OUT="$(printf '%s' "{\"tool_input\":{\"file_path\":\"$REPO/docs/domain/_index.md\"}}" | PATH="$TMP/nojq" CLAUDE_PROJECT_DIR="$REPO" "$SCRIPT" pre-edit 2>&1)"; CODE=$?
expect_code 0; expect_no_out

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
