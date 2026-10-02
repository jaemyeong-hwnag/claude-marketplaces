# 조회 · 설치 규칙 (단일 원본)

`scripts/plugin-search-install.sh` 와 그것을 감싸는 MCP 서버(`scripts/plugin-search-mcp.sh`)가 따르는 규칙이다. 스킬 · UI 플러그인 · MCP 도구는 이 문서의 문법으로 질의하고, 결과 JSON 을 이 문서의 필드로 읽는다.

## 0. 범위

**이 플러그인이 설치되어 온 마켓플레이스의 `category: public` 플러그인**만 조회 · 연관 · 추천 · 설치한다. 다른 마켓 · internal 은 어떤 명령의 결과에도 나오지 않고 설치되지 않는다.

| 대상 마켓 판별 (위가 먼저) | 예 |
|---|---|
| `PLUGIN_SEARCH_MARKETPLACE` | 테스트 · 직접 지정 |
| 설치본 경로 `…/plugins/cache/<마켓>/<플러그인>/<버전>` | 마켓에서 설치한 경우 |
| 이 플러그인을 품는 디렉터리 마켓의 위치 (`installLocation`) | 소스 체크아웃 · 디렉터리 마켓 |
| `../../.claude-plugin/marketplace.json` 의 `name` | 마켓 저장소 안의 소스 |

마켓 이름을 박아 두지 않는다 — 포크한 마켓에서도 그 마켓의 public 을 다룬다. 판별한 마켓이 등록돼 있지 않으면 안내하고 2.

## 1. 카탈로그

| 출처 | 읽는 것 |
|---|---|
| `claude plugin marketplace list --json` | 등록된 마켓플레이스와 위치 |
| 각 위치의 `.claude-plugin/marketplace.json` | 엔트리 — 이름 · 설명 · 카테고리 · 태그 · 키워드 · source · 의존 |
| `claude plugin list --json --available` | 설치 여부 · 범위 · 켜짐 · 설치 수(`installCount`) |
| 플러그인 디렉터리 (설치본이 있으면 설치본, 없으면 마켓플레이스 안 소스) | `plugin.json` · `skills/*/SKILL.md` · `commands/*.md` · `agents/*.md` · `hooks/hooks.json` · `.mcp.json` |

- `project` · `local` 범위 설치는 그 프로젝트(`projectPath`, 하위 디렉터리 포함)에서만 설치됨으로 본다. 다른 프로젝트의 것은 `installedElsewhere` 에 경로를 남긴다
- CLI 를 못 쓰면 `$CLAUDE_CONFIG_DIR`(기본 `~/.claude`)`/plugins/known_marketplaces.json` · `installed_plugins.json` 으로 읽는다
- 원격 source(github · url · npm …)이고 설치 전이면 구성요소를 모른다 — `componentsKnown: false`
- 마켓 루트의 `.claude-plugin/tags.json`(`name` · `kind` · `description`)으로 태그를 `domains` · `technologies` 로 나누고 설명을 `tagNotes` · `tagInfo` 로 붙인다
- 설명 · 이름의 제어 문자는 지운다. 터미널에 그대로 찍히면 화면을 조작할 수 있다
- 캐시: `~/.cache/plugin-search-install/catalog-<지문>.json`. 지문은 현재 디렉터리 · 마켓플레이스 목록 · 설치 상태 · 매니페스트 크기 · 시각. 10분 안이면 재사용, `--refresh` 로 다시 만든다. 설치하면 지운다

환경 변수: `PLUGIN_SEARCH_CATALOG`(카탈로그 파일 주입) · `PLUGIN_SEARCH_CLAUDE`(claude 실행 파일) · `PLUGIN_SEARCH_CACHE_DIR` · `PLUGIN_SEARCH_CACHE_TTL`(분).

## 2. 질의 문법 (`search` · `related` 의 기능어)

| 형태 | 뜻 | 예 |
|---|---|---|
| `단어` | 모든 필드에서 찾는다 | `naming` |
| `필드:값` | 그 필드에서만 | `tag:spring` · `domain:development` · `tech:spring` · `kw:coverage` · `name:naming` · `desc:배포` · `skill:issue-create` · `cmd:` · `agent:` · `hook:PreToolUse` · `mcp:` · `lsp:` · `cat:` · `mp:` · `comp:`(구성요소 전부) |
| `-단어` · `!단어` | 제외 (단어 일치만, 동의어 · 오타 허용 없음) | `-java` |
| `a\|b` | 둘 중 하나 | `github\|gitlab` |
| `/정규식/` | 대소문자 무시 정규식 | `name:/^java-/` |
| `has:종류` | 구성요소가 있다 — `skill` · `command` · `agent` · `hook` · `mcp` · `lsp` | `has:hook` |
| `is:상태` | `installed` · `not-installed` · `enabled` · `disabled` | `is:not-installed` |
| `dep:이름` | 그 플러그인에 의존한다 | `dep:github-workflow` |

