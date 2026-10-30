#!/usr/bin/env bash
# scripts/document-slop-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/document-slop-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/document-slop-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export CLAUDE_PLUGIN_DATA="$TMP/data"
unset DOCUMENT_SLOP_REVIEW_GATE
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
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" --hook 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
# 문서 하나를 만들어 검사한다 — $1=이름 (내용은 stdin)
scan() { [ "$TC_ON" = 1 ] || { cat >/dev/null; return 0; }; local d; d="$(mktemp -d "$TMP/s.XXXXXX")"; cat > "$d/$1"; run "$d/$1"; }
write_payload() { # $1=경로 $2=content [$3=session]
  jq -n --arg f "$1" --arg c "$2" --arg s "${3:-s1}" --arg w "$TMP" '{hook_event_name: "PostToolUse", tool_name: "Write", session_id: $s, cwd: $w, tool_input: {file_path: $f, content: $c}}'
}
edit_payload() { # $1=경로 $2=new_string [$3=session]
  jq -n --arg f "$1" --arg c "$2" --arg s "${3:-s1}" --arg w "$TMP" '{hook_event_name: "PostToolUse", tool_name: "Edit", session_id: $s, cwd: $w, tool_input: {file_path: $f, old_string: "x", new_string: $c}}'
}
stop_payload() { jq -n --arg s "${1:-s1}" --argjson a "${2:-false}" '{hook_event_name: "Stop", session_id: $s, stop_hook_active: $a}'; }

echo "== A. 차단 (DS-01 ~ DS-04)"

tc TC-D01 "대화 잔재는 차단, 같은 단어의 정상 문장은 통과 (DS-01)"
scan a.md <<'EOF'
# 안내

설치가 끝났습니다. 도움이 되셨길 바랍니다.
Let me know if you need anything else.
이 도구는 배포에 도움이 된다.
EOF
expect_code 2; expect_out "3행 DS-01"; expect_out "4행 DS-01"; expect_not "5행 DS-01"

tc TC-D02 "플레이스홀더는 차단, 같은 글자의 마크다운 링크는 통과 (DS-02)"
scan b.md <<'EOF'
# 설계

[여기에 배경 설명 작성]
lorem ipsum dolor sit amet
[TODO](./b.md) 문서를 본다.
EOF
expect_code 2; expect_out "3행 DS-02"; expect_out "4행 DS-02"; expect_not "5행 DS-02"

tc TC-D03 "챗봇 인용 토큰은 차단 (DS-03)"
scan c.md <<'EOF'
# 출처

결과는 다음과 같다 :contentReference[oaicite:0]{index=0}
자세한 내용은 https://example.com/?utm_source=chatgpt.com 에 있다.
EOF
expect_code 2; expect_out "3행 DS-03"; expect_out "4행 DS-03"

tc TC-D04 "없는 상대 링크 · 참조 링크는 차단, 있는 경로(%20 포함) · URL · 앵커 · 절대 경로는 통과 (DS-04)"
if [ "$TC_ON" = 1 ]; then mkdir -p "$TMP/d/sub"; : > "$TMP/d/sub/ok.md"; : > "$TMP/d/sub/ok x.md"; cat > "$TMP/d/x.md" <<'EOF'
# 링크

