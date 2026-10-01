#!/usr/bin/env bash
# plugin-search-install.sh 회귀 테스트. 사용: test/plugin-search-install.test.sh [TC 접두사]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
S="$PLUGIN/scripts/plugin-search-install.sh"
FILTER="${1:-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0

tc() { # $1=ID $2=설명 $3...=명령 (0 이면 통과)
  local id="$1" desc="$2"; shift 2
  case "$id" in "$FILTER"*) ;; *) return ;; esac
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %-7s %s\n' "$id" "$desc"
  else FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %-7s %s\n' "$id" "$desc"; fi
}
put() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
out_has() { local p="$1" out; shift; out="$("$@" 2>&1)"; grep -Fq -- "$p" <<<"$out"; }
out_lacks() { local p="$1" out; shift; out="$("$@" 2>&1)"; ! grep -Fq -- "$p" <<<"$out"; }
exit_is() { local want="$1"; shift; "$@" >/dev/null 2>&1; [ $? -eq "$want" ]; }
first_is() { local want="$1" got; shift; got="$("$@" 2>/dev/null | head -1)"; [ "$got" = "$want" ]; }
jqe() { local f="$1"; shift; { "$@" 2>/dev/null || true; } | jq -e "$f"; }   # 명령의 종료 코드가 아니라 출력을 본다

# ---- 픽스처: 스텁 claude 와 마켓플레이스 셋 --------------------------------
STUB="$WORK/stub"; mkdir -p "$STUB"
put "$WORK/bin/claude" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "plugin marketplace list --json") cat "$STUB_DIR/mps.json" ;;
  "plugin list --json --available") cat "$STUB_DIR/inst.json" ;;
  "plugin install "*)
    echo "$*" >> "$STUB_DIR/calls"
    if grep -qxF "$3" "$STUB_DIR/fail" 2>/dev/null; then echo '{"error":"설치 실패 (스텁)"}'; exit 1; fi
    echo '{"ok":true}' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/claude"
export STUB_DIR="$STUB" PLUGIN_SEARCH_CLAUDE="$WORK/bin/claude" PLUGIN_SEARCH_CACHE_DIR="$WORK/cache" CLAUDE_CONFIG_DIR="$WORK/cfg"
unset PLUGIN_SEARCH_CATALOG

MK="$WORK/mk"
put "$MK/.claude-plugin/marketplace.json" <<'EOF'
{ "name": "mk", "plugins": [
  { "name": "alpha-naming", "source": "./plugins/alpha-naming", "category": "public", "tags": ["development"], "keywords": ["naming", "convention"],
    "description": "코드 이름 규칙을 강제한다" },
  { "name": "beta-coverage", "source": "./plugins/beta-coverage", "tags": ["development"], "keywords": ["coverage", "test"],
    "description": "Java · Spring 테스트 커버리지 게이트" },
  { "name": "gamma-workflow", "source": "./plugins/gamma-workflow", "tags": ["github"], "description": "이슈에서 머지까지 GitHub 플로우" },
  { "name": "kotlin-spring-naming", "source": "./plugins/kotlin-spring-naming", "tags": ["spring"], "description": "Kotlin Spring 이름 규칙" },
  { "name": "java-spring-test", "source": "./plugins/java-spring-test", "tags": ["spring"], "description": "Java Spring testcontainers 테스트 생성" },
  { "name": "delta-mcp", "source": "./plugins/delta-mcp", "description": "데이터 조회 서버" },
  { "name": "evil", "source": "./plugins/evil", "description": "bad\u001b[31m red\u0007" },
  { "name": "remote-only", "source": { "source": "github", "repo": "x/y" }, "description": "원격 소스", "keywords": ["remote"] }
] }
EOF
put "$MK/plugins/alpha-naming/.claude-plugin/plugin.json" <<<'{"name":"alpha-naming","version":"1.2.0","keywords":["glossary"]}'
put "$MK/plugins/alpha-naming/skills/name-create/SKILL.md" <<'EOF'
---
name: name-create
description: 이름을 지을 때 사용한다. 사전으로 검증한다.
---
EOF
put "$MK/plugins/alpha-naming/commands/naming-review.md" <<<$'---\ndescription: 이름 검토\n---'
put "$MK/plugins/alpha-naming/hooks/hooks.json" <<<'{"hooks":{"PreToolUse":[],"PostToolUse":[]}}'
put "$MK/plugins/beta-coverage/.claude-plugin/plugin.json" <<<'{"name":"beta-coverage","version":"0.3.0","dependencies":["alpha-naming"]}'
put "$MK/plugins/beta-coverage/agents/coverage-reviewer.md" <<'EOF'
---
name: coverage-reviewer
description: >
  변경된 메서드의 커버리지를
  검토한다
