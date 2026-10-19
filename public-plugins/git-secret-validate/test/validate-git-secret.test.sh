#!/usr/bin/env bash
# scripts/validate-git-secret.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-git-secret.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/git-secret-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# 기본은 내장 엔진 — 결과가 설치된 gitleaks 버전에 따라 바뀌지 않게. D 절만 gitleaks
export GIT_SECRET_ENGINE=builtin
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
unset CLAUDE_PROJECT_DIR
# 픽스처 경로가 깨져도 git 명령이 이 저장소에 닿지 않게
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
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처 ------------------------------------------------------------------
# 이 파일이 저장소 검사(TC-S01)에 걸리지 않도록 값을 이어 붙여 만든다
AWS_KEY="AKIA""QYLPMN5HHHFPZAM2"
GH_TOKEN="ghp_""8fK2pQ9xLm4Rt7Vw1Zy3Bn6Hj5Dc0Ae2Gs4K"
PEM_HEAD="-----BEGIN ""RSA PRIVATE KEY-----"
# 첫 커밋이 있는 빈 저장소 → 경로
# $(...) 서브셸에서 불리므로 번호 대신 mktemp 로 디렉터리를 나눈다
repo() {
  local d; d="$(mktemp -d "$TMP/r.XXXXXX")"
  { git -C "$d" init -q -b work && git -C "$d" config user.email t@example.com && git -C "$d" config user.name t
    printf 'print("hello")\n' > "$d/app.py"
    git -C "$d" add app.py && git -C "$d" commit -qm init; } >/dev/null 2>&1
  printf '%s' "$d"
}
payload_bash() { # $1=cwd $2=명령
  jq -n --arg d "$1" --arg c "$2" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, tool_input: {command: $c}}'
}
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n}}'
}

echo "git-secret-validate 회귀 테스트"

# --- A. CLI ------------------------------------------------------------------
tc TC-S01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-S02 "시크릿 · 민감 파일이 없는 저장소는 통과한다"
r="$(repo)"; run --all "$r"; expect_code 0; expect_out "없음"

tc TC-S03 "추적 파일의 AWS 키 · GitHub 토큰을 찾고 값은 앞 4글자만 보인다 (GS-01)"
r="$(repo)"; printf 'key = "%s"\ntoken = "%s"\n' "$AWS_KEY" "$GH_TOKEN" > "$r/config.py"; git -C "$r" add config.py
run --all "$r"; expect_code 2; expect_out "[GS-01] config.py — aws-access-token: AKIA…"; expect_out "github-pat"; expect_not "$AWS_KEY"

tc TC-S04 "개인 키 블록을 찾는다 (GS-01)"
r="$(repo)"; printf '%s\nMIIEow\n' "$PEM_HEAD" > "$r/deploy.txt"
run --all "$r"; expect_code 2; expect_out "private-key"

tc TC-S05 "비밀번호 이름의 변수에 넣은 문자열을 찾는다 (GS-01)"
r="$(repo)"; printf 'DB_PASSWORD = "%s"\n' "s3cr3t""P4ssw0rd!" > "$r/settings.py"
run --all "$r"; expect_code 2; expect_out "generic-secret"

tc TC-S06 "플레이스홀더 · 환경 변수 읽기는 시크릿으로 보지 않는다 (과잉 차단 방지)"
r="$(repo)"; printf 'password = "${DB_PASSWORD}"\napi_key = "<your-api-key>"\nsecret = "changeme-later"\ntoken = os.getenv("TOKEN")\n' > "$r/settings.py"
run --all "$r"; expect_code 0

tc TC-S07 "gitleaks:allow 주석이 있는 줄은 건너뛴다"
r="$(repo)"; printf 'key = "%s"  # gitleaks:allow\n' "$AWS_KEY" > "$r/fixture.py"
run --all "$r"; expect_code 0

tc TC-S08 "ignore 되지 않은 .env 는 GS-04, ignore 되면 통과한다"
r="$(repo)"; printf 'X=1\n' > "$r/.env"
run --all "$r"; expect_code 2; expect_out "[GS-04] .env"
printf '.env\n' > "$r/.gitignore"; run --all "$r"; expect_code 0

tc TC-S09 "추적되는 민감 파일은 .gitignore 에 있어도 GS-02"
r="$(repo)"; printf 'X=1\n' > "$r/.env"; git -C "$r" add .env; printf '.env\n' > "$r/.gitignore"
run --all "$r"; expect_code 2; expect_out "[GS-02] .env"