[없음](./missing.md) · [있음](sub/ok.md#절) · [외부](https://example.com) · [앵커](#링크) · [루트](/abs.md)
[공백](sub/ok%20x.md)

[ref]: ./also-missing.md
EOF
fi
run "$TMP/d/x.md"
expect_code 2; expect_out "3행 DS-04"; expect_out "missing.md"; expect_not "4행 DS-04"; expect_out "6행 DS-04"
expect_not "sub/ok.md)"

tc TC-D05 "코드 펜스 · 인라인 코드 · 인용 · HTML 주석(여러 줄 포함) · 프런트매터 안은 보지 않는다"
scan e.md <<'EOF'
---
title: 도움이 되셨길
---
# 예시

```
도움이 되셨길 바랍니다
```
~~~
[여기에 작성]
~~~
`도움이 되셨길 바랍니다` 는 금지 표현이다.
> 도움이 되셨길 바랍니다 — 인용
<!-- 도움이 되셨길 바랍니다 -->
<!--
I hope this helps
-->
<!-- 여러 줄
[여기에 작성]
끝 --> 본문은 brew 로 설치한다.
EOF
expect_code 0; expect_not "DS-01"; expect_not "DS-02"

tc TC-D06 "document-slop-ignore 는 그 줄과 다음 줄을 뺀다"
scan f.md <<'EOF'
# 예외

도움이 되셨길 바랍니다 <!-- document-slop-ignore -->
<!-- document-slop-ignore -->
I hope this helps
I hope this helps
EOF
expect_out "6행 DS-01"; expect_not "3행 DS-01"; expect_not "5행 DS-01"

echo "== B. 근거 (DS-05 ~ DS-07)"

tc TC-D10 "출처 없는 출처 표현은 경고, 같은 줄에 링크 · 미확인 · 각주가 있으면 통과 (DS-05)"
scan g.md <<'EOF'
# 근거

연구에 따르면 이 방식이 빠르다.
연구에 따르면 이 방식이 빠르다 (https://example.com).
Studies show this works (미확인).
전문가들은 이렇게 말한다[^1].
EOF
expect_code 0; expect_out "3행 DS-05"; expect_not "4행 DS-05"; expect_not "5행 DS-05"; expect_not "6행 DS-05"

tc TC-D11 "날짜 없는 시점 표현은 경고, 연도 · 기준일이 있으면 통과 (DS-06)"
scan h.md <<'EOF'
# 시점

최근 많이 쓰인다.
2026-10 기준 최근 많이 쓰인다.
This is currently the default.
EOF
expect_out "3행 DS-06"; expect_not "4행 DS-06"; expect_out "5행 DS-06"

tc TC-D12 "근거 없는 수치는 경고, 출처 · 측정 · 표 행은 통과 (DS-07)"
scan i.md <<'EOF'
# 수치

응답이 30% 빨라졌다.
응답이 30% 빨라졌다 (측정: scripts/bench.sh).
| 항목 | 값 |
|---|---|
| 감소 | 30% |
캐시로 3x faster 가 된다.
EOF
expect_out "3행 DS-07"; expect_not "4행 DS-07"; expect_not "7행 DS-07"; expect_out "8행 DS-07"

echo "== C. 불필요한 내용 (DS-08 ~ DS-13)"

tc TC-D20 "메타 서술은 경고, 일반 설명은 통과 (DS-08)"
scan j.md <<'EOF'
# 설치

이 문서에서는 설치 방법을 살펴보겠습니다.
It's important to note that the cache is shared.
설치는 brew 로 한다.
EOF
expect_out "3행 DS-08"; expect_out "4행 DS-08"; expect_not "5행 DS-08"

tc TC-D21 "마지막 제목이 요약 절이면 경고, 앞에 있는 요약은 통과 (DS-09)"
scan k.md <<'EOF'
# 문서

## 요약

본문.

## 결론
EOF
expect_out "7행 DS-09"; expect_not "3행 DS-09"
scan k2.md <<'EOF'
# 문서

## 결론

## 변경 이력
EOF
expect_not "DS-09"

tc TC-D22 "과용 어휘는 서로 다른 단어 3개부터 경고 (DS-10)"
scan l.md <<'EOF'
# 어휘

We delve into the pivotal design.
EOF
expect_not "DS-10"
scan l2.md <<'EOF'
# 어휘

We delve into the pivotal design.
It is a testament to the team.
EOF
expect_out "DS-10"; expect_out "delve"; expect_out "testament"

tc TC-D23 "대비 구문은 2회부터 경고 (DS-11)"
scan m.md <<'EOF'
# 대비

기능뿐만 아니라 문화다.
EOF
expect_not "DS-11"
scan m2.md <<'EOF'
# 대비

기능뿐만 아니라 문화다. 단순히 도구가 아니라 철학이다.
EOF
expect_out "3행 DS-11"

tc TC-D24 "과장 어휘 · 헤지 겹침은 경고, 단정 문장은 통과 (DS-12 · DS-13)"
scan n.md <<'EOF'
# 소개

이 기능은 획기적이다.
This may potentially break the build.
이 기능은 응답을 캐시한다.
EOF
expect_out "3행 DS-12"; expect_out "4행 DS-13"; expect_not "5행 DS-1"

echo "== D. 정리 (DS-14 ~ DS-16)"

tc TC-D30 "머리말 목록 6줄 연속 · 이모지 제목은 경고, 5줄은 통과 (DS-14)"
scan o.md <<'EOF'
# 목록

- **하나**: 설명
- **둘**: 설명
- **셋**: 설명
- **넷**: 설명
- **다섯**: 설명

## 🚀 시작
EOF
expect_not "줄 이상 연속"; expect_out "9행 DS-14"
scan o2.md <<'EOF'
# 목록

- **하나**: 설명
- **둘**: 설명
- **셋**: 설명
- **넷**: 설명
- **다섯**: 설명
- **여섯**: 설명
EOF
expect_out "3행 DS-14"

tc TC-D31 "굵게 남용은 경고, 적으면 통과 (DS-14)"
scan p.md <<'EOF'
# 굵게

**가** **나** 문장.
**다** **라** 문장.
**마** **바** 문장.
**사** **아** 문장.
EOF
expect_out "문서 전체 DS-14"
scan p2.md <<'EOF'
# 굵게

**가** 문장.
일반 문장.
EOF
expect_not "DS-14"

tc TC-D32 "제목 수준을 건너뛰면 경고, 한 단계씩이면 통과 (DS-15)"
scan q.md <<'EOF'
# 하나

### 셋

## 둘

### 셋
EOF
expect_out "3행 DS-15"; expect_not "7행 DS-15"

tc TC-D33 "같은 긴 문장이 또 있으면 경고, 짧은 반복은 통과 (DS-16)"
scan r.md <<'EOF'
# 반복

이 플러그인은 문서를 저장할 때마다 검사를 실행한다.
없음
이 플러그인은 문서를 저장할 때마다 검사를 실행한다.
없음
EOF
expect_out "5행 DS-16"; expect_not "3행 DS-16"; expect_not "6행 DS-16"

echo "== E. 대상 파일 · CLI"

tc TC-D40 "문서가 아닌 파일 · requirements.txt 는 보지 않는다"
if [ "$TC_ON" = 1 ]; then printf '도움이 되셨길 바랍니다\n' > "$TMP/x.py"; printf 'lorem ipsum\n' > "$TMP/requirements.txt"; fi
run "$TMP/x.py" "$TMP/requirements.txt"; expect_code 0; expect_out "문서 0개"

tc TC-D41 "--strict 는 경고가 있으면 exit 2, 경고가 없으면 0"
scan s.md <<'EOF'
# 시점

최근 바뀌었다.
EOF
expect_code 0
run --strict "$(dirname "$(ls -d "$TMP"/s.*/s.md | head -1)")/s.md"; expect_code 2
scan s2.md <<'EOF'
# 깨끗

설치는 brew 로 한다.
EOF
expect_code 0; expect_out "차단 0건 · 경고 0건"

tc TC-D42 "--diff 는 바뀐 줄만 본다"
if [ "$TC_ON" = 1 ]; then
  git init -q "$TMP/g" && cd "$TMP/g" && printf '# 문서\n\n최근 바뀌었다.\n' > a.md && git add a.md && git commit -qm init
  printf '# 문서\n\n최근 바뀌었다.\n도움이 되셨길 바랍니다.\n' > a.md
fi
run --diff HEAD; expect_code 2; expect_out "4행 DS-01"; expect_not "3행 DS-06"
[ "$TC_ON" = 1 ] && cd "$TMP"

tc TC-D43 "모르는 옵션 · 없는 경로는 exit 1"
run --nope; expect_code 1
run "$TMP/none.md"; expect_code 1

echo "== F. 훅"

tc TC-D50 "Write 훅 — 차단은 exit 2 + stderr, 경고도 함께 보인다"
if [ "$TC_ON" = 1 ]; then printf '# 문서\n\n도움이 되셨길 바랍니다.\n최근 바뀌었다.\n' > "$TMP/w.md"; fi
run_hook "$(write_payload "$TMP/w.md" "$(cat "$TMP/w.md" 2>/dev/null)")"
expect_code 2; expect_out "DS-01"; expect_out "경고:"; expect_out "DS-06"

tc TC-D51 "Edit 훅 — 경고만 있으면 additionalContext, exit 0"
if [ "$TC_ON" = 1 ]; then printf '# 문서\n\n최근 바뀌었다.\n' > "$TMP/w2.md"; fi
run_hook "$(edit_payload "$TMP/w2.md" "최근 바뀌었다.")"
expect_code 0; expect_out "additionalContext"; expect_out "DS-06"

tc TC-D52 "Edit 훅 — 이번에 쓴 줄이 깨끗하면 다른 줄의 slop 은 알리지 않는다"
if [ "$TC_ON" = 1 ]; then printf '# 문서\n\n도움이 되셨길 바랍니다.\n설치는 brew 로 한다.\n' > "$TMP/w3.md"; fi
run_hook "$(edit_payload "$TMP/w3.md" "설치는 brew 로 한다.")"
expect_code 0; expect_no_out

tc TC-D53 "훅 — 문서가 아닌 파일 · 다른 이벤트 · 빈 입력 · 깨진 입력은 조용하다"
if [ "$TC_ON" = 1 ]; then printf 'x = "도움이 되셨길"\n' > "$TMP/h.py"; fi
run_hook "$(write_payload "$TMP/h.py" 'x = "도움이 되셨길"')"; expect_code 0; expect_no_out
run_hook '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"x.md"}}'; expect_code 0; expect_no_out
run_hook ''; expect_code 0; expect_no_out
run_hook 'not json'; expect_code 0; expect_no_out

tc TC-D54 "훅은 경고를 10건으로 자른다"
if [ "$TC_ON" = 1 ]; then printf '# 문서\n\n' > "$TMP/many.md"; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf '최근 %s 번째 변경.\n' "$i" >> "$TMP/many.md"; done; fi
run_hook "$(write_payload "$TMP/many.md" "$(cat "$TMP/many.md" 2>/dev/null)")"
expect_out "외 2건"; expect_not "14행"

echo "== G. 완료 게이트 (DS-30)"

tc TC-D60 "3줄 이상 고치고 리뷰 없이 끝나면 한 번 막고, 두 번째 종료는 통과시킨다"
if [ "$TC_ON" = 1 ]; then printf '# 문서\n\n하나.\n둘.\n셋.\n' > "$TMP/g1.md"; fi
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g60)"; expect_code 0
run_hook "$(stop_payload g60 false)"; expect_out '"decision": "block"'; expect_out "g1.md"; expect_out "document-slop-review"
run_hook "$(stop_payload g60 true)"; expect_no_out
run_hook "$(stop_payload g60 false)"; expect_no_out

tc TC-D61 "리뷰 스킬 · 에이전트가 돌면 기록을 지우고, 다른 스킬은 지우지 않는다"
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g61)"
run_hook '{"hook_event_name":"PostToolUse","tool_name":"Skill","session_id":"g61","tool_input":{"skill":"other-review"}}'
run_hook "$(stop_payload g61 false)"; expect_out '"decision": "block"'
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g61b)"
run_hook '{"hook_event_name":"PostToolUse","tool_name":"Skill","session_id":"g61b","tool_input":{"skill":"common-document-slop-review:document-slop-review"}}'
run_hook "$(stop_payload g61b false)"; expect_no_out
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g61c)"
run_hook '{"hook_event_name":"PostToolUse","tool_name":"Agent","session_id":"g61c","tool_input":{"subagent_type":"common-document-slop-review:document-slop-reviewer"}}'
run_hook "$(stop_payload g61c false)"; expect_no_out