---
EOF
put "$MK/plugins/gamma-workflow/.claude-plugin/plugin.json" <<<'{"name":"gamma-workflow","version":"0.1.0","dependencies":[{"name":"beta-coverage","version":"~0.3.0"}]}'
put "$MK/plugins/gamma-workflow/skills/issue-create/SKILL.md" <<<$'---\nname: issue-create\ndescription: "GitHub 이슈를 만들 때 사용한다"\n---'
put "$MK/plugins/kotlin-spring-naming/.claude-plugin/plugin.json" <<<'{"name":"kotlin-spring-naming"}'
put "$MK/plugins/java-spring-test/.claude-plugin/plugin.json" <<<'{"name":"java-spring-test"}'
put "$MK/plugins/delta-mcp/.claude-plugin/plugin.json" <<<'{"name":"delta-mcp"'
put "$MK/plugins/delta-mcp/.mcp.json" <<<'{"mcpServers":{"deltadb":{"command":"x"}}}'
put "$MK/plugins/evil/.claude-plugin/plugin.json" <<<'{"name":"evil"}'

OT="$WORK/other"
put "$OT/.claude-plugin/marketplace.json" <<<'{"name":"other","metadata":{"pluginRoot":"./plugins"},"plugins":[{"name":"alpha-naming","source":"alpha","description":"다른 마켓의 같은 이름"}]}'
put "$OT/plugins/alpha/skills/other-skill/SKILL.md" <<<$'---\nname: other-skill\ndescription: 다른 스킬\n---'

jq -n --arg mk "$MK" --arg ot "$OT" '[{name: "mk", installLocation: $mk}, {name: "other", installLocation: $ot}, {name: "gone", installLocation: "/nonexistent"}]' > "$STUB/mps.json"
jq -n --arg p "$MK/plugins/alpha-naming" '{installed: [{id: "alpha-naming@mk", version: "1.2.0", scope: "user", enabled: true, installPath: $p},
    {id: "gamma-workflow@mk", version: "0.1.0", scope: "project", enabled: false, projectPath: "/elsewhere/project"}],
  available: [{pluginId: "beta-coverage@mk", installCount: 50}, {pluginId: "gamma-workflow@mk", installCount: 5}]}' > "$STUB/inst.json"

run() { "$S" "$@"; }
cat_json() { run catalog --refresh; }
rec() { cat_json | jq -e --arg id "$1" ".[] | select(.id == \$id) | $2"; }

