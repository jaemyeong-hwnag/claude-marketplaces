# plugin-search-install

이 마켓플레이스의 public 플러그인을 조회하고 설치한다 — 프로젝트 선언 · 파일 신호로 필요한 것, 플러그인 · 기능어로 연관된 것, 필드 · 태그 관점 · 동의어 · 오타 허용 기능 검색. 전부 · 일부 · 조회만 설치. CLI 와 로컬 MCP 서버로 쓴다.

**대상은 이 플러그인이 설치되어 온 마켓플레이스의 `category: public` 플러그인뿐이다.** 다른 마켓 · internal 은 조회 · 추천 · 설치하지 않는다. 마켓 이름을 박아 두지 않아 포크한 마켓에서도 그 마켓의 public 을 다룬다.

```
project   이 프로젝트에 필요한 것      선언(설정) · 의존 폐포 · 파일 신호 추천
related   이것과 연관된 것             의존 · 역의존 · 태그 · 키워드 · 이름 · 구성요소 · 설명
search    이런 기능 하는 것            필드:값 · domain: · tech: · -제외 · a|b · /정규식/ · has: · is: · dep:
facets    무엇이 있나                  도메인 · 기술 태그(tags.json 설명) · 키워드 · 구성요소별 개수
install   고른 것 설치                전부 · 번호/이름 일부 · 제외 · 조회만 · dry-run
```

같은 엔진을 세 가지로 쓴다 — 스킬이 부르는 CLI, Claude 가 Bash 없이 부르는 **로컬 MCP 서버**, 터미널에서 표 · 카드로 보고 화살표로 고르는 [`plugin-browser`](../plugin-browser/README.md). 로직은 엔진 한 곳에 있다.

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install plugin-search-install@jaemyeong-hwnag-plugins --scope project
```

필요한 것: `bash` (3.2 이상), `jq` (1.6 이상), `find` · `grep` · `awk`. `claude` CLI 가 없으면 `~/.claude/plugins/` 의 기록 파일을 읽는다 (설치는 CLI 가 있어야 한다).

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| plugin-search | 플러그인 찾아 · ~하는 플러그인 있어? · 비슷한 플러그인 | 요청을 질의 문법으로 바꿔 `search` · `related` 를 돌리고 이유와 함께 보인다 |
| project-plugin-search | 이 프로젝트에 뭐 깔아야 해 · 빠진 플러그인 · 온보딩 | `project` 결과를 필수(선언 · 의존)와 추천(신호)으로 나눠 상태 · 근거와 보인다 |
| plugin-install | 깔아줘 · 전부 설치 · 1번 3번만 · 이거 빼고 | 전부 · 일부 · 조회만과 범위를 정하고 dry-run → 설치 → 재시작 안내 |

## MCP 서버

플러그인을 설치하면 Claude Code 가 `plugin-search` MCP 서버(`scripts/plugin-search-mcp.sh`, stdio)를 로컬에서 띄운다. 런타임은 `bash` · `jq` 뿐이다.

| 도구 | 하는 일 |
|---|---|
| `search_plugins` | 기능 검색 — 질의 문법 · 태그 · 도메인 · 기술 · 구성요소 · 설치 여부 |
| `list_related_plugins` | 플러그인 · 기능어와 연관된 것 |
| `list_project_plugins` | 이 프로젝트에 필요한 것 |
| `get_plugin` | 한 플러그인 상세 |
| `list_plugin_facets` | 관점별 개수 |
| `install_plugins` | 설치 — **기본 dry-run**, `dry_run: false` 일 때만 설치 |

플러그인 없이 붙이려면 (마켓 이름을 지정한다):

```bash
claude mcp add plugin-search -e PLUGIN_SEARCH_MARKETPLACE=jaemyeong-hwnag-plugins -- <경로>/scripts/plugin-search-mcp.sh
```

## 주의

- **설치는 기본 `--scope project`** 다 — 프로젝트 `.claude/settings.json` 이 바뀐다. 개인 도구면 `--scope user`
- 대상 마켓을 판별하지 못하거나 그 마켓이 등록돼 있지 않으면 멈춘다 — `PLUGIN_SEARCH_MARKETPLACE` 로 지정한다
- 원격 source(github · url) 플러그인은 설치 전에는 스킬 · 훅을 모른다 (`componentsKnown: false`). 이름 · 설명 · 태그로만 찾힌다
- 명령 실행 확인이 필요한 플러그인(command source)은 `-y` 로 대신 승인하지 않는다. 직접 실행할 명령을 알린다
- 설치한 플러그인은 **Claude Code 를 다시 시작해야** 로드된다 (`restartRequired`)
- 카탈로그 캐시는 10분. 마켓플레이스를 갱신했는데 안 보이면 `--refresh`
- 프로젝트 추천은 파일 흔적만 본다. 예제 디렉터리의 `pom.xml` 도 Java 신호가 된다 — 스킬이 `evidence` 를 보고 걸러낸다

## 사용

```bash
S=scripts/plugin-search-install.sh
$S search 테스트 커버리지                         # 기능 검색 (동의어 · 조사 · 오타 허용)
$S search naming has:hook -java --format tsv      # 필드 · 제외 · 표
$S search tech:spring is:not-installed --sort installs
$S search --domain development --has hook
$S related plugin-naming --by name,tag            # 연관 — 관계 골라서
$S related 문서 동기화                             # 기능어로 연관
$S project . --only missing                       # 선언됐는데 없는 것
$S facets                                         # 도메인 · 기술 · 키워드 · 구성요소별 개수
$S search 커버리지 > /tmp/l.json && $S install --from /tmp/l.json --select 1,3 --dry-run
$S install github-workflow --scope user
```

## 파일

| 경로 | 역할 |
|---|---|
| `references/search-rules.md` | 규칙 원본 — 카탈로그 출처, 질의 문법, 점수, 연관 · 프로젝트 · 설치 규칙, 출력 필드 |
| `references/search-synonyms.json` | 동의어 묶음 (한 · 영) · 불용어 |
| `references/project-signals.json` | 파일 신호 33종 — 경로 · 내용 패턴, 검색 단어, 가중치, 언어 배타 여부 |
| `scripts/plugin-search-install.sh` | `catalog` · `search` · `related` · `project` · `detect` · `show` · `facets` · `install` |
| `scripts/plugin-search-mcp.sh` | 로컬 MCP 서버 (stdio) — 엔진을 도구 6개로 |
| `test/` | 회귀 테스트와 TC 명세 — 엔진(스텁 claude · 가짜 마켓플레이스), MCP(JSON-RPC 대화) |
| `evals/` | `claude plugin eval` 케이스 — 기능 검색 스킬 발동(`search-request`) |

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