tc TC-S10 ".env.example · *.pub · 일반 파일은 민감 파일이 아니다 (과잉 차단 방지)"
r="$(repo)"; printf 'X=\n' > "$r/.env.example"; printf 'ssh-ed25519 AAAA\n' > "$r/id_ed25519.pub"; printf 'x\n' > "$r/environment.md"
run --all "$r"; expect_code 0

tc TC-S11 "키 · 인증서 · 자격 증명 파일을 민감 파일로 본다 (GS-04)"
r="$(repo)"; for f in server.pem tls.key id_rsa credentials.json terraform.tfstate prod.env; do printf 'x\n' > "$r/$f"; done
run --all "$r"; expect_code 2
for f in server.pem tls.key id_rsa credentials.json terraform.tfstate prod.env; do expect_out "[GS-04] $f"; done

tc TC-S12 ".git-secret-allow 의 파일 · 디렉터리는 건너뛴다"
r="$(repo)"; mkdir -p "$r/test/keys"; printf 'x\n' > "$r/test/keys/sample.pem"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/test/keys/fake.py"
printf 'x\n' > "$r/local.pem"
printf '# 테스트 키\ntest/keys\nlocal.pem\n' > "$r/.git-secret-allow"
run --all "$r"; expect_code 0

tc TC-S13 "--history 는 나중에 지운 시크릿 · 민감 파일도 찾는다"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/old.py"; printf 'X=1\n' > "$r/.env"
git -C "$r" add old.py .env && git -C "$r" commit -qm add && git -C "$r" rm -q old.py .env && git -C "$r" commit -qm rm
run --all "$r"; expect_code 0
run --history "$r"; expect_code 2; expect_out "[GS-01] old.py"; expect_out "[GS-02] .env — 민감 파일이 커밋 이력에 있다"; expect_not "커밋에 들어간다"

tc TC-S14 "바이너리 파일은 보지 않는다"
r="$(repo)"; printf 'key=%s\000\001\002' "$AWS_KEY" > "$r/blob.bin"
run --all "$r"; expect_code 0

tc TC-S15 "git 저장소가 아닌 디렉터리 · 파일 인자도 본다"
d="$TMP/plain"; mkdir -p "$d"; printf 'token = "%s"\n' "$GH_TOKEN" > "$d/a.txt"
run --all "$d"; expect_code 2; expect_out "a.txt"
run "$d/a.txt"; expect_code 2; expect_out "a.txt"

tc TC-S16 "하위 디렉터리를 루트로 주면 그 아래만 본다"
r="$(repo)"; mkdir -p "$r/svc" "$r/other"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/other/k.py"; printf 'x = 1\n' > "$r/svc/a.py"
run --all "$r/svc"; expect_code 0
run --all "$r/other"; expect_code 2; expect_out "other/k.py"

tc TC-S17 "파일 인자도 .git-secret-allow 를 따른다"
r="$(repo)"; mkdir -p "$r/fixtures"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/fixtures/k.py"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"
printf 'fixtures\n' > "$r/.git-secret-allow"
run "$r/fixtures/k.py"; expect_code 0
run "$r/c.py"; expect_code 2; expect_out "c.py"

tc TC-S18 "\$ 가 든 값은 값 전체가 \${…} · \$VAR 일 때만 플레이스홀더다"
r="$(repo)"; printf 'db_password = "%s"\n' 'Tr0ub4dor$horse' > "$r/a.py"
run --all "$r"; expect_code 2; expect_out "[GS-01] a.py — generic-secret"
r="$(repo)"; printf 'db_password = "%s"\napi_key = "%s"\n' '$DB_PASSWORD' '${API_KEY:-none}' > "$r/a.py"
run --all "$r"; expect_code 0

# --- B. 훅 — Bash ------------------------------------------------------------
tc TC-S30 "스테이징된 시크릿이 있으면 git commit 을 막는다 (GS-01)"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/config.py"; git -C "$r" add config.py
run_stdin "$(payload_bash "$r" 'git commit -m "add config"')"; expect_code 2; expect_out "[GS-01] config.py"; expect_out "secret-review"

