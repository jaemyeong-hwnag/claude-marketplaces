#!/usr/bin/env bash
# aitest-coverage-validate.sh — 작업 완료(Stop) 시점 Kotlin @AiTest 커버리지 게이트.
# 판정 기준 = 요청 시작 때의 HEAD 대비 diff (tracked + untracked). 어떤 도구로 고쳤는지 · 요청 안에서 커밋했는지와 무관하다.
#
# 호출:
#   UserPromptSubmit  aitest-coverage-validate.sh snapshot  — 요청 시작 시점의 HEAD 와 대상 경로 diff 지문 저장
#   Stop              aitest-coverage-validate.sh           — 작업 완료 시점 검증
#
# 검증 (이번 요청에서 대상 경로 diff 가 바뀐 경우만 — 질문 · 조회 응답은 막지 않는다):
#   diff-coverage-validate.sh --report-only (변경 Controller @AiTest 존재 + 변경 메서드 JaCoCo 100%,
#   리포트가 diff 보다 오래되면 FAIL, 판정 도구가 없으면 FAIL). 소비 모듈을 특정 못 하는 main 변경은 aiTest diff 가 있어야 한다.
# 미충족 → exit 2 + stderr 사유 → Claude 가 고치고 다시 완료한다.
# 트랩 방지: stop_hook_active(이미 1회 강제 계속됨)면 완료를 허용하고 systemMessage 로 알린다.
# 면제: ACK 파일에 'aitest: skip <사유>'.
# 꺼짐: Gradle Kotlin DSL 이 아닌 저장소(조용히) · build.gradle.kts 에 환경 블록이 없는 저장소(세션당 한 번 알림).
# 상태: <Gradle 루트>/.claude/kotlin-spring-aitest-coverage/ — Bash 샌드박스 안에서도 ACK 를 쓸 수 있게 프로젝트 안에 둔다.
set -uo pipefail

