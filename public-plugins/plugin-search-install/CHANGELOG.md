# CHANGELOG

## 0.2.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `plugin-search-install@jaemyeong-hwnag-plugins`

## 0.2.0

### Changed
- **대상을 이 플러그인이 설치되어 온 마켓플레이스의 `category: public` 플러그인으로 한정** (#42). 다른 마켓 · internal 은 조회 · 연관 · 추천 · 설치 대상이 아니다. 대상 마켓은 캐시 경로 · 디렉터리 마켓 위치로 스스로 판별하고 `PLUGIN_SEARCH_MARKETPLACE` 로 지정할 수 있다
- 프로젝트 조회 — 대상 밖 선언은 결과에 넣지 않고 `outOfScope` 로 알린다
- `facets` 의 `category` · `marketplace` 대신 `domain` · `technology`

### Added
- 마켓의 `tags.json` 관점 — `domain:` · `tech:` 질의, `--domain` · `--technology` 필터, 태그 설명 검색, facets 에 태그 설명
- 로컬 MCP 서버 `scripts/plugin-search-mcp.sh` (bash + jq, stdio) — `plugin.json` 의 `mcpServers` 로 선언. 도구 `search_plugins` · `list_related_plugins` · `list_project_plugins` · `get_plugin` · `list_plugin_facets` · `install_plugins`(기본 dry-run). 엔진을 감싸므로 로직은 한 곳

### Fixed
- 설치 목록 JSON 을 jq 인자(`--argjson`)로 넘겨, 환경 변수가 큰 프로세스(Claude Code 가 띄운 MCP 서버)나 리눅스(문자열 하나 128KB 한도)에서 `Argument list too long` 으로 카탈로그를 못 만들던 것 — 파일로 넘긴다. 실제 세션에서 MCP 도구로 처음 드러났다
- jq 1.6 의 `-e` 가 빈 입력을 성공으로 보아, `claude` CLI 가 없을 때 기록 파일로 넘어가지 못하고 빈 설정 파일을 정상으로 읽던 것 — 출력이 정확히 `true` 인지 본다

## 0.1.1

### Fixed
- `--select 이름` 이 여러 마켓에 같은 이름이면 모두 설치 대상으로 잡던 것 (#40). 이제 모호함으로 멈춘다 (2)
- 범위 일부가 목록 밖이거나(`1,7-9`) 거꾸로(`3-1`)여도 나머지를 고르던 것 — 아무것도 고르지 않고 2
- 같은 대상을 두 번 주면(`bar bar@a`) 두 번 설치하던 것
- 플러그인 id · 마켓 이름 · 스킬 · 커맨드 · 에이전트 이름의 제어 문자가 tsv · ids · 오류 메시지로 그대로 나가던 것, 설명의 NUL
- `--select ,` 처럼 구분자만 준 조회만 결과를 `--format ids` 가 설치 대상처럼 내던 것
- 깨진 `.claude/settings.local.json` 하나 때문에 `settings.json` 의 선언까지 사라지던 것 — 건너뛰고 `settingsErrors` 로 알린다
- 잘못된 정규식(`/[x/`) · `--min-score 1x2` 가 jq 오류로 죽던 것 — 안내와 2
- 엔진의 tsv 출력을 `--from` 으로 다시 읽지 못하던 것
- 캐시 지문과 내용을 따로 써서 동시 실행 때 짝이 어긋날 수 있던 것 — 지문을 파일 이름에 넣는다
- 기능어 연관의 직접 일치가 최소 점수에 걸려 빠지던 것
- jq 1.6 에서 키워드(`label`)를 필드로 쓰던 곳

## 0.1.0

### Added
- 등록된 모든 마켓플레이스의 플러그인을 조회 · 설치하는 public 플러그인 (#34). 화면을 모르고 json · tsv · ids · names 만 낸다 — CLI UI 는 `plugin-browser` 가 맡는다
- 스크립트 `plugin-search-install.sh` — `catalog` · `search` · `related` · `project` · `detect` · `show` · `facets` · `install`
- 카탈로그 — 마켓플레이스 엔트리 + plugin.json · 스킬 · 커맨드 · 에이전트 · 훅 · MCP 구성요소 + 설치 상태 · 설치 수. 지문 캐시, CLI 가 없으면 설정 디렉터리의 기록 파일
- 기능 검색 — `필드:값` · `-제외` · `a|b` · `/정규식/` · `has:` · `is:` · `dep:`, 동의어 · 한글 조사 제거 · 오타 허용, AND 에서 결과가 없으면 완화
- 연관 조회 — 의존 · 역의존(전이) · 공유 태그 · 키워드 · 이름 단어 · 구성요소 · 설명 단어(IDF), 기능어면 검색 상위를 씨앗으로
- 프로젝트 조회 — `.claude/settings*.json` 선언의 상태 · 의존 폐포 · 파일 신호 33종 추천, 감지 안 된 언어 대상 감점
- 설치 — 이름 · `--from` 목록, `--select` 번호 · 범위 · 이름, `--exclude`, `--all`, 선택 없으면 조회만, `--dry-run`, `--scope`
- 스킬 `plugin-search` · `project-plugin-search` · `plugin-install`
- 규칙 원본 `references/search-rules.md`, 데이터 `search-synonyms.json` · `project-signals.json`
