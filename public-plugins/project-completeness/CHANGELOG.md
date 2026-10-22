# CHANGELOG

## 0.1.4

### Fixed
- `ops.postmortem` 이 빈 파일 · `# TODO` 만 있는 템플릿 · 이름만 닮은 코드 파일(`src/lib/postMortem.ts`)로도 통과하던 것 — `ops.oncall-runbook` 과 같이 제목 · 주석 말고 내용이 있는 문서여야 통과한다 (#120). 두 판정 모두 코드 확장자 파일은 세지 않는다
- 레시피의 서드파티 CI 액션(osv-scanner · scorecard · codecov · size-limit · golangci-lint · govulncheck · pre-commit)이 태그로만 적혀 규칙(SHA 고정)과 어긋나던 것 — `@<커밋 SHA> # vX.Y.Z` 로 고정했다 (#120)

## 0.1.3

### Fixed
- `code.lint-ci` 가 package.json 에 린터 스크립트만 있고 CI 가 `yarn build` 만 돌려도 통과하던 것 — 린터를 부르는 스크립트를 CI 가 실행해야 통과한다 (#98). pre-commit 의 린터는 CI 가 pre-commit 을 돌릴 때만 센다
- `code.quality-gate` 가 `pull_request` 트리거 워크플로가 하나라도 있으면(labeler 하나로도) 통과하던 것 — 그 워크플로(또는 그것이 부르는 로컬 재사용 워크플로 · 복합 액션)가 lint · test · build 를 돌려야 통과한다 (#98)
- `security.secret-scan` 의 pre-commit 판정이 `.pre-commit-config.yaml` 만 봐 husky · lefthook 훅이면 실패하던 것 — `.husky/pre-commit` · `lefthook.yml` 도 본다 (#98)
- `perf.load-test` 가 경로에 `perf` 가 든 아무 `.js` · `.ts`(`src/utils/performance.ts`)로 통과하던 것 — 부하 테스트 디렉터리 이름 또는 k6 import 로 본다 (#98)
- `ops.oncall-runbook` 이 빈 파일 · 제목만 있는 파일도 이름(`runbook` · `alertmanager` · `oncall`)만으로 통과하던 것 — 제목 · 주석 말고 내용이 있는 파일이어야 통과한다 (#98)
- `scope --type` · `score --pass` 처럼 값 없이 끝난 옵션이 `shift 2` 실패로 끝나지 않던 것 — 값이 없으면 종료 2 로 끝낸다 (#98)

## 0.1.2

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `project-completeness@jaemyeong-hwnag-plugins`

## 0.1.1

### Fixed
- eval `completeness-request` 가 Docker Desktop 을 설치한 macOS 에서 Bash 샌드박스 제한으로 건너뛰던 것 (#31). 스킬 발동만 보는 케이스라 `Bash` 권한과 픽스처의 `git` 을 뺐다

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