- 인자 안의 공백은 단어를 나눈다. 단어끼리는 기본 **AND**. 모든 단어에 맞는 것이 없으면 일부만 맞는 결과를 내고 `relaxed: true` 로 알린다. `--any` 는 처음부터 OR
- 불용어(`references/search-synonyms.json` 의 `stopwords` — "플러그인" · "찾아줘" …)는 다른 단어가 있으면 버린다

## 3. 점수

단어마다 가장 높은 필드 점수 + 맞은 필드가 더 있으면 하나에 0.5. 플러그인 점수는 단어 점수의 합.

| 필드 | 완전 일치 | 단어 일치 | 부분 일치 |
|---|---:|---:|---:|
| 이름 | 10 | 7 | 4 |
| 태그 · 도메인 · 기술 | 6 | - | 3 |
| 태그 설명 (`tags.json`) | - | 3 | 3 |
| 키워드 | 5 | 4 | 2.5 |
| 스킬 · 커맨드 · 에이전트 · 훅 · MCP · LSP 이름 | 5 | 5 | 3 |
| 설명 | - | 3 | 2 |
| 구성요소 설명 | - | 2 | 2 |
| 카테고리 | 3 | - | - |
| 마켓플레이스 | 2 | 2 | - |

| 변형 | 배수 | 끄는 법 |
|---|---:|---|
| 동의어 (`search-synonyms.json` 의 같은 묶음) | ×0.7 | `--exact` |
| 한글 조사 · 어미를 뗀 형태 (`커버리지를` → `커버리지`) | ×0.9 | `--exact` |
| 오타 허용 — 영문 4자 이상, 편집 거리 1 (8자 이상 2). 다른 일치가 없을 때만 | 2.5 고정 | `--exact` · `--no-fuzzy` |

- 부분 일치: 영문은 **단어 앞부분**만 (`java` 는 `javascript` 에 맞지만 `nojava` 에는 안 맞는다), 한글은 조사가 붙으므로 어디든
- 이름은 3자 이상이면 이름 전체 안의 부분 문자열로도 맞는다 (`ma-work` → `gamma-workflow`)
- 2자 이하 영문은 단어 일치만
- 정렬: 그룹 → 맞은 단어 수 → 점수 → 설치 수 → 이름. `--sort name|installs` 로 바꾼다

## 4. 연관 (`related`)

대상이 플러그인 이름 · id 면 그 플러그인과 다른 모든 플러그인의 관계를 잰다. `--by` 로 관계를 고른다 (기본 전부).

| `--by` | 관계 | 점수 |
|---|---|---|
| `dependency` | 대상이 기대는 것 (같은 마켓, 전이) | 10 |
| `dependent` | 대상에 기대는 것 (같은 마켓, 전이) | 8 |
| `tag` | 공유 태그 | Σ IDF × 2 |
| `keyword` | 공유 키워드 단어 | Σ IDF × 1.5 |
| `name` | 공유 이름 단어 (`*-naming` 끼리) | Σ IDF × 2 |
| `component` | 공유 구성요소 이름 단어 (훅 제외) | Σ IDF, 최대 6 |
| `description` | 공유 설명 단어 | Σ IDF × 0.3, 최대 5 |
| `category` | 같은 카테고리 | 0.5 |

IDF = ln((전체 + 1) / 그 단어를 가진 플러그인 수) + 0.1 — 흔한 단어(`plugin` · `development`)는 거의 세지 않는다. 기본 최소 점수 1.5.

대상이 플러그인이 아니면 **기능어**로 검색해 상위 3개를 씨앗으로 삼는다. 씨앗은 `group: "match"` 로 앞에, 씨앗들의 연관은 순위 가중(1, ½, ⅓)으로 합쳐 `group: "related"` 로 뒤에 둔다. 같은 이름이 여러 마켓에 있으면 설치된 쪽을 씨앗으로 하고 `ambiguous` 에 후보를 낸다.

## 5. 프로젝트 (`project`)

| 그룹 | 근거 | 상태 |
|---|---|---|
| `declared` | 프로젝트 `.claude/settings.json` · `settings.local.json`(뒤가 이긴다)의 `enabledPlugins` 중 **대상 마켓의 public** | `ok` · `missing`(미설치) · `disabled`(설치됐지만 꺼짐) · `off`(설정에서 false) |
| `dependency` | 선언된 것의 의존 폐포 중 선언되지 않은 것 | `ok` · `missing` |
| `recommended` | 파일 신호(`references/project-signals.json`)의 단어가 플러그인 이름 · 태그 · 키워드 · 구성요소 · 설명 단어에 맞는다 | `ok` · `missing` |

