#!/usr/bin/env bash
# plugin-browser.sh 회귀 테스트. 사용: test/plugin-browser.test.sh [TC 접두사]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
B="$PLUGIN/scripts/plugin-browser.sh"
ENGINE="$PLUGIN/../plugin-search-install/scripts/plugin-search-install.sh"
FILTER="${1:-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0 SKIP=0

tc() { # $1=ID $2=설명 $3...=명령 (0 이면 통과)
  local id="$1" desc="$2"; shift 2
  case "$id" in "$FILTER"*) ;; *) return ;; esac
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %-7s %s\n' "$id" "$desc"
  else FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %-7s %s\n' "$id" "$desc"; fi
}
skip() { case "$1" in "$FILTER"*) SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %-7s %s\n' "$1" "$2" ;; esac; }
out_has() { local p="$1" out; shift; out="$("$@" 2>&1)"; grep -Fq -- "$p" <<<"$out"; }
out_lacks() { local p="$1" out; shift; out="$("$@" 2>&1)"; ! grep -Fq -- "$p" <<<"$out"; }
exit_is() { local want="$1"; shift; "$@" >/dev/null 2>&1; [ $? -eq "$want" ]; }

command -v perl >/dev/null 2>&1 || { echo "perl 이 필요합니다 (표시 폭 측정)"; exit 1; }
# 표시 폭을 스크립트와 따로 잰다 — 같은 표를 쓰면 같은 실수를 놓친다
maxw() { # $1=모호 폭 → stdin 의 가장 넓은 줄
  perl -CS -Mutf8 -e '
    my $amb = shift; my $max = 0;
    while (my $l = <STDIN>) { chomp $l; $l =~ s/\e\[[0-9;?]*[A-Za-z]//g; my $w = 0;
      my $prev = 0;
      for my $c (split //, $l) {
        if ($c eq "\x{FE0F}") { $w += 1 if $prev == 1; $prev = 0; next }   # 터미널은 VS16 이 붙은 글자를 이모지(두 칸)로 그린다
        if ($c =~ /[\p{Mn}\p{Me}\x{200B}-\x{200D}\x{2060}\x{FEFF}\x{FE00}-\x{FE0E}]/) { $prev = 0; }
        elsif ($c =~ /\p{East_Asian_Width=Wide}|\p{East_Asian_Width=Fullwidth}/) { $w += 2; $prev = 2 }
        elsif ($c =~ /\p{East_Asian_Width=Ambiguous}/) { $w += $amb; $prev = $amb }
        else { $w += 1; $prev = 1 } }
      $max = $w if $w > $max }
    print "$max\n"' "$1"
}

# ---- 픽스처 카탈로그 --------------------------------------------------------
mk() { # $1=이름 $2=마켓 $3=설명 $4=설치 $5=태그(쉼표) $6=의존(쉼표)
  jq -cn --arg n "$1" --arg m "$2" --arg d "$3" --argjson i "$4" --arg t "$5" --arg dep "$6" '
    {id: ($n + "@" + $m), name: $n, marketplace: $m, description: $d, version: "1.0.0", category: null,
     tags: ($t | split(",") | map(select(length > 0))), keywords: ["naming"], author: "작성자", homepage: null, sourceType: "path",
     dependencies: ($dep | split(",") | map(select(length > 0))), installed: $i, enabled: (if $i then true else null end),
     scopes: (if $i then ["user"] else [] end), installedVersion: null, installedElsewhere: [], installCount: null, componentsKnown: true,
     components: {skills: [{name: "name-create", description: "이름을 지을 때 사용한다 — 아주 긴 설명이 붙어서 줄을 넘길 수 있는 경우를 본다"}],
                  commands: [], agents: [], hooks: ["PreToolUse"], mcp: [], lsp: []}, path: null}'
}
{
  mk very-long-plugin-name-for-testing-truncation-behaviour-naming a-really-long-marketplace-name \
     "아주 긴 한글 설명 · 모호 폭 가운뎃점 — 줄표 🚀 이모지 ✅ 변형 ☺️ ☺️ ☺️ 그리고 English words mixed together to overflow every column naming" false development,spring ""
  mk 한글이름-naming m "전각 ＡＢＣ 결합 문자 é 와 한자 漢字 naming" true development ""
  mk ctrl-naming m "$(printf 'bad\033[31mred\007bell naming')" false "" ""
  mk dep-a-naming m "의존 대상 naming" false "" ""
  mk dep-b-naming m "dep-a 에 기댄다 naming" true "" dep-a-naming
  for i in $(seq 1 25); do mk "filler-$i-naming" m "채움 항목 $i naming" false "" ""; done
} | jq -s . > "$WORK/cat.json"
export PLUGIN_SEARCH_CATALOG="$WORK/cat.json" PLUGIN_SEARCH_INSTALL="$ENGINE" PLUGIN_SEARCH_CACHE_DIR="$WORK/cache" PLUGIN_BROWSER_AMBIGUOUS=1
unset NO_COLOR

PRJ="$WORK/proj"; mkdir -p "$PRJ/.claude" "$PRJ/src"
echo '{"enabledPlugins":{"dep-b-naming@m":true,"ghost@nowhere":true}}' > "$PRJ/.claude/settings.json"
echo 'class A {}' > "$PRJ/src/A.java"

"$ENGINE" search naming --limit 0 --format json > "$WORK/search.json"
"$ENGINE" install --from "$WORK/search.json" --select 1-3 --dry-run --format json > "$WORK/install.json"

WIDTHS="10 11 12 13 20 24 30 39 40 50 69 70 80 99 100 119 120 160 200"
fits() { # $1=모호 폭 $2...=명령 (폭 자리는 @W@) — 모든 폭에서 줄 ≤ 폭 − 1
  local amb="$1"; shift
  local w a out m
  for w in $WIDTHS; do
    a=(); for x in "$@"; do a+=("${x//@W@/$w}"); done
    out="$(PLUGIN_BROWSER_AMBIGUOUS=$amb "${a[@]}" 2>&1)" || return 1
    m="$(printf '%s\n' "$out" | maxw "$amb")"
    [ "$m" -le $((w - 1)) ] || { echo "폭 $w 에서 $m" >&2; return 1; }
  done
}

echo "== 폭: 어떤 줄도 터미널 폭을 넘지 않는다 (한글 · 이모지 · 전각 · 결합 문자 · 모호 폭)"
for amb in 1 2; do
  tc "TC-W0${amb}1" "검색 결과 (모호 폭 $amb)" fits $amb "$B" search naming --limit 0 --width @W@
  tc "TC-W0${amb}2" "프로젝트 (모호 폭 $amb)" fits $amb "$B" project "$PRJ" --width @W@
  tc "TC-W0${amb}3" "연관 (모호 폭 $amb)" fits $amb "$B" related dep-a-naming --width @W@
  tc "TC-W0${amb}4" "상세 (모호 폭 $amb)" fits $amb "$B" show very-long-plugin-name-for-testing-truncation-behaviour-naming --width @W@
  tc "TC-W0${amb}5" "관점별 개수 (모호 폭 $amb)" fits $amb "$B" facets --width @W@
  tc "TC-W0${amb}6" "설치 결과 (모호 폭 $amb)" fits $amb "$B" render "$WORK/install.json" --width @W@
  tc "TC-W0${amb}7" "색을 켜도 (모호 폭 $amb)" fits $amb "$B" search naming --width @W@ --color always
  tc "TC-W0${amb}8" "ASCII 장식 (모호 폭 $amb)" fits $amb "$B" project "$PRJ" --width @W@ --ascii
done

echo "== 레이아웃"
tc TC-L01 "100 이상은 머리글 있는 표" out_has "마켓" "$B" search naming --width 100
tc TC-L02 "120 이상은 이유 열" out_has "이유" "$B" search naming --width 120
tc TC-L03 "70 ~ 99 는 머리글 없는 한 줄" out_lacks "마켓" "$B" search naming --width 80
tc TC-L04 "40 ~ 69 는 카드 — 마켓 · 태그 줄" out_has "a-really-long-marketplace-name · development,spring" "$B" search very-long --width 69
tc TC-L05 "40 미만은 목록 — 마켓 줄 없음" out_lacks "a-really-long" "$B" search very-long --width 39
tc TC-L06 "긴 이름은 말줄임" out_has "⋯" "$B" search very-long --width 80
tc TC-L07 "프로젝트는 필수 · 추천 묶음 머리글" out_has "▸ 필수 · 프로젝트 설정에 선언" "$B" project "$PRJ" --width 80
tc TC-L08 "선언됐는데 없는 플러그인은 ! 표시" bash -c '"$0" project "$1" --width 80 | grep -q "^ *[0-9]* ! ghost"' "$B" "$PRJ"
tc TC-L09 "설치된 것은 ✓" bash -c '"$0" search naming --limit 0 --width 80 | grep -q "✓ 한글이름-naming"' "$B"
tc TC-L10 "결과가 없으면 그렇게 말한다" out_has "결과가 없습니다" "$B" search zzzzqqq --exact --width 80
tc TC-L12 "깨진 설정 파일을 알린다" bash -c 'mkdir -p "$2/.claude" && cp "$1/.claude/settings.json" "$2/.claude/" && echo "{x" > "$2/.claude/settings.local.json" && "$0" project "$2" --width 100 | grep -q "설정 파일을 읽지 못했습니다"' "$B" "$PRJ" "$WORK/broken proj"
tc TC-L11 "비대화형이면 설치 방법을 안내한다" out_has "--select" "$B" search naming --width 80

echo "== 장식 · 색 · 안전"
tc TC-A01 "--ascii 는 ✓ ⋯ ─ ▸ 를 쓰지 않는다" bash -c '! "$0" project "$1" --width 60 --ascii | grep -q "[✓⋯─▸❯]"' "$B" "$PRJ"
tc TC-A02 "UTF-8 이 아닌 로케일은 ASCII" bash -c '! LC_ALL=C "$0" search naming --width 60 | grep -q "[✓⋯─]"' "$B"
tc TC-A03 "파이프로 받으면 색이 없다" bash -c '! "$0" search naming --width 80 | grep -q $'"'"'\033'"'"'' "$B"
tc TC-A04 "--color always 는 색" bash -c '"$0" search naming --width 80 --color always | grep -q $'"'"'\033\\[1m'"'"'' "$B"
tc TC-A05 "설명의 ESC · BEL 은 출력되지 않는다" bash -c '! "$0" search ctrl --width 120 | grep -q $'"'"'[\033\007]'"'"'' "$B"
tc TC-A06 "모호 폭 2 면 구분자를 ASCII 로" bash -c 'PLUGIN_BROWSER_AMBIGUOUS=2 "$0" search very-long --width 60 | grep -q " | "' "$B"

echo "== 엔진 · 입력"
tc TC-E01 "엔진 경로가 실행 파일이 아니면 2" exit_is 2 env PLUGIN_SEARCH_INSTALL=/nonexistent "$B" search naming
tc TC-E02 "엔진 오류(모르는 옵션)는 메시지와 2" out_has "모르는 옵션" "$B" search naming --bogus
tc TC-E03 "모르는 명령은 2" exit_is 2 "$B" bogus
tc TC-E04 "--width 가 숫자가 아니면 2" exit_is 2 "$B" search naming --width wide
tc TC-E08 "--width 10 미만은 넘치므로 받지 않는다" exit_is 2 "$B" search naming --width 9
tc TC-E05 "render 는 stdin JSON 을 그린다" bash -c '"$0" render - --width 80 < "$1" | grep -q "naming"' "$B" "$WORK/search.json"
tc TC-E06 "엔진 필터를 그대로 넘긴다 (--installed)" bash -c '[ "$("$0" search naming --installed --width 80 | grep -c "✓")" -eq 2 ]' "$B"
tc TC-E07 "형제 디렉터리의 엔진을 찾는다" bash -c 'unset PLUGIN_SEARCH_INSTALL; "$0" search naming --width 80 | grep -q naming' "$B"

echo "== 비대화형 설치"
tc TC-N01 "--select 는 묻지 않고 넘긴다" bash -c '"$0" search naming --select 2 --dry-run --width 100 | grep -q "예정"' "$B"
tc TC-N02 "--install-all --dry-run 은 전부 예정" bash -c '[ "$("$0" search naming --limit 5 --install-all --dry-run --width 100 | grep -cE "예정|건너뜀")" -eq 5 ]' "$B"
tc TC-N03 "목록에 없는 번호는 2" exit_is 2 "$B" search naming --select 99 --dry-run

echo "== 대화형 (pty)"
pty() { # $1=크기 "행 열" $2=입력(초 간격 키) $3...=명령 → 화면 출력(제어 코드 제거)
  local size="$1" keys="$2"; shift 2
  local cmd; cmd="stty rows ${size% *} cols ${size#* }; $(printf '%q ' "$@")"
  { sleep 1.5; local k; for k in $keys; do printf '%b' "$k"; sleep 0.4; done; sleep 2; } \
    | if script -q /dev/null true </dev/null >/dev/null 2>&1; then script -q "$WORK/pty.out" bash -c "$cmd"
      else script -qec "$cmd" "$WORK/pty.out"; fi >/dev/null 2>&1 &
  # 키에 반응하지 않고 멈춘 화면이 테스트 전체를 붙잡지 않게
  local pid=$! wd
  ( sleep 40; kill -9 "$pid" 2>/dev/null ) & wd=$!
  wait "$pid" 2>/dev/null; kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  sed -e $'s/\033\\[[0-9;?]*[A-Za-z]//g' "$WORK/pty.out" | tr '\r' '\n'
}
export -f pty; export WORK
if script -q /dev/null true </dev/null >/dev/null 2>&1 || script -qec true /dev/null >/dev/null 2>&1; then
  tc TC-P01 "↓ · Space 두 번 → Enter → 범위 Enter 로 고른 둘만 넘긴다" bash -c 'o="$(pty "24 100" "j \\x20 j \\x20 \\r \\r" "$0" search naming --dry-run)"; grep -q "dep-a-naming@m.*예정" <<<"$o" && grep -q "dep-b-naming@m.*건너뜀" <<<"$o" && ! grep -q "ctrl-naming@m.*예정" <<<"$o"' "$B"
  tc TC-P02 "q 는 취소 — 아무것도 설치하지 않는다" bash -c 'o="$(pty "24 100" "q" "$0" search naming --dry-run)"; grep -q "취소했습니다" <<<"$o" && ! grep -q "예정" <<<"$o"' "$B"
  tc TC-P03 "a 는 전부 고른다" bash -c 'o="$(pty "24 100" "a \\r \\r" "$0" search naming --limit 4 --dry-run)"; [ "$(grep -cE "(예정|건너뜀) " <<<"$o")" -eq 4 ]' "$B"
  tc TC-P04 "작은 창(행 < 8)은 번호 입력 모드" bash -c 'o="$(pty "6 60" "2 \\r \\r" "$0" search naming --limit 4 --dry-run)"; grep -q "설치할 번호" <<<"$o" && grep -q "예정" <<<"$o"' "$B"
  tc TC-P05 "프로젝트 조회는 필수 중 없는 것을 미리 고른다" bash -c 'o="$(pty "24 100" "\\r \\r" "$0" project "$1" --dry-run)"; grep -q "dep-a-naming@m.*예정" <<<"$o"' "$B" "$PRJ"
  tc TC-P06 "범위 u 는 user 로 넘긴다" bash -c 'o="$(pty "24 100" "\\x20 \\r u\\r" "$0" search naming --limit 2 --dry-run)"; grep -q "범위 user" <<<"$o"' "$B"
  tc TC-P07 "번호 모드에 글자를 넣으면 다시 묻는다" bash -c 'o="$(pty "24 100" "abc\\r \\r" "$0" search naming --plain --limit 3 --dry-run)"; grep -q "번호 · 쉼표 · 하이픈만" <<<"$o"' "$B"
  tc TC-P08 "끝나면 커서와 화면을 되돌린다" bash -c 'pty "24 100" "q" "$0" search naming >/dev/null; grep -q $'"'"'\033\\[?1049l'"'"' "$1" && grep -q $'"'"'\033\\[?25h'"'"' "$1"' "$B" "$WORK/pty.out"
  tc TC-P09 "메뉴 → 기능 검색 → 고르고 설치 → 메뉴로 돌아와 끝낸다" bash -c 'o="$(pty "24 100" "2\\r dep-a\\r \\x20 \\r \\r q\\r" "$0" --dry-run)"; grep -q "플러그인 찾기" <<<"$o" && grep -q "dep-a-naming@m.*예정" <<<"$o" && [ "$(grep -c "플러그인 찾기" <<<"$o")" -ge 2 ]' "$B"
  tc TC-P10 "번호 모드의 공백은 구분자 — 1 3 은 13 이 아니라 1 과 3" bash -c 'o="$(pty "24 100" "1\\x203\\r \\r" "$0" search naming --plain --limit 0 --dry-run)"; [ "$(grep -cE "(예정|건너뜀) " <<<"$o")" -eq 2 ] && grep -q "ctrl-naming@m.*예정" <<<"$o"' "$B"
  tc TC-P11 "번호 모드에 구분자만 넣으면 다시 묻는다 — 전체를 보이지 않는다" bash -c 'o="$(pty "24 100" ",\\r \\r" "$0" search naming --plain --dry-run)"; grep -q "번호를 하나 이상" <<<"$o" && ! grep -q "설치할 플러그인" <<<"$o"' "$B"
  tc TC-P12 "선택 화면에서 Ctrl-D 는 취소" bash -c 'o="$(pty "24 100" "\\x04" "$0" search naming --dry-run)"; grep -q "취소했습니다" <<<"$o"' "$B"
  rules() { sed -e $'s/\033\\[[0-9;?]*[A-Za-z]//g' "$1" | tr '\r' '\n' | perl -CS -ne 'chomp; s/\s+$//; print length($_), "\n" if /^\x{2500}+$/' | sort -u | tr '\n' ' '; }
  export -f rules
  tc TC-P13 "선택 화면 도중 창을 100 → 50 열로 줄이면 50 열에 맞춰 다시 그린다" bash -c 'pty "24 100" "x x x x x x x q" bash -c "(trap \"\" TTOU; sleep 2.5; stty cols 50 </dev/tty) & exec \"\$0\" search naming" "$0" >/dev/null; r="$(rules "$1")"; case " $r" in *" 99 "*) ;; *) exit 1 ;; esac; case " $r" in *" 49 "*) ;; *) exit 1 ;; esac' "$B" "$WORK/pty.out"
else
  for t in TC-P13 TC-P12 TC-P11 TC-P10 TC-P09 TC-P01 TC-P02 TC-P03 TC-P04 TC-P05 TC-P06 TC-P07 TC-P08; do skip "$t" "pty 를 만들 수 없다 (script 없음)"; done
fi

echo
echo "통과 $PASS / 실패 $FAIL / 건너뜀 $SKIP"
[ "$FAIL" -eq 0 ]