tc TC-S31 "깨끗한 커밋은 조용히 통과한다"
r="$(repo)"; printf 'x = 1\n' > "$r/a.py"; git -C "$r" add a.py
run_stdin "$(payload_bash "$r" 'git commit -m ok')"; expect_code 0; expect_no_out

tc TC-S32 "같은 명령의 git add 는 스테이징 전이라도 본다"
r="$(repo)"; printf 'token = "%s"\n' "$GH_TOKEN" > "$r/new.py"
run_stdin "$(payload_bash "$r" 'git add new.py && git commit -m x')"; expect_code 2; expect_out "[GS-01] new.py"

tc TC-S33 "git add 없는 git commit 은 스테이징되지 않은 파일을 보지 않는다 (과잉 차단 방지)"
r="$(repo)"; printf 'token = "%s"\n' "$GH_TOKEN" > "$r/wip.py"; printf 'x = 1\n' > "$r/a.py"; git -C "$r" add a.py
run_stdin "$(payload_bash "$r" 'git commit -m x')"; expect_code 0

tc TC-S34 "git commit -am 은 바뀐 추적 파일을 본다"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" >> "$r/app.py"
run_stdin "$(payload_bash "$r" 'git commit -am "update"')"; expect_code 2; expect_out "[GS-01] app.py"

tc TC-S45 "git commit <경로> · --only · -i 는 그 경로의 작업 트리 내용을 본다"
r="$(repo)"; printf 'x = 1\n' > "$r/app.py"; git -C "$r" add app.py; git -C "$r" commit -qm base
printf 'key = "%s"\n' "$AWS_KEY" >> "$r/app.py"
run_stdin "$(payload_bash "$r" 'git commit app.py -m "update app"')"; expect_code 2; expect_out "[GS-01] app.py"
run_stdin "$(payload_bash "$r" 'git commit -m x -- app.py')"; expect_code 2
run_stdin "$(payload_bash "$r" 'git commit --only -m x app.py')"; expect_code 2
run_stdin "$(payload_bash "$r" 'git commit -qm wip -i app.py')"; expect_code 2

tc TC-S46 "메시지 · 옵션 값은 경로로 보지 않는다 (과잉 차단 방지)"
r="$(repo)"; printf 'x = 1\n' > "$r/app.py"; git -C "$r" add app.py; git -C "$r" commit -qm base
printf 'key = "%s"\n' "$AWS_KEY" >> "$r/app.py"; printf 'y = 1\n' > "$r/b.py"; git -C "$r" add b.py
run_stdin "$(payload_bash "$r" 'git commit -m "fix app.py" --author "a <a@b>"')"; expect_code 0
run_stdin "$(payload_bash "$r" 'git commit -m app.py')"; expect_code 0
run_stdin "$(payload_bash "$r" 'git commit b.py -m x')"; expect_code 0

tc TC-S47 "git add <경로> 는 그 경로만 보고, . · -A · -u · 경로 없는 git add 는 바뀐 파일 전체를 본다"
r="$(repo)"; printf 'DB_HOST=localhost\n' > "$r/.env"; printf 'b\n' > "$r/b.txt"; mkdir -p "$r/src"; printf 'x = 1\n' > "$r/src/a.py"
run_stdin "$(payload_bash "$r" 'git add b.txt && git commit -m "feat: b"')"; expect_code 0; expect_no_out
run_stdin "$(payload_bash "$r" 'git add "b.txt" src && git commit -m x')"; expect_code 0
run_stdin "$(payload_bash "$r" 'git add .env && git commit -m x')"; expect_code 2; expect_out "[GS-02] .env"
run_stdin "$(payload_bash "$r" 'git add b.txt && git add .env && git commit -m x')"; expect_code 2; expect_out "[GS-02] .env"
for c in 'git add . && git commit -m x' 'git add -A && git commit -m x' 'git add -u && git commit -m x' 'git add && git commit -m x'; do
  run_stdin "$(payload_bash "$r" "$c")"; expect_code 2; expect_out "[GS-02] .env"
done
printf 'token = "%s"\n' "$GH_TOKEN" > "$r/src/b.py"; printf 'key = "%s"\n' "$AWS_KEY" >> "$r/app.py"
run_stdin "$(payload_bash "$r" 'git add src && git commit -m x')"; expect_code 2; expect_out "[GS-01] src/b.py"; expect_not "app.py"
run_stdin "$(payload_bash "$r" 'git add app.py && git commit -m x')"; expect_code 2; expect_out "[GS-01] app.py"; expect_not "src/b.py"

