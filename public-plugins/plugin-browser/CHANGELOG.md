# CHANGELOG

## 0.1.0

### Added
- `plugin-search-install` 의 결과를 터미널에서 보고 골라 설치하는 CLI 화면 public 플러그인 (#34). 조회 · 설치 로직은 갖지 않고 엔진을 JSON 으로 부른다
- 스크립트 `plugin-browser.sh` — 메뉴 · `search` · `project` · `related` · `installed` · `show` · `facets` · `render`
- 폭별 레이아웃 — 120 이상 표(태그 · 이유 열), 100 이상 표, 70 이상 축약 표, 40 이상 카드, 그 아래 목록. 오른쪽 1칸 여백
- 표시 폭 — 한글 · CJK · 이모지 2칸, 결합 문자 0칸, 모호 폭은 터미널에 커서 위치를 물어 판별. 데이터 `references/display-width.json` (Unicode 15.1)
- 대화형 선택 — 대체 화면, ↑↓ · Space · a · n · i · Enter · q, 창 크기 변경 재그림, 상세 창, 프로젝트 조회면 필수 중 없는 것을 미리 고름. 작은 창 · `--plain` 은 번호 입력
- 설치 확인 — 범위(project · user · local) 선택 뒤 엔진으로 설치, 상태 · 재시작 안내. 비대화형은 `--select` · `--install-all`
- 비 TTY · `NO_COLOR` · `TERM=dumb` 이면 색 없음, UTF-8 이 아니면 ASCII 장식
- 스킬 `plugin-browser`
