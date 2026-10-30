# CHANGELOG

## 0.2.0

### Changed
- 스킬 이름 변경 — `/reference-search:company-reference-search` 는 `company-case-search`, `/reference-search:technical-document-search` 는 `technology-usage-search` 로 부른다 (#199)
- 에이전트 이름 변경 — `regional-database-searcher` 는 `regional-academic-database-searcher`, `field-database-searcher` 는 `discipline-database-searcher`. 출처 카탈로그 `references/sources/` 파일 이름도 같이 바뀐다 (#199)

## 0.1.1

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 없는 DOI · arXiv ID 를 쓰는 편집이 그대로 통과하던 것 (#163, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.0

### Added
- 규칙 원본 `references/reference-search-rules.md` (`RS-01` ~ `RS-06` 기계 검사, `RS-10` ~ `RS-20` AI 판단), 절차 `search-orchestration.md`, 결과 형식 `result-schema.md`, 근거 `reference-search-methods.md`, 출처 카탈로그 `references/sources/` 10개 (#136)
- 스킬 `paper-search` · `company-reference-search` · `technical-document-search` — 요청 깊이(빠르게 · 보통 · 깊게)와 사용자 지정(에이전트 수 · 출처 · 제외, `REFERENCE_SEARCH_DEPTH` · `REFERENCE_SEARCH_MAX_AGENTS`)으로 에이전트를 골라 병렬로 찾고 병합 · 검증한다
- 출처별 에이전트 10개(`*-searcher`)와 검증 에이전트 `reference-reviewer` (존재 · 지지를 따로 판정)
- `reference-search.sh` — 키 없이 부르는 18개 출처 조회를 정규화 JSON Lines 로. 키가 필요한 출처는 TODO 로 남기고 종료 코드 3
- `reference-validate.sh` — PreToolUse 훅으로 `.md` 에 새로 쓰는 없는 DOI · arXiv ID 를 차단하고 철회를 알린다. `/reference-validate` 로 파일 전체와 URL 확인
- 회귀 테스트 `test/` (네트워크 없이 curl · gh 스텁, 61건), eval 케이스 둘 (스킬 발동 · 에이전트 분담, 훅 차단)