# jq 없이 돈다 — jq 가 없는 환경에서 게이트가 꺼지지 않게
json_str() { # $1 → JSON 문자열 리터럴
  local s b='\' q='"'
  s="$(printf '%s' "$1" | LC_ALL=C tr -d '\001-\010\013\014\016-\037')"
  s=${s//"$b"/"$b$b"}; s=${s//"$q"/"$b$q"}; s=${s//$'\t'/"${b}t"}; s=${s//$'\r'/"${b}r"}; s=${s//$'\n'/"${b}n"}
  printf '"%s"' "$s"
}
system_message() { printf '{"systemMessage":%s}\n' "$(json_str "$1")"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-stop}"
INPUT="$(cat 2>/dev/null || true)"
SID=nosession; ACTIVE=false
[[ "$INPUT" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && SID="${BASH_REMATCH[1]}"
[[ "$INPUT" =~ \"stop_hook_active\"[[:space:]]*:[[:space:]]*true ]] && ACTIVE=true
SAFE="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9_.-' '_')"

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
# Gradle 루트 — diff-coverage-validate.sh 와 같은 규칙 (settings.gradle(.kts) · gradlew 가 있는 가장 가까운 상위, git 루트까지)
GRADLE_ROOT="$(pwd -P)"
TOP="$(git rev-parse --show-toplevel)" || exit 0
d="$GRADLE_ROOT"
while :; do
  if [ -e "$d/settings.gradle" ] || [ -e "$d/settings.gradle.kts" ] || [ -e "$d/gradlew" ]; then GRADLE_ROOT="$d"; break; fi
  { [ "$d" = "$TOP" ] || [ "$d" = / ]; } && break
  d="$(dirname "$d")"
done
[ -e "$GRADLE_ROOT/settings.gradle.kts" ] || [ -e "$GRADLE_ROOT/build.gradle.kts" ] || exit 0
cd "$TOP" || exit 0

STATE_DIR="$GRADLE_ROOT/.claude/kotlin-spring-aitest-coverage"
STATE="$STATE_DIR/$SAFE"
ACK="$STATE.ack"
state_dir() {
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  [ -f "$STATE_DIR/.gitignore" ] || printf '*\n' > "$STATE_DIR/.gitignore" 2>/dev/null || true
}

PATHSPEC=(':(glob)**/src/main/kotlin/**' ':(glob)**/src/main/java/**' ':(glob)**/src/main/resources/**' ':(glob)**/src/aiTest/**')

# 이번 요청의 비교 기준 — 요청 시작 HEAD 와 지금 작업 트리의 차이. 커밋 · push · amend · squash 해도 남는다.
# 요청 시작 때의 원격이 지금 HEAD 에 합쳐져 있으면 그 원격과도 달라야 한다 — 합치거나 리베이스로 들어온 원격 변경은 뺀다
turn_refs() { # $1=기준 파일 (1행 요청 시작 HEAD · 2행 그때의 원격 기본 브랜치) → REF · ALSO
  local remote
  REF="$(sed -n 1p "$1" 2>/dev/null)"
  remote="$(sed -n 2p "$1" 2>/dev/null)"
  ALSO=""
  git cat-file -e "${REF:-none}^{commit}" 2>/dev/null || REF=HEAD
  if [ -n "$remote" ] && [ "$remote" != "$REF" ] && git merge-base --is-ancestor "$remote" HEAD 2>/dev/null; then ALSO="$remote"; fi
}

# 원격 기본 브랜치의 지금 커밋 (없으면 빈 값)
remote_head() {
  local r
  r="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
  [ -n "$r" ] || for r in origin/main origin/master ""; do git rev-parse -q --verify "$r" >/dev/null 2>&1 && break; done
  [ -z "$r" ] || git rev-parse -q --verify "$r^{commit}" 2>/dev/null
}

# 대상 경로의 tracked diff + untracked 파일 내용 해시 → 지문. $1=비교 기준
fingerprint() {
  {
    git diff "$1" -- "${PATHSPEC[@]}" 2>/dev/null
    git ls-files --others --exclude-standard -z -- "${PATHSPEC[@]}" 2>/dev/null |
      while IFS= read -r -d '' f; do
        printf '%s ' "$f"
        git hash-object -- "$f" 2>/dev/null
      done
  } | git hash-object --stdin
}

if [ "$MODE" = "snapshot" ]; then
  state_dir
  head="$(git rev-parse -q --verify HEAD 2>/dev/null)"
  if [ -n "$head" ]; then printf '%s\n%s\n' "$head" "$(remote_head)" > "${STATE}.base"; else rm -f "${STATE}.base"; fi
  fingerprint HEAD > "${STATE}.turn" 2>/dev/null || true
  exit 0
fi

turn_refs "${STATE}.base"

# 이번 요청에서 대상 diff 가 그대로면 코드 · 테스트를 건드리지 않은 응답이다
if [ -f "${STATE}.turn" ] && [ "$(cat "${STATE}.turn" 2>/dev/null)" = "$(fingerprint "$REF")" ]; then
  exit 0
fi

tracked() { git diff "$1" --name-only 2>/dev/null | sort -u; }
CHANGED="$({ if [ -n "$ALSO" ]; then { tracked "$REF"; tracked "$ALSO"; } | sort | uniq -d; else tracked "$REF"; fi
             git ls-files --others --exclude-standard 2>/dev/null; } | awk 'NF && !seen[$0]++')"
MAIN="$(printf '%s\n' "$CHANGED" | grep -E '(^|/)src/main/(kotlin|java)/.*\.kt$|(^|/)src/main/resources/.*[Mm]apper.*\.xml$' || true)"
[ -z "$MAIN" ] && exit 0

if ! git grep -q --untracked -F '// >>> kotlin-spring-aitest-coverage' -- '*build.gradle.kts' 2>/dev/null; then
  # 환경이 없는 저장소는 막지 않는다 — 설치만 한 저장소의 완료를 깨지 않게. 세션당 한 번만 알린다.
  if [ ! -f "${STATE}.noenv" ]; then
    state_dir
    : > "${STATE}.noenv" 2>/dev/null || true
    system_message 'kotlin-spring-aitest-coverage: @AiTest 환경(build.gradle.kts 의 kotlin-spring-aitest-coverage 블록)이 없어 커버리지 게이트가 꺼져 있습니다. "Kotlin AiTest 환경 만들어줘" 로 kotlin-aitest-environment-create 를 쓸 수 있습니다.'
  fi
  exit 0
fi

grep -Eiq 'aitest:[[:space:]]*(skip|exempt|면제)' "$ACK" 2>/dev/null && exit 0

viol=""
VALIDATE="$SCRIPT_DIR/diff-coverage-validate.sh"
out="$(CLAUDE_PROJECT_DIR="$GRADLE_ROOT" "$VALIDATE" --report-only ${ALSO:+--also "$ALSO"} "$REF" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  viol="[테스트] 로컬 diff @AiTest 커버리지 미충족 (diff-coverage-validate.sh --report-only rc=$rc):
$(printf '%s\n' "$out" | sed 's/^/      /')"
elif printf '%s' "$out" | grep -q 'no verifiable module diff' &&
     ! printf '%s\n' "$CHANGED" | grep -Eq '(^|/)src/aiTest/kotlin/.*\.kt$'; then
  viol="[테스트] 소비 모듈을 특정할 수 없는 main 변경(라이브러리 · mapper)에 aiTest diff 없음: $(printf '%s' "$MAIN" | tr '\n' ' ')
      → 라이브러리 모듈이면 .claude/kotlin-spring-aitest-coverage.json 의 libraryModules 에 소비 모듈을 적는다"
fi

[ -z "$viol" ] && exit 0

if [ "$ACTIVE" = "true" ]; then
  msg="kotlin-spring-aitest-coverage: @AiTest 커버리지가 미충족인 채 작업이 끝났습니다(트랩 방지로 1회 강제 후 허용) — 확인 필요:
$(printf '%s\n' "$viol" | sed 's/^/  - /')"
  system_message "$msg"
  exit 0
fi

state_dir
{
  echo "완료 보류(kotlin-spring-aitest-coverage): 이번 요청의 diff(요청 시작 HEAD 대비 tracked+untracked) 기준 @AiTest 커버리지 미충족."
  printf '%s\n' "$viol" | sed 's/^/  - /'
  echo "조치(택1):"
  echo "  1) 변경 메서드 @AiTest 작성(kotlin-spring-aitest-coverage:kotlin-aitest-generate) 후 \"$VALIDATE\" ${ALSO:+--also $ALSO }$REF 실행(aiTest + JaCoCo 리포트 갱신) → 다시 완료."
  echo "  2) 면제(주석 · 포맷만 등): 사용자에게 알린 뒤 echo 'aitest: skip <사유>' >> \"$ACK\""
} >&2
exit 2
