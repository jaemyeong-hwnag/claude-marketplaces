# CHANGELOG

## 0.1.0

### Added
- 프로젝트 완성도를 진단 · 적용하는 public 플러그인 (#29)
- 스킬 `completeness-review` — 자동 탐지 → 측정 범위 선택 → 69항목 판정 → 위험도 · 실천 범위 · 가장 비어 있는 축 (읽기 전용)
- 스킬 `completeness-apply` — 레시피로 설정 · CI 를 만들고 검증, 실패하면 롤백. 커밋하지 않는다
- 스킬 `service-health-review` — DORA · SLO · 온콜 · 인시던트 · 성숙도 18지표를 기준과 대조
- 스크립트 `project-completeness.sh` — `detect` · `scope` · `score` · `health` · `recipe`. node 없이 bash + jq 로 동작한다
- 규칙 원본 `references/completeness-rules.md` (`Q-01` ~ `Q-19`), 데이터 `completeness-checklist.json` · `service-health-metrics.json`, 레시피 6개 파일

### Changed
- 항목 번호(`service[14]`)를 고정 id(`service.render-smoke`)로 — 항목이 늘어도 N/A · 핵심 목록이 어긋나지 않는다
- JVM(Gradle · Maven) 탐지 — 하위 모듈 의존성, `java-library` 라이브러리 판정, checkstyle · spotless · ktlint · detekt · ArchUnit · Testcontainers
- 저장소 밖에 있을 수 있는 항목(운영 도구 · 약관 · 제품 분석 SDK)은 판정하지 않고 흔적만 낸다
- 레시피의 외부 URL 을 걷어냈다 — gitleaks 는 컨테이너 이미지 · pre-commit `repo: local`, 앱 주소는 `<앱 주소>` 자리

### Removed
- 도구 가격 카탈로그는 두지 않는다 — 가격은 빨리 낡고 설치된 플러그인 안에서 갱신할 수 없다. 추천은 레시피가 있는 도구로 한정한다