echo "== catalog"
tc TC-C01 "마켓플레이스 둘의 엔트리를 모두 읽는다 (없는 위치는 건너뜀)" jqe 'length == 9' cat_json
tc TC-C02 "스킬 · 커맨드 · 훅 이벤트를 읽는다" rec alpha-naming@mk '.components.skills[0].name == "name-create" and (.components.commands | length) == 1 and .components.hooks == ["PostToolUse", "PreToolUse"]'
tc TC-C03 "여러 줄 description (>) 을 한 줄로 읽는다" rec beta-coverage@mk '.components.agents[0].description == "변경된 메서드의 커버리지를 검토한다"'
tc TC-C04 "plugin.json 의 dependencies (문자열 · 객체) 를 이름으로" rec gamma-workflow@mk '.dependencies == ["beta-coverage"]'
tc TC-C05 "설치 상태 · 범위 · 설치 수" rec alpha-naming@mk '.installed and .enabled and .scopes == ["user"]'
tc TC-C06 "installCount 를 붙인다" rec beta-coverage@mk '.installCount == 50 and (.installed | not)'
tc TC-C07 "깨진 plugin.json 이 있어도 .mcp.json 은 읽는다" rec delta-mcp@mk '.components.mcp == ["deltadb"]'
tc TC-C08 "설명의 제어 문자(ESC · BEL)를 지운다" rec evil@mk '(.description | test("[\u0001-\u001f]") | not)'
tc TC-C09 "metadata.pluginRoot 를 상대 source 앞에 붙인다" rec alpha-naming@other '.components.skills[0].name == "other-skill"'
tc TC-C10 "원격 source 는 구성요소 모름으로 표시" rec remote-only@mk '.componentsKnown == false and .sourceType == "github"'
tc TC-C15 "다른 프로젝트의 project 범위 설치는 여기서 설치 안 됨" rec gamma-workflow@mk '(.installed | not) and .installedElsewhere == ["/elsewhere/project"]'
tc TC-C11 "plugin.json keywords 를 엔트리 keywords 와 합친다" rec alpha-naming@mk '.keywords == ["convention", "glossary", "naming"]'
fallback_cat() { PLUGIN_SEARCH_CLAUDE=/nonexistent run catalog --refresh; }
mkdir -p "$WORK/cfg/plugins"
jq -n --arg mk "$MK" '{mk: {installLocation: $mk}}' > "$WORK/cfg/plugins/known_marketplaces.json"
jq -n '{plugins: {"beta-coverage@mk": [{scope: "project", version: "0.3.0"}]}}' > "$WORK/cfg/plugins/installed_plugins.json"
tc TC-C12 "claude CLI 가 없으면 설정 디렉터리의 기록 파일로 읽는다" jqe '(length == 8) and (.[] | select(.id == "beta-coverage@mk") | .installed)' fallback_cat
cached() { run catalog --refresh >/dev/null; mv "$MK/plugins/evil" "$WORK/evil.bak"; run catalog | jq -e '.[] | select(.id == "evil@mk") | .componentsKnown'; local r=$?; mv "$WORK/evil.bak" "$MK/plugins/evil"; return $r; }
tc TC-C13 "지문이 같으면 캐시를 쓴다" cached
tc TC-C14 "PLUGIN_SEARCH_CATALOG 로 카탈로그를 주입한다" jqe 'length == 1' env PLUGIN_SEARCH_CATALOG=<(echo '[{"id":"x@y"}]') "$S" catalog

# 이후는 고정 카탈로그로 — 빠르고 결정적이다
run catalog --refresh > "$WORK/cat.json"
export PLUGIN_SEARCH_CATALOG="$WORK/cat.json"
ids() { run "$@" --format ids; }

echo "== search"
tc TC-Q01 "이름 단어 일치가 맨 위" first_is alpha-naming@mk ids search naming --mp mk
tc TC-Q02 "한글 동의어 (네이밍 → naming)" out_has alpha-naming@mk ids search 네이밍
tc TC-Q03 "한글 조사를 떼고 찾는다 (커버리지를)" first_is beta-coverage@mk ids search 커버리지를
tc TC-Q04 "오타 허용 (covrage → coverage)" first_is beta-coverage@mk ids search covrage
tc TC-Q05 "--exact 는 오타 · 동의어를 끈다" exit_is 0 test -z "$(ids search covrage --exact)"
tc TC-Q06 "-단어 는 제외한다" out_lacks kotlin-spring-naming@mk ids search naming -kotlin
tc TC-Q07 "필드 지정 (tag:spring)" jqe '[.results[].id] | sort == ["java-spring-test@mk", "kotlin-spring-naming@mk"]' run search tag:spring
tc TC-Q08 "has:agent 필터" jqe '[.results[].id] == ["beta-coverage@mk"]' run search has:agent
tc TC-Q09 "is:installed 필터" jqe '[.results[].id] == ["alpha-naming@mk"]' run search is:installed --mp mk
tc TC-Q10 "/정규식/" jqe '[.results[].id] | sort == ["java-spring-test@mk", "kotlin-spring-naming@mk"]' run search 'name:/-spring-/'
tc TC-Q11 "a|b 는 둘 중 하나" jqe '[.results[].id] | index("gamma-workflow@mk") and index("delta-mcp@mk")' run search 'github|deltadb'
tc TC-Q12 "모든 단어에 맞는 게 없으면 완화하고 relaxed 로 알린다" jqe '.relaxed and (.results | length) > 0' run search naming 바나나
tc TC-Q13 "--any 는 완화 표시 없이 OR" jqe '(.relaxed | not) and (.results | length) >= 2' run search naming deltadb --any
tc TC-Q14 "불용어(플러그인 · 찾아줘)는 무시한다" first_is beta-coverage@mk ids search 커버리지 플러그인 찾아줘
tc TC-Q15 "--tag · --has · --installed 옵션 필터" jqe '[.results[].id] == ["alpha-naming@mk"]' run search --tag development --has hook --installed
tc TC-Q16 "스킬 이름으로 찾는다 (skill:issue-create)" first_is gamma-workflow@mk ids search skill:issue-create
tc TC-Q17 "MCP 서버 이름으로 찾는다" first_is delta-mcp@mk ids search deltadb
tc TC-Q18 "dep: 는 의존하는 플러그인" jqe '[.results[].id] == ["beta-coverage@mk"]' run search dep:alpha-naming
tc TC-Q19 "--limit 과 total" jqe '(.results | length) == 1 and .total >= 2' run search naming --limit 1
tc TC-Q20 "tsv 는 헤더 + 줄마다 탭 8칸" bash -c '"$0" search naming --format tsv | awk -F"\t" "NF != 8 { exit 1 }"' "$S"
tc TC-Q21 "--sort installs" first_is beta-coverage@mk ids search --mp mk --sort installs
tc TC-Q22 "why 에 일치 이유" jqe '.results[0].why[0] | test("이름")' run search naming
tc TC-Q23 "검색어 · 필터가 없으면 2" exit_is 2 run search
tc TC-Q24 "모르는 옵션 · 잘못된 값은 2" exit_is 2 run search x --format xml
tc TC-Q26 "이름의 일부(하이픈 포함)로 찾는다" first_is gamma-workflow@mk ids search ma-work
tc TC-Q25 "공백이 든 인자는 단어로 나눈다" first_is beta-coverage@mk ids search "커버리지 게이트"

