# CHANGELOG

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
