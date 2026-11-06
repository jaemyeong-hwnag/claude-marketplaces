# CHANGELOG

## 0.3.0

### Changed
- `ST-01` 훅을 `prompt` 타입으로 바꿨다. 부하 도구 이름이 든 Bash 명령에서만(`if` 규칙) 모델이 명령 문자열을 판정하고, 허용 목록 밖 호스트면 막고 이유를 Claude 에게 돌려준다 (`continueOnBlock`). 디렉터리가 Verified 가 아닌 조직의 mcp_tool 훅과 로컬 MCP 서버를 거절해서다. 훅 판정은 결정적이지 않고, 스크립트 파일 안 URL 과 `STRESS_TEST_ALLOWED_HOSTS` 를 보지 않는다. 이 둘은 `stress-test-create` 스킬이 실행 전에 `stress-target-validate.sh` 로 보고, 목록에 넣은 호스트도 훅이 막으므로 사용자가 직접 실행한다 (#299, `TC-S67` ~ `TC-S69`)

### Removed
- MCP 서버 `stress-hook`(`scripts/stress-hook-server.sh`, `plugin.json` `mcpServers`)
- 저장 시 `ST-02` ~ `ST-06` 알림 훅(PostToolUse `Write|Edit`). `stress-test-create` 스킬과 `/stress-script-validate` 가 맡는다 (#299)

## 0.2.0

### Changed
- 훅 두 개를 `command` 에서 `mcp_tool` 로 바꿨다. 플러그인 안 stdio MCP 서버 `stress-hook`(`scripts/stress-hook-server.sh`)이 기존 판정 스크립트를 부르고, `ST-01` 위반과 판정 스크립트 실행 오류는 `permissionDecision: deny` 로 막는다. Anthropic 디렉터리가 Verified 가 아닌 조직의 command 훅을 거절(LOCAL_CODE_HOOK_COMMAND)해서다. 훅 서버가 연결되지 않으면 훅은 통과한다 (#297, `TC-S67` ~ `TC-S70`)

## 0.1.12

### Fixed
- Anthropic 디렉터리 검증기가 PreToolUse 훅 스크립트의 따옴표 안 `>`(정규식 · tr 문자 집합)를 출력 리다이렉션으로 읽어 COMMAND_PATH_COMPUTED 로 차단하던 것 — `>` 를 본문에 쓰지 않고 실행 때 만든 값으로 넣는다. 판정은 그대로다 (#273, `TC-S66`)

## 0.1.11

### Fixed
- Anthropic 디렉터리 검증기가 문서의 백틱으로 감싼 느낌표를 스킬 · 커맨드 실행 줄로 읽어 COMMAND_PATH_COMPUTED 로 차단하던 것 — 느낌표를 백틱 없이 적었다. 뜻은 그대로다 (#270)

## 0.1.10

### Fixed
- Anthropic 디렉터리 검증기가 커맨드 · 스킬의 명령 경로를 계산된 경로(COMMAND_PATH_COMPUTED)로 차단하던 것 — `${CLAUDE_PROJECT_DIR:-.}` 를 `.` 으로, `$P/…` 를 `${CLAUDE_PLUGIN_ROOT}/scripts/…` 로 그대로 적었다 (#265)

## 0.1.9

### Fixed
- Anthropic 디렉터리 검증기가 훅 스크립트를 UNPINNED_NPX 로 차단하던 것 — awk 정규식의 `<<` 를 `[<][<]` 로, here-string 을 배열 · 매개변수 확장으로, 따옴표 문자열 안의 명령 치환을 먼저 받은 변수로 바꿨다. 판정은 그대로다 (#255)

## 0.1.8

### Fixed
- `ST-01` 이 사설 대역을 접두 문자열로 비교해 `10.evil.com` · `127.0.0.1.nip.io` 같은 공용 이름을 허용하던 것 — IP 리터럴일 때만 사설로 본다 (#240)
- `ST-01` 이 정수 · 16진 IPv4(`http://134744072/`)를 점 없는 이름으로 허용하고 `[2001:db8::1]` 같은 IPv6 리터럴을 판정하지 않던 것 — 표준 표기가 아닌 숫자 IP 는 허용하지 않고, IPv6 는 `::1` · `fc00::/7` · `fe80::/10` 만 허용한다 (#240)
- `ST-01` 이 `bombardier` · `siege` · `h2load` · `httperf` · `ghz` · `plow` · `drill` · `fortio load` 를 부하 명령으로 보지 않고, URL 을 위치 인자로 받는 도구의 스킴 없는 대상(`bombardier example.com`)을 보지 않던 것 (#240)

### Changed
- 규칙 원본 · README 에 훅이 보지 못하는 것(`make` · `npm run` 간접 실행, 변수로 만든 명령 · 대상)을 적었다 (#240)

## 0.1.7

### Changed
- `plugin.json` 에 `license`(MIT)를 적었다 — Anthropic 디렉터리 제출 조건 (#233)

## 0.1.6

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 2건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.5

### Fixed
- `stress-result-review` 트리거 "몇 rps 까지" 가 측정 결과 없는 용량 질문(`stress-test-create` 의 "몇 rps 버티나")에도 뜨던 것 — "측정 결과로 몇 rps 까지" 로 좁힌다 (#206)

## 0.1.4

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — `stress-target-validate.sh` 가 깨지면 운영 호스트 부하 차단(`ST-01`) 없이 통과하던 것 (#160, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- `stress-report-generate.sh` 가 `--slo-p99` 를 줬는데 p99 가 빈 단계를 합격으로 보던 것 — 판정할 수 없어 불합격(`p99?`)으로 보고 `--target` 은 exit 2 (#123)
- `ST-04` 안내가 thresholds 의 `p(99)` 로도 된다고 하던 것 — 요약의 분위수는 `summaryTrendStats` 에서만 나온다 (#123)
- `stress-step-generate.sh` 가 k6 단계 분위수에 실패 요청 지연을 섞던 것 (`ST-32`) — `http_req_duration{expected_response:true}` 가 있으면 p50 · p95 · p99 · max 를 그것으로 읽는다 (#123)
- `stress-step-generate.sh` 가 Locust CSV 에 `99%` 등 열이 없으면 "Aggregated 줄이 없다" 로 잘못 알리던 것 — 없는 열 이름을 알린다 (#123)
- `ST-01` 이 `nice` · `ionice` · `stdbuf` · `xargs` · `watch` · `caffeinate` 로 감싼 부하 명령을 보지 않던 것 — 래퍼와 그 옵션을 건너뛴다 (#123)
- `ST-01` 이 스크립트 파일의 줄 끝 주석 URL 을 대상으로 보고 막던 것, 스킴 없는 기본값 `__ENV.BASE_URL || 'api.example.com'` 을 보지 않던 것 (#123)

## 0.1.2

### Fixed
- `ST-01` 이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 보지 않던 것 — 래퍼 · 셸 키워드를 건너뛰고 `sh -c` 는 인자를 다시 본다 (#90)
- `ST-01` 이 `<script.js` 로 넘긴 스크립트 안의 URL 을 보지 않던 것 — `<` · `>` 를 구분자로 읽는다 (#90)
- `ST-01` 이 hey · wrk · ab · oha 의 헤더 `-H` 를 호스트로 보고 막던 것 — `-H` 는 locust 에서만 호스트로 본다 (#90)
- `ST-01` 이 여러 줄 import 의 `from '<url>'`, 출력 대상(`--out` · `-o` · `K6_*` · `>` 파일), 같은 명령의 다른 구간(`curl … && k6 run`), heredoc 본문의 URL 을 대상으로 보던 것 — 부하 구간과 다른 구간의 변수 대입에서만 호스트를 모으고 이것들은 뺀다. 부하 명령 줄의 heredoc(`k6 run - <<EOF`)은 스크립트로 본다 (#90)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `common-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/stress-test-rules.md` (`ST-01` ~ `ST-35`), 근거 `stress-test-methods.md`, 실측한 템플릿 `stress-test-templates.md` (k6 유형 6개 · 단계 루프 · Docker Compose · Kubernetes Job)
- `stress-target-validate.sh` — 부하 도구가 허용 목록 밖 호스트를 겨누면 차단 (PreToolUse `Bash`)
- `stress-script-validate.sh` — k6 · Gatling · Locust · JMeter 스크립트의 closed 모델 · thresholds · p99 · maxVUs · sleep 경고 (PostToolUse `Write|Edit`, CLI)
- `stress-step-generate.sh` — k6 · Locust · JMeter · Gatling 결과를 단계 CSV 로
- `stress-report-generate.sh` — 단계 판정 · 지속 가능 용량 · Kneedle knee · USL · Little 정합성
- `stress-regression-validate.sh` — Mann-Whitney U(정확 · 정규 근사) + Cliff's delta 회귀 판정
- `stress-test-create` · `stress-result-review` · `stress-environment-create` 스킬, `/stress-script-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
