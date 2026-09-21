# plugin-workflow

플러그인 변경이 **이슈에서 릴리즈까지 가는 경로**를 강제한다 — 이슈·PR 템플릿, 브랜치 이름, main 보호, 리베이스 뒤 머지 커밋, main 에서만 태그.

이름 · 위치 · 버전 · 작성 형식 · 의존 관계는 각 플러그인이 본다. 여기서는 **git 과 GitHub 에서 밟는 순서**만 본다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다. 다른 곳에서 쓰려면 `public-plugins/` 로 옮긴다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| issue-create | 작업 시작, 이슈 · 브랜치 · 워크트리 만들기 | 1 · 2 단계 — 타입 판단, 이슈 발행, `origin/main` 에서 브랜치 · 워크트리 |
| pull-request-create | PR 올리기, 리베이스, 검증 | 4 ~ 8 단계 — 버전, 검증 · 테스트, 리베이스 뒤 재검증, 템플릿 PR |
| release-create | 머지, 릴리즈, 태그, 정리 | 9 ~ 12 단계 — 머지 커밋, 설치 확인, 태그 · 릴리즈, 정리 |
| /workflow-validate | 직접 호출 | 템플릿 · 현재 브랜치 · 최신 여부 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-workflow.sh | PreToolUse (Bash) | `git` · `gh` · `claude plugin tag` 명령이 `W-03` ~ `W-10` 을 어기면 **차단**. 워크트리 위치(`W-04`)는 알림 |

## 파일

| 경로 | 역할 |
|---|---|
| `references/workflow-rules.md` | 개발 플로우 규칙 원본 (`W-01` ~ `W-10`) |
| `scripts/validate-workflow.sh` | 훅 · CLI 겸용 검증 (`--templates` · `--branch` · `--up-to-date`) |
| `scripts/branch-create.sh` | 2 단계 — 규칙에 맞는 브랜치와 워크트리를 `origin/main` 에서 |
| `scripts/verify-all.sh` | 5 · 6 단계 — 검증기 · 회귀 테스트 · `claude plugin validate` 를 경로 규칙으로 찾아 전부 |
| `scripts/release-plugins.sh` | 11 단계 — 버전이 바뀐 플러그인마다 태그 · 릴리즈 (`--dry-run`) |
| `test/` | 회귀 테스트와 TC 명세 |

템플릿 자체는 GitHub 가 읽는 자리인 저장소 `.github/` 에 있다. 이 플러그인은 그 존재와 형식을 검사한다 (`W-01` · `W-02`).

## 무엇을 막나

| | 조항 |
|---|---|
| 템플릿 | `W-01` 이슈 폼 `feature` · `bugfix` + 빈 이슈 금지 · `W-02` PR 템플릿 두 개, 단일 기본 파일 금지 |
| 브랜치 | `W-03` `{feature\|bugfix}/{이슈}-{slug}` · `W-04` 워크트리 위치 (알림) |
| PR · 머지 | `W-05` 템플릿 · 라벨 · `--fill` 금지 · `W-06` 최신 `origin/main` 포함 · `W-07` 머지 커밋만 |
| main | `W-08` 강제 푸시는 `--force-with-lease` 만 · `W-09` main 직접 커밋 · 머지 · 푸시 금지 · `W-10` 태그는 main 에서만 |

## 왜 훅인가

저장소가 비공개 + 무료 플랜이라 GitHub 브랜치 보호를 켤 수 없다. "최신 main 위에서만 머지", "main 직접 푸시 금지" 를 Claude 가 실행하는 명령에서 막는다. **웹 UI 의 머지 · 푸시는 막지 못한다.**

## 주의

- 워크트리 세션에서 도는 훅은 **main 의 규칙**이다 — 설치 기준이 메인 체크아웃이다. 머지되기 전의 규칙이 작업을 막지 않는다
- 이 플러그인과 `.github/` 가 main 에 들어가기 전의 브랜치(`feature/plugin-creater-setting`)는 부트스트랩 예외로 한 번만 이슈 없이 머지한다

## 사용

```bash
scripts/validate-workflow.sh --templates .
scripts/branch-create.sh feature 12 plugin-dependency
scripts/verify-all.sh .
scripts/release-plugins.sh --dry-run
test/validate-workflow.test.sh
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