tc TC-D62 "2줄 이하 수정 · 프로젝트 밖 문서 · 세션이 다르면 기록하지 않는다"
if [ "$TC_ON" = 1 ]; then OUTSIDE="$(mktemp -d "${TMPDIR:-/tmp}/document-slop-out.XXXXXX")"; printf '# 밖\n\n하나.\n둘.\n셋.\n' > "$OUTSIDE/o.md"; fi
run_hook "$(edit_payload "$TMP/g1.md" "하나.
둘." g62)"
run_hook "$(stop_payload g62 false)"; expect_no_out
run_hook "$(write_payload "$OUTSIDE/o.md" "$(cat "$OUTSIDE/o.md" 2>/dev/null)" g62b)"
run_hook "$(stop_payload g62b false)"; expect_no_out
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g62c)"
run_hook "$(stop_payload g62d false)"; expect_no_out
[ "$TC_ON" = 1 ] && rm -rf "$OUTSIDE"

tc TC-D63 "DOCUMENT_SLOP_REVIEW_GATE=0 이면 게이트가 꺼진다"
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g63)"
if [ "$TC_ON" = 1 ]; then OUT="$(stop_payload g63 false | DOCUMENT_SLOP_REVIEW_GATE=0 "$SCRIPT" --hook 2>&1)"; CODE=$?; fi
expect_code 0; expect_no_out

