#!/usr/bin/env bash
# scripts/validate-authoring.sh 의 회귀 테스트.
# 이름은 plugin-naming, 위치는 marketplace-directory-structure, 버전은 plugin-versioning 이 본다. 여기서는 내용 형식만 본다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-authoring.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/authoring-tc.XXXXXX")"
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
run_stdin() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처: 모든 규칙을 지키는 플러그인 ------------------------------------
DESC_OK='주문을 만든다. 주문을 새로 만들 때 사용한다. 트리거 — "주문 만들어".'
make_plugin() { # $1=배치(internal|public, 기본 internal) → 플러그인 경로
  local kind="${1:-internal}" d
  d="$TMP/$kind-plugins/order-sync"; rm -rf "$d"
  mkdir -p "$d/.claude-plugin" "$d/skills/order-create" "$d/commands" "$d/agents" "$d/hooks" "$d/references"
  printf '{ "name": "order-sync", "version": "0.1.0", "description": "주문" }' > "$d/.claude-plugin/plugin.json"
  printf -- '---\nname: order-create\ndescription: %s\n---\n\n# 주문\n\n규칙: [원본](../../references/rules.md)\n' "$DESC_OK" > "$d/skills/order-create/SKILL.md"
  printf -- '---\ndescription: 주문을 검증한다\n---\n\n본문\n' > "$d/commands/order-validate.md"
  printf -- '---\nname: order-reviewer\ndescription: 주문을 검토한다\n---\n\n본문\n' > "$d/agents/order-reviewer.md"
  printf '{ "hooks": { "PreToolUse": [] } }' > "$d/hooks/hooks.json"
  printf '# 규칙\n' > "$d/references/rules.md"
  printf '# CHANGELOG\n\n## 0.1.0\n' > "$d/CHANGELOG.md"
  write_readme "$d" "$kind"
  printf '%s' "$d"
}
write_readme() { # $1=플러그인 $2=배치
  local install="SessionStart 훅이 설치한다."
  [ "$2" = public ] && install="/plugin install order-sync@jaemyeong-hwnag-plugins"
  cat > "$1/README.md" <<EOF
# order-sync

주문.

## 설치

$install

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| order-create | 주문 | 만든다 |
| \`/order-validate\` | 직접 | 검증 |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| order-reviewer | 검토 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| run.sh | PreToolUse | 막는다 |

## 테스트

자유 절.

## 변경 이력

CHANGELOG.md 참조.
EOF
}
readme_sub() { # $1=플러그인 $2=찾을 문자열 $3=바꿀 문자열 (첫 번째만)
  python3 - "$1/README.md" "$2" "$3" <<'PY'
import sys; p,a,b=sys.argv[1:]; s=open(p).read(); assert a in s, a; open(p,"w").write(s.replace(a,b,1))
PY
}
readme_drop() { # $1=플러그인 $2=절 제목 — 그 절을 통째로 지운다
  python3 - "$1/README.md" "$2" <<'PY'
import sys,re; p,h=sys.argv[1:]; s=open(p).read()
s=re.sub(r'(?ms)^## '+re.escape(h)+r'\n.*?(?=^## |\Z)', '', s); open(p,"w").write(s)
PY
}
skill_fm() { # $1=플러그인 $2=프런트매터 본문(--- 없이) — SKILL.md 를 다시 쓴다
  printf -- '---\n%s\n---\n\n본문\n' "$2" > "$1/skills/order-create/SKILL.md"
}
PRE() { jq -nc --arg p "$1" --arg c "$2" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p,content:$c}}'; }
PRE_EDIT() { jq -nc --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p,old_string:"a",new_string:"b"}}'; }
POST() { jq -nc --arg p "$1" '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'; }

echo "== A. 프런트매터 (A-01 ~ A-05) =="

tc TC-A01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-A02 "모든 규칙을 지킨 플러그인은 조용히 통과한다"
run "$(make_plugin)"; expect_code 0; expect_no_out

tc TC-A03 "프런트매터가 없으면 막는다 (A-01)"
P="$(make_plugin)"; printf '# 주문\n' > "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 2; expect_out "프런트매터가 없습니다"; expect_out "(A-01)"

tc TC-A04 "프런트매터가 닫히지 않으면 막는다 (A-01)"
P="$(make_plugin)"; printf -- '---\nname: order-create\ndescription: x 할 때 사용한다\n' > "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 2; expect_out "닫히지 않았습니다"

tc TC-A05 "스킬 name 이 없으면 막는다 (A-02)"
P="$(make_plugin)"; skill_fm "$P" "description: $DESC_OK"
run "$P"; expect_code 2; expect_out "name 이 없습니다"; expect_out "(A-02)"

tc TC-A06 "스킬 name 이 디렉터리명과 다르면 막는다 (A-02)"
P="$(make_plugin)"; skill_fm "$P" "name: order-make
description: $DESC_OK"
run "$P"; expect_code 2; expect_out "name 이 'order-make'"

tc TC-A07 "description 이 없으면 막는다 (A-03)"
P="$(make_plugin)"; skill_fm "$P" "name: order-create"
run "$P"; expect_code 2; expect_out "description 이 없습니다"; expect_out "(A-03)"

tc TC-A08 "언제 쓰는가가 없으면 막는다 (A-04)"
P="$(make_plugin)"; skill_fm "$P" "name: order-create
description: 주문을 만든다."
run "$P"; expect_code 2; expect_out "(A-04)"

tc TC-A09 "'고칠 때 사용한다' 처럼 다른 동사도 허용한다 (A-04 과잉 차단 방지)"
P="$(make_plugin)"; skill_fm "$P" "name: order-create
description: 주문을 고칠 때 사용한다."
run "$P"; expect_code 0

tc TC-A10 "'~ 때 참조한다' 도 허용한다"
P="$(make_plugin)"; skill_fm "$P" "name: order-create
description: 주문 규칙을 볼 때 참조한다."
run "$P"; expect_code 0

tc TC-A11 "블록 스칼라 description 을 읽는다"
P="$(make_plugin)"; skill_fm "$P" "name: order-create
description: |
  주문을 만든다.
  주문을 새로 만들 때 사용한다."
run "$P"; expect_code 0

tc TC-A12 "따옴표로 감싼 name · description 을 읽는다"
P="$(make_plugin)"; skill_fm "$P" "name: \"order-create\"
description: '주문을 만들 때 사용한다.'"
run "$P"; expect_code 0

tc TC-A13 "description 이 300자를 넘으면 경고만 한다 (A-05)"
LONG="$(printf '가%.0s' $(seq 1 295)) 할 때 사용한다"
P="$(make_plugin)"; skill_fm "$P" "name: order-create
description: $LONG"
run "$P"; expect_code 0; expect_out "(A-05)"

tc TC-A14 "한글 300자는 경고하지 않는다 — 바이트가 아니라 글자로 센다"
EXACT="$(printf '가%.0s' $(seq 1 293)) 때 사용한다"   # 293 + 7 = 정확히 300자
P="$(make_plugin)"; skill_fm "$P" "name: order-create
description: $EXACT"
run "$P"; expect_code 0; expect_not "(A-05)"

tc TC-A15 "커맨드 description 이 없으면 막는다 (A-03)"
P="$(make_plugin)"; printf -- '---\nargument-hint: x\n---\n' > "$P/commands/order-validate.md"
run "$P"; expect_code 2; expect_out "commands/order-validate.md: description 이 없습니다"

tc TC-A16 "커맨드는 name 을 요구하지 않는다"
run "$(make_plugin)"; expect_code 0; expect_not "order-validate.md: name"

tc TC-A17 "에이전트 name 이 파일명과 다르면 막는다 (A-02)"
P="$(make_plugin)"; printf -- '---\nname: order-checker\ndescription: 검토\n---\n' > "$P/agents/order-reviewer.md"
run "$P"; expect_code 2; expect_out "파일명 'order-reviewer'"

tc TC-A18 "에이전트는 '때 사용한다' 를 요구하지 않는다"
run "$(make_plugin)"; expect_code 0; expect_not "agents/order-reviewer.md"

echo "== B. 본문 · 참조 (A-06 ~ A-09) =="

tc TC-A20 "SKILL.md 가 200줄을 넘으면 경고만 한다 (A-06)"
P="$(make_plugin)"; seq 1 210 >> "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 0; expect_out "(A-06)"

tc TC-A21 "references 파일이 500줄을 넘으면 경고만 한다 (A-07)"
P="$(make_plugin)"; seq 1 510 > "$P/references/rules.md"
run "$P"; expect_code 0; expect_out "(A-07)"

tc TC-A22 "깨진 상대 링크를 막는다 (A-08)"
P="$(make_plugin)"; printf '\n[없음](../../references/none.md)\n' >> "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 2; expect_out "'../../references/none.md'"; expect_out "(A-08)"

tc TC-A23 "앵커가 붙은 링크는 파일 부분만 본다"
P="$(make_plugin)"; printf '\n[절](../../references/rules.md#part)\n[같은 문서](#top)\n' >> "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 0

tc TC-A24 "코드펜스 안의 링크는 보지 않는다"
P="$(make_plugin)"; printf '\n```markdown\n[예시](../../references/none.md)\n```\n' >> "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 0

tc TC-A25 "스킬 본문의 외부 URL 을 막는다 (A-09)"
P="$(make_plugin)"; printf '\n자세한 것은 https://example.com/doc 참조\n' >> "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 2; expect_out "https://example.com/doc"; expect_out "(A-09)"

tc TC-A26 "references 의 외부 URL 을 막는다 (A-09)"
P="$(make_plugin)"; printf '출처: http://example.com\n' >> "$P/references/rules.md"
run "$P"; expect_code 2; expect_out "(A-09)"

tc TC-A27 "README 의 URL 은 대상이 아니다"
P="$(make_plugin)"; printf '\n홈: https://example.com\n' >> "$P/README.md"
readme_sub "$P" "## 설치" "홈: https://example.com

## 설치"
run "$P"; expect_code 0

tc TC-A28 "plugin.json 의 homepage URL 은 대상이 아니다"
P="$(make_plugin)"; printf '{ "name": "order-sync", "homepage": "https://example.com" }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 0

echo "== C. README (A-20 ~ A-28) =="

tc TC-A30 "첫 제목이 플러그인 이름과 다르면 막는다 (A-20)"
P="$(make_plugin)"; readme_sub "$P" "# order-sync" "# 주문 플러그인"
run "$P"; expect_code 2; expect_out "(A-20)"

tc TC-A31 "## 설치 가 없으면 막는다 (A-21)"
P="$(make_plugin)"; readme_drop "$P" "설치"
run "$P"; expect_code 2; expect_out "'## 설치' 절이 없습니다"

tc TC-A32 "## 의존성 이 없으면 막는다 (A-21)"
P="$(make_plugin)"; readme_drop "$P" "의존성"
run "$P"; expect_code 2; expect_out "'## 의존성' 절이 없습니다"

tc TC-A33 "## 변경 이력 이 없으면 막는다 (A-21)"
P="$(make_plugin)"; readme_drop "$P" "변경 이력"
run "$P"; expect_code 2; expect_out "'## 변경 이력' 절이 없습니다"

tc TC-A34 "스킬이 있는데 ## 포함된 스킬 이 없으면 막는다 (A-22)"
P="$(make_plugin)"; readme_drop "$P" "포함된 스킬"
run "$P"; expect_code 2; expect_out "'## 포함된 스킬' 절이 없습니다"

tc TC-A35 "에이전트가 있는데 ## 포함된 에이전트 가 없으면 막는다 (A-22)"
P="$(make_plugin)"; readme_drop "$P" "포함된 에이전트"
run "$P"; expect_code 2; expect_out "'## 포함된 에이전트' 절이 없습니다"

tc TC-A36 "hooks.json 이 있는데 ## 포함된 훅 이 없으면 막는다 (A-22)"
P="$(make_plugin)"; readme_drop "$P" "포함된 훅"
run "$P"; expect_code 2; expect_out "'## 포함된 훅' 절이 없습니다"

tc TC-A38a "스킬만 있고 커맨드가 없어도 ## 포함된 스킬 을 요구한다 (A-22, #8)"
P="$(make_plugin)"; rm -rf "$P/commands"; readme_drop "$P" "포함된 스킬"
run "$P"; expect_code 2; expect_out "'## 포함된 스킬' 절이 없습니다"

tc TC-A38b "커맨드만 있고 스킬이 없어도 ## 포함된 스킬 을 요구한다 (A-22, #8)"
P="$(make_plugin)"; rm -rf "$P/skills"; readme_drop "$P" "포함된 스킬"
run "$P"; expect_code 2; expect_out "'## 포함된 스킬' 절이 없습니다"

tc TC-A37 "스킬 · 에이전트 · 훅이 없으면 그 절도 필요 없다 (A-22 과잉 차단 방지)"
P="$(make_plugin)"; rm -rf "$P/skills" "$P/commands" "$P/agents" "$P/hooks"
readme_drop "$P" "포함된 스킬"; readme_drop "$P" "포함된 에이전트"; readme_drop "$P" "포함된 훅"
run "$P"; expect_code 0

tc TC-A38 "템플릿 절 순서가 뒤바뀌면 막는다 (A-23)"
P="$(make_plugin)"; readme_sub "$P" "## 설치" "## 의존성 임시"; readme_sub "$P" "## 의존성
" "## 설치
"; readme_sub "$P" "## 의존성 임시" "## 의존성"
run "$P"; expect_code 2; expect_out "(A-23)"

tc TC-A39 "## 변경 이력 뒤에 절이 있으면 막는다 (A-23)"
P="$(make_plugin)"; printf '\n## 부록\n\n내용\n' >> "$P/README.md"
run "$P"; expect_code 2; expect_out "'## 변경 이력' 뒤에 '## 부록'"

tc TC-A40 "자유 절은 필수 절 사이 어디든 둘 수 있다"
P="$(make_plugin)"; readme_sub "$P" "## 의존성" "## 배경

자유.

## 의존성"
run "$P"; expect_code 0

tc TC-A41 "스킬 표에 빠진 스킬을 막는다 (A-24)"
P="$(make_plugin)"; mkdir -p "$P/skills/order-delete"; skill_fm "$P" "name: order-create
description: $DESC_OK"
printf -- '---\nname: order-delete\ndescription: 지울 때 사용한다.\n---\n' > "$P/skills/order-delete/SKILL.md"
run "$P"; expect_code 2; expect_out "표에 'order-delete' 가 없습니다"; expect_out "(A-24)"

tc TC-A42 "스킬 표에 없는 스킬이 있으면 막는다 (A-24)"
P="$(make_plugin)"; readme_sub "$P" "| order-create | 주문 | 만든다 |" "| order-create | 주문 | 만든다 |
| order-ghost | 유령 | 없다 |"
run "$P"; expect_code 2; expect_out "'order-ghost' 는 없는 스킬"

tc TC-A43 "커맨드는 /{이름} 으로 표에 있어야 한다 (A-24)"
P="$(make_plugin)"; readme_sub "$P" "| \`/order-validate\` | 직접 | 검증 |" "| order-validate | 직접 | 검증 |"
run "$P"; expect_code 2; expect_out "'/order-validate' 가 없습니다"

tc TC-A44 "표 첫 칸의 백틱은 벗기고 비교한다"
run "$(make_plugin)"; expect_code 0

tc TC-A45 "에이전트 표가 실제와 다르면 막는다 (A-25)"
P="$(make_plugin)"; readme_sub "$P" "| order-reviewer | 검토 |" "| order-checker | 검토 |"
run "$P"; expect_code 2; expect_out "(A-25)"

tc TC-A46 "훅 절에 hooks.json 의 이벤트가 없으면 막는다 (A-26)"
P="$(make_plugin)"; printf '{ "hooks": { "PreToolUse": [], "PostToolUse": [] } }' > "$P/hooks/hooks.json"
run "$P"; expect_code 2; expect_out "이벤트 'PostToolUse'"; expect_out "(A-26)"

tc TC-A47 "훅 절에 이벤트가 다 있으면 통과한다"
readme_sub "$P" "| run.sh | PreToolUse | 막는다 |" "| run.sh | PreToolUse | 막는다 |
| run.sh | PostToolUse | 알린다 |"
run "$P"; expect_code 0

tc TC-A48 "의존성이 있는데 절에 이름이 없으면 막는다 (A-27)"
P="$(make_plugin)"; printf '{ "name": "order-sync", "dependencies": ["common-naming"] }' > "$P/.claude-plugin/plugin.json"
run "$P"; expect_code 2; expect_out "'common-naming' 가 없습니다"; expect_out "(A-27)"

tc TC-A49 "의존성이 없는데 '없음' 이 없으면 막는다 (A-27)"
P="$(make_plugin)"; readme_sub "$P" "없음" "(비어 있음)"
run "$P"; expect_code 2; expect_out "'없음' 이라고 씁니다"

tc TC-A50 "객체형 의존성의 name 을 읽는다"
P="$(make_plugin)"; printf '{ "name": "order-sync", "dependencies": [ { "name": "common-naming", "version": "~1.0.0" } ] }' > "$P/.claude-plugin/plugin.json"
readme_sub "$P" "없음" "| common-naming | 공통 |"
run "$P"; expect_code 0

tc TC-A51 "public 플러그인의 설치 절에 설치 명령이 없으면 막는다 (A-28)"
P="$(make_plugin public)"; readme_sub "$P" "/plugin install order-sync@jaemyeong-hwnag-plugins" "설치한다."
run "$P"; expect_code 2; expect_out "(A-28)"

tc TC-A52 "public 플러그인이 설치 명령을 가지면 통과한다"
run "$(make_plugin public)"; expect_code 0

tc TC-A53 "internal 플러그인은 설치 명령을 요구하지 않는다"
run "$(make_plugin internal)"; expect_code 0

tc TC-A54 "README 가 없으면 여기서는 보지 않는다 (P-01 의 몫)"
P="$(make_plugin)"; rm "$P/README.md"
run "$P"; expect_code 0

echo "== D. 훅 모드 =="

P="$(make_plugin)"; SK="$P/skills/order-create/SKILL.md"

tc TC-A60 "PreToolUse: 프런트매터 없는 SKILL.md 를 쓰려 하면 차단한다"
run_stdin "$(PRE "$SK" '# 주문')"; expect_code 2; expect_out "(A-01)"

tc TC-A61 "PreToolUse: name 이 디렉터리와 다르면 차단한다"
run_stdin "$(PRE "$SK" "$(printf -- '---\nname: other\ndescription: %s\n---\n' "$DESC_OK")")"; expect_code 2; expect_out "(A-02)"

tc TC-A62 "PreToolUse: 올바른 SKILL.md 는 조용히 통과시킨다"
run_stdin "$(PRE "$SK" "$(printf -- '---\nname: order-create\ndescription: %s\n---\n' "$DESC_OK")")"; expect_code 0; expect_no_out

tc TC-A63 "PreToolUse: 길이 경고만 있으면 막지 않는다"
run_stdin "$(PRE "$SK" "$(printf -- '---\nname: order-create\ndescription: %s\n---\n' "$LONG")")"; expect_code 0; expect_no_out

tc TC-A64 "PreToolUse: Edit 에는 반응하지 않는다"
run_stdin "$(PRE_EDIT "$SK")"; expect_code 0; expect_no_out

tc TC-A65 "PreToolUse: description 없는 커맨드를 차단한다"
run_stdin "$(PRE "$P/commands/order-validate.md" "$(printf -- '---\nargument-hint: x\n---\n')")"; expect_code 2; expect_out "(A-03)"

tc TC-A66 "PreToolUse: name 이 파일명과 다른 에이전트를 차단한다"
run_stdin "$(PRE "$P/agents/order-reviewer.md" "$(printf -- '---\nname: x\ndescription: y\n---\n')")"; expect_code 2; expect_out "(A-02)"

tc TC-A67 "PreToolUse: 플러그인 밖 경로에는 반응하지 않는다"
run_stdin "$(PRE "$TMP/skills/x/SKILL.md" '# 없음')"; expect_code 0; expect_no_out

tc TC-A68 "PreToolUse: 스킬 디렉터리의 다른 파일에는 반응하지 않는다"
run_stdin "$(PRE "$P/skills/order-create/example.md" '# 예시')"; expect_code 0; expect_no_out

tc TC-A69 "PostToolUse: README 가 어긋나면 알린다 (막지 않는다)"
P2="$(make_plugin)"; readme_drop "$P2" "포함된 훅"
run_stdin "$(POST "$P2/README.md")"; expect_code 0; expect_out "additionalContext"; expect_out "(A-22)"

tc TC-A70 "PostToolUse: 알림 출력이 올바른 JSON 이다"
[ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null || fail_tc "JSON 구조가 아님"; }

tc TC-A71 "PostToolUse: 정합하면 아무것도 내지 않는다"
run_stdin "$(POST "$(make_plugin)/README.md")"; expect_code 0; expect_no_out

tc TC-A72 "PostToolUse: 경고도 알림에 담는다"
P2="$(make_plugin)"; seq 1 210 >> "$P2/skills/order-create/SKILL.md"
run_stdin "$(POST "$P2/skills/order-create/SKILL.md")"; expect_code 0; expect_out "(경고)"; expect_out "(A-06)"

tc TC-A73 "PostToolUse: 스킬을 추가하면 README 누락을 알린다"
P2="$(make_plugin)"; mkdir -p "$P2/skills/order-delete"; printf -- '---\nname: order-delete\ndescription: 지울 때 사용한다.\n---\n' > "$P2/skills/order-delete/SKILL.md"
run_stdin "$(POST "$P2/skills/order-delete/SKILL.md")"; expect_code 0; expect_out "'order-delete' 가 없습니다"

tc TC-A74 "PostToolUse: scripts/ 같은 무관한 파일에는 반응하지 않는다"
run_stdin "$(POST "$P2/scripts/run.sh")"; expect_code 0; expect_no_out

tc TC-A75 "stdin 이 비면 통과시킨다"
run_stdin ""; expect_code 0; expect_no_out

tc TC-A76 "경로가 없는 훅 입력은 통과시킨다"
run_stdin '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'; expect_code 0; expect_no_out

echo "== E. CLI =="

tc TC-A80 "--all 이 모든 플러그인을 본다"
R="$TMP/all"; rm -rf "$R"; mkdir -p "$R/internal-plugins"
cp -R "$(make_plugin)" "$R/internal-plugins/order-sync"
cp -R "$R/internal-plugins/order-sync" "$R/internal-plugins/item-sync"
printf '{ "name": "item-sync" }' > "$R/internal-plugins/item-sync/.claude-plugin/plugin.json"
run --all "$R"; expect_code 2; expect_out "item-sync/README.md: 첫 제목"; expect_not "order-sync/README.md"

tc TC-A81 "없는 디렉터리는 오류를 낸다"
run "$TMP/nope"; expect_code 2; expect_out "디렉터리가 없습니다"

tc TC-A82 "여러 경로를 한 번에 받는다"
A="$(make_plugin)"; B="$TMP/internal-plugins/bad-sync"; rm -rf "$B"; mkdir -p "$B/skills/x"; printf '# x\n' > "$B/skills/x/SKILL.md"
run "$A" "$B"; expect_code 2; expect_out "bad-sync/skills/x/SKILL.md"; expect_not "order-sync"

tc TC-A83 "경고만 있으면 종료 코드 0 이다"
P="$(make_plugin)"; seq 1 210 >> "$P/skills/order-create/SKILL.md"
run "$P"; expect_code 0; expect_out "⚠️"

tc TC-A84 "위반 출력이 규칙 원본 경로를 알려준다"
P="$(make_plugin)"; readme_drop "$P" "설치"
run "$P"; expect_out "authoring-rules.md"

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
printf '\n'
[ "$FAIL" = 0 ] || exit 1
