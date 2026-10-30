#!/usr/bin/env bash
# scripts/design-soundness-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/design-soundness-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/design-soundness-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_PLUGIN_DATA="$TMP/data"
unset DESIGN_SOUNDNESS_GATE DESIGN_SOUNDNESS_PLAN_GATE DESIGN_SOUNDNESS_PATHS DESIGN_SOUNDNESS_REQUIREMENT_ID
W="$TMP/proj"
mkdir -p "$W/docs/adr" "$W/src" && cd "$W" || exit 1

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
  rm -rf "$CLAUDE_PLUGIN_DATA"
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" --hook 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
put() { [ "$TC_ON" = 1 ] || return 0; mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

write_p() { # $1=경로 $2=content [$3=session]
  jq -n --arg f "$1" --arg c "$2" --arg s "${3:-s1}" --arg w "$W" \
    '{hook_event_name: "PostToolUse", tool_name: "Write", session_id: $s, cwd: $w, tool_input: {file_path: $f, content: $c}}'
}
edit_p() { # $1=경로 $2=old $3=new [$4=session]
  jq -n --arg f "$1" --arg o "$2" --arg n "$3" --arg s "${4:-s1}" --arg w "$W" \
    '{hook_event_name: "PostToolUse", tool_name: "Edit", session_id: $s, cwd: $w, tool_input: {file_path: $f, old_string: $o, new_string: $n}}'
}
agent_p() { jq -n --arg t "$1" --arg s "${2:-s1}" '{hook_event_name: "PostToolUse", tool_name: "Agent", session_id: $s, tool_input: {subagent_type: $t, prompt: "x"}, tool_response: {status: "completed"}}'; }
async_p() { jq -n --arg t "$1" --arg s "${2:-s1}" '{hook_event_name: "PostToolUse", tool_name: "Agent", session_id: $s, tool_input: {subagent_type: $t, prompt: "x", run_in_background: true}, tool_response: {isAsync: true, status: "async_launched", agentId: "a1"}}'; }
substop_p() { jq -n --arg t "$1" --arg s "${2:-s1}" '{hook_event_name: "SubagentStop", session_id: $s, agent_type: $t, agent_id: "a1", stop_hook_active: false}'; }
prompt_p() { jq -n --arg p "$1" --arg s "${2:-s1}" --arg w "$W" '{hook_event_name: "UserPromptSubmit", session_id: $s, cwd: $w, prompt: $p}'; }
stop_p() { jq -n --arg s "${1:-s1}" --argjson a "${2:-false}" --arg w "$W" '{hook_event_name: "Stop", session_id: $s, cwd: $w, stop_hook_active: $a}'; }
plan_p() { # $1=plan 본문 [$2=planFilePath] [$3=session]
  jq -n --arg p "$1" --arg f "${2:-}" --arg s "${3:-s1}" --arg w "$W" \
    '{hook_event_name: "PreToolUse", tool_name: "ExitPlanMode", session_id: $s, cwd: $w, permission_mode: "plan", tool_input: ({plan: $p} + (if $f == "" then {} else {planFilePath: $f} end))}'
}

FULL='# 설계
## 배경
## 요구
## 결정
## 고려한 대안
## 위험
## 확인 방법'
PLAN='# Plan
## Context
## Approach
## Risks
## Verification'

section() { flush_tc; echo "$1"; }

section "A. 필수 절 (DD-20)"

tc TC-D01 "설계 문서 6절이 모두 있으면 DD-20 이 없다"
put "$W/a.md" "$FULL"; run "$W/a.md"
expect_code 0; expect_not "DD-20"; expect_out "신호 0건"

tc TC-D02 "절을 하나씩 빼면 그 절만 알린다"
for pair in "배경:문제 · 목적" "요구:요구 · 품질 속성" "결정:결정" "고려한 대안:고려한 대안" "위험:위험 · 트레이드오프" "확인 방법:확인 방법"; do
  h="${pair%%:*}"; n="${pair#*:}"
  put "$W/a.md" "$(printf '%s\n' "$FULL" | grep -vx "## $h")"; run "$W/a.md"
  expect_out "필수 절 없음 — $n"
  [ "$TC_ON" = 1 ] && [ "$(printf '%s' "$OUT" | grep -c 'DD-20')" = 1 ] || fail_tc "$h 를 뺐을 때 DD-20 이 한 건이 아님"
done

tc TC-D03 "영어 제목도 절로 본다"
put "$W/a.md" '# D
## Motivation
## Requirements
## Decision
## Considered Options
## Consequences
## Confirmation'; run "$W/a.md"
expect_not "DD-20"

tc TC-D04 "계획은 4절로 본다 — --plan"
put "$W/p.md" "$PLAN"; run --plan "$W/p.md"
expect_not "DD-20"
put "$W/p.md" "$(printf '%s\n' "$PLAN" | grep -vx '## Risks')"; run --plan "$W/p.md"
expect_out "필수 절 없음 — 위험"; expect_not "고려한 대안"

tc TC-D05 "코드 펜스 · HTML 주석 안의 제목은 절로 치지 않는다"
put "$W/a.md" '# D
## 배경
## 요구
## 결정
## 위험
## 확인 방법
```
## 대안
```
<!--
## 대안
-->'; run "$W/a.md"
expect_out "필수 절 없음 — 고려한 대안"

tc TC-D06 "영어 키워드는 단어 경계로 본다 — Latest · Designing 은 절이 아니다"
put "$W/a.md" '# D
## Background
## Requirements
## Designing notes
## Options
## Risks
## Latest news'; run "$W/a.md"
expect_out "필수 절 없음 — 결정"; expect_out "필수 절 없음 — 확인 방법"

tc TC-D07 "하위 제목은 상위 절을 잇는다"
put "$W/a.md" '# D
## 요구
- R-1 취소
### 성능
- 빠르게 응답한다
## 결정
### 큐 선택
- R-1 을 위해 큐'; run "$W/a.md"
expect_out "DD-23"; expect_not "DD-22"

section "B. 플로우 (DD-21)"

tc TC-D10 "정상 상태도는 조용하다"
put "$W/a.md" "$FULL
\`\`\`mermaid
stateDiagram-v2
  [*] --> 접수
  접수 --> 완료 : 처리
  완료 --> [*]
\`\`\`"; run "$W/a.md"
expect_not "DD-21"

tc TC-D11 "[*] 시작에서 닿지 않는 상태를 알린다"
put "$W/a.md" "$FULL
\`\`\`mermaid
stateDiagram-v2
  [*] --> 접수
  접수 --> 완료
  고아 --> 완료
  완료 --> [*]
\`\`\`"; run "$W/a.md"
expect_out "시작에서 닿지 않는 단계 — 고아"

tc TC-D12 "[*] 종료로 못 가는 상태를 알린다 (자기 루프)"
put "$W/a.md" "$FULL
\`\`\`mermaid
stateDiagram-v2
  [*] --> 대기
  대기 --> 완료
  대기 --> 재시도
  재시도 --> 재시도
  완료 --> [*]
\`\`\`"; run "$W/a.md"
expect_out "끝으로 못 가는 단계(출구 없는 루프) — 재시도"; expect_not "대기"

tc TC-D13 "flowchart 의 출구 없는 루프를 알린다 — 라벨 · 모양 · 연쇄 간선"
put "$W/a.md" "$FULL
\`\`\`mermaid
flowchart TD
  A[시작] --> B{결제?}
  B -->|yes| C
  B -- no --> D
  C --> E --> C
  D --> F
\`\`\`"; run "$W/a.md"
expect_out "출구 없는 루프) — C, E"; expect_not "— A"

tc TC-D14 "출구가 있는 루프는 알리지 않는다"
put "$W/a.md" "$FULL
\`\`\`mermaid
graph LR
  A --> B
  B --> A
  B -.-> C
\`\`\`"; run "$W/a.md"
expect_not "DD-21"

tc TC-D15 "끝이 없이 모두 순환하면 전부 알린다"
put "$W/a.md" "$FULL
\`\`\`mermaid
flowchart LR
  A ==> B
  B --> A
\`\`\`"; run "$W/a.md"
expect_out "출구 없는 루프) — A, B"

tc TC-D16 "mermaid 가 아닌 코드 펜스 · 다이어그램 없음은 보지 않는다"
put "$W/a.md" "$FULL
\`\`\`
A --> B
B --> A
\`\`\`"; run "$W/a.md"
expect_not "DD-21"

tc TC-D17 "& 로 묶은 노드를 각각 잇는다"
put "$W/a.md" "$FULL
\`\`\`mermaid
flowchart TD
  A & B --> C
  C --> A
\`\`\`"; run "$W/a.md"
expect_out "— A, B, C"

tc TC-D18 "파이프 라벨 간선을 잇는다"
put "$W/a.md" "$FULL
\`\`\`mermaid
flowchart TD
  A -->|yes| B
  B --> B
\`\`\`"; run "$W/a.md"
expect_out "출구 없는 루프) — A, B"

tc TC-D19 "줄 끝 ; · <--> · 점선 라벨 · 라벨 안 화살표 · 다이어그램 프런트매터 · note · %% 를 읽는다"
loop() { put "$W/a.md" "$FULL
\`\`\`mermaid
$1
\`\`\`"; run "$W/a.md"; expect_out "출구 없는 루프) — A, B"; expect_not "— A, B,"; expect_not ", A, B"; }
loop $'---\ntitle: x --> y\n---\nflowchart LR\n  A --> B\n  B --> A'
loop $'flowchart LR\n  A --> B;\n  B --> A;'
loop $'flowchart LR\n  A <--> B'
loop $'flowchart LR\n  A[go --> now] --> B\n  B("x --> y") --> A'
loop $'flowchart LR\n  A -. 재시도 .-> B\n  B --> A'
loop $'flowchart LR\n  %% A --> Z\n  A --> B\n  B --> A'
put "$W/a.md" "$FULL
\`\`\`mermaid
stateDiagram-v2
  [*] --> A
  note right of A : x --> y
  A --> B : on x --> y
  B --> [*]
\`\`\`"; run "$W/a.md"
expect_not "DD-21"

tc TC-D19b "한 문서의 다이어그램끼리 섞지 않는다"
put "$W/a.md" "$FULL
\`\`\`mermaid
graph LR
  A --> B
\`\`\`
\`\`\`mermaid
graph LR
  B --> A
\`\`\`"; run "$W/a.md"
expect_not "DD-21"

section "C. 요구 ID (DD-22)"

tc TC-D20 "정의와 결정 절 참조가 맞으면 조용하다"
put "$W/a.md" "$FULL
| R-1 | 취소 |
## 결정 상세
- R-1 을 위해 큐를 쓴다"; run "$W/a.md"
expect_not "DD-22"

tc TC-D21 "정의 없이 참조된 ID 를 알린다"
put "$W/a.md" '# D
## 요구
| R-1 | 취소 |
## 결정
- R-1 · R-9 을 위해 큐'; run "$W/a.md"
expect_out "정의 없이 참조된 요구 ID — R-9"; expect_not "— R-1 "

tc TC-D22 "결정 절에서 참조되지 않은 정의를 알린다"
put "$W/a.md" '# D
## 요구
- R-1 취소
- R-2 재고 복구
## 결정
- R-1 을 위해 큐'; run "$W/a.md"
expect_out "결정 절에서 참조되지 않은 요구 — R-2"

tc TC-D23 "정의가 없는 문서는 외부 ID 를 알리지 않는다 · FR-1 안의 R-1 을 따로 세지 않는다"
put "$W/a.md" '# D
## 결정
- JIRA 의 R-7 · FR-3 대응'; run "$W/a.md"
expect_not "DD-22"
put "$W/a.md" '# D
## 요구
- FR-1 취소
## 결정
- FR-1 대응'; run "$W/a.md"
expect_not "DD-22"
put "$W/a.md" '# D
## 요구
- R-1 취소
## 결정
- XR-1 대응'; run "$W/a.md"
expect_out "결정 절에서 참조되지 않은 요구 — R-1"

tc TC-D24 "DESIGN_SOUNDNESS_REQUIREMENT_ID 로 패턴을 바꾼다"
put "$W/a.md" '# D
## 요구
- US-1 취소
## 결정
- 큐'
[ "$TC_ON" = 1 ] && { OUT="$(DESIGN_SOUNDNESS_REQUIREMENT_ID='US-[0-9]+' "$SCRIPT" "$W/a.md" 2>&1)"; CODE=$?; }
expect_out "결정 절에서 참조되지 않은 요구 — US-1"

tc TC-D25 "제목도 정의로 본다 · 결정 절 안의 줄 머리는 정의가 아니다"
put "$W/a.md" '# D
## 요구
### R-1 취소
### R-2 재고
## 결정
- R-1 을 위해 큐'; run "$W/a.md"
expect_out "결정 절에서 참조되지 않은 요구 — R-2"
put "$W/a.md" '# D
## 요구
- R-1 취소
## 결정
- R-2 를 새로 둔다'; run "$W/a.md"
expect_out "정의 없이 참조된 요구 ID — R-2"

section "D. 품질 요구 (DD-23)"

tc TC-D30 "요구 절의 숫자 없는 품질 요구를 알린다 — 요구 ID 의 숫자는 세지 않는다"
put "$W/a.md" '# D
## 요구
| R-1 | 취소는 빠르게 처리한다 |
- 확장 가능해야 한다'; run "$W/a.md"
expect_out "R-1 | 취소는 빠르게"; expect_out "확장 가능해야"

tc TC-D31 "숫자 · 단위가 있으면 조용하다"
put "$W/a.md" '# D
## 요구
- 취소는 p95 200ms 안에 빠르게'; run "$W/a.md"
expect_not "DD-23"

tc TC-D32 "요구 절 밖의 같은 단어는 보지 않는다"
put "$W/a.md" '# D
## 배경
- 기존 처리가 빠르지 않다'; run "$W/a.md"
expect_not "DD-23"

tc TC-D33 "ignore 주석이 있는 줄 · 다음 줄은 보지 않는다"
put "$W/a.md" '# D
## 요구
<!-- design-soundness-ignore -->
- 빠르게 처리한다
- 안정적이어야 한다 <!-- design-soundness-ignore -->'; run "$W/a.md"
expect_not "DD-23"

tc TC-D34 "줄 안의 HTML 주석만 지우고 나머지는 본다 · 인용은 보지 않는다"
put "$W/a.md" '# D
## 요구
- 빠르게 처리한다 <!-- 메모 -->
> 안정적이어야 한다'; run "$W/a.md"
expect_out "빠르게 처리한다"; expect_not "안정적"

tc TC-D35 "영어 품질어는 단어 경계로 본다"
put "$W/a.md" '# D
## Requirements
- Breakfast service
- Unreliable links
- must be fast'; run "$W/a.md"
expect_not "Breakfast"; expect_not "Unreliable"; expect_out "must be fast"

section "E. 정의 전 용어 (DD-24)"

tc TC-D40 "용어 절이 없으면 돌지 않는다"
put "$W/a.md" '# D
환불 대기 로 간다
## 결정'; run "$W/a.md"
expect_not "DD-24"

tc TC-D41 "정의 전에 쓰면 알리고, 정의 뒤에 쓰면 조용하다"
put "$W/a.md" '# D
먼저 환불 대기 로 간다 (용어는 아래)
보류 도 있다
## 용어
| 용어 | 뜻 |
|---|---|
| 환불 대기 | 상태 |
- **보류**: 상태
- **취소됨**: 상태
## 배경
취소됨 은 뒤에 쓴다
## 결정'; run "$W/a.md"
expect_out "전에 쓴 용어 — 환불 대기 (2줄)"; expect_out "전에 쓴 용어 — 보류 (3줄)"; expect_not "— 취소됨"; expect_not "— 용어"

tc TC-D42 "용어 절이 결정 절 뒤(끝의 용어집)면 보지 않는다"
put "$W/a.md" '# D
환불 대기 로 간다
## 결정
## 용어
- **환불 대기**: 상태'; run "$W/a.md"
expect_not "DD-24"

tc TC-D43 "용어와 결정 단어가 같이 든 제목은 용어 절이다"
put "$W/a.md" '# D
큐 를 쓴다
## 설계 용어
- **큐**: 대기열
## 결정'; run "$W/a.md"
expect_out "전에 쓴 용어 — 큐 (2줄)"

section "F. CLI"

tc TC-D50 "--strict 면 신호가 있을 때 exit 2, 없으면 0"
put "$W/a.md" '# D'; run --strict "$W/a.md"; expect_code 2
put "$W/a.md" "$FULL"; run --strict "$W/a.md"; expect_code 0

tc TC-D51 "인자 없음 · 없는 파일 · 모르는 인자는 exit 1"
run; expect_code 1
run "$W/none.md"; expect_code 1
run --bogus "$W/a.md"; expect_code 1

tc TC-D52 "프런트매터 안의 내용은 보지 않는다"
put "$W/a.md" "---
title: R-9
---
$FULL
| R-1 | 취소 |"; run "$W/a.md"
expect_out "R-1"; expect_not "R-9"; expect_not "DD-20"

section "G. 설계 문서 판별 · 알림 (PostToolUse)"

tc TC-D60 "기본 경로의 설계 문서를 쓰면 신호를 알린다"
put "$W/docs/adr/0001-x.md" '# D'; run_hook "$(write_p "$W/docs/adr/0001-x.md" '# D')"
expect_out "additionalContext"; expect_out "DD-20"

tc TC-D61 "설계 문서가 아닌 .md 는 조용하다 · 표지 주석이 있으면 설계 문서다"
put "$W/README.md" '# D'; run_hook "$(write_p "$W/README.md" '# D')"
expect_no_out
put "$W/notes.md" '<!-- design-document -->
# D'; run_hook "$(write_p "$W/notes.md" 'x')"
expect_out "DD-20"

tc TC-D62 "*-design.md · *-rfc.md · design/ 를 설계 문서로 본다"
for p in "$W/x/cancel-design.md" "$W/x/cancel-rfc.md" "$W/design/a.md" "$W/designs/a.md" "$W/rfc/a.md" "$W/rfcs/a.md" "$W/decisions/a.md" "$W/adrs/a.md"; do
  put "$p" '# D'; run_hook "$(write_p "$p" '# D')"; expect_out "DD-20"
done

tc TC-D63 "DESIGN_SOUNDNESS_PATHS 를 주면 기본 경로 대신 그 글롭을 쓴다"
put "$W/specs/a.md" '# D'; put "$W/docs/adr/b.md" '# D'
if [ "$TC_ON" = 1 ]; then
  OUT="$(write_p "$W/specs/a.md" x | DESIGN_SOUNDNESS_PATHS='specs/*' "$SCRIPT" --hook 2>&1)"
  printf '%s' "$OUT" | grep -qF DD-20 || fail_tc "specs/a.md 를 설계 문서로 보지 않음"
  OUT="$(write_p "$W/docs/adr/b.md" x | DESIGN_SOUNDNESS_PATHS='specs/*' "$SCRIPT" --hook 2>&1)"
  [ -z "$OUT" ] || fail_tc "기본 경로가 남아 있음: $OUT"
fi

tc TC-D64 "같은 파일에서 이미 알린 신호는 다시 알리지 않고 새 신호만 알린다"
put "$W/docs/adr/c.md" '# D'; run_hook "$(write_p "$W/docs/adr/c.md" x)"
run_hook "$(write_p "$W/docs/adr/c.md" x)"; expect_no_out
put "$W/docs/adr/c.md" '# D
## 요구
- 빠르게'; run_hook "$(write_p "$W/docs/adr/c.md" x)"
expect_out "DD-23"; expect_not "고려한 대안"

section "H. 설계 문서 게이트 (DD-30)"

DOC="$W/docs/adr/0002-gate.md"
tc TC-D70 "설계 문서를 3줄 고치고 검토 없이 끝내면 한 번 되돌린다"
put "$DOC" "$FULL"
run_hook "$(write_p "$DOC" $'a\nb\nc')" ; run_hook "$(stop_p)"
expect_out '"decision": "block"'; expect_out "DD-30"; expect_out "0002-gate.md"; expect_out "common-document-slop-review"

tc TC-D71 "2줄이면 막지 않는다"
put "$DOC" "$FULL"; run_hook "$(edit_p "$DOC" 'a' $'a\nb')"; run_hook "$(stop_p)"
expect_no_out

tc TC-D72 "이 훅이 되돌린 뒤의 종료는 통과 · 다른 훅이 켠 stop_hook_active 는 그대로 판정"
put "$DOC" "$FULL"; run_hook "$(write_p "$DOC" $'a\nb\nc')"; run_hook "$(stop_p s1 true)"
expect_out '"decision": "block"'
run_hook "$(stop_p s1 true)"; expect_no_out

tc TC-D73 "design-soundness-reviewer 가 돌면 통과, 다른 에이전트는 아니다"
put "$DOC" "$FULL"; run_hook "$(write_p "$DOC" $'a\nb\nc')"
run_hook "$(agent_p Explore)"; run_hook "$(stop_p)"; expect_out '"decision": "block"'
run_hook "$(write_p "$DOC" $'a\nb\nc')"; run_hook "$(agent_p common-design-soundness-review:design-soundness-reviewer)"; run_hook "$(stop_p)"
expect_no_out

tc TC-D74 "검토 뒤에 3줄 이상 또 고치면 다시 막는다"
put "$DOC" "$FULL"; run_hook "$(write_p "$DOC" $'a\nb\nc')"; run_hook "$(agent_p design-soundness-reviewer)"
run_hook "$(write_p "$DOC" $'d\ne\nf')"; run_hook "$(stop_p)"
expect_out '"decision": "block"'
run_hook "$(prompt_p '다시')"; run_hook "$(write_p "$DOC" $'a\nb\nc')"; run_hook "$(agent_p design-soundness-reviewer)"
run_hook "$(edit_p "$DOC" 'a' 'z')"; run_hook "$(stop_p)"; expect_no_out

tc TC-D75 "프로젝트 밖 설계 문서 · 코드 파일은 세지 않는다"
put "$TMP/out/adr/x.md" '# D'
run_hook "$(write_p "$TMP/out/adr/x.md" $'a\nb\nc')"; run_hook "$(write_p "$W/src/a.js" $'a\nb\nc')"; run_hook "$(stop_p)"
expect_no_out

tc TC-D76 "DESIGN_SOUNDNESS_GATE=0 이면 기록도 차단도 없다"
put "$DOC" "$FULL"
if [ "$TC_ON" = 1 ]; then
  write_p "$DOC" $'a\nb\nc' | DESIGN_SOUNDNESS_GATE=0 "$SCRIPT" --hook >/dev/null 2>&1
  OUT="$(stop_p | "$SCRIPT" --hook 2>&1)"; [ -z "$OUT" ] || fail_tc "끔일 때 기록이 남음: $OUT"
  write_p "$DOC" $'a\nb\nc' | "$SCRIPT" --hook >/dev/null 2>&1
  OUT="$(stop_p | DESIGN_SOUNDNESS_GATE=0 "$SCRIPT" --hook 2>&1)"; [ -z "$OUT" ] || fail_tc "끔인데 막음: $OUT"
fi

tc TC-D77 "세션마다 따로 센다 · 요청 기록 경로를 알린다"
put "$DOC" "$FULL"
run_hook "$(write_p "$DOC" $'a\nb\nc' s1)"; run_hook "$(stop_p s2)"; expect_no_out
run_hook "$(prompt_p '취소 설계 문서 써줘' s2)"; run_hook "$(write_p "$DOC" $'a\nb\nc' s2)"; run_hook "$(stop_p s2)"
expect_out '"decision": "block"'; expect_out "s2.request"

tc TC-D78 "바꾼 줄은 고치기 전 · 후 중 큰 쪽으로 센다"
put "$DOC" "$FULL"; run_hook "$(edit_p "$DOC" $'a\nb\nc' 'z')"; run_hook "$(stop_p)"
expect_out '"decision": "block"'

tc TC-D79 "백그라운드 검증자를 기다리며 끝내면 막지 않고 기록을 남긴다 · 끝난 뒤 종료는 통과"
put "$DOC" "$FULL"; run_hook "$(write_p "$DOC" $'a\nb\nc')"
run_hook "$(async_p design-soundness-reviewer)"; run_hook "$(stop_p)"; expect_no_out
[ "$TC_ON" = 1 ] && { [ -s "$CLAUDE_PLUGIN_DATA/s1.edits" ] || fail_tc "기록이 지워짐"; }
run_hook "$(substop_p common-design-soundness-review:design-soundness-reviewer)"; run_hook "$(stop_p)"; expect_no_out
run_hook "$(write_p "$DOC" $'a\nb\nc')"; run_hook "$(async_p design-soundness-reviewer)"; run_hook "$(substop_p Explore)"
run_hook "$(prompt_p '<task-notification>done</task-notification>')"; run_hook "$(stop_p)"; expect_no_out
[ "$TC_ON" = 1 ] && { [ -e "$CLAUDE_PLUGIN_DATA/s1.pending" ] || fail_tc "다른 에이전트의 SubagentStop 이 검토 중을 지움"; }

section "I. 플랜 모드 게이트 (DD-31)"

tc TC-D80 "검토 없는 ExitPlanMode 는 exit 2 로 막고 계획 파일 · 신호를 알린다"
put "$TMP/plans/p.md" "$PLAN"
run_hook "$(plan_p "$PLAN" "$TMP/plans/p.md")"
expect_code 2; expect_out "DD-31"; expect_out "$TMP/plans/p.md"; expect_out "신호:"

tc TC-D81 "같은 계획으로 다시 나가면 통과, 바뀐 계획이면 다시 막는다"
run_hook "$(plan_p "$PLAN")"; expect_code 2
run_hook "$(plan_p "$PLAN")"; expect_code 0
run_hook "$(plan_p "$PLAN
- 추가")"; expect_code 2

tc TC-D82 "검토가 돌았으면 통과"
run_hook "$(agent_p design-soundness-reviewer)"; run_hook "$(plan_p "$PLAN")"
expect_code 0; expect_no_out

tc TC-D83 "plan 이 비면 planFilePath 를 읽고, 둘 다 없으면 통과"
put "$TMP/plans/q.md" '# 계획만 파일에'
run_hook "$(plan_p '' "$TMP/plans/q.md")"; expect_code 2; expect_out "필수 절 없음"
run_hook "$(plan_p '')"; expect_code 0

tc TC-D84 "planFilePath 가 없으면 계획을 기록 디렉터리에 써서 넘긴다"
run_hook "$(plan_p "$PLAN")"; expect_code 2; expect_out "s1.plan.md"
[ "$TC_ON" = 1 ] && { [ -s "$CLAUDE_PLUGIN_DATA/s1.plan.md" ] || fail_tc "계획 파일이 없음"; }

tc TC-D85 "DESIGN_SOUNDNESS_PLAN_GATE=0 · DESIGN_SOUNDNESS_GATE=0 이면 막지 않는다 · 다른 도구는 보지 않는다"
if [ "$TC_ON" = 1 ]; then
  plan_p "$PLAN" | DESIGN_SOUNDNESS_PLAN_GATE=0 "$SCRIPT" --hook >/dev/null 2>&1 || fail_tc "PLAN_GATE=0 인데 막음"
  plan_p "$PLAN" | DESIGN_SOUNDNESS_GATE=0 "$SCRIPT" --hook >/dev/null 2>&1 || fail_tc "GATE=0 인데 막음"
  OUT="$(plan_p "$PLAN" | jq '.tool_name = "Bash"' | "$SCRIPT" --hook 2>&1)"; CODE=$?
  [ "$CODE" = 0 ] && [ -z "$OUT" ] || fail_tc "Bash 를 막음"
fi

tc TC-D86 "새 요청은 앞 요청의 검토 · 차단 기록을 잇지 않는다"
run_hook "$(agent_p design-soundness-reviewer)"; run_hook "$(prompt_p '다른 계획 세워줘')"
run_hook "$(plan_p "$PLAN")"; expect_code 2

tc TC-D87 "백그라운드 검증자가 끝나기 전에는 같은 계획이어도 막고, SubagentStop 뒤에는 통과"
run_hook "$(plan_p "$PLAN")"; expect_code 2
run_hook "$(async_p design-soundness-reviewer)"
run_hook "$(plan_p "$PLAN")"; expect_code 2; expect_out "설계 검토 중"
run_hook "$(substop_p design-soundness-reviewer)"
run_hook "$(plan_p "$PLAN
- 판정 반영")"; expect_code 0

section "J. 설계 뒤 첫 코드 편집 (DD-32)"

tc TC-D90 "설계 요청 뒤 첫 코드 편집에서 한 번만 알린다"
run_hook "$(prompt_p '주문 취소 플로우 설계하고 구현해줘')"
run_hook "$(write_p "$W/src/a.js" 'x')"; expect_out "DD-32"
run_hook "$(write_p "$W/src/b.js" 'x')"; expect_no_out

tc TC-D91 "설계 요청이 없거나 검토가 돌았으면 조용하다"
run_hook "$(prompt_p '오타 고쳐줘')"; run_hook "$(write_p "$W/src/a.js" 'x')"; expect_no_out
run_hook "$(prompt_p 'design the cancel flow')"; run_hook "$(agent_p design-soundness-reviewer)"
run_hook "$(write_p "$W/src/a.js" 'x')"; expect_no_out

tc TC-D92 "문서 편집 · 프로젝트 밖 편집에는 알리지 않는다"
run_hook "$(prompt_p '아키텍처 잡아줘')"
put "$W/guide.md" 'x'; run_hook "$(write_p "$W/guide.md" 'x')"; expect_no_out
run_hook "$(write_p "$TMP/elsewhere.js" 'x')"; expect_no_out

tc TC-D93 "백그라운드 알림은 요청으로 치지 않는다"
run_hook "$(prompt_p '<task-notification>설계</task-notification>')"; expect_no_out
[ "$TC_ON" = 1 ] && { [ ! -e "$CLAUDE_PLUGIN_DATA/s1.request" ] || fail_tc "알림을 요청으로 기록함"; }

tc TC-D94 "requirements.txt 는 설정으로 센다 · designated 는 설계 요청이 아니다"
run_hook "$(prompt_p '의존성 설계해줘')"; run_hook "$(write_p "$W/requirements.txt" 'x')"; expect_out "DD-32"
run_hook "$(prompt_p 'the designated hitter fix')"; run_hook "$(write_p "$W/src/a.js" 'x')"; expect_no_out

tc TC-D95 "검증자가 백그라운드로 도는 동안의 코드 편집에는 알리지 않는다"
run_hook "$(prompt_p '취소 플로우 설계하고 구현해줘')"; run_hook "$(async_p design-soundness-reviewer)"
run_hook "$(write_p "$W/src/a.js" 'x')"; expect_no_out

section "K. fail-open"

tc TC-D99 "훅 입력이 JSON 이 아니거나 jq 가 없으면 조용히 통과"
run_hook "not json"; expect_code 0; expect_no_out
if [ "$TC_ON" = 1 ]; then
  NOJQ="$TMP/nojq"; mkdir -p "$NOJQ"
  for b in bash cat head dirname; do ln -sf "$(command -v $b)" "$NOJQ/$b"; done
  OUT="$(printf '%s' "$(plan_p "$PLAN")" | PATH="$NOJQ" "$SCRIPT" --hook 2>&1)"; CODE=$?
  [ "$CODE" = 0 ] || fail_tc "jq 없을 때 종료 코드 $CODE"
fi

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