- 추천 점수 = Σ 신호 가중치 × 필드 점수 / 10. 단어 일치만 본다 (부분 · 동의어 · 오타 없음)
- **대상 불일치** — 플러그인 이름에 감지되지 않은 언어 · 프레임워크(신호의 `exclusive`) 단어가 있으면 ×0.3 (Java 프로젝트의 `kotlin-*`)
- 파일 색인은 깊이 8, `prune` 디렉터리(node_modules · .git · build …)를 뺀다
- `--only declared|missing|recommended`. 기본 한도 없음, 최소 점수 1
- 설정 파일이 JSON 이 아니면 그 파일만 건너뛰고 `settingsErrors` 에 경로를 낸다
- 대상 밖 선언(다른 마켓 · internal)은 결과에 넣지 않고 `outOfScope` 에 id 를 낸다

## 6. 설치 (`install`)

| 입력 | 동작 |
|---|---|
| `install a b@m` | 이름 전부 설치 (`--select` 로 일부) |
| `install --from 파일\|-` | 검색 · 연관 · 프로젝트 JSON 의 `results`, JSON 배열, 또는 id 줄. **선택이 없으면 조회만** (`mode: "list-only"`) |
| `--select 1,3-5,이름,all,none` | 목록의 `rank` 번호 · 범위 · 이름 · id |
| `--exclude …` | 같은 문법으로 뺀다 |
| `--all` | 목록 전부 |
| `--dry-run` | 실행할 명령만 (`planned`) |
| `--scope user\|project\|local` | 기본 `project` — 팀이 같은 설정을 받는다 |

- 이름이 여러 마켓에 있거나(위치 인자 · `--select` 둘 다) 카탈로그에 없으면 **아무것도 설치하지 않고** 2로 멈춘다
- 범위의 번호가 하나라도 목록에 없거나 거꾸로(`3-1`)면 2. 같은 대상은 한 번만 설치한다
- `--from` 의 줄 목록은 id 줄 또는 이 스크립트의 tsv 출력(헤더 건너뜀, 둘째 칸이 id)
- 이미 설치된 것은 `skipped`. 명령 실행 확인이 필요한 플러그인(command source)은 `-y` 를 붙이지 않고 `failed` 로 직접 실행 명령을 알린다
- 하나라도 실패하면 1. 나머지는 계속한다. 설치가 하나라도 되면 `restartRequired: true`

## 7. 출력

`--format json`(기본) · `tsv`(헤더 + `rank id installed score group status why description`) · `ids` · `names`. `--limit`(기본 20, `project` 는 전부, 0 = 전부) · `--full`(구성요소 목록 · 경로 포함).

결과 항목 필드: `rank` · `id` · `name` · `marketplace` · `description` · `version` · `category` · `tags` · `keywords` · `dependencies` · `installed` · `enabled` · `scopes` · `installCount` · `componentCounts` · `score` · `why`(사람이 읽는 이유) · `group` · `status`. 검색은 `matches`(단어 · 필드 · 동의어/오타)와 `relaxed` 를 더한다.

종료 코드: 0 정상 · 1 설치 일부 실패 · 2 잘못된 입력 (모르는 옵션 · 값, 잘못된 정규식, 모르는 플러그인, 모호한 이름, 목록에 없는 선택).

## 8. MCP 서버

`scripts/plugin-search-mcp.sh` — stdio, 한 줄에 JSON-RPC 메시지 하나. `plugin.json` 의 `mcpServers.plugin-search` 로 선언해 플러그인을 설치하면 Claude Code 가 띄운다. 엔진을 `--format json` 으로 부르고 판단에 필요한 칸만 텍스트로 돌려준다 — 로직은 엔진 한 곳에 있다.

| 도구 | 엔진 | 입력 |
|---|---|---|
| `search_plugins` | `search` | `query`(2절 문법) · `tags` · `domain` · `technology` · `has` · `installed` · `any` · `exact` · `sort` · `limit` |
| `list_related_plugins` | `related` | `target`(필수) · `by` · `limit` |
| `list_project_plugins` | `project` | `directory`(기본 `CLAUDE_PROJECT_DIR`) · `only` |
| `get_plugin` | `show` | `name`(필수) |
| `list_plugin_facets` | `facets` | `field` |
| `install_plugins` | `install` | `plugins`(필수) · `scope`(기본 project) · `dry_run`(**기본 true**) |

- 메서드: `initialize`(요청한 프로토콜 버전을 알면 그대로, 모르면 `2025-06-18`) · `ping` · `tools/list` · `tools/call`. 알림에는 답하지 않는다
- 오류: JSON 이 아님 `-32700` · 모르는 메서드 `-32601` · 모르는 도구 · 필수 인자 없음 `-32602`. 엔진의 입력 오류(종료 2)는 `isError: true` 결과로
- 인자는 셸을 거치지 않고 배열로 엔진에 넘긴다. 큰 JSON 은 인자가 아니라 파일로 넘긴다 — MCP 프로세스는 환경 변수가 커서 `ARG_MAX` 에 먼저 닿는다
- 설치는 프로젝트 디렉터리에서 실행한다 — `project` 범위가 그 프로젝트의 `.claude/settings.json` 에 들어간다
