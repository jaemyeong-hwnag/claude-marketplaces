# CHANGELOG

## 0.10.0

### Added
- `verify-all.sh --all` — 지금까지처럼 전부 (#260)

### Changed
- `verify-all.sh` 기본 모드가 `origin/main` 대비 바뀐 파일(커밋 + 작업 트리 + 미추적)로 대상을 고른다 — 바뀐 플러그인과 `dependencies` 로 기대는 플러그인(전이 포함)의 테스트 · `claude plugin validate --strict`. 검증기 · 저장소 정책 훅 · 마켓플레이스 validate 는 늘 돌고, `.claude/hooks/` · `test/` · `.claude-plugin/` · `CLAUDE.md` 가 바뀌면 저장소 테스트도 돈다. `origin/main` 이 없으면 전부. 첫 줄에 대상을 알린다 (#260)
- `--no-run` 을 아는 검증기는 기본 모드에서 `--all --no-run` — 실행 검사는 `--since` 로 바뀐 플러그인만 (#260)

## 0.9.0

### Changed
- `release-plugins.sh` 가 `internal-plugins/` 를 태그 · 릴리즈 대상에서 뺀다. 버전 · CHANGELOG 는 그대로 올린다. 기존 internal 태그 · 릴리즈는 지우지 않는다 (#252)
- `plugin-release-create` · `plugin-create` · `plugin-name-update` 스킬과 규칙 원본 10 단계를 public 만 릴리즈하고 internal README 는 한 언어로 두는 것에 맞췄다 (#252)

### Removed
- 배포하지 않는 internal 플러그인이라 README 를 한국어 `README.ko.md` 하나로 줄였다 — `README.md` · `README.zh-CN.md` 와 언어 전환 줄을 지웠다 (#252)

## 0.8.0

### Added
- `release-plugins.sh` 릴리즈 노트를 `## English` · `## 한국어` · `## 简体中文` 세 절로 쓴다. 영어 · 중국어 간체 번역은 `--notes-dir` 로 받고, 하나라도 없거나 비면 아무것도 하지 않는다. `--dry-run --notes-dir` 는 번역 원문 `{name}.ko.md` 를 쓴다. 한국어는 늘 CHANGELOG 에서 뽑는다 (#235)
- `plugin-release-create` 스킬이 원문을 영어 · 중국어 간체로 옮긴 뒤 릴리즈한다 (#235)

## 0.7.2

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 4건을 코드에 맞췄다 — 전수 검토 (#229)
- `plugin-create` 의 단계 · 체크리스트에 README 세 언어와 루트 README 수록을 더했다 (#229)

## 0.7.1

### Fixed
- `plugin-create` 6단계가 가리키는 스킬 이름을 `plugin-document-create` 로 고쳤다 (#201, `plugin-authoring` 0.2.0 의 이름 변경)

## 0.7.0

### Changed
- 스킬 `release-create` → `plugin-release-create` (#202). 무엇의 릴리즈인지 이름으로 말하고 다른 스킬처럼 `plugin-` 으로 시작한다. 옛 이름으로 부르던 곳은 새 이름으로 부른다. 스크립트 `release-plugins.sh` 는 그대로

## 0.6.0

### Changed
- `plugin-create` 순서에 단계 둘 (#143) — 5단계 "규칙 원본 → 검증기 → 테스트"(차단 · 경고 조항이 있을 때만, 조항 ID 를 단 TC · `onFailure: "block"`), 10단계 "적어 둔 강제가 실행에서 효력이 있는가"(`enforcement-effectiveness-review`, eval 뒤). eval 안내에 스킬마다 발동 그레이더(`EF-31`), 체크리스트 두 줄

## 0.5.0

### Added
- `plugin-name-update` 스킬 · `scripts/plugin-name-update.sh` — 플러그인 이름 변경 (#141). 디렉터리 · `plugin.json` · 엔트리 · public 이면 `marketplace.json` `renames` · 기대는 플러그인의 `dependencies` · `enabledPlugins` 키를 바꾸고, 남은 문자열 참조는 후보로만 낸다. `renames` 가 있어야 설치한 사용자의 설정 키를 Claude Code 가 새 이름으로 옮긴다
- TC-W138 ~ W147, eval `name-update-steps`

## 0.4.0

### Changed
- `plugin-create` 1단계 — 새 플러그인 이름은 비슷한 이름이 있을 때만이 아니라 늘 `naming-reviewer` 에 목적 문장과 후보를 넘겨 판정받는다 (#140)

## 0.3.2

### Fixed
- `release-plugins.sh` — 대상을 현재 `version` 의 `{name}--v{version}` 태그가 없는 플러그인으로 고른다 (#85). `HEAD^1` 과만 비교해 PR 여럿을 머지한 뒤 돌리면 앞 머지의 플러그인이 빠지고, 마지막 머지가 문서뿐이면 "릴리즈할 플러그인이 없다" 로 끝났다. `--since` 는 대상을 좁히는 데만 쓴다
- `release-plugins.sh` — 이 저장소에 적용되는 설치본(`claude plugin list --json` 의 user 범위 · 이 저장소 `projectPath`)이 없거나 이번 `version` 이 아니면 멈춘다 (#85). 로드 에러만 봐서 sync 훅이 갱신하지 않는 public 플러그인의 옛 설치본으로 통과했다. `release-create` 스킬에 public 플러그인 `claude plugin update` 단계를 넣었다

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
