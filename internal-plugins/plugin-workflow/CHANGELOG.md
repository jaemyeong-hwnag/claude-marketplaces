# CHANGELOG

## 0.3.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `plugin-workflow@jaemyeong-hwnag-plugins`

## 0.3.0

### Changed
- GitHub 플로우를 public 플러그인 `github-workflow` 로 옮기고 그것에 의존한다 (#12). 옮긴 것 — `validate-workflow.sh` 훅(`W-01` ~ `W-10`), `branch-create.sh`, `issue-create` · `pull-request-create` 스킬, `/workflow-validate`, 해당 TC · eval
- `release-create` 는 설치 확인 · 태그 · 릴리즈만 한다. 머지와 정리는 `github-workflow` 의 `pull-request-merge`
- 규칙 원본은 이 마켓플레이스가 더하는 단계(버전 · `verify-all.sh` · 설치 확인 · 태그)만 담는다
- 테스트 파일 `validate-workflow.test.sh` → `workflow-scripts.test.sh`

## 0.2.4

### Fixed
- `release-create` 스킬이 옛 노트 범위("그 버전의 절")를 안내하던 것 (#6). 직전 태그 이후의 절 전부, 첫 한꺼번에 릴리즈할 때의 `--since`, GitHub 가 Latest 를 스스로 정한다는 것을 적었다

## 0.2.3

### Fixed
- `release-plugins.sh` 의 릴리즈 노트가 현재 버전 절 하나만 담아 첫 릴리즈에서 이전 이력이 빠지던 것 (#2). 이제 직전 태그 이후의 모든 절을 담고, 태그가 없었으면 끝까지 담는다. 날짜가 붙은 제목도 경계로 읽는다
- 이 동작을 정답으로 고정하고 있던 TC-W108 을 바로잡았다

## 0.2.2

### Fixed
- `verify-all.sh` · `eval-all.sh` 가 워크트리 안에서 플러그인을 하나도 찾지 못하던 것 (#3) — `*/.claude/*` 제외가 루트 경로 자체에 걸렸다. 루트 기준으로 바꿨다

## 0.2.1

### Fixed
- `release-plugins.sh` 가 저장소 전체의 미추적 파일(`.idea/` 등)에 막히던 것. 추적 중인 파일의 변경과 **플러그인 디렉터리 안의** 미추적 파일만 본다 — `claude plugin tag` 의 요구와 같다

## 0.2.0

### Added
- `plugin-create` · `plugin-delete` 스킬 — 생성 체크리스트와 삭제 순서(역참조 → 의존 끊기 → 정리, 태그는 남긴다)
- `eval-all.sh` — 케이스 단위로 필요한 권한만 주고, 리포트는 게시하지 않고(`--no-publish`), 결과는 플러그인 밖에. Bash 샌드박스를 못 쓰는 환경은 실패가 아니라 환경 제한으로
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다 (넷)

### Changed
- `release-plugins.sh` 의 로드 확인을 `claude plugin list --json` 의 `errors` 로 (못 받으면 텍스트). 날짜가 붙은 CHANGELOG 절도 노트로 뽑는다

## 0.1.0

### Added
- 개발 플로우 규칙 원본 `references/workflow-rules.md` (`W-01` ~ `W-10`, 12 단계)
- `validate-workflow.sh` — `PreToolUse(Bash)` 훅으로 브랜치 이름 · main 보호 · 머지 방식 · 최신 확인 · 태그 위치 · PR 템플릿·라벨을 막는다. CLI `--templates` · `--branch` · `--up-to-date`
- `branch-create.sh` · `verify-all.sh` · `release-plugins.sh`
- `issue-create` · `pull-request-create` · `release-create` 스킬, `/workflow-validate` 커맨드