tc TC-D64 "백그라운드로 띄운 document-slop-reviewer 는 끝날 때(SubagentStop)까지 리뷰로 치지 않는다"
run_hook "$(write_payload "$TMP/g1.md" "$(cat "$TMP/g1.md" 2>/dev/null)" g64)"
run_hook '{"hook_event_name":"PostToolUse","tool_name":"Agent","session_id":"g64","tool_input":{"subagent_type":"common-document-slop-review:document-slop-reviewer","run_in_background":true},"tool_response":{"isAsync":true,"status":"async_launched"}}'
run_hook "$(stop_payload g64 false)"; expect_no_out
[ "$TC_ON" = 1 ] && { [ -s "$CLAUDE_PLUGIN_DATA/gate-g64.list" ] || fail_tc "기다리는 동안 기록이 지워짐"; }
run_hook '{"hook_event_name":"SubagentStop","session_id":"g64","agent_type":"Explore"}'
[ "$TC_ON" = 1 ] && { [ -e "$CLAUDE_PLUGIN_DATA/gate-g64.pending" ] || fail_tc "다른 에이전트의 SubagentStop 이 리뷰 중을 지움"; }
run_hook '{"hook_event_name":"SubagentStop","session_id":"g64","agent_type":"common-document-slop-review:document-slop-reviewer"}'
[ "$TC_ON" = 1 ] && { [ ! -e "$CLAUDE_PLUGIN_DATA/gate-g64.list" ] && [ ! -e "$CLAUDE_PLUGIN_DATA/gate-g64.pending" ] || fail_tc "SubagentStop 뒤 기록이 남음"; }
run_hook "$(stop_payload g64 false)"; expect_no_out

flush_tc
echo ""
echo "통과 $PASS / 실패 $FAIL$([ "$SKIP" -gt 0 ] && echo " / 건너뜀 $SKIP")"
[ "$FAIL" = 0 ]