tc TC-S48 "-C · -c 값이 따옴표 문자열이어도 commit 으로 알아본다"
r="$TMP/sp ace"; git init -q -b work "$r"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"; git -C "$r" add c.py
run_stdin "$(payload_bash "$TMP" "git -C \"$r\" commit -m x")"; expect_code 2; expect_out "[GS-01] c.py"
run_stdin "$(payload_bash "$TMP" "git -C '$r' commit -m x")"; expect_code 2; expect_out "[GS-01] c.py"
run_stdin "$(payload_bash "$r" 'git -c user.name="A B" commit -m x')"; expect_code 2; expect_out "[GS-01] c.py"
run_stdin "$(payload_bash "$r" "git -c 'user.name=A B' status")"; expect_code 0; expect_no_out

tc TC-S35 "스테이징된 .env 는 막는다 (GS-02)"
r="$(repo)"; printf 'X=1\n' > "$r/.env"; git -C "$r" add .env
run_stdin "$(payload_bash "$r" 'git commit -m env')"; expect_code 2; expect_out "[GS-02] .env"

tc TC-S36 "git add -f 로 ignore 된 파일을 넣으면 막는다 (GS-02)"
r="$(repo)"; printf '.env\n' > "$r/.gitignore"; printf 'X=1\n' > "$r/.env"
run_stdin "$(payload_bash "$r" 'git add -f .env && git commit -m env')"; expect_code 2; expect_out "[GS-02] .env"
run_stdin "$(payload_bash "$r" 'git add . && git commit -m all')"; expect_code 0

tc TC-S37 "cd <저장소> && · git -C <저장소> 를 따라간다"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"; git -C "$r" add c.py
run_stdin "$(payload_bash "$TMP" "cd $r && git commit -m x")"; expect_code 2; expect_out "c.py"
run_stdin "$(payload_bash "$TMP" "git -C $r commit -m x")"; expect_code 2; expect_out "c.py"

tc TC-S38 "시크릿을 지우는 커밋은 통과한다 (추가된 줄만 본다)"
r="$(repo)"; printf 'key = "%s"  # gitleaks:allow\n' "$AWS_KEY" > "$r/c.py"; git -C "$r" add c.py && git -C "$r" commit -qm k
printf 'key = os.environ["KEY"]\n' > "$r/c.py"; git -C "$r" add c.py
run_stdin "$(payload_bash "$r" 'git commit -m rm')"; expect_code 0

tc TC-S39 "첫 커밋(HEAD 없음)도 본다"
r="$(mktemp -d "$TMP/r.XXXXXX")"; git -C "$r" init -q -b work
printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"; git -C "$r" add c.py
run_stdin "$(payload_bash "$r" 'git commit -m init')"; expect_code 2; expect_out "c.py"

tc TC-S40 "git push 는 원격에 없는 커밋의 시크릿을 막고, 푸시된 뒤에는 통과한다"
r="$(repo)"; git init -q --bare "$r.remote.git"; git -C "$r" remote add origin "$r.remote.git"; git -C "$r" push -q origin work 2>/dev/null
run_stdin "$(payload_bash "$r" 'git push')"; expect_code 0
printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"; git -C "$r" add c.py && git -C "$r" commit -qm k
run_stdin "$(payload_bash "$r" 'git push origin work')"; expect_code 2; expect_out "[GS-01] c.py"
git -C "$r" push -q origin work 2>/dev/null
run_stdin "$(payload_bash "$r" 'git push')"; expect_code 0

tc TC-S41 "git commit · push 가 아닌 명령은 보지 않는다"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"; git -C "$r" add c.py
for c in 'git status' 'git log --grep commit' 'git diff --cached' 'echo commit'; do
  run_stdin "$(payload_bash "$r" "$c")"; expect_code 0; expect_no_out
done

tc TC-S42 "git 저장소 밖 · 빈 입력 · PostToolUse 는 통과한다"
d="$TMP/plain2"; mkdir -p "$d"
run_stdin "$(payload_bash "$d" 'git commit -m x')"; expect_code 0; expect_no_out
run_stdin ""; expect_code 0; expect_no_out
r="$(repo)"; printf 'X=1\n' > "$r/.env"; git -C "$r" add .env
run_stdin "$(payload_bash "$r" 'git commit -m x' | jq '.hook_event_name = "PostToolUse"')"; expect_code 0; expect_no_out