echo "== related"
tc TC-R01 "의존 (직접 · 간접)" jqe '[.results[] | select(any(.why[]; startswith("의존"))) | .id] | sort == ["alpha-naming@mk", "beta-coverage@mk"]' run related gamma-workflow --by dependency
tc TC-R02 "역의존 (직접 · 간접)" jqe '[.results[] | select(any(.why[]; startswith("역의존"))) | .id] | sort == ["beta-coverage@mk", "gamma-workflow@mk"]' run related alpha-naming@mk --by dependent
tc TC-R03 "--by tag 는 태그만" jqe '[.results[].id] == ["java-spring-test@mk"]' run related kotlin-spring-naming --by tag
tc TC-R04 "이름 단어 공유 (naming)" out_has kotlin-spring-naming@mk ids related alpha-naming@mk --by name
tc TC-R05 "같은 이름이 여러 마켓이면 ambiguous 로 알린다" jqe '.ambiguous | length == 2' run related alpha-naming
tc TC-R06 "기능어면 검색 일치를 앞에, 연관을 뒤에" jqe '.mode == "feature" and .results[0].group == "match" and any(.results[]; .group == "related")' run related 커버리지
tc TC-R07 "모르는 --by 는 2" exit_is 2 run related alpha-naming --by color

echo "== project"
P1="$WORK/proj-java"
put "$P1/build.gradle" <<<"dependencies { implementation 'org.springframework.boot:spring-boot-starter-web' }"
put "$P1/src/main/java/A.java" <<<"class A {}"
put "$P1/.claude/settings.json" <<'EOF'
{ "enabledPlugins": { "alpha-naming@mk": true, "gamma-workflow@mk": true, "delta-mcp@mk": false, "nope@ghost": true } }
EOF
tc TC-P01 "신호: java · spring · gradle" jqe '[.signals[].id] | sort == ["gradle", "java", "spring"]' run detect "$P1"
pj() { run project "$P1"; }
tc TC-P02 "선언됨 + 설치됨 → ok" jqe '.results[] | select(.id == "alpha-naming@mk") | .status == "ok" and .group == "declared"' pj
tc TC-P03 "선언됨 + 미설치 → missing" jqe '.results[] | select(.id == "gamma-workflow@mk") | .status == "missing"' pj
tc TC-P04 "false 로 끈 선언 → off" jqe '.results[] | select(.id == "delta-mcp@mk") | .status == "off"' pj
tc TC-P05 "마켓플레이스가 없는 선언 → marketplace-missing" jqe '.results[] | select(.id == "nope@ghost") | .status == "marketplace-missing"' pj
tc TC-P06 "선언의 의존 폐포 → dependency (beta-coverage)" jqe '.results[] | select(.id == "beta-coverage@mk") | .group == "dependency" and .status == "missing"' pj
tc TC-P07 "신호로 추천 (java-spring-test)" jqe '.results[] | select(.id == "java-spring-test@mk") | .group == "recommended"' pj
tc TC-P08 "감지 안 된 언어 대상은 깎는다 (kotlin)" jqe '([.results[] | select(.id == "java-spring-test@mk") | .score][0]) > ([.results[] | select(.id == "kotlin-spring-naming@mk") | .score][0] // 0)' pj
tc TC-P09 "--only missing" jqe '[.results[].status] | unique | all(. == "missing" or . == "marketplace-missing")' run project "$P1" --only missing
tc TC-P10 "--only recommended 는 선언을 뺀다" jqe 'all(.results[]; .group == "recommended")' run project "$P1" --only recommended
P2="$WORK/proj-empty"; mkdir -p "$P2"; echo hi > "$P2/readme.txt"
tc TC-P11 "신호 · 선언이 없으면 빈 결과" jqe '.results == [] and .signals == []' run project "$P2"
tc TC-P12 "node_modules 는 보지 않는다" bash -c 'mkdir -p "$1/node_modules/x" && echo "{}" > "$1/node_modules/x/package.json" && "$0" detect "$1" | jq -e ".signals == []"' "$S" "$P2"

