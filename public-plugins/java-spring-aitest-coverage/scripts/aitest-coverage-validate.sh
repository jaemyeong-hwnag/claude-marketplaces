#!/usr/bin/env bash
# aitest-coverage-validate.sh — 작업 완료(Stop) 시점 @AiTest 커버리지 게이트.
# 판정 기준 = git 로컬 수정사항 diff (HEAD 대비 tracked + untracked). 어떤 도구로 고쳤는지 · 커밋 여부와 무관하다.
#
# 호출:
#   UserPromptSubmit  aitest-coverage-validate.sh snapshot  — 요청 시작 시점의 대상 경로 diff 지문 저장
#   Stop              aitest-coverage-validate.sh           — 작업 완료 시점 검증
#
# 검증 (이번 요청에서 대상 경로 diff 가 바뀐 경우만 — 질문 · 조회 응답은 막지 않는다):
#   diff-coverage-validate.sh --report-only (변경 Controller @AiTest 존재 + 수정 메서드 JaCoCo 100%,
#   리포트가 diff 보다 오래되면 FAIL). 소비 모듈을 특정 못 하는 main 변경은 *AiTest* diff 가 있어야 한다.
# 미충족 → exit 2 + stderr 사유 → Claude 가 고치고 다시 완료한다.
# 트랩 방지: stop_hook_active(이미 1회 강제 계속됨)면 완료를 허용하고 systemMessage 로 알린다.
# 면제: ACK 파일에 'aitest: skip <사유>'.
# 꺼짐: @AiTest 환경(gradle/ai-test.gradle 또는 @interface AiTest)이 없는 저장소 — 세션당 한 번 알린다.
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "경고(java-spring-aitest-coverage): jq 가 없어 @AiTest 게이트를 건너뜁니다." >&2
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-stop}"
INPUT="$(cat 2>/dev/null || true)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null || echo nosession)"
ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
SAFE="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9_.-' '_')"
STATE="${TMPDIR:-/tmp}/claude-aitest-${SAFE}"
ACK="${TMPDIR:-/tmp}/claude-aitest-${SAFE}.ack"

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
cd "$(git rev-parse --show-toplevel)" || exit 0

PATHSPEC=(':(glob)**/src/main/java/**' ':(glob)**/src/main/resources/**' ':(glob)**/src/test/java/**')

# 대상 경로의 tracked diff + untracked 파일 내용 해시 → 지문
fingerprint() {
  {
    git diff HEAD -- "${PATHSPEC[@]}" 2>/dev/null
    git ls-files --others --exclude-standard -z -- "${PATHSPEC[@]}" 2>/dev/null |
      while IFS= read -r -d '' f; do
        printf '%s ' "$f"
        git hash-object -- "$f" 2>/dev/null
      done
  } | git hash-object --stdin
}

if [ "$MODE" = "snapshot" ]; then
  fingerprint > "${STATE}.turn" 2>/dev/null || true
  exit 0
fi

# 이번 요청에서 대상 diff 가 그대로면 코드 · 테스트를 건드리지 않은 응답이다
if [ -f "${STATE}.turn" ] && [ "$(cat "${STATE}.turn" 2>/dev/null)" = "$(fingerprint)" ]; then
  exit 0
fi

CHANGED="$({ git diff HEAD --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | awk 'NF && !seen[$0]++')"
MAIN="$(printf '%s\n' "$CHANGED" | grep -E '(^|/)src/main/java/.*\.java$|(^|/)src/main/resources/.*[Mm]apper.*\.xml$' || true)"
[ -z "$MAIN" ] && exit 0

if [ ! -f gradle/ai-test.gradle ] && ! git grep -qE '@interface[[:space:]]+AiTest' -- '*.java' 2>/dev/null; then
  # 환경이 없는 저장소는 막지 않는다 — 설치만 한 저장소의 완료를 깨지 않게. 세션당 한 번만 알린다.
  if [ ! -f "${STATE}.noenv" ]; then
    : > "${STATE}.noenv" 2>/dev/null || true
    jq -cn '{ systemMessage: "java-spring-aitest-coverage: @AiTest 환경(gradle/ai-test.gradle)이 없어 커버리지 게이트가 꺼져 있습니다. \"AiTest 환경 만들어줘\" 로 aitest-environment-create 를 쓸 수 있습니다." }'
  fi
  exit 0
fi

grep -Eiq 'aitest:[[:space:]]*(skip|exempt|면제)' "$ACK" 2>/dev/null && exit 0

viol=""
VALIDATE="$SCRIPT_DIR/diff-coverage-validate.sh"
out="$("$VALIDATE" --report-only HEAD 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  viol="[테스트] 로컬 diff @AiTest 커버리지 미충족 (diff-coverage-validate.sh --report-only rc=$rc):
$(printf '%s\n' "$out" | sed 's/^/      /')"
elif printf '%s' "$out" | grep -q 'no verifiable module diff' &&
     ! printf '%s\n' "$CHANGED" | grep -Eq '(^|/)src/test/java/.*AiTest.*\.java$'; then
  viol="[테스트] 소비 모듈을 특정할 수 없는 main 변경(라이브러리 · mapper)에 *AiTest* diff 없음: $(printf '%s' "$MAIN" | tr '\n' ' ')
      → 라이브러리 모듈이면 .claude/java-spring-aitest-coverage.json 의 libraryModules 에 소비 모듈을 적는다"
fi

[ -z "$viol" ] && exit 0

if [ "$ACTIVE" = "true" ]; then
  msg="java-spring-aitest-coverage: @AiTest 커버리지가 미충족인 채 작업이 끝났습니다(트랩 방지로 1회 강제 후 허용) — 확인 필요:
$(printf '%s\n' "$viol" | sed 's/^/  - /')"
  jq -cn --arg m "$msg" '{ systemMessage: $m }'
  exit 0
fi

{
  echo "완료 보류(java-spring-aitest-coverage): git 로컬 수정사항 diff(HEAD 대비 tracked+untracked) 기준 @AiTest 커버리지 미충족."
  printf '%s\n' "$viol" | sed 's/^/  - /'
  echo "조치(택1):"
  echo "  1) 수정 메서드 @AiTest 작성(java-spring-aitest-coverage:aitest-generate) 후 \"$VALIDATE\" HEAD 실행(aiTest + JaCoCo 리포트 갱신) → 다시 완료."
  echo "  2) 면제(주석 · 포맷만 등): 사용자에게 알린 뒤 echo 'aitest: skip <사유>' >> \"$ACK\""
} >&2
exit 2