tc TC-S43 "git 과 commit 사이의 전역 옵션(--no-pager · -c)이 있어도 -a 를 본다"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" >> "$r/app.py"
for c in 'git --no-pager commit -am x' 'git -c core.pager=cat commit -am x' 'git --no-pager -C . commit --all -m x'; do
  run_stdin "$(payload_bash "$r" "$c")"; expect_code 2; expect_out "[GS-01] app.py"
done

tc TC-S44 "git 이 없는 Bash 명령은 jq · 임시 디렉터리 전에 끝난다"
OUT="$(payload_bash "$TMP" 'ls -la && make build' | TMPDIR=/nonexistent "$SCRIPT" 2>&1)"; CODE=$?; expect_code 0; expect_no_out
# 대조 — git 명령은 임시 디렉터리를 만들려다 실패한다
OUT="$(payload_bash "$TMP" 'git commit -m x' | TMPDIR=/nonexistent "$SCRIPT" 2>&1)"; CODE=$?; expect_code 1

# --- C. 훅 — Write · Edit ---------------------------------------------------
tc TC-S50 "ignore 안 된 파일에 시크릿을 쓰면 경고하고 통과한다 (GS-03)"
r="$(repo)"; run_stdin "$(payload_write "$r/config.py" "key = \"$AWS_KEY\"\n")"
expect_code 0; expect_out "additionalContext"; expect_out "[GS-03] config.py"; expect_not "$AWS_KEY"

tc TC-S51 "ignore 된 .env 에 시크릿을 쓰면 조용히 통과한다 (과잉 경고 방지)"
r="$(repo)"; printf '.env\n' > "$r/.gitignore"
run_stdin "$(payload_write "$r/.env" "GITHUB_TOKEN=$GH_TOKEN\n")"; expect_code 0; expect_no_out

tc TC-S52 "ignore 안 된 .env 를 만들면 경고한다 (GS-04)"
r="$(repo)"; run_stdin "$(payload_write "$r/.env" 'DEBUG=1\n')"; expect_code 0; expect_out "[GS-04] .env"

tc TC-S53 "추적되는 민감 파일은 ignore 에 있어도 경고한다 (GS-04)"
r="$(repo)"; printf 'X=1\n' > "$r/.env"; git -C "$r" add .env; printf '.env\n' > "$r/.gitignore"
run_stdin "$(payload_edit "$r/.env" 'X=1' 'X=2')"; expect_code 0; expect_out "[GS-04] .env"; expect_out "추적"

tc TC-S54 "기존 시크릿이 있는 파일의 다른 줄을 고치면 경고하지 않는다 (새로 생긴 것만)"
r="$(repo)"; printf 'key = "%s"\nx = 1\n' "$AWS_KEY" > "$r/c.py"
run_stdin "$(payload_edit "$r/c.py" 'x = 1' 'x = 2')"; expect_code 0; expect_no_out

tc TC-S55 "Edit 가 시크릿을 더하면 경고한다"
r="$(repo)"; printf 'x = 1\n' > "$r/c.py"
run_stdin "$(payload_edit "$r/c.py" 'x = 1' "x = 1\ntoken = \"$GH_TOKEN\"")"; expect_code 0; expect_out "[GS-03] c.py"

tc TC-S56 "아직 없는 하위 디렉터리 · 심볼릭 링크 경로도 저장소 안으로 본다"
r="$(repo)"; ln -s "$r" "$r.link"
run_stdin "$(payload_write "$r.link/deep/new/k.py" "key = \"$AWS_KEY\"\n")"; expect_code 0; expect_out "[GS-03] deep/new/k.py"

tc TC-S57 "저장소 밖 · .git 안 · .git-secret-allow 경로는 보지 않는다"
d="$TMP/plain3"; mkdir -p "$d"; run_stdin "$(payload_write "$d/k.py" "key = \"$AWS_KEY\"\n")"; expect_code 0; expect_no_out
r="$(repo)"; run_stdin "$(payload_write "$r/.git/x" "key = \"$AWS_KEY\"\n")"; expect_code 0; expect_no_out
printf 'fixtures\n' > "$r/.git-secret-allow"; run_stdin "$(payload_write "$r/fixtures/k.py" "key = \"$AWS_KEY\"\n")"; expect_code 0; expect_no_out