echo "== show · facets"
tc TC-F01 "show 는 구성요소 목록과 역의존" jqe '.components.skills[0].name == "name-create" and .dependents == ["beta-coverage@mk"]' run show alpha-naming@mk
tc TC-F02 "없는 플러그인은 2" exit_is 2 run show nope
tc TC-F03 "facets tag 개수" jqe '.tag | map(select(.value == "spring"))[0].count == 2' run facets tag
tc TC-F04 "facets has 는 구성요소 종류별" jqe '.has | map(.value) | index("mcp") != null' run facets has

echo "== install"
calls() { cat "$STUB/calls" 2>/dev/null; }
reset_calls() { rm -f "$STUB/calls" "$STUB/fail"; }
reset_calls
tc TC-I01 "dry-run 은 설치하지 않는다" jqe '.results[0].status == "planned"' run install beta-coverage --dry-run
tc TC-I02 "dry-run 뒤 호출 기록이 없다" exit_is 0 test -z "$(calls)"
tc TC-I03 "이미 설치된 것은 건너뛴다" jqe '.results[0].status == "skipped"' run install alpha-naming@mk
reset_calls
tc TC-I04 "설치는 --scope 와 --json 으로 부른다" jqe '.summary.installed == 1 and .restartRequired' run install beta-coverage --scope user
tc TC-I05 "호출 인자" bash -c 'grep -qx "plugin install beta-coverage@mk --scope user --json" "$0/calls"' "$STUB"
tc TC-I06 "같은 이름이 여러 마켓이면 설치 전에 멈춘다" exit_is 2 run install alpha-naming
run search --mp mk --sort name > "$WORK/list.json"
tc TC-I07 "--from 에 선택이 없으면 조회만" jqe '.mode == "list-only" and all(.results[]; .status == "listed")' run install --from "$WORK/list.json"
reset_calls
tc TC-I08 "--select 번호 · 범위" jqe '[.results[].id] == ["beta-coverage@mk", "delta-mcp@mk", "evil@mk"]' run install --from "$WORK/list.json" --select 2-4 --dry-run
tc TC-I09 "--exclude 로 뺀다" jqe '[.results[].id] == ["beta-coverage@mk", "evil@mk"]' run install --from "$WORK/list.json" --select 2-4 --exclude delta-mcp --dry-run
tc TC-I10 "--all 은 목록 전부" jqe '(.results | length) == 8' run install --from "$WORK/list.json" --all --dry-run
tc TC-I11 "목록에 없는 번호는 2" exit_is 2 run install --from "$WORK/list.json" --select 99
tc TC-I12 "stdin 의 id 줄 목록" jqe '[.results[].id] == ["delta-mcp@mk"]' bash -c 'printf "beta-coverage@mk\ndelta-mcp@mk\n" | "$0" install --from - --select 2 --dry-run' "$S"
reset_calls; echo "delta-mcp@mk" > "$STUB/fail"
tc TC-I13 "하나라도 실패하면 1, 나머지는 계속" exit_is 1 run install delta-mcp evil
tc TC-I14 "실패 메시지를 결과에 남긴다" jqe '.results[] | select(.id == "delta-mcp@mk") | .status == "failed" and (.message | test("스텁"))' run install delta-mcp
reset_calls
tc TC-I15 "카탈로그에 없는 이름은 2" exit_is 2 run install ghost-plugin
tc TC-I16 "모르는 --scope 는 2" exit_is 2 run install beta-coverage --scope team
tc TC-I17 "--format ids 는 설치된 것만" first_is beta-coverage@mk run install beta-coverage --dry-run --format ids

echo
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]
