# 강제 실효성 테스트

`scripts/validate-enforcement-effectiveness.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-enforcement-effectiveness.test.sh          # 전체 (2026-10-30 실측 38 ~ 53초 — 훅 · MCP 서버를 실제로 띄운다)
test/validate-enforcement-effectiveness.test.sh TC-E5    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. MCP 제한 시간은 테스트에서 `EF_MCP_TIMEOUT=2` 로 줄인다.

## 자동 TC (80건)

픽스처는 **모든 조항을 지키는 플러그인**을 `mktemp -d` 아래 git 저장소로 만든다. 스킬 · 커맨드 · 에이전트 · 훅(Pre · Post · Stop, 실행 권한 있는 스크립트) · JSON-RPC 에 답하는 MCP 서버 · 판정 열이 있는 규칙 원본 · 그 ID 를 가진 TC · trigger / hook eval 을 갖는다. TC 마다 한 곳만 깨뜨린다. 구성요소를 하나씩 뺀 경우는 I 절에 따로 둔다.

픽스처의 git 명령은 `-C` 가 픽스처 아래일 때만 돈다. 경로 계산이 틀려 이 저장소를 커밋 · 체크아웃한 적이 있다 (작성 중).

### A. 기준

| ID | 케이스 |
|---|---|
| TC-E01 | 이 저장소 전체가 --all --no-run 을 통과한다 |
| TC-E02 | 모든 조항을 지킨 플러그인은 조용히 통과한다 |
| TC-E03 | 실행 검사까지 해도 조용히 통과한다 (--all) |

### B. 강제 사슬 (EF-01 ~ EF-07)

| ID | 케이스 |
|---|---|
| TC-E10 | 훅 command 가 상대 경로면 막는다 (EF-01) |
| TC-E11 | 훅 args 안의 상대 경로를 막는다 (EF-01 경계) |
| TC-E12 | MCP 서버 command 가 상대 경로면 막는다 (EF-01) |
| TC-E13 | env · 인터프리터 · 시스템 명령 · 리다이렉트 · CLAUDE_PROJECT_DIR 는 통과한다 (EF-01 과잉 차단 방지) |
| TC-E14 | 훅이 가리키는 스크립트가 없으면 막는다 (EF-02) |
| TC-E15 | MCP 서버 스크립트가 없으면 막는다 (EF-02) |
| TC-E16 | 직접 실행하는 스크립트에 실행 권한이 없으면 막는다 (EF-03) |
| TC-E17 | 인터프리터 뒤의 파일은 실행 권한을 보지 않는다 (EF-03 과잉 차단 방지) |
| TC-E18 | 작업 트리는 755 인데 git 인덱스가 644 면 막는다 (EF-03 경계) |
| TC-E19 | 인덱스는 755 인데 작업 트리가 644 면 막는다 (EF-03 경계) |
| TC-E20 | git 이 추적하지 않는 새 스크립트는 작업 트리 권한만 본다 (EF-03 경계) |
| TC-E21 | git 저장소가 아니어도 작업 트리 권한을 본다 (EF-03 경계) |
| TC-E22 | Stop 에 matcher 를 쓰면 막는다 (EF-04) |
| TC-E23 | UserPromptSubmit 의 빈 matcher 도 막는다 (EF-04 경계) |
| TC-E24 | 규칙 원본의 차단 조항 ID 가 test 에 없으면 막는다 (EF-05) |
| TC-E25 | ID 가 scripts 에만 있어도 막는다 — test 만 본다 (EF-05) |
| TC-E26 | '위반 시 차단' · '**경고**' 셀도 대상이다 — 포함 판정 (EF-05) |
| TC-E27 | 판정 열이 없는 표 · AI 판단 조항은 보지 않는다 (EF-05 과잉 차단 방지) |
| TC-E28 | 차단 조항이 있는데 검증기도 훅도 없으면 막는다 (EF-06) |
| TC-E29 | scripts/validate-*.sh 가 있으면 훅이 없어도 된다 (EF-06) |
| TC-E30 | onFailure 가 없는 PreToolUse 훅은 경고만 한다 — 플러그인 · --all (EF-07) |
| TC-E31 | --since 에서는 onFailure 가 없으면 막는다 (EF-07) |
| TC-E32 | PostToolUse · Stop 훅에는 onFailure 를 요구하지 않는다 (EF-07 과잉 차단 방지) |

### C. 선언이 적용되는가 (EF-10 ~ EF-13)

| ID | 케이스 |
|---|---|
| TC-E40-{permissionMode · hooks · mcpServers · initialPrompt} | 에이전트의 각 필드는 무시되므로 막는다 (EF-10) — 4건 |
| TC-E41 | 본문에 permissionMode 라는 단어가 있어도 프런트매터가 아니면 보지 않는다 (EF-10 과잉 차단 방지) |
| TC-E42 | 에이전트에 tools 가 없으면 막는다 (EF-11) |
| TC-E43 | tools 에 편집 도구가 있으면 경고만 한다 — 쉼표 · 블록 목록 (EF-12) |
| TC-E44 | 같은 이름의 스킬과 커맨드를 막는다 (EF-13) |

### D. 실행 검사 (EF-20 ~ EF-22)

| ID | 케이스 |
|---|---|
| TC-E50 | 무관한 입력에 exit 2 하는 훅을 경고한다 (EF-20) |
| TC-E51 | timeout 안에 끝나지 않는 훅을 경고한다 (EF-20) |
| TC-E52 | stdout 으로 deny 를 내는 훅을 경고한다 (EF-20) |
| TC-E53 | matcher 가 Read 를 받으면 다른 도구로 바꿔 넣는다 (EF-20) |
| TC-E54 | matcher 가 시험 도구를 모두 받거나 입력이 없는 이벤트는 '실행 안 함' 으로 적는다 (EF-20) |
| TC-E55 | --no-run 이면 실행 검사를 건너뛴다 (EF-20 · EF-21) |
| TC-E56 | 플러그인 하나만 볼 때는 실행하지 않는다 (EF-20) |
| TC-E57 | initialize 에 응답하지 않고 끝나는 MCP 서버를 막는다 (EF-21) |
| TC-E58 | 제한 시간 안에 응답하지 않는 MCP 서버를 막는다 (EF-21) |
| TC-E59 | tools/list 에 없는 MCP 도구 이름을 막는다 (EF-22) |

### E. eval (EF-30 · EF-31)

| ID | 케이스 |
|---|---|
| TC-E60 | 스킬이 있는데 trigger 케이스가 없으면 막는다 (EF-30) |
| TC-E61 | 훅이 있는데 hook 케이스가 없으면 막는다 (EF-30) |
| TC-E62 | 블록 목록 tags 와 묶음 디렉터리 안의 케이스도 읽는다 (EF-30 경계) |
| TC-E63 | 스킬에 발동 그레이더가 없으면 경고만 한다 — 플러그인 · --all (EF-31) |
| TC-E64 | disable-model-invocation: true 스킬은 보지 않는다 (EF-31 과잉 차단 방지) |
| TC-E65 | input_match 없는 tool: Skill 그레이더는 모든 스킬에 맞는다 (EF-31) |
| TC-E66 | 끝 따옴표까지 쓴 정규식은 접두사가 같은 다른 스킬에 맞지 않는다 (EF-31 경계) |
| TC-E67 | JS 에서 깨지는 인라인 플래그 정규식은 위반이다 (EF-31) |
| TC-E68 | --since 에서 새 플러그인은 발동 그레이더가 없으면 막는다 (EF-31) |
| TC-E69 | --since 에서 고친 기존 플러그인은 경고만 한다 (EF-31) |

TC-E66 은 작성 중 찾은 결함의 회귀다. 그레이더 값의 작은따옴표를 벗긴 뒤 큰따옴표까지 벗겨 `"…plugin-search"` 가 `plugin-search-install:plugin-install` 에도 맞았다.

### F. --since

| ID | 케이스 |
|---|---|
| TC-E70 | 바뀌지 않은 플러그인은 보지 않는다 |
| TC-E71 | merge-base 와 비교한다 — 기준 쪽에서만 바뀐 플러그인은 보지 않는다 |
| TC-E72 | 추적되지 않는 새 파일도 바뀐 것으로 본다 |
| TC-E73 | 없는 ref 는 실행 오류다 |

### G. 훅 모드

| ID | 케이스 |
|---|---|
| TC-E80 | Pre: 무시되는 필드를 가진 에이전트를 쓰려 하면 막는다 (EF-10) |
| TC-E81 | Pre: tools 없는 에이전트를 막는다 (EF-11) |
| TC-E82 | Pre: 맞는 에이전트는 조용히 통과한다 · 편집 도구 경고는 내지 않는다 (EF-12) |
| TC-E83 | Pre: Edit 는 보지 않는다 |
| TC-E84 | Pre: hooks.json 의 상대 경로 · Stop matcher 를 막는다 (EF-01 · EF-04) |
| TC-E85 | Pre: hooks.json 이 아직 없는 스크립트를 가리켜도 막지 않는다 — 파일 둘이 맞아야 하는 조항 (EF-02) |
| TC-E86 | Pre: plugin.json 의 mcpServers 상대 경로를 막는다 (EF-01) |
| TC-E87 | Pre: 스킬이 있는 이름으로 커맨드를 · 커맨드가 있는 이름으로 스킬을 만들면 막는다 (EF-13) |
| TC-E88 | Post: 위반을 additionalContext 로 알리고 막지 않는다 |
| TC-E89 | Post: 정합하면 출력이 없다 |
| TC-E90 | 플러그인 밖 경로 · 빈 stdin · 경로 없는 입력은 무시한다 |

### H. CLI

| ID | 케이스 |
|---|---|
| TC-E95 | --all 이 플러그인을 하나도 못 찾으면 실행 오류다 |
| TC-E96 | 없는 디렉터리는 실행 오류다 |
| TC-E97 | 여러 경로를 받고, 위반 출력에 규칙 원본 경로를 적는다 |
| TC-E98 | 루트가 .claude/worktrees/ 안이어도 검사한다 |

### I. 구성요소를 하나씩 뺀 플러그인

| ID | 케이스 |
|---|---|
| TC-E99a | plugin.json 만 있는 플러그인은 통과한다 |
| TC-E99b | 훅 · hook 케이스가 없으면 훅 조항을 보지 않는다 (EF-01 · EF-07 · EF-30) |
| TC-E99c | 스킬 · trigger 케이스가 없으면 스킬 조항을 보지 않는다 (EF-13 · EF-30 · EF-31) |
| TC-E99d | 에이전트가 없으면 에이전트 조항을 보지 않는다 (EF-10 · EF-11) |
| TC-E99e | MCP 서버가 없으면 MCP 조항을 보지 않는다 (EF-21 · EF-22) |
| TC-E99f | 규칙 원본 · test 가 없으면 조항 연결을 보지 않는다 (EF-05 · EF-06) |
| TC-E99g | .mcp.json 의 서버도 본다 (EF-01) |

## 변이 테스트

조항마다 그 ID 를 내는 `err` · `warn` · `flag_ef07` · `flag_ef31` · `note` 호출을 `true` 로 바꾼 스크립트로 전체 TC 를 돌렸다 (`EF_SCRIPT=<변이> test/validate-enforcement-effectiveness.test.sh`). 2026-10-30 실행 결과다. 실패가 0 인 조항은 TC 가 막지 못하는 것이므로 TC 를 보강한다.

| 조항 | 바꾼 줄 | 실패한 TC |
|---|---|---|
| EF-01 | 1 | 6 |
| EF-02 | 1 | 2 |
| EF-03 | 2 | 4 |
| EF-04 | 1 | 3 |
| EF-05 | 1 | 3 |
| EF-06 | 1 | 1 |
| EF-07 | 1 | 2 |
| EF-10 | 1 | 5 |
| EF-11 | 1 | 7 |
| EF-12 | 1 | 1 |
| EF-13 | 3 | 2 |
| EF-20 | 5 | 4 |
| EF-21 | 1 | 2 |
| EF-22 | 1 | 1 |
| EF-30 | 2 | 2 |
| EF-31 | 2 | 5 |

## 사람이 확인할 것

| 항목 | 방법 |
|---|---|
| 설치 뒤 훅이 로드된다 | 새 세션에서 `claude plugin details plugin-enforcement-effectiveness@jaemyeong-hwnag-plugins` 의 Hooks 가 2 (PreToolUse · PostToolUse) |
| Pre 훅이 실제로 막는다 | `eval-all.sh --quick --plugin plugin-enforcement-effectiveness .` 의 `ignored-agent-field-blocked` |
| 검토 스킬이 발동한다 | 같은 명령의 `review-skill-fired` |