# --- D. 엔진 ------------------------------------------------------------------
tc TC-S70 "내장 엔진이면 GS-05 를 알린다"
r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"; run --all "$r"; expect_out "GS-05"

tc TC-S71 "GIT_SECRET_ENGINE 이 잘못되면 실행 오류다"
OUT="$(GIT_SECRET_ENGINE=nope "$SCRIPT" --all "$TMP" 2>&1)"; CODE=$?; expect_code 1; expect_out "GIT_SECRET_ENGINE"

tc TC-S76 "gitleaks 가 실패하면 내장 패턴으로 보고 알린다"
r="$(repo)"; printf 'token = "%s"\n' "$GH_TOKEN" > "$r/c.py"; git -C "$r" add c.py
if [ "$TC_ON" = 1 ]; then mkdir -p "$TMP/fakebin"; printf '#!/bin/sh\nexit 3\n' > "$TMP/fakebin/gitleaks"; chmod +x "$TMP/fakebin/gitleaks"; fi
OUT="$(payload_bash "$r" 'git commit -m x' | PATH="$TMP/fakebin:$PATH" GIT_SECRET_ENGINE=gitleaks "$SCRIPT" 2>&1)"; CODE=$?
expect_code 2; expect_out "[GS-01] c.py"; expect_out "gitleaks 실행에 실패해"

if command -v gitleaks >/dev/null 2>&1; then
  tc TC-S72 "gitleaks 엔진도 같은 경로 · 가린 값으로 보고한다"
  r="$(repo)"; printf 'key = "%s"\n' "$AWS_KEY" > "$r/c.py"
  OUT="$(GIT_SECRET_ENGINE=gitleaks "$SCRIPT" --all "$r" 2>&1)"; CODE=$?
  expect_code 2; expect_out "[GS-01] c.py — aws-access-token: AKIA…"; expect_not "GS-05"

  tc TC-S73 "gitleaks 엔진으로 커밋을 막고 gitleaks:allow 를 따른다"
  r="$(repo)"; printf 'token = "%s"\n' "$GH_TOKEN" > "$r/c.py"; git -C "$r" add c.py
  OUT="$(payload_bash "$r" 'git commit -m x' | GIT_SECRET_ENGINE=gitleaks "$SCRIPT" 2>&1)"; CODE=$?; expect_code 2; expect_out "[GS-01] c.py"
  printf 'token = "%s"  # gitleaks:allow\n' "$GH_TOKEN" > "$r/c.py"; git -C "$r" add c.py
  OUT="$(payload_bash "$r" 'git commit -m x' | GIT_SECRET_ENGINE=gitleaks "$SCRIPT" 2>&1)"; CODE=$?; expect_code 0

  tc TC-S74 "gitleaks 엔진도 편집 전후를 비교한다"
  r="$(repo)"; printf 'key = "%s"\nx = 1\n' "$AWS_KEY" > "$r/c.py"
  OUT="$(payload_edit "$r/c.py" 'x = 1' 'x = 2' | GIT_SECRET_ENGINE=gitleaks "$SCRIPT" 2>&1)"; CODE=$?; expect_code 0; expect_no_out

  tc TC-S75 "gitleaks 엔진은 여러 줄 개인 키의 본문을 출력하지 않는다"
  r="$(repo)"
  if [ "$TC_ON" = 1 ]; then
    ssh-keygen -q -t ed25519 -N '' -C tc -f "$TMP/tc-key" >/dev/null 2>&1
    cp "$TMP/tc-key" "$r/deploy_key.txt"; body="$(sed -n 2p "$TMP/tc-key")"; rm -f "$TMP/tc-key" "$TMP/tc-key.pub"
  fi
  OUT="$(GIT_SECRET_ENGINE=gitleaks "$SCRIPT" --all "$r" 2>&1)"; CODE=$?
  expect_code 2; expect_out "[GS-01] deploy_key.txt — private-key: ----…"; expect_not "${body:0:12}"
  [ "$TC_ON" = 1 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^  - \[GS-01\]')" != 1 ] && fail_tc "키 하나가 GS-01 한 줄이 아니다"
else
  echo "  SKIP      TC-S72 ~ TC-S75 — gitleaks 가 없다"
fi

flush_tc
echo "결과: $PASS 통과, $FAIL 실패, $SKIP 건너뜀"
[ "$FAIL" = 0 ]
